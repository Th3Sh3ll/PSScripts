<#
    Use this after a cluster event in Hyper-V and you need to check the VM state after recovery.
    This will get all VMs on each node in the cluster and do a simple cim query, if results return then
    its assumed the vm is online and responding.
#>

$clusterName = Get-Cluster -Name '' # Use to query a cluster and get all nodes.
$clusterNodes   = Get-ClusterNode -Cluster $clusterName # or put in a single host name that you would like to check
$offlineServers = @()
$onlineServers  = @()
$toBeCheckedManually = @()

foreach ($clusterNode in $clusterNodes) {
    write-host "`nGetting VM list from Host: $($clusterNode)"
    try {
        $serversToBeChecked = Get-VM -ComputerName $clusterNode -ErrorAction Stop
        Write-Host "Servers found $($serversToBeChecked.count)"
        write-host "Servers Offline: $(($serversToBeChecked | ? {$_.State -ne "Running"}).count )"        
        write-host "Servers Online: $(($serversToBeChecked | ? {$_.State -eq "Running"}).count )"

        $serversToBeChecked | % {if ($_.State -ne "Running") {$offlineServers += [pscustomobject] @{Server = $server.Name; Host = $server.ComputerName}}}

        foreach ($server in $($serversToBeChecked | ? {$_.State -eq "Running"})) {
            try {
                $state = Get-CimInstance -ClassName Win32_OperatingSystem -Property * -ComputerName $server.name -ErrorAction Stop
                Write-Host "$($server.name) - Online" -ForegroundColor Green
                Write-Host "$($server.name) - UpTime: $(New-TimeSpan -Start $state.LastBootUpTime -End $(get-date) | select days,hours,minutes,seconds)"
            } catch {
                write-host "$($server.name) is in a $($server.state) state but unable to connect." -ForegroundColor Yellow
                write-host "ERROR: $($Error[0].exception.message)" -ForegroundColor Red
                $toBeCheckedManually += [pscustomobject] @{Server = $server.Name; Host = $server.ComputerName}
            }
        }
    } catch {
        Write-Host "Error occured looking for servers on host: $($clusterNode)" -ForegroundColor Yellow
        Write-Host "ERROR: $($Error[0].exception.message)" -ForegroundColor Red
    }
}

write-host "`nOffline Servers: $($offlineServers.count)"
$offlineServers | ft -AutoSize
Write-Host "`nServers that need to be manually checked: $($toBeCheckedManually.count)"
$toBeCheckedManually | ft -AutoSize