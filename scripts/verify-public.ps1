param(
    [switch]$SkipDocker
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$bundleRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $bundleRoot

Write-Host "Verifying DOSClaw-Qwen public bundle..."

python -m pytest -v
python -m compileall dosclaw_qwen tests

if (!$SkipDocker) {
    docker build -t dosclaw-qwen:verify .
    $existing = docker ps -a --filter "name=^dosclaw-qwen-verify$" --format "{{.Names}}"
    if ($existing -contains "dosclaw-qwen-verify") {
        docker rm -f dosclaw-qwen-verify | Out-Null
    }
    docker run -d --name dosclaw-qwen-verify -p 8092:8092 dosclaw-qwen:verify | Out-Null
    try {
        Start-Sleep -Seconds 4
        $health = Invoke-RestMethod -Uri "http://localhost:8092/api/health"
        if (!$health.ok -or $health.service -ne "dosclaw-qwen") {
            throw "Unexpected health response: $($health | ConvertTo-Json -Depth 5)"
        }
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $bundleRoot "scripts/smoke-scenarios.ps1") -BaseUrl "http://localhost:8092" -OutputPath "docs/proof/local-smoke-latest.json"
    } finally {
        $existing = docker ps -a --filter "name=^dosclaw-qwen-verify$" --format "{{.Names}}"
        if ($existing -contains "dosclaw-qwen-verify") {
            docker rm -f dosclaw-qwen-verify | Out-Null
        }
    }
}

Write-Host "DOSClaw-Qwen public bundle verification passed."
