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
    runtime = $null
    customers = @()
    chat = $null
    scenarios = [ordered]@{}
}

function ConvertFrom-NdjsonResponse {
    param([object]$Response)

    $raw = [System.Text.Encoding]::UTF8.GetString($Response.RawContentStream.ToArray())
    return @($raw -split "`n" | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object { $_ | ConvertFrom-Json })
}

function Invoke-ChatScenario {
    param(
        [string]$Name,
        [string]$CustomerId,
        [string]$Message
    )

    $body = @{
        customer_id = $CustomerId
        message = $Message
    } | ConvertTo-Json
    $response = Invoke-WebRequest -Uri "$BaseUrl/api/chat" -Method Post -ContentType "application/json" -Body $body -UseBasicParsing
    $events = ConvertFrom-NdjsonResponse -Response $response
    if ($response.StatusCode -ne 200) {
        throw "$Name failed with HTTP $($response.StatusCode)"
    }
    if (!($events | Where-Object { $_.kind -eq "memory" })) {
        throw "$Name missing memory event"
    }
    if (!($events | Where-Object { $_.kind -eq "model_info" })) {
        throw "$Name missing model_info event"
    }
    if (!($events | Where-Object { $_.kind -in @("message", "message_delta") })) {
        throw "$Name missing reply event"
    }

    $reply = (($events | Where-Object { $_.kind -eq "message" } | Select-Object -Last 1).text)
    if ([string]::IsNullOrWhiteSpace($reply)) {
        $reply = (($events | Where-Object { $_.kind -eq "message_delta" } | ForEach-Object { $_.text }) -join "")
    }
    return [ordered]@{
        customerId = $CustomerId
        message = $Message
        events = $events
        memory = (($events | Where-Object { $_.kind -eq "memory" } | Select-Object -Last 1).text)
        tools = @($events | Where-Object { $_.kind -eq "tool_info" } | ForEach-Object { $_.text })
        reply = $reply
    }
}

Write-Host "Checking DOSClaw-Qwen at $BaseUrl..."
$health = Invoke-RestMethod -Uri "$BaseUrl/api/health"
if (!$health.ok -or $health.service -ne "dosclaw-qwen") {
    throw "Unexpected health response: $($health | ConvertTo-Json -Depth 10)"
}
$results.health = $health

$runtime = Invoke-RestMethod -Uri "$BaseUrl/api/runtime"
if ($runtime.service -ne "dosclaw-qwen" -or !$runtime.chat_model -or $runtime.memory_engine -ne "Mem0Middleware") {
    throw "Unexpected runtime response: $($runtime | ConvertTo-Json -Depth 10)"
}
$results.runtime = $runtime

$customers = Invoke-RestMethod -Uri "$BaseUrl/api/customers"
if (!$customers -or $customers.Count -lt 2) {
    throw "Expected at least two demo customers: $($customers | ConvertTo-Json -Depth 10)"
}
$results.customers = $customers

if (!$SkipLiveChat) {
    Write-Host "Checking live judge scenarios..."

    $returning = Invoke-ChatScenario -Name "returning-customer-memory" -CustomerId "cust_a" -Message "I'm lactose intolerant. What do you recommend?"
    if ($returning.memory -notmatch "lactose|oat|Linh") {
        throw "Returning customer memory did not surface seeded profile: $($returning.memory)"
    }
    $results.scenarios.returningCustomerMemory = $returning
    $results.chat = $returning.events

    $isolation = Invoke-ChatScenario -Name "multi-customer-isolation" -CustomerId "cust_b" -Message "Do you remember my usual drink?"
    if ($isolation.memory -match "Linh|lactose|oat milk latte|almond croissant") {
        throw "Customer B leaked Customer A memory: $($isolation.memory)"
    }
    $results.scenarios.multiCustomerIsolation = $isolation

    $teach = Invoke-ChatScenario -Name "customer-b-teach-profile" -CustomerId "cust_b" -Message "I'm JOY, 18 YO"
    if ($teach.memory -notmatch "Name: JOY" -or $teach.memory -notmatch "Age: 18") {
        throw "Customer B profile was not updated with JOY/18: $($teach.memory)"
    }
    $results.scenarios.customerBTeachProfile = $teach

    $recall = Invoke-ChatScenario -Name "customer-b-recall-profile" -CustomerId "cust_b" -Message "What's my name?"
    if ($recall.memory -notmatch "Name: JOY" -or $recall.reply -notmatch "JOY") {
        throw "Customer B recall failed. Memory=$($recall.memory) Reply=$($recall.reply)"
    }
    $results.scenarios.customerBRecallProfile = $recall

    $knowledge = Invoke-ChatScenario -Name "knowledge-grounded-answer" -CustomerId "cust_b" -Message "What is your refund policy for coffee beans?"
    if ($knowledge.reply -notmatch "refund|human|teammate|review") {
        throw "Knowledge scenario did not answer with the policy shape: $($knowledge.reply)"
    }
    $results.scenarios.knowledgeGroundedAnswer = $knowledge

    $handoff = Invoke-ChatScenario -Name "human-handoff" -CustomerId "cust_b" -Message "My order was wrong twice. I want a refund and a staff member to review this."
    if ($handoff.reply -notmatch "ticket #[0-9]+" -or (($handoff.tools -join "`n") -notmatch "human_handoff")) {
        throw "Handoff scenario did not create a visible ticket/tool event. Tools=$($handoff.tools -join ', ') Reply=$($handoff.reply)"
    }
    $results.scenarios.humanHandoff = $handoff
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
