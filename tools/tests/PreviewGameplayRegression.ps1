param(
    [string] $Executable,
    [int] $TimeoutSeconds = 90
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Executable) -or -not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
    Write-Output 'NOT RUN: supply -Executable pointing to a newly built Preview 4 Windows executable. This runner does not build or use the old release.'
    exit 2
}
$gameplayExe = (Resolve-Path -LiteralPath $Executable).Path
$gameplayBin = Split-Path -Parent $gameplayExe
if (-not (Test-Path -LiteralPath (Join-Path $gameplayBin 'assets') -PathType Container)) {
    throw 'The migrated executable needs its packaged assets directory beside it.'
}
$gameplaySource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$gameplayRuntime = Join-Path $gameplaySource ('.work/preview-gameplay/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$gameplayMod = Join-Path $gameplayRuntime 'mods/psych-lua-test'
New-Item -ItemType Directory -Path (Join-Path $gameplayMod 'scripts') -Force | Out-Null
foreach ($gameplayFolder in @('assets', 'manifest', 'plugins')) {
    $gameplayInput = Join-Path $gameplayBin $gameplayFolder
    if (Test-Path -LiteralPath $gameplayInput -PathType Container) {
        New-Item -ItemType Junction -Path (Join-Path $gameplayRuntime $gameplayFolder) -Target $gameplayInput | Out-Null
    }
}
Get-ChildItem -LiteralPath $gameplayBin -File | Where-Object { $_.Extension -in @('.dll', '.ndll') } | Copy-Item -Destination $gameplayRuntime
Copy-Item -LiteralPath $gameplayExe -Destination $gameplayRuntime
foreach ($gameplayFixture in @('PreviewGameplayRegression.hxc', 'PreviewGameplaySoundscapeRegression.hxc')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $gameplayFixture) -Destination (Join-Path $gameplayMod 'scripts')
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'PreviewGameplayLifecycle.luap') -Destination (Join-Path $gameplayMod 'scripts')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'PreviewGameplayFixture-meta.json') -Destination (Join-Path $gameplayMod '_polymod_meta.json')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/psych-test.marker') -Destination $gameplayRuntime
$gameplayStdout = Join-Path $gameplayRuntime 'stdout.log'
$gameplayProcess = Start-Process -WindowStyle Hidden -FilePath (Join-Path $gameplayRuntime (Split-Path -Leaf $gameplayExe)) -ArgumentList '--lua-test', '--lua-song=tutorial' -WorkingDirectory $gameplayRuntime -RedirectStandardOutput $gameplayStdout -RedirectStandardError (Join-Path $gameplayRuntime 'stderr.log') -PassThru
try {
    $gameplayDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $gameplayDeadline) {
        Start-Sleep -Milliseconds 250
        $gameplayProcess.Refresh()
        $gameplayOutput = if (Test-Path -LiteralPath $gameplayStdout) { Get-Content -LiteralPath $gameplayStdout -Raw } else { '' }
        $gameplayCrash = Get-ChildItem -LiteralPath (Join-Path $gameplayRuntime 'logs') -Filter 'crash-native-*.log' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($gameplayCrash) { throw "FAILED: native Preview 4 gameplay crashed. See $($gameplayCrash.FullName)" }
        if ($gameplayOutput -match 'Fatal Uncaught|Null Object Reference|Loading failed:|Could not parse superclass|Could not load script|Error while parsing|Error while executing function') {
            throw "FAILED: native Preview 4 gameplay regression. Logs: $gameplayRuntime"
        }
        if ($gameplayOutput -match 'PREVIEW_GAMEPLAY_REGRESSION_(OK|FAILED)' -and $gameplayOutput -match 'PREVIEW_GAMEPLAY_SOUNDSCAPE_REGRESSION_(OK|FAILED)' -and $gameplayOutput -match 'PREVIEW_GAMEPLAY_LIFECYCLE_(OK|FAILED)') {
            if ($gameplayOutput -match 'PREVIEW_GAMEPLAY_\w*FAILED') {
                throw "FAILED: native Preview 4 gameplay regression. Logs: $gameplayRuntime"
            }
            if ($gameplayOutput -notmatch 'PREVIEW_GAMEPLAY_LIFECYCLE_INITIAL_OK') {
                throw "FAILED: Psych initial lifecycle did not finish before retry. Logs: $gameplayRuntime"
            }
            Write-Output "PASSED: native Preview 4 gameplay regression. Logs: $gameplayRuntime"
            exit 0
        }
        if ($gameplayProcess.HasExited) { throw "FAILED: native fixture exited before completing. Logs: $gameplayRuntime" }
    }
    throw "FAILED: native gameplay regression timed out. Logs: $gameplayRuntime"
}
finally {
    $gameplayProcess.Refresh()
    if (-not $gameplayProcess.HasExited) { Stop-Process -Id $gameplayProcess.Id }
}
