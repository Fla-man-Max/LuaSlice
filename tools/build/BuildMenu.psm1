Set-StrictMode -Version 2.0

function Get-BuildTargets([string] $Target) {
    switch ($Target.ToLowerInvariant()) {
        'all' { 'windows'; 'android'; 'linux' }
        { $_ -in 'windows', 'android', 'linux' } { $_ }
        default { throw "Unknown build target: $Target" }
    }
}

function Invoke-BuildTargets([string[]] $Targets, [scriptblock] $Action) {
    foreach ($target in $Targets) {
        try {
            & $Action $target | Out-Host
            [pscustomobject]@{ Target = $target; Success = $true; Error = '' }
        } catch {
            [pscustomobject]@{ Target = $target; Success = $false; Error = $_.Exception.Message }
        }
    }
}

function Invoke-BuildCommand([string] $Command, [string[]] $Arguments) {
    & $Command @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

function Add-BuildPath([string] $Path) {
    if ($Path -and (Test-Path -LiteralPath $Path -PathType Container)) { $env:PATH = "$Path;$env:PATH" }
}

function Get-BuildConfig([string] $Root) {
    $file = Join-Path $Root '.work/build-settings.json'
    if (Test-Path -LiteralPath $file) { return Get-Content -LiteralPath $file -Raw | ConvertFrom-Json }
    return [pscustomobject]@{}
}

function Get-BuildSetting($Config, [string] $Name, [string] $Default = '') {
    $property = $Config.PSObject.Properties[$Name]
    if ($null -ne $property -and $property.Value) { return [string] $property.Value }
    return $Default
}

function Receive-BuildFile([string] $Url, [string] $Destination) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $directory = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $partial = "$Destination.partial"
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $partial
    Move-Item -LiteralPath $partial -Destination $Destination -Force
}

function Initialize-WindowsHaxe([switch] $Install) {
    $cache = Join-Path $env:LOCALAPPDATA 'FNFBuildTools'
    Add-BuildPath 'C:/HaxeToolkit/neko'
    Add-BuildPath 'C:/HaxeToolkit/haxe'
    Add-BuildPath (Join-Path $cache 'neko-2.4.1-win64')
    $cachedHaxe = Get-ChildItem -Path (Join-Path $cache 'haxe-4.3.7') -Filter haxe.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cachedHaxe) { Add-BuildPath $cachedHaxe.DirectoryName }
    $haxe = Get-Command haxe -ErrorAction SilentlyContinue
    $version = if ($haxe) { & $haxe.Source --version } else { '' }
    if ($version -ne '4.3.7' -or -not (Get-Command neko -ErrorAction SilentlyContinue)) {
        if (-not $Install) { throw 'Haxe 4.3.7 and Neko are needed. Run Setup first.' }
        Receive-BuildFile 'https://github.com/HaxeFoundation/haxe/releases/download/4.3.7/haxe-4.3.7-win64.zip' (Join-Path $cache 'haxe.zip')
        Receive-BuildFile 'https://github.com/HaxeFoundation/neko/releases/download/v2-4-1/neko-2.4.1-win64.zip' (Join-Path $cache 'neko.zip')
        Expand-Archive -LiteralPath (Join-Path $cache 'haxe.zip') -DestinationPath (Join-Path $cache 'haxe-4.3.7') -Force
        Expand-Archive -LiteralPath (Join-Path $cache 'neko.zip') -DestinationPath $cache -Force
        $haxeExe = Get-ChildItem -LiteralPath (Join-Path $cache 'haxe-4.3.7') -Filter haxe.exe -Recurse | Select-Object -First 1
        if (-not $haxeExe) { throw 'Haxe archive did not contain haxe.exe.' }
        Add-BuildPath $haxeExe.DirectoryName
        Add-BuildPath (Join-Path $cache 'neko-2.4.1-win64')
    }
    $haxeDirectory = Split-Path -Parent (Get-Command haxe -ErrorAction Stop).Source
    $env:HAXEPATH = $haxeDirectory
    $env:HAXE_STD_PATH = Join-Path $haxeDirectory 'std'
    if ((& haxe --version) -ne '4.3.7') { throw 'The selected Haxe version is not 4.3.7.' }
}

function Initialize-BuildGit([switch] $Install) {
    Add-BuildPath (Join-Path $env:ProgramFiles 'Git/cmd')
    if (Get-Command git -ErrorAction SilentlyContinue) { return }
    if (-not $Install) { throw 'Git is missing. Run Setup first.' }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'Install Git for Windows, then run Setup again.' }
    Invoke-BuildCommand winget @('install', '--exact', '--id', 'Git.Git', '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements')
    Add-BuildPath (Join-Path $env:ProgramFiles 'Git/cmd')
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git is not on PATH. Reopen Setup after its installer finishes.' }
}

