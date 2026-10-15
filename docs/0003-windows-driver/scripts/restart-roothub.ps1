param([string]$ChildPattern = "USB\VID_1963*")
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$pedal = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like $ChildPattern } | Select-Object -First 1
"child: " + $pedal.InstanceId
$parent = (Get-PnpDeviceProperty -InstanceId $pedal.InstanceId -KeyName DEVPKEY_Device_Parent).Data
"parent: " + $parent
pnputil /restart-device $parent 2>&1 | Out-String
Start-Sleep 5
pnputil /enum-devices /instanceid $parent /stack 2>&1 | Out-String
$pedal = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like "USB\VID_1963*" } | Select-Object -First 1
pnputil /enum-devices /instanceid $pedal.InstanceId /stack 2>&1 | Out-String
