param(
    [switch]$Once,
    [switch]$DumpLimitEvents,
    [int]$DumpLimitEventCount = 40,
    [int]$MaxSessionTabs = 5,
    [int]$RefreshSeconds = 1,
    [string]$CodexHome = (Join-Path $env:USERPROFILE ".codex")
)

Set-StrictMode -Version Latest

$script:Sample = @{
    SessionPath = $null
    SessionScan = [datetime]::MinValue
    LastPath = $null
    LastLength = 0L
    LastLengthTime = Get-Date
    LastTokenTotal = $null
    LastTokenTime = Get-Date
    ProcessCpu = @{}
    ProcessTime = Get-Date
    MetaPath = $null
    Meta = $null
    TokenHistory = New-Object 'System.Collections.Generic.List[double]'
    EventHistory = New-Object 'System.Collections.Generic.List[double]'
    ProcessHistory = New-Object 'System.Collections.Generic.List[double]'
    SpeedHistory = New-Object 'System.Collections.Generic.List[double]'
    ContextHistory = New-Object 'System.Collections.Generic.List[double]'
    PrimaryRemainingHistory = New-Object 'System.Collections.Generic.List[double]'
    SecondaryRemainingHistory = New-Object 'System.Collections.Generic.List[double]'
    ProfileCache = @{}
    SessionUsageCache = @{}
    SessionPromptUseCache = @{}
    SessionMetricsCache = @{}
    SessionKeyCache = @{}
    SessionLabelCache = @{}
    TokenGraphValue = 0.0
    EventGraphValue = 0.0
    ProcessGraphValue = 0.0
    SpeedScale = 12000.0
    SpeedScalePerSecond = 120.0
    SpeedMaxTokPerSecond = 0.0
    SpeedScaleLastDropAt = [datetime]::MinValue
    UseScaleLastDropAt = [datetime]::MinValue
    ActiveSessionId = $null
    SessionSwitchedAt = [datetime]::MinValue
    LastTabRefresh = [datetime]::MinValue
    SessionTabSignature = $null
    CandidateFiles = @()
    CandidateScan = [datetime]::MinValue
    PinnedSessionPath = $null
    TabRebuilding = $false
    TabPinnedByUser = $false
    Updating = $false
    DarkMode = $true
    MiniMode = $false
    ClickThrough = $false
    AlwaysOnTop = $true
    WindowOpacity = 100
    CostFlashOn = $false
    LayoutBusy = $false
    DetailsOpen = $false
    CurrentSnapshot = $null
    BenchmarkRuns = @()
    BenchmarkArmed = $false
    BenchmarkStatus = "idle"
    BenchmarkSessionPath = $null
    BenchmarkArmedAt = [datetime]::MinValue
    BenchmarkRunStartedAt = [datetime]::MinValue
    BenchmarkBaseline = $null
    BenchmarkPromptText = $null
    BenchmarkLastExportPath = $null
    SessionUseResetBaselines = @{}
    UsageForecastSamples = @()
    LongContextNoticeKey = $null
    LongContextNoticeAt = [datetime]::MinValue
    LastCrashSignature = $null
    LastCrashLoggedAt = [datetime]::MinValue
}

$script:LongContextInputThreshold = 272000.0
$script:LongContextYellowThreshold = 200000.0
$script:LongContextRedThreshold = 230000.0
$script:LongContextHardStopThreshold = 240000.0
$script:CostWeightInput = 1.0
$script:CostWeightCachedInput = 0.1
$script:CostWeightOutput = 6.0
$script:CostWeightReasoning = 8.0
$script:ModelPricing = @{
    "gpt-5.6-sol" = @{ Label = "GPT-5.6 Sol"; Input = 5.0; CachedInput = 0.5; CacheWrite = 6.25; Output = 30.0; LongInput = 10.0; LongCachedInput = 1.0; LongCacheWrite = 12.5; LongOutput = 45.0 }
    "gpt-5.6-terra" = @{ Label = "GPT-5.6 Terra"; Input = 2.5; CachedInput = 0.25; CacheWrite = 3.125; Output = 15.0; LongInput = 5.0; LongCachedInput = 0.5; LongCacheWrite = 6.25; LongOutput = 22.5 }
    "gpt-5.6-luna" = @{ Label = "GPT-5.6 Luna"; Input = 1.0; CachedInput = 0.1; CacheWrite = 1.25; Output = 6.0; LongInput = 2.0; LongCachedInput = 0.2; LongCacheWrite = 2.5; LongOutput = 9.0 }
    "gpt-5.5" = @{ Label = "GPT-5.5"; Input = 5.0; CachedInput = 0.5; CacheWrite = $null; Output = 30.0; LongInput = 10.0; LongCachedInput = 1.0; LongCacheWrite = $null; LongOutput = 45.0 }
    "gpt-5.5-pro" = @{ Label = "GPT-5.5 Pro"; Input = 30.0; CachedInput = $null; CacheWrite = $null; Output = 180.0; LongInput = 60.0; LongCachedInput = $null; LongCacheWrite = $null; LongOutput = 270.0 }
    "gpt-5.4" = @{ Label = "GPT-5.4"; Input = 2.5; CachedInput = 0.25; CacheWrite = $null; Output = 15.0; LongInput = 5.0; LongCachedInput = 0.5; LongCacheWrite = $null; LongOutput = 22.5 }
    "gpt-5.4-mini" = @{ Label = "GPT-5.4 Mini"; Input = 0.75; CachedInput = 0.075; CacheWrite = $null; Output = 4.5; LongInput = $null; LongCachedInput = $null; LongCacheWrite = $null; LongOutput = $null }
    "gpt-5.4-pro" = @{ Label = "GPT-5.4 Pro"; Input = 30.0; CachedInput = $null; CacheWrite = $null; Output = 180.0; LongInput = 60.0; LongCachedInput = $null; LongCacheWrite = $null; LongOutput = 270.0 }
}
$script:BuddyRoot = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_BUDDY_ROOT)) { $env:CODEX_BUDDY_ROOT } elseif ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }
$script:CrashLogPath = Join-Path $script:BuddyRoot "CodexBuddy.crash.log"
$script:LongContextAlertPath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "CodexBuddy\long-context-alerts.json"
$script:LongContextAlerts = @{}
$script:BenchmarkDataPath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "CodexBuddy\benchmarks.json"
$script:BenchmarkExportDirectory = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Codex Buddy\Benchmarks"
$script:SessionUseResetPath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "CodexBuddy\session-use-resets.json"
$script:UsageForecastPath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "CodexBuddy\usage-forecast.json"

function Write-BuddyCrashLog {
    param($ErrorRecord)

    try {
        $message = if ($ErrorRecord -and $ErrorRecord.Exception) { $ErrorRecord.Exception.ToString() } elseif ($ErrorRecord) { [string]$ErrorRecord } else { "Unknown error" }
        $now = Get-Date
        if (($message -eq $script:Sample.LastCrashSignature) -and (($now - $script:Sample.LastCrashLoggedAt).TotalSeconds -lt 30)) {
            return
        }

        if (Test-Path -LiteralPath $script:CrashLogPath) {
            $crashLog = Get-Item -LiteralPath $script:CrashLogPath -ErrorAction SilentlyContinue
            if ($crashLog -and $crashLog.Length -gt 4MB) {
                [System.IO.File]::WriteAllText($script:CrashLogPath, ("[{0}] Crash log compacted after reaching 4 MB.`r`n" -f $now.ToString("s")))
            }
        }

        $entry = "[{0}] {1}`r`n" -f (Get-Date).ToString("s"), $message
        Add-Content -LiteralPath $script:CrashLogPath -Value $entry -ErrorAction SilentlyContinue
        $script:Sample.LastCrashSignature = $message
        $script:Sample.LastCrashLoggedAt = $now
    } catch {}
}

function Limit-BuddyCrashLog {
    try {
        if ((Test-Path -LiteralPath $script:CrashLogPath) -and ((Get-Item -LiteralPath $script:CrashLogPath -ErrorAction Stop).Length -gt 4MB)) {
            [System.IO.File]::WriteAllText($script:CrashLogPath, ("[{0}] Crash log compacted at startup after reaching 4 MB.`r`n" -f (Get-Date).ToString("s")))
        }
    } catch {}
}

Limit-BuddyCrashLog

function Get-LatestSessionPath {
    param(
        [string]$Root,
        [hashtable]$State
    )

    $now = Get-Date
    if ($State.SessionPath -and (Test-Path -LiteralPath $State.SessionPath) -and (($now - $State.SessionScan).TotalSeconds -lt 2)) {
        return $State.SessionPath
    }

    $sessionRoot = Join-Path $Root "sessions"
    if (-not (Test-Path -LiteralPath $sessionRoot)) {
        return $null
    }

    $latest = Get-SessionCandidateFiles -Root $Root -State $State |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    $State.SessionScan = $now
    $State.SessionPath = if ($latest) { $latest.FullName } else { $null }
    return $State.SessionPath
}

function Convert-FromJsonLine {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $null
    }

    try {
        return $Line | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
}

function Get-FileTailLines {
    param(
        [string]$Path,
        [int]$LineCount = 240
    )

    if ($LineCount -le 0) {
        return @()
    }

    $stream = $null
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
        if ($stream.Length -le 0) {
            return @()
        }

        $chunkSize = 262144
        $buffer = New-Object byte[] $chunkSize
        $chunks = New-Object 'System.Collections.Generic.List[byte[]]'
        $position = [int64]$stream.Length
        $lineBreaks = 0

        while ($position -gt 0 -and $lineBreaks -le $LineCount) {
            $readSize = [int][Math]::Min($chunkSize, $position)
            $position -= $readSize
            [void]$stream.Seek($position, [System.IO.SeekOrigin]::Begin)
            $read = $stream.Read($buffer, 0, $readSize)
            if ($read -le 0) {
                break
            }

            $chunk = New-Object byte[] $read
            [Array]::Copy($buffer, 0, $chunk, 0, $read)
            $chunks.Add($chunk)
            for ($i = 0; $i -lt $read; $i++) {
                if ($chunk[$i] -eq 10) {
                    $lineBreaks++
                }
            }
        }

        $totalBytes = 0
        foreach ($chunk in $chunks) {
            $totalBytes += $chunk.Length
        }
        if ($totalBytes -le 0) {
            return @()
        }

        $tailBytes = New-Object byte[] $totalBytes
        $offset = 0
        for ($i = $chunks.Count - 1; $i -ge 0; $i--) {
            $chunk = $chunks[$i]
            [Array]::Copy($chunk, 0, $tailBytes, $offset, $chunk.Length)
            $offset += $chunk.Length
        }

        $lines = @([System.Text.Encoding]::UTF8.GetString($tailBytes) -split "\r?\n")
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq "") {
            if ($lines.Count -eq 1) {
                return @()
            }
            $lines = @($lines[0..($lines.Count - 2)])
        }

        return @($lines | Select-Object -Last $LineCount)
    } finally {
        if ($stream) {
            $stream.Dispose()
        }
    }
}

function Format-Number {
    param([nullable[double]]$Value)

    if ($null -eq $Value) {
        return "n/a"
    }

    if ($Value -ge 1000000) {
        return ("{0:N1}m" -f ($Value / 1000000))
    }

    if ($Value -ge 1000) {
        return ("{0:N1}k" -f ($Value / 1000))
    }

    return ("{0:N0}" -f $Value)
}

function Format-ToolTipText {
    param(
        [string]$Text,
        [int]$Width = 84
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $words = ([regex]::Replace($Text, '\s+', ' ')).Trim().Split(' ')
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $line = ""
    foreach ($word in $words) {
        if ([string]::IsNullOrWhiteSpace($word)) {
            continue
        }
        if ($line.Length -eq 0) {
            $line = $word
        } elseif (($line.Length + 1 + $word.Length) -le $Width) {
            $line = "$line $word"
        } else {
            $lines.Add($line)
            $line = $word
        }
    }
    if ($line.Length -gt 0) {
        $lines.Add($line)
    }

    return [string]::Join([Environment]::NewLine, $lines)
}

function Set-BuddyToolTip {
    param(
        [System.Windows.Forms.ToolTip]$Tip,
        [System.Windows.Forms.Control]$Control,
        [string]$Text,
        [int]$Width = 84
    )

    $Tip.SetToolTip($Control, (Format-ToolTipText -Text $Text -Width $Width))
}

function Format-TokenUse {
    param(
        [nullable[double]]$Total,
        [nullable[double]]$InputTokens,
        [nullable[double]]$OutputTokens = $null
    )

    if ($null -eq $Total -and $null -eq $InputTokens -and $null -eq $OutputTokens) {
        return "n/a"
    }

    if ($null -ne $OutputTokens) {
        return ("{0} total / {1} in / {2} out" -f (Format-Number $Total), (Format-Number $InputTokens), (Format-Number $OutputTokens))
    }

    return ("{0} total / {1} in" -f (Format-Number $Total), (Format-Number $InputTokens))
}

function Convert-ToNullableDouble {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [array]) {
        foreach ($item in $Value) {
            $converted = Convert-ToNullableDouble $item
            if ($null -ne $converted) {
                return $converted
            }
        }
        return $null
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($item in $Value) {
            $converted = Convert-ToNullableDouble $item
            if ($null -ne $converted) {
                return $converted
            }
        }
        return $null
    }

    try {
        return [double]$Value
    } catch {
        return $null
    }
}

function Format-CostUnits {
    param($Value)

    $number = Convert-ToNullableDouble $Value
    if ($null -eq $number) {
        return "n/a"
    }

    return ("{0} cost units" -f (Format-Number $number))
}

function Format-BurnScore {
    param(
        $CostUnits,
        $CostUnitsPerOnePercent = $null
    )

    $costNumber = Convert-ToNullableDouble $CostUnits
    $scaleNumber = Convert-ToNullableDouble $CostUnitsPerOnePercent
    if ($null -eq $costNumber) {
        return "n/a"
    }

    $scale = if ($null -ne $scaleNumber -and $scaleNumber -gt 0) { $scaleNumber / 100.0 } else { 1000.0 }
    $score = $costNumber / $scale
    if ($score -lt 10) {
        return ("{0:N2}" -f $score)
    }

    return ("{0:N1}" -f $score)
}

function Format-ApiCostEstimate {
    param(
        $CostUnits,
        [string]$Model
    )

    $costNumber = Convert-ToNullableDouble $CostUnits
    if ($null -eq $costNumber -or -not (Get-ModelPricing -Model $Model)) {
        return "n/a"
    }

    return ('~${0:0.0000}' -f ($costNumber / 1000000.0))
}

function Get-PromptCostHistoryText {
    param(
        $Session,
        $CostUnitsPerOnePercent = $null
    )

    $rows = if ($Session -and $Session.RecentPromptCosts) { @($Session.RecentPromptCosts) } else { @() }
    if ($rows.Count -eq 0) {
        return "  Last 5 prompts: waiting for completed prompt data."
    }

    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add("  Last 5 prompts (newest first)")
    $fallbackNumber = 0
    foreach ($row in $rows) {
        $fallbackNumber++
        $promptNumber = if ($null -ne $row.PromptNumber) { $row.PromptNumber } else { $fallbackNumber }
        $model = if ($row.Model) { Shorten-Model $row.Model } else { "unknown model" }
        $cost = Format-BurnScore -CostUnits $row.CostUnits -CostUnitsPerOnePercent $CostUnitsPerOnePercent
        $apiCost = Format-ApiCostEstimate -CostUnits $row.CostUnits -Model $row.Model
        $inputText = Format-Number $row.InputTokens
        $outputText = Format-Number $row.OutputTokens
        $lines.Add(("    #{0} {1}: {2} pts | API {3} | {4} in / {5} out" -f $promptNumber, $model, $cost, $apiCost, $inputText, $outputText))
    }

    $lines.Add("  API values use configured model rates; this is an estimate, not billing data.")
    return [string]::Join([Environment]::NewLine, $lines)
}

function Normalize-BenchmarkPromptText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    return ([regex]::Replace($Text, '\s+', ' ')).Trim()
}

function Get-BenchmarkPromptFingerprint {
    param([string]$Text)

    $normalized = Normalize-BenchmarkPromptText $Text
    if ($normalized.Length -eq 0) {
        return "unknown"
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').Substring(0, 16).ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Import-BenchmarkRuns {
    if (-not (Test-Path -LiteralPath $script:BenchmarkDataPath)) {
        return
    }

    try {
        $json = Get-Content -LiteralPath $script:BenchmarkDataPath -Raw -ErrorAction Stop
        if (-not [string]::IsNullOrWhiteSpace($json)) {
            $loaded = $json | ConvertFrom-Json
            if ($loaded -and $loaded.PSObject.Properties["value"] -and $loaded.PSObject.Properties["Count"]) {
                $script:Sample.BenchmarkRuns = @($loaded.value)
                Save-BenchmarkRuns
            } else {
                $script:Sample.BenchmarkRuns = @($loaded)
            }
        }
    } catch {
        Write-BuddyCrashLog $_
    }
}

function Save-BenchmarkRuns {
    try {
        $directory = Split-Path -Parent $script:BenchmarkDataPath
        [void][System.IO.Directory]::CreateDirectory($directory)
        $json = ConvertTo-Json -InputObject @($script:Sample.BenchmarkRuns) -Depth 8
        [System.IO.File]::WriteAllText($script:BenchmarkDataPath, $json)
    } catch {
        Write-BuddyCrashLog $_
    }
}

function Import-SessionUseResetBaselines {
    if (-not (Test-Path -LiteralPath $script:SessionUseResetPath)) {
        return
    }

    try {
        $json = Get-Content -LiteralPath $script:SessionUseResetPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($json)) {
            return
        }

        $loaded = $json | ConvertFrom-Json
        $baselines = @{}
        foreach ($property in $loaded.PSObject.Properties) {
            $baselines[[string]$property.Name] = $property.Value
        }
        $script:Sample.SessionUseResetBaselines = $baselines
    } catch {
        Write-BuddyCrashLog $_
    }
}

function Save-SessionUseResetBaselines {
    try {
        $directory = Split-Path -Parent $script:SessionUseResetPath
        [void][System.IO.Directory]::CreateDirectory($directory)
        $json = $script:Sample.SessionUseResetBaselines | ConvertTo-Json -Depth 6
        [System.IO.File]::WriteAllText($script:SessionUseResetPath, $json)
    } catch {
        Write-BuddyCrashLog $_
    }
}

function Import-UsageForecastSamples {
    if (-not (Test-Path -LiteralPath $script:UsageForecastPath)) {
        return
    }

    try {
        $json = Get-Content -LiteralPath $script:UsageForecastPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($json)) {
            return
        }

        $loaded = @($json | ConvertFrom-Json)
        $cutoff = (Get-Date).ToUniversalTime().AddDays(-16)
        $samples = New-Object System.Collections.Generic.List[object]
        foreach ($row in $loaded) {
            $sampledAt = $null
            $usedPercent = Convert-ToNullableDouble (Get-JsonValue -Object $row -Name "UsedPercent")
            try { $sampledAt = ([datetime](Get-JsonValue -Object $row -Name "SampledAt")).ToUniversalTime() } catch {}
            if (-not $sampledAt -or $sampledAt -lt $cutoff -or $null -eq $usedPercent -or $usedPercent -lt 0 -or $usedPercent -gt 100) {
                continue
            }
            $samples.Add([pscustomobject]@{
                Key = [string](Get-JsonValue -Object $row -Name "Key")
                SampledAt = $sampledAt.ToString("o")
                UsedPercent = [Math]::Round([double]$usedPercent, 3)
            })
        }
        $script:Sample.UsageForecastSamples = @($samples | Sort-Object SampledAt | Select-Object -Last 3000)
    } catch {
        Write-BuddyCrashLog $_
    }
}

function Save-UsageForecastSamples {
    try {
        $directory = Split-Path -Parent $script:UsageForecastPath
        [void][System.IO.Directory]::CreateDirectory($directory)
        $json = ConvertTo-Json -InputObject @($script:Sample.UsageForecastSamples) -Depth 4
        [System.IO.File]::WriteAllText($script:UsageForecastPath, $json)
    } catch {
        Write-BuddyCrashLog $_
    }
}

function Get-UsageForecast {
    param($Session)

    if (-not $Session) {
        return [pscustomobject]@{ Status = "unavailable"; Text = "usage forecast unavailable"; SampleCount = 0; CoverageMinutes = 0; RatePercentPerHour = $null; ExhaustionAt = $null }
    }

    $usedPercent = Convert-ToNullableDouble (Get-JsonValue -Object $Session -Name "WeeklyUsedPercent")
    $remainingPercent = Convert-ToNullableDouble (Get-JsonValue -Object $Session -Name "WeeklyRemainingPercent")
    $windowMinutes = Convert-ToNullableDouble (Get-JsonValue -Object $Session -Name "WeeklyWindowMinutes")
    $resetAt = Get-JsonValue -Object $Session -Name "WeeklyResetAt"
    if ($null -eq $usedPercent) {
        $usedPercent = Convert-ToNullableDouble (Get-JsonValue -Object $Session -Name "PrimaryUsedPercent")
        $remainingPercent = Convert-ToNullableDouble (Get-JsonValue -Object $Session -Name "PrimaryRemainingPercent")
        $windowMinutes = Convert-ToNullableDouble (Get-JsonValue -Object $Session -Name "PrimaryWindowMinutes")
        $resetAt = Get-JsonValue -Object $Session -Name "PrimaryResetAt"
    }

    $reset = $null
    try { if ($resetAt) { $reset = ([datetime]$resetAt).ToUniversalTime() } } catch {}
    if ($null -eq $usedPercent -or $null -eq $remainingPercent -or -not $reset -or $reset -le (Get-Date).ToUniversalTime()) {
        return [pscustomobject]@{ Status = "unavailable"; Text = "waiting for a resettable usage limit"; SampleCount = 0; CoverageMinutes = 0; RatePercentPerHour = $null; ExhaustionAt = $null }
    }

    $key = "{0}|{1}|{2}|{3}" -f ([string]$Session.UsageProfileKey), ([string]$Session.LimitId), ([int]$windowMinutes), $reset.ToString("o")
    $now = (Get-Date).ToUniversalTime()
    $matching = @($script:Sample.UsageForecastSamples | Where-Object { $_.Key -eq $key } | Sort-Object SampledAt)
    $last = if ($matching.Count -gt 0) { $matching[$matching.Count - 1] } else { $null }
    $lastAt = $null
    try { if ($last) { $lastAt = ([datetime]$last.SampledAt).ToUniversalTime() } } catch {}
    $shouldAdd = (-not $lastAt) -or (($now - $lastAt).TotalMinutes -ge 5) -or (([Math]::Abs([double]$usedPercent - [double]$last.UsedPercent) -ge 0.1) -and (($now - $lastAt).TotalMinutes -ge 1))
    if ($shouldAdd) {
        $script:Sample.UsageForecastSamples = @($script:Sample.UsageForecastSamples | Where-Object {
            $sampleAt = $null
            try { $sampleAt = ([datetime]$_.SampledAt).ToUniversalTime() } catch {}
            $sampleAt -and $sampleAt -ge $now.AddDays(-16)
        }) + [pscustomobject]@{ Key = $key; SampledAt = $now.ToString("o"); UsedPercent = [Math]::Round([double]$usedPercent, 3) }
        $script:Sample.UsageForecastSamples = @($script:Sample.UsageForecastSamples | Sort-Object SampledAt | Select-Object -Last 3000)
        Save-UsageForecastSamples
        $matching = @($script:Sample.UsageForecastSamples | Where-Object { $_.Key -eq $key } | Sort-Object SampledAt)
    }

    if ($matching.Count -lt 2) {
        return [pscustomobject]@{ Status = "learning"; Text = "learning local usage rate"; SampleCount = $matching.Count; CoverageMinutes = 0; RatePercentPerHour = $null; ExhaustionAt = $null }
    }

    $first = $matching[0]
    $last = $matching[$matching.Count - 1]
    $firstAt = ([datetime]$first.SampledAt).ToUniversalTime()
    $lastAt = ([datetime]$last.SampledAt).ToUniversalTime()
    $coverageMinutes = [Math]::Max(0, ($lastAt - $firstAt).TotalMinutes)
    $usedDelta = [double]$last.UsedPercent - [double]$first.UsedPercent
    if ($coverageMinutes -lt 15 -or $usedDelta -le 0) {
        return [pscustomobject]@{ Status = "learning"; Text = "learning local usage rate"; SampleCount = $matching.Count; CoverageMinutes = [Math]::Round($coverageMinutes, 1); RatePercentPerHour = $null; ExhaustionAt = $null }
    }

    $rate = $usedDelta / ($coverageMinutes / 60.0)
    $hoursToLimit = [double]$remainingPercent / $rate
    $exhaustionAt = $now.AddHours($hoursToLimit)
    if ($exhaustionAt -ge $reset) {
        return [pscustomobject]@{ Status = "steady"; Text = "local rate projects remaining usage through reset"; SampleCount = $matching.Count; CoverageMinutes = [Math]::Round($coverageMinutes, 1); RatePercentPerHour = [Math]::Round($rate, 3); ExhaustionAt = $null }
    }

    return [pscustomobject]@{ Status = "projected"; Text = ("local rate projects limit near {0}" -f $exhaustionAt.ToLocalTime().ToString("g")); SampleCount = $matching.Count; CoverageMinutes = [Math]::Round($coverageMinutes, 1); RatePercentPerHour = [Math]::Round($rate, 3); ExhaustionAt = $exhaustionAt.ToLocalTime() }
}

function Get-SessionUseResetKey {
    param($Session)

    if (-not $Session) {
        return $null
    }

    if ($Session.SessionPath -and [string]$Session.SessionPath -ne "__ALL__") {
        return [string]$Session.SessionPath
    }

    if ($Session.SessionId) {
        return [string]$Session.SessionId
    }

    return $null
}

function New-SessionUseResetBaseline {
    param($Session)

    return [pscustomobject]@{
        ResetAt = Get-Date
        SessionPromptCostUnits = Convert-ToNullableDouble $Session.SessionPromptCostUnits
        SessionPromptFastExtraCostUnits = Convert-ToNullableDouble $Session.SessionPromptFastExtraCostUnits
        SessionPromptPrimaryUseDelta = Convert-ToNullableDouble $Session.SessionPromptPrimaryUseDelta
        SessionPromptCount = if ($null -ne $Session.SessionPromptCount) { [int]$Session.SessionPromptCount } else { 0 }
        SessionPromptTokens = Convert-ToNullableDouble $Session.SessionPromptTokens
        SessionPromptInputTokens = Convert-ToNullableDouble $Session.SessionPromptInputTokens
        SessionPromptOutputTokens = Convert-ToNullableDouble $Session.SessionPromptOutputTokens
        SessionPromptCachedInputTokens = Convert-ToNullableDouble $Session.SessionPromptCachedInputTokens
        SessionPromptReasoningTokens = Convert-ToNullableDouble $Session.SessionPromptReasoningTokens
    }
}

function Get-SessionUseSinceReset {
    param($Session)

    $key = Get-SessionUseResetKey -Session $Session
    $baseline = if ($key -and $script:Sample.SessionUseResetBaselines.ContainsKey($key)) { $script:Sample.SessionUseResetBaselines[$key] } else { $null }
    $active = ($null -ne $baseline)

    function Get-DeltaValue {
        param($Current, $Base)
        $currentNumber = Convert-ToNullableDouble $Current
        $baseNumber = Convert-ToNullableDouble $Base
        if ($null -eq $currentNumber) {
            return $null
        }
        if ($null -eq $baseNumber) {
            return $currentNumber
        }
        return [Math]::Max(0.0, $currentNumber - $baseNumber)
    }

    $countBase = if ($baseline -and $null -ne $baseline.SessionPromptCount) { [int]$baseline.SessionPromptCount } else { 0 }
    $countCurrent = if ($null -ne $Session.SessionPromptCount) { [int]$Session.SessionPromptCount } else { 0 }
    $resetAt = if ($baseline -and $baseline.ResetAt) { [datetime]$baseline.ResetAt } else { $null }
    $baseCost = if ($baseline) { $baseline.SessionPromptCostUnits } else { $null }
    $baseFastExtra = if ($baseline) { $baseline.SessionPromptFastExtraCostUnits } else { $null }
    $basePrimaryUse = if ($baseline) { $baseline.SessionPromptPrimaryUseDelta } else { $null }
    $baseTokens = if ($baseline) { $baseline.SessionPromptTokens } else { $null }
    $baseInputTokens = if ($baseline) { $baseline.SessionPromptInputTokens } else { $null }
    $baseOutputTokens = if ($baseline) { $baseline.SessionPromptOutputTokens } else { $null }
    $baseCachedInputTokens = if ($baseline) { $baseline.SessionPromptCachedInputTokens } else { $null }
    $baseReasoningTokens = if ($baseline) { $baseline.SessionPromptReasoningTokens } else { $null }

    return [pscustomobject]@{
        Active = $active
        ResetAt = $resetAt
        CostUnits = Get-DeltaValue $Session.SessionPromptCostUnits $baseCost
        FastExtraCostUnits = Get-DeltaValue $Session.SessionPromptFastExtraCostUnits $baseFastExtra
        PrimaryUseDelta = Get-DeltaValue $Session.SessionPromptPrimaryUseDelta $basePrimaryUse
        PromptCount = [Math]::Max(0, $countCurrent - $countBase)
        Tokens = Get-DeltaValue $Session.SessionPromptTokens $baseTokens
        InputTokens = Get-DeltaValue $Session.SessionPromptInputTokens $baseInputTokens
        OutputTokens = Get-DeltaValue $Session.SessionPromptOutputTokens $baseOutputTokens
        CachedInputTokens = Get-DeltaValue $Session.SessionPromptCachedInputTokens $baseCachedInputTokens
        ReasoningTokens = Get-DeltaValue $Session.SessionPromptReasoningTokens $baseReasoningTokens
    }
}

function Reset-SessionUseCounter {
    $snapshot = $script:Sample.CurrentSnapshot
    $session = if ($snapshot) { $snapshot.Session } else { $null }
    $key = Get-SessionUseResetKey -Session $session
    if (-not $session -or -not $key -or [string]$session.SessionPath -eq "__ALL__") {
        return
    }

    $script:Sample.SessionUseResetBaselines[$key] = New-SessionUseResetBaseline -Session $session
    Save-SessionUseResetBaselines
}

function Get-BenchmarkComparisonText {
    param([array]$Runs)

    $completed = @($Runs | Where-Object { $_.Status -eq "completed" } | Sort-Object RunNumber)
    if ($completed.Count -eq 0) {
        return "  No completed runs yet. Select one conversation and click Bench before sending the test prompt."
    }

    $lines = New-Object 'System.Collections.Generic.List[string]'
    $groups = @($completed | Group-Object PromptFingerprint)
    $lines.Add(("  {0} completed run(s) across {1} task group(s)." -f $completed.Count, $groups.Count))
    foreach ($group in $groups) {
        $first = @($group.Group)[0]
        $task = Normalize-BenchmarkPromptText ([string]$first.PromptPreview)
        if ($task.Length -gt 100) {
            $task = $task.Substring(0, 100) + "..."
        }
        $lines.Add(("  Task {0}: {1}" -f $group.Name, $(if ($task) { $task } else { "prompt text unavailable" })))
        foreach ($run in @($group.Group | Sort-Object RunNumber)) {
            $cost = Format-BurnScore -CostUnits $run.CostUnits -CostUnitsPerOnePercent $run.BurnCostUnitsPerPercent
            $api = Format-ApiCostEstimate -CostUnits $run.CostUnits -Model $run.Model
            $tools = if ($run.ToolsUsed -and @($run.ToolsUsed).Count -gt 0) { [string]::Join(', ', @($run.ToolsUsed)) } else { "none" }
            if ($tools.Length -gt 36) {
                $tools = $tools.Substring(0, 36) + "..."
            }
            $elapsedSeconds = Convert-ToNullableDouble $run.TimeTakenSeconds
            $elapsedText = if ($null -ne $elapsedSeconds) { [Math]::Round($elapsedSeconds, 1) } else { "n/a" }
            $lines.Add(("    #{0} {1} | {2}s | {3}/s | {4} calls | {5} | {6} pts | API {7}" -f $run.RunNumber, (Shorten-Model $run.Model), $elapsedText, (Format-Number (Convert-ToNullableDouble $run.OutputTokensPerSecond)), $run.ToolCalls, $tools, $cost, $api))
        }
    }

    return [string]::Join([Environment]::NewLine, $lines)
}

function Get-BenchmarkReportText {
    param([array]$Runs)

    $completed = @($Runs | Where-Object { $_.Status -eq "completed" } | Sort-Object RunNumber)
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add("# Codex Buddy Benchmark Report")
    $lines.Add("")
    $lines.Add(("Generated: {0}" -f (Get-Date).ToString("s")))
    $lines.Add("")
    $lines.Add("## Side-by-side comparison")
    $lines.Add("")
    $lines.Add('```text')
    foreach ($line in ((Get-BenchmarkComparisonText -Runs $completed) -split "`r?`n")) {
        $lines.Add($line)
    }
    $lines.Add('```')
    $lines.Add("")
    $lines.Add("## Run details")
    $lines.Add("")
    foreach ($run in $completed) {
        $lines.Add(("### Run #{0}: {1}" -f $run.RunNumber, (Shorten-Model $run.Model)))
        $lines.Add(("Task group: {0}" -f $run.PromptFingerprint))
        $lines.Add(("Prompt: {0}" -f $run.PromptPreview))
        $lines.Add(("Started: {0} | completed: {1} | elapsed: {2}s | first token: {3}ms" -f $run.StartedAt, $run.CompletedAt, ([Math]::Round([double]$run.TimeTakenSeconds, 2)), $(if ($null -ne $run.TimeToFirstTokenMs) { $run.TimeToFirstTokenMs } else { "n/a" })))
        $lines.Add(("Tokens: {0} total / {1} input / {2} output / {3} cache-write | output speed: {4}/sec | total speed: {5}/sec" -f (Format-Number $run.TotalTokens), (Format-Number $run.InputTokens), (Format-Number $run.OutputTokens), (Format-Number $run.CacheWriteInputTokens), (Format-Number $run.OutputTokensPerSecond), (Format-Number $run.TotalTokensPerSecond)))
        $lines.Add(("Tools: {0} calls, {1} outputs | used: {2}" -f $run.ToolCalls, $run.ToolOutputs, $(if ($run.ToolsUsed -and @($run.ToolsUsed).Count -gt 0) { [string]::Join(', ', @($run.ToolsUsed)) } else { "none" })))
        $lines.Add(("Cost: {0} points | API estimate: {1} | fast multiplier: {2}x" -f (Format-BurnScore -CostUnits $run.CostUnits -CostUnitsPerOnePercent $run.BurnCostUnitsPerPercent), (Format-ApiCostEstimate -CostUnits $run.CostUnits -Model $run.Model), $run.FastMultiplier))
        $lines.Add(("Context: {0}% | 5-hour delta: {1} | service tier: {2}" -f $run.ContextPercent, $run.PrimaryUseDelta, $run.ServiceTier))
        $lines.Add("")
    }

    return [string]::Join([Environment]::NewLine, $lines)
}

function Export-BenchmarkReport {
    $completed = @($script:Sample.BenchmarkRuns | Where-Object { $_.Status -eq "completed" })
    if ($completed.Count -eq 0) {
        return $null
    }

    try {
        [void][System.IO.Directory]::CreateDirectory($script:BenchmarkExportDirectory)
        $path = Join-Path $script:BenchmarkExportDirectory ("benchmark-report-{0}.md" -f (Get-Date).ToString("yyyyMMdd-HHmmss"))
        [System.IO.File]::WriteAllText($path, (Get-BenchmarkReportText -Runs $completed))
        $script:Sample.BenchmarkLastExportPath = $path
        if ($detailsForm) {
            [void][System.Windows.Forms.MessageBox]::Show(("Benchmark report saved to:`r`n{0}" -f $path), "Codex Buddy benchmarks", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        return $path
    } catch {
        Write-BuddyCrashLog $_
        return $null
    }
}

function New-BenchmarkBaseline {
    param($Session)

    $toolCounts = @{}
    if ($Session.ToolNameCounts) {
        foreach ($name in $Session.ToolNameCounts.Keys) {
            $toolCounts[[string]$name] = [int]$Session.ToolNameCounts[$name]
        }
    }

    return [pscustomobject]@{
        UserMessages = [int]$Session.UserMessages
        ToolCalls = [int]$Session.ToolCalls
        ToolOutputs = [int]$Session.ToolOutputs
        AssistantMessages = [int]$Session.AssistantMessages
        ParsedEventCount = [int]$Session.ParsedEventCount
        LastTaskCompleteAt = $Session.LastTaskCompleteAt
        ToolNameCounts = $toolCounts
    }
}

function New-BenchmarkRun {
    param(
        $Session,
        $Baseline,
        [datetime]$StartedAt,
        [datetime]$CompletedAt
    )

    $reportedDurationMs = Convert-ToNullableDouble $Session.LastTaskDurationMs
    $elapsed = if ($null -ne $reportedDurationMs -and $reportedDurationMs -gt 0) { [Math]::Max(0.001, $reportedDurationMs / 1000.0) } else { [Math]::Max(0.001, ($CompletedAt - $StartedAt).TotalSeconds) }
    $promptText = Normalize-BenchmarkPromptText ([string]$Session.LastPromptText)
    $promptPreview = if ($promptText.Length -gt 220) { $promptText.Substring(0, 220) + "..." } else { $promptText }
    $currentToolCounts = if ($Session.ToolNameCounts) { $Session.ToolNameCounts } else { @{} }
    $toolBreakdown = New-Object 'System.Collections.Generic.List[string]'
    foreach ($name in $currentToolCounts.Keys) {
        $currentCount = [int]$currentToolCounts[$name]
        $previousCount = if ($Baseline.ToolNameCounts.ContainsKey([string]$name)) { [int]$Baseline.ToolNameCounts[[string]$name] } else { 0 }
        $delta = $currentCount - $previousCount
        if ($delta -gt 0) {
            $toolBreakdown.Add(("{0} x{1}" -f $name, $delta))
        }
    }

    $nextRunNumber = 1
    if (@($script:Sample.BenchmarkRuns).Count -gt 0) {
        $maxRun = @($script:Sample.BenchmarkRuns | Measure-Object -Property RunNumber -Maximum).Maximum
        if ($null -ne $maxRun) {
            $nextRunNumber = [int]$maxRun + 1
        }
    }

    $inputTokens = if ($null -ne $Session.LastInputTokens) { [double]$Session.LastInputTokens } else { 0.0 }
    $outputTokens = if ($null -ne $Session.LastOutputTokens) { [double]$Session.LastOutputTokens } else { 0.0 }
    $totalTokens = if ($null -ne $Session.LastTokens) { [double]$Session.LastTokens } else { $inputTokens + $outputTokens }
    $toolCalls = [Math]::Max(0, [int]$Session.ToolCalls - [int]$Baseline.ToolCalls)
    $toolOutputs = [Math]::Max(0, [int]$Session.ToolOutputs - [int]$Baseline.ToolOutputs)
    $assistantMessages = [Math]::Max(0, [int]$Session.AssistantMessages - [int]$Baseline.AssistantMessages)
    $eventCount = [Math]::Max(0, [int]$Session.ParsedEventCount - [int]$Baseline.ParsedEventCount)

    return [pscustomobject]@{
        Status = "completed"
        RunNumber = $nextRunNumber
        PromptFingerprint = Get-BenchmarkPromptFingerprint $promptText
        PromptPreview = $promptPreview
        StartedAt = $StartedAt
        CompletedAt = $CompletedAt
        CapturedAt = Get-Date
        TimeTakenSeconds = [Math]::Round($elapsed, 3)
        Model = if ($Session.ActiveModel) { [string]$Session.ActiveModel } else { "unknown" }
        ServiceTier = if ($Session.ServiceTier) { [string]$Session.ServiceTier } else { "unknown" }
        PlanType = if ($Session.PlanType) { [string]$Session.PlanType } else { "unknown" }
        Cwd = [string]$Session.Cwd
        SessionId = [string]$Session.SessionId
        SessionPath = [string]$Session.SessionPath
        TotalTokens = [Math]::Round($totalTokens, 1)
        InputTokens = [Math]::Round($inputTokens, 1)
        OutputTokens = [Math]::Round($outputTokens, 1)
        CachedInputTokens = if ($null -ne $Session.LastPromptCachedInputTokens) { [Math]::Round([double]$Session.LastPromptCachedInputTokens, 1) } else { 0.0 }
        CacheWriteInputTokens = if ($null -ne $Session.LastPromptCacheWriteInputTokens) { [Math]::Round([double]$Session.LastPromptCacheWriteInputTokens, 1) } else { 0.0 }
        ReasoningTokens = if ($null -ne $Session.LastPromptReasoningTokens) { [Math]::Round([double]$Session.LastPromptReasoningTokens, 1) } else { 0.0 }
        TimeToFirstTokenMs = $Session.LastTaskTimeToFirstTokenMs
        TotalTokensPerSecond = [Math]::Round($totalTokens / $elapsed, 2)
        OutputTokensPerSecond = [Math]::Round($outputTokens / $elapsed, 2)
        ToolCallsPerMinute = [Math]::Round(($toolCalls / $elapsed) * 60.0, 2)
        ToolCalls = $toolCalls
        ToolOutputs = $toolOutputs
        ToolsUsed = @($toolBreakdown)
        AssistantMessages = $assistantMessages
        ParsedEvents = $eventCount
        CostUnits = $Session.LastPromptCostUnits
        BurnCostUnitsPerPercent = $Session.BurnCostUnitsPerPercent
        FastMultiplier = $Session.LastPromptFastMultiplier
        FastExtraCostUnits = $Session.LastPromptFastExtraCostUnits
        ContextPercent = $Session.LastPromptContextPercent
        PrimaryUseDelta = $Session.LastPromptPrimaryUseDelta
    }
}

function Set-BenchmarkButtonState {
    param([bool]$Enabled = $true)

    if (-not $benchmarkButton) {
        return
    }

    $benchmarkButton.Enabled = $Enabled
    switch ([string]$script:Sample.BenchmarkStatus) {
        "armed" {
            $benchmarkButton.Text = "Armed"
            $tip = "Benchmark armed. Send exactly one prompt in this conversation. Click again to cancel."
        }
        "running" {
            $benchmarkButton.Text = "Run..."
            $tip = "Benchmark running. Waiting for this prompt to complete."
        }
        default {
            $benchmarkButton.Text = "Bench"
            $tip = "Arm a one-prompt benchmark for this selected conversation. It completes automatically at task_complete."
        }
    }
    Set-BuddyToolTip -Tip $uiTip -Control $benchmarkButton -Text $tip
}

function Start-BenchmarkCapture {
    $snapshot = $script:Sample.CurrentSnapshot
    $session = if ($snapshot) { $snapshot.Session } else { $null }
    if (-not $session -or [string]$session.SessionPath -eq "__ALL__") {
        Set-BuddyToolTip -Tip $uiTip -Control $benchmarkButton -Text "Select one conversation tab before arming a benchmark."
        return
    }

    $script:Sample.BenchmarkArmed = $true
    $script:Sample.BenchmarkStatus = "armed"
    $script:Sample.BenchmarkSessionPath = [string]$session.SessionPath
    $script:Sample.BenchmarkArmedAt = Get-Date
    $script:Sample.BenchmarkRunStartedAt = [datetime]::MinValue
    $script:Sample.BenchmarkBaseline = New-BenchmarkBaseline -Session $session
    $script:Sample.BenchmarkPromptText = $null
    Set-BenchmarkButtonState -Enabled $true
}

function Cancel-BenchmarkCapture {
    $script:Sample.BenchmarkArmed = $false
    $script:Sample.BenchmarkStatus = "idle"
    $script:Sample.BenchmarkSessionPath = $null
    $script:Sample.BenchmarkArmedAt = [datetime]::MinValue
    $script:Sample.BenchmarkRunStartedAt = [datetime]::MinValue
    $script:Sample.BenchmarkBaseline = $null
    $script:Sample.BenchmarkPromptText = $null
    Set-BenchmarkButtonState -Enabled $true
}

function Update-BenchmarkCapture {
    param($Session)

    if (-not $script:Sample.BenchmarkArmed -or -not $Session -or -not $script:Sample.BenchmarkBaseline) {
        return
    }
    if ([string]$Session.SessionPath -ne [string]$script:Sample.BenchmarkSessionPath) {
        return
    }

    $baseline = $script:Sample.BenchmarkBaseline
    if ($script:Sample.BenchmarkStatus -eq "armed" -and $null -ne $Session.LastPromptStartedAt -and $Session.LastPromptStartedAt -gt $script:Sample.BenchmarkArmedAt -and [int]$Session.UserMessages -gt [int]$baseline.UserMessages) {
        $script:Sample.BenchmarkStatus = "running"
        $script:Sample.BenchmarkRunStartedAt = [datetime]$Session.LastPromptStartedAt
        $script:Sample.BenchmarkPromptText = [string]$Session.LastPromptText
        Set-BenchmarkButtonState -Enabled $true
    }

    if ($script:Sample.BenchmarkStatus -eq "running" -and $null -ne $Session.LastTaskCompleteAt -and $Session.LastTaskCompleteAt -gt $script:Sample.BenchmarkRunStartedAt) {
        $run = New-BenchmarkRun -Session $Session -Baseline $baseline -StartedAt $script:Sample.BenchmarkRunStartedAt -CompletedAt ([datetime]$Session.LastTaskCompleteAt)
        $script:Sample.BenchmarkRuns = @($script:Sample.BenchmarkRuns) + $run
        $script:Sample.BenchmarkLastRun = $run
        Save-BenchmarkRuns
        $script:Sample.BenchmarkArmed = $false
        $script:Sample.BenchmarkStatus = "idle"
        $script:Sample.BenchmarkSessionPath = $null
        $script:Sample.BenchmarkBaseline = $null
        $script:Sample.BenchmarkRunStartedAt = [datetime]::MinValue
        Set-BenchmarkButtonState -Enabled $true
        if ($detailsForm) {
            Set-DetailsOpen -Open $true
        }
    }
}

function Format-UsePercentDelta {
    param([nullable[double]]$Value)

    if ($null -eq $Value) {
        return "n/a"
    }

    return ("{0:+0.00;-0.00;+0.00}%" -f [double]$Value)
}

function Format-UsePercent {
    param([nullable[double]]$Value)

    if ($null -eq $Value) {
        return "n/a"
    }

    return ("{0:N2}%" -f [double]$Value)
}

function Get-UsageConfidenceLabel {
    param($Session)

    if (-not $Session) {
        return "Unknown"
    }

    $hasObservedLimit = ($null -ne $Session.PrimaryUsedPercent -or $null -ne $Session.SessionPromptPrimaryUseDelta)
    $freshTokenEvent = ($null -ne $Session.LastTokenEventAgeSeconds -and [double]$Session.LastTokenEventAgeSeconds -le 120)
    if ($hasObservedLimit -and $freshTokenEvent) {
        return "Fresh"
    }

    if ($freshTokenEvent) {
        return "Estimate"
    }

    if ($null -ne $Session.LastTokenEventAgeSeconds) {
        return "Old"
    }

    return "Waiting"
}

function Get-UsageVerdict {
    param(
        $Session,
        $PriceGuard,
        [nullable[double]]$SpeedTokPerSecond,
        [string]$LastPromptBurnText,
        [string]$SessionBurnText,
        [bool]$HasFastExtra
    )

    $confidence = Get-UsageConfidenceLabel -Session $Session
    $signal = if ($Session -and $Session.CompactSignal) { [string]$Session.CompactSignal } else { "learning" }
    $guardState = if ($PriceGuard -and $PriceGuard.State) { [string]$PriceGuard.State } else { "wait" }
    $speed = if ($null -ne $SpeedTokPerSecond) { [Math]::Round([double]$SpeedTokPerSecond, 1) } else { 0.0 }

    if ($guardState -eq "hard") {
        return [pscustomobject]@{ Text = "Stop soon: start a fresh chat"; Tone = "bad"; Confidence = $confidence }
    }
    if ($guardState -eq "over") {
        return [pscustomobject]@{ Text = "Higher API price: start fresh"; Tone = "bad"; Confidence = $confidence }
    }
    if ($guardState -eq "red") {
        return [pscustomobject]@{ Text = "Very long chat: fresh chat is cheaper"; Tone = "bad"; Confidence = $confidence }
    }
    if ($guardState -eq "yellow") {
        return [pscustomobject]@{ Text = "Long chat: keep prompts short"; Tone = "warn"; Confidence = $confidence }
    }

    switch ($signal) {
        "compact now" { return [pscustomobject]@{ Text = "Start a fresh chat soon"; Tone = "bad"; Confidence = $confidence } }
        "compact soon" { return [pscustomobject]@{ Text = "Chat is getting long"; Tone = "warn"; Confidence = $confidence } }
        "cost spike" { return [pscustomobject]@{ Text = "Last prompt cost was high"; Tone = "bad"; Confidence = $confidence } }
        "cost high" { return [pscustomobject]@{ Text = "This chat is getting costly"; Tone = "warn"; Confidence = $confidence } }
        "watch" { return [pscustomobject]@{ Text = "Watch cost: above normal"; Tone = "warn"; Confidence = $confidence } }
    }

    if ($HasFastExtra) {
        return [pscustomobject]@{ Text = "Fast mode costs extra"; Tone = "warn"; Confidence = $confidence }
    }

    if ($speed -gt 0) {
        return [pscustomobject]@{ Text = ("Replying: {0}/sec | last cost {1}" -f $speed, $LastPromptBurnText); Tone = "good"; Confidence = $confidence }
    }

    return [pscustomobject]@{ Text = ("Ready: chat cost {0}" -f $SessionBurnText); Tone = "neutral"; Confidence = $confidence }
}

function Get-CostSpeedDetailsText {
    param(
        $Session,
        $Process,
        $PriceGuard,
        $UsageVerdict,
        [string]$UsageModel,
        [nullable[double]]$SpeedTokPerSecond,
        [nullable[double]]$SpeedMaxTokPerSecond,
        [string]$SessionBurnText,
        [string]$LastPromptBurnText,
        [string]$SessionFastExtraBurnText,
        [string]$LastPromptFastExtraBurnText,
        [string]$SessionPrimaryUseText,
        [string]$LastPromptPrimaryUseText,
        [string]$CostMultiplierText,
        [string]$CompactSignalText,
        [string]$LastPromptAgeText,
        [string]$BurnScaleText,
        [string]$ModelPriceSummary
    )

    if (-not $Session) {
        return "Waiting for session data."
    }

    $guardState = if ($PriceGuard -and $PriceGuard.State) { [string]$PriceGuard.State } else { "wait" }
    $guardText = if ($PriceGuard -and $PriceGuard.Text) { [string]$PriceGuard.Text } else { "waiting" }
    $speed = if ($null -ne $SpeedTokPerSecond) { [Math]::Round([double]$SpeedTokPerSecond, 2) } else { 0.0 }
    $maxSpeed = if ($null -ne $SpeedMaxTokPerSecond) { [Math]::Round([double]$SpeedMaxTokPerSecond, 2) } else { 0.0 }
    $weeklyOnly = ($null -eq $Session.PrimaryWindowMinutes -and $null -ne $Session.SecondaryWindowMinutes)
    $primaryWindowLabel = Get-RateLimitWindowLabel -WindowMinutes $(if ($weeklyOnly) { $Session.SecondaryWindowMinutes } else { $Session.PrimaryWindowMinutes }) -Fallback "Usage Limit"
    $secondaryWindowLabel = Get-RateLimitWindowLabel -WindowMinutes $Session.SecondaryWindowMinutes -Fallback "Additional Limit"
    $primaryLeft = if ($weeklyOnly -and $null -ne $Session.SecondaryRemainingPercent) { ("{0}%, reset {1}" -f $Session.SecondaryRemainingPercent, $Session.SecondaryReset) } elseif ($null -ne $Session.PrimaryRemainingPercent) { ("{0}%, reset {1}" -f $Session.PrimaryRemainingPercent, $Session.PrimaryReset) } else { "n/a" }
    $secondaryLeft = if ($null -ne $Session.PrimaryWindowMinutes -and $null -ne $Session.SecondaryRemainingPercent) { ("{0}%, reset {1}" -f $Session.SecondaryRemainingPercent, $Session.SecondaryReset) } else { $null }
    $secondaryLimitLine = if ($null -ne $Session.PrimaryWindowMinutes -and $null -ne $Session.SecondaryRemainingPercent) { "  " + $secondaryWindowLabel + " left: " + $secondaryLeft } else { $null }
    $tierText = if ($Session.ServiceTier) { [string]$Session.ServiceTier } else { "unknown" }
    $fastText = if ([double]$Session.FastMultiplier -gt 1.0) { ("on, {0}x" -f $Session.FastMultiplier) } else { "off" }
    $freshText = if ($null -ne $Session.LastTokenEventAgeSeconds) { ("{0}, updated {1} ago" -f $UsageVerdict.Confidence, (Format-RelativeAge $Session.LastTokenEventAgeSeconds)) } else { ("{0}, waiting for update" -f $UsageVerdict.Confidence) }
    $taskDurationMs = Get-JsonValue -Object $Session -Name "LastTaskDurationMs"
    $taskTtftMs = Get-JsonValue -Object $Session -Name "LastTaskTimeToFirstTokenMs"
    $cacheWriteTokens = Get-JsonValue -Object $Session -Name "CacheWriteTokens"
    $lastCacheWriteTokens = Get-JsonValue -Object $Session -Name "LastPromptCacheWriteInputTokens"
    $weeklyWindow = Get-JsonValue -Object $Session -Name "WeeklyWindowMinutes"
    $weeklyUsed = Get-JsonValue -Object $Session -Name "WeeklyUsedPercent"
    $weeklyReset = Get-JsonValue -Object $Session -Name "WeeklyReset"
    $creditsBalance = Get-JsonValue -Object $Session -Name "CreditsBalance"
    $cacheHitPercent = Get-JsonValue -Object $Session -Name "CacheHitPercent"
    $lastPromptCacheHitPercent = Get-JsonValue -Object $Session -Name "LastPromptCacheHitPercent"
    $uncachedInputTokens = Get-JsonValue -Object $Session -Name "UncachedInputTokens"
    $recentTaskCount = Get-JsonValue -Object $Session -Name "RecentTaskCount"
    $recentTaskAverageMs = Get-JsonValue -Object $Session -Name "RecentTaskDurationAverageMs"
    $recentTaskMedianMs = Get-JsonValue -Object $Session -Name "RecentTaskDurationMedianMs"
    $recentTaskTtftAverageMs = Get-JsonValue -Object $Session -Name "RecentTaskTimeToFirstTokenAverageMs"
    $forecastText = Get-JsonValue -Object $Session -Name "UsageForecastText"
    $forecastRate = Get-JsonValue -Object $Session -Name "UsageForecastRatePercentPerHour"
    $forecastSamples = Get-JsonValue -Object $Session -Name "UsageForecastSampleCount"
    $forecastCoverage = Get-JsonValue -Object $Session -Name "UsageForecastCoverageMinutes"
    $taskDurationText = if ($null -ne $taskDurationMs) { [string]$taskDurationMs } else { "n/a" }
    $taskTtftText = if ($null -ne $taskTtftMs) { [string]$taskTtftMs } else { "n/a" }
    $taskTimingLine = "  Last task: " + $taskDurationText + " ms | first token: " + $taskTtftText + " ms"
    $weeklyLine = if ($null -ne $weeklyWindow) { "  Weekly: " + [string]$weeklyUsed + "% used | reset " + [string]$weeklyReset } else { $null }
    $creditsLine = if ($null -ne $creditsBalance) { "  Credits balance: " + [string]$creditsBalance } else { $null }
    $cacheHitText = if ($null -ne $cacheHitPercent) { ([string]$cacheHitPercent + "%") } else { "n/a" }
    $lastCacheHitText = if ($null -ne $lastPromptCacheHitPercent) { ([string]$lastPromptCacheHitPercent + "%") } else { "n/a" }
    $cacheEfficiencyLine = "  Cache efficiency: " + $cacheHitText + " hit | last " + $lastCacheHitText + " | uncached " + (Format-Number $uncachedInputTokens)
    $taskCountText = if ($null -ne $recentTaskCount) { [string]$recentTaskCount } else { "0" }
    $taskAverageText = if ($null -ne $recentTaskAverageMs) { ("{0:N1}s" -f ([double]$recentTaskAverageMs / 1000.0)) } else { "n/a" }
    $taskMedianText = if ($null -ne $recentTaskMedianMs) { ("{0:N1}s" -f ([double]$recentTaskMedianMs / 1000.0)) } else { "n/a" }
    $taskTtftAverageText = if ($null -ne $recentTaskTtftAverageMs) { ("{0:N1}s" -f ([double]$recentTaskTtftAverageMs / 1000.0)) } else { "n/a" }
    $taskPerformanceLine = "  Recent tasks: " + $taskCountText + " | avg " + $taskAverageText + " | median " + $taskMedianText + " | first token " + $taskTtftAverageText
    $forecastRateText = if ($null -ne $forecastRate) { ([string]$forecastRate + "%/h") } else { "learning" }
    $forecastCoverageText = if ($null -ne $forecastCoverage -and [double]$forecastCoverage -gt 0) { ([string]$forecastCoverage + "m") } else { "new" }
    $forecastLine = "  Forecast: " + $(if ($forecastText) { [string]$forecastText } else { "waiting" }) + " | " + $forecastRateText + " | " + [string]$forecastSamples + " samples / " + $forecastCoverageText
    $chatRiskText = switch ($guardState) {
        "over" { "Official 272K API price cliff crossed. Start a fresh chat now." }
        "hard" { "Start a fresh chat now." }
        "red" { "Fresh chat strongly recommended." }
        "yellow" { "Keep prompts short, or start fresh soon." }
        "green" { "Looks okay." }
        default { "Waiting for enough data." }
    }

    return [string]::Join([Environment]::NewLine, @(
        "Quick read",
        ("  {0}" -f $UsageVerdict.Text),
        ("  Data: {0}" -f $freshText),
        "",
        "Speed",
        ("  Reply speed: {0} tokens/sec" -f $speed),
        ("  Best seen: {0} tokens/sec" -f $maxSpeed),
        "",
        "Cost",
        ("  Last ask: {0} cost points" -f $LastPromptBurnText),
        ("  This chat: {0} cost points across {1} asks" -f $SessionBurnText, (Format-Number $Session.SessionPromptCount)),
        (Get-PromptCostHistoryText -Session $Session -CostUnitsPerOnePercent $Session.BurnCostUnitsPerPercent),
        "",
        "Benchmark",
        (Get-BenchmarkComparisonText -Runs $script:Sample.BenchmarkRuns),
        ("  Short-window meter change: last {0}, chat {1}" -f $LastPromptPrimaryUseText, $SessionPrimaryUseText),
        ("  Fast mode: {0}" -f $fastText),
        "",
        "Limits",
        ("  {0} left: {1}" -f $primaryWindowLabel, $primaryLeft),
        $secondaryLimitLine,
        "",
        "Long chat risk",
        ("  {0}" -f $chatRiskText),
        ("  {0}" -f $guardText),
        "",
        "Telemetry",
        $taskTimingLine,
        $taskPerformanceLine,
        ("  Tools: {0} calls | {1} outputs | last {2}" -f $Session.ToolCalls, $Session.ToolOutputs, $Session.LastTool),
        ("  Cache write: chat {0} | last ask {1}" -f (Format-Number $cacheWriteTokens), (Format-Number $lastCacheWriteTokens)),
        $cacheEfficiencyLine,
        $weeklyLine,
        $forecastLine,
        $creditsLine,
        "",
        "Advanced",
        ("  Model: {0} | tier {1}" -f (Shorten-Model $UsageModel), $tierText),
        ("  API price: {0}" -f $ModelPriceSummary),
        ("  Last prompt tokens: {0}" -f (Format-Number $Session.LastTokens)),
        ("  Chat tokens: {0}" -f (Format-Number $Session.SessionPromptTokens)),
        ("  Cost signal: {0}, {1} baseline" -f $CompactSignalText, $CostMultiplierText)
    ))
}

function Get-SessionBoardRow {
    param($Session)

    if (-not $Session) {
        return [pscustomobject]@{ Name = "Waiting"; Detail = "No session data yet"; Tone = "neutral"; Tip = "Waiting for session data." }
    }

    $speed = if ($Session.OutputTokensPerSecond -and [double]$Session.OutputTokensPerSecond -gt 0) { [double]$Session.OutputTokensPerSecond } else { [double]$Session.TokensPerSecond }
    $lastCost = Format-BurnScore -CostUnits $Session.LastPromptCostUnits -CostUnitsPerOnePercent $Session.BurnCostUnitsPerPercent
    $chatCost = Format-BurnScore -CostUnits $Session.SessionPromptCostUnits -CostUnitsPerOnePercent $Session.BurnCostUnitsPerPercent
    $guard = Get-LongContextPriceGuard -Model ([string]$Session.PriceGuardModel) -CurrentInputTokens $Session.LastInputTokens
    $hasFast = ($null -ne $Session.SessionPromptFastExtraCostUnits -and [double]$Session.SessionPromptFastExtraCostUnits -gt 0)
    $verdict = Get-UsageVerdict -Session $Session -PriceGuard $guard -SpeedTokPerSecond $speed -LastPromptBurnText $lastCost -SessionBurnText $chatCost -HasFastExtra $hasFast
    $model = Shorten-Model $Session.ActiveModel
    $cwd = Short-Cwd $Session.Cwd
    $left = ("{0} | {1}" -f $cwd, $model)
    $primaryWindowText = Get-RateLimitWindowShortLabel -WindowMinutes $Session.PrimaryWindowMinutes -Fallback "usage"
    $secondaryWindowText = Get-RateLimitWindowShortLabel -WindowMinutes $Session.SecondaryWindowMinutes -Fallback "additional"
    $limitParts = New-Object 'System.Collections.Generic.List[string]'
    if ($null -ne $Session.PrimaryRemainingPercent) { [void]$limitParts.Add(("{0} {1}%" -f $primaryWindowText, $Session.PrimaryRemainingPercent)) }
    if ($null -ne $Session.SecondaryRemainingPercent) { [void]$limitParts.Add(("{0} {1}%" -f $secondaryWindowText, $Session.SecondaryRemainingPercent)) }
    $limitSummary = $limitParts -join " | "
    if ([string]::IsNullOrWhiteSpace($limitSummary)) { $limitSummary = "limits n/a" }
    $right = ("{0}/sec | last {1} | chat {2} | {3}" -f ([Math]::Round($speed, 1)), $lastCost, $chatCost, $limitSummary)
    $tip = ("{0}. {1}. Reply speed {2} tokens/sec. Last ask {3} cost points. Chat {4} cost points across {5} asks. Limits: {6}. Updated {7} ago." -f $left, $verdict.Text, ([Math]::Round($speed, 2)), $lastCost, $chatCost, (Format-Number $Session.SessionPromptCount), $limitSummary, $(if ($null -ne $Session.LastTokenEventAgeSeconds) { Format-RelativeAge $Session.LastTokenEventAgeSeconds } else { "unknown" }))

    return [pscustomobject]@{
        Name = $left
        Detail = $right
        Tone = $verdict.Tone
        Tip = $tip
    }
}

function Get-PromptCostUnits {
    param(
        [nullable[double]]$InputTokens,
        [nullable[double]]$CachedInputTokens,
        [nullable[double]]$CacheWriteInputTokens,
        [nullable[double]]$OutputTokens,
        [nullable[double]]$ReasoningTokens,
        [string]$Model = $null
    )

    $pricing = Get-ModelPricing -Model $Model
    $input = if ($null -ne $InputTokens) { [double]$InputTokens } else { 0.0 }
    $cached = if ($null -ne $CachedInputTokens) { [Math]::Min([double]$CachedInputTokens, $input) } else { 0.0 }
    $cacheWrite = if ($null -ne $CacheWriteInputTokens) { [Math]::Max(0.0, [double]$CacheWriteInputTokens) } else { 0.0 }
    $output = if ($null -ne $OutputTokens) { [double]$OutputTokens } else { 0.0 }
    $reasoning = if ($null -ne $ReasoningTokens) { [Math]::Min([double]$ReasoningTokens, $output) } else { 0.0 }
    $useLongRates = ($pricing -and $input -gt $script:LongContextInputThreshold -and $null -ne $pricing.LongInput -and $null -ne $pricing.LongOutput)
    $inputRate = if ($useLongRates) { [double]$pricing.LongInput } elseif ($pricing) { [double]$pricing.Input } else { [double]$script:CostWeightInput }
    $cachedRate = if ($useLongRates -and $null -ne $pricing.LongCachedInput) { [double]$pricing.LongCachedInput } elseif ($pricing -and $null -ne $pricing.CachedInput) { [double]$pricing.CachedInput } else { [double]$script:CostWeightCachedInput }
    $cacheWriteRate = if ($useLongRates -and $null -ne $pricing.LongCacheWrite) { [double]$pricing.LongCacheWrite } elseif ($pricing -and $null -ne $pricing.CacheWrite) { [double]$pricing.CacheWrite } else { $inputRate }
    $outputRate = if ($useLongRates) { [double]$pricing.LongOutput } elseif ($pricing) { [double]$pricing.Output } else { [double]$script:CostWeightOutput }
    $freshInput = [Math]::Max(0.0, $input - $cached)
    $visibleOutput = [Math]::Max(0.0, $output - $reasoning)

    return [Math]::Round(
        ($freshInput * $inputRate) +
        ($cached * $cachedRate) +
        ($cacheWrite * $cacheWriteRate) +
        ($visibleOutput * $outputRate) +
        ($reasoning * $outputRate),
        1
    )
}

function Get-CodexConfigServiceTier {
    param(
        [string]$Root,
        [hashtable]$State
    )

    if (-not $State.ContainsKey("CodexConfigTier")) {
        $State.CodexConfigTier = $null
        $State.CodexConfigFastMode = $false
        $State.CodexConfigReadAt = [datetime]::MinValue
    }

    $now = Get-Date
    if (($now - [datetime]$State.CodexConfigReadAt).TotalSeconds -lt 10) {
        return $State.CodexConfigTier
    }

    $State.CodexConfigReadAt = $now
    $State.CodexConfigTier = $null
    $State.CodexConfigFastMode = $false
    $configPath = Join-Path $Root "config.toml"
    if (-not (Test-Path -LiteralPath $configPath)) {
        return $null
    }

    try {
        foreach ($line in (Get-Content -LiteralPath $configPath -ErrorAction Stop)) {
            $trimmed = ([string]$line).Trim()
            if ($trimmed -match '^\s*service_tier\s*=\s*["'']?([^"''#]+)["'']?') {
                $State.CodexConfigTier = $matches[1].Trim()
            } elseif ($trimmed -match '^\s*fast_mode\s*=\s*true\b') {
                $State.CodexConfigFastMode = $true
            }
        }
    } catch {}

    if ([string]::IsNullOrWhiteSpace([string]$State.CodexConfigTier) -and [bool]$State.CodexConfigFastMode) {
        $State.CodexConfigTier = "fast"
    }

    return $State.CodexConfigTier
}

function Get-ServiceTierFromObject {
    param($Object)

    foreach ($name in @("service_tier", "serviceTier")) {
        $value = Get-JsonValue -Object $Object -Name $name
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            return [string]$value
        }
    }

    return $null
}

function Get-FastModeMultiplier {
    param(
        [string]$Model,
        [string]$ServiceTier
    )

    if ([string]::IsNullOrWhiteSpace($ServiceTier) -or ([string]$ServiceTier).ToLowerInvariant() -ne "fast") {
        return 1.0
    }

    $modelKey = if ($Model) { ([string]$Model).ToLowerInvariant() } else { "" }
    if ($modelKey -like "*gpt-5.5*") {
        return 2.5
    }
    if ($modelKey -like "*gpt-5.4*" -and $modelKey -notlike "*mini*") {
        return 2.0
    }

    return 1.0
}

function Get-FastExtraCostUnits {
    param(
        [nullable[double]]$CostUnits,
        [double]$Multiplier
    )

    if ($null -eq $CostUnits -or $Multiplier -le 1.0) {
        return 0.0
    }

    return [Math]::Round([double]$CostUnits * ($Multiplier - 1.0), 1)
}

function Get-ModelPricing {
    param([string]$Model)

    if ([string]::IsNullOrWhiteSpace($Model)) {
        return $null
    }

    $modelKey = $Model.Trim().ToLowerInvariant().Replace('_', '-')
    $pricingKey = $null
    if ($modelKey -like "*gpt-5.6-sol*") {
        $pricingKey = "gpt-5.6-sol"
    } elseif ($modelKey -like "*gpt-5.6-terra*") {
        $pricingKey = "gpt-5.6-terra"
    } elseif ($modelKey -like "*gpt-5.6-luna*") {
        $pricingKey = "gpt-5.6-luna"
    } elseif ($modelKey -like "*gpt-5.5-pro*") {
        $pricingKey = "gpt-5.5-pro"
    } elseif ($modelKey -like "*gpt-5.5*") {
        $pricingKey = "gpt-5.5"
    } elseif ($modelKey -like "*gpt-5.4-mini*") {
        $pricingKey = "gpt-5.4-mini"
    } elseif ($modelKey -like "*gpt-5.4-pro*") {
        $pricingKey = "gpt-5.4-pro"
    } elseif ($modelKey -like "*gpt-5.4*") {
        $pricingKey = "gpt-5.4"
    }

    if ($pricingKey -and $script:ModelPricing -and $script:ModelPricing.ContainsKey($pricingKey)) {
        return $script:ModelPricing[$pricingKey]
    }

    return $null
}

function Format-UsdRate {
    param([nullable[double]]$Value)

    if ($null -eq $Value) {
        return "n/a"
    }

    $formatted = ("{0:0.###}" -f [double]$Value)
    if ($formatted -notlike "*.*") {
        $formatted = "$formatted.00"
    } elseif ($formatted.Split('.')[1].Length -eq 1) {
        $formatted = "${formatted}0"
    }

    return ("`$" + $formatted)
}

function Get-ModelPriceSummary {
    param($Pricing)

    if (-not $Pricing) {
        return "price unavailable"
    }

    $short = ("{0} in / {1} out" -f (Format-UsdRate $Pricing.Input), (Format-UsdRate $Pricing.Output))
    if ($null -ne $Pricing.LongInput -and $null -ne $Pricing.LongOutput) {
        return ("API {0} short | {1} long per 1M tokens" -f $short, ("{0} in / {1} out" -f (Format-UsdRate $Pricing.LongInput), (Format-UsdRate $Pricing.LongOutput)))
    }

    return ("API {0} per 1M tokens" -f $short)
}

function Test-LongContextPriceModel {
    param([string]$Model)

    return ($null -ne (Get-LongContextPriceModelLabel -Model $Model))
}

function Get-LongContextPriceModelLabel {
    param([string]$Model)

    if ([string]::IsNullOrWhiteSpace($Model)) {
        return $null
    }

    $modelName = $Model.Trim()
    $modelKey = $modelName.ToLowerInvariant()
    if ($modelKey -eq "gpt-5.6-sol" -or $modelKey.StartsWith("gpt-5.6-sol-")) {
        return "GPT-5.6 Sol"
    }

    if ($modelKey -eq "gpt-5.6-terra" -or $modelKey.StartsWith("gpt-5.6-terra-")) {
        return "GPT-5.6 Terra"
    }

    if ($modelKey -eq "gpt-5.6-luna" -or $modelKey.StartsWith("gpt-5.6-luna-")) {
        return "GPT-5.6 Luna"
    }

    if ($modelKey -eq "gpt-5.4" -or ($modelKey.StartsWith("gpt-5.4-") -and -not $modelKey.StartsWith("gpt-5.4-mini") -and -not $modelKey.StartsWith("gpt-5.4-nano") -and -not $modelKey.StartsWith("gpt-5.4-pro"))) {
        return "GPT-5.4"
    }

    if ($modelKey -eq "gpt-5.4-pro" -or $modelKey.StartsWith("gpt-5.4-pro-")) {
        return "GPT-5.4 Pro"
    }

    if ($modelKey -eq "gpt-5.5" -or ($modelKey.StartsWith("gpt-5.5-") -and -not $modelKey.StartsWith("gpt-5.5-pro"))) {
        return "GPT-5.5"
    }

    if ($modelKey -eq "gpt-5.5-pro" -or $modelKey.StartsWith("gpt-5.5-pro-")) {
        return "GPT-5.5 Pro"
    }

    return $null
}

function Get-LongContextPriceGuard {
    param(
        [string]$Model,
        [nullable[double]]$CurrentInputTokens
    )

    $modelLabel = Get-LongContextPriceModelLabel -Model $Model
    if (-not $modelLabel) {
        return [pscustomobject]@{ State = "off"; Text = "This model is not tracked for long-chat risk."; Percent = 0.0; Remaining = $null }
    }

    if ($null -eq $CurrentInputTokens) {
        return [pscustomobject]@{ State = "wait"; Text = ("{0}: waiting for chat size" -f $modelLabel); Percent = 0.0; Remaining = $null }
    }

    $inputTokens = [double]$CurrentInputTokens
    $percent = [Math]::Min(100.0, ($inputTokens / $script:LongContextInputThreshold) * 100.0)
    $remaining = $script:LongContextInputThreshold - $inputTokens
    if ($inputTokens -gt $script:LongContextInputThreshold) {
        return [pscustomobject]@{ State = "over"; Text = ("{0}: OVER 272K higher API price" -f $modelLabel); Percent = 100.0; Remaining = $remaining }
    }

    if ($inputTokens -ge $script:LongContextHardStopThreshold) {
        return [pscustomobject]@{ State = "hard"; Text = ("{0}: final warning before 272K" -f $modelLabel); Percent = $percent; Remaining = $remaining }
    }

    if ($inputTokens -ge $script:LongContextRedThreshold) {
        return [pscustomobject]@{ State = "red"; Text = ("{0}: fresh chat is safer" -f $modelLabel); Percent = $percent; Remaining = $remaining }
    }

    if ($inputTokens -ge $script:LongContextYellowThreshold) {
        return [pscustomobject]@{ State = "yellow"; Text = ("{0}: this chat is getting long" -f $modelLabel); Percent = $percent; Remaining = $remaining }
    }

    return [pscustomobject]@{ State = "green"; Text = ("{0}: chat length looks ok" -f $modelLabel); Percent = $percent; Remaining = $remaining }
}

function Show-LongContextPriceNotice {
    param(
        $Session,
        $PriceGuard,
        [string]$ModelLabel
    )

    if (-not $Session -or -not $PriceGuard -or $PriceGuard.State -ne "over") {
        return
    }

    $sessionId = if ($Session.PriceGuardSessionId) { [string]$Session.PriceGuardSessionId } elseif ($Session.SessionId) { [string]$Session.SessionId } else { "unknown" }
    $model = if ($ModelLabel) { $ModelLabel } else { [string]$Session.PriceGuardModel }
    $noticeKey = "{0}|{1}|over-272k" -f $sessionId, $model
    $now = Get-Date
    $shouldNotify = ($script:Sample.LongContextNoticeKey -ne $noticeKey) -or (($now - [datetime]$script:Sample.LongContextNoticeAt).TotalMinutes -ge 10)
    if (-not $shouldNotify) {
        return
    }

    $script:Sample.LongContextNoticeKey = $noticeKey
    $script:Sample.LongContextNoticeAt = $now
    $inputText = Format-Number $Session.LastInputTokens
    $overText = Format-Number ([Math]::Max(0.0, [double]$Session.LastInputTokens - [double]$script:LongContextInputThreshold))
    $message = "{0} input tokens. Over the 272K API price cliff by {1}. Start a fresh chat to get out of the higher-cost zone." -f $inputText, $overText

    try {
        if ($script:PriceNotifyIcon) {
            $script:PriceNotifyIcon.BalloonTipTitle = "Codex Buddy: higher API price"
            $script:PriceNotifyIcon.BalloonTipText = $message
            $script:PriceNotifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
            $script:PriceNotifyIcon.ShowBalloonTip(10000)
        }
        [System.Media.SystemSounds]::Exclamation.Play()
    } catch {
        Write-BuddyCrashLog $_
    }
}

function Save-LongContextAlertLedger {
    try {
        $directory = Split-Path -Parent $script:LongContextAlertPath
        if (-not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }

        $rows = foreach ($key in @($script:LongContextAlerts.Keys)) {
            $entry = $script:LongContextAlerts[$key]
            [pscustomobject]@{
                Key = [string]$key
                Count = [int]$entry.Count
                PendingCount = [int]$entry.PendingCount
                WasOver = [bool]$entry.WasOver
                Model = [string]$entry.Model
                SessionId = [string]$entry.SessionId
                LastInputTokens = if ($null -ne $entry.LastInputTokens) { [double]$entry.LastInputTokens } else { $null }
                LastSeen = [string]$entry.LastSeen
            }
        }

        ConvertTo-Json -InputObject @($rows) -Depth 4 | Set-Content -LiteralPath $script:LongContextAlertPath -Encoding UTF8
    } catch {
        Write-BuddyCrashLog $_
    }
}

function Import-LongContextAlertLedger {
    $script:LongContextAlerts = @{}
    if (-not (Test-Path -LiteralPath $script:LongContextAlertPath)) {
        return
    }

    try {
        $raw = Get-Content -LiteralPath $script:LongContextAlertPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        foreach ($item in @($raw)) {
            $key = Get-JsonValue -Object $item -Name "Key"
            if ([string]::IsNullOrWhiteSpace([string]$key)) {
                continue
            }

            $script:LongContextAlerts[[string]$key] = @{
                Count = [Math]::Max(0, [int](Get-JsonValue -Object $item -Name "Count"))
                PendingCount = [Math]::Max(0, [int](Get-JsonValue -Object $item -Name "PendingCount"))
                WasOver = [bool](Get-JsonValue -Object $item -Name "WasOver")
                Model = [string](Get-JsonValue -Object $item -Name "Model")
                SessionId = [string](Get-JsonValue -Object $item -Name "SessionId")
                LastInputTokens = Get-JsonValue -Object $item -Name "LastInputTokens"
                LastSeen = [string](Get-JsonValue -Object $item -Name "LastSeen")
            }
        }
    } catch {
        Write-BuddyCrashLog $_
        $script:LongContextAlerts = @{}
    }
}

function Get-LongContextAlertKey {
    param(
        $Session,
        [string]$ModelLabel,
        [string]$Kind = "price"
    )

    $sessionId = if ($Session -and $Session.PriceGuardSessionId) { [string]$Session.PriceGuardSessionId } elseif ($Session -and $Session.SessionId) { [string]$Session.SessionId } else { "unknown" }
    $model = if ($ModelLabel) { $ModelLabel } elseif ($Session -and $Session.PriceGuardModel) { [string]$Session.PriceGuardModel } elseif ($Session -and $Session.ActiveModel) { [string]$Session.ActiveModel } else { "unknown" }
    return ("{0}|{1}|{2}" -f $Kind, $sessionId, $model)
}

function Get-LongContextAlertSummary {
    $pending = 0
    $total = 0
    foreach ($key in @($script:LongContextAlerts.Keys)) {
        $entry = $script:LongContextAlerts[$key]
        $pending += [Math]::Max(0, [int]$entry.PendingCount)
        $total += [Math]::Max(0, [int]$entry.Count)
    }

    return [pscustomobject]@{
        PendingCount = $pending
        TotalCount = $total
    }
}

function Update-LongContextAlertLedger {
    param(
        $Session,
        $PriceGuard,
        [string]$ModelLabel
    )

    if (-not $Session -or -not $PriceGuard) {
        return Get-LongContextAlertSummary
    }

    $contextWindow = if ($null -ne $Session.ContextWindow) { [double]$Session.ContextWindow } else { 0.0 }
    $contextOver = (($contextWindow -gt 0 -and $null -ne $Session.LastInputTokens -and [double]$Session.LastInputTokens -ge $contextWindow) -or ($null -ne $Session.ContextUsedPercent -and [double]$Session.ContextUsedPercent -ge 100.0))
    $priceOver = ($PriceGuard.State -eq "over")
    $alertKind = if (-not $ModelLabel -or ($contextOver -and -not $priceOver)) { "context" } else { "price" }
    $key = Get-LongContextAlertKey -Session $Session -ModelLabel $ModelLabel -Kind $alertKind
    if (($PriceGuard.State -eq "off" -or $PriceGuard.State -eq "wait") -and -not $contextOver) {
        if ($script:LongContextAlerts.ContainsKey($key) -and [bool]$script:LongContextAlerts[$key].WasOver) {
            $script:LongContextAlerts[$key].WasOver = $false
            Save-LongContextAlertLedger
        }
        return Get-LongContextAlertSummary
    }

    if (-not $script:LongContextAlerts.ContainsKey($key)) {
        $script:LongContextAlerts[$key] = @{
            Count = 0
            PendingCount = 0
            WasOver = $false
            Model = if ($ModelLabel) { $ModelLabel } elseif ($Session.ActiveModel) { [string]$Session.ActiveModel } else { "unknown" }
            SessionId = if ($Session.PriceGuardSessionId) { [string]$Session.PriceGuardSessionId } else { [string]$Session.SessionId }
            LastInputTokens = $null
            LastSeen = ""
        }
    }

    $entry = $script:LongContextAlerts[$key]
    $dirty = $false
    $isOver = ($priceOver -or $contextOver)
    if ($isOver -and -not [bool]$entry.WasOver) {
        $entry.Count = [int]$entry.Count + 1
        $entry.PendingCount = [int]$entry.PendingCount + 1
        $dirty = $true
    }

    if ([bool]$entry.WasOver -ne $isOver) {
        $entry.WasOver = $isOver
        $dirty = $true
    }

    if ($null -ne $Session.LastInputTokens) {
        $entry.LastInputTokens = [double]$Session.LastInputTokens
    }
    $entry.LastSeen = (Get-Date).ToString("o")
    if ($dirty) {
        Save-LongContextAlertLedger
    }

    return Get-LongContextAlertSummary
}

function Accept-LongContextAlerts {
    $changed = $false
    foreach ($key in @($script:LongContextAlerts.Keys)) {
        $entry = $script:LongContextAlerts[$key]
        if ([int]$entry.PendingCount -gt 0) {
            $entry.PendingCount = 0
            $changed = $true
        }
    }

    if ($changed) {
        Save-LongContextAlertLedger
    }

    return Get-LongContextAlertSummary
}

function Format-Reset {
    param($UnixSeconds)

    if ($null -eq $UnixSeconds) {
        return "n/a"
    }

    try {
        $reset = [DateTimeOffset]::FromUnixTimeSeconds([int64]$UnixSeconds).LocalDateTime
        $left = $reset - (Get-Date)
        if ($left.TotalSeconds -le 0) {
            return "now"
        }

        if ($left.TotalHours -ge 1) {
            return ("{0}h {1}m" -f [int]$left.TotalHours, $left.Minutes)
        }

        return ("{0}m {1}s" -f [int]$left.TotalMinutes, $left.Seconds)
    } catch {
        return "n/a"
    }
}

function Shorten-Model {
    param([string]$Model)

    if ([string]::IsNullOrWhiteSpace($Model)) {
        return "unknown"
    }

    if ($Model -like "*spark*") {
        return "spark"
    }

    $modelKey = $Model.ToLowerInvariant()
    if ($modelKey -like "*gpt-5.6-sol*") { return "GPT-5.6 Sol" }
    if ($modelKey -like "*gpt-5.6-terra*") { return "GPT-5.6 Terra" }
    if ($modelKey -like "*gpt-5.6-luna*") { return "GPT-5.6 Luna" }
    if ($modelKey -like "*gpt-5.5-pro*") { return "GPT-5.5 Pro" }
    if ($modelKey -like "*gpt-5.5*") { return "GPT-5.5" }
    if ($modelKey -like "*gpt-5.4-mini*") { return "GPT-5.4 Mini" }
    if ($modelKey -like "*gpt-5.4-pro*") { return "GPT-5.4 Pro" }
    if ($modelKey -like "*gpt-5.4*") { return "GPT-5.4" }

    return $Model
}

function Convert-FromUnixSeconds {
    param($UnixSeconds)

    if ($null -eq $UnixSeconds) {
        return $null
    }

    try {
        return [DateTimeOffset]::FromUnixTimeSeconds([int64]$UnixSeconds).LocalDateTime
    } catch {
        return $null
    }
}

function Get-UsageProfileKey {
    param([string]$Model)

    if ([string]::IsNullOrWhiteSpace($Model)) {
        return "unknown"
    }

    if ($Model -like "*spark*") {
        return "spark"
    }

    return "codex"
}

function Get-UsageProfileLabel {
    param([string]$ProfileKey)

    if ([string]::IsNullOrWhiteSpace($ProfileKey)) {
        return "unknown"
    }

    switch ($ProfileKey) {
        "spark" { return "spark" }
        "codex" { return "codex" }
        default { return $ProfileKey }
    }
}

function Get-RateLimitWindowMinutes {
    param($Limit)

    if (-not $Limit) {
        return $null
    }

    $rawMinutes = Get-JsonValue -Object $Limit "window_minutes"
    if ($null -eq $rawMinutes) {
        return $null
    }

    try {
        $minutes = [int]$rawMinutes
        if ($minutes -gt 0) {
            return $minutes
        }
    } catch {}

    return $null
}

function Split-RateLimitSlots {
    param(
        $PrimaryLimit,
        $SecondaryLimit
    )

    $limits = @(@($PrimaryLimit, $SecondaryLimit) | Where-Object { $_ })
    if ($limits.Count -eq 0) {
        return [pscustomobject]@{ Primary = $null; Secondary = $null }
    }

    $knownWindows = @($limits | Where-Object { $null -ne (Get-RateLimitWindowMinutes $_) })
    if ($knownWindows.Count -eq 0) {
        return [pscustomobject]@{ Primary = $PrimaryLimit; Secondary = $SecondaryLimit }
    }

    $shortWindow = @($knownWindows | Where-Object { (Get-RateLimitWindowMinutes $_) -le 720 } | Sort-Object { Get-RateLimitWindowMinutes $_ } | Select-Object -First 1)
    $longWindow = @($knownWindows | Where-Object { (Get-RateLimitWindowMinutes $_) -gt 720 } | Sort-Object { Get-RateLimitWindowMinutes $_ } -Descending | Select-Object -First 1)

    return [pscustomobject]@{
        Primary = if ($shortWindow.Count -gt 0) { $shortWindow[0] } else { $null }
        Secondary = if ($longWindow.Count -gt 0) { $longWindow[0] } else { $null }
    }
}

function Get-RateLimitWindowLabel {
    param(
        $WindowMinutes,
        [string]$Fallback = "Limit"
    )

    if ($null -eq $WindowMinutes -or [int]$WindowMinutes -le 0) {
        return $Fallback
    }

    $minutes = [int]$WindowMinutes
    if ($minutes -ge 10080) {
        return "Week Limit"
    }
    if ($minutes -ge 1440) {
        return ("{0}d Limit" -f [Math]::Round($minutes / 1440.0, 1))
    }
    if (($minutes % 60) -eq 0) {
        return ("{0}h Limit" -f [int]($minutes / 60))
    }
    return ("{0}m Limit" -f $minutes)
}

function Get-RateLimitWindowShortLabel {
    param(
        $WindowMinutes,
        [string]$Fallback = "n/a"
    )

    if ($null -eq $WindowMinutes -or [int]$WindowMinutes -le 0) {
        return $Fallback
    }

    $minutes = [int]$WindowMinutes
    if ($minutes -ge 10080) {
        return "wk"
    }
    if ($minutes -ge 1440) {
        return ("{0}d" -f [Math]::Round($minutes / 1440.0, 1))
    }
    if (($minutes % 60) -eq 0) {
        return ("{0}h" -f [int]($minutes / 60))
    }
    return ("{0}m" -f $minutes)
}

function Get-SessionStatusRank {
    param([string]$Status)

    switch ($Status) {
        "active" { return 3 }
        "warm" { return 2 }
        "idle" { return 1 }
        default { return 0 }
    }
}

function Select-PreferredUsageSession {
    param([array]$Sessions)

    $best = $null
    foreach ($session in @($Sessions)) {
        if (-not $session) {
            continue
        }

        if (-not $best) {
            $best = $session
            continue
        }

        $sessionRank = Get-SessionStatusRank $session.Status
        $bestRank = Get-SessionStatusRank $best.Status
        if ($sessionRank -gt $bestRank) {
            $best = $session
            continue
        }
        if ($sessionRank -lt $bestRank) {
            continue
        }

        $sessionHasToken = ($null -ne $session.LastTokenEventTime)
        $bestHasToken = ($null -ne $best.LastTokenEventTime)
        if ($sessionHasToken -and -not $bestHasToken) {
            $best = $session
            continue
        }
        if (-not $sessionHasToken -and $bestHasToken) {
            continue
        }

        if ($sessionHasToken -and $bestHasToken) {
            if ([datetime]$session.LastTokenEventTime -gt [datetime]$best.LastTokenEventTime) {
                $best = $session
                continue
            }
            if ([datetime]$session.LastTokenEventTime -lt [datetime]$best.LastTokenEventTime) {
                continue
            }
        }

        $sessionProfile = Get-UsageProfileKey $session.ActiveModel
        $bestProfile = Get-UsageProfileKey $best.ActiveModel
        if ($bestProfile -eq "spark" -and $sessionProfile -ne "spark") {
            $best = $session
            continue
        }
        if ($sessionProfile -eq "spark" -and $bestProfile -ne "spark") {
            continue
        }

        if ($session.LastWrite -gt $best.LastWrite) {
            $best = $session
        }
    }

    return $best
}

function Get-DistinctUsageSessions {
    param([array]$Sessions)

    $groups = @{}
    foreach ($session in @($Sessions)) {
        if (-not $session) {
            continue
        }

        $sessionKey = if ($session.SessionId -and ([string]$session.SessionId -ne "unknown")) {
            ([string]$session.SessionId).ToLowerInvariant()
        } else {
            $cwdKey = if ([string]::IsNullOrWhiteSpace($session.Cwd)) { "unknown" } else { ([string]$session.Cwd).ToLowerInvariant() }
            $profileKey = if ($session.UsageProfileKey) { [string]$session.UsageProfileKey } else { Get-UsageProfileKey $session.ActiveModel }
            "{0}|{1}" -f $cwdKey, $profileKey
        }
        $groupKey = "session|$sessionKey"
        if (-not $groups.ContainsKey($groupKey)) {
            $groups[$groupKey] = New-Object System.Collections.Generic.List[object]
        }
        $groups[$groupKey].Add($session)
    }

    $result = New-Object System.Collections.Generic.List[object]
    foreach ($group in $groups.Values) {
        $picked = Select-PreferredUsageSession -Sessions $group.ToArray()
        if ($picked) {
            $result.Add($picked)
        }
    }

    return @($result.ToArray())
}

function Format-UsageProfilesSummary {
    param([array]$Sessions)

    $profiles = @{}
    foreach ($session in @($Sessions)) {
        if (-not $session) {
            continue
        }

        $profileKey = Get-UsageProfileKey $session.ActiveModel
        if (-not $profiles.ContainsKey($profileKey)) {
            $profiles[$profileKey] = New-Object System.Collections.Generic.List[object]
        }
        $profiles[$profileKey].Add($session)
    }

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($profileKey in @("codex", "spark", "unknown")) {
        if (-not $profiles.ContainsKey($profileKey)) {
            continue
        }

        $profileSession = Select-PreferredUsageSession -Sessions $profiles[$profileKey].ToArray()
        if (-not $profileSession) {
            continue
        }

        $weeklyOnly = ($null -eq $profileSession.PrimaryWindowMinutes -and $null -ne $profileSession.SecondaryWindowMinutes)
        if ($weeklyOnly) {
            $weeklyText = if ($null -ne $profileSession.SecondaryRemainingPercent) { "{0}% {1}" -f $profileSession.SecondaryRemainingPercent, (Get-RateLimitWindowShortLabel -WindowMinutes $profileSession.SecondaryWindowMinutes -Fallback "wk") } else { "n/a wk" }
            $parts.Add(("{0} {1}" -f (Get-UsageProfileLabel $profileKey), $weeklyText))
            continue
        }

        $primaryWindowText = Get-RateLimitWindowShortLabel -WindowMinutes $profileSession.PrimaryWindowMinutes -Fallback "usage"
        $secondaryWindowText = Get-RateLimitWindowShortLabel -WindowMinutes $profileSession.SecondaryWindowMinutes -Fallback "additional"
        $primaryText = if ($null -ne $profileSession.PrimaryRemainingPercent) { "{0}% {1}" -f $profileSession.PrimaryRemainingPercent, $primaryWindowText } else { "n/a {0}" -f $primaryWindowText }
        $secondaryText = if ($null -ne $profileSession.SecondaryRemainingPercent) { "{0}% {1}" -f $profileSession.SecondaryRemainingPercent, $secondaryWindowText } else { "n/a {0}" -f $secondaryWindowText }
        $parts.Add(("{0} {1} {2}" -f (Get-UsageProfileLabel $profileKey), $primaryText, $secondaryText))
    }

    return ($parts -join " | ")
}

function Short-SessionId {
    param([string]$Id)

    if ([string]::IsNullOrWhiteSpace($Id)) {
        return "unknown"
    }

    if ($Id.Length -gt 8) {
        return $Id.Substring(0, 8)
    }

    return $Id
}

function Short-Cwd {
    param([string]$Cwd)

    if ([string]::IsNullOrWhiteSpace($Cwd)) {
        return "unknown"
    }

    try {
        $leaf = Split-Path -Path $Cwd -Leaf
        if ([string]::IsNullOrWhiteSpace($leaf)) {
            return $Cwd
        }

        return $leaf
    } catch {
        return $Cwd
    }
}

function Format-RelativeAge {
    param([nullable[double]]$Seconds)

    if ($null -eq $Seconds) {
        return "unknown"
    }

    $totalSeconds = [Math]::Max(0, [int][Math]::Round($Seconds))
    if ($totalSeconds -lt 60) {
        return ("{0}s" -f $totalSeconds)
    }

    $minutes = [int][Math]::Floor($totalSeconds / 60)
    if ($minutes -lt 60) {
        return ("{0}m" -f $minutes)
    }

    $hours = [int][Math]::Floor($minutes / 60)
    $remainingMinutes = $minutes % 60
    if ($hours -lt 24) {
        return if ($remainingMinutes -gt 0) { ("{0}h {1}m" -f $hours, $remainingMinutes) } else { ("{0}h" -f $hours) }
    }

    $days = [int][Math]::Floor($hours / 24)
    $remainingHours = $hours % 24
    if ($remainingHours -gt 0) {
        return ("{0}d {1}h" -f $days, $remainingHours)
    }

    return ("{0}d" -f $days)
}

function Short-Text {
    param(
        [string]$Value,
        [int]$Max = 12
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "unknown"
    }

    if ($Value.Length -le $Max) {
        return $Value
    }

    return ($Value.Substring(0, $Max - 1) + "~")
}

function Get-SessionCandidateFiles {
    param(
        [string]$Root,
        [int]$DaysBack = 14,
        [hashtable]$State = $null
    )

    $now = Get-Date
    if ($State) {
        if (-not $State.ContainsKey("CandidateFiles")) {
            $State.CandidateFiles = @()
        }

        if (-not $State.ContainsKey("CandidateScan")) {
            $State.CandidateScan = [datetime]::MinValue
        }

        if (($now - $State.CandidateScan).TotalSeconds -lt 12) {
            return @($State.CandidateFiles | Where-Object { $_ } | ForEach-Object { try { $_.Refresh() } catch {}; $_ } | Where-Object { $_.Exists })
        }
    }

    $sessionRoot = Join-Path $Root "sessions"
    if (-not (Test-Path -LiteralPath $sessionRoot)) {
        if ($State) {
            $State.CandidateFiles = @()
            $State.CandidateScan = $now
        }
        return @()
    }

    $files = @()
    for ($i = 0; $i -le $DaysBack; $i++) {
        $day = $now.Date.AddDays(-$i)
        $dayRoot = Join-Path $sessionRoot (Join-Path ($day.ToString("yyyy")) (Join-Path ($day.ToString("MM")) ($day.ToString("dd"))))
        if (Test-Path -LiteralPath $dayRoot) {
            $files += @(Get-ChildItem -LiteralPath $dayRoot -Filter "*.jsonl" -File -ErrorAction SilentlyContinue)
        }
    }

    if ($files.Count -gt 0) {
        if ($State) {
            $State.CandidateFiles = @($files)
            $State.CandidateScan = $now
        }
        return $files
    }

    $fallback = @(Get-ChildItem -LiteralPath $sessionRoot -Recurse -Filter "*.jsonl" -File -ErrorAction SilentlyContinue)
    if ($State) {
        $State.CandidateFiles = @($fallback)
        $State.CandidateScan = $now
    }

    return $fallback
}

function Get-RecentSessionPaths {
    param(
        [string]$Root,
        [int]$Max = 5,
        [int]$ActiveSeconds = 90,
        [hashtable]$State = $null
    )

    $sessionRoot = Join-Path $Root "sessions"
    if (-not (Test-Path -LiteralPath $sessionRoot)) {
        return @()
    }

    $now = Get-Date
    $all = Get-SessionCandidateFiles -Root $Root -State $State |
        Sort-Object LastWriteTime -Descending

    $active = @($all | Where-Object { (($now) - $_.LastWriteTime).TotalSeconds -lt $ActiveSeconds } | Select-Object -First $Max)

    return @($active | ForEach-Object { $_.FullName })
}

function Get-SessionConversationKey {
    param(
        [string]$Path,
        [hashtable]$State = $null
    )

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item) {
        return $Path
    }

    if ($State) {
        if (-not $State.ContainsKey("SessionKeyCache")) {
            $State.SessionKeyCache = @{}
        }

        $cached = if ($State.SessionKeyCache.ContainsKey($Path)) { $State.SessionKeyCache[$Path] } else { $null }
        if ($cached) {
            return $cached.Key
        }
    }

    $firstLine = Get-Content -LiteralPath $Path -TotalCount 1 -ErrorAction SilentlyContinue
    $meta = Convert-FromJsonLine $firstLine
    $payload = if ($meta) { Get-JsonValue $meta "payload" } else { $null }
    $sessionId = Get-JsonValue $payload "session_id"
    if (-not $sessionId) {
        $sessionId = Get-JsonValue $payload "id"
    }
    if ($sessionId) {
        $key = ([string]$sessionId).ToLowerInvariant()
        if ($State) {
            $State.SessionKeyCache[$Path] = [pscustomobject]@{
                Key = $key
                Length = [int64]$item.Length
                LastWriteTime = $item.LastWriteTime
                CachedAt = Get-Date
            }
        }
        return $key
    }

    if ($State) {
        $State.SessionKeyCache[$Path] = [pscustomobject]@{
            Key = $Path
            Length = [int64]$item.Length
            LastWriteTime = $item.LastWriteTime
            CachedAt = Get-Date
        }
    }

    return $Path
}

function Get-CollapsedSessionPaths {
    param(
        [array]$Paths,
        [hashtable]$State = $null
    )

    $rows = @()
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        $item = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
        if (-not $item) {
            continue
        }

        $rows += [pscustomobject]@{
            Path = [string]$path
            Key = Get-SessionConversationKey -Path $path -State $State
            LastWrite = $item.LastWriteTime
        }
    }

    $collapsed = @()
    foreach ($group in ($rows | Group-Object Key)) {
        $ordered = @($group.Group | Sort-Object LastWrite -Descending)
        if ($ordered.Count -eq 0) {
            continue
        }

        $newest = $ordered[0]
        $collapsed += $newest.Path
    }

    return @($collapsed | Select-Object -Unique)
}

function Get-SessionTabLabel {
    param(
        [string]$Path,
        [hashtable]$State = $null
    )

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item) {
        return "unknown - unknown"
    }

    $project = $null
    if ($State) {
        if (-not $State.ContainsKey("SessionLabelCache")) {
            $State.SessionLabelCache = @{}
        }

        $cached = if ($State.SessionLabelCache.ContainsKey($Path)) { $State.SessionLabelCache[$Path] } else { $null }
        if ($cached -and ($cached.Length -eq [int64]$item.Length) -and ($cached.LastWriteTime -eq $item.LastWriteTime)) {
            $project = $cached.Project
        }
    }

    if (-not $project) {
        $firstLine = Get-Content -LiteralPath $Path -TotalCount 1 -ErrorAction SilentlyContinue
        $meta = Convert-FromJsonLine $firstLine
        $payload = if ($meta) { Get-JsonValue $meta "payload" } else { $null }
        $cwd = Get-JsonValue $payload "cwd"
        $project = if ($cwd) { Short-Text (Short-Cwd ([string]$cwd)) 10 } else { "unknown" }
        if ($State) {
            $State.SessionLabelCache[$Path] = [pscustomobject]@{
                Project = $project
                Length = [int64]$item.Length
                LastWriteTime = $item.LastWriteTime
                CachedAt = Get-Date
            }
        }
    }

    $ageText = Format-RelativeAge ((Get-Date) - $item.LastWriteTime).TotalSeconds
    return ("{0} {1}" -f $project, $ageText)
}

function Get-JsonValue {
    param(
        $Object,
        [string]$Name
    )

    if (-not $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }

    return $null
}

function Add-HistoryPoint {
    param(
        $History,
        [nullable[double]]$Value,
        [int]$Limit = 90
    )

    if ($null -eq $Value) {
        return
    }

    $History.Add([double]$Value)
    while ($History.Count -gt $Limit) {
        $History.RemoveAt(0)
    }
}

function Smooth-GraphValue {
    param(
        [double]$Previous,
        [double]$Current,
        [double]$AgeSeconds = 0,
        [double]$RiseAlpha = 0.55,
        [double]$FallAlpha = 0.20,
        [double]$Decay = 0.84,
        [double]$HoldSeconds = 4
    )

    if ($Current -le 0 -and $Previous -gt 0) {
        if ($AgeSeconds -le $HoldSeconds) {
            return [Math]::Max(0, $Previous * 0.97)
        }

        return [Math]::Max(0, $Previous * $Decay)
    }

    if ($Current -gt 0 -and $Previous -gt 0) {
        $alpha = if ($Current -ge $Previous) { $RiseAlpha } else { $FallAlpha }
        return [Math]::Max(0, $Previous + (($Current - $Previous) * $alpha))
    }

    if ($Current -gt 0) {
        return [Math]::Max(0, $Current)
    }

    return 0.0
}

function Update-StableScale {
    param(
        [double]$Scale,
        [double]$Current,
        [double]$Floor,
        [double]$UpTargetPercent = 95,
        [double]$DownTargetPercent = 90,
        [double]$Decay = 0.97,
        [int]$DropSeconds = 30,
        [datetime]$Now,
        [datetime]$LastDropAt
    )

    if ($Scale -lt $Floor) {
        $Scale = $Floor
    }

    if ($Current -le 0) {
        if ($LastDropAt -eq [datetime]::MinValue -or ($Now - $LastDropAt).TotalSeconds -ge $DropSeconds) {
            $Scale = [Math]::Max($Floor, $Scale * $Decay)
            $LastDropAt = $Now
        }

        return [pscustomobject]@{
            Scale = $Scale
            LastDropAt = $LastDropAt
        }
    }

    $upTarget = [Math]::Max($Floor, $Current / ($UpTargetPercent / 100.0))
    if ($Current -ge $Scale) {
        $Scale = [Math]::Max($Scale * 1.05, $upTarget)
        return [pscustomobject]@{
            Scale = $Scale
            LastDropAt = $LastDropAt
        }
    }

    if ($LastDropAt -eq [datetime]::MinValue -or ($Now - $LastDropAt).TotalSeconds -ge $DropSeconds) {
        $downTarget = [Math]::Max($Floor, $Current / ($DownTargetPercent / 100.0))
        $Scale = [Math]::Max($downTarget, $Scale * $Decay)
        $LastDropAt = $Now
    }

    return [pscustomobject]@{
        Scale = $Scale
        LastDropAt = $LastDropAt
    }
}

function Get-SessionMetrics {
    param(
        [string]$Path,
        [hashtable]$State,
        [double]$CacheSeconds = 1.0,
        [int]$TailLines = 720
    )

    $file = Get-Item -LiteralPath $Path -ErrorAction Stop
    $now = Get-Date
    if (-not $State.ContainsKey("SessionMetricsCache")) {
        $State.SessionMetricsCache = @{}
    }

    $cachedMetrics = if ($State.SessionMetricsCache.ContainsKey($Path)) { $State.SessionMetricsCache[$Path] } else { $null }
    if ($cachedMetrics -and (($now - $cachedMetrics.CachedAt).TotalSeconds -lt $CacheSeconds)) {
        return $cachedMetrics.Session
    }

    if ($cachedMetrics -and $cachedMetrics.Length -eq [int64]$file.Length -and $cachedMetrics.LastWriteTime -eq $file.LastWriteTime -and (($now - $cachedMetrics.CachedAt).TotalSeconds -lt 12)) {
        return $cachedMetrics.Session
    }

    $lines = Get-FileTailLines -Path $Path -LineCount $TailLines
    if (-not $State.ContainsKey("SessionUsageCache")) {
        $State.SessionUsageCache = @{}
    }

    if ($State.MetaPath -ne $Path -or -not $State.Meta) {
        $firstLine = Get-Content -LiteralPath $Path -TotalCount 1 -ErrorAction SilentlyContinue
        $State.Meta = Convert-FromJsonLine $firstLine
        $State.MetaPath = $Path
    }

    $meta = $State.Meta
    $metaPayload = if ($meta) { Get-JsonValue -Object $meta "payload" } else { $null }
    $windowStart = $now.AddSeconds(-60)

    $tokenEvent = $null
    $tokenByModel = @{}
    $tokenByProfile = @{}
    $limitEvent = $null
    $limitByModel = @{}
    $limitByProfile = @{}
    $lastEvent = $null
    $lastTool = $null
    $activeModel = $null
    $serviceTier = Get-CodexConfigServiceTier -Root $CodexHome -State $State
    $timestamps = New-Object System.Collections.Generic.List[datetime]
    $toolCalls = 0
    $toolOutputs = 0
    $assistantMessages = 0
    $userMessages = 0
    $parsedEvents = 0
    $toolNameCounts = @{}
    $lastPromptStartedTime = $null
    $lastPromptText = $null
    $lastTaskStartedTime = $null
    $lastTaskCompleteTime = $null
    $lastTaskTurnId = $null
    $lastTaskDurationMs = $null
    $lastTaskTimeToFirstTokenMs = $null
    $lastTaskAgentMessage = $null
    $lastTaskModelContextWindow = $null
    $lastTaskCollaborationMode = $null
    $recentTaskDurationsMs = New-Object 'System.Collections.Generic.List[double]'
    $recentTaskTimeToFirstTokenMs = New-Object 'System.Collections.Generic.List[double]'
    $lastPromptClientId = $null
    $lastPromptImageCount = 0
    $lastPromptLocalImageCount = 0
    $lastPromptTextElementCount = 0
    $lastTurnId = $null
    $lastTurnEffort = $null
    $lastTurnApprovalPolicy = $null
    $lastTurnRealtimeActive = $null
    $lastTurnWorkspaceRoots = @()
    $lastTurnCurrentDate = $null
    $lastTurnTimezone = $null
    $lastTurnCollaborationMode = $null
    $recentCompactionEvents = 0
    $lastCompactionWindowId = $null
    $tokensLastMinuteRaw = 0.0
    $outputTokensLastMinuteRaw = 0.0
    $tokensPerSecondRaw = 0.0
    $outputTokensPerSecondRaw = 0.0
    $tokenEventsLastMinute = 0
    $lastTokenEventTime = $null
    $tokenRatePoints = New-Object 'System.Collections.Generic.List[object]'
    if (-not $State.ContainsKey("SessionPromptUseCache")) {
        $State.SessionPromptUseCache = @{}
    }
    $promptUse = if ($State.SessionPromptUseCache.ContainsKey($Path)) { $State.SessionPromptUseCache[$Path] } else { $null }
    if (-not $promptUse -or ([int64]$promptUse.FileLength -gt [int64]$file.Length)) {
        $promptUse = [pscustomobject]@{
            FileLength = [int64]$file.Length
            PromptTotals = @{}
            PromptInputs = @{}
            PromptOutputs = @{}
            PromptCachedInputs = @{}
            PromptCacheWrites = @{}
            PromptReasoning = @{}
            PromptCosts = @{}
            PromptContexts = @{}
            PromptOrders = @{}
            PromptModels = @{}
            PromptServiceTiers = @{}
            PromptPrimaryUsedPercents = @{}
            LastPromptKey = "session-start"
        }
        $State.SessionPromptUseCache[$Path] = $promptUse
        # A complete historical scan can freeze WinForms on very large chats.
        # Keep prompt history to the caller's recent-event window; live updates
        # overwrite the same keys as Codex writes new token events.
        $lines = Get-FileTailLines -Path $Path -LineCount $TailLines
    } else {
        $promptUse.FileLength = [int64]$file.Length
        if (-not ($promptUse.PSObject.Properties.Name -contains "PromptServiceTiers")) {
            $promptUse | Add-Member -NotePropertyName PromptServiceTiers -NotePropertyValue @{}
        }
        if (-not ($promptUse.PSObject.Properties.Name -contains "PromptCacheWrites")) {
            $promptUse | Add-Member -NotePropertyName PromptCacheWrites -NotePropertyValue @{}
        }
    }
    $currentPromptKey = [string]$promptUse.LastPromptKey

    foreach ($line in $lines) {
        $entry = Convert-FromJsonLine $line
        if (-not $entry) {
            continue
        }

        $parsedEvents++

        $entryType = Get-JsonValue -Object $entry "type"
        $payload = Get-JsonValue -Object $entry "payload"
        $payloadType = Get-JsonValue -Object $payload "type"
        $entryServiceTier = Get-ServiceTierFromObject -Object $payload
        if (-not $entryServiceTier) {
            $entryServiceTier = Get-ServiceTierFromObject -Object $entry
        }
        if ($entryServiceTier) {
            $serviceTier = [string]$entryServiceTier
        }
        $entryTime = $null
        try {
            $timestamp = Get-JsonValue -Object $entry "timestamp"
            if ($timestamp) {
                $entryTime = ([datetime]$timestamp).ToLocalTime()
                $timestamps.Add($entryTime)
            }
        } catch {}

        $lastEvent = $entry

        if ($entryType -eq "compacted") {
            $recentCompactionEvents++
            $lastCompactionWindowId = Get-JsonValue -Object $payload "window_id"
        }

        if ($entryType -eq "event_msg") {
            if ($payloadType -eq "task_started") {
                $lastTaskStartedTime = Convert-FromUnixSeconds (Get-JsonValue -Object $payload "started_at")
                if (-not $lastTaskStartedTime) { $lastTaskStartedTime = $entryTime }
                $lastTaskTurnId = Get-JsonValue -Object $payload "turn_id"
                $lastTaskModelContextWindow = Get-JsonValue -Object $payload "model_context_window"
                $lastTaskCollaborationMode = Get-JsonValue -Object $payload "collaboration_mode_kind"
            } elseif ($payloadType -eq "task_complete") {
                $lastTaskCompleteTime = Convert-FromUnixSeconds (Get-JsonValue -Object $payload "completed_at")
                if (-not $lastTaskCompleteTime) { $lastTaskCompleteTime = $entryTime }
                $lastTaskStartedTime = Convert-FromUnixSeconds (Get-JsonValue -Object $payload "started_at")
                if (-not $lastTaskStartedTime) { $lastTaskStartedTime = $entryTime }
                $lastTaskTurnId = Get-JsonValue -Object $payload "turn_id"
                $lastTaskDurationMs = Convert-ToNullableDouble (Get-JsonValue -Object $payload "duration_ms")
                $lastTaskTimeToFirstTokenMs = Convert-ToNullableDouble (Get-JsonValue -Object $payload "time_to_first_token_ms")
                $lastTaskAgentMessage = Get-JsonValue -Object $payload "last_agent_message"
                if ($null -ne $lastTaskDurationMs -and $lastTaskDurationMs -ge 0) {
                    $recentTaskDurationsMs.Add([double]$lastTaskDurationMs)
                }
                if ($null -ne $lastTaskTimeToFirstTokenMs -and $lastTaskTimeToFirstTokenMs -ge 0) {
                    $recentTaskTimeToFirstTokenMs.Add([double]$lastTaskTimeToFirstTokenMs)
                }
            } elseif ($payloadType -eq "user_message") {
                $messageText = Get-JsonValue -Object $payload "message"
                if ($messageText) {
                    $lastPromptText = [string]$messageText
                }
                $lastPromptClientId = Get-JsonValue -Object $payload "client_id"
                $lastPromptImageCount = @((Get-JsonValue -Object $payload "images")).Count
                $lastPromptLocalImageCount = @((Get-JsonValue -Object $payload "local_images")).Count
                $lastPromptTextElementCount = @((Get-JsonValue -Object $payload "text_elements")).Count
            }
        }

        if ($entryType -eq "event_msg" -and $payloadType -eq "token_count") {
            $limitEvent = $entry
            if ($activeModel) {
                $tokenByModelKey = [string]$activeModel
                $tokenByProfileKey = Get-UsageProfileKey $activeModel
                $limitByModel[$tokenByModelKey] = $entry
                $limitByProfile[$tokenByProfileKey] = $entry
            }

            $entryInfo = Get-JsonValue -Object $payload "info"
            $entryUsage = Get-JsonValue -Object $entryInfo "total_token_usage"
            $entryLastUsage = Get-JsonValue -Object $entryInfo "last_token_usage"
            $entryHasUsage = ($null -ne (Get-JsonValue -Object $entryUsage "total_tokens")) -and ($null -ne (Get-JsonValue -Object $entryLastUsage "total_tokens"))
            if ($entryHasUsage) {
                $tokenEvent = $entry
                if ($entryTime) {
                    $lastTokenEventTime = $entryTime
                }
                $entryLastTokensForTotal = Get-JsonValue -Object $entryLastUsage "total_tokens"
                if ($null -ne $entryLastTokensForTotal) {
                    $entryLastInputForTotal = Get-JsonValue -Object $entryLastUsage "input_tokens"
                    $entryLastOutputForTotal = Get-JsonValue -Object $entryLastUsage "output_tokens"
                    $entryLastCachedForTotal = Get-JsonValue -Object $entryLastUsage "cached_input_tokens"
                    $entryLastCacheWriteForTotal = Get-JsonValue -Object $entryLastUsage "cache_write_input_tokens"
                    $entryLastReasoningForTotal = Get-JsonValue -Object $entryLastUsage "reasoning_output_tokens"
                    if ([string]::IsNullOrWhiteSpace($currentPromptKey)) {
                        $currentPromptKey = "session-start"
                    }
                    $promptUse.PromptTotals[$currentPromptKey] = [double]$entryLastTokensForTotal
                    if ($null -ne $entryLastInputForTotal) {
                        $promptUse.PromptInputs[$currentPromptKey] = [double]$entryLastInputForTotal
                    }
                    if ($null -ne $entryLastOutputForTotal) {
                        $promptUse.PromptOutputs[$currentPromptKey] = [double]$entryLastOutputForTotal
                    }
                    if ($null -ne $entryLastCachedForTotal) {
                        $promptUse.PromptCachedInputs[$currentPromptKey] = [double]$entryLastCachedForTotal
                    }
                    if ($null -ne $entryLastCacheWriteForTotal) {
                        $promptUse.PromptCacheWrites[$currentPromptKey] = [double]$entryLastCacheWriteForTotal
                    }
                    if ($null -ne $entryLastReasoningForTotal) {
                        $promptUse.PromptReasoning[$currentPromptKey] = [double]$entryLastReasoningForTotal
                    }
                    $promptUse.PromptCosts[$currentPromptKey] = Get-PromptCostUnits -InputTokens $entryLastInputForTotal -CachedInputTokens $entryLastCachedForTotal -CacheWriteInputTokens $entryLastCacheWriteForTotal -OutputTokens $entryLastOutputForTotal -ReasoningTokens $entryLastReasoningForTotal -Model $activeModel
                    $entryContextWindowForTotal = Get-JsonValue -Object $entryInfo "model_context_window"
                    if ($null -ne $entryLastInputForTotal -and $null -ne $entryContextWindowForTotal -and [double]$entryContextWindowForTotal -gt 0) {
                        $promptUse.PromptContexts[$currentPromptKey] = [Math]::Round(([double]$entryLastInputForTotal / [double]$entryContextWindowForTotal) * 100.0, 1)
                    }
                    if (-not $promptUse.PromptOrders.ContainsKey($currentPromptKey)) {
                        $promptUse.PromptOrders[$currentPromptKey] = if ($entryTime) { [int64]$entryTime.Ticks } else { [int64]0 }
                    }
                    if ($activeModel) {
                        $promptUse.PromptModels[$currentPromptKey] = [string]$activeModel
                    }
                    if ($serviceTier) {
                        $promptUse.PromptServiceTiers[$currentPromptKey] = [string]$serviceTier
                    }
                    $entryLimitsForPrompt = Get-JsonValue -Object $payload "rate_limits"
                    $entryLimitSlots = Split-RateLimitSlots -PrimaryLimit (Get-JsonValue -Object $entryLimitsForPrompt "primary") -SecondaryLimit (Get-JsonValue -Object $entryLimitsForPrompt "secondary")
                    $entryPrimaryForPrompt = $entryLimitSlots.Primary
                    $entryPrimaryUsedForPrompt = if ($entryPrimaryForPrompt) { Get-JsonValue -Object $entryPrimaryForPrompt "used_percent" } else { $null }
                    if ($null -ne $entryPrimaryUsedForPrompt) {
                        $promptUse.PromptPrimaryUsedPercents[$currentPromptKey] = [double]$entryPrimaryUsedForPrompt
                    }
                }
                if ($activeModel) {
                    $tokenByModel[$tokenByModelKey] = $entry
                    $tokenByProfile[$tokenByProfileKey] = $entry
                }

                if ($entryTime) {
                    $entryTotalOutputForRate = Get-JsonValue -Object $entryUsage "output_tokens"
                    if ($null -ne $entryTotalOutputForRate) {
                        $tokenRatePoints.Add([pscustomobject]@{
                            Time = $entryTime
                            OutputTokens = [double]$entryTotalOutputForRate
                        })
                    }
                }
            }

            if ($entryTime -and $entryTime -ge $windowStart) {
                $tokenEventsLastMinute++
            }
        }

        if ($entryType -eq "turn_context") {
            $modelValue = Get-JsonValue -Object $payload "model"
            if ($modelValue) {
                $activeModel = [string]$modelValue
            }
            $turnServiceTier = Get-ServiceTierFromObject -Object $payload
            if ($turnServiceTier) {
                $serviceTier = [string]$turnServiceTier
            }
            $lastTurnId = Get-JsonValue -Object $payload "turn_id"
            $lastTurnEffort = Get-JsonValue -Object $payload "effort"
            $lastTurnApprovalPolicy = Get-JsonValue -Object $payload "approval_policy"
            $lastTurnRealtimeActive = Get-JsonValue -Object $payload "realtime_active"
            $lastTurnWorkspaceRoots = @((Get-JsonValue -Object $payload "workspace_roots"))
            $lastTurnCurrentDate = Get-JsonValue -Object $payload "current_date"
            $lastTurnTimezone = Get-JsonValue -Object $payload "timezone"
            $lastTurnCollaborationMode = Get-JsonValue -Object (Get-JsonValue -Object $payload "collaboration_mode") "mode"
        }

        if ($entryType -eq "response_item") {
            switch (Get-JsonValue -Object $payload "type") {
                "function_call" {
                    $toolCalls++
                    $lastTool = Get-JsonValue -Object $payload "name"
                    if ($lastTool) {
                        $toolName = [string]$lastTool
                        if (-not $toolNameCounts.ContainsKey($toolName)) {
                            $toolNameCounts[$toolName] = 0
                        }
                        $toolNameCounts[$toolName]++
                    }
                }
                "custom_tool_call" {
                    $toolCalls++
                    $lastTool = Get-JsonValue -Object $payload "name"
                    if ($lastTool) {
                        $toolName = [string]$lastTool
                        if (-not $toolNameCounts.ContainsKey($toolName)) {
                            $toolNameCounts[$toolName] = 0
                        }
                        $toolNameCounts[$toolName]++
                    }
                }
                "function_call_output" { $toolOutputs++ }
                "custom_tool_call_output" { $toolOutputs++ }
                "message" {
                    $role = Get-JsonValue -Object $payload "role"
                    if ($role -eq "assistant") {
                        $assistantMessages++
                    } elseif ($role -eq "user") {
                        $userMessages++
                        $lastPromptStartedTime = $entryTime
                        $currentPromptKey = if ($entryTime) { [string]$entryTime.Ticks } else { "prompt-{0}" -f $userMessages }
                        if (-not $promptUse.PromptOrders.ContainsKey($currentPromptKey)) {
                            $promptUse.PromptOrders[$currentPromptKey] = if ($entryTime) { [int64]$entryTime.Ticks } else { [int64]$userMessages }
                        }
                        if ($activeModel) {
                            $promptUse.PromptModels[$currentPromptKey] = [string]$activeModel
                        }
                        if ($serviceTier) {
                            $promptUse.PromptServiceTiers[$currentPromptKey] = [string]$serviceTier
                        }
                        $promptUse.LastPromptKey = $currentPromptKey
                    }
                }
            }
        }
    }

    if ($tokenRatePoints.Count -ge 2) {
        $rateEnd = $tokenRatePoints[$tokenRatePoints.Count - 1]
        $rateStart = @($tokenRatePoints | Where-Object { $_.Time -le $windowStart } | Select-Object -Last 1)
        if ($rateStart.Count -eq 0) {
            $rateStart = @($tokenRatePoints | Where-Object { $_.Time -ge $windowStart } | Select-Object -First 1)
        }
        if ($rateStart.Count -gt 0 -and $rateEnd.Time -gt $rateStart[0].Time) {
            $rateSeconds = [Math]::Max(0.001, ($rateEnd.Time - $rateStart[0].Time).TotalSeconds)
            $outputDelta = [Math]::Max(0.0, [double]$rateEnd.OutputTokens - [double]$rateStart[0].OutputTokens)
            $outputTokensLastMinuteRaw = $outputDelta
            $tokensLastMinuteRaw = $outputDelta
            $outputTokensPerSecondRaw = $outputDelta / $rateSeconds
            $tokensPerSecondRaw = $outputTokensPerSecondRaw
        }
    }

    $sessionPromptTokens = 0.0
    $sessionPromptInputTokens = 0.0
    $sessionPromptOutputTokens = 0.0
    $sessionPromptCachedInputTokens = 0.0
    $sessionPromptCacheWriteInputTokens = 0.0
    $sessionPromptReasoningTokens = 0.0
    $sessionPromptCostUnits = 0.0
    foreach ($value in $promptUse.PromptTotals.Values) {
        $sessionPromptTokens += [double]$value
    }
    foreach ($value in $promptUse.PromptInputs.Values) {
        $sessionPromptInputTokens += [double]$value
    }
    foreach ($value in $promptUse.PromptOutputs.Values) {
        $sessionPromptOutputTokens += [double]$value
    }
    foreach ($value in $promptUse.PromptCachedInputs.Values) {
        $sessionPromptCachedInputTokens += [double]$value
    }
    foreach ($value in $promptUse.PromptCacheWrites.Values) {
        $sessionPromptCacheWriteInputTokens += [double]$value
    }
    foreach ($value in $promptUse.PromptReasoning.Values) {
        $sessionPromptReasoningTokens += [double]$value
    }
    foreach ($value in $promptUse.PromptCosts.Values) {
        $sessionPromptCostUnits += [double]$value
    }
    $sessionPromptFastExtraCostUnits = 0.0
    foreach ($promptKey in $promptUse.PromptCosts.Keys) {
        $promptCost = [double]$promptUse.PromptCosts[$promptKey]
        $promptModel = if ($promptUse.PromptModels.ContainsKey($promptKey)) { [string]$promptUse.PromptModels[$promptKey] } else { [string]$activeModel }
        $promptServiceTier = if ($promptUse.PromptServiceTiers.ContainsKey($promptKey)) { [string]$promptUse.PromptServiceTiers[$promptKey] } else { [string]$serviceTier }
        $promptFastMultiplier = Get-FastModeMultiplier -Model $promptModel -ServiceTier $promptServiceTier
        $sessionPromptFastExtraCostUnits += Get-FastExtraCostUnits -CostUnits $promptCost -Multiplier $promptFastMultiplier
    }
    $sessionPromptCount = $promptUse.PromptTotals.Count
    $lowContextTotal = 0.0
    $lowContextCount = 0
    $midContextTotal = 0.0
    $midContextCount = 0
    $highContextTotal = 0.0
    $highContextCount = 0
    foreach ($promptKey in $promptUse.PromptTotals.Keys) {
        if (-not $promptUse.PromptContexts.ContainsKey($promptKey)) {
            continue
        }
        $promptContext = [double]$promptUse.PromptContexts[$promptKey]
        $promptTokens = if ($promptUse.PromptCosts.ContainsKey($promptKey)) { [double]$promptUse.PromptCosts[$promptKey] } else { [double]$promptUse.PromptTotals[$promptKey] }
        if ($promptContext -lt 40.0) {
            $lowContextTotal += $promptTokens
            $lowContextCount++
        } elseif ($promptContext -lt 70.0) {
            $midContextTotal += $promptTokens
            $midContextCount++
        } else {
            $highContextTotal += $promptTokens
            $highContextCount++
        }
    }
    $lowContextAvg = if ($lowContextCount -gt 0) { [Math]::Round($lowContextTotal / $lowContextCount, 1) } else { $null }
    $midContextAvg = if ($midContextCount -gt 0) { [Math]::Round($midContextTotal / $midContextCount, 1) } else { $null }
    $highContextAvg = if ($highContextCount -gt 0) { [Math]::Round($highContextTotal / $highContextCount, 1) } else { $null }
    $lastPromptContextPercent = if ($promptUse.PromptContexts.ContainsKey($currentPromptKey)) { [double]$promptUse.PromptContexts[$currentPromptKey] } else { $null }
    $lastPromptTokensForCost = if ($promptUse.PromptCosts.ContainsKey($currentPromptKey)) { [double]$promptUse.PromptCosts[$currentPromptKey] } elseif ($promptUse.PromptTotals.ContainsKey($currentPromptKey)) { [double]$promptUse.PromptTotals[$currentPromptKey] } else { $null }
    $lastPromptCachedInputTokens = if ($promptUse.PromptCachedInputs.ContainsKey($currentPromptKey)) { [double]$promptUse.PromptCachedInputs[$currentPromptKey] } else { 0.0 }
    $lastPromptCacheWriteInputTokens = if ($promptUse.PromptCacheWrites.ContainsKey($currentPromptKey)) { [double]$promptUse.PromptCacheWrites[$currentPromptKey] } else { 0.0 }
    $lastPromptReasoningTokens = if ($promptUse.PromptReasoning.ContainsKey($currentPromptKey)) { [double]$promptUse.PromptReasoning[$currentPromptKey] } else { 0.0 }
    $lastPromptCostUnits = $lastPromptTokensForCost
    $lastPromptServiceTier = if ($promptUse.PromptServiceTiers.ContainsKey($currentPromptKey)) { [string]$promptUse.PromptServiceTiers[$currentPromptKey] } else { [string]$serviceTier }
    $lastPromptFastMultiplier = Get-FastModeMultiplier -Model $(if ($promptUse.PromptModels.ContainsKey($currentPromptKey)) { [string]$promptUse.PromptModels[$currentPromptKey] } else { [string]$activeModel }) -ServiceTier $lastPromptServiceTier
    $lastPromptFastExtraCostUnits = Get-FastExtraCostUnits -CostUnits $lastPromptCostUnits -Multiplier $lastPromptFastMultiplier
    $promptRows = @(
        $promptUse.PromptOrders.Keys |
            Where-Object { $_ -ne "session-start" -and $promptUse.PromptTotals.ContainsKey([string]$_) } |
            ForEach-Object {
                $promptKey = [string]$_
                $promptModel = if ($promptUse.PromptModels.ContainsKey($promptKey)) { [string]$promptUse.PromptModels[$promptKey] } else { [string]$activeModel }
                [pscustomobject]@{
                    Key = $promptKey
                    Order = [int64]$promptUse.PromptOrders[$promptKey]
                    CostUnits = if ($promptUse.PromptCosts.ContainsKey($promptKey)) { [double]$promptUse.PromptCosts[$promptKey] } else { [double]$promptUse.PromptTotals[$promptKey] }
                    TotalTokens = [double]$promptUse.PromptTotals[$promptKey]
                    InputTokens = if ($promptUse.PromptInputs.ContainsKey($promptKey)) { [double]$promptUse.PromptInputs[$promptKey] } else { $null }
                    OutputTokens = if ($promptUse.PromptOutputs.ContainsKey($promptKey)) { [double]$promptUse.PromptOutputs[$promptKey] } else { $null }
                    Model = $promptModel
                }
            } |
            Sort-Object Order
    )
    $promptNumber = 0
    foreach ($promptRow in $promptRows) {
        $promptNumber++
        $promptRow | Add-Member -NotePropertyName PromptNumber -NotePropertyValue $promptNumber
    }
    $recentPromptCostRows = @($promptRows | Select-Object -Last 5 | Sort-Object Order -Descending)
    $sessionPromptPrimaryUseDelta = $null
    $lastPromptPrimaryUseDelta = $null
    $burnCalibrationCostUnits = 0.0
    $burnCalibrationPercent = 0.0
    $burnCalibrationByModel = @{}
    $burnCostUnitsPerPercent = $null
    $primaryPromptRows = @($promptUse.PromptPrimaryUsedPercents.Keys | ForEach-Object {
        $promptKey = [string]$_
        [pscustomobject]@{
            Key = $promptKey
            Order = if ($promptUse.PromptOrders.ContainsKey($promptKey)) { [int64]$promptUse.PromptOrders[$promptKey] } else { [int64]0 }
            Used = [double]$promptUse.PromptPrimaryUsedPercents[$promptKey]
            Cost = if ($promptUse.PromptCosts.ContainsKey($promptKey)) { [double]$promptUse.PromptCosts[$promptKey] } elseif ($promptUse.PromptTotals.ContainsKey($promptKey)) { [double]$promptUse.PromptTotals[$promptKey] } else { 0.0 }
            Model = if ($promptUse.PromptModels.ContainsKey($promptKey)) { [string]$promptUse.PromptModels[$promptKey] } else { "unknown" }
        }
    } | Sort-Object Order)
    if ($primaryPromptRows.Count -gt 1) {
        $sessionPromptPrimaryUseDelta = 0.0
        $previousPrimaryUsed = $null
        foreach ($primaryPromptRow in $primaryPromptRows) {
            if ($null -ne $previousPrimaryUsed) {
                $promptPrimaryDelta = [Math]::Max(0.0, [double]$primaryPromptRow.Used - [double]$previousPrimaryUsed)
                $sessionPromptPrimaryUseDelta += $promptPrimaryDelta
                if ($promptPrimaryDelta -gt 0 -and [double]$primaryPromptRow.Cost -gt 0) {
                    $burnCalibrationCostUnits += [double]$primaryPromptRow.Cost
                    $burnCalibrationPercent += $promptPrimaryDelta
                    $modelCalibrationKey = ([string]$primaryPromptRow.Model).ToLowerInvariant()
                    if (-not $burnCalibrationByModel.ContainsKey($modelCalibrationKey)) {
                        $burnCalibrationByModel[$modelCalibrationKey] = @{ Cost = 0.0; Percent = 0.0 }
                    }
                    $burnCalibrationByModel[$modelCalibrationKey].Cost += [double]$primaryPromptRow.Cost
                    $burnCalibrationByModel[$modelCalibrationKey].Percent += $promptPrimaryDelta
                }
                if ([string]$primaryPromptRow.Key -eq $currentPromptKey) {
                    $lastPromptPrimaryUseDelta = $promptPrimaryDelta
                }
            }
            $previousPrimaryUsed = [double]$primaryPromptRow.Used
        }
        $sessionPromptPrimaryUseDelta = [Math]::Round($sessionPromptPrimaryUseDelta, 2)
        if ($null -ne $lastPromptPrimaryUseDelta) {
            $lastPromptPrimaryUseDelta = [Math]::Round($lastPromptPrimaryUseDelta, 2)
        }
    }
    if ($burnCalibrationPercent -gt 0 -and $burnCalibrationCostUnits -gt 0) {
        $burnCostUnitsPerPercent = [Math]::Round($burnCalibrationCostUnits / $burnCalibrationPercent, 1)
    }
    $activeCalibrationKey = if ($activeModel) { ([string]$activeModel).ToLowerInvariant() } else { "unknown" }
    if ($burnCalibrationByModel.ContainsKey($activeCalibrationKey) -and [double]$burnCalibrationByModel[$activeCalibrationKey].Percent -gt 0) {
        $burnCostUnitsPerPercent = [Math]::Round([double]$burnCalibrationByModel[$activeCalibrationKey].Cost / [double]$burnCalibrationByModel[$activeCalibrationKey].Percent, 1)
    }
    $overallPromptAvg = if ($sessionPromptCount -gt 0) { [Math]::Round($sessionPromptCostUnits / $sessionPromptCount, 1) } else { $null }
    $baselinePromptAvg = if ($null -ne $lowContextAvg -and $lowContextAvg -gt 0) { $lowContextAvg } elseif ($null -ne $overallPromptAvg -and $overallPromptAvg -gt 0) { $overallPromptAvg } else { $null }
    $lastPromptCostMultiplier = if ($null -ne $baselinePromptAvg -and $baselinePromptAvg -gt 0 -and $null -ne $lastPromptTokensForCost) { [Math]::Round([double]$lastPromptTokensForCost / [double]$baselinePromptAvg, 2) } else { $null }
    $compactSignal = "learning"
    if ($null -ne $lastPromptContextPercent) {
        if ($lastPromptContextPercent -ge 85.0) {
            $compactSignal = "compact now"
        } elseif ($lastPromptContextPercent -ge 70.0) {
            $compactSignal = "compact soon"
        } elseif ($lastPromptContextPercent -ge 40.0) {
            if ($null -ne $lastPromptCostMultiplier -and $lastPromptCostMultiplier -ge 1.6) {
                $compactSignal = "cost high"
            } else {
                $compactSignal = "watch"
            }
        } elseif ($null -ne $lastPromptCostMultiplier -and $lastPromptCostMultiplier -ge 2.5) {
            $compactSignal = "cost spike"
        } elseif ($null -ne $lastPromptCostMultiplier -and $lastPromptCostMultiplier -ge 1.6) {
            $compactSignal = "cost high"
        } else {
            $compactSignal = "healthy"
        }
    }

    $bytesPerSecond = 0.0
    if ($State.LastPath -eq $Path) {
        $seconds = [Math]::Max(0.001, ($now - $State.LastLengthTime).TotalSeconds)
        $bytesPerSecond = [Math]::Max(0, ($file.Length - [int64]$State.LastLength) / $seconds)
    }

    $State.LastPath = $Path
    $State.LastLength = [int64]$file.Length
    $State.LastLengthTime = $now

    $spanMinutes = 1.0
    if ($timestamps.Count -gt 1) {
        $spanMinutes = [Math]::Max(0.1, (($timestamps[$timestamps.Count - 1] - $timestamps[0]).TotalMinutes))
    }

    $totalTokens = $null
    $lastTokens = $null
    $lastInputTokens = $null
    $lastOutputTokens = $null
    $inputTokens = $null
    $outputTokens = $null
    $reasoningTokens = $null
    $cachedTokens = $null
    $cacheWriteTokens = $null
    $contextWindow = $null
    $primaryLimit = $null
    $secondaryLimit = $null
    $limits = $null
    $planType = "unknown"
    $limitId = "n/a"
    $rateLimitName = $null
    $creditsHasCredits = $null
    $creditsUnlimited = $null
    $creditsBalance = $null
    $individualLimit = $null
    $rateLimitReachedType = $null
    $spendControlReached = $null
    $metaModel = Get-JsonValue -Object $metaPayload "model"
    $activeModel = if ($activeModel) { [string]$activeModel } else { if ($metaModel) { [string]$metaModel } else { "unknown" } }
    $metaServiceTier = Get-ServiceTierFromObject -Object $metaPayload
    if (-not $serviceTier -and $metaServiceTier) {
        $serviceTier = [string]$metaServiceTier
    }
    $fastMultiplier = Get-FastModeMultiplier -Model $activeModel -ServiceTier $serviceTier
    if ($null -ne $lastPromptCostUnits) {
        $lastPromptModelForFast = if ($promptUse.PromptModels.ContainsKey($currentPromptKey)) { [string]$promptUse.PromptModels[$currentPromptKey] } else { [string]$activeModel }
        $lastPromptFastMultiplier = Get-FastModeMultiplier -Model $lastPromptModelForFast -ServiceTier $lastPromptServiceTier
        $lastPromptFastExtraCostUnits = Get-FastExtraCostUnits -CostUnits $lastPromptCostUnits -Multiplier $lastPromptFastMultiplier
    }
    $profileKey = Get-UsageProfileKey $activeModel
    $cachedProfile = if ($State.ProfileCache.ContainsKey($profileKey)) { $State.ProfileCache[$profileKey] } else { $null }
    $sessionCache = if ($State.SessionUsageCache.ContainsKey($Path)) { $State.SessionUsageCache[$Path] } else { $null }
    $tokenEvent = if ($activeModel -and $tokenByModel.ContainsKey($activeModel)) { $tokenByModel[$activeModel] } elseif ($tokenByProfile.ContainsKey($profileKey)) { $tokenByProfile[$profileKey] } else { $tokenEvent }
    $limitEvent = if ($activeModel -and $limitByModel.ContainsKey($activeModel)) { $limitByModel[$activeModel] } elseif ($limitByProfile.ContainsKey($profileKey)) { $limitByProfile[$profileKey] } else { $limitEvent }

    if ($tokenEvent) {
        $tokenPayload = Get-JsonValue -Object $tokenEvent "payload"
        $tokenInfo = Get-JsonValue -Object $tokenPayload "info"
        $usage = Get-JsonValue -Object $tokenInfo "total_token_usage"
        $lastUsage = Get-JsonValue -Object $tokenInfo "last_token_usage"
        $limitPayload = if ($limitEvent) { Get-JsonValue -Object $limitEvent "payload" } else { $tokenPayload }
        $limits = Get-JsonValue -Object $limitPayload "rate_limits"

        $totalTokens = [double](Get-JsonValue -Object $usage "total_tokens")
        $inputTokens = [double](Get-JsonValue -Object $usage "input_tokens")
        $outputTokens = [double](Get-JsonValue -Object $usage "output_tokens")
        $reasoningTokens = [double](Get-JsonValue -Object $usage "reasoning_output_tokens")
        $cachedTokens = [double](Get-JsonValue -Object $usage "cached_input_tokens")
        $cacheWriteTokens = Convert-ToNullableDouble (Get-JsonValue -Object $usage "cache_write_input_tokens")
        $contextWindow = [double](Get-JsonValue -Object $tokenInfo "model_context_window")
        $lastTokens = [double](Get-JsonValue -Object $lastUsage "total_tokens")
        $lastInputTokens = [double](Get-JsonValue -Object $lastUsage "input_tokens")
        $lastOutputTokens = [double](Get-JsonValue -Object $lastUsage "output_tokens")
        $primaryLimit = Get-JsonValue -Object $limits "primary"
        $secondaryLimit = Get-JsonValue -Object $limits "secondary"
        $planType = if (Get-JsonValue -Object $limits "plan_type") { [string](Get-JsonValue -Object $limits "plan_type") } else { "unknown" }
        $limitId = if (Get-JsonValue -Object $limits "limit_id") { [string](Get-JsonValue -Object $limits "limit_id") } else { "codex" }
        $State.SessionUsageCache[$Path] = [pscustomobject]@{
            TotalTokens = $totalTokens
            LastTokens = $lastTokens
            LastInputTokens = $lastInputTokens
            LastOutputTokens = $lastOutputTokens
            InputTokens = $inputTokens
            OutputTokens = $outputTokens
            ReasoningTokens = $reasoningTokens
            CachedTokens = $cachedTokens
            CacheWriteTokens = $cacheWriteTokens
            ContextWindow = $contextWindow
            LastTokenEventTime = $lastTokenEventTime
            ServiceTier = $serviceTier
        }
        $State.ProfileCache[$profileKey] = [pscustomobject]@{
            TotalTokens = $totalTokens
            LastTokens = $lastTokens
            LastInputTokens = $lastInputTokens
            LastOutputTokens = $lastOutputTokens
            InputTokens = $inputTokens
            OutputTokens = $outputTokens
            ReasoningTokens = $reasoningTokens
            CachedTokens = $cachedTokens
            CacheWriteTokens = $cacheWriteTokens
            ContextWindow = $contextWindow
            ServiceTier = $serviceTier
            PlanType = $planType
            LimitId = $limitId
            PrimaryUsedPercent = if ($primaryLimit) { [double](Get-JsonValue -Object $primaryLimit "used_percent") } else { $null }
            PrimaryResetRaw = if ($primaryLimit) { Get-JsonValue -Object $primaryLimit "resets_at" } else { $null }
            PrimaryWindowMinutes = if ($primaryLimit) { [int](Get-JsonValue -Object $primaryLimit "window_minutes") } else { $null }
            SecondaryUsedPercent = if ($secondaryLimit) { [double](Get-JsonValue -Object $secondaryLimit "used_percent") } else { $null }
            SecondaryResetRaw = if ($secondaryLimit) { Get-JsonValue -Object $secondaryLimit "resets_at" } else { $null }
            SecondaryWindowMinutes = if ($secondaryLimit) { [int](Get-JsonValue -Object $secondaryLimit "window_minutes") } else { $null }
            PrimaryRemainingPercent = if ($primaryLimit) { [Math]::Round(100 - [double](Get-JsonValue -Object $primaryLimit "used_percent"), 1) } else { $null }
            SecondaryRemainingPercent = if ($secondaryLimit) { [Math]::Round(100 - [double](Get-JsonValue -Object $secondaryLimit "used_percent"), 1) } else { $null }
        }
    } elseif ($sessionCache) {
        $totalTokens = $sessionCache.TotalTokens
        $lastTokens = $sessionCache.LastTokens
        $lastInputTokens = $sessionCache.LastInputTokens
        $lastOutputTokens = $sessionCache.LastOutputTokens
        $inputTokens = $sessionCache.InputTokens
        $outputTokens = $sessionCache.OutputTokens
        $reasoningTokens = $sessionCache.ReasoningTokens
        $cachedTokens = $sessionCache.CachedTokens
        $cacheWriteTokens = if ($sessionCache.PSObject.Properties.Name -contains "CacheWriteTokens") { $sessionCache.CacheWriteTokens } else { $null }
        $contextWindow = $sessionCache.ContextWindow
        $lastTokenEventTime = $sessionCache.LastTokenEventTime
        if ($sessionCache.PSObject.Properties.Name -contains "ServiceTier") {
            $serviceTier = $sessionCache.ServiceTier
        }
    }

    if (-not $tokenEvent -and $cachedProfile) {
        $planType = $cachedProfile.PlanType
        $limitId = $cachedProfile.LimitId
        $primaryLimit = if ($cachedProfile.PrimaryUsedPercent -ne $null -or $cachedProfile.PrimaryResetRaw -ne $null -or $cachedProfile.PrimaryWindowMinutes -ne $null) {
            [pscustomobject]@{ used_percent = $cachedProfile.PrimaryUsedPercent; resets_at = $cachedProfile.PrimaryResetRaw; window_minutes = $cachedProfile.PrimaryWindowMinutes }
        } else { $null }
        $secondaryLimit = if ($cachedProfile.SecondaryUsedPercent -ne $null -or $cachedProfile.SecondaryResetRaw -ne $null -or $cachedProfile.SecondaryWindowMinutes -ne $null) {
            [pscustomobject]@{ used_percent = $cachedProfile.SecondaryUsedPercent; resets_at = $cachedProfile.SecondaryResetRaw; window_minutes = $cachedProfile.SecondaryWindowMinutes }
        } else { $null }
        $tokensPerMinute = 0.0
    }

    if ($limitEvent) {
        $limitPayload = Get-JsonValue -Object $limitEvent "payload"
        $limits = Get-JsonValue -Object $limitPayload "rate_limits"
        if ($limits) {
            $primaryLimit = Get-JsonValue -Object $limits "primary"
            $secondaryLimit = Get-JsonValue -Object $limits "secondary"
            $planType = if (Get-JsonValue -Object $limits "plan_type") { [string](Get-JsonValue -Object $limits "plan_type") } else { $planType }
            $limitId = if (Get-JsonValue -Object $limits "limit_id") { [string](Get-JsonValue -Object $limits "limit_id") } else { $limitId }
        }
    }

    if ($limits) {
        $rateLimitName = Get-JsonValue -Object $limits "limit_name"
        $credits = Get-JsonValue -Object $limits "credits"
        $creditsHasCredits = Convert-ToNullableDouble (Get-JsonValue -Object $credits "has_credits")
        if ($null -ne $creditsHasCredits) { $creditsHasCredits = [bool]$creditsHasCredits }
        $creditsUnlimited = Convert-ToNullableDouble (Get-JsonValue -Object $credits "unlimited")
        if ($null -ne $creditsUnlimited) { $creditsUnlimited = [bool]$creditsUnlimited }
        $creditsBalance = Get-JsonValue -Object $credits "balance"
        $individualLimit = Get-JsonValue -Object $limits "individual_limit"
        $rateLimitReachedType = Get-JsonValue -Object $limits "rate_limit_reached_type"
        $spendControlReached = Get-JsonValue -Object $limits "spend_control_reached"
    }

    $limitSlots = Split-RateLimitSlots -PrimaryLimit $primaryLimit -SecondaryLimit $secondaryLimit
    $primaryLimit = $limitSlots.Primary
    $secondaryLimit = $limitSlots.Secondary
    $weeklyLimit = @($primaryLimit, $secondaryLimit | Where-Object { $_ -and (Get-RateLimitWindowMinutes $_) -ge 10080 } | Select-Object -First 1)
    $weeklyLimit = if ($weeklyLimit.Count -gt 0) { $weeklyLimit[0] } else { $null }

    $tokensPerMinute = [Math]::Round($tokensLastMinuteRaw, 1)

    if ($tokenEvent -and $null -ne $totalTokens) {
        $State.LastTokenTotal = $totalTokens
        $State.LastTokenTime = $now
    }

    $age = $now - $file.LastWriteTime
    $status = if ($age.TotalSeconds -lt 20) { "active" } elseif ($age.TotalMinutes -lt 5) { "warm" } else { "idle" }
    $primaryRemainingPercent = if ($primaryLimit) { [Math]::Round(100 - [double](Get-JsonValue -Object $primaryLimit "used_percent"), 1) } else { $null }
    $secondaryRemainingPercent = if ($secondaryLimit) { [Math]::Round(100 - [double](Get-JsonValue -Object $secondaryLimit "used_percent"), 1) } else { $null }
    $primaryWindowText = Get-RateLimitWindowShortLabel -WindowMinutes $(if ($primaryLimit) { Get-RateLimitWindowMinutes $primaryLimit } else { $null }) -Fallback "usage"
    $secondaryWindowText = Get-RateLimitWindowShortLabel -WindowMinutes $(if ($secondaryLimit) { Get-RateLimitWindowMinutes $secondaryLimit } else { $null }) -Fallback "additional"
    $primaryRemainingText = if ($null -ne $primaryRemainingPercent) { "{0}%" -f $primaryRemainingPercent } else { "n/a" }
    $secondaryRemainingText = if ($null -ne $secondaryRemainingPercent) { "{0}%" -f $secondaryRemainingPercent } else { "n/a" }
    $usageProfilesSummary = if ($null -eq $primaryLimit -and $secondaryLimit) {
        ("{0} {1} {2}" -f (Get-UsageProfileLabel $profileKey), $secondaryRemainingText, (Get-RateLimitWindowShortLabel -WindowMinutes (Get-RateLimitWindowMinutes $secondaryLimit) -Fallback "wk"))
    } else {
        ("{0} {1} {2} | {3} {4}" -f (Get-UsageProfileLabel $profileKey), $primaryRemainingText, $primaryWindowText, $secondaryRemainingText, $secondaryWindowText)
    }
    $recentTaskDurationValues = @($recentTaskDurationsMs.ToArray() | Sort-Object)
    $recentTaskTtftValues = @($recentTaskTimeToFirstTokenMs.ToArray() | Sort-Object)
    $recentTaskCount = $recentTaskDurationValues.Count
    $recentTaskDurationAverageMs = if ($recentTaskCount -gt 0) { [Math]::Round((($recentTaskDurationValues | Measure-Object -Average).Average), 1) } else { $null }
    $recentTaskDurationMedianMs = if ($recentTaskCount -gt 0) {
        $middle = [int][Math]::Floor($recentTaskCount / 2)
        if (($recentTaskCount % 2) -eq 1) { $recentTaskDurationValues[$middle] } else { [Math]::Round((([double]$recentTaskDurationValues[$middle - 1] + [double]$recentTaskDurationValues[$middle]) / 2.0), 1) }
    } else { $null }
    $recentTaskTtftAverageMs = if ($recentTaskTtftValues.Count -gt 0) { [Math]::Round((($recentTaskTtftValues | Measure-Object -Average).Average), 1) } else { $null }
    $cacheHitPercent = if ($null -ne $inputTokens -and [double]$inputTokens -gt 0 -and $null -ne $cachedTokens) { [Math]::Round(([double]$cachedTokens / [double]$inputTokens) * 100.0, 1) } else { $null }
    $uncachedInputTokens = if ($null -ne $inputTokens -and $null -ne $cachedTokens) { [Math]::Max(0.0, [double]$inputTokens - [double]$cachedTokens) } else { $null }
    $lastPromptCacheHitPercent = if ($null -ne $lastInputTokens -and [double]$lastInputTokens -gt 0 -and $null -ne $lastPromptCachedInputTokens) { [Math]::Round(([double]$lastPromptCachedInputTokens / [double]$lastInputTokens) * 100.0, 1) } else { $null }

    $result = [pscustomobject]@{
        SessionPath = $Path
        SessionName = Split-Path -Leaf $Path
        SessionId = if (Get-JsonValue -Object $metaPayload "id") { [string](Get-JsonValue -Object $metaPayload "id") } else { "unknown" }
        Cwd = if (Get-JsonValue -Object $metaPayload "cwd") { [string](Get-JsonValue -Object $metaPayload "cwd") } else { "unknown" }
        Model = if (Get-JsonValue -Object $metaPayload "model_provider") { [string](Get-JsonValue -Object $metaPayload "model_provider") } else { "unknown" }
        SessionOriginator = Get-JsonValue -Object $metaPayload "originator"
        SessionSource = Get-JsonValue -Object $metaPayload "source"
        ThreadSource = Get-JsonValue -Object $metaPayload "thread_source"
        HistoryMode = Get-JsonValue -Object $metaPayload "history_mode"
        MemoryMode = Get-JsonValue -Object $metaPayload "memory_mode"
        ContextWindowId = Get-JsonValue -Object (Get-JsonValue -Object $metaPayload "context_window") "window_id"
        GitBranch = Get-JsonValue -Object (Get-JsonValue -Object $metaPayload "git") "branch"
        GitCommit = Get-JsonValue -Object (Get-JsonValue -Object $metaPayload "git") "commit_hash"
        GitRepositoryUrl = Get-JsonValue -Object (Get-JsonValue -Object $metaPayload "git") "repository_url"
        ActiveModel = if ($activeModel) { [string]$activeModel } else { "unknown" }
        UsageProfileKey = $profileKey
        UsageSourceModel = if ($activeModel) { [string]$activeModel } else { "unknown" }
        UsageSourcePlanType = $planType
        UsageSourceLimitId = $limitId
        UsageSourceSessionId = if (Get-JsonValue -Object $metaPayload "id") { [string](Get-JsonValue -Object $metaPayload "id") } else { "unknown" }
        UsageProfilesSummary = $usageProfilesSummary
        PriceGuardModel = if ($activeModel) { [string]$activeModel } else { "unknown" }
        PriceGuardSessionId = if (Get-JsonValue -Object $metaPayload "id") { [string](Get-JsonValue -Object $metaPayload "id") } else { "unknown" }
        PriceGuardSessionName = Split-Path -Leaf $Path
        CliVersion = if (Get-JsonValue -Object $metaPayload "cli_version") { [string](Get-JsonValue -Object $metaPayload "cli_version") } else { "unknown" }
        Status = $status
        LastWrite = $file.LastWriteTime
        LastWriteAgeSeconds = [Math]::Round($age.TotalSeconds, 1)
        LogKb = [Math]::Round($file.Length / 1kb, 1)
        LogBytesPerSecond = [Math]::Round($bytesPerSecond, 1)
        EventsPerMinute = [Math]::Round($lines.Count / $spanMinutes, 1)
        ToolCallsPerMinute = [Math]::Round($toolCalls / $spanMinutes, 1)
        ToolCalls = $toolCalls
        ToolOutputs = $toolOutputs
        AssistantMessages = $assistantMessages
        UserMessages = $userMessages
        ParsedEventCount = $parsedEvents
        ToolNameCounts = $toolNameCounts
        ToolsUsed = @($toolNameCounts.Keys | Sort-Object)
        LastTool = if ($lastTool) { [string]$lastTool } else { "none" }
        LastEventType = if ($lastEvent) { [string](Get-JsonValue -Object $lastEvent "type") } else { "none" }
        LastPromptStartedAt = $lastPromptStartedTime
        LastPromptText = $lastPromptText
        LastPromptClientId = $lastPromptClientId
        LastPromptImageCount = $lastPromptImageCount
        LastPromptLocalImageCount = $lastPromptLocalImageCount
        LastPromptTextElementCount = $lastPromptTextElementCount
        LastTaskStartedAt = $lastTaskStartedTime
        LastTaskCompleteAt = $lastTaskCompleteTime
        LastTaskTurnId = $lastTaskTurnId
        LastTaskDurationMs = $lastTaskDurationMs
        LastTaskTimeToFirstTokenMs = $lastTaskTimeToFirstTokenMs
        LastTaskAgentMessage = $lastTaskAgentMessage
        LastTaskModelContextWindow = $lastTaskModelContextWindow
        LastTaskCollaborationMode = $lastTaskCollaborationMode
        RecentTaskDurationsMs = $recentTaskDurationValues
        RecentTaskTimeToFirstTokenMs = $recentTaskTtftValues
        RecentTaskCount = $recentTaskCount
        RecentTaskDurationAverageMs = $recentTaskDurationAverageMs
        RecentTaskDurationMedianMs = $recentTaskDurationMedianMs
        RecentTaskTimeToFirstTokenAverageMs = $recentTaskTtftAverageMs
        LastTurnId = $lastTurnId
        LastTurnEffort = $lastTurnEffort
        LastTurnApprovalPolicy = $lastTurnApprovalPolicy
        LastTurnRealtimeActive = $lastTurnRealtimeActive
        LastTurnWorkspaceRoots = @($lastTurnWorkspaceRoots)
        LastTurnCurrentDate = $lastTurnCurrentDate
        LastTurnTimezone = $lastTurnTimezone
        LastTurnCollaborationMode = $lastTurnCollaborationMode
        RecentCompactionEvents = $recentCompactionEvents
        LastCompactionWindowId = $lastCompactionWindowId
        LastTokenEventTime = $lastTokenEventTime
        LastTokenEventAgeSeconds = if ($lastTokenEventTime) { [Math]::Max(0, [Math]::Round(($now - $lastTokenEventTime).TotalSeconds, 1)) } else { $null }
        TotalTokens = $totalTokens
        LastTokens = $lastTokens
        LastInputTokens = $lastInputTokens
        LastOutputTokens = $lastOutputTokens
        InputTokens = $inputTokens
        OutputTokens = $outputTokens
        ReasoningTokens = $reasoningTokens
        CachedTokens = $cachedTokens
        CacheWriteTokens = $cacheWriteTokens
        CacheHitPercent = $cacheHitPercent
        UncachedInputTokens = if ($null -ne $uncachedInputTokens) { [Math]::Round($uncachedInputTokens, 1) } else { $null }
        LastPromptCacheHitPercent = $lastPromptCacheHitPercent
        ContextWindow = $contextWindow
        ContextUsedPercent = if ($contextWindow -and $lastTokens) { [Math]::Round(($lastTokens / $contextWindow) * 100, 1) } else { $null }
        TokensLastMinute = [Math]::Round($tokensLastMinuteRaw, 1)
        OutputTokensLastMinute = [Math]::Round($outputTokensLastMinuteRaw, 1)
        TokenEventsLastMinute = $tokenEventsLastMinute
        TokensPerMinute = [Math]::Round($tokensPerMinute, 1)
        TokensPerSecond = [Math]::Round($tokensPerSecondRaw, 2)
        OutputTokensPerSecond = [Math]::Round($outputTokensPerSecondRaw, 2)
        SessionPromptTokens = [Math]::Round($sessionPromptTokens, 1)
        SessionPromptInputTokens = [Math]::Round($sessionPromptInputTokens, 1)
        SessionPromptOutputTokens = [Math]::Round($sessionPromptOutputTokens, 1)
        SessionPromptCachedInputTokens = [Math]::Round($sessionPromptCachedInputTokens, 1)
        SessionPromptCacheWriteInputTokens = [Math]::Round($sessionPromptCacheWriteInputTokens, 1)
        SessionPromptReasoningTokens = [Math]::Round($sessionPromptReasoningTokens, 1)
        SessionPromptCostUnits = [Math]::Round($sessionPromptCostUnits, 1)
        SessionPromptFastExtraCostUnits = [Math]::Round($sessionPromptFastExtraCostUnits, 1)
        RecentPromptCosts = $recentPromptCostRows
        SessionPromptPrimaryUseDelta = $sessionPromptPrimaryUseDelta
        BurnCostUnitsPerPercent = $burnCostUnitsPerPercent
        SessionPromptCount = [int]$sessionPromptCount
        LastPromptCachedInputTokens = [Math]::Round($lastPromptCachedInputTokens, 1)
        LastPromptCacheWriteInputTokens = [Math]::Round($lastPromptCacheWriteInputTokens, 1)
        LastPromptReasoningTokens = [Math]::Round($lastPromptReasoningTokens, 1)
        LastPromptCostUnits = if ($null -ne $lastPromptCostUnits) { [Math]::Round([double]$lastPromptCostUnits, 1) } else { $null }
        LastPromptFastExtraCostUnits = if ($null -ne $lastPromptFastExtraCostUnits) { [Math]::Round([double]$lastPromptFastExtraCostUnits, 1) } else { $null }
        FastMultiplier = [Math]::Round([double]$fastMultiplier, 2)
        LastPromptFastMultiplier = [Math]::Round([double]$lastPromptFastMultiplier, 2)
        ServiceTier = if ($serviceTier) { [string]$serviceTier } else { "unknown" }
        LastPromptPrimaryUseDelta = $lastPromptPrimaryUseDelta
        LowContextPromptAvg = $lowContextAvg
        MidContextPromptAvg = $midContextAvg
        HighContextPromptAvg = $highContextAvg
        LastPromptContextPercent = $lastPromptContextPercent
        LastPromptCostMultiplier = $lastPromptCostMultiplier
        CompactSignal = $compactSignal
        PlanType = $planType
        PrimaryUsedPercent = if ($primaryLimit) { [double](Get-JsonValue -Object $primaryLimit "used_percent") } else { $null }
        PrimaryRemainingPercent = $primaryRemainingPercent
        PrimaryReset = if ($primaryLimit) { Format-Reset (Get-JsonValue -Object $primaryLimit "resets_at") } else { "n/a" }
        PrimaryResetAt = if ($primaryLimit) { Convert-FromUnixSeconds (Get-JsonValue -Object $primaryLimit "resets_at") } else { $null }
        PrimaryWindowMinutes = if ($primaryLimit) { [int](Get-JsonValue -Object $primaryLimit "window_minutes") } else { $null }
        SecondaryUsedPercent = if ($secondaryLimit) { [double](Get-JsonValue -Object $secondaryLimit "used_percent") } else { $null }
        SecondaryRemainingPercent = $secondaryRemainingPercent
        SecondaryReset = if ($secondaryLimit) { Format-Reset (Get-JsonValue -Object $secondaryLimit "resets_at") } else { "n/a" }
        SecondaryResetAt = if ($secondaryLimit) { Convert-FromUnixSeconds (Get-JsonValue -Object $secondaryLimit "resets_at") } else { $null }
        SecondaryWindowMinutes = if ($secondaryLimit) { [int](Get-JsonValue -Object $secondaryLimit "window_minutes") } else { $null }
        WeeklyUsedPercent = if ($weeklyLimit) { Convert-ToNullableDouble (Get-JsonValue -Object $weeklyLimit "used_percent") } else { $null }
        WeeklyRemainingPercent = if ($weeklyLimit) { [Math]::Round(100 - [double](Get-JsonValue -Object $weeklyLimit "used_percent"), 1) } else { $null }
        WeeklyReset = if ($weeklyLimit) { Format-Reset (Get-JsonValue -Object $weeklyLimit "resets_at") } else { "n/a" }
        WeeklyResetAt = if ($weeklyLimit) { Convert-FromUnixSeconds (Get-JsonValue -Object $weeklyLimit "resets_at") } else { $null }
        WeeklyWindowMinutes = if ($weeklyLimit) { Get-RateLimitWindowMinutes $weeklyLimit } else { $null }
        RateLimitName = $rateLimitName
        CreditsHasCredits = $creditsHasCredits
        CreditsUnlimited = $creditsUnlimited
        CreditsBalance = $creditsBalance
        IndividualLimit = $individualLimit
        RateLimitReachedType = $rateLimitReachedType
        SpendControlReached = $spendControlReached
        LimitId = $limitId
    }

    $State.SessionMetricsCache[$Path] = [pscustomobject]@{
        Length = [int64]$file.Length
        LastWriteTime = $file.LastWriteTime
        CachedAt = $now
        Session = $result
    }

    return $result
}

function Get-CodexLimitEvents {
    param(
        [string]$Root,
        [int]$MaxEvents = 40
    )

    $sessionRoot = Join-Path $Root "sessions"
    if (-not (Test-Path -LiteralPath $sessionRoot)) {
        return @()
    }

    $files = Get-SessionCandidateFiles -Root $Root |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 8

    $rows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($file in $files) {
        $lines = Get-FileTailLines -Path $file.FullName -LineCount 300
        if (-not $lines -or $lines.Count -eq 0) {
            continue
        }

        $model = $null
        foreach ($line in $lines) {
            if ($line -notlike "*token_count*" -and $line -notlike "*turn_context*") {
                continue
            }

            $entry = Convert-FromJsonLine $line
            if (-not $entry) {
                continue
            }

            $entryType = Get-JsonValue -Object $entry "type"
            $payload = Get-JsonValue -Object $entry "payload"
            if ($entryType -eq "turn_context") {
                $modelValue = Get-JsonValue -Object $payload "model"
                if ($modelValue) {
                    $model = [string]$modelValue
                }
            }

            if ($entryType -eq "event_msg" -and (Get-JsonValue -Object $payload "type") -eq "token_count") {
                $eventTime = try { ([datetime](Get-JsonValue -Object $entry "timestamp")).ToLocalTime() } catch { $file.LastWriteTime }
                $info = Get-JsonValue -Object $payload "info"
                $usage = Get-JsonValue -Object $info "total_token_usage"
                $lastUsage = Get-JsonValue -Object $info "last_token_usage"
                $limits = Get-JsonValue -Object $payload "rate_limits"
                $limitSlots = Split-RateLimitSlots -PrimaryLimit (Get-JsonValue -Object $limits "primary") -SecondaryLimit (Get-JsonValue -Object $limits "secondary")
                $primary = $limitSlots.Primary
                $secondary = $limitSlots.Secondary

                $rows.Add([pscustomobject]@{
                    Time = $eventTime
                    Session = $file.Name
                    LimitId = if (Get-JsonValue -Object $limits "limit_id") { [string](Get-JsonValue -Object $limits "limit_id") } else { "codex" }
                    Plan = if (Get-JsonValue -Object $limits "plan_type") { [string](Get-JsonValue -Object $limits "plan_type") } else { "unknown" }
                    ActiveModel = if ($model -like "*spark*") { "spark" } else { Shorten-Model $model }
                    TotalTokens = [double](Get-JsonValue -Object $usage "total_tokens")
                    LastTokens = [double](Get-JsonValue -Object $lastUsage "total_tokens")
                    PrimaryUsedPercent = if ($primary) { [Math]::Round([double](Get-JsonValue -Object $primary "used_percent"), 1) } else { $null }
                    SecondaryUsedPercent = if ($secondary) { [Math]::Round([double](Get-JsonValue -Object $secondary "used_percent"), 1) } else { $null }
                })
            }
        }

        if ($rows.Count -ge $MaxEvents) {
            break
        }
    }

    return $rows | Sort-Object Time -Descending | Select-Object -First $MaxEvents
}

function Get-CodexProcessMetrics {
    param([hashtable]$State)

    $now = Get-Date
    $processes = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match "codex|Code" -or $_.MainWindowTitle -match "Codex" }

    $cpuSeconds = 0.0
    $memoryMb = 0.0
    $nextCpu = @{}

    foreach ($process in $processes) {
        $memoryMb += $process.WorkingSet64 / 1mb
        if ($null -ne $process.CPU) {
            $nextCpu[$process.Id] = [double]$process.CPU
            if ($State.ProcessCpu.ContainsKey($process.Id)) {
                $cpuSeconds += [Math]::Max(0, [double]$process.CPU - [double]$State.ProcessCpu[$process.Id])
            }
        }
    }

    $elapsed = [Math]::Max(0.001, ($now - $State.ProcessTime).TotalSeconds)
    $cpuPercent = ($cpuSeconds / $elapsed / [Environment]::ProcessorCount) * 100
    $State.ProcessCpu = $nextCpu
    $State.ProcessTime = $now

    [pscustomobject]@{
        Count = @($processes).Count
        CpuPercent = [Math]::Round($cpuPercent, 1)
        MemoryMb = [Math]::Round($memoryMb, 1)
    }
}

function Merge-SessionMetrics {
    param([array]$Sessions)

    if (-not $Sessions -or $Sessions.Count -eq 0) {
        return $null
    }

    $ordered = @($Sessions | Sort-Object LastWrite -Descending)
    $latest = $ordered[0]
    $usageSession = Select-PreferredUsageSession -Sessions $ordered
    if (-not $usageSession) {
        $usageSession = $latest
    }
    $usageProfilesSummary = Format-UsageProfilesSummary -Sessions $ordered
    $tokensLastMinute = 0.0
    $eventsPerMinute = 0.0
    $toolCallsPerMinute = 0.0
    $totalTokens = 0.0
    $inputTokens = 0.0
    $outputTokens = 0.0
    $reasoningTokens = 0.0
    $cachedTokens = 0.0
    $cacheWriteTokens = 0.0
    $sessionPromptTokens = 0.0
    $sessionPromptInputTokens = 0.0
    $sessionPromptOutputTokens = 0.0
    $sessionPromptCachedInputTokens = 0.0
    $sessionPromptReasoningTokens = 0.0
    $sessionPromptCostUnits = 0.0
    $sessionPromptFastExtraCostUnits = 0.0
    $sessionPromptPrimaryUseDelta = 0.0
    $burnCalibrationCostUnits = 0.0
    $burnCalibrationPercent = 0.0
    $hasSessionPromptPrimaryUseDelta = $false
    $sessionPromptCount = 0
    $outputTokensLastMinute = 0.0
    $tokensPerSecond = 0.0
    $outputTokensPerSecond = 0.0
    $logKb = 0.0
    $tokenEvents = 0
    $parsedEventCount = 0
    $toolNameCounts = @{}
    $hasInputTokens = $false
    $hasCachedTokens = $false
    $hasContext = $false
    $contextUsed = 0.0
    $contextWindow = 0.0
    $recentTaskDurationsMs = New-Object 'System.Collections.Generic.List[double]'
    $recentTaskTimeToFirstTokenMs = New-Object 'System.Collections.Generic.List[double]'
    $guardSession = @($ordered |
        Where-Object { (Test-LongContextPriceModel -Model $_.ActiveModel) -and $null -ne $_.LastInputTokens } |
        Sort-Object LastInputTokens -Descending |
        Select-Object -First 1)
    if (-not $guardSession -or $guardSession.Count -eq 0) {
        $guardSession = $latest
    } else {
        $guardSession = $guardSession[0]
    }

    foreach ($s in $ordered) {
        if ($null -ne $s.TokensLastMinute) { $tokensLastMinute += [double]$s.TokensLastMinute }
        if ($null -ne $s.EventsPerMinute) { $eventsPerMinute += [double]$s.EventsPerMinute }
        if ($null -ne $s.ToolCallsPerMinute) { $toolCallsPerMinute += [double]$s.ToolCallsPerMinute }
        if ($null -ne $s.ParsedEventCount) { $parsedEventCount += [int]$s.ParsedEventCount }
        if ($s.ToolNameCounts) {
            foreach ($toolName in $s.ToolNameCounts.Keys) {
                if (-not $toolNameCounts.ContainsKey([string]$toolName)) {
                    $toolNameCounts[[string]$toolName] = 0
                }
                $toolNameCounts[[string]$toolName] += [int]$s.ToolNameCounts[$toolName]
            }
        }
        if ($null -ne $s.TotalTokens) { $totalTokens += [double]$s.TotalTokens }
        if ($null -ne $s.InputTokens) { $inputTokens += [double]$s.InputTokens; $hasInputTokens = $true }
        if ($null -ne $s.OutputTokens) { $outputTokens += [double]$s.OutputTokens }
        if ($null -ne $s.ReasoningTokens) { $reasoningTokens += [double]$s.ReasoningTokens }
        if ($null -ne $s.CachedTokens) { $cachedTokens += [double]$s.CachedTokens; $hasCachedTokens = $true }
        if ($null -ne $s.CacheWriteTokens) { $cacheWriteTokens += [double]$s.CacheWriteTokens }
        foreach ($duration in @($s.RecentTaskDurationsMs)) { if ($null -ne $duration) { $recentTaskDurationsMs.Add([double]$duration) } }
        foreach ($ttft in @($s.RecentTaskTimeToFirstTokenMs)) { if ($null -ne $ttft) { $recentTaskTimeToFirstTokenMs.Add([double]$ttft) } }
        if ($null -ne $s.SessionPromptTokens) { $sessionPromptTokens += [double]$s.SessionPromptTokens }
        if ($null -ne $s.SessionPromptInputTokens) { $sessionPromptInputTokens += [double]$s.SessionPromptInputTokens }
        if ($null -ne $s.SessionPromptOutputTokens) { $sessionPromptOutputTokens += [double]$s.SessionPromptOutputTokens }
        if ($null -ne $s.SessionPromptCachedInputTokens) { $sessionPromptCachedInputTokens += [double]$s.SessionPromptCachedInputTokens }
        if ($null -ne $s.SessionPromptReasoningTokens) { $sessionPromptReasoningTokens += [double]$s.SessionPromptReasoningTokens }
        if ($null -ne $s.SessionPromptCostUnits) { $sessionPromptCostUnits += [double]$s.SessionPromptCostUnits }
        if ($null -ne $s.SessionPromptFastExtraCostUnits) { $sessionPromptFastExtraCostUnits += [double]$s.SessionPromptFastExtraCostUnits }
        if ($null -ne $s.SessionPromptPrimaryUseDelta) { $sessionPromptPrimaryUseDelta += [double]$s.SessionPromptPrimaryUseDelta; $hasSessionPromptPrimaryUseDelta = $true }
        if ($null -ne $s.BurnCostUnitsPerPercent -and [double]$s.BurnCostUnitsPerPercent -gt 0 -and $null -ne $s.SessionPromptPrimaryUseDelta -and [double]$s.SessionPromptPrimaryUseDelta -gt 0 -and [string]$s.ActiveModel -eq [string]$usageSession.ActiveModel) {
            $burnCalibrationCostUnits += [double]$s.BurnCostUnitsPerPercent * [double]$s.SessionPromptPrimaryUseDelta
            $burnCalibrationPercent += [double]$s.SessionPromptPrimaryUseDelta
        }
        if ($null -ne $s.SessionPromptCount) { $sessionPromptCount += [int]$s.SessionPromptCount }
        if ($null -ne $s.OutputTokensLastMinute) { $outputTokensLastMinute += [double]$s.OutputTokensLastMinute }
        if ($null -ne $s.TokensPerSecond) { $tokensPerSecond += [double]$s.TokensPerSecond }
        if ($null -ne $s.OutputTokensPerSecond) { $outputTokensPerSecond += [double]$s.OutputTokensPerSecond }
        if ($null -ne $s.LogKb) { $logKb += [double]$s.LogKb }
        if ($null -ne $s.TokenEventsLastMinute) { $tokenEvents += [int]$s.TokenEventsLastMinute }
        if ($null -ne $s.ContextUsedPercent -and $null -ne $s.ContextWindow) {
            $contextUsed += ([double]$s.ContextUsedPercent * [double]$s.ContextWindow)
            $contextWindow += [double]$s.ContextWindow
            $hasContext = $true
        }
    }

    $contextPercent = if ($hasContext -and $contextWindow -gt 0) { [Math]::Round($contextUsed / $contextWindow, 1) } else { $null }
    $ageSeconds = [Math]::Max(0, [Math]::Round(((Get-Date) - $latest.LastWrite).TotalSeconds, 1))
    $recentPromptCosts = @($ordered | ForEach-Object { @($_.RecentPromptCosts) } | Sort-Object Order -Descending | Select-Object -First 5)
    $taskDurationValues = @($recentTaskDurationsMs.ToArray() | Sort-Object)
    $taskTtftValues = @($recentTaskTimeToFirstTokenMs.ToArray() | Sort-Object)
    $taskCount = $taskDurationValues.Count
    $taskDurationAverageMs = if ($taskCount -gt 0) { [Math]::Round((($taskDurationValues | Measure-Object -Average).Average), 1) } else { $null }
    $taskDurationMedianMs = if ($taskCount -gt 0) {
        $middle = [int][Math]::Floor($taskCount / 2)
        if (($taskCount % 2) -eq 1) { $taskDurationValues[$middle] } else { [Math]::Round((([double]$taskDurationValues[$middle - 1] + [double]$taskDurationValues[$middle]) / 2.0), 1) }
    } else { $null }
    $taskTtftAverageMs = if ($taskTtftValues.Count -gt 0) { [Math]::Round((($taskTtftValues | Measure-Object -Average).Average), 1) } else { $null }
    $cacheHitPercent = if ($hasInputTokens -and $hasCachedTokens -and $inputTokens -gt 0) { [Math]::Round(($cachedTokens / $inputTokens) * 100.0, 1) } else { $null }
    $uncachedInputTokens = if ($hasInputTokens -and $hasCachedTokens) { [Math]::Round([Math]::Max(0.0, $inputTokens - $cachedTokens), 1) } else { $null }

    [pscustomobject]@{
        SessionPath = "__ALL__"
        SessionName = "ALL"
        SessionId = "all"
        Cwd = "multiple"
        Model = "mixed"
        ActiveModel = $usageSession.ActiveModel
        UsageProfileKey = Get-UsageProfileKey $usageSession.ActiveModel
        UsageSourceModel = $usageSession.ActiveModel
        UsageSourcePlanType = $usageSession.PlanType
        UsageSourceLimitId = $usageSession.LimitId
        UsageSourceSessionId = $usageSession.SessionId
        UsageProfilesSummary = $usageProfilesSummary
        PriceGuardModel = $guardSession.ActiveModel
        PriceGuardSessionId = $guardSession.SessionId
        PriceGuardSessionName = $guardSession.SessionName
        CliVersion = $latest.CliVersion
        Status = if ($ordered | Where-Object { $_.Status -eq "active" }) { "active" } elseif ($ordered | Where-Object { $_.Status -eq "warm" }) { "warm" } else { "idle" }
        LastWrite = $latest.LastWrite
        LastWriteAgeSeconds = $ageSeconds
        LogKb = [Math]::Round($logKb, 1)
        LogBytesPerSecond = $latest.LogBytesPerSecond
        EventsPerMinute = [Math]::Round($eventsPerMinute, 1)
        ToolCallsPerMinute = [Math]::Round($toolCallsPerMinute, 1)
        ToolCalls = ($ordered | Measure-Object -Property ToolCalls -Sum).Sum
        ToolOutputs = ($ordered | Measure-Object -Property ToolOutputs -Sum).Sum
        AssistantMessages = ($ordered | Measure-Object -Property AssistantMessages -Sum).Sum
        UserMessages = ($ordered | Measure-Object -Property UserMessages -Sum).Sum
        ParsedEventCount = $parsedEventCount
        ToolNameCounts = $toolNameCounts
        ToolsUsed = @($toolNameCounts.Keys | Sort-Object)
        LastTool = $latest.LastTool
        LastEventType = $latest.LastEventType
        LastPromptStartedAt = $guardSession.LastPromptStartedAt
        LastPromptText = $guardSession.LastPromptText
        LastTaskStartedAt = $guardSession.LastTaskStartedAt
        LastTaskCompleteAt = $guardSession.LastTaskCompleteAt
        RecentTaskDurationsMs = $taskDurationValues
        RecentTaskTimeToFirstTokenMs = $taskTtftValues
        RecentTaskCount = $taskCount
        RecentTaskDurationAverageMs = $taskDurationAverageMs
        RecentTaskDurationMedianMs = $taskDurationMedianMs
        RecentTaskTimeToFirstTokenAverageMs = $taskTtftAverageMs
        LastTokenEventTime = $guardSession.LastTokenEventTime
        LastTokenEventAgeSeconds = $guardSession.LastTokenEventAgeSeconds
        TotalTokens = [Math]::Round($totalTokens, 1)
        LastTokens = $guardSession.LastTokens
        LastInputTokens = $guardSession.LastInputTokens
        LastOutputTokens = $guardSession.LastOutputTokens
        InputTokens = if ($hasInputTokens) { [Math]::Round($inputTokens, 1) } else { $null }
        OutputTokens = [Math]::Round($outputTokens, 1)
        ReasoningTokens = [Math]::Round($reasoningTokens, 1)
        CachedTokens = if ($hasCachedTokens) { [Math]::Round($cachedTokens, 1) } else { $null }
        CacheWriteTokens = [Math]::Round($cacheWriteTokens, 1)
        CacheHitPercent = $cacheHitPercent
        UncachedInputTokens = $uncachedInputTokens
        LastPromptCacheHitPercent = $guardSession.LastPromptCacheHitPercent
        ContextWindow = if ($hasContext) { [Math]::Round($contextWindow, 1) } else { $null }
        ContextUsedPercent = $contextPercent
        TokensLastMinute = [Math]::Round($tokensLastMinute, 1)
        OutputTokensLastMinute = [Math]::Round($outputTokensLastMinute, 1)
        TokenEventsLastMinute = $tokenEvents
        TokensPerMinute = [Math]::Round($tokensLastMinute, 1)
        TokensPerSecond = [Math]::Round($tokensPerSecond, 2)
        OutputTokensPerSecond = [Math]::Round($outputTokensPerSecond, 2)
        SessionPromptTokens = [Math]::Round($sessionPromptTokens, 1)
        SessionPromptInputTokens = [Math]::Round($sessionPromptInputTokens, 1)
        SessionPromptOutputTokens = [Math]::Round($sessionPromptOutputTokens, 1)
        SessionPromptCachedInputTokens = [Math]::Round($sessionPromptCachedInputTokens, 1)
        SessionPromptReasoningTokens = [Math]::Round($sessionPromptReasoningTokens, 1)
        SessionPromptCostUnits = [Math]::Round($sessionPromptCostUnits, 1)
        SessionPromptFastExtraCostUnits = [Math]::Round($sessionPromptFastExtraCostUnits, 1)
        RecentPromptCosts = $recentPromptCosts
        SessionPromptPrimaryUseDelta = if ($hasSessionPromptPrimaryUseDelta) { [Math]::Round($sessionPromptPrimaryUseDelta, 2) } else { $null }
        BurnCostUnitsPerPercent = if ($burnCalibrationPercent -gt 0 -and $burnCalibrationCostUnits -gt 0) { [Math]::Round($burnCalibrationCostUnits / $burnCalibrationPercent, 1) } else { $usageSession.BurnCostUnitsPerPercent }
        SessionPromptCount = $sessionPromptCount
        LastPromptCachedInputTokens = $guardSession.LastPromptCachedInputTokens
        LastPromptCacheWriteInputTokens = $guardSession.LastPromptCacheWriteInputTokens
        LastPromptReasoningTokens = $guardSession.LastPromptReasoningTokens
        LastPromptCostUnits = $guardSession.LastPromptCostUnits
        LastPromptFastExtraCostUnits = $guardSession.LastPromptFastExtraCostUnits
        FastMultiplier = $usageSession.FastMultiplier
        LastPromptFastMultiplier = $guardSession.LastPromptFastMultiplier
        ServiceTier = $usageSession.ServiceTier
        LastPromptPrimaryUseDelta = $guardSession.LastPromptPrimaryUseDelta
        LowContextPromptAvg = $guardSession.LowContextPromptAvg
        MidContextPromptAvg = $guardSession.MidContextPromptAvg
        HighContextPromptAvg = $guardSession.HighContextPromptAvg
        LastPromptContextPercent = $guardSession.LastPromptContextPercent
        LastPromptCostMultiplier = $guardSession.LastPromptCostMultiplier
        CompactSignal = $guardSession.CompactSignal
        PlanType = $usageSession.PlanType
        PrimaryUsedPercent = $usageSession.PrimaryUsedPercent
        PrimaryRemainingPercent = $usageSession.PrimaryRemainingPercent
        PrimaryReset = $usageSession.PrimaryReset
        PrimaryResetAt = $usageSession.PrimaryResetAt
        PrimaryWindowMinutes = $usageSession.PrimaryWindowMinutes
        SecondaryUsedPercent = $usageSession.SecondaryUsedPercent
        SecondaryRemainingPercent = $usageSession.SecondaryRemainingPercent
        SecondaryReset = $usageSession.SecondaryReset
        SecondaryResetAt = $usageSession.SecondaryResetAt
        SecondaryWindowMinutes = $usageSession.SecondaryWindowMinutes
        WeeklyUsedPercent = $usageSession.WeeklyUsedPercent
        WeeklyRemainingPercent = $usageSession.WeeklyRemainingPercent
        WeeklyReset = $usageSession.WeeklyReset
        WeeklyResetAt = $usageSession.WeeklyResetAt
        WeeklyWindowMinutes = $usageSession.WeeklyWindowMinutes
        LimitId = if (@($ordered | Select-Object -ExpandProperty UsageProfileKey -Unique).Count -gt 1) { "mixed" } else { $usageSession.LimitId }
    }
}

function Get-CodexBuddySnapshot {
    param(
        [string]$Root,
        [hashtable]$State,
        [string]$SessionPath = $null,
        [switch]$AllSessions
    )

    $path = if ($SessionPath -and (Test-Path -LiteralPath $SessionPath)) { $SessionPath } else { Get-LatestSessionPath -Root $Root -State $State }
    $process = Get-CodexProcessMetrics -State $State

    if (-not $path) {
        return [pscustomobject]@{
            Status = "no session"
            Session = $null
            Sessions = @()
            Process = $process
            Error = "No Codex session JSONL files found under $Root"
        }
    }

    try {
        if ($AllSessions) {
            $paths = @(Get-RecentSessionPaths -Root $Root -Max ([Math]::Max($MaxSessionTabs * 3, 12)) -ActiveSeconds 300 -State $State)
            if ($path -and -not ($paths -contains $path)) {
                $paths = @($path) + $paths | Select-Object -Unique
            }

            $sessions = @()
            foreach ($p in $paths) {
                if (Test-Path -LiteralPath $p) {
                    $sessions += Get-SessionMetrics -Path $p -State $State -CacheSeconds 4 -TailLines 720
                }
            }

            if ($sessions.Count -eq 0 -and $path) {
                    $sessions += Get-SessionMetrics -Path $path -State $State -CacheSeconds 4 -TailLines 720
            }

            $sessions = @(Get-DistinctUsageSessions -Sessions $sessions)
            $session = Merge-SessionMetrics -Sessions $sessions
        } else {
            $session = Get-SessionMetrics -Path $path -State $State -CacheSeconds 1 -TailLines 2000
            $sessions = @($session)
        }

        $forecast = Get-UsageForecast -Session $session
        $session | Add-Member -NotePropertyName UsageForecastStatus -NotePropertyValue $forecast.Status -Force
        $session | Add-Member -NotePropertyName UsageForecastText -NotePropertyValue $forecast.Text -Force
        $session | Add-Member -NotePropertyName UsageForecastSampleCount -NotePropertyValue $forecast.SampleCount -Force
        $session | Add-Member -NotePropertyName UsageForecastCoverageMinutes -NotePropertyValue $forecast.CoverageMinutes -Force
        $session | Add-Member -NotePropertyName UsageForecastRatePercentPerHour -NotePropertyValue $forecast.RatePercentPerHour -Force
        $session | Add-Member -NotePropertyName UsageForecastExhaustionAt -NotePropertyValue $forecast.ExhaustionAt -Force

        return [pscustomobject]@{
            Status = $session.Status
            Session = $session
            Sessions = @($sessions)
            Process = $process
            Error = $null
        }
    } catch {
        return [pscustomobject]@{
            Status = "error"
            Session = $null
            Sessions = @()
            Process = $process
            Error = $_.Exception.Message
        }
    }
}

if ($Once) {
    Get-CodexBuddySnapshot -Root $CodexHome -State $script:Sample -SessionPath $script:Sample.PinnedSessionPath | ConvertTo-Json -Depth 6
    exit
}

if ($DumpLimitEvents) {
    Get-CodexLimitEvents -Root $CodexHome -MaxEvents $DumpLimitEventCount |
        Select-Object Time,Session,LimitId,Plan,ActiveModel,TotalTokens,LastTokens,PrimaryUsedPercent,SecondaryUsedPercent |
        Format-Table -AutoSize
    exit
}

Import-LongContextAlertLedger
Import-BenchmarkRuns
Import-SessionUseResetBaselines
Import-UsageForecastSamples

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if (-not ("BuddyNative" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class BuddyNative {
    public const int GWL_EXSTYLE = -20;
    public const long WS_EX_TRANSPARENT = 0x20L;
    public const long WS_EX_LAYERED = 0x80000L;

    [DllImport("user32.dll", EntryPoint="GetWindowLong")]
    private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint="SetWindowLong")]
    private static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", EntryPoint="GetWindowLongPtr")]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint="SetWindowLongPtr")]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    public static long GetWindowLongPtr(IntPtr hWnd, int nIndex) {
        if (IntPtr.Size == 8) {
            return GetWindowLongPtr64(hWnd, nIndex).ToInt64();
        }
        return GetWindowLong32(hWnd, nIndex);
    }

    public static void SetWindowLongPtr(IntPtr hWnd, int nIndex, long dwNewLong) {
        if (IntPtr.Size == 8) {
            SetWindowLongPtr64(hWnd, nIndex, new IntPtr(dwNewLong));
        } else {
            SetWindowLong32(hWnd, nIndex, (int)dwNewLong);
        }
    }
}
"@
}
[System.Windows.Forms.Application]::EnableVisualStyles()

$font = New-Object System.Drawing.Font("Segoe UI", 9)
$monoFont = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$titleFont = New-Object System.Drawing.Font("Segoe UI Semibold", 11)
$smallFont = New-Object System.Drawing.Font("Segoe UI", 8.5)
$sectionFont = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5)

function Set-ThemePalette {
    param([bool]$Dark)

    if ($Dark) {
        $script:colorBg = [System.Drawing.Color]::FromArgb(15, 18, 24)
        $script:colorCard = [System.Drawing.Color]::FromArgb(25, 30, 39)
        $script:colorGraph = [System.Drawing.Color]::FromArgb(13, 16, 22)
        $script:colorBorder = [System.Drawing.Color]::FromArgb(40, 48, 62)
        $script:colorText = [System.Drawing.Color]::FromArgb(239, 242, 247)
        $script:colorMuted = [System.Drawing.Color]::FromArgb(151, 163, 181)
        $script:colorAccent = [System.Drawing.Color]::FromArgb(117, 224, 167)
        $script:colorBlue = [System.Drawing.Color]::FromArgb(102, 170, 255)
        $script:colorAmber = [System.Drawing.Color]::FromArgb(255, 199, 95)
        $script:colorCoral = [System.Drawing.Color]::FromArgb(242, 132, 130)
        $script:colorButton = [System.Drawing.Color]::FromArgb(28, 34, 44)
        $script:colorButtonActive = [System.Drawing.Color]::FromArgb(39, 49, 63)
        $script:colorButtonBorder = [System.Drawing.Color]::FromArgb(56, 66, 82)
        $script:colorButtonHover = [System.Drawing.Color]::FromArgb(41, 51, 65)
        $script:colorButtonDown = [System.Drawing.Color]::FromArgb(45, 56, 72)
        $script:colorStatusIdleText = [System.Drawing.Color]::FromArgb(188, 198, 214)
        $script:colorStatusIdleBack = [System.Drawing.Color]::FromArgb(31, 40, 52)
        $script:colorStatusActiveBack = [System.Drawing.Color]::FromArgb(27, 45, 39)
        $script:colorStatusWarmBack = [System.Drawing.Color]::FromArgb(49, 38, 26)
    } else {
        $script:colorBg = [System.Drawing.Color]::FromArgb(244, 247, 251)
        $script:colorCard = [System.Drawing.Color]::FromArgb(255, 255, 255)
        $script:colorGraph = [System.Drawing.Color]::FromArgb(233, 239, 247)
        $script:colorBorder = [System.Drawing.Color]::FromArgb(198, 208, 222)
        $script:colorText = [System.Drawing.Color]::FromArgb(31, 41, 55)
        $script:colorMuted = [System.Drawing.Color]::FromArgb(91, 104, 124)
        $script:colorAccent = [System.Drawing.Color]::FromArgb(28, 139, 94)
        $script:colorBlue = [System.Drawing.Color]::FromArgb(40, 111, 204)
        $script:colorAmber = [System.Drawing.Color]::FromArgb(181, 120, 20)
        $script:colorCoral = [System.Drawing.Color]::FromArgb(198, 73, 76)
        $script:colorButton = [System.Drawing.Color]::FromArgb(238, 243, 249)
        $script:colorButtonActive = [System.Drawing.Color]::FromArgb(219, 232, 245)
        $script:colorButtonBorder = [System.Drawing.Color]::FromArgb(185, 198, 216)
        $script:colorButtonHover = [System.Drawing.Color]::FromArgb(225, 235, 246)
        $script:colorButtonDown = [System.Drawing.Color]::FromArgb(210, 224, 240)
        $script:colorStatusIdleText = [System.Drawing.Color]::FromArgb(80, 94, 115)
        $script:colorStatusIdleBack = [System.Drawing.Color]::FromArgb(229, 236, 246)
        $script:colorStatusActiveBack = [System.Drawing.Color]::FromArgb(216, 244, 231)
        $script:colorStatusWarmBack = [System.Drawing.Color]::FromArgb(253, 238, 209)
    }
}

Set-ThemePalette -Dark $script:Sample.DarkMode

[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
[System.Windows.Forms.Application]::add_ThreadException({
    param($sender, $eventArgs)

    Write-BuddyCrashLog $eventArgs.Exception
    try {
        if ($status) {
            $status.Text = "ERROR"
            $status.ForeColor = $colorAmber
            $status.BackColor = $colorStatusWarmBack
            $uiTip.SetToolTip($status, $eventArgs.Exception.Message)
        }
    } catch {}
})
[AppDomain]::CurrentDomain.add_UnhandledException({
    param($sender, $eventArgs)

    Write-BuddyCrashLog $eventArgs.ExceptionObject
})

$form = New-Object System.Windows.Forms.Form
$form.Text = "Codex Buddy"
$form.Size = New-Object System.Drawing.Size(332, 812)
$form.MinimumSize = New-Object System.Drawing.Size(332, 360)
$form.StartPosition = "Manual"
$form.FormBorderStyle = "None"
$form.TopMost = $script:Sample.AlwaysOnTop
$form.BackColor = $colorBg
$form.ForeColor = $colorText
$form.Opacity = [Math]::Max(0.35, [Math]::Min(1.0, [double]$script:Sample.WindowOpacity / 100.0))
$form.ShowInTaskbar = $true
$script:PriceNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:PriceNotifyIcon.Icon = [System.Drawing.SystemIcons]::Warning
$script:PriceNotifyIcon.Text = "Codex Buddy cost alerts"
$script:PriceNotifyIcon.Visible = $true
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$formY = [Math]::Max($screen.Top, [Math]::Min(($screen.Bottom - $form.Height - 24), ($screen.Top + 48)))
$form.Location = New-Object System.Drawing.Point(($screen.Right - $form.Width - 24), $formY)

function Set-DoubleBuffered {
    param([System.Windows.Forms.Control]$Control)

    try {
        $prop = $Control.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]("NonPublic,Instance"))
        if ($prop) {
            $prop.SetValue($Control, $true, $null)
        }
    } catch {}
}

Set-DoubleBuffered -Control $form

$dragging = $false
$resizing = $false
$dragStartCursor = [System.Drawing.Point]::Empty
$dragStartForm = [System.Drawing.Point]::Empty
$resizeStartCursor = [System.Drawing.Point]::Empty
$resizeStartSize = [System.Drawing.Size]::Empty
$script:CardRects = @()
$script:RowGuides = @()
$form.Add_Paint({
    $brush = New-Object System.Drawing.SolidBrush($colorCard)
    $borderPen = New-Object System.Drawing.Pen($colorBorder, 1)
    $rowPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(28, $colorBorder.R, $colorBorder.G, $colorBorder.B), 1)

    $rects = if ($script:CardRects -and $script:CardRects.Count -gt 0) { $script:CardRects } else { @((New-Object System.Drawing.Rectangle(12, 44, ($form.ClientSize.Width - 24), ($form.ClientSize.Height - 88)))) }

    foreach ($rect in $rects) {
        $_.Graphics.FillRectangle($brush, $rect)
        $_.Graphics.DrawRectangle($borderPen, $rect)
    }

    foreach ($lineY in @($script:RowGuides)) {
        foreach ($rect in $rects) {
            if ($lineY -gt ($rect.Top + 24) -and $lineY -lt ($rect.Bottom - 8)) {
                $_.Graphics.DrawLine($rowPen, ($rect.Left + 10), $lineY, ($rect.Right - 10), $lineY)
                break
            }
        }
    }

    $brush.Dispose()
    $borderPen.Dispose()
    $rowPen.Dispose()
})

function Enable-DragAnywhere {
    param([System.Windows.Forms.Control]$Control)

    if ($Control.Tag -eq "resize-grip" -or $Control.Tag -eq "no-drag") {
        return
    }

    $Control.Add_MouseDown({
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $script:dragging = $true
            $script:dragStartCursor = [System.Windows.Forms.Cursor]::Position
            $script:dragStartForm = $form.Location
        }
    })

    $Control.Add_MouseMove({
        if ($script:dragging) {
            $cursor = [System.Windows.Forms.Cursor]::Position
            $dx = $cursor.X - $script:dragStartCursor.X
            $dy = $cursor.Y - $script:dragStartCursor.Y
            if ([Math]::Abs($dx) -lt 2 -and [Math]::Abs($dy) -lt 2) {
                return
            }
            $form.Location = New-Object System.Drawing.Point(($script:dragStartForm.X + $dx), ($script:dragStartForm.Y + $dy))
        }
    })

    $Control.Add_MouseUp({ $script:dragging = $false })

    foreach ($child in $Control.Controls) {
        Enable-DragAnywhere -Control $child
    }
}

function New-Label {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H,
        [System.Drawing.Font]$LabelFont = $font,
        [System.Drawing.Color]$Color = $colorMuted
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($W, $H)
    $label.Font = $LabelFont
    $label.ForeColor = $Color
    $label.BackColor = [System.Drawing.Color]::Transparent
    $label.AutoEllipsis = $true
    $form.Controls.Add($label)
    return $label
}

function New-Value {
    param([int]$X, [int]$Y, [int]$W, [int]$H)

    return New-Label -Text "..." -X $X -Y $Y -W $W -H $H -LabelFont $monoFont -Color $colorText
}

function New-Bar {
    param(
        [int]$X,
        [int]$Y,
        [int]$W,
        [System.Drawing.Color]$FillColor = $colorAccent
    )

    $bar = New-Object System.Windows.Forms.PictureBox
    $bar.Location = New-Object System.Drawing.Point($X, $Y)
    $bar.Size = New-Object System.Drawing.Size($W, 6)
    $bar.BackColor = $colorGraph
    $bar.Tag = $FillColor
    $form.Controls.Add($bar)
    return $bar
}

function New-Graph {
    param([int]$X, [int]$Y, [int]$W, [int]$H)

    $box = New-Object System.Windows.Forms.PictureBox
    $box.Location = New-Object System.Drawing.Point($X, $Y)
    $box.Size = New-Object System.Drawing.Size($W, $H)
    $box.BackColor = $colorGraph
    $form.Controls.Add($box)
    return $box
}

function Set-BarValue {
    param($Bar, $Value)

    if ($null -eq $Value) {
        $Value = 0
    }

    $percent = [Math]::Min(100, [Math]::Max(0, [double]$Value))
    $bitmap = New-Object System.Drawing.Bitmap($Bar.Width, $Bar.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear($colorGraph)

    $fillWidth = [int][Math]::Round(($Bar.Width * $percent) / 100)
    if ($fillWidth -gt 0) {
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]$Bar.Tag)
        $graphics.FillRectangle($brush, 0, 0, $fillWidth, $Bar.Height)
        $brush.Dispose()
    }

    $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(45, 54, 68), 1)
    $graphics.DrawRectangle($borderPen, 0, 0, $Bar.Width - 1, $Bar.Height - 1)
    $old = $Bar.Image
    $Bar.Image = $bitmap
    if ($old) {
        $old.Dispose()
    }

    $borderPen.Dispose()
    $graphics.Dispose()
}

function Draw-Graph {
    param(
        $Box,
        [array]$Series,
        [string]$Title,
        [System.Drawing.Color]$LineColor,
        [nullable[double]]$FixedMax = $null
    )

    $bitmap = New-Object System.Drawing.Bitmap($Box.Width, $Box.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear($colorGraph)

    $gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(38, 47, 61), 1)
    $linePen = New-Object System.Drawing.Pen($LineColor, 2)
    $textBrush = New-Object System.Drawing.SolidBrush($colorMuted)
    $valueBrush = New-Object System.Drawing.SolidBrush($colorText)
    $graphFont = New-Object System.Drawing.Font("Segoe UI", 7)

    $graphics.DrawLine($gridPen, 0, $Box.Height - 16, $Box.Width, $Box.Height - 16)
    $graphics.DrawLine($gridPen, 0, [int]($Box.Height / 2), $Box.Width, [int]($Box.Height / 2))

    $latest = if ($Series.Count -gt 0) { [double]$Series[$Series.Count - 1] } else { 0.0 }
    $max = if ($null -ne $FixedMax) { [double]$FixedMax } else { 1.0 }
    if ($null -eq $FixedMax -and $Series.Count -gt 0) {
        foreach ($value in $Series) {
            $max = [Math]::Max($max, [double]$value)
        }
    }

    $graphics.DrawString($Title, $graphFont, $textBrush, 6, 4)
    $graphics.DrawString((Format-Number $latest), $graphFont, $valueBrush, $Box.Width - 52, 4)

    if ($Series.Count -gt 1) {
        $points = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
        for ($i = 0; $i -lt $Series.Count; $i++) {
            $x = if ($Series.Count -eq 1) { 0 } else { ($i / ($Series.Count - 1)) * ($Box.Width - 8) + 4 }
            $normalized = [Math]::Min(1, [Math]::Max(0, [double]$Series[$i] / $max))
            $y = ($Box.Height - 18) - ($normalized * ($Box.Height - 32))
            $points.Add((New-Object System.Drawing.PointF([float]$x, [float]$y)))
        }

        $graphics.DrawLines($linePen, $points.ToArray())
    }

    $old = $Box.Image
    $Box.Image = $bitmap
    if ($old) {
        $old.Dispose()
    }

    $gridPen.Dispose()
    $linePen.Dispose()
    $textBrush.Dispose()
    $valueBrush.Dispose()
    $graphFont.Dispose()
    $graphics.Dispose()
}

function Draw-Sparkline {
    param(
        $Box,
        [array]$Series,
        [System.Drawing.Color]$LineColor,
        [nullable[double]]$FixedMax = $null
    )

    $bitmap = New-Object System.Drawing.Bitmap($Box.Width, $Box.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear($colorGraph)

    $gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(35, 43, 56), 1)
    $lineWidth = if ($Box.Height -ge 32) { 2.2 } else { 1.6 }
    $linePen = New-Object System.Drawing.Pen($LineColor, $lineWidth)

    $graphics.DrawLine($gridPen, 0, [int]($Box.Height / 2), $Box.Width, [int]($Box.Height / 2))
    if ($Box.Height -ge 32) {
        $graphics.DrawLine($gridPen, 0, [int]($Box.Height * 0.25), $Box.Width, [int]($Box.Height * 0.25))
        $graphics.DrawLine($gridPen, 0, [int]($Box.Height * 0.75), $Box.Width, [int]($Box.Height * 0.75))
    }

    if ($null -ne $FixedMax) {
        $min = 0.0
        $max = [Math]::Max(1.0, [double]$FixedMax)
    } elseif ($Series.Count -gt 0) {
        $min = [double]$Series[0]
        $max = [double]$Series[0]
        foreach ($value in $Series) {
            $min = [Math]::Min($min, [double]$value)
            $max = [Math]::Max($max, [double]$value)
        }
    } else {
        $min = 0.0
        $max = 1.0
    }

    if ($Series.Count -gt 1) {
        $range = $max - $min
        if ($range -le 0.001) {
            $min -= 1.0
            $max += 1.0
            $range = $max - $min
        } elseif ($null -eq $FixedMax) {
            $padding = $range * 0.18
            $min -= $padding
            $max += $padding
            $range = $max - $min
        }

        $points = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
        for ($i = 0; $i -lt $Series.Count; $i++) {
            $x = ($i / ($Series.Count - 1)) * ($Box.Width - 6) + 3
            $normalized = [Math]::Min(1, [Math]::Max(0, ([double]$Series[$i] - $min) / $range))
            $y = ($Box.Height - 4) - ($normalized * ($Box.Height - 8))
            $points.Add((New-Object System.Drawing.PointF([float]$x, [float]$y)))
        }

        $graphics.DrawLines($linePen, $points.ToArray())
        if ($Box.Height -ge 32) {
            $lastPoint = $points[$points.Count - 1]
            $brush = New-Object System.Drawing.SolidBrush($LineColor)
            $graphics.FillEllipse($brush, [int]$lastPoint.X - 3, [int]$lastPoint.Y - 3, 6, 6)
            $brush.Dispose()
        }
    } elseif ($Series.Count -eq 1) {
        $brush = New-Object System.Drawing.SolidBrush($LineColor)
        $graphics.FillEllipse($brush, [int]($Box.Width / 2) - 2, [int]($Box.Height / 2) - 2, 4, 4)
        $brush.Dispose()
    }

    $old = $Box.Image
    $Box.Image = $bitmap
    if ($old) {
        $old.Dispose()
    }

    $gridPen.Dispose()
    $linePen.Dispose()
    $graphics.Dispose()
}

function Draw-LimitGraph {
    param(
        $Box,
        [array]$PrimarySeries,
        [array]$SecondarySeries
    )

    $bitmap = New-Object System.Drawing.Bitmap($Box.Width, $Box.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear($colorGraph)

    $gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(38, 47, 61), 1)
    $primaryPen = New-Object System.Drawing.Pen($colorAccent, 2)
    $secondaryPen = New-Object System.Drawing.Pen($colorBlue, 2)
    $textBrush = New-Object System.Drawing.SolidBrush($colorMuted)
    $primaryBrush = New-Object System.Drawing.SolidBrush($primaryPen.Color)
    $secondaryBrush = New-Object System.Drawing.SolidBrush($secondaryPen.Color)
    $graphFont = New-Object System.Drawing.Font("Segoe UI", 7)

    $graphics.DrawLine($gridPen, 0, $Box.Height - 16, $Box.Width, $Box.Height - 16)
    $graphics.DrawLine($gridPen, 0, [int]($Box.Height / 2), $Box.Width, [int]($Box.Height / 2))
    $graphics.DrawString("Limit Left", $graphFont, $textBrush, 6, 4)
    $graphics.DrawString("5h", $graphFont, $primaryBrush, $Box.Width - 52, 4)
    $graphics.DrawString("wk", $graphFont, $secondaryBrush, $Box.Width - 27, 4)

    foreach ($pair in @(@($PrimarySeries, $primaryPen), @($SecondarySeries, $secondaryPen))) {
        $series = $pair[0]
        $pen = $pair[1]
        if ($series.Count -lt 2) {
            continue
        }

        $points = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
        for ($i = 0; $i -lt $series.Count; $i++) {
            $x = ($i / ($series.Count - 1)) * ($Box.Width - 8) + 4
            $normalized = [Math]::Min(1, [Math]::Max(0, [double]$series[$i] / 100))
            $y = ($Box.Height - 18) - ($normalized * ($Box.Height - 32))
            $points.Add((New-Object System.Drawing.PointF([float]$x, [float]$y)))
        }

        $graphics.DrawLines($pen, $points.ToArray())
    }

    $old = $Box.Image
    $Box.Image = $bitmap
    if ($old) {
        $old.Dispose()
    }

    $gridPen.Dispose()
    $primaryPen.Dispose()
    $secondaryPen.Dispose()
    $textBrush.Dispose()
    $primaryBrush.Dispose()
    $secondaryBrush.Dispose()
    $graphFont.Dispose()
    $graphics.Dispose()
}

$title = New-Label -Text "Codex Buddy" -X 18 -Y 12 -W 158 -H 24 -LabelFont $titleFont -Color $colorText
$subtitle = New-Label -Text "" -X 180 -Y 16 -W 60 -H 18 -LabelFont $smallFont -Color $colorMuted
$subtitle.Visible = $false
$status = New-Object System.Windows.Forms.Button
$status.Text = "starting"
$status.Location = New-Object System.Drawing.Point(244, 16)
$status.Size = New-Object System.Drawing.Size(72, 20)
$status.FlatStyle = "Flat"
$status.FlatAppearance.BorderSize = 0
$status.Font = $smallFont
$status.ForeColor = $colorAccent
$status.BackColor = $colorStatusIdleBack
$status.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$status.Cursor = [System.Windows.Forms.Cursors]::Default
$status.Tag = "no-drag"
$form.Controls.Add($status)

$close = New-Object System.Windows.Forms.Button
$close.Text = "X"
$close.Location = New-Object System.Drawing.Point(430, 12)
$close.Size = New-Object System.Drawing.Size(24, 24)
$close.FlatStyle = "Flat"
$close.FlatAppearance.BorderSize = 0
$close.BackColor = $colorButton
$close.ForeColor = $colorText
$close.Font = $smallFont
$close.Add_Click({ $form.Close() })
$form.Controls.Add($close)

$themeToggle = New-Object System.Windows.Forms.CheckBox
$themeToggle.Appearance = [System.Windows.Forms.Appearance]::Button
$themeToggle.Text = "Dark"
$themeToggle.Location = New-Object System.Drawing.Point(320, 12)
$themeToggle.Size = New-Object System.Drawing.Size(46, 24)
$themeToggle.FlatStyle = "Flat"
$themeToggle.FlatAppearance.BorderSize = 1
$themeToggle.FlatAppearance.BorderColor = $colorButtonBorder
$themeToggle.BackColor = $colorButton
$themeToggle.ForeColor = $colorText
$themeToggle.Font = $smallFont
$themeToggle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$themeToggle.Cursor = [System.Windows.Forms.Cursors]::Hand
$themeToggle.AutoCheck = $false
$form.Controls.Add($themeToggle)

$modeToggle = New-Object System.Windows.Forms.CheckBox
$modeToggle.Appearance = [System.Windows.Forms.Appearance]::Button
$modeToggle.Text = "Full"
$modeToggle.Location = New-Object System.Drawing.Point(372, 12)
$modeToggle.Size = New-Object System.Drawing.Size(52, 24)
$modeToggle.FlatStyle = "Flat"
$modeToggle.FlatAppearance.BorderSize = 1
$modeToggle.FlatAppearance.BorderColor = $colorButtonBorder
$modeToggle.BackColor = $colorButton
$modeToggle.ForeColor = $colorText
$modeToggle.Font = $smallFont
$modeToggle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$modeToggle.Cursor = [System.Windows.Forms.Cursors]::Hand
$modeToggle.AutoCheck = $false
$form.Controls.Add($modeToggle)

$speedSectionLabel = New-Label -Text "Now" -X 22 -Y 54 -W 120 -H 16 -LabelFont $sectionFont -Color $colorAccent
$verdictLabel = New-Label -Text "Verdict" -X 22 -Y 78 -W 100 -H 20
$verdictText = New-Value -X 132 -Y 78 -W 315 -H 20
$benchmarkButton = New-Object System.Windows.Forms.Button
$benchmarkButton.Text = "Bench"
$benchmarkButton.Location = New-Object System.Drawing.Point(348, 78)
$benchmarkButton.Size = New-Object System.Drawing.Size(50, 20)
$benchmarkButton.FlatStyle = "Flat"
$benchmarkButton.FlatAppearance.BorderSize = 1
$benchmarkButton.FlatAppearance.BorderColor = $colorButtonBorder
$benchmarkButton.BackColor = $colorButton
$benchmarkButton.ForeColor = $colorText
$benchmarkButton.Font = $smallFont
$benchmarkButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$benchmarkButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$benchmarkButton.Tag = "no-drag"
$form.Controls.Add($benchmarkButton)
$detailsButton = New-Object System.Windows.Forms.Button
$detailsButton.Text = "Info"
$detailsButton.Location = New-Object System.Drawing.Point(402, 78)
$detailsButton.Size = New-Object System.Drawing.Size(44, 20)
$detailsButton.FlatStyle = "Flat"
$detailsButton.FlatAppearance.BorderSize = 1
$detailsButton.FlatAppearance.BorderColor = $colorButtonBorder
$detailsButton.BackColor = $colorButton
$detailsButton.ForeColor = $colorText
$detailsButton.Font = $smallFont
$detailsButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$detailsButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$detailsButton.Tag = "no-drag"
$form.Controls.Add($detailsButton)
$syncButton = New-Object System.Windows.Forms.Button
$syncButton.Text = "Sync"
$syncButton.Location = New-Object System.Drawing.Point(300, 78)
$syncButton.Size = New-Object System.Drawing.Size(42, 20)
$syncButton.FlatStyle = "Flat"
$syncButton.FlatAppearance.BorderSize = 1
$syncButton.FlatAppearance.BorderColor = $colorButtonBorder
$syncButton.BackColor = $colorButton
$syncButton.ForeColor = $colorText
$syncButton.Font = $smallFont
$syncButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$syncButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$syncButton.Tag = "no-drag"
$form.Controls.Add($syncButton)
$tokensWindowLabel = New-Label -Text "Session Use" -X 22 -Y 78 -W 100 -H 20
$tokensRate = New-Value -X 132 -Y 78 -W 115 -H 20
$tokenSecondRate = New-Value -X 262 -Y 78 -W 185 -H 20
$speedBarLegend = New-Label -Text "Speed Bar" -X 22 -Y 100 -W 100 -H 18 -LabelFont $smallFont -Color $colorAccent
$speedBar = New-Bar -X 262 -Y 95 -W 185 -FillColor $colorAccent
$speedBarValue = New-Value -X 132 -Y 100 -W 315 -H 18
$tokenUseBarLegend = New-Label -Text "Session Bar" -X 22 -Y 144 -W 100 -H 18 -LabelFont $smallFont -Color $colorBlue
$tokenUseBar = New-Bar -X 262 -Y 123 -W 185 -FillColor $colorBlue
$tokenUseBarValue = New-Value -X 132 -Y 144 -W 315 -H 18

$eventSpeedLabel = New-Label -Text "Tools" -X 22 -Y 106 -W 100 -H 20
$eventsRate = New-Value -X 132 -Y 106 -W 115 -H 20
$speedScale = New-Value -X 262 -Y 106 -W 185 -H 20

$processLabel = New-Label -Text "System" -X 22 -Y 134 -W 100 -H 20
$processText = New-Value -X 132 -Y 134 -W 315 -H 20

$lastToolLabel = New-Label -Text "Last Tool" -X 22 -Y 162 -W 100 -H 20
$lastTool = New-Value -X 132 -Y 162 -W 315 -H 20

$tokensSectionLabel = New-Label -Text "Cost & Limits" -X 22 -Y 220 -W 140 -H 16 -LabelFont $sectionFont -Color $colorBlue
$tokensLabel = New-Label -Text "Session Use" -X 22 -Y 244 -W 100 -H 20
$tokenTotal = New-Value -X 132 -Y 244 -W 115 -H 20
$sessionUseResetButton = New-Object System.Windows.Forms.Button
$sessionUseResetButton.Text = "Rst"
$sessionUseResetButton.Location = New-Object System.Drawing.Point(402, 244)
$sessionUseResetButton.Size = New-Object System.Drawing.Size(44, 20)
$sessionUseResetButton.FlatStyle = "Flat"
$sessionUseResetButton.FlatAppearance.BorderSize = 1
$sessionUseResetButton.FlatAppearance.BorderColor = $colorButtonBorder
$sessionUseResetButton.BackColor = $colorButton
$sessionUseResetButton.ForeColor = $colorText
$sessionUseResetButton.Font = $smallFont
$sessionUseResetButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$sessionUseResetButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$sessionUseResetButton.Tag = "no-drag"
$form.Controls.Add($sessionUseResetButton)
$tokenOutput = New-Value -X 262 -Y 244 -W 185 -H 20
$tokenLastLabel = New-Label -Text "Last Ask" -X 22 -Y 266 -W 100 -H 20
$lastTurn = New-Value -X 132 -Y 266 -W 315 -H 20
$sessionTokenLabel = New-Label -Text "Cost Signal" -X 22 -Y 288 -W 100 -H 20
$sessionTokens = New-Value -X 132 -Y 288 -W 315 -H 20
$priceStepLabel = New-Label -Text "Long Chat" -X 22 -Y 310 -W 100 -H 20
$priceStepText = New-Value -X 132 -Y 310 -W 315 -H 20
$priceStepBar = New-Bar -X 132 -Y 334 -W 315 -FillColor $colorAmber

$contextLabel = New-Label -Text "Context" -X 22 -Y 352 -W 100 -H 20
$contextText = New-Value -X 132 -Y 352 -W 115 -H 20
$contextBar = New-Bar -X 262 -Y 376 -W 185 -FillColor $colorBlue

$primaryLabel = New-Label -Text "5h Limit" -X 22 -Y 394 -W 100 -H 20
$primaryText = New-Value -X 132 -Y 394 -W 115 -H 20
$primaryReset = New-Value -X 262 -Y 394 -W 185 -H 20
$primaryBar = New-Bar -X 132 -Y 418 -W 315 -FillColor $colorAccent

$secondaryLabel = New-Label -Text "Week Limit" -X 22 -Y 436 -W 100 -H 20
$secondaryText = New-Value -X 132 -Y 436 -W 115 -H 20
$secondaryReset = New-Value -X 262 -Y 436 -W 185 -H 20
$secondaryBar = New-Bar -X 132 -Y 460 -W 315 -FillColor $colorBlue

$historySectionLabel = New-Label -Text "Rolling History" -X 22 -Y 498 -W 140 -H 16 -LabelFont $sectionFont -Color $colorCoral
$tokenGraph = New-Graph -X 22 -Y 522 -W 201 -H 70
$processGraph = New-Graph -X 238 -Y 522 -W 201 -H 70
$useGraph = New-Graph -X 22 -Y 604 -W 201 -H 70
$limitGraph = New-Graph -X 238 -Y 604 -W 201 -H 70

$allSessionsSectionLabel = New-Label -Text "All Chats" -X 22 -Y 498 -W 140 -H 16 -LabelFont $sectionFont -Color $colorCoral

$sessionLabel = New-Label -Text "Session" -X 22 -Y 710 -W 100 -H 20
$sessionText = New-Value -X 132 -Y 710 -W 315 -H 20
$sessionMeta = New-Label -Text "..." -X 132 -Y 728 -W 315 -H 14 -LabelFont $smallFont -Color $colorMuted
$streamsLabel = New-Label -Text "Sessions" -X 22 -Y 38 -W 100 -H 16 -LabelFont $sectionFont -Color $colorBlue

$sessionTabStrip = New-Object System.Windows.Forms.FlowLayoutPanel
$sessionTabStrip.Location = New-Object System.Drawing.Point(92, 36)
$sessionTabStrip.Size = New-Object System.Drawing.Size(324, 22)
$sessionTabStrip.WrapContents = $false
$sessionTabStrip.AutoScroll = $false
$sessionTabStrip.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$sessionTabStrip.BackColor = [System.Drawing.Color]::Transparent
Set-DoubleBuffered -Control $sessionTabStrip
$form.Controls.Add($sessionTabStrip)

$footer = New-Label -Text "drag to move" -X 18 -Y 796 -W 200 -H 18 -LabelFont $smallFont
$planText = New-Label -Text "plan unknown" -X 258 -Y 796 -W 185 -H 18 -LabelFont $smallFont -Color $colorMuted
$miniSummary = New-Label -Text "..." -X 22 -Y 188 -W 425 -H 18 -LabelFont $smallFont -Color $colorMuted
$opacityLabel = New-Label -Text ("Opacity {0}%" -f $script:Sample.WindowOpacity) -X 176 -Y 796 -W 82 -H 18 -LabelFont $smallFont -Color $colorMuted
$opacitySlider = New-Object System.Windows.Forms.TrackBar
$opacitySlider.Location = New-Object System.Drawing.Point(258, 790)
$opacitySlider.Size = New-Object System.Drawing.Size(110, 24)
$opacitySlider.Minimum = 35
$opacitySlider.Maximum = 100
$opacitySlider.Value = [Math]::Max($opacitySlider.Minimum, [Math]::Min($opacitySlider.Maximum, [int]$script:Sample.WindowOpacity))
$opacitySlider.TickStyle = [System.Windows.Forms.TickStyle]::None
$opacitySlider.BackColor = $colorBg
$opacitySlider.Cursor = [System.Windows.Forms.Cursors]::Hand
$opacitySlider.Tag = "no-drag"
$form.Controls.Add($opacitySlider)
$resizeGrip = New-Label -Text "..." -X 436 -Y 806 -W 22 -H 18 -LabelFont $smallFont -Color $colorMuted
$resizeGrip.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$resizeGrip.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
$resizeGrip.Tag = "resize-grip"

$settingsGear = New-Object System.Windows.Forms.Button
$settingsGear.Text = [string][char]0x2699
$settingsGear.Location = New-Object System.Drawing.Point(400, 806)
$settingsGear.Size = New-Object System.Drawing.Size(24, 22)
$settingsGear.FlatStyle = "Flat"
$settingsGear.FlatAppearance.BorderSize = 1
$settingsGear.FlatAppearance.BorderColor = $colorButtonBorder
$settingsGear.BackColor = $colorButton
$settingsGear.ForeColor = $colorText
$settingsGear.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 9)
$settingsGear.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$settingsGear.Cursor = [System.Windows.Forms.Cursors]::Hand
$settingsGear.Tag = "no-drag"
$form.Controls.Add($settingsGear)

$gearForm = New-Object System.Windows.Forms.Form
$gearForm.Text = "Codex Buddy Settings"
$gearForm.Size = New-Object System.Drawing.Size(34, 34)
$gearForm.FormBorderStyle = "None"
$gearForm.StartPosition = "Manual"
$gearForm.ShowInTaskbar = $false
$gearForm.TopMost = $script:Sample.AlwaysOnTop
$gearForm.BackColor = $colorBg
$gearForm.Opacity = 0.96

$gearButton = New-Object System.Windows.Forms.Button
$gearButton.Text = [string][char]0x2699
$gearButton.Location = New-Object System.Drawing.Point(3, 3)
$gearButton.Size = New-Object System.Drawing.Size(28, 28)
$gearButton.FlatStyle = "Flat"
$gearButton.FlatAppearance.BorderSize = 1
$gearButton.FlatAppearance.BorderColor = $colorButtonBorder
$gearButton.BackColor = $colorButton
$gearButton.ForeColor = $colorText
$gearButton.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 9)
$gearButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$gearForm.Controls.Add($gearButton)

$settingsForm = New-Object System.Windows.Forms.Form
$settingsForm.Text = "Codex Buddy Settings"
$settingsForm.Size = New-Object System.Drawing.Size(244, 146)
$settingsForm.FormBorderStyle = "None"
$settingsForm.StartPosition = "Manual"
$settingsForm.ShowInTaskbar = $false
$settingsForm.TopMost = $script:Sample.AlwaysOnTop
$settingsForm.BackColor = $colorCard
$settingsForm.ForeColor = $colorText
$settingsForm.Opacity = 0.98
$settingsForm.Visible = $false

$settingsTitle = New-Object System.Windows.Forms.Label
$settingsTitle.Text = "Settings"
$settingsTitle.Location = New-Object System.Drawing.Point(12, 10)
$settingsTitle.Size = New-Object System.Drawing.Size(86, 18)
$settingsTitle.Font = $sectionFont
$settingsTitle.ForeColor = $colorText
$settingsTitle.BackColor = [System.Drawing.Color]::Transparent
$settingsForm.Controls.Add($settingsTitle)

$settingsOpacityLabel = New-Object System.Windows.Forms.Label
$settingsOpacityLabel.Text = ("Opacity {0}%" -f $script:Sample.WindowOpacity)
$settingsOpacityLabel.Location = New-Object System.Drawing.Point(12, 38)
$settingsOpacityLabel.Size = New-Object System.Drawing.Size(88, 18)
$settingsOpacityLabel.Font = $smallFont
$settingsOpacityLabel.ForeColor = $colorMuted
$settingsOpacityLabel.BackColor = [System.Drawing.Color]::Transparent
$settingsForm.Controls.Add($settingsOpacityLabel)

$settingsOpacitySlider = New-Object System.Windows.Forms.TrackBar
$settingsOpacitySlider.Location = New-Object System.Drawing.Point(98, 32)
$settingsOpacitySlider.Size = New-Object System.Drawing.Size(128, 28)
$settingsOpacitySlider.Minimum = 35
$settingsOpacitySlider.Maximum = 100
$settingsOpacitySlider.Value = [Math]::Max($settingsOpacitySlider.Minimum, [Math]::Min($settingsOpacitySlider.Maximum, [int]$script:Sample.WindowOpacity))
$settingsOpacitySlider.TickStyle = [System.Windows.Forms.TickStyle]::None
$settingsOpacitySlider.BackColor = $colorCard
$settingsOpacitySlider.Cursor = [System.Windows.Forms.Cursors]::Hand
$settingsForm.Controls.Add($settingsOpacitySlider)

$topMostToggle = New-Object System.Windows.Forms.CheckBox
$topMostToggle.Text = "Always on top"
$topMostToggle.Location = New-Object System.Drawing.Point(12, 70)
$topMostToggle.Size = New-Object System.Drawing.Size(220, 22)
$topMostToggle.Checked = $script:Sample.AlwaysOnTop
$topMostToggle.ForeColor = $colorText
$topMostToggle.BackColor = $colorCard
$topMostToggle.Font = $smallFont
$settingsForm.Controls.Add($topMostToggle)

$clickThroughToggle = New-Object System.Windows.Forms.CheckBox
$clickThroughToggle.Text = "Click through Buddy"
$clickThroughToggle.Location = New-Object System.Drawing.Point(12, 100)
$clickThroughToggle.Size = New-Object System.Drawing.Size(220, 22)
$clickThroughToggle.Checked = $script:Sample.ClickThrough
$clickThroughToggle.ForeColor = $colorText
$clickThroughToggle.BackColor = $colorCard
$clickThroughToggle.Font = $smallFont
$settingsForm.Controls.Add($clickThroughToggle)

$detailsForm = New-Object System.Windows.Forms.Form
$detailsForm.Text = "Codex Buddy Details"
$detailsForm.Size = New-Object System.Drawing.Size(430, 470)
$detailsForm.MinimumSize = New-Object System.Drawing.Size(360, 260)
$detailsForm.FormBorderStyle = "SizableToolWindow"
$detailsForm.StartPosition = "Manual"
$detailsForm.ShowInTaskbar = $false
$detailsForm.TopMost = $script:Sample.AlwaysOnTop
$detailsForm.BackColor = $colorCard
$detailsForm.ForeColor = $colorText
$detailsForm.Opacity = 0.98
$detailsForm.Visible = $false

$detailsText = New-Object System.Windows.Forms.TextBox
$detailsText.Multiline = $true
$detailsText.ReadOnly = $true
$detailsText.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$detailsText.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$detailsText.Location = New-Object System.Drawing.Point(12, 12)
$detailsText.Size = New-Object System.Drawing.Size(390, 385)
$detailsText.Anchor = ([System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$detailsText.Font = $monoFont
$detailsText.BackColor = $colorCard
$detailsText.ForeColor = $colorText
$detailsText.Text = "Waiting for session data."
$detailsForm.Controls.Add($detailsText)

$benchmarkExportButton = New-Object System.Windows.Forms.Button
$benchmarkExportButton.Text = "Export benchmarks"
$benchmarkExportButton.Location = New-Object System.Drawing.Point(12, 405)
$benchmarkExportButton.Size = New-Object System.Drawing.Size(118, 24)
$benchmarkExportButton.Anchor = ([System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$benchmarkExportButton.FlatStyle = "Flat"
$benchmarkExportButton.FlatAppearance.BorderSize = 1
$benchmarkExportButton.FlatAppearance.BorderColor = $colorButtonBorder
$benchmarkExportButton.BackColor = $colorButton
$benchmarkExportButton.ForeColor = $colorText
$benchmarkExportButton.Font = $smallFont
$benchmarkExportButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$detailsForm.Controls.Add($benchmarkExportButton)

function New-AllSessionRow {
    param([int]$Y)

    $name = New-Label -Text "..." -X 24 -Y $Y -W 150 -H 18 -LabelFont $smallFont -Color $colorText
    $detail = New-Label -Text "..." -X 180 -Y $Y -W 262 -H 18 -LabelFont $smallFont -Color $colorMuted
    $detail.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    return [pscustomobject]@{
        Name = $name
        Detail = $detail
    }
}

function New-MiniRow {
    param(
        [string]$Text,
        [int]$Y,
        [System.Drawing.Color]$AccentColor
    )

    $name = New-Label -Text $Text -X 24 -Y $Y -W 110 -H 18 -LabelFont $smallFont -Color $colorMuted
    $value = New-Label -Text "..." -X 142 -Y $Y -W 120 -H 18 -LabelFont $monoFont -Color $colorText
    $graph = New-Graph -X 276 -Y ($Y + 1) -W 166 -H 16
    $value.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $graph.Tag = $AccentColor
    Set-DoubleBuffered -Control $graph
    return [pscustomobject]@{
        Label = $name
        Value = $value
        Graph = $graph
        Color = $AccentColor
    }
}

$miniRows = @(
    (New-MiniRow -Text "Profile" -Y 60 -AccentColor $colorAccent),
    (New-MiniRow -Text "Reply Speed" -Y 89 -AccentColor $colorAccent),
    (New-MiniRow -Text "Chat Cost" -Y 181 -AccentColor $colorBlue),
    (New-MiniRow -Text "Work Rate" -Y 210 -AccentColor $colorCoral),
    (New-MiniRow -Text "Chat Size" -Y 239 -AccentColor $colorBlue),
    (New-MiniRow -Text "5h Left" -Y 268 -AccentColor $colorAccent),
    (New-MiniRow -Text "Week Left" -Y 297 -AccentColor $colorBlue),
    (New-MiniRow -Text "System" -Y 326 -AccentColor $colorAmber)
)

$miniRows[1].Value.Location = New-Object System.Drawing.Point(270, 89)
$miniRows[1].Value.Size = New-Object System.Drawing.Size(172, 18)
$miniRows[1].Graph.Location = New-Object System.Drawing.Point(24, 112)
$miniRows[1].Graph.Size = New-Object System.Drawing.Size(418, 54)

foreach ($row in $miniRows) {
    $row.Label.Visible = $false
    $row.Value.Visible = $false
    $row.Graph.Visible = $false
}

foreach ($valueLabel in @(
    $verdictText, $tokensRate, $tokenSecondRate, $eventsRate, $speedScale,
    $speedBarValue, $tokenUseBarValue, $tokenTotal, $tokenOutput, $lastTurn, $sessionTokens, $priceStepText, $contextText, $primaryText, $secondaryText,
    $primaryReset, $secondaryReset
)) {
    $valueLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
}

foreach ($textLabel in @($processText, $lastTool, $sessionText)) {
    $textLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
}

$uiTip = New-Object System.Windows.Forms.ToolTip
$uiTip.AutoPopDelay = 12000
$uiTip.InitialDelay = 250
$uiTip.ReshowDelay = 100
$uiTip.ShowAlways = $true

function Set-ControlBounds {
    param(
        [System.Windows.Forms.Control]$Control,
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H
    )

    if (-not $Control) {
        return
    }

    $Control.Bounds = New-Object System.Drawing.Rectangle($X, $Y, ([Math]::Max(1, $W)), ([Math]::Max(1, $H)))
}

function Set-ControlsVisible {
    param(
        [array]$Controls,
        [bool]$Visible
    )

    foreach ($control in $Controls) {
        if ($control) {
            $control.Visible = $Visible
        }
    }
}

function Set-BuddyOpacity {
    param([int]$Percent)

    $script:Sample.WindowOpacity = [Math]::Max(35, [Math]::Min(100, $Percent))
    $form.Opacity = [Math]::Max(0.35, [Math]::Min(1.0, [double]$script:Sample.WindowOpacity / 100.0))
    $opacityLabel.Text = ("Opacity {0}%" -f $script:Sample.WindowOpacity)
    if ($settingsOpacityLabel) {
        $settingsOpacityLabel.Text = ("Opacity {0}%" -f $script:Sample.WindowOpacity)
    }
}

function Set-BuddyTopMost {
    param([bool]$Enabled)

    $script:Sample.AlwaysOnTop = $Enabled
    $form.TopMost = $Enabled
    $gearForm.TopMost = $Enabled
    $settingsForm.TopMost = $Enabled
    $detailsForm.TopMost = $Enabled
    $topMostToggle.Checked = $Enabled
}

$allSessionRows = @(
    (New-AllSessionRow -Y 524),
    (New-AllSessionRow -Y 548),
    (New-AllSessionRow -Y 572),
    (New-AllSessionRow -Y 596),
    (New-AllSessionRow -Y 620),
    (New-AllSessionRow -Y 644)
)

foreach ($row in $allSessionRows) {
    $row.Name.Visible = $false
    $row.Detail.Visible = $false
}

function Set-BuddyClickThrough {
    param([bool]$Enabled)

    $script:Sample.ClickThrough = $Enabled
    $style = [BuddyNative]::GetWindowLongPtr($form.Handle, [BuddyNative]::GWL_EXSTYLE)
    if ($Enabled) {
        $style = $style -bor [BuddyNative]::WS_EX_LAYERED -bor [BuddyNative]::WS_EX_TRANSPARENT
        $settingsForm.Visible = $false
        Sync-SettingsWindows
        $gearForm.Show()
    } else {
        $style = $style -band (-bnot [BuddyNative]::WS_EX_TRANSPARENT)
        $gearForm.Hide()
    }

    [BuddyNative]::SetWindowLongPtr($form.Handle, [BuddyNative]::GWL_EXSTYLE, $style)
    $clickThroughToggle.Checked = $Enabled
    $gearButton.BackColor = if ($Enabled) { $colorButtonActive } else { $colorButton }
}

function Sync-SettingsWindows {
    if (-not $form -or -not $gearForm) {
        return
    }

    $workArea = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    $gearX = [Math]::Max($workArea.Left, [Math]::Min(($workArea.Right - $gearForm.Width), ($form.Location.X + 8)))
    $gearY = [Math]::Max($workArea.Top, [Math]::Min(($workArea.Bottom - $gearForm.Height), ($form.Location.Y + $form.Height - 42)))
    $gearForm.Location = New-Object System.Drawing.Point($gearX, $gearY)
    if ($settingsForm) {
        $anchorX = if ($script:Sample.ClickThrough) { $gearForm.Location.X } else { $form.Location.X + $settingsGear.Left }
        $anchorY = if ($script:Sample.ClickThrough) { $gearForm.Location.Y } else { $form.Location.Y + $settingsGear.Top }
        $settingsX = [Math]::Max($workArea.Left, [Math]::Min(($workArea.Right - $settingsForm.Width), ($anchorX - $settingsForm.Width + 34)))
        $settingsY = [Math]::Max($workArea.Top, [Math]::Min(($workArea.Bottom - $settingsForm.Height), ($anchorY - $settingsForm.Height - 8)))
        $settingsForm.Location = New-Object System.Drawing.Point($settingsX, $settingsY)
    }
    if ($detailsForm -and $script:Sample.DetailsOpen) {
        $detailsX = [Math]::Max($workArea.Left, [Math]::Min(($workArea.Right - $detailsForm.Width), ($form.Location.X - $detailsForm.Width - 10)))
        if ($detailsX -lt $workArea.Left + 4) {
            $detailsX = [Math]::Max($workArea.Left, [Math]::Min(($workArea.Right - $detailsForm.Width), ($form.Location.X + $form.Width + 10)))
        }
        $detailsY = [Math]::Max($workArea.Top, [Math]::Min(($workArea.Bottom - $detailsForm.Height), $form.Location.Y))
        $detailsForm.Location = New-Object System.Drawing.Point($detailsX, $detailsY)
    }
}

function Set-SettingsOpen {
    param([bool]$Open)

    Sync-SettingsWindows
    $settingsForm.Visible = $Open
    if ($Open) {
        $settingsForm.Activate()
    }
}

function Update-ResponsiveLayout {
    if (-not $form) {
        return
    }

    if ($script:Sample.LayoutBusy) {
        return
    }

    $script:Sample.LayoutBusy = $true
    $form.SuspendLayout()
    try {
    $w = [Math]::Max($form.MinimumSize.Width, $form.ClientSize.Width)
    $h = [Math]::Max($form.MinimumSize.Height, $form.ClientSize.Height)
    $innerX = 18
    $innerW = [Math]::Max(220, $w - 36)
    $rightEdge = $innerX + $innerW
    $compact = ($w -lt 380)
    $labelW = if ($compact) { 86 } elseif ($w -lt 500) { 96 } else { 118 }
    $valueX = $innerX + $labelW + 6
    $leftValueW = if ($compact) { 82 } elseif ($w -lt 500) { 104 } else { 156 }
    $rightX = $valueX + $leftValueW + 8
    $rightW = [Math]::Max(64, $rightEdge - $rightX)
    $fullValueW = [Math]::Max(96, $rightEdge - $valueX)
    $meterW = [Math]::Max(112, [Math]::Min($fullValueW, [int][Math]::Round($fullValueW * 0.62)))
    $graphW = [Math]::Max(150, [Math]::Min($innerW, [int][Math]::Round($innerW * 0.66)))
    $barH = 6
    $cardX = 10
    $cardW = [Math]::Max(250, $w - 20)
    $bottomY = [Math]::Max(260, $h - 28)
    $hidden = $false

    $closeX = $w - 36
    $modeW = if ($compact) { 48 } else { 52 }
    $themeW = if ($compact) { 44 } else { 46 }
    $statusW = if ($compact) { 64 } else { 72 }
    $modeX = $closeX - ($modeW + 6)
    $themeX = $modeX - ($themeW + 6)
    $statusX = $themeX - ($statusW + 6)
    Set-ControlBounds $close $closeX 12 24 24
    Set-ControlBounds $modeToggle $modeX 12 $modeW 24
    Set-ControlBounds $themeToggle $themeX 12 $themeW 24
    Set-ControlBounds $status ([Math]::Max(104, $statusX)) 16 $statusW 20
    Set-ControlBounds $title 18 12 ([Math]::Max(72, [Math]::Min(158, $statusX - 24))) 24
    $subtitle.Visible = $false

    if ($script:Sample.MiniMode) {
        $cardH = [Math]::Max(180, $h - 80)
        $script:CardRects = @((New-Object System.Drawing.Rectangle($cardX, 44, $cardW, $cardH)))
        $script:RowGuides = @(82, 174, 203, 232, 261, 290, 319)
        $miniSummaryY = [Math]::Min(178, $h - 46)
        Set-ControlBounds $miniSummary $innerX $miniSummaryY $innerW 20
        $opacityLabel.Visible = $false
        $opacitySlider.Visible = $false

        $graphX = [Math]::Max(236, $w - 194)
        $graphW = [Math]::Max(84, $rightEdge - $graphX)
        foreach ($row in $miniRows) {
            $row.Label.Size = New-Object System.Drawing.Size(([Math]::Max(78, $labelW + 10)), 18)
            $row.Value.Location = New-Object System.Drawing.Point(($innerX + $labelW + 20), $row.Value.Location.Y)
            $row.Value.Size = New-Object System.Drawing.Size(([Math]::Max(72, $graphX - $row.Value.Location.X - 10)), 18)
            $row.Graph.Location = New-Object System.Drawing.Point($graphX, $row.Graph.Location.Y)
            $row.Graph.Size = New-Object System.Drawing.Size($graphW, $row.Graph.Height)
            $visible = ($row.Label.Location.Y + $row.Label.Height -le ($h - 34))
            $row.Label.Visible = $visible
            $row.Value.Visible = $visible
            $row.Graph.Visible = $visible
            if (-not $visible) { $hidden = $true }
        }

        $miniRows[1].Value.Location = New-Object System.Drawing.Point($graphX, 89)
        $miniRows[1].Value.Size = New-Object System.Drawing.Size($graphW, 18)
        $miniRows[1].Graph.Location = New-Object System.Drawing.Point($innerX, 112)
        $miniRows[1].Graph.Size = New-Object System.Drawing.Size($innerW, 54)
        $footer.Visible = $false
        $planText.Visible = $false
        $opacityLabel.Visible = $false
        $opacitySlider.Visible = $false
    } else {
        $speedControls = @($speedSectionLabel, $verdictLabel, $verdictText, $benchmarkButton, $detailsButton, $syncButton, $tokensWindowLabel, $tokensRate, $tokenSecondRate, $speedBarLegend, $speedBarValue, $speedBar, $tokenUseBarLegend, $tokenUseBarValue, $tokenUseBar, $eventSpeedLabel, $eventsRate, $speedScale, $processLabel, $processText, $lastToolLabel, $lastTool)
        $tokenBaseControls = @($tokensSectionLabel, $tokensLabel, $tokenTotal, $sessionUseResetButton, $tokenOutput, $tokenLastLabel, $lastTurn, $sessionTokenLabel, $sessionTokens, $priceStepLabel, $priceStepText, $priceStepBar)
        $limitControls = @($contextLabel, $contextText, $contextBar, $primaryLabel, $primaryText, $primaryReset, $primaryBar, $secondaryLabel, $secondaryText, $secondaryReset, $secondaryBar)
        $allSessionControls = @($allSessionsSectionLabel)
        foreach ($row in $allSessionRows) {
            $allSessionControls += @($row.Name, $row.Detail)
        }
        $historyControls = @($historySectionLabel, $tokenGraph, $processGraph, $useGraph, $limitGraph) + $allSessionControls
        $sessionControls = @($sessionLabel, $sessionText, $sessionMeta)

        $script:CardRects = @((New-Object System.Drawing.Rectangle($cardX, 44, $cardW, 248)))
        $script:RowGuides = @(84, 108, 132, 164, 188, 220, 240, 266, 316, 340, 364, 388, 430, 468, 506)
        Set-ControlsVisible $speedControls $true
        $streamsLabel.Visible = $false
        Set-ControlBounds $sessionTabStrip $innerX 36 $innerW 22
        Update-SessionTabLayout
        Set-ControlBounds $speedSectionLabel $innerX 64 120 16
        Set-ControlBounds $verdictLabel $innerX 86 $labelW 20
        $detailsW = 44
        $benchmarkW = 50
        $syncW = 42
        Set-ControlBounds $detailsButton ($rightEdge - $detailsW) 86 $detailsW 20
        Set-ControlBounds $benchmarkButton ($rightEdge - $detailsW - $benchmarkW - 6) 86 $benchmarkW 20
        Set-ControlBounds $syncButton ($rightEdge - $detailsW - $benchmarkW - $syncW - 12) 86 $syncW 20
        Set-ControlBounds $verdictText $valueX 86 ([Math]::Max(80, $fullValueW - $detailsW - $benchmarkW - $syncW - 20)) 20
        Set-ControlBounds $tokensWindowLabel $innerX 110 $labelW 20
        Set-ControlBounds $tokensRate $valueX 110 $fullValueW 20
        $tokenSecondRate.Visible = $false
        Set-ControlBounds $speedBarLegend $innerX 134 $labelW 18
        Set-ControlBounds $speedBarValue $valueX 134 $fullValueW 18
        Set-ControlBounds $speedBar $valueX 158 $meterW $barH
        Set-ControlBounds $eventSpeedLabel $innerX 170 $labelW 20
        Set-ControlBounds $eventsRate $valueX 170 $fullValueW 20
        $speedScale.Visible = $false
        Set-ControlBounds $tokenUseBarLegend $innerX 194 $labelW 18
        Set-ControlBounds $tokenUseBarValue $valueX 194 $fullValueW 18
        Set-ControlBounds $tokenUseBar $valueX 218 $meterW $barH
        Set-ControlBounds $processLabel $innerX 232 $labelW 20
        Set-ControlBounds $processText $valueX 232 $fullValueW 20
        Set-ControlBounds $lastToolLabel $innerX 254 $labelW 20
        Set-ControlBounds $lastTool $valueX 254 $fullValueW 20

        $showTokenBase = ($h -ge 360)
        $showLimits = ($h -ge 535)
        Set-ControlsVisible $tokenBaseControls $showTokenBase
        Set-ControlsVisible $limitControls $showLimits
        if ($showTokenBase) {
            $tokenTop = 300
            $tokenBottom = if ($showLimits) { 518 } else { 398 }
            $script:CardRects += (New-Object System.Drawing.Rectangle($cardX, $tokenTop, $cardW, ($tokenBottom - $tokenTop)))
            Set-ControlBounds $tokensSectionLabel $innerX ($tokenTop + 10) 140 16
            Set-ControlBounds $tokensLabel $innerX ($tokenTop + 34) $labelW 20
            $resetW = 44
            Set-ControlBounds $sessionUseResetButton ($rightEdge - $resetW) ($tokenTop + 34) $resetW 20
            Set-ControlBounds $tokenTotal $valueX ($tokenTop + 34) ([Math]::Max(80, $fullValueW - $resetW - 6)) 20
            $tokenOutput.Visible = $false
            Set-ControlBounds $tokenLastLabel $innerX ($tokenTop + 58) $labelW 20
            Set-ControlBounds $lastTurn $valueX ($tokenTop + 58) $fullValueW 20
            Set-ControlBounds $sessionTokenLabel $innerX ($tokenTop + 82) $labelW 20
            Set-ControlBounds $sessionTokens $valueX ($tokenTop + 82) $fullValueW 20
            Set-ControlBounds $priceStepLabel $innerX ($tokenTop + 106) $labelW 20
            Set-ControlBounds $priceStepText $valueX ($tokenTop + 106) $fullValueW 20
            Set-ControlBounds $priceStepBar $valueX ($tokenTop + 126) $meterW $barH

            if ($showLimits) {
                Set-ControlBounds $contextLabel $innerX ($tokenTop + 140) $labelW 20
                Set-ControlBounds $contextText $valueX ($tokenTop + 140) $leftValueW 20
                Set-ControlBounds $contextBar $valueX ($tokenTop + 160) $meterW $barH
                Set-ControlBounds $primaryLabel $innerX ($tokenTop + 174) $labelW 20
                Set-ControlBounds $primaryText $valueX ($tokenTop + 174) $leftValueW 20
                Set-ControlBounds $primaryReset $rightX ($tokenTop + 174) $rightW 20
                Set-ControlBounds $primaryBar $valueX ($tokenTop + 194) $meterW $barH
                Set-ControlBounds $secondaryLabel $innerX ($tokenTop + 208) $labelW 20
                Set-ControlBounds $secondaryText $valueX ($tokenTop + 208) $leftValueW 20
                Set-ControlBounds $secondaryReset $rightX ($tokenTop + 208) $rightW 20
                Set-ControlBounds $secondaryBar $valueX ($tokenTop + 228) $meterW $barH
            } else {
                $hidden = $true
            }
        } else {
            $hidden = $true
            $tokenBottom = 210
        }

        $historyY = $tokenBottom + 10
        $historyH = [Math]::Min(160, $bottomY - $historyY - 74)
        $showHistory = ($historyH -ge 120)
        $showAllBoard = (-not $script:Sample.PinnedSessionPath)
        Set-ControlsVisible $historyControls $false
        if ($showHistory) {
            $script:CardRects += (New-Object System.Drawing.Rectangle($cardX, $historyY, $cardW, $historyH))
            if ($showAllBoard) {
                Set-ControlBounds $allSessionsSectionLabel $innerX ($historyY + 8) 140 16
                $allSessionsSectionLabel.Visible = $true
                $rowTop = $historyY + 30
                $rowGap = 22
                for ($i = 0; $i -lt $allSessionRows.Count; $i++) {
                    $row = $allSessionRows[$i]
                    $rowY = $rowTop + ($i * $rowGap)
                    $visible = ($rowY + 18 -le ($historyY + $historyH - 8))
                    Set-ControlBounds $row.Name $innerX $rowY ([Math]::Max(90, [int]($innerW * 0.34))) 18
                    Set-ControlBounds $row.Detail ($innerX + [Math]::Max(94, [int]($innerW * 0.34)) + 8) $rowY ([Math]::Max(100, $rightEdge - ($innerX + [Math]::Max(94, [int]($innerW * 0.34)) + 8))) 18
                    $row.Name.Visible = $visible
                    $row.Detail.Visible = $visible
                }
            } else {
                Set-ControlBounds $historySectionLabel $innerX ($historyY + 8) 140 16
                $historySectionLabel.Visible = $true
                $graphTop = $historyY + 26
                $graphGap = 6
                $graphH = [Math]::Max(22, [Math]::Min(32, [int](($historyH - 34 - ($graphGap * 3)) / 4)))
                Set-ControlBounds $tokenGraph $innerX $graphTop $graphW $graphH
                Set-ControlBounds $processGraph $innerX ($graphTop + $graphH + $graphGap) $graphW $graphH
                Set-ControlBounds $useGraph $innerX ($graphTop + (($graphH + $graphGap) * 2)) $graphW $graphH
                Set-ControlBounds $limitGraph $innerX ($graphTop + (($graphH + $graphGap) * 3)) $graphW $graphH
                Set-ControlsVisible @($tokenGraph, $processGraph, $useGraph, $limitGraph) $true
            }
        } else {
            $hidden = $true
        }

        $sessionY = if ($showHistory) { $historyY + $historyH + 10 } else { $historyY }
        $sessionH = 62
        $showSession = ($sessionY + $sessionH -le ($h - 34))
        Set-ControlsVisible $sessionControls $showSession
        if ($showSession) {
            $script:CardRects += (New-Object System.Drawing.Rectangle($cardX, $sessionY, $cardW, $sessionH))
            Set-ControlBounds $sessionLabel $innerX ($sessionY + 14) $labelW 20
            Set-ControlBounds $sessionText $valueX ($sessionY + 14) $fullValueW 20
            Set-ControlBounds $sessionMeta $valueX ($sessionY + 32) $fullValueW 14
        } else {
            $hidden = $true
        }

        $footer.Visible = $true
        $opacityLabel.Visible = $false
        $opacitySlider.Visible = $false
        $planText.Visible = ($w -ge 680)
        Set-ControlBounds $footer 18 ($h - 26) ([Math]::Min(200, [Math]::Max(120, $w - 240))) 18
        Set-ControlBounds $planText ([Math]::Max(420, $w - 212)) ($h - 26) 185 18
    }

    $resizeGrip.Text = if ($hidden) { "..." } else { "..." }
    $resizeGrip.ForeColor = if ($hidden) { $colorAmber } else { $colorMuted }
    $resizeGrip.Visible = $true
    $settingsGear.Visible = $true
    Set-ControlBounds $settingsGear ($w - 64) ($h - 26) 24 20
    Set-ControlBounds $resizeGrip ($w - 32) ($h - 24) 22 18
    $uiTip.SetToolTip($resizeGrip, $(if ($hidden) { "Drag to resize. Some lower sections are hidden at this size." } else { "Drag to resize." }))
    $form.Invalidate()
    } catch {
        Write-BuddyCrashLog $_
    } finally {
        $form.ResumeLayout()
        $script:Sample.LayoutBusy = $false
    }
}

function Set-DisplayMode {
    param([bool]$Mini)

    $script:Sample.MiniMode = $Mini
    $form.SuspendLayout()

    $hideInMini = @(
        $speedSectionLabel, $verdictLabel, $verdictText, $benchmarkButton, $detailsButton, $syncButton, $tokensWindowLabel, $tokensRate, $tokenSecondRate, $speedBarLegend, $speedBarValue, $speedBar,
        $tokenUseBarLegend, $tokenUseBarValue, $tokenUseBar, $eventSpeedLabel, $eventsRate, $speedScale, $processLabel, $processText,
        $tokensSectionLabel, $tokensLabel, $sessionUseResetButton, $tokenOutput, $tokenLastLabel, $lastTurn, $sessionTokenLabel, $sessionTokens,
        $priceStepLabel, $priceStepText, $priceStepBar, $contextLabel, $contextText, $contextBar,
        $primaryLabel, $primaryText, $primaryReset, $primaryBar, $secondaryLabel, $secondaryText, $secondaryReset, $secondaryBar,
        $historySectionLabel, $tokenGraph, $processGraph, $useGraph, $limitGraph, $allSessionsSectionLabel,
        $sessionLabel, $sessionText, $sessionMeta, $streamsLabel, $sessionTabStrip, $miniSummary, $lastToolLabel, $lastTool
    )
    foreach ($row in $allSessionRows) {
        $hideInMini += @($row.Name, $row.Detail)
    }

    foreach ($control in $hideInMini) {
        if ($control) {
            $control.Visible = -not $Mini
        }
    }

    foreach ($control in $form.Controls) {
        if ($Mini -and $control.Location.Y -ge 210) {
            if ($control -eq $opacityLabel -or $control -eq $opacitySlider -or $control -eq $settingsGear) {
                continue
            }

            if ($hideInMini -contains $control) {
                continue
            }

            $control.Visible = $false
        } elseif (-not $Mini) {
            $control.Visible = $true
        }
    }

    if ($Mini) {
        $form.Size = New-Object System.Drawing.Size(332, 414)
        foreach ($row in $miniRows) {
            $row.Label.Visible = $true
            $row.Value.Visible = $true
            $row.Graph.Visible = $true
        }
        $footer.Visible = $false
        $planText.Visible = $false
        $opacityLabel.Visible = $false
        $opacitySlider.Visible = $false
        $subtitle.Visible = $false
        $status.Location = New-Object System.Drawing.Point(244, 16)

        $verdictLabel.Location = New-Object System.Drawing.Point(22, 72)
        $verdictText.Location = New-Object System.Drawing.Point(132, 72)
        $benchmarkButton.Visible = $false
        $detailsButton.Visible = $false
        $tokensRate.Location = New-Object System.Drawing.Point(132, 72)
        $tokenSecondRate.Location = New-Object System.Drawing.Point(262, 72)
        $tokensWindowLabel.Location = New-Object System.Drawing.Point(22, 72)
        $speedBarLegend.Location = New-Object System.Drawing.Point(222, 95)
        $speedBar.Location = New-Object System.Drawing.Point(262, 95)
        $eventSpeedLabel.Location = New-Object System.Drawing.Point(22, 112)
        $eventsRate.Location = New-Object System.Drawing.Point(132, 112)
        $speedScale.Location = New-Object System.Drawing.Point(262, 112)
        $tokenUseBarLegend.Location = New-Object System.Drawing.Point(222, 123)
        $tokenUseBar.Location = New-Object System.Drawing.Point(262, 123)
        $processLabel.Location = New-Object System.Drawing.Point(22, 154)
        $processText.Location = New-Object System.Drawing.Point(132, 154)
        $miniSummary.Location = New-Object System.Drawing.Point(22, 178)
        $miniSummary.Size = New-Object System.Drawing.Size(425, 20)
        $opacityLabel.Location = New-Object System.Drawing.Point(24, 382)
        $opacitySlider.Location = New-Object System.Drawing.Point(108, 376)

        $modeToggle.Text = "Mini"
        $modeToggle.Checked = $true
        $modeToggle.BackColor = $colorButtonActive
        $modeToggle.FlatAppearance.BorderColor = $colorAccent
        $modeToggle.ForeColor = $colorText
    } else {
        $form.Size = New-Object System.Drawing.Size(332, 812)
        foreach ($row in $miniRows) {
            $row.Label.Visible = $false
            $row.Value.Visible = $false
            $row.Graph.Visible = $false
        }
        $miniSummary.Visible = $false
        $tokenUseBar.Visible = $true
        $footer.Visible = $true
        $planText.Visible = $true
        $opacityLabel.Visible = $false
        $opacitySlider.Visible = $false
        $subtitle.Visible = $false
        $status.Location = New-Object System.Drawing.Point(244, 16)

        $verdictLabel.Location = New-Object System.Drawing.Point(22, 78)
        $verdictText.Location = New-Object System.Drawing.Point(132, 78)
        $benchmarkButton.Visible = $true
        $detailsButton.Visible = $true
        $tokensRate.Location = New-Object System.Drawing.Point(132, 78)
        $tokenSecondRate.Location = New-Object System.Drawing.Point(262, 78)
        $tokensWindowLabel.Location = New-Object System.Drawing.Point(22, 78)
        $speedBarLegend.Location = New-Object System.Drawing.Point(222, 95)
        $speedBar.Location = New-Object System.Drawing.Point(262, 95)
        $eventSpeedLabel.Location = New-Object System.Drawing.Point(22, 106)
        $eventsRate.Location = New-Object System.Drawing.Point(132, 106)
        $speedScale.Location = New-Object System.Drawing.Point(262, 106)
        $tokenUseBarLegend.Location = New-Object System.Drawing.Point(222, 123)
        $tokenUseBar.Location = New-Object System.Drawing.Point(262, 123)
        $processLabel.Location = New-Object System.Drawing.Point(22, 134)
        $processText.Location = New-Object System.Drawing.Point(132, 134)
        $miniSummary.Location = New-Object System.Drawing.Point(22, 188)
        $miniSummary.Size = New-Object System.Drawing.Size(425, 18)

        $footer.Text = "drag to move"
        $modeToggle.Text = "Full"
        $modeToggle.Checked = $false
        $modeToggle.BackColor = $colorButton
        $modeToggle.FlatAppearance.BorderColor = $colorButtonBorder
        $modeToggle.ForeColor = $colorText
    }

    $form.ResumeLayout()
    Update-ResponsiveLayout
}

function Update-MiniRow {
    param(
        [int]$Index,
        [string]$Value,
        [array]$Series,
        [string]$Tip,
        [nullable[double]]$FixedMax = $null
    )

    if ($Index -ge $miniRows.Count) {
        return
    }

    $row = $miniRows[$Index]
    $row.Value.Text = $Value
    Draw-Sparkline -Box $row.Graph -Series $Series -LineColor ([System.Drawing.Color]$row.Color) -FixedMax $FixedMax
    Set-BuddyToolTip -Tip $uiTip -Control $row.Label -Text $Tip
    Set-BuddyToolTip -Tip $uiTip -Control $row.Value -Text $Tip
    Set-BuddyToolTip -Tip $uiTip -Control $row.Graph -Text $Tip
}

function Set-DetailsOpen {
    param([bool]$Open)

    $script:Sample.DetailsOpen = $Open
    Sync-SettingsWindows
    $detailsForm.Visible = $Open
    $detailsButton.BackColor = if ($Open) { $colorButtonActive } else { $colorButton }
    $detailsButton.FlatAppearance.BorderColor = if ($Open) { $colorAccent } else { $colorButtonBorder }
    if ($Open) {
        $detailsForm.Show()
        $detailsForm.Activate()
    } else {
        $detailsForm.Hide()
    }
}

function Apply-Theme {
    $form.BackColor = $colorBg
    $form.ForeColor = $colorText
    $title.ForeColor = $colorText
    $subtitle.ForeColor = $colorMuted
    $speedSectionLabel.ForeColor = $colorAccent
    $speedBarLegend.ForeColor = $colorAccent
    $tokenUseBarLegend.ForeColor = $colorBlue
    $tokensSectionLabel.ForeColor = $colorBlue
    $priceStepLabel.ForeColor = $colorAmber
    $historySectionLabel.ForeColor = $colorCoral
    $allSessionsSectionLabel.ForeColor = $colorCoral
    $streamsLabel.ForeColor = $colorBlue

    foreach ($label in @(
        $verdictLabel, $tokensWindowLabel, $eventSpeedLabel, $processLabel, $lastToolLabel, $opacityLabel,
        $tokensLabel, $tokenLastLabel, $sessionTokenLabel, $contextLabel, $primaryLabel, $secondaryLabel, $sessionLabel,
        $sessionMeta, $footer, $planText, $miniSummary
    )) {
        if ($label) {
            $label.ForeColor = $colorMuted
        }
    }

    foreach ($label in @(
        $verdictText, $tokensRate, $tokenSecondRate, $speedBarValue, $tokenUseBarValue, $eventsRate, $speedScale, $processText, $lastTool,
        $tokenTotal, $tokenOutput, $lastTurn, $sessionTokens, $priceStepText, $contextText, $primaryText, $primaryReset,
        $secondaryText, $secondaryReset, $sessionText
    )) {
        if ($label) {
            $label.ForeColor = $colorText
        }
    }

    $speedBar.Tag = $colorAccent
    $tokenUseBar.Tag = $colorBlue
    $priceStepBar.Tag = $colorAmber
    $contextBar.Tag = $colorBlue
    $primaryBar.Tag = $colorAccent
    $secondaryBar.Tag = $colorBlue

    foreach ($box in @($speedBar, $tokenUseBar, $priceStepBar, $contextBar, $primaryBar, $secondaryBar, $tokenGraph, $processGraph, $useGraph, $limitGraph)) {
        if ($box) {
            $box.BackColor = $colorGraph
        }
    }

    $miniRows[0].Color = $colorAccent
    $miniRows[1].Color = $colorAccent
    $miniRows[2].Color = $colorBlue
    $miniRows[3].Color = $colorCoral
    $miniRows[4].Color = $colorBlue
    $miniRows[5].Color = $colorAccent
    $miniRows[6].Color = $colorBlue
    $miniRows[7].Color = $colorAmber
    foreach ($row in $miniRows) {
        $row.Label.ForeColor = $colorMuted
        $row.Value.ForeColor = $colorText
        $row.Graph.BackColor = $colorGraph
    }
    foreach ($row in $allSessionRows) {
        $row.Name.ForeColor = $colorText
        $row.Detail.ForeColor = $colorMuted
    }

    $close.BackColor = $colorButton
    $close.ForeColor = $colorText
    $benchmarkButton.BackColor = if ($script:Sample.BenchmarkStatus -eq "armed" -or $script:Sample.BenchmarkStatus -eq "running") { $colorButtonActive } else { $colorButton }
    $benchmarkButton.ForeColor = $colorText
    $benchmarkButton.FlatAppearance.BorderColor = if ($script:Sample.BenchmarkStatus -eq "armed" -or $script:Sample.BenchmarkStatus -eq "running") { $colorAccent } else { $colorButtonBorder }
    $detailsButton.BackColor = if ($script:Sample.DetailsOpen) { $colorButtonActive } else { $colorButton }
    $detailsButton.ForeColor = $colorText
    $detailsButton.FlatAppearance.BorderColor = if ($script:Sample.DetailsOpen) { $colorAccent } else { $colorButtonBorder }
    $syncButton.BackColor = $colorButton
    $syncButton.ForeColor = $colorText
    $syncButton.FlatAppearance.BorderColor = $colorButtonBorder
    $sessionUseResetButton.BackColor = $colorButton
    $sessionUseResetButton.ForeColor = $colorText
    $sessionUseResetButton.FlatAppearance.BorderColor = $colorButtonBorder
    $settingsGear.BackColor = $colorButton
    $settingsGear.ForeColor = $colorText
    $settingsGear.FlatAppearance.BorderColor = $colorButtonBorder
    $gearForm.BackColor = $colorBg
    $gearButton.BackColor = if ($script:Sample.ClickThrough) { $colorButtonActive } else { $colorButton }
    $gearButton.ForeColor = $colorText
    $gearButton.FlatAppearance.BorderColor = $colorButtonBorder
    $settingsForm.BackColor = $colorCard
    $settingsForm.ForeColor = $colorText
    $settingsTitle.ForeColor = $colorText
    $settingsOpacityLabel.ForeColor = $colorMuted
    $settingsOpacitySlider.BackColor = $colorCard
    $detailsForm.BackColor = $colorCard
    $detailsForm.ForeColor = $colorText
    $detailsText.BackColor = $colorCard
    $detailsText.ForeColor = $colorText
    $benchmarkExportButton.BackColor = $colorButton
    $benchmarkExportButton.ForeColor = $colorText
    $benchmarkExportButton.FlatAppearance.BorderColor = $colorButtonBorder
    foreach ($toggle in @($topMostToggle, $clickThroughToggle)) {
        $toggle.BackColor = $colorCard
        $toggle.ForeColor = $colorText
    }
    $themeToggle.Text = if ($script:Sample.DarkMode) { "Dark" } else { "Lite" }
    $themeToggle.BackColor = $colorButtonActive
    $themeToggle.ForeColor = $colorText
    $themeToggle.FlatAppearance.BorderColor = $colorAccent
    $modeToggle.BackColor = if ($script:Sample.MiniMode) { $colorButtonActive } else { $colorButton }
    $modeToggle.ForeColor = $colorText
    $modeToggle.FlatAppearance.BorderColor = if ($script:Sample.MiniMode) { $colorAccent } else { $colorButtonBorder }
    $opacitySlider.BackColor = $colorBg

    $script:Sample.LastTabRefresh = [datetime]::MinValue
    Update-ResponsiveLayout
    $form.Invalidate()
}

$modeToggle.Add_Click({
    try {
        Set-DisplayMode -Mini (-not $script:Sample.MiniMode)
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$themeToggle.Add_Click({
    try {
        $script:Sample.DarkMode = -not $script:Sample.DarkMode
        Set-ThemePalette -Dark $script:Sample.DarkMode
        Apply-Theme
        Update-Display
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$opacitySlider.Add_ValueChanged({
    try {
        Set-BuddyOpacity -Percent $opacitySlider.Value
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$settingsOpacitySlider.Add_ValueChanged({
    try {
        Set-BuddyOpacity -Percent $settingsOpacitySlider.Value
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$topMostToggle.Add_CheckedChanged({
    try {
        Set-BuddyTopMost -Enabled $topMostToggle.Checked
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$clickThroughToggle.Add_CheckedChanged({
    try {
        Set-BuddyClickThrough -Enabled $clickThroughToggle.Checked
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$gearButton.Add_Click({
    try {
        Set-SettingsOpen -Open (-not $settingsForm.Visible)
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$settingsGear.Add_Click({
    try {
        Set-SettingsOpen -Open (-not $settingsForm.Visible)
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$detailsButton.Add_Click({
    try {
        Set-DetailsOpen -Open (-not $script:Sample.DetailsOpen)
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$syncButton.Add_Click({
    try {
        Reset-BuddyView
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$benchmarkButton.Add_Click({
    try {
        if ($script:Sample.BenchmarkArmed) {
            Cancel-BenchmarkCapture
        } else {
            Start-BenchmarkCapture
        }
        Update-Display
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$benchmarkExportButton.Add_Click({
    try {
        [void](Export-BenchmarkReport)
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$sessionUseResetButton.Add_Click({
    try {
        Reset-SessionUseCounter
        Update-Display
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$status.Add_Click({
    try {
        $summary = Accept-LongContextAlerts
        if ([int]$summary.PendingCount -gt 0) {
            $uiTip.SetToolTip($status, ("{0} long-context alert(s) still need acknowledgement." -f $summary.PendingCount))
        }
        Update-Display
    } catch {
        Write-BuddyCrashLog $_
        Show-DisplayError -ErrorRecord $_
    }
})

$detailsForm.Add_FormClosing({
    if ($_.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
        $_.Cancel = $true
        Set-DetailsOpen -Open $false
    }
})

$resizeGrip.Add_MouseDown({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:resizing = $true
        $script:resizeStartCursor = [System.Windows.Forms.Cursor]::Position
        $script:resizeStartSize = $form.Size
    }
})

$resizeGrip.Add_MouseMove({
    try {
        if ($script:resizing) {
            $cursor = [System.Windows.Forms.Cursor]::Position
            $newWidth = [Math]::Max($form.MinimumSize.Width, $script:resizeStartSize.Width + ($cursor.X - $script:resizeStartCursor.X))
            $newHeight = [Math]::Max($form.MinimumSize.Height, $script:resizeStartSize.Height + ($cursor.Y - $script:resizeStartCursor.Y))
            $form.Size = New-Object System.Drawing.Size($newWidth, $newHeight)
        }
    } catch {
        Write-BuddyCrashLog $_
    }
})

$resizeGrip.Add_MouseUp({
    $script:resizing = $false
})

$form.Add_Resize({
    Update-ResponsiveLayout
    Sync-SettingsWindows
})

$form.Add_Move({
    Sync-SettingsWindows
})

$form.Add_FormClosed({
    try {
        if ($script:PriceNotifyIcon) {
            $script:PriceNotifyIcon.Visible = $false
            $script:PriceNotifyIcon.Dispose()
        }
        $settingsForm.Close()
        $gearForm.Close()
    } catch {}
})

$uiTip.SetToolTip($modeToggle, "Toggle between full dashboard and compact mini view.")
$uiTip.SetToolTip($themeToggle, "Toggle between dark and light themes.")
$uiTip.SetToolTip($settingsGear, "Open Codex Buddy settings.")
$uiTip.SetToolTip($gearButton, "Open Codex Buddy settings.")
$uiTip.SetToolTip($syncButton, "Refresh Buddy's live session view and clear recoverable display errors without restarting.")
$uiTip.SetToolTip($settingsOpacityLabel, "Window transparency setting.")
$uiTip.SetToolTip($settingsOpacitySlider, "Adjust Codex Buddy window opacity from 35% to 100%.")
$uiTip.SetToolTip($topMostToggle, "Keep Codex Buddy above other desktop windows.")
$uiTip.SetToolTip($clickThroughToggle, "Let mouse clicks pass through the Buddy telemetry window.")
$uiTip.SetToolTip($tokensRate, "Exact tokens used over the last 60 seconds from logged token events.")
$uiTip.SetToolTip($tokenSecondRate, "Output tokens in the last 60 seconds.")
$uiTip.SetToolTip($speedBar, "Reply speed in tokens per second.")
$uiTip.SetToolTip($speedBarLegend, "Output-speed bar legend.")
$uiTip.SetToolTip($speedBarValue, "Reply speed in tokens per second.")
$uiTip.SetToolTip($tokenUseBar, "Tracked session-use bar, built by adding each completed prompt token_count event once.")
$uiTip.SetToolTip($tokenUseBarLegend, "Tracked session-use bar legend.")
$uiTip.SetToolTip($tokenUseBarValue, "Estimated cost for this chat.")
$uiTip.SetToolTip($eventsRate, "How often Codex is using tools.")
$uiTip.SetToolTip($speedScale, "Supporting event throughput detail for the Tools row.")
$uiTip.SetToolTip($processText, "Detected Codex-related process count, CPU usage, and memory.")
$uiTip.SetToolTip($lastTool, "Most recent tool call name observed in this conversation.")
$uiTip.SetToolTip($tokenTotal, "Tracked session use from completed prompt token_count events.")
$uiTip.SetToolTip($tokenOutput, "Output tokens in the last 60 seconds.")
$uiTip.SetToolTip($tokenLastLabel, "Last completed prompt/interaction token use from the latest logged token event; holds until the next prompt updates it.")
$uiTip.SetToolTip($lastTurn, "Last completed prompt/interaction token use from the latest logged token event; holds until the next prompt updates it.")
$uiTip.SetToolTip($sessionTokenLabel, "Cost pressure compares the last prompt against lower-context prompt averages, so compact timing is easier to see.")
$uiTip.SetToolTip($sessionTokens, "Cost pressure compares the last prompt against lower-context prompt averages, so compact timing is easier to see.")
$uiTip.SetToolTip($priceStepLabel, "API long-context guard from last_token_usage.input_tokens for supported GPT-5.4, GPT-5.5, and GPT-5.6 models: green under 200K, yellow 200K-230K, red 230K-240K, final warning at 240K. Official price cliff is over 272K input tokens.")
$uiTip.SetToolTip($priceStepText, "API long-context guard from last_token_usage.input_tokens for supported GPT-5.4, GPT-5.5, and GPT-5.6 models: green under 200K, yellow 200K-230K, red 230K-240K, final warning at 240K. Official price cliff is over 272K input tokens.")
$uiTip.SetToolTip($priceStepBar, "Current input tokens as a percent of the 272K context cliff.")
$uiTip.SetToolTip($contextText, "Last-turn context utilization percent.")
$uiTip.SetToolTip($contextBar, "Last-turn context usage vs model context window.")
$uiTip.SetToolTip($primaryText, "Active profile 5-hour remaining percent.")
$uiTip.SetToolTip($primaryReset, "Next reset time for active 5-hour window.")
$uiTip.SetToolTip($primaryBar, "Active profile 5-hour remaining usage.")
$uiTip.SetToolTip($secondaryText, "Active profile weekly remaining percent.")
$uiTip.SetToolTip($secondaryReset, "Next reset time for active weekly window.")
$uiTip.SetToolTip($secondaryBar, "Active profile weekly remaining usage.")
$uiTip.SetToolTip($tokenGraph, "Smoothed trend of exact tokens used in recent 60-second windows.")
$uiTip.SetToolTip($processGraph, "Smoothed trend of Codex process CPU usage.")
$uiTip.SetToolTip($useGraph, "Smoothed tool-call throughput trend.")
$uiTip.SetToolTip($limitGraph, "Trend lines for active 5-hour and weekly remaining limits.")
$uiTip.SetToolTip($sessionText, "Workspace, log age, and log size for the current session.")
$uiTip.SetToolTip($sessionMeta, "Current workspace and how long since the pinned conversation switched.")
$uiTip.SetToolTip($sessionTabStrip, "Choose a session tab. Each tab shows the project name and how long since it last moved.")
$uiTip.SetToolTip($planText, "Plan type, active model profile, and local limit ID.")

function Format-SessionTabText {
    param([string]$Label)

    if ([string]::IsNullOrWhiteSpace($Label)) {
        return "Session"
    }

    $clean = [regex]::Replace($Label, "[^\x20-\x7E]+", " ")
    $clean = [regex]::Replace($clean, "\s+", " ").Trim()
    $clean = $clean -replace "\s+ago$", ""
    return $clean
}

function New-SessionStripButton {
    param(
        [string]$Label,
        [string]$Tag,
        [bool]$Selected,
        [string]$Tip
    )

    $tabButton = New-Object System.Windows.Forms.Button
    $tabButton.Text = Format-SessionTabText $Label
    $tabButton.Tag = $Tag
    $tabButton.Size = New-Object System.Drawing.Size(80, 22)
    $tabButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
    $tabButton.FlatStyle = "Flat"
    $tabButton.FlatAppearance.BorderSize = 1
    $tabButton.FlatAppearance.MouseOverBackColor = $colorButtonHover
    $tabButton.FlatAppearance.MouseDownBackColor = $colorButtonDown
    $tabButton.BackColor = if ($Selected) { $colorButtonActive } else { $colorButton }
    $tabButton.FlatAppearance.BorderColor = if ($Selected) { $colorAccent } else { $colorButtonBorder }
    $tabButton.ForeColor = if ($Selected) { $colorText } else { $colorStatusIdleText }
    $tabButton.Font = $smallFont
    $tabButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $tabButton.AutoEllipsis = $true
    $tabButton.UseMnemonic = $false
    $tabButton.TabStop = $false
    $tabButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $uiTip.SetToolTip($tabButton, $Tip)
    Enable-DragAnywhere -Control $tabButton
    $tabButton.Add_Click({
        if ([string]$this.Tag -eq "__ALL__") {
            $script:Sample.PinnedSessionPath = $null
            $script:Sample.TabPinnedByUser = $false
        } else {
            $script:Sample.PinnedSessionPath = [string]$this.Tag
            $script:Sample.TabPinnedByUser = $true
        }

        $script:Sample.LastTabRefresh = [datetime]::MinValue
    })

    return $tabButton
}

function Update-SessionTabLayout {
    $count = $sessionTabStrip.Controls.Count
    if ($count -le 0) {
        return
    }

    $gap = 3
    $height = 20
    $availableWidth = [Math]::Max(80, $sessionTabStrip.ClientSize.Width)
    $gapTotal = [Math]::Max(0, ($count - 1) * $gap)
    $allWidth = if ($count -eq 1) { [Math]::Min(56, $availableWidth) } else { 42 }
    $sessionCount = [Math]::Max(0, $count - 1)
    $sessionWidth = if ($sessionCount -gt 0) {
        [Math]::Max(30, [int][Math]::Floor(($availableWidth - $allWidth - $gapTotal) / $sessionCount))
    } else {
        0
    }

    for ($i = 0; $i -lt $count; $i++) {
        $tabButton = $sessionTabStrip.Controls[$i]
        $tabWidth = if ($tabButton.Tag -eq "__ALL__") { $allWidth } else { $sessionWidth }

        $tabButton.Size = New-Object System.Drawing.Size($tabWidth, $height)
        $rightMargin = if ($i -eq ($count - 1)) { 0 } else { $gap }
        $tabButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, $rightMargin, 0)
    }
}

function Clear-SessionTabStrip {
    $oldControls = @($sessionTabStrip.Controls | ForEach-Object { $_ })
    foreach ($control in $oldControls) {
        try {
            $sessionTabStrip.Controls.Remove($control)
            $control.Dispose()
        } catch {}
    }
}

function Reset-BuddyView {
    $script:Sample.Updating = $false
    $script:Sample.CurrentSnapshot = $null
    $script:Sample.LastTabRefresh = [datetime]::MinValue
    $script:Sample.SessionTabSignature = $null
    Clear-SessionTabStrip
    [System.GC]::Collect()
    Update-Display
}

function Update-Display {
    if ($script:Sample.Updating) {
        return
    }

    $script:Sample.Updating = $true
    try {
    $now = Get-Date
    if (($sessionTabStrip.Controls.Count -eq 0) -or (($now - $script:Sample.LastTabRefresh).TotalSeconds -ge 4)) {
        $tabCandidates = [Math]::Max($MaxSessionTabs * 8, 32)
        $paths = @(Get-RecentSessionPaths -Root $CodexHome -Max $tabCandidates -State $script:Sample)
        $paths = @($paths | Select-Object -Unique)
        $paths = @(Get-CollapsedSessionPaths -Paths $paths -State $script:Sample | Select-Object -First $MaxSessionTabs)
        if ($script:Sample.PinnedSessionPath -and -not (Test-Path -LiteralPath $script:Sample.PinnedSessionPath)) {
            $script:Sample.PinnedSessionPath = $null
            $script:Sample.TabPinnedByUser = $false
        } elseif ($script:Sample.PinnedSessionPath) {
            $pinnedKey = Get-SessionConversationKey -Path $script:Sample.PinnedSessionPath -State $script:Sample
            $representative = @($paths | Where-Object { (Get-SessionConversationKey -Path $_ -State $script:Sample) -eq $pinnedKey } | Select-Object -First 1)
            if ($representative.Count -gt 0) {
                $script:Sample.PinnedSessionPath = $representative[0]
            } else {
                $paths = @($script:Sample.PinnedSessionPath) + $paths | Select-Object -Unique
                $paths = @(Get-CollapsedSessionPaths -Paths $paths -State $script:Sample | Select-Object -First $MaxSessionTabs)
            }
        }

        $selectedPath = if ($script:Sample.PinnedSessionPath) { $script:Sample.PinnedSessionPath } else { "__ALL__" }

        $tabSignature = (@($selectedPath) + @($paths)) -join "`n"
        if (($sessionTabStrip.Controls.Count -eq 0) -or ($tabSignature -ne $script:Sample.SessionTabSignature)) {
            $script:Sample.TabRebuilding = $true
            try {
                Clear-SessionTabStrip
                $allButton = New-SessionStripButton -Label "All" -Tag "__ALL__" -Selected ($selectedPath -eq "__ALL__") -Tip "Show aggregated live stats across active and warm sessions."
                $sessionTabStrip.Controls.Add($allButton)

                foreach ($path in $paths) {
                    $selected = ([string]$path -eq [string]$selectedPath)
                    $tabButton = New-SessionStripButton -Label (Get-SessionTabLabel -Path $path -State $script:Sample) -Tag $path -Selected $selected -Tip $path
                    $sessionTabStrip.Controls.Add($tabButton)
                }

                Update-SessionTabLayout
                $script:Sample.SessionTabSignature = $tabSignature
            } finally {
                $script:Sample.TabRebuilding = $false
            }
        }

        $script:Sample.LastTabRefresh = $now
    }

    $allMode = (-not $script:Sample.PinnedSessionPath)
    $snapshot = Get-CodexBuddySnapshot -Root $CodexHome -State $script:Sample -SessionPath $script:Sample.PinnedSessionPath -AllSessions:$allMode
    $script:Sample.CurrentSnapshot = $snapshot
    $status.Text = ([string]$snapshot.Status).ToUpperInvariant()

    if ($snapshot.Error) {
        $status.ForeColor = $colorAmber
        $status.BackColor = $colorStatusWarmBack
        $tokensRate.Text = "n/a"
        $eventsRate.Text = "n/a"
        $lastTool.Text = $snapshot.Error
        Set-BenchmarkButtonState -Enabled $false
        return
    }

    $session = $snapshot.Session
    $process = $snapshot.Process
    $weeklyOnly = ($null -eq $session.PrimaryWindowMinutes -and $null -ne $session.SecondaryWindowMinutes)
    $mainLimitWindowMinutes = if ($weeklyOnly) { $session.SecondaryWindowMinutes } else { $session.PrimaryWindowMinutes }
    $mainLimitUsedPercent = if ($weeklyOnly) { $session.SecondaryUsedPercent } else { $session.PrimaryUsedPercent }
    $mainLimitRemainingPercent = if ($weeklyOnly) { $session.SecondaryRemainingPercent } else { $session.PrimaryRemainingPercent }
    $mainLimitReset = if ($weeklyOnly) { $session.SecondaryReset } else { $session.PrimaryReset }
    $hasAdditionalLimit = (-not $weeklyOnly -and $null -ne $session.SecondaryWindowMinutes)
    $mainLimitWindowLabel = Get-RateLimitWindowLabel -WindowMinutes $mainLimitWindowMinutes -Fallback "Usage Limit"
    $mainLimitWindowShortLabel = Get-RateLimitWindowShortLabel -WindowMinutes $mainLimitWindowMinutes -Fallback "usage"
    Update-BenchmarkCapture -Session $session
    Set-BenchmarkButtonState -Enabled (-not $allMode)
    $benchmarkExportButton.Enabled = (@($script:Sample.BenchmarkRuns | Where-Object { $_.Status -eq "completed" }).Count -gt 0)
    $guardModel = Get-JsonValue -Object $session -Name "PriceGuardModel"
    if (-not $guardModel) {
        $guardModel = $session.ActiveModel
    }
    $priceGuard = Get-LongContextPriceGuard -Model ([string]$guardModel) -CurrentInputTokens $session.LastInputTokens
    $guardLabel = Get-LongContextPriceModelLabel -Model ([string]$guardModel)
    $alertSummary = Update-LongContextAlertLedger -Session $session -PriceGuard $priceGuard -ModelLabel $guardLabel
    Show-LongContextPriceNotice -Session $session -PriceGuard $priceGuard -ModelLabel $guardLabel
    $costFlashActive = ($priceGuard.State -eq "yellow" -or $priceGuard.State -eq "red" -or $priceGuard.State -eq "hard" -or $priceGuard.State -eq "over")
    $script:Sample.CostFlashOn = if ($costFlashActive) { -not $script:Sample.CostFlashOn } else { $false }

    switch ($snapshot.Status) {
        "active" {
            $status.ForeColor = $colorAccent
            $status.BackColor = $colorStatusActiveBack
            $uiTip.SetToolTip($status, "Active: session log has new events very recently.")
        }
        "warm" {
            $status.ForeColor = $colorAmber
            $status.BackColor = $colorStatusWarmBack
            $uiTip.SetToolTip($status, "Warm: session is quiet but still recently active.")
        }
        default {
            $status.ForeColor = $colorStatusIdleText
            $status.BackColor = $colorStatusIdleBack
            $uiTip.SetToolTip($status, "Idle: no recent session activity.")
        }
    }

    if ($priceGuard.State -eq "yellow" -or $priceGuard.State -eq "red" -or $priceGuard.State -eq "hard" -or $priceGuard.State -eq "over") {
        $status.Text = switch ($priceGuard.State) {
            "over" { "HIGH COST" }
            "hard" { "START NEW" }
            "red" { "TOO LONG" }
            default { "LONG CHAT" }
        }
        $status.ForeColor = if ($script:Sample.CostFlashOn) { $colorBg } elseif ($priceGuard.State -eq "yellow") { $colorAmber } else { $colorCoral }
        $status.BackColor = if ($script:Sample.CostFlashOn) { if ($priceGuard.State -eq "yellow") { $colorAmber } else { $colorCoral } } else { $colorStatusWarmBack }
        $uiTip.SetToolTip($status, ("{0}. Current input tokens: {1}. Start a fresh chat now if this says HIGH COST." -f $priceGuard.Text, (Format-Number $session.LastInputTokens)))
    }

    if ([int]$alertSummary.PendingCount -gt 0) {
        $status.Text = ("OVER {0}" -f [int]$alertSummary.PendingCount)
        $status.ForeColor = $colorText
        $status.BackColor = $colorCoral
        $status.Cursor = [System.Windows.Forms.Cursors]::Hand
        $uiTip.SetToolTip($status, ("{0} long-context alert(s) are waiting. Click this badge to Accept them." -f [int]$alertSummary.PendingCount))
    } else {
        $status.Cursor = [System.Windows.Forms.Cursors]::Default
    }

    if ($script:Sample.ActiveSessionId -ne $session.SessionId) {
        $script:Sample.ActiveSessionId = $session.SessionId
        $script:Sample.SessionSwitchedAt = Get-Date
    }

    $sessionUseView = Get-SessionUseSinceReset -Session $session
    $sessionUseCostUnits = if ($sessionUseView.Active) { $sessionUseView.CostUnits } else { $session.SessionPromptCostUnits }
    $sessionUseFastExtraCostUnits = if ($sessionUseView.Active) { $sessionUseView.FastExtraCostUnits } else { $session.SessionPromptFastExtraCostUnits }
    $sessionUsePrimaryDelta = if ($sessionUseView.Active) { $sessionUseView.PrimaryUseDelta } else { $session.SessionPromptPrimaryUseDelta }
    $sessionUsePromptCount = if ($sessionUseView.Active) { $sessionUseView.PromptCount } else { $session.SessionPromptCount }
    $sessionUseLabel = if ($sessionUseView.Active) { "Since Reset" } else { "This Chat" }
    $sessionUseTipPrefix = if ($sessionUseView.Active -and $sessionUseView.ResetAt) { ("Since reset at {0}. " -f ([datetime]$sessionUseView.ResetAt).ToString("g")) } elseif ($sessionUseView.Active) { "Since reset. " } else { "" }
    $shortWindowDeltaLabel = Get-RateLimitWindowShortLabel -WindowMinutes $session.PrimaryWindowMinutes -Fallback "short"
    $sessionPrimaryUseText = Format-UsePercentDelta $sessionUsePrimaryDelta
    $lastPromptPrimaryUseText = Format-UsePercentDelta $session.LastPromptPrimaryUseDelta
    $usageLimitText = if ($weeklyOnly -and $null -ne $mainLimitUsedPercent) { ("{0} {1:N1}% used" -f $mainLimitWindowShortLabel, ([double]$mainLimitUsedPercent)) } else { ("{0} {1}" -f $shortWindowDeltaLabel, $sessionPrimaryUseText) }
    $sessionUseCostForGraph = if ($null -ne $sessionUseCostUnits) { [double]$sessionUseCostUnits } else { 0.0 }

    $script:Sample.TokenGraphValue = $sessionUseCostForGraph
    $script:Sample.EventGraphValue = Smooth-GraphValue -Previous $script:Sample.EventGraphValue -Current ([double]$session.ToolCallsPerMinute) -AgeSeconds ([double]$session.LastWriteAgeSeconds) -RiseAlpha 0.52 -FallAlpha 0.24 -Decay 0.86 -HoldSeconds 3
    $script:Sample.ProcessGraphValue = Smooth-GraphValue -Previous $script:Sample.ProcessGraphValue -Current ([double]$process.CpuPercent) -AgeSeconds 0 -RiseAlpha 0.50 -FallAlpha 0.30 -Decay 0.80 -HoldSeconds 0

    Add-HistoryPoint -History $script:Sample.TokenHistory -Value $script:Sample.TokenGraphValue
    Add-HistoryPoint -History $script:Sample.EventHistory -Value $script:Sample.EventGraphValue
    Add-HistoryPoint -History $script:Sample.ProcessHistory -Value $script:Sample.ProcessGraphValue
    $additionalLimitRemainingPercent = if ($hasAdditionalLimit) { $session.SecondaryRemainingPercent } else { $null }
    Add-HistoryPoint -History $script:Sample.PrimaryRemainingHistory -Value $mainLimitRemainingPercent
    Add-HistoryPoint -History $script:Sample.SecondaryRemainingHistory -Value $additionalLimitRemainingPercent

    $primaryUsedText = Format-UsePercent $session.PrimaryUsedPercent
    $burnScaleText = if ($null -ne $session.BurnCostUnitsPerPercent -and [double]$session.BurnCostUnitsPerPercent -gt 0) { ("calibrated from local limit movement") } else { "estimate" }
    $sessionBurnText = Format-BurnScore -CostUnits $sessionUseCostUnits -CostUnitsPerOnePercent $session.BurnCostUnitsPerPercent
    $fullSessionBurnText = Format-BurnScore -CostUnits $session.SessionPromptCostUnits -CostUnitsPerOnePercent $session.BurnCostUnitsPerPercent
    $lastPromptBurnText = Format-BurnScore -CostUnits $session.LastPromptCostUnits -CostUnitsPerOnePercent $session.BurnCostUnitsPerPercent
    $recentPromptCosts = if ($session.RecentPromptCosts) { @($session.RecentPromptCosts) } else { @() }
    $recentPromptAverageUnits = if ($recentPromptCosts.Count -gt 0) { ($recentPromptCosts | Measure-Object -Property CostUnits -Average).Average } else { $null }
    $recentPromptAverageText = Format-BurnScore -CostUnits $recentPromptAverageUnits -CostUnitsPerOnePercent $session.BurnCostUnitsPerPercent
    $sessionFastExtraBurnText = Format-BurnScore -CostUnits $sessionUseFastExtraCostUnits -CostUnitsPerOnePercent $session.BurnCostUnitsPerPercent
    $lastPromptFastExtraBurnText = Format-BurnScore -CostUnits $session.LastPromptFastExtraCostUnits -CostUnitsPerOnePercent $session.BurnCostUnitsPerPercent
    $hasSessionFastExtra = ($null -ne $sessionUseFastExtraCostUnits -and [double]$sessionUseFastExtraCostUnits -gt 0)
    $hasLastFastExtra = ($null -ne $session.LastPromptFastExtraCostUnits -and [double]$session.LastPromptFastExtraCostUnits -gt 0)
    $sessionFastText = if ($hasSessionFastExtra) { ("Fast extra +{0}" -f $sessionFastExtraBurnText) } else { $null }
    $lastFastText = if ($hasLastFastExtra) { ("Fast extra +{0}" -f $lastPromptFastExtraBurnText) } else { $null }
    $tokensWindowLabel.Text = "Chat Cost"
    $tokensRate.Text = if ($sessionFastText) { ("{0} cost | {1} | {2}" -f $sessionBurnText, $sessionFastText, $usageLimitText) } else { ("{0} cost | {1}" -f $sessionBurnText, $usageLimitText) }
    $speedTokPerSecond = if ($session.OutputTokensPerSecond -and $session.OutputTokensPerSecond -gt 0) { [double]$session.OutputTokensPerSecond } else { [double]$session.TokensPerSecond }
    if ($speedTokPerSecond -gt [double]$script:Sample.SpeedMaxTokPerSecond) {
        $script:Sample.SpeedMaxTokPerSecond = [double]$speedTokPerSecond
    }
    $usageVerdict = Get-UsageVerdict -Session $session -PriceGuard $priceGuard -SpeedTokPerSecond $speedTokPerSecond -LastPromptBurnText $lastPromptBurnText -SessionBurnText $sessionBurnText -HasFastExtra $hasSessionFastExtra
    $verdictText.Text = ("{0} [{1}]" -f $usageVerdict.Text, $usageVerdict.Confidence)
    $verdictText.ForeColor = switch ($usageVerdict.Tone) {
        "bad" { $colorCoral }
        "warn" { $colorAmber }
        "good" { $colorAccent }
        default { $colorText }
    }
    $dataFreshnessText = if ($null -ne $session.LastTokenEventAgeSeconds) { ("{0} | token {1} ago" -f $usageVerdict.Confidence, (Format-RelativeAge $session.LastTokenEventAgeSeconds)) } else { ("{0} | waiting" -f $usageVerdict.Confidence) }
    Add-HistoryPoint -History $script:Sample.SpeedHistory -Value $speedTokPerSecond
    $tokenSecondRate.Text = ("last minute {0} out" -f (Format-Number $session.OutputTokensLastMinute))
    $eventsRate.Text = ("{0} tool calls/min" -f $session.ToolCallsPerMinute)
    $speedScale.Text = ""
    $speedScaleUpdate = Update-StableScale -Scale $script:Sample.SpeedScalePerSecond -Current $speedTokPerSecond -Floor 20 -UpTargetPercent 95 -DownTargetPercent 90 -Decay 0.97 -DropSeconds 30 -Now $now -LastDropAt $script:Sample.SpeedScaleLastDropAt
    $script:Sample.SpeedScalePerSecond = [double]$speedScaleUpdate.Scale
    $script:Sample.SpeedScaleLastDropAt = [datetime]$speedScaleUpdate.LastDropAt
    $speedPercent = if ($script:Sample.SpeedScalePerSecond -gt 0) { [Math]::Min(100, ($speedTokPerSecond / $script:Sample.SpeedScalePerSecond) * 100) } else { 0.0 }
    Set-BarValue -Bar $speedBar -Value $speedPercent
    $speedBarLegend.Text = "Reply Speed"
    $speedBarValue.Text = ("{0}/sec | best {1}/sec" -f ([Math]::Round($speedTokPerSecond, 1)), ([Math]::Round($script:Sample.SpeedMaxTokPerSecond, 1)))

    $useScaleUpdate = Update-StableScale -Scale $script:Sample.SpeedScale -Current $sessionUseCostForGraph -Floor 60000 -UpTargetPercent 95 -DownTargetPercent 90 -Decay 1.0 -DropSeconds 30 -Now $now -LastDropAt $script:Sample.UseScaleLastDropAt
    $script:Sample.SpeedScale = [double]$useScaleUpdate.Scale
    $script:Sample.UseScaleLastDropAt = [datetime]$useScaleUpdate.LastDropAt
    $tokenUsePercent = if ($script:Sample.SpeedScale -gt 0 -and $null -ne $sessionUseCostUnits) { [Math]::Min(100, ([double]$sessionUseCostUnits / $script:Sample.SpeedScale) * 100) } else { 0.0 }
    Set-BarValue -Bar $tokenUseBar -Value $tokenUsePercent
    $tokenUseBarLegend.Text = "Chat Cost"
    $tokenUseBarValue.Text = ("{0} cost points | {1} asks" -f $sessionBurnText, (Format-Number $sessionUsePromptCount))

    $lastTool.Text = $session.LastTool

    $tokensLabel.Text = $sessionUseLabel
    $sessionUseResetButton.Enabled = (-not $allMode)
    $tokenTotal.Text = if ($sessionFastText) { ("{0} cost | {1} | {2} asks" -f $sessionBurnText, $sessionFastText, (Format-Number $sessionUsePromptCount)) } else { ("{0} cost | {1} | {2} asks" -f $sessionBurnText, $usageLimitText, (Format-Number $sessionUsePromptCount)) }
    $tokenOutput.Text = if ($recentPromptCosts.Count -gt 0) { ("last {0} avg {1}" -f $recentPromptCosts.Count, $recentPromptAverageText) } else { "last 5: n/a" }
    $lastPromptAgeText = if ($null -ne $session.LastTokenEventAgeSeconds) { ("ended {0} ago" -f (Format-RelativeAge $session.LastTokenEventAgeSeconds)) } else { "waiting" }
    $lastTurn.Text = if ($lastFastText) { ("{0} cost | {1} | {2}" -f $lastPromptBurnText, $lastFastText, $lastPromptAgeText) } else { ("{0} cost | {1} {2} | {3}" -f $lastPromptBurnText, $shortWindowDeltaLabel, $lastPromptPrimaryUseText, $lastPromptAgeText) }
    $lastPromptContextText = if ($null -ne $session.LastPromptContextPercent) { ("{0}%" -f $session.LastPromptContextPercent) } else { "n/a" }
    $costMultiplierText = if ($null -ne $session.LastPromptCostMultiplier) { ("{0:N1}x" -f [double]$session.LastPromptCostMultiplier) } else { "baseline..." }
    $compactSignalText = if ($session.CompactSignal) { [string]$session.CompactSignal } else { "learning" }
    $sessionTokens.Text = ("{0} full | {1} normal cost | {2}" -f $lastPromptContextText, $costMultiplierText, $compactSignalText)
    $sessionTokens.ForeColor = switch ($compactSignalText) {
        "compact now" { $colorCoral }
        "compact soon" { $colorAmber }
        "cost spike" { $colorCoral }
        "cost high" { $colorAmber }
        "watch" { $colorAmber }
        "healthy" { $colorAccent }
        default { $colorText }
    }
    $priceStateText = switch ($priceGuard.State) {
        "over" { "HIGHER API PRICE" }
        "hard" { "start fresh now" }
        "red" { "start fresh soon" }
        "yellow" { "getting long" }
        "green" { "ok" }
        "wait" { "waiting" }
        default { "not tracked" }
    }
    $guardRunwayText = if ($null -ne $session.LastInputTokens) {
        $lastInputForRunway = [double]$session.LastInputTokens
        switch ($priceGuard.State) {
            "over" { ("over cliff by {0}" -f (Format-Number ([Math]::Max(0.0, $lastInputForRunway - $script:LongContextInputThreshold)))) }
            "hard" { ("official cliff room {0}" -f (Format-Number ($script:LongContextInputThreshold - $lastInputForRunway))) }
            "red" { ("guard room {0}" -f (Format-Number ($script:LongContextHardStopThreshold - $lastInputForRunway))) }
            "yellow" { ("guard room {0}" -f (Format-Number ($script:LongContextRedThreshold - $lastInputForRunway))) }
            "green" { ("guard room {0}" -f (Format-Number ($script:LongContextYellowThreshold - $lastInputForRunway))) }
            default { "waiting" }
        }
    } else {
        "waiting"
    }
    $contextRemaining = if ($null -ne $session.ContextWindow -and $null -ne $session.LastInputTokens) {
        [Math]::Max(0.0, [double]$session.ContextWindow - [double]$session.LastInputTokens)
    } else {
        $null
    }
    $priceStepText.Text = if ($guardLabel -and $null -ne $session.LastInputTokens) {
        ("{0}: {1} | {2}" -f $guardLabel, $priceStateText, $guardRunwayText)
    } elseif ($guardLabel) {
        ("{0} waiting for chat size" -f $guardLabel)
    } elseif ($null -ne $session.ContextUsedPercent -and $null -ne $contextRemaining) {
        ("Context: {0}% used | {1} tokens left" -f $session.ContextUsedPercent, (Format-Number $contextRemaining))
    } elseif ($null -ne $session.ContextUsedPercent) {
        ("Context: {0}% used" -f $session.ContextUsedPercent)
    } else {
        "waiting for chat size"
    }
    $priceStepLabel.ForeColor = if ($script:Sample.CostFlashOn) { $colorText } else { $colorAmber }
    $priceStepText.ForeColor = if ($script:Sample.CostFlashOn) {
        if ($priceGuard.State -eq "yellow") { $colorAmber } else { $colorCoral }
    } else {
        switch ($priceGuard.State) {
            "over" { $colorCoral }
            "hard" { $colorCoral }
            "red" { $colorCoral }
            "yellow" { $colorAmber }
            default { $colorText }
        }
    }
    $priceStepBar.Tag = if ($script:Sample.CostFlashOn) { $colorText } elseif ($priceGuard.State -eq "over" -or $priceGuard.State -eq "hard" -or $priceGuard.State -eq "red") { $colorCoral } elseif ($priceGuard.State -eq "yellow") { $colorAmber } else { $colorBlue }
    $longChatPercent = if ($guardLabel) { $priceGuard.Percent } else { $session.ContextUsedPercent }
    Set-BarValue -Bar $priceStepBar -Value $longChatPercent
    $contextText.Text = if ($null -ne $session.ContextUsedPercent) { ("{0}%" -f $session.ContextUsedPercent) } else { "n/a" }
    Add-HistoryPoint -History $script:Sample.ContextHistory -Value $session.ContextUsedPercent
    Set-BarValue -Bar $contextBar -Value $session.ContextUsedPercent

    $primaryWindowLabel = $mainLimitWindowLabel
    $secondaryWindowLabel = if ($hasAdditionalLimit) { Get-RateLimitWindowLabel -WindowMinutes $session.SecondaryWindowMinutes -Fallback "Additional Limit" } else { "Additional Limit" }
    $primaryLabel.Text = $primaryWindowLabel
    $secondaryLabel.Text = $secondaryWindowLabel
    $primaryText.Text = if ($null -ne $mainLimitUsedPercent) { ("{0:N1}% used" -f ([double]$mainLimitUsedPercent)) } else { "n/a" }
    $primaryReset.Text = if ($null -ne $mainLimitRemainingPercent) { ("{0:N1}% left / reset {1}" -f ([double]$mainLimitRemainingPercent), $mainLimitReset) } else { ("reset {0}" -f $mainLimitReset) }
    Set-BarValue -Bar $primaryBar -Value $mainLimitUsedPercent

    $secondaryText.Text = if ($hasAdditionalLimit -and $null -ne $session.SecondaryUsedPercent) { ("{0:N1}% used" -f ([double]$session.SecondaryUsedPercent)) } else { "n/a" }
    $secondaryReset.Text = if ($hasAdditionalLimit -and $null -ne $session.SecondaryRemainingPercent) { ("{0:N1}% left / reset {1}" -f ([double]$session.SecondaryRemainingPercent), $session.SecondaryReset) } else { "" }
    $additionalLimitUsedPercent = if ($hasAdditionalLimit) { $session.SecondaryUsedPercent } else { $null }
    Set-BarValue -Bar $secondaryBar -Value $additionalLimitUsedPercent
    $showAdditionalLimit = $hasAdditionalLimit -and (-not $script:Sample.MiniMode) -and ($form.ClientSize.Height -ge 535)
    foreach ($control in @($secondaryLabel, $secondaryText, $secondaryReset, $secondaryBar)) {
        $control.Visible = $showAdditionalLimit
    }
    Set-BuddyToolTip -Tip $uiTip -Control $limitGraph -Text ("Remaining-limit trend: {0}." -f $primaryWindowLabel)

    $processText.Text = ("CPU {0}% | memory {1} MB | apps {2}" -f $process.CpuPercent, $process.MemoryMb, $process.Count)
    $switchAge = if ($script:Sample.SessionSwitchedAt -eq [datetime]::MinValue) { 0 } else { [Math]::Max(0, [int]((Get-Date) - $script:Sample.SessionSwitchedAt).TotalSeconds) }
    $usageModel = if ($session.UsageSourceModel) { [string]$session.UsageSourceModel } else { [string]$session.ActiveModel }
    $modelPricing = Get-ModelPricing -Model $usageModel
    $modelDisplay = Shorten-Model $usageModel
    $modelPriceSummary = Get-ModelPriceSummary -Pricing $modelPricing
    $usagePlanType = if ($session.UsageSourcePlanType) { [string]$session.UsageSourcePlanType } else { [string]$session.PlanType }
    $usageLimitId = if ($session.UsageSourceLimitId) { [string]$session.UsageSourceLimitId } else { [string]$session.LimitId }
    $sessionText.Text = ("{0} - {1} - {2}kb" -f (Short-Cwd $session.Cwd), $modelDisplay, $session.LogKb)
    $sessionMeta.Text = ("{0} | switched {1}s | {2}" -f (Short-Cwd $session.Cwd), $switchAge, $dataFreshnessText)
    $planText.Text = ("{0} | {1} | {2}" -f $usagePlanType, $modelDisplay, $modelPriceSummary)
    $limitSummaryParts = New-Object 'System.Collections.Generic.List[string]'
    if ($null -ne $mainLimitRemainingPercent) { [void]$limitSummaryParts.Add(("{0} {1}% left" -f $mainLimitWindowShortLabel, $mainLimitRemainingPercent)) }
    if ($hasAdditionalLimit -and $null -ne $session.SecondaryRemainingPercent) { [void]$limitSummaryParts.Add(("{0} {1}% left" -f (Get-RateLimitWindowShortLabel -WindowMinutes $session.SecondaryWindowMinutes -Fallback "additional"), $session.SecondaryRemainingPercent)) }
    $limitSummaryText = $limitSummaryParts -join " | "
    if ([string]::IsNullOrWhiteSpace($limitSummaryText)) { $limitSummaryText = "limits n/a" }
    $miniSummary.Text = if ($sessionFastText) { ("{0} | last {1} cost | chat {2} cost | fast +{3}" -f $modelDisplay, $lastPromptBurnText, $sessionBurnText, $sessionFastExtraBurnText) } else { ("{0} | last {1} cost | chat {2} cost | {3}" -f $modelDisplay, $lastPromptBurnText, $sessionBurnText, $limitSummaryText) }

    if ($script:Sample.MiniMode) {
        $miniRows[0].Label.Text = "Now"
        $miniRows[0].Value.ForeColor = $verdictText.ForeColor
        Update-MiniRow -Index 0 -Value (Short-Text $usageVerdict.Text 28) -Series $script:Sample.EventHistory.ToArray() -Tip ("{0}. Confidence: {1}. Showing usage from {2}. Plan: {3}. Limit: {4}. Profiles: {5}." -f $usageVerdict.Text, $usageVerdict.Confidence, (Shorten-Model $usageModel), $usagePlanType, $usageLimitId, $session.UsageProfilesSummary)
        Update-MiniRow -Index 1 -Value ("{0}/sec | best {1}" -f ([Math]::Round($speedTokPerSecond, 1)), ([Math]::Round($script:Sample.SpeedMaxTokPerSecond, 1))) -Series $script:Sample.SpeedHistory.ToArray() -Tip ("Reply speed: {0} tokens per second. Best this run: {1}." -f ([Math]::Round($speedTokPerSecond, 2)), ([Math]::Round($script:Sample.SpeedMaxTokPerSecond, 2))) -FixedMax $script:Sample.SpeedScalePerSecond
        Update-MiniRow -Index 2 -Value $(if ($sessionFastText) { ("{0} cost | fast +{1}" -f $sessionBurnText, $sessionFastExtraBurnText) } else { ("last {0} | chat {1}" -f $lastPromptBurnText, $sessionBurnText) }) -Series $script:Sample.TokenHistory.ToArray() -Tip ("Cost points estimate. Last ask {0}, chat {1}, fast extra +{2}. Short-window meter: last {3}, chat {4}. Signal: {5}." -f $lastPromptBurnText, $sessionBurnText, $sessionFastExtraBurnText, $lastPromptPrimaryUseText, $sessionPrimaryUseText, $compactSignalText) -FixedMax $script:Sample.SpeedScale
        Update-MiniRow -Index 3 -Value ("{0} calls/min" -f $session.ToolCallsPerMinute) -Series $script:Sample.EventHistory.ToArray() -Tip ("Tool calls: {0}/min. Background events: {1}/min." -f $session.ToolCallsPerMinute, $session.EventsPerMinute)
        Update-MiniRow -Index 4 -Value $contextText.Text -Series $script:Sample.ContextHistory.ToArray() -Tip ("How full the current chat is: {0}%." -f $session.ContextUsedPercent) -FixedMax 100
        $miniRows[5].Label.Text = $primaryWindowLabel
        Update-MiniRow -Index 5 -Value ("{0}% | {1}" -f $mainLimitRemainingPercent, $mainLimitReset) -Series $script:Sample.PrimaryRemainingHistory.ToArray() -Tip ("{0} remaining: {1}%. Reset: {2}." -f $primaryWindowLabel, $mainLimitRemainingPercent, $mainLimitReset) -FixedMax 100
        $miniRows[6].Label.Text = $secondaryWindowLabel
        $miniRows[6].Label.Visible = $hasAdditionalLimit
        $miniRows[6].Value.Visible = $hasAdditionalLimit
        $miniRows[6].Graph.Visible = $hasAdditionalLimit
        if ($hasAdditionalLimit) {
            Update-MiniRow -Index 6 -Value ("{0}% | {1}" -f $session.SecondaryRemainingPercent, $session.SecondaryReset) -Series $script:Sample.SecondaryRemainingHistory.ToArray() -Tip ("{0} remaining: {1}%. Reset: {2}." -f $secondaryWindowLabel, $session.SecondaryRemainingPercent, $session.SecondaryReset) -FixedMax 100
        }
        Update-MiniRow -Index 7 -Value ("CPU {0}% RAM {1}MB Proc {2}" -f $process.CpuPercent, $process.MemoryMb, $process.Count) -Series $script:Sample.ProcessHistory.ToArray() -Tip ("Processes: {0}. CPU: {1}%. Memory: {2} MB." -f $process.Count, $process.CpuPercent, $process.MemoryMb) -FixedMax 100
    }

    if ($allMode) {
        $boardSessions = @($snapshot.Sessions |
            Sort-Object @{ Expression = { Get-SessionStatusRank $_.Status }; Descending = $true }, @{ Expression = { $_.LastWrite }; Descending = $true } |
            Select-Object -First $allSessionRows.Count)
        if ($boardSessions.Count -eq 0) {
            $allSessionRows[0].Name.Text = "No active chats"
            $allSessionRows[0].Detail.Text = "Waiting for Codex logs"
            $allSessionRows[0].Name.ForeColor = $colorMuted
            $allSessionRows[0].Detail.ForeColor = $colorMuted
            Set-BuddyToolTip -Tip $uiTip -Control $allSessionRows[0].Name -Text "No active Codex session logs were found."
            Set-BuddyToolTip -Tip $uiTip -Control $allSessionRows[0].Detail -Text "No active Codex session logs were found."
        }

        for ($i = 0; $i -lt $allSessionRows.Count; $i++) {
            $row = $allSessionRows[$i]
            if ($i -lt $boardSessions.Count) {
                $rowInfo = Get-SessionBoardRow -Session $boardSessions[$i]
                $row.Name.Text = $rowInfo.Name
                $row.Detail.Text = $rowInfo.Detail
                $row.Name.ForeColor = switch ($rowInfo.Tone) {
                    "bad" { $colorCoral }
                    "warn" { $colorAmber }
                    "good" { $colorAccent }
                    default { $colorText }
                }
                $row.Detail.ForeColor = $colorText
                Set-BuddyToolTip -Tip $uiTip -Control $row.Name -Text $rowInfo.Tip
                Set-BuddyToolTip -Tip $uiTip -Control $row.Detail -Text $rowInfo.Tip
            } elseif ($boardSessions.Count -gt 0 -or $i -gt 0) {
                $row.Name.Text = ""
                $row.Detail.Text = ""
                $row.Name.ForeColor = $colorMuted
                $row.Detail.ForeColor = $colorMuted
                $uiTip.SetToolTip($row.Name, "")
                $uiTip.SetToolTip($row.Detail, "")
            }
        }
    }

    $fastTip = ("Fast mode: detected tier {0}, current multiplier {1}x, chat extra +{2} cost points ({3}), last extra +{4} cost points ({5}). Unsupported or non-fast modes add 0." -f $session.ServiceTier, $session.FastMultiplier, $sessionFastExtraBurnText, (Format-CostUnits $session.SessionPromptFastExtraCostUnits), $lastPromptFastExtraBurnText, (Format-CostUnits $session.LastPromptFastExtraCostUnits))
    $detailsText.Text = Get-CostSpeedDetailsText -Session $session -Process $process -PriceGuard $priceGuard -UsageVerdict $usageVerdict -UsageModel $usageModel -SpeedTokPerSecond $speedTokPerSecond -SpeedMaxTokPerSecond $script:Sample.SpeedMaxTokPerSecond -SessionBurnText $sessionBurnText -LastPromptBurnText $lastPromptBurnText -SessionFastExtraBurnText $sessionFastExtraBurnText -LastPromptFastExtraBurnText $lastPromptFastExtraBurnText -SessionPrimaryUseText $sessionPrimaryUseText -LastPromptPrimaryUseText $lastPromptPrimaryUseText -CostMultiplierText $costMultiplierText -CompactSignalText $compactSignalText -LastPromptAgeText $lastPromptAgeText -BurnScaleText $burnScaleText -ModelPriceSummary $modelPriceSummary
    Set-BuddyToolTip -Tip $uiTip -Control $verdictLabel -Text ("Simple readout: {0}. Data: {1}. Fresh means Codex recently wrote token and limit data; Estimate means recent token data but no fresh limit delta; Old means the data may be stale." -f $usageVerdict.Text, $usageVerdict.Confidence)
    Set-BuddyToolTip -Tip $uiTip -Control $verdictText -Text ("Simple readout: {0}. Data: {1}. Fresh means Codex recently wrote token and limit data; Estimate means recent token data but no fresh limit delta; Old means the data may be stale." -f $usageVerdict.Text, $usageVerdict.Confidence)
    Set-BuddyToolTip -Tip $uiTip -Control $detailsButton -Text "Open a short cost and speed summary."
    $usageLimitTip = if ($weeklyOnly) { ("Current {0}: {1:N1}% used, {2:N1}% left, reset {3}. Codex did not report a short-window bucket for this session." -f $mainLimitWindowLabel, ([double]$mainLimitUsedPercent), ([double]$mainLimitRemainingPercent), $mainLimitReset) } else { ("{0} meter change: {1}." -f $shortWindowDeltaLabel, $sessionPrimaryUseText) }
    Set-BuddyToolTip -Tip $uiTip -Control $tokensRate -Text ("{0}Estimated displayed cost is {1} cost points across {2} asks. Full chat cost is {3}. {4} {5}" -f $sessionUseTipPrefix, $sessionBurnText, (Format-Number $sessionUsePromptCount), $fullSessionBurnText, $usageLimitTip, $fastTip)
    $uiTip.SetToolTip($tokenSecondRate, ("Output in the last 60 seconds: {0} tokens." -f (Format-Number $session.OutputTokensLastMinute)))
    $uiTip.SetToolTip($speedBar, ("Reply speed is {0} tokens/sec. Best this run is {1} tokens/sec." -f $speedTokPerSecond, ([Math]::Round($script:Sample.SpeedMaxTokPerSecond, 1))))
    $uiTip.SetToolTip($speedBarValue, ("Reply speed is {0} tokens/sec. Best this run is {1} tokens/sec." -f $speedTokPerSecond, ([Math]::Round($script:Sample.SpeedMaxTokPerSecond, 1))))
    $uiTip.SetToolTip($tokenUseBar, ("{0}Estimated displayed cost: {1} cost points. Full chat: {2}." -f $sessionUseTipPrefix, $sessionBurnText, $fullSessionBurnText))
    $uiTip.SetToolTip($tokenUseBarValue, ("{0}Estimated displayed cost: {1} cost points. Full chat: {2}." -f $sessionUseTipPrefix, $sessionBurnText, $fullSessionBurnText))
    Set-BuddyToolTip -Tip $uiTip -Control $speedScale -Text ("Background event rate: {0}/min." -f $session.EventsPerMinute)
    $uiTip.SetToolTip($eventsRate, ("Tool-call throughput: {0} calls/min." -f $session.ToolCallsPerMinute))
    $uiTip.SetToolTip($processText, ("System metrics: {0} CPU, {1} MB RAM, {2} process(es)." -f $process.CpuPercent, $process.MemoryMb, $process.Count))
    $uiTip.SetToolTip($lastTool, ("Last tool: {0}" -f $session.LastTool))
    Set-BuddyToolTip -Tip $uiTip -Control $tokenTotal -Text ("{0}Estimated displayed cost: {1} cost points across {2} asks. Full chat cost: {3}. {4} {5}" -f $sessionUseTipPrefix, $sessionBurnText, (Format-Number $sessionUsePromptCount), $fullSessionBurnText, $usageLimitTip, $fastTip)
    Set-BuddyToolTip -Tip $uiTip -Control $sessionUseResetButton -Text "Reset the visible Session Use counter for this selected conversation. This only changes Buddy's baseline; it does not change Codex logs or billing."
    Set-BuddyToolTip -Tip $uiTip -Control $tokenOutput -Text (Get-PromptCostHistoryText -Session $session -CostUnitsPerOnePercent $session.BurnCostUnitsPerPercent)
    Set-BuddyToolTip -Tip $uiTip -Control $tokenLastLabel -Text ("Last ask cost: {0} cost points. {1} meter change: {2}. Updated {3}." -f $lastPromptBurnText, $shortWindowDeltaLabel, $lastPromptPrimaryUseText, $lastPromptAgeText)
    Set-BuddyToolTip -Tip $uiTip -Control $lastTurn -Text ("Last ask cost: {0} cost points. {1} meter change: {2}. Updated {3}." -f $lastPromptBurnText, $shortWindowDeltaLabel, $lastPromptPrimaryUseText, $lastPromptAgeText)
    $costTrendTip = ("Cost signal: {0}. Last ask used {1} of the chat window and cost {2}x normal." -f $compactSignalText, $lastPromptContextText, $costMultiplierText)
    Set-BuddyToolTip -Tip $uiTip -Control $sessionTokenLabel -Text $costTrendTip
    Set-BuddyToolTip -Tip $uiTip -Control $sessionTokens -Text $costTrendTip
    $guardSessionText = if ($session.PriceGuardSessionId) { Short-SessionId $session.PriceGuardSessionId } else { Short-SessionId $session.SessionId }
    $tokenAgeText = if ($null -ne $session.LastTokenEventAgeSeconds) { ("Last token_count update {0}s ago." -f $session.LastTokenEventAgeSeconds) } else { "No token_count update has been logged yet." }
    if ($guardLabel) {
        $longChatTip = ("{0} API long-context guard. {1} Current input tokens: {2}. Official cliff starts over 272K. Guard chat: {3}." -f $guardLabel, $tokenAgeText, (Format-Number $session.LastInputTokens), $guardSessionText)
    } else {
        $longChatTip = ("Local model context usage. {0} Current input tokens: {1} of {2}." -f $tokenAgeText, (Format-Number $session.LastInputTokens), (Format-Number $session.ContextWindow))
    }
    Set-BuddyToolTip -Tip $uiTip -Control $priceStepLabel -Text $longChatTip
    Set-BuddyToolTip -Tip $uiTip -Control $priceStepText -Text $longChatTip
    if ($guardLabel) {
        Set-BuddyToolTip -Tip $uiTip -Control $priceStepBar -Text ("Current input tokens are {0:N1}% of the official 272K API long-context cliff." -f $priceGuard.Percent)
    } else {
        Set-BuddyToolTip -Tip $uiTip -Control $priceStepBar -Text ("Current chat context is {0}% of the local model window ({1} tokens)." -f $session.ContextUsedPercent, (Format-Number $session.ContextWindow))
    }
    $uiTip.SetToolTip($contextText, ("Current context load: {0}%." -f $session.ContextUsedPercent))
    $uiTip.SetToolTip($contextBar, ("Context usage {0}% of window {1} tokens." -f $session.ContextUsedPercent, (Format-Number $session.ContextWindow)))
    $primaryUseTip = if ($null -ne $mainLimitUsedPercent -and $null -ne $mainLimitRemainingPercent) { ("Showing {0} from {1}: {2:N1}% used, {3:N1}% left. Reset: {4}. Profiles: {5}." -f $primaryWindowLabel, (Shorten-Model $usageModel), ([double]$mainLimitUsedPercent), ([double]$mainLimitRemainingPercent), $mainLimitReset, $session.UsageProfilesSummary) } else { ("Showing {0} from {1}: waiting for limit data. Profiles: {2}." -f $primaryWindowLabel, (Shorten-Model $usageModel), $session.UsageProfilesSummary) }
    Set-BuddyToolTip -Tip $uiTip -Control $primaryText -Text $primaryUseTip
    Set-BuddyToolTip -Tip $uiTip -Control $primaryReset -Text $primaryUseTip
    Set-BuddyToolTip -Tip $uiTip -Control $primaryBar -Text $primaryUseTip
    $uiTip.SetToolTip($secondaryText, $(if ($hasAdditionalLimit) { ("Showing {0} from {1}: {2:N1}% used, {3:N1}% left. Profiles: {4}." -f $secondaryWindowLabel, (Shorten-Model $usageModel), $session.SecondaryUsedPercent, $session.SecondaryRemainingPercent, $session.UsageProfilesSummary) } else { "No additional active limit is reported by Codex." }))
    $uiTip.SetToolTip($secondaryReset, $(if ($hasAdditionalLimit) { ("Showing {0} reset from {1}: {2}. Profiles: {3}." -f $secondaryWindowLabel, (Shorten-Model $usageModel), $session.SecondaryReset, $session.UsageProfilesSummary) } else { "No additional active limit is reported by Codex." }))
    Set-BuddyToolTip -Tip $uiTip -Control $secondaryBar -Text $(if ($hasAdditionalLimit) { ("Showing active {0} usage from {1}: {2}% used | reset {3}. Profiles: {4}." -f $secondaryWindowLabel, (Shorten-Model $usageModel), $session.SecondaryUsedPercent, $session.SecondaryReset, $session.UsageProfilesSummary) } else { "No additional active limit is reported by Codex." })
    Set-BuddyToolTip -Tip $uiTip -Control $planText -Text ("Showing usage from {0}. Plan {1} | API price: {2} | source limit {3} | display limit {4}. Profiles: {5}." -f $modelDisplay, $usagePlanType, $modelPriceSummary, $usageLimitId, $session.LimitId, $session.UsageProfilesSummary)
    $uiTip.SetToolTip($sessionText, ("Workspace {0}. Model {1}. API price: {2}. Log updated {3} ago. Size {4}kb." -f (Short-Cwd $session.Cwd), $modelDisplay, $modelPriceSummary, (Format-RelativeAge $session.LastWriteAgeSeconds), $session.LogKb))
    $uiTip.SetToolTip($sessionMeta, ("Workspace {0}. Model {1}. API price: {2}. Switched {3}s ago. Showing usage from {4}." -f (Short-Cwd $session.Cwd), $modelDisplay, $modelPriceSummary, $switchAge, $modelDisplay))
    Set-BuddyToolTip -Tip $uiTip -Control $miniSummary -Text ("Showing {0}. Last ask {1} cost points. Displayed chat {2} cost points. Full chat {3}. Limits: {4}." -f (Shorten-Model $usageModel), $lastPromptBurnText, $sessionBurnText, $fullSessionBurnText, $limitSummaryText)

    if (-not $script:Sample.MiniMode) {
        Draw-Graph -Box $tokenGraph -Series $script:Sample.TokenHistory.ToArray() -Title "Chat Cost" -LineColor ([System.Drawing.Color]::FromArgb(117, 224, 167))
        Draw-Graph -Box $processGraph -Series $script:Sample.ProcessHistory.ToArray() -Title "Process CPU" -LineColor ([System.Drawing.Color]::FromArgb(255, 199, 95)) -FixedMax 100
        Draw-Graph -Box $useGraph -Series $script:Sample.EventHistory.ToArray() -Title "Tools/Min" -LineColor ([System.Drawing.Color]::FromArgb(242, 132, 130))
        Draw-LimitGraph -Box $limitGraph -PrimarySeries $script:Sample.PrimaryRemainingHistory.ToArray() -SecondarySeries $script:Sample.SecondaryRemainingHistory.ToArray()
    }
    } finally {
        $script:Sample.Updating = $false
    }
}

function Show-DisplayError {
    param($ErrorRecord)

    Write-BuddyCrashLog $ErrorRecord
    $message = if ($ErrorRecord -and $ErrorRecord.Exception) { $ErrorRecord.Exception.Message } else { "Unknown display error" }
    $status.Text = "ERROR"
    $status.ForeColor = $colorAmber
    $status.BackColor = $colorStatusWarmBack
    $tokensRate.Text = "n/a"
    $verdictText.Text = "Error"
    $eventsRate.Text = "n/a"
    $lastTool.Text = $message
    $miniSummary.Text = $message
    $detailsText.Text = $message
    $uiTip.SetToolTip($status, $message)
}

Enable-DragAnywhere -Control $form
Apply-Theme
Set-DisplayMode -Mini $false
Set-BuddyOpacity -Percent $script:Sample.WindowOpacity
Set-BuddyTopMost -Enabled $script:Sample.AlwaysOnTop
Sync-SettingsWindows
if ($script:Sample.ClickThrough) {
    $gearForm.Show()
} else {
    $gearForm.Hide()
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = [Math]::Max(1, $RefreshSeconds) * 1000
$timer.Add_Tick({
    try {
        Update-Display
    } catch {
        Show-DisplayError -ErrorRecord $_
    }
})
$form.Add_Shown({
    $timer.Start()
})

[System.Windows.Forms.Application]::Run($form)
