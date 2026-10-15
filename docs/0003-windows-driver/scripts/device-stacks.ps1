param([string[]]$Patterns = @("USB\VID_1963*", "USB\VID_0627*", "USB\ROOT_HUB30*"))
[Console]::OutputEncoding = [Text.Encoding]::UTF8
foreach ($pattern in $Patterns) {
    foreach ($d in (Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like $pattern })) {
        $text = pnputil /enum-devices /instanceid $d.InstanceId /stack 2>&1 | Out-String
        $stack = ($text -split "`r?`n" | Where-Object { $_ -match "^(Stack:|\s{20,}\S)" } | ForEach-Object { $_.Trim() -replace "^Stack:\s*", "" }) -join " > "
        "$($d.InstanceId) [$($d.FriendlyName)] stack: $stack"
    }
}
