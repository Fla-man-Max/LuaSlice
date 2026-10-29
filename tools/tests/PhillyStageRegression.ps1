param([switch] $PackagedStages)
$ErrorActionPreference = 'Stop'
$phillySource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$phillyBin = Join-Path $phillySource 'export/release/windows/bin'
$phillyRuntime = Join-Path $phillySource ('.work/philly-stage-tests/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$phillyMod = Join-Path $phillyRuntime 'mods/psych-lua-test'
New-Item -ItemType Directory -Path (Join-Path $phillyMod 'scripts/stages') -Force | Out-Null
foreach ($phillyFolder in @('assets', 'manifest', 'plugins')) {
    New-Item -ItemType Junction -Path (Join-Path $phillyRuntime $phillyFolder) -Target (Join-Path $phillyBin $phillyFolder) | Out-Null
}
Get-ChildItem -LiteralPath $phillyBin -File | Where-Object { $_.Extension -in @('.dll', '.ndll') -or $_.Name -eq 'LuaSlice.exe' } | Copy-Item -Destination $phillyRuntime
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/psych-test.marker') -Destination $phillyRuntime
Copy-Item -LiteralPath (Join-Path $phillySource 'example_mods/psych-lua-test/_polymod_meta.json') -Destination $phillyMod
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'PhillyStageRegression.hxc') -Destination (Join-Path $phillyMod 'scripts')
foreach ($phillyStage in @('phillyStreets', 'phillyStreetsErect')) {
    $phillyInput = if ($PackagedStages) { Join-Path $phillyBin "assets/scripts/stages/$phillyStage.hxc" } else { Join-Path $phillySource "assets/preload/scripts/stages/$phillyStage.hxc" }
    $phillyCode = Get-Content -LiteralPath $phillyInput -Raw
    $phillyStart = $phillyCode.IndexOf('  override function addProp(')
    $phillyEnd = $phillyCode.IndexOf('  override function addCharacter(', $phillyStart)
    if ($phillyStart -lt 0 -or $phillyEnd -lt 0) { throw 'Cannot locate stage addProp regression boundary.' }
    $phillyMethod = $phillyCode.Substring($phillyStart, $phillyEnd - $phillyStart)
    $phillyOpen = $phillyMethod.IndexOf('{')
    $phillyClose = $phillyMethod.LastIndexOf('}')
    $phillyMethod = $phillyMethod.Insert($phillyClose, "`n    } catch (error:Dynamic) { trace('PHILLY_STAGE_REGRESSION_FAILED: $phillyStage addProp: ' + error); }`n  ").Insert($phillyOpen + 1, "`n    try {`n")
    $phillyCode = $phillyCode.Substring(0, $phillyStart) + $phillyMethod + $phillyCode.Substring($phillyEnd)
    $phillyCode | Set-Content -LiteralPath (Join-Path $phillyMod "scripts/stages/$phillyStage.hxc") -Encoding utf8
}
$phillyStdout = Join-Path $phillyRuntime 'stdout.log'
$phillyProcess = Start-Process -WindowStyle Hidden -FilePath (Join-Path $phillyRuntime 'LuaSlice.exe') -ArgumentList '--lua-test', '--lua-song=tutorial' -WorkingDirectory $phillyRuntime -RedirectStandardOutput $phillyStdout -RedirectStandardError (Join-Path $phillyRuntime 'stderr.log') -PassThru
try {
    $phillyDeadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $phillyDeadline) {
        Start-Sleep -Milliseconds 250
        $phillyProcess.Refresh()
        $phillyOutput = Get-Content -LiteralPath $phillyStdout -Raw
        if ($phillyOutput -match 'PHILLY_STAGE_REGRESSION_FAILED|Fatal Uncaught|Error while executing function|Loading failed:') { throw "Philly stage regression failed. Logs: $phillyRuntime" }
        if ($phillyOutput -match 'PHILLY_STAGE_REGRESSION_OK') { Write-Output "PASS: Philly stage prop behavior. Logs: $phillyRuntime"; exit 0 }
        if ($phillyProcess.HasExited) { throw "Philly fixture exited early. Logs: $phillyRuntime" }
    }
    throw "Philly fixture timed out. Logs: $phillyRuntime"
} finally {
    $phillyProcess.Refresh()
    if (-not $phillyProcess.HasExited) { Stop-Process -Id $phillyProcess.Id }
}
