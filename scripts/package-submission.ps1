param(
    [string]$OutputPath = "docs/proof/dosclaw-qwen-submission-evidence.zip"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("dosclaw-qwen-submission-" + [System.Guid]::NewGuid().ToString("N"))
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
        "ARCHITECTURE.md",
        "HANDOFF.md",
        "Dockerfile",
        "docker-compose.yml",
        "docs/MEMORY_STACK.md",
        "docs/AGENTSCOPE_API.md",
        "docs/hackathon-reference.md",
        "docs/devpost-draft.md",
        "docs/demo-script.md",
        "docs/video-recording-packet.md",
        "docs/judging-packet.md",
        "docs/submission-status.md",
        "docs/deployment-proof.md",
        "docs/architecture.mmd",
        "docs/proof/README.md",
        "infra/alibaba/README.md",
        "infra/alibaba/ram-policy-dosclaw-qwen-deploy.json",
        "scripts/preflight-alibaba.ps1",
        "scripts/deploy-fc.ps1",
        "scripts/deploy-eci.ps1",
        "scripts/deploy-eci-source.ps1",
        "scripts/deploy-ecs-ssh.ps1",
        "scripts/deploy-acr.sh",
        "scripts/smoke-scenarios.ps1",
        "scripts/render-demo-video.ps1"
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

    $proofFiles = @()
    $proofFiles += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "docs/proof") -Filter "*.json" -ErrorAction SilentlyContinue)
    $proofFiles += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "docs/proof") -Filter "*.mp4" -ErrorAction SilentlyContinue)
    foreach ($file in $proofFiles) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $proofOut $file.Name) -Force
    }

    $links = [ordered]@{
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        repository = "https://github.com/JOY/DOSClaw-Qwen"
        ci = "https://github.com/JOY/DOSClaw-Qwen/actions"
        liveDemo = "http://8.219.211.170/"
        runtimeApi = "http://8.219.211.170/api/runtime"
        liveQwenAdapter = "https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py"
        demoApi = "https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/app.py"
        healthApi = "https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/app.py"
        devpostDraft = "https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/devpost-draft.md"
        judgingPacket = "https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/judging-packet.md"
        demoScript = "https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/demo-script.md"
        videoRecordingPacket = "https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/video-recording-packet.md"
        submissionStatus = "https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/submission-status.md"
        deploymentProofNotes = "https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/deployment-proof.md"
        architectureDiagram = "https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.mmd"
        deployRamPolicy = "https://github.com/JOY/DOSClaw-Qwen/blob/main/infra/alibaba/ram-policy-dosclaw-qwen-deploy.json"
        smokeScript = "https://github.com/JOY/DOSClaw-Qwen/blob/main/scripts/smoke-scenarios.ps1"
        preflightScript = "https://github.com/JOY/DOSClaw-Qwen/blob/main/scripts/preflight-alibaba.ps1"
        functionComputeDeployScript = "https://github.com/JOY/DOSClaw-Qwen/blob/main/scripts/deploy-fc.ps1"
        elasticContainerInstanceDeployScript = "https://github.com/JOY/DOSClaw-Qwen/blob/main/scripts/deploy-eci.ps1"
        elasticContainerInstanceSourceDeployScript = "https://github.com/JOY/DOSClaw-Qwen/blob/main/scripts/deploy-eci-source.ps1"
        ecsSshDeployScript = "https://github.com/JOY/DOSClaw-Qwen/blob/main/scripts/deploy-ecs-ssh.ps1"
        demoVideoRenderScript = "https://github.com/JOY/DOSClaw-Qwen/blob/main/scripts/render-demo-video.ps1"
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
    Write-Host "DOSClaw-Qwen submission evidence package written to $outputFullPath"
} finally {
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}
