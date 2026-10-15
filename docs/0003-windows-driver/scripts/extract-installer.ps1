param(
    [string]$Installer = "C:\IK\zip\StealthPedal Windows Drivers 1.1.0.8 64bit\Install StealthPedal Drivers 1.1.0.8 64bit.exe"
)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$before = Get-ChildItem $env:TEMP -Directory | Where-Object { $_.Name -like "{*}" } | Select-Object -ExpandProperty Name
$p = Start-Process -FilePath $Installer -ArgumentList '/b"C:\IK\cache"' -PassThru
Start-Sleep 25
Get-ChildItem $env:TEMP -Directory | Where-Object { $_.Name -like "{*}" -and $before -notcontains $_.Name } | ForEach-Object {
    $_.FullName
    Get-ChildItem -Recurse $_.FullName | Select-Object FullName, Length | Format-Table -AutoSize | Out-String -Width 220
}
Get-Process | Where-Object { $_.Id -eq $p.Id } | Stop-Process -Force -ErrorAction SilentlyContinue
