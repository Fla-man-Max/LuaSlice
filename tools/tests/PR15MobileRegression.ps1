param([int] $TimeoutSeconds = 90)
$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$taskBin = Join-Path $taskSource 'export/release/windows/bin'
$taskRuntime = Join-Path $taskSource ('.work/pr15-mobile/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$taskMod = Join-Path $taskRuntime 'mods/psych-lua-test'
New-Item -ItemType Directory -Path (Join-Path $taskMod 'scripts') -Force | Out-Null
foreach ($taskFolder in @('assets', 'manifest', 'plugins')) {
    New-Item -ItemType Junction -Path (Join-Path $taskRuntime $taskFolder) -Target (Join-Path $taskBin $taskFolder) | Out-Null
}
Get-ChildItem -LiteralPath $taskBin -File | Where-Object { $_.Extension -in @('.dll', '.ndll') -or $_.Name -eq 'LuaSlice.exe' } | Copy-Item -Destination $taskRuntime
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'PR15MobileRegression.hxc') -Destination (Join-Path $taskMod 'scripts')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'PR15MobileRegression.lua') -Destination $taskMod
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/scripts-meta.json') -Destination (Join-Path $taskMod '_polymod_meta.json')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/psych-test.marker') -Destination $taskRuntime
$taskStdout = Join-Path $taskRuntime 'stdout.log'
$taskProcess = Start-Process -WindowStyle Hidden -FilePath (Join-Path $taskRuntime 'LuaSlice.exe') -ArgumentList '--lua-test' -WorkingDirectory $taskRuntime -RedirectStandardOutput $taskStdout -RedirectStandardError (Join-Path $taskRuntime 'stderr.log') -PassThru
try {
    $taskDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $taskDeadline) {
        Start-Sleep -Milliseconds 500
        $taskProcess.Refresh()
        $taskOutput = if (Test-Path -LiteralPath $taskStdout) { Get-Content -LiteralPath $taskStdout -Raw } else { '' }
        if ($taskOutput -match 'PR15_MOBILE_REGRESSION_FAILED|Fatal Uncaught|Null Object Reference|Loading failed:|Could not parse|Could not load script|Error while parsing') { throw "Mobile regression failed. See $taskRuntime" }
        if ($taskOutput -match 'PR15_MOBILE_NATIVE_OK' -and $taskOutput -match 'PR15_MOBILE_LUA_OK') {
            Write-Output "PASS: native mobile ownership, cleanup and Lua prelude regressions. Logs: $taskRuntime"
            exit 0
        }
        if ($taskProcess.HasExited) { throw "Mobile regression exited early. See $taskRuntime" }
    }
    throw "Mobile regression timed out. See $taskRuntime"
} finally {
    $taskProcess.Refresh()
    if (-not $taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id }
}
