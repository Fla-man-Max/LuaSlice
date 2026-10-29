param([string] $NoteFixture = '', [string] $BaseGameProject = '', [switch] $CheckConverters, [switch] $CheckEditor, [switch] $NoMods, [switch] $CheckCommunity)
$ErrorActionPreference = 'Stop'
$taskWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$taskPlatform = if ($taskWindows) { 'windows' } else { 'linux' }
$taskLinkType = if ($taskWindows) { 'Junction' } else { 'SymbolicLink' }
$taskWindowOptions = @{}
if ($taskWindows) { $taskWindowOptions.WindowStyle = 'Hidden' }
$taskSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$taskBin = Join-Path $taskSource "export/release/$taskPlatform/bin"
$taskFixture = Join-Path $PSScriptRoot 'psych-lua'
$taskTestCode = $PSScriptRoot
function Test-PsychLuaSavePersistence {
    param([string] $ModDirectory)
    $taskRuntimeRoot = Split-Path -Parent (Split-Path -Parent $ModDirectory)
    $taskSaveRoots = @($taskRuntimeRoot, (Join-Path $taskRuntimeRoot 'psych-test-save'), (Join-Path $taskRuntimeRoot 'psych-test-save/company/game'))
    foreach ($taskRequest in Get-ChildItem -LiteralPath $ModDirectory -File -Filter 'save-persistence-request-*.json') {
        if (Test-Path -LiteralPath ($taskRequest.FullName + '.verified')) { continue }
        $taskIdentity = Get-Content -LiteralPath $taskRequest.FullName -Raw | ConvertFrom-Json
        $taskSaveRoot = $null
        foreach ($taskCandidate in $taskSaveRoots) {
            if (Test-Path -LiteralPath (Join-Path $taskCandidate ($taskIdentity.path + '/' + $taskIdentity.name + '.sol'))) { $taskSaveRoot = $taskCandidate; break }
        }
        if ($null -eq $taskSaveRoot) { throw "Could not locate on-disk save for persistence check: $($taskIdentity.name)" }
        & haxe -cp $taskTestCode --run PsychLuaFixtures verify-save $taskSaveRoot $taskRequest.FullName
        if ($LASTEXITCODE -ne 0) { throw "On-disk save persistence verification failed: $($taskRequest.FullName)" }
    }
}
if ($BaseGameProject -ne '') { $taskSource = (Resolve-Path -LiteralPath $BaseGameProject).Path; $taskBin = Join-Path $taskSource "export/release/$taskPlatform/bin" }
$taskExecutable = if ($BaseGameProject -ne '') { 'Funkin' } else { 'LuaSlice' }
if ($taskWindows) { $taskExecutable += '.exe' }
if (-not (Test-Path -LiteralPath (Join-Path $taskBin $taskExecutable))) { throw "Missing $taskPlatform release executable: $taskBin/$taskExecutable" }
$taskExtension = if ($BaseGameProject -ne '') { '.lua' } else { '.luap' }
$taskRuntime = Join-Path $taskSource ('.work/psych-tests/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$taskMod = Join-Path $taskRuntime 'mods/psych-lua-test'
New-Item -ItemType Directory -Path $taskRuntime -Force | Out-Null
foreach ($taskFolder in @('assets', 'manifest', 'plugins')) {
    $taskTarget = Join-Path $taskBin $taskFolder
    if (Test-Path -LiteralPath $taskTarget) {
        New-Item -ItemType $taskLinkType -Path (Join-Path $taskRuntime $taskFolder) -Target $taskTarget | Out-Null
    }
}
Get-ChildItem -LiteralPath $taskBin -File | Where-Object { $_.Extension -in @('.dll', '.ndll', '.so') -or $_.Name -eq $taskExecutable } | Copy-Item -Destination $taskRuntime
if ($NoMods) {
    if ($BaseGameProject -ne '') { throw 'NoMods is a LuaSlice regression check.' }
    Copy-Item -LiteralPath (Join-Path $taskFixture 'psych-test.marker') -Destination $taskRuntime
    New-Item -ItemType Directory -Path (Join-Path $taskRuntime 'mods') -Force | Out-Null
    $taskStdout = Join-Path $taskRuntime 'stdout.log'
    $taskProcess = Start-Process @taskWindowOptions -FilePath (Join-Path $taskRuntime $taskExecutable) -ArgumentList '--lua-test', '--lua-test-no-mods' -WorkingDirectory $taskRuntime -RedirectStandardOutput $taskStdout -RedirectStandardError (Join-Path $taskRuntime 'stderr.log') -PassThru
    try {
        $taskDeadline = (Get-Date).AddSeconds(120)
        $taskReadyAt = $null
        while ((Get-Date) -lt $taskDeadline) {
            Start-Sleep -Seconds 1
            $taskProcess.Refresh()
            if ($taskProcess.HasExited) { throw "No-mod startup exited early. See $taskRuntime" }
            [string]$taskOutput = Get-Content -LiteralPath $taskStdout -Raw
            if ($taskOutput -match 'Fatal Uncaught|Null Object Reference|Loading failed:|\[Psych Lua\].*\[Psych Lua/LuaJIT\]') { throw "No-mod startup error. See $taskRuntime" }
            if ($taskOutput -match 'Opening Attract state in') {
                if ($null -eq $taskReadyAt) { $taskReadyAt = Get-Date }
                if (((Get-Date) - $taskReadyAt).TotalSeconds -ge 15) {
                    Write-Output "PASS: No-mod startup reached TitleState and stayed running. Logs: $taskRuntime"
                    exit 0
                }
            }
        }
        throw "No-mod startup timed out. See $taskRuntime"
    } finally {
        $taskProcess.Refresh()
        if (-not $taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id }
    }
}
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
    Copy-Item -LiteralPath (Join-Path $taskFixture 'global.nxg') -Destination (Join-Path $taskMod 'global.nxg')
    New-Item -ItemType Directory -Path (Join-Path $taskMod 'data/characters') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $taskSource 'assets/preload/data/characters/senpai.json') -Destination (Join-Path $taskMod 'data/characters/scripted-character-test.json')
    foreach ($taskCreationScript in @('CreationNoteKindTest.hxc','CreationSongEventTest.hxc')) {
        Copy-Item -LiteralPath (Join-Path $taskFixture $taskCreationScript) -Destination (Join-Path $taskMod "scripts/$taskCreationScript")
    }
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
        $taskNoteScript = Join-Path $NoteFixture "custom_notetypes/$taskKind.lua"
        if (-not (Test-Path -LiteralPath $taskNoteScript)) { $taskNoteScript = Join-Path $NoteFixture "custom_notetypes/$taskKind.luap" }
        Copy-Item -LiteralPath $taskNoteScript -Destination (Join-Path $taskMod "custom_notetypes/$taskKind$taskExtension")
    }
    Copy-Item -LiteralPath (Join-Path $taskFixture 'note-compat.luapg') -Destination (Join-Path $taskMod ("scripts/note-compat" + $(if ($BaseGameProject -ne '') { '.lua' } else { '.luapg' })))
}
$taskStdout = Join-Path $taskRuntime 'stdout.log'
if ($BaseGameProject -eq '' -and -not $CheckEditor) {
    & haxe -cp $taskTestCode --run PsychLuaFixtures atlas $taskMod
    if ($LASTEXITCODE -ne 0) { throw 'Could not generate trusted atlas fixture.' }
    $taskMetadataBinary = Join-Path $taskRuntime 'metadata-regression.n'
    Push-Location -LiteralPath $taskSource
    try {
        & haxe -cp (Join-Path $taskSource 'source') -cp $taskTestCode -lib polymod -lib thx.semver -lib lime -D lime_cffi --macro "haxe.macro.Compiler.nullSafety('polymod.hscript._internal.PolymodStaticAbstractReference', Off)" -main ModMetadataRepairTest -neko $taskMetadataBinary
        if ($LASTEXITCODE -ne 0) { throw 'Could not compile trusted metadata regression test.' }
        & neko $taskMetadataBinary | Tee-Object -FilePath (Join-Path $taskRuntime 'metadata-regression.log')
        if ($LASTEXITCODE -ne 0) { throw 'Trusted metadata regression test failed.' }
    } finally { Pop-Location }
}
if ($CheckEditor) {
    Copy-Item -LiteralPath (Join-Path $taskFixture 'ConverterEditorTest.hxc') -Destination (Join-Path $taskMod 'scripts/ConverterEditorTest.hxc')
    if ($CheckCommunity) {
        Copy-Item -LiteralPath (Join-Path $taskFixture 'ChartClipboardRegression.hxc') -Destination (Join-Path $taskMod 'scripts/ChartClipboardRegression.hxc')
        Copy-Item -LiteralPath (Join-Path $taskFixture 'NoteAnimationEditorRegression.hxc') -Destination (Join-Path $taskMod 'scripts/NoteAnimationEditorRegression.hxc')
    }
} elseif ($CheckCommunity) {
    Copy-Item -LiteralPath (Join-Path $taskFixture 'DynamicCameraAnimationRegression.hxc') -Destination (Join-Path $taskMod 'scripts/DynamicCameraAnimationRegression.hxc')
    Copy-Item -LiteralPath (Join-Path $taskFixture 'hscript-compat.luapg') -Destination (Join-Path $taskMod 'hscript-compat.luapg')
}
if ($CheckConverters) {
    Copy-Item -LiteralPath (Join-Path $taskFixture 'converter-check.luapg') -Destination (Join-Path $taskMod "scripts/converter-check$taskExtension")
}
$taskProcess = Start-Process @taskWindowOptions -FilePath (Join-Path $taskRuntime $taskExecutable) -ArgumentList '--lua-test', '--lua-song=tutorial' -WorkingDirectory $taskRuntime -RedirectStandardOutput $taskStdout -RedirectStandardError (Join-Path $taskRuntime 'stderr.log') -PassThru
try {
    $taskDeadline = (Get-Date).AddSeconds(300)
    $taskPassedAt = $null
    while ((Get-Date) -lt $taskDeadline) {
        Start-Sleep -Seconds 1
        $taskProcess.Refresh()
        [string]$taskOutput = if (Test-Path -LiteralPath $taskStdout) { Get-Content -LiteralPath $taskStdout -Raw } else { '' }
        if ($taskProcess.HasExited) { throw "Test process exited early: $($taskProcess.ExitCode). See $taskRuntime" }
        if ([string]::IsNullOrEmpty($taskOutput)) { continue }
        if ($BaseGameProject -eq '' -and -not $CheckEditor) { Test-PsychLuaSavePersistence $taskMod }
        $taskUnexpectedPsychErrors = @($taskOutput -split '\r?\n' | Where-Object {
            $_ -match 'Psych Lua\]?\s+\[.*\]\[' -and -not ($CheckCommunity -and $_.Contains('[HScript]') -and $_.Contains('hscript-compat.luapg'))
        })
        if ($taskUnexpectedPsychErrors.Count -gt 0 -or $taskOutput -match 'COMMUNITY_REGRESSION_FAILED:|\[Psych Lua/LuaJIT\]|Fatal Uncaught|Null Object Reference|Error while executing function|LuaScriptManager.*(Error in|Failed to load)') {
            throw "Runtime script error. See $taskRuntime"
        }
        if ($CheckEditor) {
            if ($taskOutput.Contains('CONVERTER_EDITOR_FAILED:')) { throw "Editor import failed. See $taskRuntime" }
            if ($taskOutput.Contains('CONVERTER_EDITOR_OGG_OK') -and $taskOutput.Contains('EDITOR_PLAYTEST_RETURN_OK')) {
                if ($CheckCommunity -and -not $taskOutput.Contains('CHART_CLIPBOARD_REGRESSION_OK')) { throw "Chart clipboard regression did not pass. See $taskRuntime" }
                if ($CheckCommunity -and -not $taskOutput.Contains('PLAY_ANIMATION_EDITOR_REGRESSION_OK')) { throw "Animation note editor regression did not pass. See $taskRuntime" }
                if ($null -eq $taskPassedAt) { $taskPassedAt = Get-Date }
                if (((Get-Date) - $taskPassedAt).TotalSeconds -ge 15) {
                    Write-Output "PASS: Both converted chart formats, repeated full-length OGG imports, vocals/waveforms, corrupt audio rejection, playtest audio and return to ChartEditorState. Logs: $taskRuntime"
                    exit 0
                }
            }
            continue
        }
        if (Test-Path -LiteralPath (Join-Path $taskMod 'runtime-pass.txt')) {
            if ($null -eq $taskPassedAt) { $taskPassedAt = Get-Date }
            if (((Get-Date) - $taskPassedAt).TotalSeconds -ge 15) {
                if ($CheckCommunity) {
                    foreach ($taskCommunityMarker in @('DYNAMIC_CAMERA_REGRESSION_OK', 'PLAY_ANIMATION_NOTE_REGRESSION_OK', 'HSCRIPT_DEFAULTS_CALLBACKS_OK', 'HSCRIPT_OPTIONAL_IMPORT_OK', 'HSCRIPT_PARSE_RECOVERY_OK', 'HSCRIPT_RUNTIME_RECOVERY_OK', 'HSCRIPT_CALLBACK_RECOVERY_OK', 'HSCRIPT_SANDBOX_OK', 'HSCRIPT_COMPAT_RECOVERY_OK')) {
                        if (-not $taskOutput.Contains($taskCommunityMarker)) { throw "Community regression did not pass: $taskCommunityMarker. See $taskRuntime" }
                    }
                    $taskHScriptRuns = [regex]::Matches($taskOutput, 'HSCRIPT_COMPAT_RECOVERY_OK').Count
                    $taskHScriptDiagnostics = @($taskOutput -split '\r?\n' | Where-Object { $_.Contains('[HScript]') -and $_.Contains('hscript-compat.luapg') })
                    if ($taskHScriptDiagnostics.Count -ne 7 * $taskHScriptRuns) { throw "Unexpected number of HScript fixture diagnostics: $($taskHScriptDiagnostics.Count), runs $taskHScriptRuns. See $taskRuntime" }
                }
                foreach ($taskMarker in @('PSYCH_TEST_CREATE_OK', 'PSYCH_TEST_CREATE_POST_OK', 'PSYCH_TEST_TIMER_OK', 'PSYCH_TEST_TWEEN_OK', 'PSYCH_TEST_RELOAD_OK', 'PSYCH_ROUTING_AND_BRIDGE_OK', 'PSYCH_RUNTIME_CHECK_PASS', 'PSYCH_RUNTIME_DESTROY_OK', 'LUASLICE_LEGACY_CREATE_OK', 'LUASLICE_LEGACY_DESTROY_OK')) {
                    if ($BaseGameProject -ne '' -and $taskMarker.StartsWith('LUASLICE_')) { continue }
                    if (-not $taskOutput.Contains($taskMarker)) { throw "Missing marker: $taskMarker. See $taskRuntime" }
                }
                if ($NoteFixture -ne '' -and -not (Test-Path -LiteralPath (Join-Path $taskMod 'note-check-passed.txt'))) {
                    throw "Custom-note checks did not pass. See $taskRuntime"
                }
                if ($BaseGameProject -eq '') {
                    if (-not $taskOutput.Contains('PSYCH_LIFECYCLE_SAFE_OK')) { throw "Lifecycle regression did not pass. See $taskRuntime" }
                    if (-not $taskOutput.Contains('NOTE_POOL_AND_SAVE_REGRESSION_OK')) { throw "Note recycling/save regression did not pass. See $taskRuntime" }
                    if (-not $taskOutput.Contains('PSYCH_ATLAS_HOLD_REGRESSION_OK')) { throw "Sparrow hold regression did not pass. See $taskRuntime" }
                    if (-not $taskOutput.Contains('NOTE_COPY_AND_JUDGEMENT_REGRESSION_OK')) { throw "Copy/paste or judgement regression did not pass. See $taskRuntime" }
                    if (-not (Get-Content -LiteralPath (Join-Path $taskRuntime 'metadata-regression.log') -Raw).Contains('ModMetadataRepairTest passed 20 checks')) { throw "Trusted metadata repair regression did not pass. See $taskRuntime" }
                    if (-not $taskOutput.Contains('NXSCRIPT_RUNTIME_OK')) { throw "NxScript coexistence did not pass. See $taskRuntime" }
                    foreach ($taskNewMarker in @('CUSTOM_EVENT_REGRESSION_OK','CHARACTER_GETTER_REGRESSION_OK','LUASLICE_NATIVE_EVENT_OK','LUASLICE_HOLD_EVENT_OK','LUASLICE_CUSTOM_EVENT_OK','PSYCH_CUSTOM_EVENT_OK','SSCRIPT_CUSTOM_EVENT_OK','NXSCRIPT_CUSTOM_EVENT_OK')) {
                        if (-not $taskOutput.Contains($taskNewMarker)) { throw "Missing regression marker: $taskNewMarker. See $taskRuntime" }
                    }
                    if ([regex]::Matches($taskOutput, 'LUASLICE_INHERITED_HOOK_ONCE').Count -ne [regex]::Matches($taskOutput, 'PSYCH_LIFECYCLE_SAFE_OK').Count) {
                        throw "Inherited Lua hook ran more than once per lifecycle. See $taskRuntime"
                    }
                    foreach ($taskCreationMarker in @('NOTE_KIND_CREATE_REGRESSION_OK','SONG_EVENT_CREATE_REGRESSION_OK','SONG_EVENT_HANDLE_REGRESSION_OK')) {
                        if (-not $taskOutput.Contains($taskCreationMarker)) { throw "Creation regression did not pass: $taskCreationMarker. See $taskRuntime" }
                    }
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
