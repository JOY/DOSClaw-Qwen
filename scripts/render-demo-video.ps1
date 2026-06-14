param(
    [string]$FramesDir = "docs/proof/video-frames",
    [string]$OutputPath = "docs/proof/dosclaw-qwen-demo-local.mp4",
    [string]$Title = "DOSClaw-Qwen MemoryAgent Demo",
    [int]$Width = 1920,
    [int]$Height = 1080,
    [int]$DefaultDuration = 12
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$framesFullPath = if ([System.IO.Path]::IsPathRooted($FramesDir)) {
    $FramesDir
} else {
    Join-Path $repoRoot $FramesDir
}
$outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
} else {
    Join-Path $repoRoot $OutputPath
}

if (!(Test-Path -LiteralPath $framesFullPath)) {
    throw "Frames directory not found: $framesFullPath"
}

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (!$ffmpeg) {
    throw "ffmpeg is required to render the demo video."
}

$defaultCaptions = @{
    "01-returning-customer" = "Returning Customer A: the memory panel recalls lactose intolerance and oat-milk preference before Qwen answers."
    "02-customer-isolation" = "New Customer B: Customer A's memories do not leak into a different customer profile."
    "03-customer-profile" = "Customer B teaches a profile fact; a later turn recalls JOY and age from persistent memory."
    "04-knowledge-search" = "Policy questions use tenant FAQ search instead of unsupported guesses."
    "05-human-handoff" = "Refund complaints can create an auditable human handoff ticket before escalation is confirmed."
    "06-runtime-proof" = "Runtime proof: AgentScope 2.0, Qwen Cloud, Mem0Middleware, Qdrant, and tenant-scoped memory."
}

function Get-CaptionRows {
    param([string]$Directory)

    $captionPath = Join-Path $Directory "captions.csv"
    if (Test-Path -LiteralPath $captionPath) {
        return @(Import-Csv -LiteralPath $captionPath)
    }

    $frames = Get-ChildItem -LiteralPath $Directory -Filter "*.png" | Sort-Object Name
    return @($frames | ForEach-Object {
        [pscustomobject]@{
            File = $_.Name
            Duration = $DefaultDuration
            Caption = $defaultCaptions[$_.BaseName]
        }
    })
}

function Draw-WrappedText {
    param(
        [System.Drawing.Graphics]$Graphics,
        [string]$Text,
        [System.Drawing.Font]$Font,
        [System.Drawing.Brush]$Brush,
        [float]$X,
        [float]$Y,
        [float]$MaxWidth,
        [float]$LineHeight
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return
    }

    $words = $Text -split "\s+"
    $line = ""
    foreach ($word in $words) {
        $candidate = if ($line) { "$line $word" } else { $word }
        $size = $Graphics.MeasureString($candidate, $Font)
        if ($size.Width -le $MaxWidth -or !$line) {
            $line = $candidate
        } else {
            $Graphics.DrawString($line, $Font, $Brush, $X, $Y)
            $Y += $LineHeight
            $line = $word
        }
    }
    if ($line) {
        $Graphics.DrawString($line, $Font, $Brush, $X, $Y)
    }
}

