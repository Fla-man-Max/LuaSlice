param([string] $Project = '')
$ErrorActionPreference = 'Stop'
$taskWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$taskPlatform = if ($taskWindows) { 'windows' } else { 'linux' }
$taskLinkType = if ($taskWindows) { 'Junction' } else { 'SymbolicLink' }
$taskExecutable = if ($taskWindows) { 'LuaSlice.exe' } else { 'LuaSlice' }
$taskWindowOptions = @{}
if ($taskWindows) { $taskWindowOptions.WindowStyle = 'Hidden' }
$taskSource = if ($Project -eq '') { (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path } else { (Resolve-Path -LiteralPath $Project).Path }
$taskBin = Join-Path $taskSource "export/release/$taskPlatform/bin"
$taskRuntime = Join-Path $taskSource ('.work/pr15-tests/' + $taskPlatform + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$taskMod = Join-Path $taskRuntime 'mods/psych-lua-test'
New-Item -ItemType Directory -Path $taskMod -Force | Out-Null
foreach ($taskFolder in @('assets', 'manifest', 'plugins')) {
    $taskTarget = Join-Path $taskBin $taskFolder
    if (Test-Path -LiteralPath $taskTarget) { New-Item -ItemType $taskLinkType -Path (Join-Path $taskRuntime $taskFolder) -Target $taskTarget | Out-Null }
}
Get-ChildItem -LiteralPath $taskBin -File | Where-Object { $_.Extension -in @('.dll', '.ndll', '.so') -or $_.Name -eq $taskExecutable } | Copy-Item -Destination $taskRuntime
Copy-Item -LiteralPath (Join-Path $taskSource 'example_mods/psych-lua-test/_polymod_meta.json') -Destination $taskMod
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/PR15Compat.luapg') -Destination $taskMod
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/psych-test.marker') -Destination $taskRuntime
& haxe -cp $PSScriptRoot --run PsychLuaFixtures atlas $taskMod
if ($LASTEXITCODE -ne 0) { throw 'PR15 atlas fixture generation failed.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/PR15Frames.xml') -Destination (Join-Path $taskMod 'images/PR15Frames.xml')
Copy-Item -LiteralPath (Join-Path $taskMod 'images/atlas-hold-test.png') -Destination (Join-Path $taskMod 'images/PR15Frames.png')
Copy-Item -LiteralPath (Join-Path $taskSource 'assets/shared/images/characters/gf') -Destination (Join-Path $taskMod 'images/PR15Animate') -Recurse
$taskStdout = Join-Path $taskRuntime 'stdout.log'
$taskProcess = Start-Process @taskWindowOptions -FilePath (Join-Path $taskRuntime $taskExecutable) -ArgumentList '--lua-test', '--lua-song=tutorial' -WorkingDirectory $taskRuntime -RedirectStandardOutput $taskStdout -RedirectStandardError (Join-Path $taskRuntime 'stderr.log') -PassThru
try {
    $taskDeadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $taskDeadline) {
        Start-Sleep -Seconds 1
        $taskProcess.Refresh()
        $taskOutput = if (Test-Path -LiteralPath $taskStdout) { Get-Content -LiteralPath $taskStdout -Raw } else { '' }
        $taskUnexpectedHScriptErrors = @($taskOutput -split '\r?\n' | Where-Object { $_.Contains('[HScript]') -and -not ($_.Contains('PR15Invalid.hx:') -and $_.Contains('[parse]')) })
        if ($taskUnexpectedHScriptErrors.Count -gt 0) { throw "Unexpected HScript error. Logs: $taskRuntime" }
        if ($taskOutput -match 'PR15_COMPAT_FAILED:|Fatal Uncaught|Null Object Reference|\[Psych Lua/LuaJIT\]') { throw "PR15 regression failed. Logs: $taskRuntime" }
        if ($taskOutput -match 'PR15_COMPAT_OK' -and (Test-Path -LiteralPath (Join-Path $taskMod 'PR15-pass.txt'))) {
            if ([regex]::Matches($taskOutput, '\[HScript\]\[[^\r\n]*PR15Invalid\.hx:\d+\]\[parse\]').Count -ne 1) { throw "Expected exactly one invalid HScript diagnostic. Logs: $taskRuntime" }
            Write-Output "PASS: PR15 Psych compatibility. Logs: $taskRuntime"
            exit 0
        }
        if ($taskProcess.HasExited) { throw "PR15 test exited early: $($taskProcess.ExitCode). Logs: $taskRuntime" }
    }
    throw "PR15 regression timed out. Logs: $taskRuntime"
} finally {
    $taskProcess.Refresh()
    if (-not $taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id }
}
