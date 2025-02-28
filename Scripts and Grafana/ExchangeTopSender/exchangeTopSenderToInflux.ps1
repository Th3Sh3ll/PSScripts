# Import the Exchange module
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn

# functions
function get-topSender ($messagesTracked) {
    $top10 = $messagesTracked | Group-Object -Property Sender | Select-Object Name, @{Name='ReturnPath';Expression={$_.group.ReturnPath[0]}}, @{Name='EmailsSent';Expression={$_.Count}} | Sort-Object -Property EmailsSent -Descending
    return $top10
}

function get-topEmailSent ($messagesTracked) {
    write-host "Getting sender and count"
    $senderAndCount = ($messagesTracked | Group-Object -Property MessageSubject | sort count -Descending)[0].group | Group-Object sender | select count, name 
    write-host "getting message subject"
    $messageSubject = ((($messagesTracked | Group-Object -Property MessageSubject | sort count -Descending)[0].group | Group-Object sender).group | select messagesubject)[0]
    Write-Host "returning $($senderAndCount) with subject: $($messageSubject) "
    return $senderAndCount, $messageSubject.messagesubject
}

$exchangeServerLocation = 'TEST' # TEST=ExchangeServersMatching | ALL=ALLExchangeServersKnown
[int]$lastHourcheck = 1

$StartDate = (Get-Date).AddHours(-$($lastHourcheck))
$EndDate = Get-Date

if ($exchangeServerLocation -eq 'ALL') {
    $returnedMessages = Get-ExchangeServer | Get-MessageTrackingLog -ResultSize Unlimited -Start $StartDate -End $EndDate | ? { $_.EventId -eq "SEND" -and $_.sender -notmatch 'MicrosoftExchange329e71ec88ae4615bbc36ab6ce41109e' } 
    $topSenders = get-topSender -messagesTracked $returnedMessages
} else {
    $returnedMessages = Get-ExchangeServer | ? {$_.name -match $($exchangeServerLocation)} | Get-MessageTrackingLog -ResultSize Unlimited -Start $StartDate -End $EndDate | ? { $_.EventId -eq "SEND" -and $_.sender -notmatch 'MicrosoftExchange329e71ec88ae4615bbc36ab6ce41109e' } 
    $topSenders = get-topSender -messagesTracked $returnedMessages
}

$topEmail = get-topEmailSent -messagesTracked $returnedMessages
# $topEmail | select -First 1 | Format-Table -AutoSize

$topEmailSentCount = 0
foreach ($senderMessage in $topEmail[0]) {
    $topEmailSentCount += $senderMessage.count
}

$totalSent = 0
foreach ($sent in $TopSenders) {
    $totalSent += $sent.emailssent
}

$topSender = $topSenders[0]
if (!$topSender.name) {
    $topSender.name = $topSender.ReturnPath
}

# send data to influxDB
# InfluxDB measurement
$measurement = 'TopSender'

# Computer hosing influx
$influxHost     = ""

# influx port
$influxHostPort = "8086"

# Database/Bucket to write metrics to
$influxDbName   = "EXCHANGE_PS"

# build URL for posting to Influx
$influxUriPost  = "https://$influxHost" + ":" + "$influxHostPort/write?db=$influxDbName"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$authArray = @{
    "Authorization" = "Token tokenString"
}
$TimeStamp   = [DateTimeOffset]::Now.ToUnixTimeMilliseconds() * 1000000

# Used to validate metric that will be sent
# Comment out when metric is validated and accepted by influxDB 
Write-Host "$measurement,Host=""$env:COMPUTERNAME"" Server=""$env:COMPUTERNAME"",TotalSent=$($totalSent),MostSent=$($topEmailSentCount),from=""$($topEmail[0].name)"",MostSentSubject=""$($topEmail[1])"",topSender=""$($topSender.name)"",topSenderSent=$($topSender.EmailsSent) $TimeStamp"

# POST the metric to influxDB
Invoke-RestMethod -Uri $influxUriPost -Method POST -Headers $authArray  -Body "$measurement,Host=""$env:COMPUTERNAME"" Server=""$env:COMPUTERNAME"",TotalSent=$($totalSent),MostSent=$($topEmailSentCount),from=""$($topEmail[0].name)"",MostSentSubject=""$($topEmail[1])"",topSender=""$($topSender.name)"",topSenderSent=$($topSender.EmailsSent) $TimeStamp"
