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
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $bundleRoot "scripts/smoke-scenarios.ps1") -BaseUrl "http://localhost:3010" -OutputPath "docs/proof/local-smoke-latest.json"
    } finally {
        $existing = docker ps -a --filter "name=^huyen-verify$" --format "{{.Names}}"
        if ($existing -contains "huyen-verify") {
            docker rm -f huyen-verify | Out-Null
        }
    }
}

Write-Host "Huyen public bundle verification passed."
