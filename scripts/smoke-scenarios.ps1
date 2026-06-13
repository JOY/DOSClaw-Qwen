param(
    [string]$BaseUrl = $env:DOSCLAW_QWEN_URL,
    [string]$OutputPath = "docs/proof/smoke-latest.json",
    [switch]$SkipLiveChat
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    $BaseUrl = "http://localhost:8092"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
$results = [ordered]@{
    checkedAt = (Get-Date).ToUniversalTime().ToString("o")
    baseUrl = $BaseUrl
    health = $null
    customers = @()
    chat = $null
}

Write-Host "Checking DOSClaw-Qwen at $BaseUrl..."
$health = Invoke-RestMethod -Uri "$BaseUrl/api/health"
if (!$health.ok -or $health.service -ne "dosclaw-qwen") {
    throw "Unexpected health response: $($health | ConvertTo-Json -Depth 10)"
}
$results.health = $health

$customers = Invoke-RestMethod -Uri "$BaseUrl/api/customers"
if (!$customers -or $customers.Count -lt 2) {
    throw "Expected at least two demo customers: $($customers | ConvertTo-Json -Depth 10)"
}
$results.customers = $customers

if (!$SkipLiveChat) {
    Write-Host "Checking live chat stream..."
    $body = @{
        customer_id = "cust_a"
        message = "I'm lactose intolerant. What do you recommend?"
    } | ConvertTo-Json
    $chatRaw = Invoke-RestMethod -Uri "$BaseUrl/api/chat" -Method Post -ContentType "application/json" -Body $body
    $chatLines = @($chatRaw -split "`n" | Where-Object { $_.Trim().Length -gt 0 })
    if ($chatLines.Count -lt 2) {
        throw "Expected streamed memory and message events, got: $chatRaw"
    }
    $parsed = @($chatLines | ForEach-Object { $_ | ConvertFrom-Json })
    if (!($parsed | Where-Object { $_.kind -eq "memory" })) {
        throw "Missing memory event in chat stream: $chatRaw"
    }
    if (!($parsed | Where-Object { $_.kind -in @("message", "message_delta") })) {
        throw "Missing reply event in chat stream: $chatRaw"
    }
    $results.chat = $parsed
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

Write-Host "DOSClaw-Qwen smoke scenarios passed. Evidence written to $outputFullPath"
