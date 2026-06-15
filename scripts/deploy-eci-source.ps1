param(
    [string]$Region = "ap-southeast-1",
    [string]$ContainerGroupName = "dosclaw-qwen",
    [string]$RepoUrl = "https://github.com/JOY/DOSClaw-Qwen.git",
    [string]$Branch = "main",
    [int]$Port = 8092,
    [int]$PublicPort = 80,
    [double]$AppCpu = 1,
    [double]$AppMemory = 2,
    [double]$DbCpu = 0.5,
    [double]$DbMemory = 1,
    [double]$ProxyCpu = 0.1,
    [double]$ProxyMemory = 0.128,
    [double]$QdrantCpu = 0.2,
    [double]$QdrantMemory = 0.5,
    [switch]$ReplaceExisting
)

$ErrorActionPreference = "Stop"

function Get-DotEnvValue {
    param(
        [string]$Name,
        [string]$Default = ""
    )

    $current = [Environment]::GetEnvironmentVariable($Name)
    if (![string]::IsNullOrWhiteSpace($current)) {
        return $current
    }

    $envPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")) ".env"
    if (Test-Path -LiteralPath $envPath) {
        $line = Get-Content -LiteralPath $envPath | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -First 1
        if ($line) {
            return $line -replace "^$([regex]::Escape($Name))=", ""
        }
    }

    return $Default
}

function Invoke-AliyunEci {
    param([string[]]$Arguments)

    $combined = (& aliyun @Arguments 2>&1 | Out-String)
    $looksDenied = $combined -match "AccessDenied|Unauthorized|AUTHENTICATION_FAILED|Forbidden\.Unauthorized|ImplicitDeny"

    if ($LASTEXITCODE -ne 0 -or $looksDenied) {
        throw $combined
    }

    return $combined
}

function Ensure-SecurityGroupPort {
    param(
        [string]$Region,
        [string]$SecurityGroupId,
        [int]$Port
    )

    if ([string]::IsNullOrWhiteSpace($SecurityGroupId)) {
        Write-Warning "ECI did not return a SecurityGroupId; verify port $Port manually."
        return
    }

    $ruleExists = $false
    try {
        $securityGroup = Invoke-AliyunEci -Arguments @(
            "ecs", "DescribeSecurityGroupAttribute",
            "--region", $Region,
            "--SecurityGroupId", $SecurityGroupId
        ) | ConvertFrom-Json
        $ruleExists = @($securityGroup.Permissions.Permission) | Where-Object {
            $_.Direction -eq "ingress" -and
            $_.Policy -eq "Accept" -and
            $_.IpProtocol -eq "TCP" -and
            $_.PortRange -eq "$Port/$Port" -and
            $_.SourceCidrIp -eq "0.0.0.0/0"
        } | Select-Object -First 1
    } catch {
        Write-Warning "Could not inspect Security Group $SecurityGroupId. Open TCP $Port manually if the public URL times out. $($_.Exception.Message)"
        return
    }

    if ($ruleExists) {
        Write-Host "Security Group $SecurityGroupId already allows TCP $Port."
        return
    }

    Write-Host "Opening Security Group $SecurityGroupId for TCP $Port..."
    try {
        Invoke-AliyunEci -Arguments @(
            "ecs", "AuthorizeSecurityGroup",
            "--region", $Region,
            "--SecurityGroupId", $SecurityGroupId,
            "--IpProtocol", "tcp",
            "--PortRange", "$Port/$Port",
            "--SourceCidrIp", "0.0.0.0/0",
            "--Policy", "accept",
            "--Priority", "100"
        ) | Out-Null
    } catch {
        Write-Warning "Could not open Security Group $SecurityGroupId. Grant ecs:AuthorizeSecurityGroup or open TCP $Port manually. $($_.Exception.Message)"
    }
}

