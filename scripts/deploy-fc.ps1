param(
    [Parameter(Mandatory = $true)]
    [string]$Image,

    [string]$Region = "ap-southeast-1",
    [string]$ServiceName = "dosclaw-qwen",
    [string]$FunctionName = "dosclaw-qwen",
    [string]$TriggerName = "http-public",
    [int]$Port = 8092
)

$ErrorActionPreference = "Stop"

function Invoke-AliyunJson {
    param(
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

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

    if (($process.ExitCode -ne 0 -or $looksDenied) -and !$AllowFailure) {
        throw $combined
    }

    return [pscustomobject]@{
        ok = $process.ExitCode -eq 0 -and !$looksDenied
        output = $combined
    }
}

function ConvertTo-CompactJson {
    param([object]$Value)
    return $Value | ConvertTo-Json -Depth 20 -Compress
}

if ([string]::IsNullOrWhiteSpace($Image)) {
    throw "Image is required. Example: registry.ap-southeast-1.aliyuncs.com/<namespace>/dosclaw-qwen:hackathon-2026-06-13"
}

Write-Host "Deploying DOSClaw-Qwen Function Compute custom container..."
Write-Host "Region: $Region"
Write-Host "Service: $ServiceName"
Write-Host "Function: $FunctionName"
Write-Host "Image: $Image"

$serviceCheck = Invoke-AliyunJson -Arguments @("fc-open", "GetService", "--region", $Region, "--serviceName", $ServiceName) -AllowFailure
if ($serviceCheck.ok) {
    Write-Host "Service exists: $ServiceName"
} else {
    $serviceBody = ConvertTo-CompactJson @{
        serviceName = $ServiceName
        description = "DOSClaw-Qwen Qwen Cloud hackathon demo service"
        internetAccess = $true
    }
    Invoke-AliyunJson -Arguments @("fc-open", "CreateService", "--region", $Region, "--body", $serviceBody) | Out-Null
    Write-Host "Created service: $ServiceName"
}

$envVars = [ordered]@{
    PORT = "$Port"
    DASHSCOPE_BASE_URL = $env:DASHSCOPE_BASE_URL
    QWEN_CHAT_MODEL = if ($env:QWEN_CHAT_MODEL) { $env:QWEN_CHAT_MODEL } else { "qwen3.6-plus" }
    QWEN_EMBED_MODEL = if ($env:QWEN_EMBED_MODEL) { $env:QWEN_EMBED_MODEL } else { "text-embedding-v4" }
}

if ($env:DASHSCOPE_API_KEY) {
    $envVars.DASHSCOPE_API_KEY = $env:DASHSCOPE_API_KEY
}

if (!$envVars.DASHSCOPE_BASE_URL) {
    $envVars.DASHSCOPE_BASE_URL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
}

$functionCheck = Invoke-AliyunJson -Arguments @("fc-open", "GetFunction", "--region", $Region, "--serviceName", $ServiceName, "--functionName", $FunctionName) -AllowFailure
if ($functionCheck.ok) {
    throw "Function already exists. To avoid accidental runtime mutation, update it manually or create a new FunctionName. Existing function: $ServiceName/$FunctionName"
}

$functionBody = ConvertTo-CompactJson @{
    functionName = $FunctionName
    description = "DOSClaw-Qwen Qwen Cloud support agent demo"
    runtime = "custom-container"
    handler = "index.handler"
    caPort = $Port
    memorySize = 512
    timeout = 60
    instanceConcurrency = 10
    customContainerConfig = @{
        image = $Image
        webServerMode = $true
    }
    environmentVariables = $envVars
}

Invoke-AliyunJson -Arguments @("fc-open", "CreateFunction", "--region", $Region, "--serviceName", $ServiceName, "--function", $functionBody) | Out-Null
Write-Host "Created function: $ServiceName/$FunctionName"

$triggerBody = ConvertTo-CompactJson @{
    triggerName = $TriggerName
    triggerType = "http"
    description = "Public HTTP trigger for DOSClaw-Qwen hackathon demo"
    triggerConfig = @{
        authType = "anonymous"
        methods = @("GET", "POST", "OPTIONS")
        disableURLInternet = $false
    }
}

$trigger = Invoke-AliyunJson -Arguments @(
    "fc-open",
    "CreateTrigger",
    "--region",
    $Region,
    "--serviceName",
    $ServiceName,
    "--functionName",
    $FunctionName,
    "--body",
    $triggerBody
)

Write-Host "Created HTTP trigger: $TriggerName"
Write-Host $trigger.output
Write-Host "After deployment, run:"
Write-Host '$env:DOSCLAW_QWEN_URL = "<trigger-url>"'
Write-Host "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke-scenarios.ps1"
