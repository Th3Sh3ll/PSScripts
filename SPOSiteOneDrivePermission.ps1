<#
    to provide access to one drive 
#>

# Import module and connect to SPO
# # check if module exists and import, if not break with error.
$SPdomain = 'Sharepoint domain name'
$moduleName = 'Microsoft.Online.SharePoint.PowerShell'
$siteAddres = "https://$($SPdomain)-my.sharepoint.com/personal"
try {
    Import-Module $moduleName -ErrorAction Stop
    Write-Host "Module imported" -ForegroundColor Green
} catch {
    write-host "Unable to import module $($moduleName), you may need to install the module`nInstall-Module -Name Microsoft.Online.SharePoint.PowerShell `nor make it usable for all users." -ForegroundColor Yellow
    Write-Host "`nError: $($Error[0].Exception.Message)" -ForegroundColor Red
    break
}

# # connect to SPO
# build email addy
$upn = ([adsisearcher]"(samaccountname=$env:USERNAME)").FindOne().Properties.mail

try {
    Connect-SPOService -Url "https://$($SPdomain)-admin.sharepoint.com" -Credential (Get-Credential -Message "Auth to SPO" -UserName $($upn)) -ErrorAction Stop
    write-host "Connected" -ForegroundColor Green
} catch {
    write-host "Connection failed, is your PIM activated!"
    Write-Host "`nError: $($Error[0].Exception.Message)" -ForegroundColor Red
    break
}

# user account that needs access
write-host "`nEnter the user that is requesting access, example:`nStella Won" -ForegroundColor Yellow
$userRequestingAccess = Read-Host("User")
if (! ([adsisearcher]"(name=$userRequestingAccess)").FindOne().Properties.mail) {
    Write-Host "`nUnable to retrieve mail for $($userRequestingAccess)`nAre you sure of the name?" -ForegroundColor Yellow
    break
} else {
    $userRequestingAccess = ([adsisearcher]"(name=$userRequestingAccess)").FindOne().Properties.mail
    Write-Host "Email address found: $($userRequestingAccess)" -ForegroundColor Green
}

# user account that access must be given to
write-host "`nEnter the user that $($userRequestingAccess) needs access to" -ForegroundColor Yellow
$accessTo = Read-Host "User"
if (! ([adsisearcher]"(name=$accessTo)").FindOne().Properties.mail) {
    Write-Host "`nUnable to retrieve mail for $($accessTo)`nAre you sure of the name?" -ForegroundColor Yellow
    break
} else {
    $accessTo = ([adsisearcher]"(name=$accessTo)").FindOne().Properties.mail
    Write-Host "Email address found: $($accessTo)" -ForegroundColor Green
}

Write-Host "`nGiving access to $($userRequestingAccess) on $($accessTo) One Drive" -ForegroundColor Yellow
# converting user to format that will be accepted by function: name_surname_fqml_com
$convertedSiteNameAccount = $($accessTo -replace('\.','_') -replace('@','_'))

# getting the site 
if (! (Get-SPOSite -Identity "$($siteAddres)/$($convertedSiteNameAccount)" ) ) {
    # nothing returned from normal get site, checking in deleted sites
    if ( !(Get-SPODeletedSite -Identity "$($siteAddres)/$($convertedSiteNameAccount)") ) {
        # nothing found in deleted sites, script will break
        write-host "checked deleted sites as well, found nothing for : $($siteAddres)/$($convertedSiteNameAccount)" -ForegroundColor Yellow
        break
    } else {
        # found in deleted sites, restore the site and mark as found
        Write-Host "`nSite found in deleted sites, restoring site to apply permission" -ForegroundColor Green
        Restore-SPODeletedSite -Identity "$($siteAddres)/$($convertedSiteNameAccount)"
        $found = 1
    }
} else {
    # found and mark as found
    Write-Host "`nSite found, applying permission" -ForegroundColor Green
    $found = 1
}

# use the found marker to confirm that site exists and apply permission with set SPOuser.
if ($found -eq 1) {
    # set in try/catch for error handling.
    try {
        Set-SPOUser -Site "$($siteAddres)/$($convertedSiteNameAccount)" -LoginName $userRequestingAccess -IsSiteCollectionAdmin $true -ErrorAction Stop
        write-host "Site access applied, request $($userRequestingAccess) to use this link to access the one drive location" -ForegroundColor Cyan
        write-host "$($siteAddres)/$($convertedSiteNameAccount)" -ForegroundColor Green
    } catch {
        write-host "`nUnable to apply permission" -ForegroundColor Yellow
        Write-Host "ERROR;`n$($Error[0].Exception.Message)" -ForegroundColor Red
        break
    }
} else {
    $null
}