param(
    [int]$Index = 2,
    [string]$Out = "C:\IK\capture.pcap",
    [int]$Seconds = 10,
    [switch]$RestartPedal,
    [switch]$DisableEnable,
    [string]$Run = "",
    [string]$StartProcess = "",
    [int]$ProcessSeconds = 6
)
$exe = "C:\Program Files\USBPcap\USBPcapCMD.exe"
$dev = "\\.\USBPcap$Index"
$pedal = "USB\VID_1963&PID_0003\6&2684214c&0&3"
Remove-Item $Out -ErrorAction SilentlyContinue
$arguments = @("-d", $dev, "-o", $Out, "-s", "65535", "-A", "--inject-descriptors")
$log = $Out + ".usbpcapcmd.log"
$errlog = $Out + ".usbpcapcmd.err"
$p = Start-Process -FilePath $exe -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $errlog
Start-Sleep 3
if ($RestartPedal) {
    $r = & pnputil /restart-device $pedal 2>&1 | Out-String
    Write-Output ("restart: " + ($r -replace "\s+", " ").Trim())
}
if ($DisableEnable) {
    $r = & pnputil /disable-device $pedal 2>&1 | Out-String
    Write-Output ("disable: " + ($r -replace "\s+", " ").Trim())
    Start-Sleep 3
    $r = & pnputil /enable-device $pedal 2>&1 | Out-String
    Write-Output ("enable: " + ($r -replace "\s+", " ").Trim())
}
if ($Run -ne "") {
    $r = Invoke-Expression $Run 2>&1 | Out-String
    Write-Output ("run: " + ($r -replace "\s+", " ").Trim())
}
if ($StartProcess -ne "") {
    $child = Start-Process -FilePath $StartProcess -PassThru
    Write-Output ("started " + $StartProcess + " pid=" + $child.Id)
    Start-Sleep $ProcessSeconds
    Stop-Process -Id $child.Id -Force -ErrorAction SilentlyContinue
    Write-Output ("stopped pid=" + $child.Id)
}
Start-Sleep $Seconds
& taskkill /PID $p.Id | Out-Null
Start-Sleep 3
if (-not $p.HasExited) {
    Write-Output "graceful stop failed; forcing"
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
}
Start-Sleep 1
$f = Get-Item $Out -ErrorAction SilentlyContinue
Write-Output ("device=" + $dev + " out=" + $Out + " size=" + $(if ($f) { $f.Length } else { "missing" }))
Write-Output ("usbpcapcmd stdout: " + ((Get-Content $log -ErrorAction SilentlyContinue) -join " | "))
Write-Output ("usbpcapcmd stderr: " + ((Get-Content $errlog -ErrorAction SilentlyContinue) -join " | "))
