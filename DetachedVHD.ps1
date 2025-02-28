<#
    Look at all VHD disks to see if there are any disks that are not attached.
    This usually means the server is off or the disk is not attached to any virtual machine.
#>

$clusterName = ''

$clusterNodes = (Get-ClusterNode -Cluster $clusterName).name
$clusterVolumes = Get-ChildItem -Path "\\$($clusterNodes[0])\c$\ClusterStorage"
$clusterVMs = Get-ClusterGroup -Cluster $clusterName

$replicas = $clusterVMs | ?{$_.Name -match 'replica'}

write-host "Cluster nodes and virtual machines stats gathered, Script will start scanning disks"

$diskDetailsArray = @()
#reset counters
$progressCount = 0
foreach ($volume in $clusterVolumes) {
    write-host "Getting disks from volume: $($volume)"
    $vhdDisk = Get-ChildItem -Path $($volume.FullName -replace("C:\\", "\\$($clusternodes[0])\c$\")) -Recurse | ? {$_.Extension -match 'VHD'}
    $progressCount +=1
    Write-Progress -Activity "Searching $volume" -Status "$($progressCount) out of $($clusterVolumes.count) Volumes" -PercentComplete $([math]::Round($progressCount/$clusterVolumes.count*100, 1)) -Id 1
    #rest count for each disk check in volume
    $diskCheckProgress = 0
    foreach ($disk in $vhddisk) {
        $diskCheckProgress += 1
        write-host "`ncount at $($diskCheckProgress)"
        Write-Progress -Activity "Checking $($disk.Name)" -Status "Disk $($diskCheckProgress) out of $($vhdDisk.count)" -PercentComplete $([math]::Round($diskCheckProgress/$vhdDisk.count*100, 1)) -Id 2 -ParentId 1
        write-host "Checking Path: $($disk.FullName -replace("\\\\$($clusternodes[0])\\c\$", "C:"))"        
        write-host "Checking if path is for a replica"
        if ($replicas -match $($disk.Directory.Name) -or $disk.FullName -match 'replica') {
            write-host "Disk: $($disk.FullName) matched to a replica, will ignore." -ForegroundColor Green
            #$diskCheckProgress -1
            continue
        }
        $diskFullName = $($disk.FullName -replace("\\\\$($clusternodes[0])\\c\$", "C:"))
        do {
            $passed = 0
            try {
                $diskAttachedCheck = Get-VHD -Path $diskFullName -ErrorAction Stop
                $passed = 1
                Write-Host "First check: Passed." -ForegroundColor Green
            } catch {
                Write-Host "First check: Failed." -ForegroundColor Yellow
                do {
                    foreach ($node in $clusterNodes) {
                        try {
                            write-host "Checking host: $($node)"
                            $diskAttachedCheck = Get-VHD -Path $diskFullName -ComputerName $node -ErrorAction Stop
                            $passed = 1
                            Write-Host "Second check: Passed using node: $($node)" -ForegroundColor Green
                            break
                        } catch {
                            $clusterEndNode = $clusterNodes.count -1
                            if ($node -eq $clusterNodes[$clusterEndNode]) {
                                $nodeCheckComplete = 1
                                Write-Host "All checks failed for disk $($disk.name)" -ForegroundColor Red
                                if ($($Error[0].Exception.Message) -match 'The operation cannot be performed while the object is in use.') {
                                    write-host "The operation cannot be performed while the object is in use." -ForegroundColor Yellow
                                }
                            } else {
                                continue
                            }
                        }
                    }
                } until ($passed -eq 1 -or $nodeCheckComplete -eq 1)
            }
        } until ($passed -eq 1 -or $nodeCheckComplete -eq 1)
        $diskDetailsArray += [pscustomobject]@{
            DiskPath = $diskFullName;
            Attached = $diskAttachedCheck.Attached;
            DiskSize = [math]::Round($diskAttachedCheck.Size /1GB, 1);
            DiskFileSize = [math]::Round($diskAttachedCheck.FileSize /1GB, 1)
        }
    }
}

$diskDetailsArray | ?{$_.Attached -ne 'True'} | ft Attached,DiskSize,DiskFileSize,DiskPath -AutoSize

## Enable to export output to CSV.
$diskDetailsArray | ?{$_.Attached -ne 'True'} | Export-Csv -Delimiter ',' -Path C:\temp\DetachedDisks-$($clusterName).csv -NoTypeInformation 
