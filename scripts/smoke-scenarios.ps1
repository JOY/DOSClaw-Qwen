param(
    [string]$BaseUrl = $env:HUYEN_URL,
    [string]$OutputPath = "docs/proof/smoke-latest.json"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    $BaseUrl = "http://localhost:3010"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
$scenarios = @("memory", "knowledge", "handoff")
$results = [ordered]@{
    checkedAt = (Get-Date).ToUniversalTime().ToString("o")
    baseUrl = $BaseUrl
    health = $null
    scenarios = @()
}

Write-Host "Checking Huyen at $BaseUrl..."
$health = Invoke-RestMethod -Uri "$BaseUrl/api/health"
if (!$health.ok -or $health.service -ne "huyen") {
    throw "Unexpected health response: $($health | ConvertTo-Json -Depth 10)"
}
$results.health = $health

foreach ($scenario in $scenarios) {
    Write-Host "Checking scenario: $scenario"
    $body = @{ scenario = $scenario } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$BaseUrl/api/demo" -Method Post -ContentType "application/json" -Body $body

    if (!$response.ok -or $response.scenario -ne $scenario) {
        throw "Unexpected scenario response for ${scenario}: $($response | ConvertTo-Json -Depth 10)"
    }
    if (!$response.evidence.modelRef -or $response.evidence.modelRef -notlike "qwen-cloud/*") {
        throw "Missing qwen-cloud modelRef for ${scenario}: $($response | ConvertTo-Json -Depth 10)"
    }
    if (!$response.evidence.mcpTools -or $response.evidence.mcpTools.Count -lt 1) {
        throw "Missing MCP tool evidence for ${scenario}: $($response | ConvertTo-Json -Depth 10)"
    }
    if ($response.result.answerSource -notin @("qwen-cloud-live", "synthetic-fallback")) {
        throw "Unexpected answerSource for ${scenario}: $($response | ConvertTo-Json -Depth 10)"
    }

    $results.scenarios += [ordered]@{
        scenario = $scenario
        answerSource = $response.result.answerSource
        liveQwen = [bool]$response.evidence.liveQwen
        qwenConfigured = [bool]$response.evidence.qwenConfigured
        modelRef = $response.evidence.modelRef
        mcpTools = $response.evidence.mcpTools
        qwenError = $response.evidence.qwenError
    }
}

$outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
} else {
    Join-Path (Get-Location) $OutputPath
}

$outputDir = Split-Path -Parent $outputFullPath
if (!(Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Force $outputDir | Out-Null
}

$json = $results | ConvertTo-Json -Depth 10
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outputFullPath, $json + [Environment]::NewLine, $utf8NoBom)

Write-Host "Huyen smoke scenarios passed. Evidence written to $outputFullPath"
