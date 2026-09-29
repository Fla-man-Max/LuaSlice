$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskDestination = Join-Path ([Environment]::GetFolderPath('Desktop')) 'LuaSlice Source Code'
if (-not (Test-Path -LiteralPath (Join-Path $taskSource 'VersionUpdater.txt'))) { throw 'Not a LuaSlice source folder.' }
if ($taskSource -eq $taskDestination) { throw 'Source and destination must differ.' }
New-Item -ItemType Directory -Force -Path $taskDestination | Out-Null
foreach ($taskFolder in @('source', 'assets', 'art', 'docs', 'licenses', 'changelogs', 'example_mods', 'build', 'other', 'scripts', 'templates', 'tools')) {
    $taskFrom = Join-Path $taskSource $taskFolder
    if (-not (Test-Path -LiteralPath $taskFrom)) { continue }
    & robocopy $taskFrom (Join-Path $taskDestination $taskFolder) /E /XJ /R:1 /W:1 /XD .git __pycache__ /XF .git .env *.keystore *.jks signing.properties /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -ge 8) { throw "Source sync failed: $taskFolder" }
}
foreach ($taskFile in Get-ChildItem -LiteralPath $taskSource -File -Force) {
    if ($taskFile.Name -in @('.env', 'signing.properties')) { continue }
    if ($taskFile.Extension -in @('.md', '.json', '.hxp', '.bat', '.ps1', '.sh', '.plist', '.storyboard', '.js') -or $taskFile.Name -in @('VersionUpdater.txt', '.gitignore', '.gitmodules', '.gitattributes', '.editorconfig', '.prettierignore')) {
        Copy-Item -LiteralPath $taskFile.FullName -Destination (Join-Path $taskDestination $taskFile.Name) -Force
    }
}
foreach ($taskFile in Get-ChildItem -LiteralPath (Join-Path $taskSource 'source') -File -Recurse) {
    $taskRelative = $taskFile.FullName.Substring($taskSource.TrimEnd('\', '/').Length).TrimStart('\', '/')
    if ((Get-FileHash -LiteralPath $taskFile.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $taskDestination $taskRelative)).Hash) {
        throw "Source sync mismatch: $taskRelative"
    }
}
Write-Output "Synced and verified: $taskDestination"
