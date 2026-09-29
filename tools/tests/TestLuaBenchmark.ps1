param([Parameter(Mandatory)][string] $Executable)
$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$taskBin = Join-Path $taskSource 'export/release/windows/bin'
$taskRuntime = Join-Path $taskSource ('.work/lua-benchmarks/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $taskRuntime -Force | Out-Null
foreach ($taskFolder in 'assets', 'manifest', 'plugins') {
    if (Test-Path -LiteralPath (Join-Path $taskBin $taskFolder)) {
        New-Item -ItemType Junction -Path (Join-Path $taskRuntime $taskFolder) -Target (Join-Path $taskBin $taskFolder) | Out-Null
    }
}
Get-ChildItem -LiteralPath $taskBin -File | Where-Object { $_.Extension -in '.dll', '.ndll' } | Copy-Item -Destination $taskRuntime
Copy-Item -LiteralPath $Executable -Destination (Join-Path $taskRuntime 'LuaSlice.exe')
$taskMod = Join-Path $taskRuntime 'mods/psych-lua-test'
New-Item -ItemType Directory -Path $taskMod -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $taskSource 'example_mods/psych-lua-test/_polymod_meta.json') -Destination $taskMod
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/psych-test.marker') -Destination $taskRuntime
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'psych-lua/benchmark.lua') -Destination (Join-Path $taskRuntime 'mods/global.lua')
$taskStdout = Join-Path $taskRuntime 'stdout.log'
$taskProcess = Start-Process -FilePath (Join-Path $taskRuntime 'LuaSlice.exe') -ArgumentList '--lua-test', '--lua-song=tutorial' -WorkingDirectory $taskRuntime -WindowStyle Hidden -RedirectStandardOutput $taskStdout -RedirectStandardError (Join-Path $taskRuntime 'stderr.log') -PassThru
try {
    $taskDeadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $taskDeadline) {
        Start-Sleep -Seconds 1
        $taskProcess.Refresh()
        if ($taskProcess.HasExited) { throw "Benchmark exited early. See $taskRuntime" }
        [string]$taskOutput = Get-Content -LiteralPath $taskStdout -Raw
        if ($taskOutput -match 'LUA_BENCHMARK_DONE') {
            $taskOutput -split '\r?\n' | Where-Object { $_ -match 'LUA_BENCHMARK' }
            Write-Output "Logs: $taskRuntime"
            exit 0
        }
    }
    throw "Benchmark timed out. See $taskRuntime"
} finally {
    $taskProcess.Refresh()
    if (-not $taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id }
}
