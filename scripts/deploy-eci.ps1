param(
    [Parameter(Mandatory = $true)]
    [string]$Image,

    [Parameter(Mandatory = $true)]
    [string]$VSwitchId,

    [Parameter(Mandatory = $true)]
    [string]$SecurityGroupId,

    [string]$Region = "ap-southeast-1",
    [string]$ContainerGroupName = "dosclaw-qwen",
    [int]$Port = 8092,
    [double]$Cpu = 1,
    [double]$Memory = 2
)

$ErrorActionPreference = "Stop"

function Invoke-AliyunEci {
    param([string[]]$Arguments)

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    $process = Start-Process `
        -FilePath "aliyun" `
        -ArgumentList $Arguments `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath

    $stdout = Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
    $stderr = Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

    $combined = (($stdout, $stderr) | Where-Object { $_ }) -join [Environment]::NewLine
    $looksDenied = $combined -match "AccessDenied|Unauthorized|AUTHENTICATION_FAILED|Forbidden\.Unauthorized|ImplicitDeny"

    if ($process.ExitCode -ne 0 -or $looksDenied) {
        throw $combined
    }

    return $combined
}

function Add-EnvArgs {
    param(
        [System.Collections.Generic.List[string]]$Args,
        [int]$Index,
        [string]$Key,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $Args.Add("--Container.1.EnvironmentVar.$Index.Key")
    $Args.Add($Key)
    $Args.Add("--Container.1.EnvironmentVar.$Index.Value")
    $Args.Add($Value)
}

Write-Host "Deploying DOSClaw-Qwen to Elastic Container Instance..."
Write-Host "Region: $Region"
Write-Host "Container group: $ContainerGroupName"
Write-Host "Image: $Image"

$dashscopeBaseUrl = if ($env:DASHSCOPE_BASE_URL) {
    $env:DASHSCOPE_BASE_URL
} else {
    "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
}
$qwenModel = if ($env:QWEN_CHAT_MODEL) { $env:QWEN_CHAT_MODEL } else { "qwen3.6-plus" }
$qwenEmbedModel = if ($env:QWEN_EMBED_MODEL) { $env:QWEN_EMBED_MODEL } else { "text-embedding-v4" }

$argsList = [System.Collections.Generic.List[string]]::new()
@(
    "eci",
    "CreateContainerGroup",
    "--region", $Region,
    "--ContainerGroupName", $ContainerGroupName,
    "--VSwitchId", $VSwitchId,
    "--SecurityGroupId", $SecurityGroupId,
    "--RestartPolicy", "Always",
    "--Cpu", "$Cpu",
    "--Memory", "$Memory",
    "--Container.1.Name", "dosclaw-qwen",
    "--Container.1.Image", $Image,
    "--Container.1.ImagePullPolicy", "Always",
    "--Container.1.Port.1.Port", "$Port",
    "--Container.1.Port.1.Protocol", "TCP"
) | ForEach-Object { $argsList.Add($_) }

Add-EnvArgs -Args $argsList -Index 1 -Key "PORT" -Value "$Port"
Add-EnvArgs -Args $argsList -Index 2 -Key "DASHSCOPE_BASE_URL" -Value $dashscopeBaseUrl
Add-EnvArgs -Args $argsList -Index 3 -Key "QWEN_CHAT_MODEL" -Value $qwenModel
Add-EnvArgs -Args $argsList -Index 4 -Key "QWEN_EMBED_MODEL" -Value $qwenEmbedModel
Add-EnvArgs -Args $argsList -Index 5 -Key "DASHSCOPE_API_KEY" -Value $env:DASHSCOPE_API_KEY

$result = Invoke-AliyunEci -Arguments $argsList.ToArray()
Write-Host $result
Write-Host "After the container group is running, use the ECI console or DescribeContainerGroups to find the public endpoint or attach a load balancer."
Write-Host '$env:DOSCLAW_QWEN_URL = "http://<public-endpoint>:8092"'
Write-Host "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke-scenarios.ps1"
