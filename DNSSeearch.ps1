$DNSServerToCheck = ''
$zoneName = ''
$hostname = ''
$hostIPad = ''


try {
    if (!$hostname) {
        Write-Host "No hostname provided, searching on IP" -ForegroundColor Yellow
        $IPResult = Get-DnsServerZone -Name $zoneName -ComputerName $DNSServerToCheck -ErrorAction Stop | Get-DnsServerResourceRecord -Type 1 -ErrorAction Stop | ? {$_.RecordData.IPv4Address.IPAddressToString -eq $hostIPad}
        write-host "Record found and matched on IPAddress: $($hostIPad)" -ForegroundColor Green
        Write-Output $IPResult
    } else {
        $Result = Get-DnsServerZone -Name $zoneName -ComputerName $DNSServerToCheck -ErrorAction Stop | Get-DnsServerResourceRecord -Type 1 -ErrorAction Stop | ? {$_.hostname -match $hostname} 
        if ($Result) {
            Write-Host "Record found and matched on Hostname: $($hostname)" -ForegroundColor Green
            Write-Output $Result
        } else {
            write-host "Nothing found on hostname: $($hostname), looking for a match on IP: $($hostIPad)" -ForegroundColor Yellow
            try{
                $IPResult = Get-DnsServerZone -Name $zoneName -ComputerName $DNSServerToCheck -ErrorAction Stop | Get-DnsServerResourceRecord -Type 1 -ErrorAction Stop | ? {$_.RecordData.IPv4Address.IPAddressToString -eq $hostIPad}
                if ($IPResult) {
                    write-host "Record found and matched on IPAddress: $($hostIPad)" -ForegroundColor Green
                    Write-Output $IPResult
                } else {
                    write-host "Nothing found on IPAddress: $($hostIPad)" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Error occured: $($Error[0].Exception.Message)"
            }        
        }
    }
} catch {
    Write-Host "Error occured: $($Error[0].Exception.Message)"
}
