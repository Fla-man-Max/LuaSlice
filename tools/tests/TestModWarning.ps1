param([ValidateSet('all', 'flagged', 'booleanFlagged', 'unflagged', 'booleanUnflagged', 'numeric', 'missing', 'malformed')][string] $Mode = 'all')
$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$taskWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$taskPlatform = if ($taskWindows) { 'windows' } else { 'linux' }
$taskExecutable = if ($taskWindows) { 'LuaSlice.exe' } else { 'LuaSlice' }
$taskBin = Join-Path $taskSource "export/release/$taskPlatform/bin"
$taskLinkType = if ($taskWindows) { 'Junction' } else { 'SymbolicLink' }
if (-not (Test-Path -LiteralPath (Join-Path $taskBin $taskExecutable))) { throw "Missing release executable: $taskBin/$taskExecutable" }
$taskModes = if ($Mode -eq 'all') { @('flagged', 'booleanFlagged', 'unflagged', 'booleanUnflagged', 'numeric', 'missing', 'malformed') } else { @($Mode) }
foreach ($taskMode in $taskModes) {
    $taskRuntime = Join-Path $taskSource ('.work/mod-warning-tests/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + $taskMode)
    $taskMod = Join-Path $taskRuntime 'mods/psych-lua-test'
    New-Item -ItemType Directory -Path (Join-Path $taskMod 'scripts') -Force | Out-Null
    foreach ($taskFolder in @('assets', 'manifest', 'plugins')) {
        $taskTarget = Join-Path $taskBin $taskFolder
        if (Test-Path -LiteralPath $taskTarget) {
            New-Item -ItemType $taskLinkType -Path (Join-Path $taskRuntime $taskFolder) -Target $taskTarget | Out-Null
        }
    }
    Get-ChildItem -LiteralPath $taskBin -File | Where-Object { $_.Extension -in @('.dll', '.ndll', '.so') -or $_.Name -eq $taskExecutable } | Copy-Item -Destination $taskRuntime
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/psych-test.marker') -Destination $taskRuntime
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/PhotosensitivityWarningFixture.hxc') -Destination (Join-Path $taskMod 'scripts')
    $taskMetadata = @{
        title = 'Photosensitivity Warning Fixture'; description = 'Isolated warning gate regression test'; id = 'psych-lua-test'
        contributors = @(@{name = 'LuaSlice tests'}); api_version = '0.8.6'; mod_version = '1.0.0'; license = 'Apache-2.0'
        metadata = @{photosensitivityWarning = $(if ($taskMode -eq 'flagged') { 'true' } else { 'false' })}
    }
    if ($taskMode -eq 'missing') { $taskMetadata.Remove('metadata') }
    if ($taskMode -eq 'booleanFlagged') { $taskMetadata.metadata.photosensitivityWarning = $true }
    if ($taskMode -eq 'booleanUnflagged') { $taskMetadata.metadata.photosensitivityWarning = $false }
    if ($taskMode -eq 'numeric') { $taskMetadata.metadata.photosensitivityWarning = 1 }
    if ($taskMode -eq 'malformed') { $taskMetadata.metadata.photosensitivityWarning = @{unexpected = $true} }
    $taskMetadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $taskMod '_polymod_meta.json') -Encoding utf8
    $taskStdout = Join-Path $taskRuntime 'stdout.log'
    $taskWindowOptions = @{}
    if ($taskWindows) { $taskWindowOptions.WindowStyle = 'Hidden' }
    $taskProcess = Start-Process @taskWindowOptions -FilePath (Join-Path $taskRuntime $taskExecutable) -ArgumentList '--lua-test' -WorkingDirectory $taskRuntime -RedirectStandardOutput $taskStdout -RedirectStandardError (Join-Path $taskRuntime 'stderr.log') -PassThru
    try {
        $taskDeadline = (Get-Date).AddSeconds(60)
        $taskWarningAt = $null
        $taskPassed = $false
        while ((Get-Date) -lt $taskDeadline) {
            Start-Sleep -Milliseconds 250
            $taskProcess.Refresh()
            [string]$taskOutput = Get-Content -LiteralPath $taskStdout -Raw
            if ($taskProcess.HasExited) { throw "$taskMode startup exited early. Logs: $taskRuntime" }
            if ($taskOutput -match 'Fatal Uncaught|Null Object Reference|Loading failed:|Error while executing function') { throw "$taskMode startup error. Logs: $taskRuntime" }
            $taskHasModule = $taskOutput -match 'MOD_WARNING_FIXTURE.*INITIALIZED'
            $taskHasWarning = $taskOutput -match 'MOD WARNING.*Waiting for acknowledgment'
            if ($taskMode -in @('flagged', 'booleanFlagged')) {
                if ($taskHasModule) { throw "Flagged mod initialized before acknowledgment. Logs: $taskRuntime" }
                if ($taskHasWarning -and $null -eq $taskWarningAt) { $taskWarningAt = Get-Date }
                if ($null -ne $taskWarningAt -and ((Get-Date) - $taskWarningAt).TotalSeconds -ge 3) {
                    $taskPassed = $true
                    break
                }
            } else {
                if ($taskHasWarning) { throw "Unflagged mod unexpectedly warned. Logs: $taskRuntime" }
                if ($taskHasModule) {
                    $taskPassed = $true
                    break
                }
            }
        }
        if (-not $taskPassed) { throw "$taskMode warning regression timed out. Logs: $taskRuntime" }
        Write-Output "PASS: $taskMode warning gate. Logs: $taskRuntime"
    } finally {
        $taskProcess.Refresh()
        if (-not $taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id }
    }
}
