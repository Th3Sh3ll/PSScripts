# check where your account is logged in, log you off or not, whatever...

$userAccount = "" # user account to check

$location = "" # All=Search all servers in your domain else put a pattern that can be used, for example, EXCH=all exchange servers in your domain only.

$logOff = "no" # Specify Yes or No... If you just want to be shown a list of servers you are logged into, then specify No, if you want the script to do the dirty work for you, then specify Yes.

# arrys
$serversFailed = @()
$serversSucces = @()
$sessionsFound = @()
$sessionsNull  = @()
$sessionsLogOff= @()

if ($location -eq 'All') {
    $serversToCheck = Get-ADComputer -Filter "OperatingSystem -Like '*Windows Server*' -and Enabled -eq 'True'"
} else {
    $serversToCheck = Get-ADComputer -Filter "OperatingSystem -Like '*Windows Server*' -and Enabled -eq 'True' -and name -like '$($location)*'"
}

write-host "Script will no loop through $($serversToCheck.count) servers." -ForegroundColor Green

foreach ($server in $serversToCheck) {
    write-host "checking server: $($server.name)"
    try {
        $sessions = query user /server:$($server.name) 2>$null
        if ($sessions) {
            $UserInfo = foreach ($Session in ($sessions | select -Skip 1)) {
                $Session = $Session.ToString().trim() -replace '\s+', ' ' -replace '>', ''
                if ($Session.Split(' ')[0] -eq $userAccount) {
                    if ($logOff -eq 'No') {
                        $sessionsFound += [PSCustomObject]@{
                            ComputerName = $server.name
                            UserName     = $session.Split(' ')[0]
                            SessionName  = $session.Split(' ')[1]
                            SessionID    = $Session.Split(' ')[2]
                            SessionState = $Session.Split(' ')[3]
                            IdleTime     = $Session.Split(' ')[4]
                            LogonTime    = $session.Split(' ')[5, 6, 7] -as [string] -as [datetime]
                            LogOffResult = "Not Attempted"
                        }
                    } else {
                        write-host "`nScript will attempt to log you out of $($server.Name)" -ForegroundColor Yellow
                        #safe gauard to logging yourself out on the computer you running the script lol
                        if ($server.name -eq $env:COMPUTERNAME) {
                            Write-Host "`nwont you log you out of the host you executing from" -ForegroundColor Green
                        } else {
                            logoff $($Session.Split(' ')[1]) /server:$($server.name)
                            $sessionsFound += [PSCustomObject]@{
                                ComputerName = $server.name
                                UserName     = $session.Split(' ')[0]
                                SessionName  = $session.Split(' ')[1]
                                SessionID    = $Session.Split(' ')[2]
                                SessionState = $Session.Split(' ')[3]
                                IdleTime     = $Session.Split(' ')[4]
                                LogonTime    = $session.Split(' ')[5, 6, 7] -as [string] -as [datetime]
                                LogOffResult = "Attempted"
                            }
                            $sessionsLogOff += $server.Name
                        }
                    }
                } else {
                    continue
                }
            }
            $serversSucces += $server.Name
        } else {
            write-host "no sessions found on $($server.Name)"
            $sessionsNull += $server.Name
        }
    } catch {
        write-host "Error occured on $($server.name)" -ForegroundColor Yellow
        $serversFailed += $server.Name
    }
}
write-host "`nSummary" -ForegroundColor Yellow
write-host "Servers failed to check: $($serversFailed.count)"
write-host "Servers Successfully checked: $($serversSucces.count)"
write-host "Servers with no sessions matched to $($userAccount): $($sessionsNull.count)"
if ($logOff -eq 'Yes') {
    write-host "Servers with sessions log off attempted: $($sessionsLogOff.count)" -ForegroundColor Yellow
}
write-host "`nSessions found" -ForegroundColor Green
$sessionsFound | ft -AutoSize