function Initialize-WindowsCompiler([switch] $Install) {
    if ($env:VSINSTALLDIR -and (Test-Path (Join-Path $env:VSINSTALLDIR 'VC/Auxiliary/Build/vcvars64.bat'))) { return }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $installation = if (Test-Path -LiteralPath $vswhere) { & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath }
    if (-not $installation) {
        if (-not $Install) { throw 'Windows C++ tools are missing. Run Setup and choose Windows.' }
        Invoke-BuildCommand winget @('install', '--exact', '--id', 'Microsoft.VisualStudio.2022.BuildTools', '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements', '--force', '--override', '--wait --passive --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
        $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    }
    if (-not $installation) { throw 'C++ tools are not ready. Restart Windows if the installer requested it, then run Setup again.' }
    $env:VSINSTALLDIR = "$installation\"
}

function Initialize-AndroidTools([switch] $Install) {
    $cache = Join-Path $env:LOCALAPPDATA 'FNFBuildTools'
    $sdk = $env:ANDROID_SDK_ROOT
    if (-not $sdk) { $sdk = $env:ANDROID_HOME }
    if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android/Sdk' }
    if (-not $env:JAVA_HOME -or -not (Test-Path (Join-Path $env:JAVA_HOME 'bin/javac.exe'))) {
        $java = Get-ChildItem -Path (Join-Path $cache 'jdk-*'), (Join-Path $env:LOCALAPPDATA 'LuaSliceBuildTools/jdk-*') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'jdk-17*' } | Select-Object -First 1
        if (-not $java) {
            if (-not $Install) { throw 'JDK 17 is missing. Run Setup and choose Android.' }
            Receive-BuildFile 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse' (Join-Path $cache 'jdk17.zip')
            Expand-Archive -LiteralPath (Join-Path $cache 'jdk17.zip') -DestinationPath $cache -Force
            $java = Get-ChildItem -LiteralPath $cache -Directory -Filter 'jdk-17*' | Select-Object -First 1
        }
        if (-not $java) { throw 'The JDK archive could not be located after extraction.' }
        $env:JAVA_HOME = $java.FullName
    }
    Add-BuildPath (Join-Path $env:JAVA_HOME 'bin')
    $env:ANDROID_HOME = $sdk
    $env:ANDROID_SDK_ROOT = $sdk
    $env:ANDROID_SDK = $sdk
    $env:ANDROID_NDK_ROOT = Join-Path $sdk 'ndk/29.0.13113456'
    if ($Install) {
        $sdkManager = Join-Path $sdk 'cmdline-tools/latest/bin/sdkmanager.bat'
        if (-not (Test-Path -LiteralPath $sdkManager)) {
            Receive-BuildFile 'https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip' (Join-Path $cache 'commandline-tools.zip')
            $extract = Join-Path $cache ('sdk-extract-' + [Guid]::NewGuid().ToString('N'))
            Expand-Archive -LiteralPath (Join-Path $cache 'commandline-tools.zip') -DestinationPath $extract
            New-Item -ItemType Directory -Force -Path (Join-Path $sdk 'cmdline-tools/latest') | Out-Null
            Get-ChildItem -LiteralPath (Join-Path $extract 'cmdline-tools') | Copy-Item -Destination (Join-Path $sdk 'cmdline-tools/latest') -Recurse -Force
        }
        Write-Host 'Read and accept the Android SDK licenses below to install the SDK and NDK.'
        Invoke-BuildCommand $sdkManager @("--sdk_root=$sdk", '--licenses')
        Invoke-BuildCommand $sdkManager @("--sdk_root=$sdk", 'platform-tools', 'platforms;android-35', 'build-tools;35.0.0', 'ndk;29.0.13113456')
    }
    foreach ($path in @('platforms/android-35/android.jar', 'build-tools/35.0.0/aapt.exe', 'ndk/29.0.13113456/source.properties')) {
        if (-not (Test-Path -LiteralPath (Join-Path $sdk $path))) { throw "Missing Android component $path. Run Setup and choose Android." }
    }
    $env:ANDROID_GRADLE_TASK = 'assembleRelease'
    $env:ANDROID_SETUP = 'true'
}

function Invoke-ShortPathBuild([string] $Root, [scriptblock] $Action) {
    $drive = $null
    foreach ($letter in 'LMNOPQRSTUVWXYZ'.ToCharArray()) {
        if (Test-Path "${letter}:\") { continue }
        & subst "${letter}:" $Root
        if ($LASTEXITCODE -eq 0) { $drive = "${letter}:"; break }
    }
    if (-not $drive) { throw 'Could not reserve a short build path. Free a drive letter and retry.' }
    Push-Location "$drive\"
    try {
        $env:HAXELIB_PATH = "$drive\.haxelib"
        & $Action
    } finally {
        Pop-Location
        & subst $drive /d | Out-Null
    }
}

function Invoke-LinuxBuild([string] $Root, [string] $Mode, [string] $Configuration, [string] $GameName) {
    $config = Get-BuildConfig $Root
    $distribution = Get-BuildSetting $config 'LinuxDistribution' 'Ubuntu-24.04'
    $buildRoot = Get-BuildSetting $config 'LinuxBuildRoot' '-'
    $toolRoot = Get-BuildSetting $config 'LinuxToolRoot' '-'
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) { throw 'WSL is unavailable. Install WSL on Windows 10/11, restart, and run Setup again.' }
    & wsl -d $distribution --exec true 2>$null
    if ($LASTEXITCODE -ne 0) {
        if ($Mode -ne 'setup') { throw "WSL $distribution is not ready. Run Setup and choose Linux." }
        Write-Host 'Installing Ubuntu for Linux builds. Windows may request administrator approval.'
        & wsl --install -d $distribution --no-launch
        throw 'Finish the WSL installation and restart if Windows asks. Open Ubuntu once to create a Linux user, then run Setup again. This script will not restart Windows.'
    }
    $sourcePath = (& wsl -d $distribution --exec wslpath -u $Root | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $sourcePath) { throw 'Could not translate the source folder for WSL.' }
    Invoke-BuildCommand wsl @('-d', $distribution, '--exec', 'bash', "$sourcePath/tools/build/Linux.sh", $Mode, $sourcePath, $Configuration, $GameName, $buildRoot, $toolRoot)
}

Export-ModuleMember -Function *
