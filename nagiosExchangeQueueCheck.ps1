function get-exServerQueue ($server) {
    try {
        $queues = Get-Queue -Server $($server) -ErrorAction stop
    } catch {
        write-output "Connection to $($server) broken"
        Write-Output "Connected with $($env:USERNAME)"
        write-output $($Error[0].exception.message)
        exit 2
    }
    foreach ($queue in $queues) {
        if ($queue.status -ne 'Ready' -and $queue.status -ne 'active') {
            $exchangeCheckOutputIssue = "CRITICAL: Queue $($queue.Identity.Replace('\',' ')) is in $($queue.Status) state on $($server)"
        } elseif ($queue.messagecount -gt 100) {
            $queueHighCount = "CRITICAL: Queue $($queue.Identity.Replace('\',' ')) has a high count of $($queue.MessageCount) on $($server)"
        } else {
            $exchangeCheckOutputOK = "OK: All Queues Good"
        }
    }
    if ($exchangeCheckOutputIssue) {
        write-output $exchangeCheckOutputIssue
        exit 2
    } elseif ($queueHighCount) {
        Write-Output $queueHighCount
        exit 2
    } else {
        Write-Output $exchangeCheckOutputOK
        exit 0
    }
}


#decrypt and build creds
$cUser   = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String("$($env:SWU)"))
$cPassB64= [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String("$($env:SWP)"))
$cPass   = $cPassB64 | ConvertTo-SecureString -AsPlainText -Force
$creds = [System.Management.Automation.PSCredential]::new($cUser, $cPass)

# Create and Import Session
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$($args)/powershell -Authentication Kerberos -Credential $Creds

Import-PSSession $Session -CommandName get-queue -AllowClobber -DisableNameChecking | Out-Null

get-exServerQueue -server $args

# Disconnect Session
Remove-PSSession $Session