function Add-EnvArgs {
    param(
        [System.Collections.Generic.List[string]]$TargetArgs,
        [int]$ContainerIndex,
        [int]$Index,
        [string]$Key,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $TargetArgs.Add("--Container.$ContainerIndex.EnvironmentVar.$Index.Key=$Key")
    $TargetArgs.Add("--Container.$ContainerIndex.EnvironmentVar.$Index.Value=$Value")
}

function Get-SourceRevision {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
    $envRev = Get-DotEnvValue "APP_SOURCE_REV"
    if (![string]::IsNullOrWhiteSpace($envRev)) {
        return $envRev
    }

    try {
        $gitRev = (& git -C $repoRoot rev-parse --short HEAD 2>$null | Select-Object -First 1).Trim()
        if (![string]::IsNullOrWhiteSpace($gitRev)) {
            return $gitRev
        }
    } catch {
    }

    return (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss")
}

$dashscopeApiKey = Get-DotEnvValue "DASHSCOPE_API_KEY"
if ([string]::IsNullOrWhiteSpace($dashscopeApiKey)) {
    throw "Set DASHSCOPE_API_KEY in the environment or .env before deploying."
}

$dashscopeBaseUrl = Get-DotEnvValue "DASHSCOPE_BASE_URL" "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
$qwenChatModel = Get-DotEnvValue "QWEN_CHAT_MODEL" "qwen3.6-plus"
$qwenEmbedModel = Get-DotEnvValue "QWEN_EMBED_MODEL" "text-embedding-v4"
$embedDim = Get-DotEnvValue "EMBED_DIM" "1024"
$tenantId = Get-DotEnvValue "DEFAULT_TENANT_ID" "tenant_demo"
$demoLoginUser = Get-DotEnvValue "DEMO_LOGIN_USER" "judge"
$demoLoginPass = Get-DotEnvValue "DEMO_LOGIN_PASS" "changeme-demo-pass"
$sourceRev = Get-SourceRevision

$existing = aliyun eci DescribeContainerGroups --region $Region --ContainerGroupName $ContainerGroupName | ConvertFrom-Json
$existingGroup = @($existing.ContainerGroups)[0]
if ($existingGroup) {
    if (!$ReplaceExisting) {
        throw "Container group '$ContainerGroupName' already exists. Re-run with -ReplaceExisting to delete and recreate it."
    }
    Write-Host "Deleting existing container group $ContainerGroupName..."
    Invoke-AliyunEci -Arguments @("eci", "DeleteContainerGroup", "--region", $Region, "--ContainerGroupId", $existingGroup.ContainerGroupId) | Out-Null
    do {
        Start-Sleep -Seconds 3
        $current = aliyun eci DescribeContainerGroups --region $Region --ContainerGroupName $ContainerGroupName | ConvertFrom-Json
    } while (@($current.ContainerGroups).Count -gt 0)
}

$bootstrap = @"
set -eu
apt-get update
apt-get install -y --no-install-recommends git ca-certificates
rm -rf /var/lib/apt/lists/*
git clone --depth 1 --branch "$Branch" "$RepoUrl" /app
cd /app
export APP_GIT_SHA="`$(git rev-parse --short HEAD)"
pip install --no-cache-dir -r requirements.txt
python -c "import asyncio, pathlib, asyncpg
async def main():
    conn = None
    for _ in range(90):
        try:
            conn = await asyncpg.connect('postgresql://dosclaw_qwen:dosclaw_qwen@127.0.0.1:5432/dosclaw_qwen')
            break
        except Exception:
            await asyncio.sleep(2)
    if conn is None:
        raise RuntimeError('Postgres did not become ready in time')
    for path in ['db/schema.sql', 'db/seed.sql']:
        await conn.execute(pathlib.Path(path).read_text())
    await conn.close()
asyncio.run(main())"
python -m dosclaw_qwen.seed_embeddings
uvicorn dosclaw_qwen.app:app --host 0.0.0.0 --port $Port
"@
$bootstrapBytes = [Text.Encoding]::UTF8.GetBytes($bootstrap.Replace("`r`n", "`n"))
$bootstrapB64 = [Convert]::ToBase64String($bootstrapBytes)
$bootstrapRunner = 'echo${IFS}' + $bootstrapB64 + '|base64${IFS}-d|sh'

$proxy = @"
cat >/etc/nginx/conf.d/default.conf <<'EOF'
server {
    listen $PublicPort;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:$Port;
        proxy_http_version 1.1;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        add_header X-Accel-Buffering no;
    }
}
EOF
nginx -g 'daemon off;'
"@
$proxyBytes = [Text.Encoding]::UTF8.GetBytes($proxy.Replace("`r`n", "`n"))
$proxyB64 = [Convert]::ToBase64String($proxyBytes)
$proxyRunner = 'echo${IFS}' + $proxyB64 + '|base64${IFS}-d|sh'

$argsList = [System.Collections.Generic.List[string]]::new()
@(
    "eci",
    "CreateContainerGroup",
    "--region", $Region,
    "--ContainerGroupName", $ContainerGroupName,
    "--RestartPolicy", "Always",
    "--AutoCreateEip", "true",
    "--EipBandwidth", "5",
    "--Cpu", "$($AppCpu + $DbCpu + $ProxyCpu + $QdrantCpu)",
    "--Memory", "$($AppMemory + $DbMemory + $ProxyMemory + $QdrantMemory)",
    "--Container.1.Name", "app",
    "--Container.1.Image", "python:3.11-slim",
    "--Container.1.ImagePullPolicy", "IfNotPresent",
    "--Container.1.Command.1", "/bin/sh",
    "--Container.1.Arg.1=-lc",
    "--Container.1.Arg.2=$bootstrapRunner",
    "--Container.1.Cpu", "$AppCpu",
    "--Container.1.Memory", "$AppMemory",
    "--Container.1.Port.1.Port", "$Port",
    "--Container.1.Port.1.Protocol", "TCP",
    "--Container.1.ReadinessProbe.HttpGet.Path", "/api/health",
    "--Container.1.ReadinessProbe.HttpGet.Port", "$Port",
    "--Container.1.ReadinessProbe.InitialDelaySeconds", "120",
    "--Container.1.ReadinessProbe.PeriodSeconds", "10",
    "--Container.1.ReadinessProbe.TimeoutSeconds", "5",
    "--Container.2.Name", "db",
    "--Container.2.Image", "pgvector/pgvector:pg16",
    "--Container.2.ImagePullPolicy", "IfNotPresent",
    "--Container.2.Cpu", "$DbCpu",
    "--Container.2.Memory", "$DbMemory",
    "--Container.2.Port.1.Port", "5432",
    "--Container.2.Port.1.Protocol", "TCP",
    "--Container.3.Name", "web-proxy",
    "--Container.3.Image", "nginx:alpine",
    "--Container.3.ImagePullPolicy", "IfNotPresent",
    "--Container.3.Command.1", "/bin/sh",
    "--Container.3.Arg.1=-lc",
    "--Container.3.Arg.2=$proxyRunner",
    "--Container.3.Cpu", "$ProxyCpu",
    "--Container.3.Memory", "$ProxyMemory",
    "--Container.3.Port.1.Port", "$PublicPort",
    "--Container.3.Port.1.Protocol", "TCP",
    "--Container.3.ReadinessProbe.HttpGet.Path", "/api/health",
    "--Container.3.ReadinessProbe.HttpGet.Port", "$PublicPort",
    "--Container.3.ReadinessProbe.InitialDelaySeconds", "150",
    "--Container.3.ReadinessProbe.PeriodSeconds", "10",
    "--Container.3.ReadinessProbe.TimeoutSeconds", "5",
    "--Container.4.Name", "qdrant",
    "--Container.4.Image", "qdrant/qdrant:latest",
    "--Container.4.ImagePullPolicy", "IfNotPresent",
    "--Container.4.Cpu", "$QdrantCpu",
    "--Container.4.Memory", "$QdrantMemory",
    "--Container.4.Port.1.Port", "6333",
    "--Container.4.Port.1.Protocol", "TCP",
    "--Container.4.ReadinessProbe.HttpGet.Path", "/",
    "--Container.4.ReadinessProbe.HttpGet.Port", "6333",
    "--Container.4.ReadinessProbe.InitialDelaySeconds", "20",
    "--Container.4.ReadinessProbe.PeriodSeconds", "10",
    "--Container.4.ReadinessProbe.TimeoutSeconds", "5"
) | ForEach-Object { $argsList.Add($_) }

$appEnv = [ordered]@{
    "PORT" = "$Port"
    "DASHSCOPE_API_KEY" = $dashscopeApiKey
    "DASHSCOPE_BASE_URL" = $dashscopeBaseUrl
    "QWEN_CHAT_MODEL" = $qwenChatModel
    "QWEN_EMBED_MODEL" = $qwenEmbedModel
    "EMBED_DIM" = $embedDim
    "DATABASE_URL" = "postgresql://dosclaw_qwen:dosclaw_qwen@127.0.0.1:5432/dosclaw_qwen"
    "DEFAULT_TENANT_ID" = $tenantId
    "APP_SOURCE_REV" = $sourceRev
    "MEM0_QDRANT_PATH" = "/tmp/dosclaw-qwen-mem0/qdrant"
    "MEM0_QDRANT_HOST" = "127.0.0.1"
    "MEM0_QDRANT_PORT" = "6333"
    "DEMO_LOGIN_USER" = $demoLoginUser
    "DEMO_LOGIN_PASS" = $demoLoginPass
}

$envIndex = 1
foreach ($entry in $appEnv.GetEnumerator()) {
    Add-EnvArgs -TargetArgs $argsList -ContainerIndex 1 -Index $envIndex -Key $entry.Key -Value $entry.Value
    $envIndex += 1
}

$dbEnv = [ordered]@{
    "POSTGRES_USER" = "dosclaw_qwen"
    "POSTGRES_PASSWORD" = "dosclaw_qwen"
    "POSTGRES_DB" = "dosclaw_qwen"
}

$envIndex = 1
foreach ($entry in $dbEnv.GetEnumerator()) {
    Add-EnvArgs -TargetArgs $argsList -ContainerIndex 2 -Index $envIndex -Key $entry.Key -Value $entry.Value
    $envIndex += 1
}

Write-Host "Deploying DOSClaw-Qwen source bootstrap to ECI..."
$result = Invoke-AliyunEci -Arguments $argsList.ToArray()
Write-Host $result
Write-Host "Waiting for public endpoint..."

for ($i = 0; $i -lt 120; $i++) {
    $status = aliyun eci DescribeContainerGroups --region $Region --ContainerGroupName $ContainerGroupName | ConvertFrom-Json
    $group = @($status.ContainerGroups)[0]
    if ($group) {
        Write-Host "Status=$($group.Status) InternetIP=$($group.InternetIp)"
        if ($group.InternetIp -and $group.Status -eq "Running") {
            Ensure-SecurityGroupPort -Region $Region -SecurityGroupId $group.SecurityGroupId -Port $PublicPort
            if ($PublicPort -eq 80) {
                Write-Host "Public URL: http://$($group.InternetIp)"
            } else {
                Write-Host "Public URL: http://$($group.InternetIp):$PublicPort"
            }
            exit 0
        }
    }
    Start-Sleep -Seconds 10
}

throw "Timed out waiting for ECI public endpoint."
