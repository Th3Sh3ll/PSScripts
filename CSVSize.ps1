<#
    This will get all the cluster shared volumes in a cluster 
    Build the volume paths 
    get the size of the disk in each folder in the path that was built.
    Export to CSV with lastwrite timestamp.
#>

$clusterVolumes = Get-ClusterSharedVolume -cluster "" # cluster name that you want to get all disk sizes for.

# build path to query
$volumePaths = @()
$sizeOfFolderInVolumes = @()

foreach ($volume in $clusterVolumes) {
    $pathName = "\\$($volume.OwnerNode)\$($volume.SharedVolumeInfo.FriendlyVolumeName.Replace('C:\','c$\'))"
    $volumePaths += $pathName
}

foreach ($path in $volumePaths) {
    $folderInVolume = Get-ChildItem -Path $path
    foreach ($folder in $folderInVolume) {
        $disks = Get-ChildItem -Path $folder.FullName -Recurse -file | ?{$_.Extension -eq '.vhdx'}
        $buildData = [PSCustomObject] @{
            Volume = $folder.Parent;
            Folder = $folder.name;
            Size   = [math]::Round((Get-ChildItem -Path $folder.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum /1GB, 2);
            Disk   = foreach ($disk in $disks.Name){$disk};
            LastWrite = foreach ($time in $disks.LastWriteTime) {$time}
        }
        $sizeOfFolderInVolumes += $buildData
    }
}
$expandData = $sizeOfFolderInVolumes | select Volume, Folder, Size, @{Name='Disk';Expression={($_.disk -join ',')}}, @{Name='LastWrite';Expression={($_.LastWrite -join ',')}}
$expandData | Export-Csv -Path "C:\Temp\name.csv" -Delimiter ',' -NoTypeInformation -Force