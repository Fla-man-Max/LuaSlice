param([int] $TimeoutSeconds = 120, [string] $ReferenceExecutable = '')
$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$taskWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$taskPlatform = if ($taskWindows) { 'windows' } else { 'linux' }
$taskLinkType = if ($taskWindows) { 'Junction' } else { 'SymbolicLink' }
$taskExecutable = if ($taskWindows) { 'LuaSlice.exe' } else { 'LuaSlice' }
$taskOptions = @{}
if ($taskWindows) { $taskOptions.WindowStyle = 'Hidden' }
$taskBin = Join-Path $taskSource "export/release/$taskPlatform/bin"
$taskRuntime = Join-Path $taskSource ('.work/upstream-editor/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$taskMod = Join-Path $taskRuntime 'mods/psych-lua-test'
New-Item -ItemType Directory -Path (Join-Path $taskMod 'scripts') -Force | Out-Null
foreach ($taskFolder in @('assets', 'manifest', 'plugins')) {
    $taskTarget = Join-Path $taskBin $taskFolder
    if (Test-Path -LiteralPath $taskTarget) { New-Item -ItemType $taskLinkType -Path (Join-Path $taskRuntime $taskFolder) -Target $taskTarget | Out-Null }
}
Get-ChildItem -LiteralPath $taskBin -File | Where-Object { $_.Extension -in @('.dll', '.ndll', '.so') -or $_.Name -eq $taskExecutable } | Copy-Item -Destination $taskRuntime
if ($ReferenceExecutable -ne '') { Copy-Item -LiteralPath $ReferenceExecutable -Destination (Join-Path $taskRuntime $taskExecutable) }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'UpstreamEditorRegression.hxc') -Destination (Join-Path $taskMod 'scripts')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/scripts-meta.json') -Destination (Join-Path $taskMod '_polymod_meta.json')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/psych-test.marker') -Destination $taskRuntime
$taskStdout = Join-Path $taskRuntime 'stdout.log'
$taskProcess = Start-Process @taskOptions -FilePath (Join-Path $taskRuntime $taskExecutable) -ArgumentList '--lua-test', '--lua-song=tutorial' -WorkingDirectory $taskRuntime -RedirectStandardOutput $taskStdout -RedirectStandardError (Join-Path $taskRuntime 'stderr.log') -PassThru
try {
    $taskDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $taskDeadline) {
        Start-Sleep -Milliseconds 500
        $taskProcess.Refresh()
        $taskOutput = if (Test-Path -LiteralPath $taskStdout) { Get-Content -LiteralPath $taskStdout -Raw } else { '' }
        if ($taskOutput -match 'UPSTREAM_REGRESSION_FAILED') { throw "Upstream editor regressions failed. Logs: $taskRuntime" }
        if ($taskOutput -match 'Fatal Uncaught|Error while parsing|Could not parse|Error while executing') { throw "Unexpected engine/script error. Logs: $taskRuntime" }
        if ($taskOutput -match 'UPSTREAM_REGRESSION_OK: 5') { Write-Output "PASS: five upstream editor regressions. Logs: $taskRuntime"; exit 0 }
        if ($taskProcess.HasExited) { throw "Regression process exited early. Logs: $taskRuntime" }
    }
    throw "Regression timed out. Logs: $taskRuntime"
} finally {
    $taskProcess.Refresh()
    if (-not $taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id }
}
