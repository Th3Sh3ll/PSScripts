<#
Used to get certificate details from CA and email the report.
#>
function Get-TableRow {
    param (
        [pscustomobject]$Object
    )

    $statusClass = if ($Object.'Days To Expire' -le 7) { "Expiring" } else { "OK" }
    
    "<tr>" +
    "<td style='font-family: sans-serif;'>$($Object.'Common Name')</td>" +
    "<td style='font-family: sans-serif;'>$($Object.'Effective Date')</td>" +
    "<td style='font-family: sans-serif;'>$($object.'Expiration Date')</td>" +
    "<td style='font-family: sans-serif;'>$($Object.'Template')</td>" +
    "<td style='font-family: sans-serif;'>$($Object.'Days To Expire')</td>" +
    "<td style='font-family: sans-serif;' class='$statusClass'>$($statusClass)</td>" +
    "</tr>"
}

$issuedCerts = (certutil -out "Request Disposition,Revocation Date,Certificate Expiration Date,Certificate Effective Date,Certificate Template,Issued Common Name,Issued Email Address" -view csv) | ConvertFrom-Csv 

$expiredCount = 0
$certificateDetailsArray = @()
foreach ($cert in $issuedCerts) {
    $date = $cert.'Certificate Expiration Date'
    $name = $cert.'Certificate Template'
    $certDetails = [pscustomobject]@{
        'Common Name'     = $cert.'Issued Common Name';
        'Effective Date'  = $cert.'Certificate Effective Date';
        'Expiration Date' = $date;
        'Template'        = $($name.Split(' ')[1..10] -join " ");
        'Days To Expire'  = ((get-date $date.split(' ')[0]) - (get-date)).days
    }
    if ($certDetails.'Days To Expire' -lt 0) {
        write-host "Ignoring as certificate has already expired"
        $expiredCount ++
    } else {
        $certificateDetailsArray += $certDetails
    }
}

$aboutToExpire = $certificateDetailsArray | ? {$_.'Days To Expire' -le 7}

$tableRows = $certificateDetailsArray | sort 'Days To Expire' | ForEach-Object { Get-TableRow $_ }

$htmlTemplate = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Certificate Check</title>
<style>
    table {
        border-collapse: collapse;
        width: 100%;
    }
    th, td {
        border: 1px solid #dddddd;
        text-align: left;
        padding: 6px;
    }
    th {
        background-color: #f2f2f2;
    }
    .OK {
        background-color: #c8e6c9; /* light green */
    }
    .Expiring {
        background-color: #ffcdd2; /* light red */
    }
</style>
</head>
<body>
<p style='font-family: sans-serif;'>Certificates Report From: <b>$($env:COMPUTERNAME)</b></p>
<p style='font-family: sans-serif;'>Certificates found: <b>$($certificateDetailsArray.count + $expiredCount)</b></p>
<p style='font-family: sans-serif;'>Certificates Expired: <b>$($expiredCount)</b></p>
<p style='font-family: sans-serif;'>Certificates About To Expire: <b>$($aboutToExpire.count)</b></p>
<p style='font-family: sans-serif;'>Certificates Reported: <b>$($certificateDetailsArray.count)</b></p>
<table>
    <thead>
        <tr>
            <th style='font-family: sans-serif;'>Name</th>
            <th style='font-family: sans-serif;'>Created</th>
            <th style='font-family: sans-serif;'>Expiring</th>
            <th style='font-family: sans-serif;'>Template Used</th>
            <th style='font-family: sans-serif;'>Days Left</th>
            <th style='font-family: sans-serif;'>Status</th>
        </tr>
    </thead>
    <tbody>
        $($tableRows -join "`n")
    </tbody>
</table>

</body>
</html>
"@

$mailParams = @{
    To         = ""
    From       = ""
    Subject    = 'Certificate Check'
    body       = "$($htmlTemplate)"
    SmtpServer = ""
}

try {
    Send-MailMessage @mailParams -BodyAsHtml -ErrorAction Stop
} catch {
    scriptLogging -logMessage "Error unable to send email: $($error[0].exception.message)"
}
