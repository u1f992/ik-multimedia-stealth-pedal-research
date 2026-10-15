param([string]$Inf = "C:\IK\Driver\IKStealthPedalLL.inf")
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$catalog = Join-Path (Split-Path $Inf) "IKStealthPedalLL.cat"
$signature = Get-AuthenticodeSignature $catalog
"catalog: " + $signature.Status + " signer: " + $signature.SignerCertificate.Subject
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPublisher", "LocalMachine")
$store.Open("ReadWrite")
$store.Add($signature.SignerCertificate)
$store.Close()
pnputil /add-driver $Inf /install 2>&1 | Out-String
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like "USB\VID_1963*" -or $_.InstanceId -like "HID\VID_1963*" } | ForEach-Object {
    $d = Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_DriverInfPath, DEVPKEY_Device_Service, DEVPKEY_Device_ProblemCode -ErrorAction SilentlyContinue
    "$($_.Status) $($_.Class) [$($_.FriendlyName)] $($_.InstanceId) :: " + (($d | ForEach-Object { $_.Data }) -join " / ")
}
Get-CimInstance Win32_SystemDriver | Where-Object { $_.Name -like "IK*" } | Select-Object Name, State, PathName | Out-String
Get-WinEvent -LogName Microsoft-Windows-CodeIntegrity/Operational -MaxEvents 3 -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id, Message | Format-List | Out-String -Width 160
