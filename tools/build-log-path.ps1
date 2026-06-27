param(
  [Parameter(Mandatory=$true)][string]$Platform,
  [string]$Label = ""
)

$root = Split-Path -Parent $PSScriptRoot
$platformName = $Platform.ToLowerInvariant()
$dir = Join-Path $root "BuildLogs\$platformName"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$stamp = Get-Date -Format 'yyyy-MM-dd-HH-mm-ss'
$suffix = ""
if (-not [string]::IsNullOrWhiteSpace($Label)) {
  $safeLabel = ($Label.ToLowerInvariant() -replace '[^a-z0-9_-]+', '-').Trim('-')
  if ($safeLabel.Length -gt 0) { $suffix = "-$safeLabel" }
}

$baseName = "log-$($platformName)build-$stamp$suffix"
$path = Join-Path $dir "$baseName.txt"
$index = 2

while (Test-Path -LiteralPath $path) {
  $path = Join-Path $dir "$baseName($index).txt"
  $index++
}

Write-Output $path
