param(
    [string]$Region = "ap-southeast-1",
    [ValidateSet("ManagedContainer", "EcsReadOnly")]
    [string]$Mode = "ManagedContainer",
    [string]$OutputPath = $null
)

$ErrorActionPreference = "Continue"
$PSNativeCommandUseErrorActionPreference = $false

$checks = @(
    @{
        Name = "Caller identity"
        Command = @("sts", "GetCallerIdentity")
        Required = $true
    }
)

if ($Mode -eq "ManagedContainer") {
    $checks += @(
        @{
            Name = "Container Registry access"
            Command = @("cr", "ListInstance", "--region", $Region)
            Required = $true
        },
        @{
            Name = "Function Compute access"
            Command = @("fc-open", "ListServices", "--region", $Region)
            Required = $false
        },
        @{
            Name = "Elastic Container Instance access"
            Command = @("eci", "ListUsage", "--region", $Region)
            Required = $false
        }
    )
} else {
    $checks += @(
        @{
            Name = "ECS instance read access"
            Command = @("ecs", "DescribeInstances", "--RegionId", $Region, "--PageSize", "10")
            Required = $true
        },
        @{
            Name = "VPC read access"
            Command = @("vpc", "DescribeVpcs", "--RegionId", $Region, "--PageSize", "10")
            Required = $false
        }
    )
}

$failedRequired = $false
$runtimeAvailable = $false
$results = [ordered]@{
    checkedAt = (Get-Date).ToUniversalTime().ToString("o")
    region = $Region
    mode = $Mode
    passed = $false
    failure = $null
    checks = @()
}

function Get-FirstRegexGroup {
    param(
        [string]$Text,
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success) {
            return $match.Groups[1].Value.Trim()
        }
    }

    return $null
}

function Get-SanitizedErrorSummary {
    param([string]$Text)

    return [ordered]@{
        errorCode = Get-FirstRegexGroup $Text @('"Code"\s*:\s*"([^"]+)"', 'ErrorCode:\s*([^\r\n]+)')
        authAction = Get-FirstRegexGroup $Text @('AuthAction:([A-Za-z0-9:\*]+)', '"AuthAction"\s*:\s*"([^"]+)"')
        noPermissionType = Get-FirstRegexGroup $Text @('NoPermissionType:([A-Za-z0-9]+)', '"NoPermissionType"\s*:\s*"([^"]+)"')
    }
}

function Write-PreflightEvidence {
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        return
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
    Write-Host "Alibaba Cloud preflight evidence written to $outputFullPath"
}

foreach ($check in $checks) {
    Write-Host "Checking $($check.Name)..."
    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    $process = Start-Process `
        -FilePath "aliyun" `
        -ArgumentList $check.Command `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath
    $exitCode = $process.ExitCode
    $output = @(
        Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
        Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
    )
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

    $joinedOutput = ($output | Out-String)
    $looksDenied = $joinedOutput -match "AccessDenied|Unauthorized|AUTHENTICATION_FAILED|Forbidden\.Unauthorized|ImplicitDeny"
    $summary = Get-SanitizedErrorSummary $joinedOutput

    if ($exitCode -eq 0 -and !$looksDenied) {
        Write-Host "OK: $($check.Name)"
        $results.checks += [ordered]@{
            name = $check.Name
            required = [bool]$check.Required
            command = "aliyun " + ($check.Command -join " ")
            ok = $true
            exitCode = $exitCode
            errorCode = $null
            authAction = $null
            noPermissionType = $null
        }
        if (!$check.Required -and ($check.Name -like "*Function Compute*" -or $check.Name -like "*Elastic Container Instance*")) {
            $runtimeAvailable = $true
        }
        continue
    }

    Write-Host "DENIED: $($check.Name)"
    Write-Host $joinedOutput
    $results.checks += [ordered]@{
        name = $check.Name
        required = [bool]$check.Required
        command = "aliyun " + ($check.Command -join " ")
        ok = $false
        exitCode = $exitCode
        errorCode = $summary.errorCode
        authAction = $summary.authAction
        noPermissionType = $summary.noPermissionType
    }
    if ($check.Required) {
        $failedRequired = $true
    }
}

if ($failedRequired -and $Mode -eq "ManagedContainer") {
    $results.failure = "Container Registry access is required before pushing the DOSClaw-Qwen image."
    Write-PreflightEvidence
    throw "Alibaba Cloud preflight failed: $($results.failure)"
}

if ($failedRequired) {
    $results.failure = "ECS read access is required for this preflight mode, or deploy to a known ECS host with scripts/deploy-ecs-ssh.ps1."
    Write-PreflightEvidence
    throw "Alibaba Cloud preflight failed: $($results.failure)"
}

if ($Mode -eq "ManagedContainer" -and !$runtimeAvailable) {
    $results.failure = "Grant either Function Compute or Elastic Container Instance permissions before creating the public runtime."
    Write-PreflightEvidence
    throw "Alibaba Cloud preflight failed: $($results.failure)"
}

$results.passed = $true
Write-PreflightEvidence
Write-Host "Alibaba Cloud preflight passed for region $Region."
