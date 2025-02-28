# folder usage

$location = "c:\temp"

$folders = Get-ChildItem -Path $location -Recurse -Depth 0

$folderSizeOuput = @()
$count = 0
foreach ($folder in $folders) {
    $count ++
    Write-Progress -Activity "Checking $($folder.Name)" -Status "$($count) of $($folders.Count)" -PercentComplete $($count / $folders.Count * 100)
    try {
        $folderSize = [math]::Round((Get-ChildItem -Path $folder.FullName -Recurse | Measure-Object length -Sum -ErrorAction Stop).sum /1GB, 1)
    } catch {
        $folderSize = 0
    }
    $folderSizeOuput += [pscustomobject] @{
        Folder = $folder.name;
        SizeGB = $folderSize -as [int]
    }
}
write-host "check completed" -ForegroundColor Green
Write-Host $location
$folderSizeOuput | sort SizeGB -Descending |ft -AutoSize