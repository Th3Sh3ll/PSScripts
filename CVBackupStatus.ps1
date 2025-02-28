<#
    This i built to get information from commvault and compare that to virtual machines in a hyper-v cluster
    The script gets all the virtual machines being backed up
    then gets all the virtual machines from the cluster
    Does the comparrison and then prints out what is not backed up.

    this is because commvault (at the time of writing this) never had a report to show me what is not backed up
    from cluster level.
#>


function auth-commvaultServer ($creds, $server) {
    try {
        Connect-CVServer -Server $cServer -User $creds.UserName -Password $creds.Password -ErrorAction Stop
        return "Connected"
    } catch {
        return "Connection failed, $($Error[0])"
    }    
}

$cUser   = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String("$($env:CU)"))
$cPassB64= [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String("$($env:CP)"))
$cPass   = $cPassB64 | ConvertTo-SecureString -AsPlainText -Force
$creds = [System.Management.Automation.PSCredential]::new($cUser, $cPass)

# byPass IE setup as module doesnt include parameter -usebasicparsing
$keyPath = 'Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Internet Explorer\Main'
if (!(Test-Path $keyPath)) { New-Item $keyPath -Force | Out-Null }
Set-ItemProperty -Path $keyPath -Name "DisableFirstRunCustomize" -Value 1 -ErrorAction SilentlyContinue


$cServer = "COMMVAULTSERVER"
auth-commvaultServer -creds $creds -server $cServer 

$comVaultVMs = Get-CVVirtualMachine 

$clusters = @(
    "ClusterName"
)

$virtualMachines = @()
foreach ($cluster in $clusters) {
    write-host "Getting nodes from cluster: $($cluster)"
    $clusterNodes = (get-cluster $cluster | Get-ClusterNode).name
    foreach ($clusterNode in $clusterNodes) {
        write-host "Getting virtual machines from cluster node: $($clusterNode)"
        $virtualMachines += Get-VM -ComputerName $clusterNode
    }
    write-host "Found $($virtualMachines.count) virtual machines on $($cluster)"
}


$virtualMachinesBackedUp    = @()
$virtualMachinesNOTBackedUp = @()
$convertedListFromCV = ($comVaultVMs).name
$convertedListFromHV = ($virtualMachines).name
foreach ($vm in $convertedListFromHV) {
    if ($convertedListFromCV -contains $vm) {
        write-host "$($vm) matched" -ForegroundColor Green
        $virtualMachinesBackedUp += $vm
    } else {
        write-host "$($vm) NOT matched"
        $virtualMachinesNOTBackedUp += $virtualMachines | ? {$_.name -eq $vm}
    }
}

write-host "VMs not backed up: $($virtualMachinesNOTBackedUp.count)"
$virtualMachinesNOTBackedUp | ft name,state,computername -AutoSize