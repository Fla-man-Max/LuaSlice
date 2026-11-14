param(
    [ValidateSet('build', 'setup', 'help')] [string] $Mode = 'build',
    [ValidateSet('windows', 'android', 'linux', 'all', '')] [string] $Target = '',
    [ValidateSet('release', 'debug', '')] [string] $Configuration = '',
    [switch] $NoPause
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'build/BuildMenu.psm1') -Force
$taskRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskName = if (Test-Path (Join-Path $taskRoot 'VersionUpdater.txt')) { 'LuaSlice' } else { 'Funkin' }
$taskExit = 0
function Select-Target([string] $Prompt, [switch] $AllowSkip) {
    Write-Host "`n$Prompt"
    Write-Host '[1] Windows  [2] Android  [3] Linux  [4] All three'
    if ($AllowSkip) { Write-Host '[0] Finish without building' }
    do {
        $selection = Read-Host 'Choose a number'
        switch ($selection) {
            '1' { return 'windows' }
            '2' { return 'android' }
            '3' { return 'linux' }
            '4' { return 'all' }
            '0' { if ($AllowSkip) { return '' } }
        }
        Write-Host 'Please choose one of the numbers above.'
    } while ($true)
}
try {
    if ($Mode -eq 'help') {
        Write-Host 'Run Setup to install the tools for your chosen platforms. Build uses installed tools.'
        Write-Host 'Targets: windows, android, linux, all. All means Windows, Android and Linux.'
        Write-Host 'Build example: powershell -File tools/Build.ps1 -Target all -Configuration release'
        Write-Host 'Linux uses Ubuntu-24.04 through WSL, with its own native project libraries.'
        Write-Host 'iOS requires macOS/Xcode; it is not a local Windows target.'
    } else {
        if (-not (Test-Path (Join-Path $taskRoot 'project.hxp')) -or -not (Test-Path (Join-Path $taskRoot 'hmm.json'))) { throw 'Keep this script in the source folder beside project.hxp and hmm.json.' }
        if (-not $Target) { $Target = Select-Target $(if ($Mode -eq 'setup') { 'Which platforms do you mainly want to build?' } else { 'What do you want to build?' }) }
        $taskTargets = @(Get-BuildTargets $Target)
        Push-Location $taskRoot
        try {
            if ($Mode -eq 'setup') {
                Write-Host 'Setup will download tools for the selected platforms. No signing keys are replaced.'
                if ($taskTargets -contains 'windows' -or $taskTargets -contains 'android') {
                    Initialize-BuildGit -Install
                    Initialize-WindowsHaxe -Install
                    $env:HAXELIB_PATH = Join-Path $taskRoot '.haxelib'
                    New-Item -ItemType Directory -Force -Path $env:HAXELIB_PATH | Out-Null
                    & haxelib path hmm *> $null
                    if ($LASTEXITCODE -ne 0) { Invoke-BuildCommand haxelib @('install', 'hmm', '3.1.0', '--always') }
                    if (Test-Path .git) { Invoke-BuildCommand git @('submodule', 'update', '--init', '--recursive') }
                    if (-not (Test-Path assets/preload)) { throw 'The official assets are missing. Download the source with its assets submodule.' }
                    Invoke-BuildCommand haxelib @('run', 'hmm', 'install')
                    foreach ($dependency in (Get-Content hmm.json -Raw | ConvertFrom-Json).dependencies) {
                        if ($dependency.type -ne 'git') { continue }
                        $library = Join-Path $env:HAXELIB_PATH ($dependency.name.Replace('.', ',') + '/git')
                        Invoke-BuildCommand git @('-C', $library, 'submodule', 'update', '--init', '--recursive')
                    }
                    Push-Location (Join-Path $env:HAXELIB_PATH 'hxcpp/git/tools/hxcpp')
                    try { Invoke-BuildCommand haxe @('compile.hxml') } finally { Pop-Location }
                }
                $taskSetupResults = @(Invoke-BuildTargets $taskTargets {
                    param($Platform)
                    switch ($Platform) {
                        'windows' {
                            Initialize-WindowsCompiler -Install
                            Invoke-ShortPathBuild $taskRoot { Invoke-BuildCommand haxelib @('run', 'lime', 'rebuild', 'windows', '-release') }
                        }
                        'android' {
                            Initialize-AndroidTools -Install
                            Invoke-ShortPathBuild $taskRoot { Invoke-BuildCommand haxelib @('run', 'lime', 'rebuild', 'android', '-release') }
                        }
                        'linux' { Invoke-LinuxBuild $taskRoot setup release $taskName }
                    }
                })
                $taskSetupResults | Format-Table Target, Success, Error -AutoSize | Out-Host
                if ($taskSetupResults.Success -contains $false) { throw 'Some setup steps failed. See the platform errors above.' }
                $Target = Select-Target 'Setup is complete. Which build would you like to make now?' -AllowSkip
                $taskTargets = if ($Target) { @(Get-BuildTargets $Target) } else { @() }
            }
            if ($taskTargets.Count -gt 0) {
                if (-not $Configuration) {
                    do { $selection = Read-Host '[1] Release (normal build)  [2] Debug' } while ($selection -notin '1', '2')
                    $Configuration = if ($selection -eq '1') { 'release' } else { 'debug' }
                }
                if (-not $env:HXCPP_COMPILE_THREADS) { $env:HXCPP_COMPILE_THREADS = [string][Math]::Max(1, [Math]::Min(8, [Environment]::ProcessorCount - 2)) }
                $taskResults = @(Invoke-BuildTargets $taskTargets {
                    param($Platform)
                    Write-Host "`nBuilding $Platform ($Configuration)..."
                    if ($Platform -eq 'linux') { Invoke-LinuxBuild $taskRoot build $Configuration $taskName; return }
                    Initialize-WindowsHaxe
                    if ($Platform -eq 'windows') { Initialize-WindowsCompiler } else { Initialize-AndroidTools }
                    Invoke-ShortPathBuild $taskRoot {
                        $arguments = @('run', 'lime', 'build', $Platform, "-$Configuration")
                        if ($Platform -eq 'windows') { $arguments += '-64' }
                        Invoke-BuildCommand haxelib $arguments
                    }
                    Write-Host "Output: $taskRoot\export\$Configuration\$Platform"
                })
                $taskResults | Format-Table Target, Success, Error -AutoSize | Out-Host
                if ($taskResults.Success -contains $false) { throw 'One or more builds failed. Successful builds are still available.' }
            }
        } finally { Pop-Location }
    }
} catch {
    Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
    $taskExit = 1
}
if (-not $NoPause -and $Mode -ne 'help') { Read-Host 'Press Enter to close' | Out-Null }
exit $taskExit
