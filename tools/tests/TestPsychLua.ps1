param([string] $NoteFixture = '', [string] $BaseGameProject = '', [switch] $CheckConverters, [switch] $CheckEditor)
$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$taskBin = Join-Path $taskSource 'export/release/windows/bin'
$taskFixture = Join-Path $PSScriptRoot 'psych-lua'
if ($BaseGameProject -ne '') { $taskSource = (Resolve-Path -LiteralPath $BaseGameProject).Path; $taskBin = Join-Path $taskSource 'export/release/windows/bin' }
$taskExecutable = if ($BaseGameProject -ne '') { 'Funkin.exe' } else { 'LuaSlice.exe' }
$taskExtension = if ($BaseGameProject -ne '') { '.lua' } else { '.luap' }
$taskRuntime = Join-Path $taskSource ('.work/psych-tests/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$taskMod = Join-Path $taskRuntime 'mods/psych-lua-test'
New-Item -ItemType Directory -Path $taskRuntime -Force | Out-Null
foreach ($taskFolder in @('assets', 'manifest', 'plugins')) {
    $taskTarget = Join-Path $taskBin $taskFolder
    if (Test-Path -LiteralPath $taskTarget) {
        New-Item -ItemType Junction -Path (Join-Path $taskRuntime $taskFolder) -Target $taskTarget | Out-Null
    }
}
Get-ChildItem -LiteralPath $taskBin -File | Where-Object { $_.Extension -in @('.dll', '.ndll') -or $_.Name -eq $taskExecutable } | Copy-Item -Destination $taskRuntime
New-Item -ItemType Directory -Path (Join-Path $taskRuntime 'mods') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $taskSource 'example_mods/psych-lua-test') -Destination $taskMod -Recurse
New-Item -ItemType Directory -Path (Join-Path $taskMod 'data/songs/Tutorial'), (Join-Path $taskMod 'data/songs/not-tutorial') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $taskFixture 'psych-test.marker') -Destination $taskRuntime
if ($BaseGameProject -ne '') {
    Copy-Item -LiteralPath (Join-Path $taskFixture 'runtime-check.luapg') -Destination (Join-Path $taskMod 'scripts/00-runtime-check.lua')
} elseif (-not $CheckEditor) {
    Copy-Item -LiteralPath (Join-Path $taskFixture 'runtime-check.luapg') -Destination $taskMod
    Copy-Item -LiteralPath (Join-Path $taskFixture 'not-psych.lua') -Destination (Join-Path $taskMod 'scripts')
    Copy-Item -LiteralPath (Join-Path $taskFixture 'legacy-check.lua') -Destination (Join-Path $taskRuntime 'mods/global.lua')
    Copy-Item -LiteralPath (Join-Path $taskFixture 'legacy-global.luag') -Destination (Join-Path $taskRuntime 'mods/global.luag')
    New-Item -ItemType Directory -Path (Join-Path $taskRuntime 'mods/scripts') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $taskFixture 'scripts-meta.json') -Destination (Join-Path $taskRuntime 'mods/scripts/_polymod_meta.json')
    Copy-Item -LiteralPath (Join-Path $taskFixture 'legacy-second.lua') -Destination (Join-Path $taskRuntime 'mods/scripts/global.lua')
    Copy-Item -LiteralPath (Join-Path $taskFixture 'runtime-helper.lua') -Destination (Join-Path $taskRuntime 'mods/scripts/runtime-helper.lua')
    Copy-Item -LiteralPath (Join-Path $taskFixture 'convenience.ss') -Destination (Join-Path $taskMod 'scripts/PlayState.ss')
}
Copy-Item -LiteralPath (Join-Path $taskFixture 'folder-check.luap') -Destination (Join-Path $taskMod "scripts/folder-check$taskExtension")
Copy-Item -LiteralPath (Join-Path $taskFixture 'song-check.luap') -Destination (Join-Path $taskMod "data/songs/Tutorial/song-check$taskExtension")
Copy-Item -LiteralPath (Join-Path $taskFixture 'unrelated-check.luap') -Destination (Join-Path $taskMod "data/songs/not-tutorial/unrelated-check$taskExtension")
if ($NoteFixture -ne '') {
    foreach ($taskFolder in @('images', 'sounds')) {
        Copy-Item -LiteralPath (Join-Path $NoteFixture $taskFolder) -Destination (Join-Path $taskMod $taskFolder) -Recurse
    }
    New-Item -ItemType Directory -Path (Join-Path $taskMod 'custom_notetypes') -Force | Out-Null
    foreach ($taskKind in @('ItemNotePixel', 'RoaringNote')) {
        Copy-Item -LiteralPath (Join-Path $NoteFixture "custom_notetypes/$taskKind.lua") -Destination (Join-Path $taskMod "custom_notetypes/$taskKind$taskExtension")
    }
    Copy-Item -LiteralPath (Join-Path $taskFixture 'note-compat.luapg') -Destination (Join-Path $taskMod ("scripts/note-compat" + $(if ($BaseGameProject -ne '') { '.lua' } else { '.luapg' })))
}
$taskStdout = Join-Path $taskRuntime 'stdout.log'
if ($CheckEditor) {
    Copy-Item -LiteralPath (Join-Path $taskFixture 'ConverterEditorTest.hxc') -Destination (Join-Path $taskMod 'scripts/ConverterEditorTest.hxc')
}
if ($CheckConverters) {
    Copy-Item -LiteralPath (Join-Path $taskFixture 'converter-check.luapg') -Destination (Join-Path $taskMod "scripts/converter-check$taskExtension")
}
$taskProcess = Start-Process -FilePath (Join-Path $taskRuntime $taskExecutable) -ArgumentList '--lua-test', '--lua-song=tutorial' -WorkingDirectory $taskRuntime -WindowStyle Hidden -RedirectStandardOutput $taskStdout -RedirectStandardError (Join-Path $taskRuntime 'stderr.log') -PassThru
try {
    $taskDeadline = (Get-Date).AddSeconds(300)
    $taskPassedAt = $null
    while ((Get-Date) -lt $taskDeadline) {
        Start-Sleep -Seconds 1
        $taskProcess.Refresh()
        [string]$taskOutput = if (Test-Path -LiteralPath $taskStdout) { Get-Content -LiteralPath $taskStdout -Raw } else { '' }
        if ($taskProcess.HasExited) { throw "Test process exited early: $($taskProcess.ExitCode). See $taskRuntime" }
        if ([string]::IsNullOrEmpty($taskOutput)) { continue }
        if ($taskOutput -match 'Psych Lua\]?\s+\[.*\]\[' -or $taskOutput -match 'Fatal Uncaught|Null Object Reference') {
            throw "Runtime script error. See $taskRuntime"
        }
        if ($CheckEditor) {
            if ($taskOutput.Contains('CONVERTER_EDITOR_FAILED:')) { throw "Editor import failed. See $taskRuntime" }
            if ($taskOutput.Contains('CONVERTER_EDITOR_OGG_OK')) {
                if ($null -eq $taskPassedAt) { $taskPassedAt = Get-Date }
                if (((Get-Date) - $taskPassedAt).TotalSeconds -ge 15) {
                    Write-Output "PASS: Both converted chart formats, repeated full-length OGG imports, vocals/waveforms and corrupt audio rejection in ChartEditorState. Logs: $taskRuntime"
                    exit 0
                }
            }
            continue
        }
        if (Test-Path -LiteralPath (Join-Path $taskMod 'runtime-pass.txt')) {
            if ($null -eq $taskPassedAt) { $taskPassedAt = Get-Date }
            if (((Get-Date) - $taskPassedAt).TotalSeconds -ge 15) {
                foreach ($taskMarker in @('PSYCH_TEST_CREATE_OK', 'PSYCH_TEST_CREATE_POST_OK', 'PSYCH_TEST_TIMER_OK', 'PSYCH_TEST_TWEEN_OK', 'PSYCH_TEST_RELOAD_OK', 'PSYCH_ROUTING_AND_BRIDGE_OK', 'PSYCH_RUNTIME_CHECK_PASS', 'PSYCH_RUNTIME_DESTROY_OK', 'LUASLICE_LEGACY_CREATE_OK', 'LUASLICE_LEGACY_DESTROY_OK')) {
                    if ($BaseGameProject -ne '' -and $taskMarker.StartsWith('LUASLICE_')) { continue }
                    if (-not $taskOutput.Contains($taskMarker)) { throw "Missing marker: $taskMarker. See $taskRuntime" }
                }
                if ($NoteFixture -ne '' -and -not (Test-Path -LiteralPath (Join-Path $taskMod 'note-check-passed.txt'))) {
                    throw "Custom-note checks did not pass. See $taskRuntime"
                }
                if ($BaseGameProject -eq '') {
                    foreach ($taskMarker in 'LUASLICE_GLOBAL_ISOLATION_OK', 'LUASLICE_SECOND_ISOLATION_OK', 'LUASLICE_TASK_OK', 'LUASLICE_CONVENIENCE_OK', 'SSCRIPT_CONVENIENCE_OK') {
                        if (-not $taskOutput.Contains($taskMarker)) { throw "Missing marker: $taskMarker. See $taskRuntime" }
                    }
                }
                if ($CheckConverters -and -not $taskOutput.Contains('CONVERTER_REGRESSION_OK')) { throw "Converter checks did not pass. See $taskRuntime" }
                if (Test-Path -LiteralPath (Join-Path $taskRuntime 'crash')) {
                    if (Get-ChildItem -LiteralPath (Join-Path $taskRuntime 'crash') -File -Recurse) { throw "Crash report created. See $taskRuntime" }
                }
                Write-Output "PASS: Psych callbacks, routing, isolated globals, bridge, legacy coexistence, reload, substate and song exit. Logs: $taskRuntime"
                exit 0
            }
        }
    }
    throw "Runtime test timed out. See $taskRuntime"
}
finally {
    $taskProcess.Refresh()
    if (-not $taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id }
}
