param(
    [string]$Region = "ap-southeast-1",
    [ValidateSet("ManagedContainer", "EcsReadOnly")]
    [string]$Mode = "ManagedContainer"
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

    if ($exitCode -eq 0 -and !$looksDenied) {
        Write-Host "OK: $($check.Name)"
        if (!$check.Required -and ($check.Name -like "*Function Compute*" -or $check.Name -like "*Elastic Container Instance*")) {
            $runtimeAvailable = $true
        }
        continue
    }

    Write-Host "DENIED: $($check.Name)"
    Write-Host $joinedOutput
    if ($check.Required) {
        $failedRequired = $true
    }
}

if ($failedRequired -and $Mode -eq "ManagedContainer") {
    throw "Alibaba Cloud preflight failed: Container Registry access is required before pushing the DOSClaw-Qwen image."
}

if ($failedRequired) {
    throw "Alibaba Cloud preflight failed: ECS read access is required for this preflight mode, or deploy to a known ECS host with scripts/deploy-ecs-ssh.ps1."
}

if ($Mode -eq "ManagedContainer" -and !$runtimeAvailable) {
    throw "Alibaba Cloud preflight failed: grant either Function Compute or Elastic Container Instance permissions before creating the public runtime."
}

Write-Host "Alibaba Cloud preflight passed for region $Region."
