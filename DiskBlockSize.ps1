# function to return max size for found block size
function get-maxSize ($blockSize) {
    switch ($blockSize) {
        512 {
            return 2
        }
        1024 {
            return 4
        }
        2048 {
            return 8
        }
        4096 {
            return 16
        }
        8192 {
            return 32
        }
        16384 {
            return 64
        }
        32768 {
            return 128
        }
        65536 {
            return 256
        }
    }
}

# Function to get the block size of a volume
function Get-VolumeBlockSize ($VolumeLetter) {
    $volume = Get-Volume -DriveLetter $VolumeLetter

    # Use Get-WmiObject to retrieve the allocation unit size
    $query = "SELECT BlockSize FROM Win32_Volume WHERE DriveLetter='$($volume.DriveLetter):'"
    $blockSize = Get-WmiObject -Query $query | Select-Object -ExpandProperty BlockSize

    # Return the block size in a human-readable format
    return [PSCustomObject]@{
        DriveLetter = $VolumeLetter
        BlockSize   = "$blockSize bytes"
        MaxSize     = "$(get-maxSize -blocksize $blockSize)TB" 
    }
}

# Get a list of all volumes
$volumes = Get-Volume | Where-Object { $_.DriveLetter -ne $null -and $_.FileSystemLabel -ne 'Recovery' -and $_.FileSystemType -eq 'NTFS'}

# Iterate over each volume and get the block size
$blockSizes = foreach ($volume in $volumes) {
    Get-VolumeBlockSize -VolumeLetter $volume.DriveLetter
}

# Output the results
$blockSizes | Format-Table -AutoSize
