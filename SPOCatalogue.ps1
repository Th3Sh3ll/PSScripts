$yourMail = ''
$SPdomain = 'Sharepoint domain name'
$siteName = 'EXPL-HSE'
$baseSite = "https://$($SPdomain).sharepoint.com/sites"
$siteFull = "$($baseSite.replace('-admin', ''))/$($siteName)"

function get-mySiteAdded ($siteFull) {
    try {
        $sitesEnabled = Get-SPOSiteCollectionAppCatalogs -Site $siteFull -ErrorAction Stop
    } catch {
        return "Error: $($Error[0].Exception.Message)"
    }
    write-host "`nListing sites , your one added should be in green." -ForegroundColor Yellow
    foreach ($site in $sitesEnabled) {
        if ($site.AbsoluteUrl -match $siteName) {
            Write-Host "Site Enabled: $($site.AbsoluteUrl)" -ForegroundColor Green
        } else {
            Write-Host "Site Enabled: $($site.AbsoluteUrl)"
        }
    }
}

try {
    Connect-SPOService -Url $($baseSite.Replace('/sites', '')) -Credential (get-credential -Message "AzureLogin Required" -UserName $($yourMail)) -ErrorAction Stop
} catch {
    write-host "Error in connecting to $($baseSite.Replace('/sites', ''))`nError: $($Error[0].exception.message)" -ForegroundColor Yellow
}


try {
    write-host "Getting site: $($siteFull)"
    $siteInfo = Get-SPOSite -Identity $siteFull -ErrorAction Stop
} catch {
    write-host "Error in getting site: $($siteFull)`nError: $($Error[0].exception.message)" -ForegroundColor Yellow
}


try {
    write-host "Adding app catalogue to $($siteFull)"
    Add-SPOSiteCollectionAppCatalog -Site $siteFull -ErrorAction Stop
} catch {
    write-host "Error happened adding app catalogue to: $($siteFull)`nError: $($Error[0].exception.message)" -ForegroundColor Yellow
}

get-mySiteAdded -siteFull $siteFull