function Render-Frame {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [string]$Caption,
        [string]$SceneTitle
    )

    $bitmap = New-Object System.Drawing.Bitmap $Width, $Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $source = [System.Drawing.Image]::FromFile($SourcePath)

    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.Clear([System.Drawing.Color]::FromArgb(19, 24, 27))

        $headerBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(33, 43, 36))
        $captionBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245, 248, 244))
        $mutedBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(178, 190, 181))
        $panelBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(247, 249, 247))
        $accentPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(132, 184, 141)), 4
        $titleFont = New-Object System.Drawing.Font "Segoe UI", 34, ([System.Drawing.FontStyle]::Bold)
        $sceneFont = New-Object System.Drawing.Font "Segoe UI", 21, ([System.Drawing.FontStyle]::Regular)
        $captionFont = New-Object System.Drawing.Font "Segoe UI", 30, ([System.Drawing.FontStyle]::Bold)

        $graphics.FillRectangle($headerBrush, 0, 0, $Width, 126)
        $graphics.DrawString($Title, $titleFont, $captionBrush, 70, 28)
        $graphics.DrawString($SceneTitle, $sceneFont, $mutedBrush, 70, 82)

        $targetX = 76
        $targetY = 158
        $targetW = $Width - 152
        $targetH = 710
        $sourceAspect = $source.Width / $source.Height
        $targetAspect = $targetW / $targetH
        if ($sourceAspect -gt $targetAspect) {
            $drawW = $targetW
            $drawH = [int]($targetW / $sourceAspect)
        } else {
            $drawH = $targetH
            $drawW = [int]($targetH * $sourceAspect)
        }
        $drawX = $targetX + [int](($targetW - $drawW) / 2)
        $drawY = $targetY + [int](($targetH - $drawH) / 2)

        $graphics.FillRectangle($panelBrush, $targetX - 10, $targetY - 10, $targetW + 20, $targetH + 20)
        $graphics.DrawRectangle($accentPen, $targetX - 10, $targetY - 10, $targetW + 20, $targetH + 20)
        $graphics.DrawImage($source, $drawX, $drawY, $drawW, $drawH)

        $captionY = 910
        Draw-WrappedText -Graphics $graphics -Text $Caption -Font $captionFont -Brush $captionBrush -X 76 -Y $captionY -MaxWidth ($Width - 152) -LineHeight 48
    } finally {
        $source.Dispose()
        $graphics.Dispose()
        $bitmap.Save($TargetPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
    }
}

Add-Type -AssemblyName System.Drawing

$rows = @(Get-CaptionRows -Directory $framesFullPath)
if ($rows.Count -eq 0) {
    throw "No PNG frames were found in $framesFullPath"
}

$outputDir = Split-Path -Parent $outputFullPath
if (!(Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Force $outputDir | Out-Null
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("dosclaw-qwen-video-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $workDir | Out-Null

try {
    $concatLines = @("ffconcat version 1.0")
    $renderedFrames = @()
    $index = 1
    foreach ($row in $rows) {
        $sourcePath = Join-Path $framesFullPath $row.File
        if (!(Test-Path -LiteralPath $sourcePath)) {
            throw "Missing frame listed in captions: $($row.File)"
        }
        $duration = if ($row.Duration) { [double]$row.Duration } else { $DefaultDuration }
        $caption = if ($row.Caption) { $row.Caption } else { $defaultCaptions[[System.IO.Path]::GetFileNameWithoutExtension($row.File)] }
        $sceneTitle = [System.IO.Path]::GetFileNameWithoutExtension($row.File) -replace "^\d+-", "" -replace "-", " "
        $targetPath = Join-Path $workDir ("frame-{0:D2}.png" -f $index)
        Render-Frame -SourcePath $sourcePath -TargetPath $targetPath -Caption $caption -SceneTitle $sceneTitle
        $renderedFrames += @{ Path = $targetPath; Duration = $duration }
        $index += 1
    }

    foreach ($frame in $renderedFrames) {
        $path = $frame.Path.Replace("\", "/")
        $concatLines += "file '$path'"
        $concatLines += "duration $($frame.Duration)"
    }
    $lastPath = $renderedFrames[-1].Path.Replace("\", "/")
    $concatLines += "file '$lastPath'"

    $concatPath = Join-Path $workDir "frames.ffconcat"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($concatPath, ($concatLines -join [Environment]::NewLine), $utf8NoBom)

    & ffmpeg -y -hide_banner -loglevel error -f concat -safe 0 -i $concatPath -vf "fps=30,format=yuv420p" -movflags +faststart $outputFullPath
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg failed with exit code $LASTEXITCODE"
    }
    Write-Host "DOSClaw-Qwen demo video written to $outputFullPath"
} finally {
    if (Test-Path -LiteralPath $workDir) {
        Remove-Item -LiteralPath $workDir -Recurse -Force
    }
}
