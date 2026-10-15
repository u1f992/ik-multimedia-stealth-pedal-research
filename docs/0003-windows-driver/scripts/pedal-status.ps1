[Console]::OutputEncoding = [Text.Encoding]::UTF8
Get-CimInstance Win32_SystemDriver | Where-Object { $_.Name -like "USBPcap*" -or $_.Name -like "IKStealth*" } | Select-Object Name, State | Format-Table -AutoSize | Out-String -Width 120
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like "USB\VID_1963*" -or $_.InstanceId -like "HID\VID_1963*" } | ForEach-Object {
    $d = Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_DriverInfPath, DEVPKEY_Device_Service, DEVPKEY_Device_ProblemCode -ErrorAction SilentlyContinue
    "$($_.Status) $($_.Class) [$($_.FriendlyName)] $($_.InstanceId) :: " + (($d | ForEach-Object { $_.Data }) -join " / ")
}
Get-PnpDevice -Class USB -PresentOnly | Where-Object { $_.FriendlyName -like "*Root Hub*" } | ForEach-Object {
    "root hub: $($_.FriendlyName) [$($_.InstanceId)]"
    pnputil /enum-devices /instanceid $_.InstanceId /stack 2>&1 | Out-String
}
pnputil /enum-devices /instanceid "USB\VID_1963&PID_0003\6&2684214c&0&3" /stack 2>&1 | Out-String
foreach ($i in 1..4) {
    $n = "\\.\USBPcap$i"
    try {
        $h = [System.IO.File]::Open($n, "Open", "ReadWrite", "None")
        $h.Close()
        "$n open OK"
    } catch {
        "$n : " + $_.Exception.InnerException.Message
    }
}
