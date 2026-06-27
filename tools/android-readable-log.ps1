param(
  [string]$Package = "me.luaslice",
  [string]$Activity = "me.luaslice/.MainActivity",
  [int]$Seconds = 25,
  [switch]$Launch
)

$ErrorActionPreference = "Stop"
$adb = "C:\Android\sdk\platform-tools\adb.exe"
$logDir = Join-Path (Get-Location) "BuildLogs\android"
$rawPath = Join-Path $logDir "android-raw-latest.log"
$readablePath = Join-Path $logDir "android-readable-latest.log"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

if ($Launch) {
  & $adb logcat -c | Out-Null
  & $adb shell am force-stop $Package | Out-Null
  & $adb shell am start -n $Activity | Out-Null
  Start-Sleep -Seconds $Seconds
}

& $adb logcat -d -v time -t 12000 | Set-Content -Encoding UTF8 $rawPath
$raw = Get-Content $rawPath | Where-Object {
  $_ -notmatch "android\.hardware\.audio.*pcmWrite" -and
  $_ -notmatch "pcm_writei failed with 'cannot read/write stream data"
}

$currentPid = (& $adb shell pidof $Package) -join " "
$pidMatches = $raw | Select-String -Pattern "Start proc ([0-9]+):$([regex]::Escape($Package))" |
  ForEach-Object { $_.Matches.Groups[1].Value }
$pids = @($currentPid -split "\s+" | Where-Object { $_ }) + $pidMatches
$pids = $pids | Select-Object -Unique

$pidPattern = if ($pids.Count -gt 0) { "\((" + (($pids | ForEach-Object { [regex]::Escape($_) }) -join "|") + ")\)" } else { $null }
$packagePattern = [regex]::Escape($Package)

$appLines = $raw | Where-Object {
  ($_ -match $packagePattern) -or
  ($pidPattern -and $_ -match $pidPattern) -or
  ($_ -match "LuaSlice|HXCPP|AndroidRuntime|libApplicationMain|liblime") -or
  ($_ -match "\s(SDL|Exception|lime|openfl)\s*\(")
}

$lifecycle = $appLines | Where-Object {
  $_ -match "START u0|Start proc|Running main function|nativeRunMain|Finished main function|onCreate\(\)|onStart\(\)|onResume\(\)|onPause\(\)|onStop\(\)|onDestroy\(\)|surfaceCreated|surfaceDestroyed|WindowStopped|force-stop|ActivityRecord"
}

$errors = $appLines | Where-Object {
  ($_ -match "FATAL EXCEPTION|AndroidRuntime| E/(me\.luaslice|HXCPP|Exception|SDL|lime|openfl)|Could not find primitive|does not have signature|UnsatisfiedLinkError|NoSuchMethod|JNI DETECTED|SIGSEGV|SIGABRT|Fatal signal|Abort message|OutOfMemory|ANR|Killing .*me\.luaslice") -or
  (($pidPattern -and $_ -match $pidPattern) -and ($_ -match "E/|Called from|Null Object Reference|Exception|Error|trace"))
}

$notes = @()
if (($appLines -match "Finished main function").Count -gt 0) {
  $notes += "Native main returned. If this happens before Main.hx starts, check # Error/s for Lime/HXCPP boot failures."
}
if (($errors -match "does not have signature|Could not find primitive").Count -gt 0) {
  $notes += "Lime CFFI mismatch detected. Android native liblime.so is missing a primitive that Haxe tried to load."
}
if ($notes.Count -eq 0) {
  $notes += "None"
}

$out = @()
$out += "# Info"
$out += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$out += "Package: $Package"
$out += "Activity: $Activity"
$out += "Current PID: $(if ($currentPid) { $currentPid } else { 'not running' })"
$out += "Raw log: $rawPath"
$out += ""
$out += "# Lifecycle"
$out += $(if ($lifecycle.Count -gt 0) { $lifecycle } else { "None" })
$out += ""
$out += "# Error/s"
$out += $(if ($errors.Count -gt 0) { $errors } else { "None" })
$out += ""
$out += "# Notes"
$out += $notes

$out | Set-Content -Encoding UTF8 $readablePath
Write-Output "Wrote $readablePath"
