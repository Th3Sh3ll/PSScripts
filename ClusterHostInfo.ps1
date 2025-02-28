<#
    Use this script to compare your hosts with each other in clusters, this can be used to make sure they are aligned 
    Checks:
        OS
        CPU arch
        Socket count
        Securty and Windows update levels
        Migration Details.
#>

function check-CPUDuplicate ($cpu) {
    $CompareTo = @()
    $difference= @()
    foreach ($proc in $cpu) {
        $CompareTo += $proc.name
        if ($CompareTo.count -gt 1) {
            if ($CompareTo -eq $proc.name) {
                return $CompareTo[0].replace('  ','')
            } else {
                $difference += $proc.name
            }
        }
    }
    return $difference
}

$clusterNameToCheck = @(
    "ClusterOne",
    "ClusterTwo"
)

$AllNodesInCluster = @() 
foreach ($cluster in $clusterNameToCheck) {
    write-host "Getting nodes from cluster: $($cluster)"
    $AllNodesInCluster += (Get-ClusterNode -Cluster $cluster).name
}

write-host "Nodes that will be checked:" -ForegroundColor Green
$AllNodesInCluster | % {write-host $_}

$nodeInformationOutput = @()
foreach ($Node in $AllNodes) {
    write-host "`nBusy with $($Node)"
    write-host "$($Node) | Getting OS information"
    $osInfo  = Get-WmiObject win32_operatingsystem -ComputerName $Node
    
    write-host "$($Node) | Getting CPU information"
    $cpuInfo = Get-WmiObject Win32_Processor -ComputerName $Node
    
    write-host "$($Node) | Getting Hotfix information"
    $hotfix  = Get-HotFix -ComputerName $Node

    write-host "$($Node) | Getting VM host information"
    $vmHost  = Get-VMHost -ComputerName $Node
    
    $nodeInformationOutput += [pscustomobject]@{
        Host               = $Node;
        OS                 = $osInfo.caption.Replace('Microsoft Windows Server ','');
        OSVersion          = $osInfo.version;
        OSBuild            = $osInfo.buildnumber;
        Sockets            = $cpuInfo.count;
        CPUName            = if ($cpuInfo.count -gt 1) {check-CPUDuplicate -cpu $cpuInfo} else {$cpuInfo.name};
        KBInstalled        = ($hotfix | ? {$_.description -eq 'update'} | Measure-Object hotfixid).count;
        SKBInstalled       = ($hotfix | ? {$_.description -ne 'update'} | Measure-Object hotfixid).count;
        LastKBInstalled    = ($hotfix | sort installedon -Descending)[0].installedon;
        VMMigrationAuth    = $vmHost.VirtualMachineMigrationAuthenticationType;
        VMMigrationEnabled = $vmHost.VirtualMachineMigrationEnabled;
        VMMigrationPerform = $vmHost.VirtualMachineMigrationPerformanceOption;
        AnyNetworkUsed     = $vmHost.UseAnyNetworkForMigration;
        IovSupport         = $vmHost.IovSupport
    }
}

$nodeInformationOutput | ft -AutoSize
$nodeInformationOutput | Export-Csv -Path 'C:\temp\ClusterHostInfo.csv' -Delimiter ';' -NoTypeInformation