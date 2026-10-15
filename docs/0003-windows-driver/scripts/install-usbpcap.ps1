param([string]$Package = "C:\Program Files\USBPcap")
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$staging = "C:\IK\usbpcap"
New-Item -ItemType Directory -Force -Path $staging | Out-Null
Copy-Item (Join-Path $Package "USBPcap.inf"), (Join-Path $Package "USBPcap.sys"), (Join-Path $Package "usbpcapamd64.cat") $staging -Force
pnputil /add-driver (Join-Path $staging "USBPcap.inf") 2>&1 | Out-String
Copy-Item (Join-Path $staging "USBPcap.sys") C:\Windows\System32\drivers\USBPcap.sys -Force
sc.exe create USBPcap type= kernel start= demand error= severe binPath= System32\drivers\USBPcap.sys DisplayName= "USBPcap Capture Service" | Out-String
$classKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{36fc9e60-c465-11cf-8056-444553540000}"
$filters = @((Get-ItemProperty $classKey -ErrorAction SilentlyContinue).UpperFilters | Where-Object { $_ })
if ($filters -notcontains "USBPcap") {
    Set-ItemProperty -Path $classKey -Name UpperFilters -Value ([string[]]($filters + "USBPcap")) -Type MultiString
}
"UpperFilters: " + ((Get-ItemProperty $classKey).UpperFilters -join ",")
Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\USBPcap | Select-Object Start, Type, ErrorControl, ImagePath | Out-String
"reboot required for the class filter to attach to the root hubs"
