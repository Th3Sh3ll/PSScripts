<#
    Script used to copy group memberships from one user to the other.
#>

$fromUser = "" # # user to copy group membership from
$toUser   = "" # user to copy group membership to

# Arrays
$groupsNotAddedTo  = @()
$groupsAddedSucces = @()

# get the from users groups
Write-Host "`ngetting groups from user: $($fromUser)" 
try {
    $groupMembershipOfFromUser = Get-ADUser $fromUser -Properties * -ErrorAction Stop | select -ExpandProperty memberof
} catch {
    Write-Host "Something happened when looking for: $($fromUser)" -ForegroundColor Yellow
    write-host "ERROR: $($Error[0].Exception.Message)"
    write-host "Script will end." -ForegroundColor Red
    break
}
Write-Host "Number of groups found: $($groupMembershipOfFromUser.count)"

# adding groups to the to user
$groupMembershipOfFromUser | % {
    $groupName      = $_
    $groupShortName = $groupName.Split('=')[1] -replace(',OU','')
    write-host "Adding $($groupShortName) to $($toUser)"
    try {
        Add-ADGroupMember -Identity $groupName -Members $toUser -ErrorAction Stop
        $groupsAddedSucces += [pscustomobject] @{
            GroupName = $($groupShortName);
            Message   = 'Added'
        }
    } catch {
        write-host "Error adding $($toUser) to $($groupShortName)" -ForegroundColor Yellow
        Write-Host "Error: $($Error[0].Exception.Message)"
        $groupsNotAddedTo += [PSCustomObject] @{
            GroupName = $($groupShortName);
            Exception = $($Error[0].Exception.Message)
        }
    }
}
Write-Host "`nSummary for copying groupmembership" -ForegroundColor Green
Write-Host "From: $($fromUser) to $($toUser)"
Write-Host "`nGroups successfully added: $($groupsAddedSucces.count) out of $($groupMembershipOfFromUser.count)" -ForegroundColor Green
$groupsAddedSucces | ft -AutoSize
Write-Host "`nGroups NOT added: $($groupsNotAddedTo.count)" -ForegroundColor Yellow
$groupsNotAddedTo | ft -AutoSize