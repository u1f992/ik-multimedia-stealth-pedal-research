[Console]::OutputEncoding = [Text.Encoding]::UTF8
"# uninstall entries"
foreach ($root in @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")) {
    Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath
        if ($p.DisplayName -like "*StealthPedal*" -or $p.DisplayName -like "*IK Multimedia*") {
            "$($p.DisplayName) | $($p.DisplayVersion) | $($p.InstallLocation) | $($p.UninstallString)"
        }
    }
}
"# executables"
foreach ($dir in @("C:\Program Files", "C:\Program Files (x86)", "C:\ProgramData", "$env:LOCALAPPDATA")) {
    Get-ChildItem -Path $dir -Recurse -Depth 4 -Filter "*StealthPedal*" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
}
"# start menu shortcuts"
Get-ChildItem -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" -Recurse -Filter "*StealthPedal*" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
"# devices"
Get-PnpDevice | Where-Object { $_.InstanceId -like "*IKStealthPedalMidi*" -or $_.FriendlyName -like "*StealthPedal*" } | ForEach-Object { "$($_.Status) $($_.Class) [$($_.FriendlyName)] $($_.InstanceId)" }
"# services"
Get-CimInstance Win32_SystemDriver | Where-Object { $_.Name -like "IKStealth*" -or $_.Name -like "USBPcap*" } | Select-Object Name, State, PathName | Format-Table -AutoSize | Out-String -Width 160
"# midi ports (winmm)"
Add-Type -Namespace Win32 -Name Midi -MemberDefinition @"
[DllImport("winmm.dll")] public static extern uint midiInGetNumDevs();
[DllImport("winmm.dll")] public static extern uint midiOutGetNumDevs();
[DllImport("winmm.dll", CharSet = CharSet.Unicode)] public static extern uint midiInGetDevCapsW(UIntPtr id, byte[] caps, uint size);
[DllImport("winmm.dll", CharSet = CharSet.Unicode)] public static extern uint midiOutGetDevCapsW(UIntPtr id, byte[] caps, uint size);
"@
$n = [Win32.Midi]::midiInGetNumDevs()
for ($i = 0; $i -lt $n; $i++) {
    $caps = New-Object byte[] 92
    [void][Win32.Midi]::midiInGetDevCapsW([UIntPtr]::new($i), $caps, 92)
    "midi in $i : " + ([Text.Encoding]::Unicode.GetString($caps, 8, 64) -replace "\0.*$", "")
}
$n = [Win32.Midi]::midiOutGetNumDevs()
for ($i = 0; $i -lt $n; $i++) {
    $caps = New-Object byte[] 92
    [void][Win32.Midi]::midiOutGetDevCapsW([UIntPtr]::new($i), $caps, 92)
    "midi out $i : " + ([Text.Encoding]::Unicode.GetString($caps, 8, 64) -replace "\0.*$", "")
}
"# processes"
Get-Process | Where-Object { $_.ProcessName -like "*StealthPedal*" -or $_.ProcessName -like "*AmpliTube*" } | Select-Object Id, ProcessName, Path | Format-Table -AutoSize | Out-String -Width 160
