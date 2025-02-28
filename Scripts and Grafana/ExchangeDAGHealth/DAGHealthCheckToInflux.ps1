<#
    Script will gather metrics on:
        Database mount status
        Service health
        Replication health
        Memory (back pressure)

    this will write the metrics to a influx DB status
    Import the Grafana dashboard and hook to influx DB datasource.
#>

# Functions
Function log-ToFile ($message) {
    $dateTimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss:ffff'
    $logMessage = [ordered]@{
        timestamp = $dateTimeStamp;
        message   = $message
    }
    $logJson = $logMessage | ConvertTo-Json -Compress
    $logJson | Out-File -FilePath "C:\Scripts\Healthchecker\DAG-Replication-Service-healthCheck Logs\$($env:COMPUTERNAME)-$($dateTimeStamp.split(' ')[0]).txt" -Append       
}

## build array for DAG check
Function build-DAGCheckArray ($db, $status) {
    $object = [pscustomobject] @{
        Server = ($db -split('\\'))[1];
        DB     = ($db -split('\\'))[0];
        Count  = $status
    }
    return $object
}

## build array for Replication check
Function build-ReplicationArray ($dagName, $check, $result, $ErrorMessage) {
    $object = [pscustomobject] @{
        dagName = $dagName;
        Check   = $check;
        Result  = $result;
        Error   = if ($ErrorMessage) {$ErrorMessage} else {"No Error"}
    }
    return $object
}

## build array for service health check
Function build-ServiceArray ($serverchecked, $role, $runningState) {
    $object = [pscustomobject] @{
        Server     = $serverchecked;
        Role       = $role;
        AllRunning = $runningState
    }
    return $object
}

## Function to send DAG output to InfluxDB
Function send-InfluxDB ($measurement, $payload) {
    # InfluxDB measurement
    $ExchangeQueue = $measurement
    # Computer hosing influx
    $influxHost     = ""
    # influx port
    $influxHostPort = "8086"
    # Database/Bucket to write metrics to
    $influxDbName   = "EXCHANGE"
    # hostname from where it is getting its metrics
    $Hostname       = $env:COMPUTERNAME
    # build URL for posting to Influx
    $influxUriPost  = "https://$influxHost" + ":" + "$influxHostPort/write?db=$influxDbName"
    $authArray = @{
        "Authorization" = "Token base64AuthTokenFromBucket"
    }
    # set security protocol to use TLS as the influx instance is listening on HTTPS 
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    if ($ExchangeQueue -eq 'DAG') {
        foreach ($load in $payload) {
            $TimeStamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds() * 1000000
            log-ToFile -message "Sending Payload to InfluxDB for Measurement:-------------$($ExchangeQueue),Host=""$($payload.server)"" Server=""$($payload.server)"",Database=""$($payload.DB)"",Active=$($payload.Count) $TimeStamp"
            Invoke-RestMethod -Method Post -Uri $influxUriPost -Headers $authArray -Body "$($ExchangeQueue),Host=""$($payload.server)"" Server=""$($payload.server)"",Database=""$($payload.DB)"",Active=$($payload.Count) $TimeStamp"
        }
    } elseif ($ExchangeQueue -eq 'Service') {
        foreach ($load in $payload) {
            $TimeStamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds() * 1000000
            log-ToFile -message "Sending Payload to InfluxDB for Measurement:-------------$($ExchangeQueue),Host=""$($payload.server)"" Server=""$($payload.server)"",Role=""$($payload.Role)"",Status=$($payload.AllRunning) $TimeStamp"
            Invoke-RestMethod -Method Post -Uri $influxUriPost -Headers $authArray -Body "$($ExchangeQueue),Host=""$($payload.Server)"" Server=""$($payload.server)"",Role=""$($payload.Role)"",Status=$($payload.AllRunning) $TimeStamp"
        }
    } elseif ($ExchangeQueue -eq 'Replication') {
        foreach ($load in $payload) {
            $TimeStamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds() * 1000000
            log-ToFile -message "Sending Payload to InfluxDB for Measurement:-------------$($ExchangeQueue),Host=""$($payload.dagName)"" DagName=""$($payload.dagName)"",Check=""$($payload.Check)"",Result=""$($payload.Result)"",Error=""$($payload.Error)"" $TimeStamp"
            Invoke-RestMethod -Method Post -Uri $influxUriPost -Headers $authArray -Body "$($ExchangeQueue),Host=""$($payload.dagName)"" DagName=""$($payload.dagName)"",Check=""$($payload.Check)"",Result=""$($payload.Result)"",Error=""$($payload.Error)"" $TimeStamp"
        }
    } elseif ($ExchangeQueue -eq 'backPressure') {
        foreach ($load in $payload) {
            $TimeStamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds() * 1000000
            log-ToFile -message "Sending Payload to InfluxDB for Measurement:-------------$($ExchangeQueue),Host=""$($payload.Server)"" resource=""$($payload.resource)"",PressureValue=$($payload.PressureValue) $TimeStamp"
            Invoke-RestMethod -Method Post -Uri $influxUriPost -Headers $authArray -Body "$($ExchangeQueue),Host=""$($payload.Server)"" resource=""$($payload.resource)"",PressureValue=$($payload.PressureValue) $TimeStamp"
        }        
    } else {
        return write-host "No measurement found, nothing will be sent."
    }
}

