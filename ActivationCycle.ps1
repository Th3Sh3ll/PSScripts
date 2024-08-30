$hostServer = '' # where the vm lives
$clusterName= '' # to get cluster resource
$vmName     = '' #vm name
$diskSource = '' # source disk to make a copy from, this should be your prepped disk
$diskFolder = "\\host\c$\ClusterStorage\volume\vmname\"
$copyDisk   = "" # name of the disk
$attachDisk = "\\host\c$\ClusterStorage\volume\vmname\$copyDisk"

###
# This will get the cluster resource (VM) state, offline or online.
# If the VM is offline it will then detach the syspreped disk and delete it as it is marked as used.
# then it will make a copy from source
# attach the new copy to the VM
# start the vm
#
# sysprep should have an answer file which can carry through the setup unattended
# execute the IP and ACtivation script, script must be updated to force a shutwon after IP and actiavtion.
#
# there is a loop within this script to then check on the running status of the vm
# once the running status of the VM goes into offline, it will then incrememt the activation count by 1 and loop again until 
# activation count and activationEnd count is equal 
###

# loop will continue until activation count is greater or equal to activation count end
$activationCountEnd = 4  # till what number the activation cycle must end
$activationCount    = 0  # count of how many cycles have activated
$minutesWaitingFor  = 0  # used to give us a count of minutes its been online for
$secondsToWait      = 60 # this will wait for specified seconds/minutes to check the VM status again and wait till its offline.
$totalMinutesTaken  = 0

function removeDrive {
    Param(
        $vmState
    )
    Write-Host "VM current state: $($vmState)"
    Invoke-Command -ComputerName $hostServer -ScriptBlock {
        $vmHDD = Get-VM $Using:vmName | select -ExpandProperty harddrives
        Write-Host "Removing disk from VM" -ForegroundColor Yellow
        Remove-VMHardDiskDrive -VMName $vmHDD.vmname -ControllerType $vmHDD.ControllerType -ControllerNumber $vmHDD.ControllerNumber -ControllerLocation $vmHDD.ControllerLocation -WarningAction SilentlyContinue
        Write-Host "Removing used drive: $($vmHDD.path)" -ForegroundColor Yellow
        Remove-Item $vmHDD.path 
    }
}

function attachDrive {
    Param(
        $vmState
    )
    Write-Host "VM current state: $($vmState)"
    Write-Host "Attaching drive" -ForegroundColor Yellow
    Invoke-Command -ComputerName $hostServer -ScriptBlock {
        Add-VMHardDiskDrive -VMName $Using:vmName -Path $using:attachDisk -WarningAction SilentlyContinue
    }
}

while ($activationCountEnd -ge $activationCount) {
    $vmResource = Get-ClusterResource -Cluster $clusterName | ? {$_.OwnerGroup -eq $vmName -and $_.ResourceType -eq 'Virtual Machine'}
    switch ($vmResource.State) {
        "Offline" {
            removeDrive -vmState $vmResource.State
            
            Write-Host "Making a copy from source drive"
            Copy-Item $diskSource "$($diskFolder)$($copyDisk)"

            attachDrive -vmState $vmResource.State

            $vmResource | Start-ClusterResource 
        }
        "Online" {
            do {
                Start-Sleep -Seconds 60
                $minutesWaitingFor += 1
                $stateCheck = Get-ClusterResource -Cluster $clusterName | ? {$_.OwnerGroup -eq $vmName -and $_.ResourceType -eq 'Virtual Machine'}
                Write-Host "Currently online for $($minutesWaitingFor) minute(s)"
            } until ($stateCheck.State -eq "Offline")
            $activationCount ++
            $totalMinutesTaken += $minutesWaitingFor
            Write-Host "VM is off, time taken: $($minutesWaitingFor) minutes" -ForegroundColor Green
            $minutesWaitingFor = 0 # reset timer
        }
    }
    write-host "Cycle will end when count: $($activationCountEnd) is reached" -ForegroundColor Yellow
    write-host "Count of Activation Cycle: $($activationCount)" -ForegroundColor Green
}

write-host "Activation cycle ended after $totalMinutesTaken minutes"