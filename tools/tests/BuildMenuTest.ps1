$ErrorActionPreference = 'Stop'
$taskModule = Join-Path $PSScriptRoot '../build/BuildMenu.psm1'
if (-not (Test-Path -LiteralPath $taskModule)) { throw 'Build menu implementation is missing.' }
Import-Module $taskModule -Force
function Assert-Equal($Actual, $Expected, [string] $Name) {
    if (($Actual | ConvertTo-Json -Compress) -ne ($Expected | ConvertTo-Json -Compress)) {
        throw "$Name : expected $Expected, received $Actual"
    }
}
Assert-Equal @(Get-BuildTargets all) @('windows', 'android', 'linux') 'All includes Linux, not an unsupported local iOS build'
Assert-Equal @(Get-BuildTargets linux) @('linux') 'Linux-only setup does not request Windows or Android'
Assert-Equal @(Get-BuildTargets android) @('android') 'Android-only setup'
$taskRejected = $false
try { Get-BuildTargets ios } catch { $taskRejected = $true }
Assert-Equal $taskRejected $true 'Unsupported targets are rejected'
$taskCalls = [Collections.Generic.List[string]]::new()
$taskResults = @(Invoke-BuildTargets -Targets @('windows', 'android', 'linux') -Action {
    param($Target)
    $taskCalls.Add($Target)
    if ($Target -eq 'android') { throw 'A real build command failed.' }
})
Assert-Equal @($taskCalls.ToArray()) @('windows', 'android', 'linux') 'A failed target does not silently skip remaining targets'
Assert-Equal @($taskResults.Success) @($true, $false, $true) 'Per-platform failures survive orchestration'
Assert-Equal $taskResults[1].Error 'A real build command failed.' 'Failure text is preserved'
$taskCalls.Clear()
$taskResults = @(Invoke-BuildTargets -Targets @('linux') -Action { param($Target) $taskCalls.Add($Target) })
Assert-Equal @($taskCalls.ToArray()) @('linux') 'Only selected target executes'
Assert-Equal $taskResults[0].Success $true 'Successful command is reported'
$taskRejected = $false
try { Invoke-BuildCommand cmd @('/d', '/c', 'exit 7') } catch {
    $taskRejected = $_.Exception.Message -like '*exit code 7'
}
Assert-Equal $taskRejected $true 'Native process failures must not appear successful'
Invoke-BuildCommand cmd @('/d', '/c', 'exit 0')
Write-Output 'Build menu: 11 checks passed.'