log-ToFile -message "Script loaded functions and started."
# module load.
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn

#exchange servers to check
$exchangeCluster = ''
try {
    log-ToFile -message "Getting list of exchange servers and DAG with location: $($exchangeCluster)"
    $exchangeServers = Get-ExchangeServer -ErrorAction Stop | ? {$_.name -match $($exchangeCluster)} | sort name
    $databaseDAGName = (Get-DatabaseAvailabilityGroup  -ErrorAction Stop| ? {$_.Servers.name[0] -match $($exchangeCluster)}).Name
} catch {
    log-ToFile "Something went wrong"
    log-ToFile "ERROR: $($Error[0].exception.message)"
}

log-ToFile -message "Gathered list of exchange servers to work with"
$exchangeServers | % {
    log-ToFile -message "$($_.name)"
}
log-ToFile -message "DAG Found: $($databaseDAGName)."

# Arrays
$balanceCheckOutput = @()
$serviceCheckOutput = @()
$replicationcheck   = @()
$backPressureMemory = @()

# Health checks
# Replication test
log-ToFile -message "Testing replication for DAG: $($databaseDAGName)"
$replication = Test-ReplicationHealth -DatabaseAvailabilityGroup $databaseDAGName

# replication health foreach due to it being done to the DAG not on server level
# build array for replication check
log-ToFile -message "Building array for replication test"
foreach ($1 in $replication) {
    $replicationcheck += build-ReplicationArray -dagName $databaseDAGName -check $1.check -result $1.result -ErrorMessage $1.Error
}

# foreach section due to each server check being done on all servers in DAG
foreach ($server in $exchangeServers) {
    # DAG check
    log-ToFile -message "Getting DAG copy status for $($server.name)"
    $dbs = Get-MailboxDatabaseCopyStatus -Server $server.name
    log-ToFile -message "Building array for DAG check"
    $balanceCheckOutput += build-DAGCheckArray -db $($dbs[0].Name) -status $(($dbs | ? {$_.status -eq 'mounted'}).count)

    # Service check
    log-ToFile -message "testing services for exchange server: $($server.Name)"
    $services = Test-ServiceHealth -Server $server.Name

    # build array for service health test per server
    log-ToFile -message "Building service check array"
    foreach ($service in $services) {
        $serviceCheckOutput += build-ServiceArray -serverchecked $server.Name -role $service.role -runningState $service.RequiredServicesRunning
    }

    # check back pressure
    log-ToFile -message "Getting BackPressure check: $($server)" -ForegroundColor Green
    [xml]$catch = Get-ExchangeDiagnosticInfo -server $($server.name) -Process EdgeTransport -Component ResourceThrottling
    foreach ($item in $catch.Diagnostics.Components.ResourceThrottling.ResourceTracker.ResourceMeter) {
        $backPressureMemory += [pscustomobject] @{
            Server          = $server.name;
            resource        = $item.resource;
            CurrentPressure = $item.CurrentResourceUse;
            PressureValue   = $item.Pressure
        }
    }
}
log-ToFile -message "Sending Metrics for DAG Replication"
$replicationcheck   | % {
    send-InfluxDB -measurement "Replication" -payload $_
}

log-ToFile -message "Sending Metrics for Service Health check"
$serviceCheckOutput | % {
    send-InfluxDB -measurement "Service" -payload $_
}

log-ToFile -message "Sending Metrics for DAG copy status"
$balanceCheckOutput | % {
    send-InfluxDB -measurement "DAG" -payload $_
}

log-ToFile -message "Sending Metrics for BackPressure Memory"
$backPressureMemory | ? {$_.resource -eq 'SystemMemory'} | % {
    send-InfluxDB -measurement 'backPressure' -payload $_
}