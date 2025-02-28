function get-creds ($user, $pass) {
    #decrypt and build creds
    $cUser   = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String("$($user)"))
    $cPassB64= [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String("$($pass)"))
    $cPass   = $cPassB64 | ConvertTo-SecureString -AsPlainText -Force
    $creds = [System.Management.Automation.PSCredential]::new($cUser, $cPass)
    return $creds
}

function get-exServerQueue ($server) {
    $creds = get-creds -user $env:SWU -pass $env:SWP
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$($server)/powershell -Authentication Kerberos -Credential $Creds
    Import-PSSession $Session -CommandName get-queue,get-exchangeserver -AllowClobber -DisableNameChecking | Out-Null

    $exchangeServers = Get-ExchangeServer 
    $exchangeServersNotConnected = @()
    $exchangeCheckOutput         = @()

    foreach ($exchangeServer in $exchangeServers) {        
        write-host "`nscript is busy with $($exchangeServer.Name)"
        try {
            $queues = Get-Queue -Server $($exchangeServer.Name) -ErrorAction stop
        } catch {
            write-host "Connection to $($exchangeServer) broken"
            write-host "Error: $($Error[0].Exception.Message)"
            $exchangeServersNotConnected += $($exchangeServer)
            continue
        }
        foreach ($queue in $queues) {
            $exchangeCheckOutput += [pscustomobject]@{
                ExchangeServer    = $($exchangeServer.Name);
                QueueIdentity     = $queue.Identity;
                QueueStatus       = $queue.Status;
                QueueMessageCount = $queue.MessageCount
            }
        }
    }

    # InfluxDB measurement
    $InfluxMeasurement = 'ExchangeQueue'

    # Computer hosing influx
    $influxHost     = ""

    # influx port
    $influxHostPort = "8086"

    # Database/Bucket to write metrics to
    $influxDbName   = "PSSCRIPT_EXCHANGE"

    # hostname from where it is getting its metrics
    $Hostname       = $env:COMPUTERNAME

    # build URL for posting to Influx
    $influxUriPost  = "https://$influxHost" + ":" + "$influxHostPort/write?db=$influxDbName"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $authArray = @{
        "Authorization" = "Token base64Token"
    }


    foreach ( $queuePayload in $exchangeCheckOutput ) {
        $payload = @{
            Measurement = $InfluxMeasurement
            Host        = $($Hostname)
            Server      = $($queuePayload.exchangeServer)
            Queue       = $($queuePayload.QueueIdentity -replace('\\',' ') -replace(' ','_'))
            Status      = $($queuePayload.QueueStatus)
            Counts      = $($queuePayload.QueueMessageCount -as [int])
            TimeStamp   = [DateTimeOffset]::Now.ToUnixTimeMilliseconds() * 1000000
        }

        $line = "$($payload.Measurement),Host=$($payload.host),Server=$([string]$payload.Server),Queue=$($payload.Queue),Status=$($payload.Status) Count=$($payload.Counts) $($payload.TimeStamp)"
        Write-host $line

        Invoke-RestMethod -Uri $influxUriPost -Method POST -Headers $authArray -Body $line
    }

    # Disconnect Session
    Remove-PSSession $Session
}


get-exServerQueue -server "ExchangeServer"

