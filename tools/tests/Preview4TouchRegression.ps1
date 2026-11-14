param([int] $TimeoutSeconds = 90, [string] $Executable = '')
$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$taskBin = Join-Path $taskSource 'export/release/windows/bin'
$taskExecutable = if ($Executable) { $Executable } else { Join-Path $taskBin 'LuaSlice.exe' }
if (-not (Test-Path -LiteralPath $taskExecutable)) { throw 'Build the migrated preview binary before running this native test. The preserved v0.8.6 binary is not a valid substitute.' }
$taskExecutable = (Resolve-Path -LiteralPath $taskExecutable).Path
$taskRuntime = Join-Path $taskSource ('.work/preview4-touch/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$taskMod = Join-Path $taskRuntime 'mods/psych-lua-test'
New-Item -ItemType Directory -Path (Join-Path $taskMod 'scripts') -Force | Out-Null
foreach ($taskFolder in @('assets', 'manifest', 'plugins')) {
    New-Item -ItemType Junction -Path (Join-Path $taskRuntime $taskFolder) -Target (Join-Path $taskBin $taskFolder) | Out-Null
}
Get-ChildItem -LiteralPath $taskBin -File | Where-Object { $_.Extension -in @('.dll', '.ndll') } | Copy-Item -Destination $taskRuntime
Copy-Item -LiteralPath $taskExecutable -Destination (Join-Path $taskRuntime 'LuaSlice.exe')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Preview4TouchRegression.hxc') -Destination (Join-Path $taskMod 'scripts')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/scripts-meta.json') -Destination (Join-Path $taskMod '_polymod_meta.json')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/psych-test.marker') -Destination $taskRuntime
$taskDisabled = Join-Path $taskRuntime 'mods/disabled-lua-fixture'
$taskLoose = Join-Path $taskRuntime 'mods/scripts/states'
foreach ($taskStatePath in @((Join-Path $taskMod 'scripts/states'), (Join-Path $taskDisabled 'scripts/states'), $taskLoose)) {
    New-Item -ItemType Directory -Path $taskStatePath -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/scripts-meta.json') -Destination (Join-Path $taskDisabled '_polymod_meta.json')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'original-lua/active.luag') -Destination (Join-Path $taskMod 'scripts/states/MusicBeatState.luag')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'original-lua/disabled.luag') -Destination (Join-Path $taskDisabled 'scripts/states/MusicBeatState.luag')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'original-lua/disabled-module.lua') -Destination (Join-Path $taskDisabled 'luaslice_disabled_fixture.lua')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'original-lua/active-module.lua') -Destination (Join-Path $taskMod 'scripts/luaslice_active_fixture.lua')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'original-lua/loose.luag') -Destination (Join-Path $taskLoose 'MusicBeatState.luag')
$taskStdout = Join-Path $taskRuntime 'stdout.log'
$taskProcess = Start-Process -WindowStyle Hidden -FilePath (Join-Path $taskRuntime 'LuaSlice.exe') -ArgumentList '--lua-test' -WorkingDirectory $taskRuntime -RedirectStandardOutput $taskStdout -RedirectStandardError (Join-Path $taskRuntime 'stderr.log') -PassThru
try {
    $taskDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $taskDeadline) {
        Start-Sleep -Milliseconds 500
        $taskProcess.Refresh()
        $taskOutput = if (Test-Path -LiteralPath $taskStdout) { Get-Content -LiteralPath $taskStdout -Raw } else { '' }
        $taskCrash = Get-ChildItem -LiteralPath (Join-Path $taskRuntime 'logs') -Filter 'crash-native-*.log' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($taskCrash) { throw "Native touch regression crashed. See $($taskCrash.FullName)" }
        if ($taskOutput -match 'PREVIEW4_TOUCH_NATIVE_FAILED|Fatal Uncaught|Null Object Reference|Loading failed:|Could not parse|Could not load script|Error while parsing|Error while executing function') { throw "Native touch regression failed. See $taskRuntime" }
        if ($taskOutput -match 'PREVIEW4_TOUCH_NATIVE_OK') {
            if ($taskOutput -match 'ORIGINAL_LUA_DISABLED_(SCRIPT|MODULE)_RAN' -or
                $taskOutput -notmatch 'ORIGINAL_LUA_ACTIVE_SCRIPT_RAN' -or
                $taskOutput -notmatch 'ORIGINAL_LUA_ACTIVE_MODULE_RAN' -or
                $taskOutput -notmatch 'ORIGINAL_LUA_LOOSE_SCRIPT_RAN') {
                throw "Original Lua did not honor the active mod list or lost loose-script compatibility. See $taskRuntime"
            }
            Write-Output "PASS: migrated touch, event ownership, original Lua mod activation, and chart editor audio persistence. Logs: $taskRuntime"
            exit 0
        }
        if ($taskProcess.HasExited) { throw "Native touch regression exited early. See $taskRuntime" }
    }
    throw "Native touch regression timed out. See $taskRuntime"
} finally {
    $taskProcess.Refresh()
    if (-not $taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id }
}
