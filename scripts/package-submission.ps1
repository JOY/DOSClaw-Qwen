param(
    [string]$OutputPath = "docs/proof/huyen-submission-evidence.zip"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("huyen-submission-" + [System.Guid]::NewGuid().ToString("N"))
$outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
} else {
    Join-Path $repoRoot $OutputPath
}

$outputDir = Split-Path -Parent $outputFullPath
if (!(Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Force $outputDir | Out-Null
}

New-Item -ItemType Directory -Force $staging | Out-Null

try {
    $docsOut = Join-Path $staging "docs"
    $proofOut = Join-Path $staging "proof"
    New-Item -ItemType Directory -Force $docsOut, $proofOut | Out-Null

    $docFiles = @(
        "README.md",
        "docs/devpost-draft.md",
        "docs/blog-post-draft.md",
        "docs/social-post-draft.md",
        "docs/demo-script.md",
        "docs/video-recording-packet.md",
        "docs/architecture.mmd",
        "docs/deployment-proof.md",
        "docs/judging-packet.md",
        "docs/alibaba-cloud-deploy.md",
        "docs/alibaba-ram-policy-huyen-deploy.json",
        "scripts/preflight-alibaba.ps1",
        "scripts/smoke-scenarios.ps1"
    )

    foreach ($file in $docFiles) {
        $source = Join-Path $repoRoot $file
        if (!(Test-Path -LiteralPath $source)) {
            throw "Missing submission evidence file: $file"
        }
        $target = Join-Path $staging $file
        $targetDir = Split-Path -Parent $target
        if (!(Test-Path -LiteralPath $targetDir)) {
            New-Item -ItemType Directory -Force $targetDir | Out-Null
        }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }

    $smokeFiles = Get-ChildItem -LiteralPath (Join-Path $repoRoot "docs/proof") -Filter "*.json" -ErrorAction SilentlyContinue
    foreach ($file in $smokeFiles) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $proofOut $file.Name) -Force
    }

    $links = [ordered]@{
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        repository = "https://github.com/JOY/huyen-qwen-cloud"
        ci = "https://github.com/JOY/huyen-qwen-cloud/actions"
        permissionIssue = "https://github.com/JOY/huyen-qwen-cloud/issues/1"
        liveQwenAdapter = "https://github.com/JOY/huyen-qwen-cloud/blob/main/src/lib/qwen.ts"
        demoApi = "https://github.com/JOY/huyen-qwen-cloud/blob/main/src/app/api/demo/route.ts"
        healthApi = "https://github.com/JOY/huyen-qwen-cloud/blob/main/src/app/api/health/route.ts"
        smokeScript = "https://github.com/JOY/huyen-qwen-cloud/blob/main/scripts/smoke-scenarios.ps1"
        preflightScript = "https://github.com/JOY/huyen-qwen-cloud/blob/main/scripts/preflight-alibaba.ps1"
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        (Join-Path $staging "links.json"),
        (($links | ConvertTo-Json -Depth 10) + [Environment]::NewLine),
        $utf8NoBom
    )

    if (Test-Path -LiteralPath $outputFullPath) {
        Remove-Item -LiteralPath $outputFullPath -Force
    }

    Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $outputFullPath -Force
    Write-Host "Huyen submission evidence package written to $outputFullPath"
} finally {
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}
