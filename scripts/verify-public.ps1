param(
    [switch]$SkipDocker
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$bundleRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $bundleRoot

Write-Host "Verifying Huyen public bundle..."

npm ci
npm run build

if (!$SkipDocker) {
    docker build -t huyen-qwen-cloud:verify .
    $existing = docker ps -a --filter "name=^huyen-verify$" --format "{{.Names}}"
    if ($existing -contains "huyen-verify") {
        docker rm -f huyen-verify | Out-Null
    }
    docker run -d --name huyen-verify -p 3010:3010 huyen-qwen-cloud:verify | Out-Null
    try {
        Start-Sleep -Seconds 4
        $health = Invoke-RestMethod -Uri "http://localhost:3010/api/health"
        if (!$health.ok -or $health.service -ne "huyen") {
            throw "Unexpected health response: $($health | ConvertTo-Json -Depth 5)"
        }
        $handoff = Invoke-RestMethod -Uri "http://localhost:3010/api/demo" -Method Post -ContentType "application/json" -Body '{"scenario":"handoff"}'
        if (!$handoff.ok -or $handoff.scenario -ne "handoff") {
            throw "Unexpected handoff response: $($handoff | ConvertTo-Json -Depth 5)"
        }
    } finally {
        $existing = docker ps -a --filter "name=^huyen-verify$" --format "{{.Names}}"
        if ($existing -contains "huyen-verify") {
            docker rm -f huyen-verify | Out-Null
        }
    }
}

Write-Host "Huyen public bundle verification passed."
