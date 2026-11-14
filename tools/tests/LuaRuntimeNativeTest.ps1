param([int] $CompileThreads = 4)
$ErrorActionPreference = 'Stop'
$runtimeRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
Import-Module (Join-Path $runtimeRoot 'tools/build/BuildMenu.psm1') -Force
Initialize-WindowsHaxe
Initialize-WindowsCompiler
$runtimeOldThreads = $env:HXCPP_COMPILE_THREADS
$runtimeOutput = Join-Path $runtimeRoot '.work/lua-runtime-native-test'
$runtimeOldLibraries = $env:HAXELIB_PATH
try {
    $env:HXCPP_COMPILE_THREADS = [string][Math]::Max(1, $CompileThreads)
    $env:HAXELIB_PATH = Join-Path $runtimeRoot '.haxelib'
    Push-Location $runtimeRoot
    try {
        Invoke-BuildCommand haxe @(
            '-cp', 'source', '-cp', 'tools/tests', '-lib', 'hxluajit-wrapper', '-lib', 'polymod',
            '-D', 'FEATURE_LUA_SCRIPTS', '-D', 'scriptable', '-D', 'HXCPP_M64', '-D', 'no-compilation',
            '-D', 'POLYMOD_CPPIA', '-dce', 'no',
            '--macro', "addGlobalMetadata('', '@:build(polymod.hscript._internal.PolymodBaseClassMacro.buildBaseClass())')",
            '--macro', 'haxe.macro.Compiler.addGlobalMetadata("hxluajit", "@:hscriptBaseCreated", true, true, false)',
            '-main', 'LuaRuntimeNativeTest', '-cpp', $runtimeOutput
        )
    } finally { Pop-Location }
    Push-Location $runtimeOutput
    try {
        Invoke-BuildCommand haxelib @('run', 'hxcpp', 'Build.xml', 'haxe', '-DHXCPP_M64')
        Invoke-BuildCommand (Join-Path $runtimeOutput 'LuaRuntimeNativeTest.exe') @()
    } finally { Pop-Location }
} finally {
    $env:HXCPP_COMPILE_THREADS = $runtimeOldThreads
    $env:HAXELIB_PATH = $runtimeOldLibraries
}
