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
    [double]$QdrantMemory = 0.5
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
    throw "Set DASHSCOPE_API_KEY in the environment or .env before updating ECI."
}

$dashscopeBaseUrl = Get-DotEnvValue "DASHSCOPE_BASE_URL" "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
$qwenChatModel = Get-DotEnvValue "QWEN_CHAT_MODEL" "qwen3.6-plus"
$qwenEmbedModel = Get-DotEnvValue "QWEN_EMBED_MODEL" "text-embedding-v4"
$embedDim = Get-DotEnvValue "EMBED_DIM" "1024"
$tenantId = Get-DotEnvValue "DEFAULT_TENANT_ID" "tenant_demo"
$demoLoginUser = Get-DotEnvValue "DEMO_LOGIN_USER" "judge"
$demoLoginPass = Get-DotEnvValue "DEMO_LOGIN_PASS" ""
$sourceRev = Get-SourceRevision

$existing = aliyun eci DescribeContainerGroups --region $Region --ContainerGroupName $ContainerGroupName | ConvertFrom-Json
$existingGroup = @($existing.ContainerGroups)[0]
if (!$existingGroup) {
    throw "Container group '$ContainerGroupName' was not found in $Region."
}

$bootstrap = @"
set -eu
apt-get update
apt-get install -y --no-install-recommends git ca-certificates
rm -rf /var/lib/apt/lists/* /app
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

$argsList = [System.Collections.Generic.List[string]]::new()
@(
    "eci",
    "UpdateContainerGroup",
    "--RegionId", $Region,
    "--ContainerGroupId", $existingGroup.ContainerGroupId,
    "--UpdateType", "IncrementalUpdate",
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
    "--Container.1.ReadinessProbe.TimeoutSeconds", "5"
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

Write-Host "Updating app container in $ContainerGroupName without touching DB/Qdrant or creating a new EIP..."
Invoke-AliyunEci -Arguments $argsList.ToArray() | Out-Null
Write-Host "Waiting for containers to become ready..."

for ($i = 0; $i -lt 120; $i++) {
    $status = aliyun eci DescribeContainerGroups --region $Region --ContainerGroupName $ContainerGroupName | ConvertFrom-Json
    $group = @($status.ContainerGroups)[0]
    if ($group) {
        $readyCount = @($group.Containers | Where-Object { $_.Ready }).Count
        Write-Host "Status=$($group.Status) Ready=$readyCount/$(@($group.Containers).Count) InternetIP=$($group.InternetIp)"
        if ($group.InternetIp -and $group.Status -eq "Running" -and $readyCount -eq @($group.Containers).Count) {
            $baseUrl = if ($PublicPort -eq 80) { "http://$($group.InternetIp)" } else { "http://$($group.InternetIp):$PublicPort" }
            Invoke-RestMethod -Uri "$baseUrl/api/health" | Out-Null
            Write-Host "Public URL: $baseUrl"
            exit 0
        }
    }
    Start-Sleep -Seconds 10
}

throw "Timed out waiting for ECI update."
