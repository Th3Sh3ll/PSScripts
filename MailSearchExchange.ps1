Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn

function set-datetime ($time) {
    $formattedTime = [datetime]::ParseExact($($time), 'MM/dd/yyyy HH:mm:ss', $null)
    return $formattedTime
}

function find-messages ($start, $end, $subject, $sender, $recipient, $service) {
    if (!$recipient) {
        Write-Host "Searching Service: $service with sender and no recipient"
        $messages = Get-MessageTrackingLog -Server $service -Start $startTime -End $endTime -MessageSubject $subject -Sender $sender 
        return $messages
    } elseif (!$sender -and !$recipient) {
        Write-Host "Searching Service: $service with no sender or recipient and only for subject"
        $messages = Get-MessageTrackingLog -Server $service -Start $startTime -End $endTime -MessageSubject $subject 
        return $messages
    } else {
        Write-Host "Searching Service: $service with no sender or recipient and only for subject"
        $messages = Get-MessageTrackingLog -Server $service -Start $startTime -End $endTime -MessageSubject $subject -Sender $sender -Recipients $recipient
        return $messages
    }
}

# arrays
$messagesFound = @()

# populate variables
$sender  = '' #if blank will search for anyone that sent between the times for the subject
$reciev  = '' # if blank it will search for all recipients
$subject = 'Test' # if left blank it will search all messages sent between the times from your defined sender and recipient.
$start   = '06/19/2025 00:00:00' #time format expected: MM/DD/yyyy hh:mm:ss
$end     = '06/19/2025 23:00:00'


# get formatted time
$startTime = set-datetime -time $start
$endTime   = set-datetime -time $end

# Get all transport servers/services
$transportService = Get-TransportService

# search for message by going through each transport service.
foreach ($service in $transportService) {
    $messagesFound += find-messages -service $service.Identity -start $startTime -end $endTime -subject $subject -sender $sender -recipient $reciev
}

# display results
if (! $messagesFound) {
    Write-Host "`nNo messages found for:" -ForegroundColor Yellow
    Write-Output "Sender: $($sender)`nRecipient: $($reciev)`nSubject: $($subject)`nBetween: $($start) and $($end)"
} else {
    Write-Host "`nMessages found $($messagesFound.count)" -ForegroundColor Green
    write-host "Search period: $($startTime) to $($endTime)"
    $messagesFound | sort timestamp | % {Write-Output $_}
}