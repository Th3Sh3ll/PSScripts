import-module DhcpServer

$dhcpServers = @(
    "DHCPServer1",
    "DHCPServer2"
)
$scopeBad_Address = @()
$scopeOutput = @()
foreach ($server in $dhcpServers) {
    write-host "Getting scopes from server: $($server)"
    $dhcpScopes = Get-DhcpServerv4Scope -ComputerName $server
    foreach ($scope in $dhcpScopes) {
        $badAddressCount = 0
        write-host "`nChecking Scope: $($scope.name) on server: $($server)"
        $scopeStats = Get-DhcpServerv4ScopeStatistics -ComputerName $server -ScopeId $scope.scopeid
        write-host "Checking for bad address in scope"
        $BadAddres = Get-DhcpServerv4Scope -ScopeId $($scope.ScopeId) | Get-DhcpServerv4Lease | ?{$_.hostname -match 'bad_address'}
        if ($BadAddres) {
            $badAddressCount = ($BadAddres | Measure-Object).count
            foreach ($badAdd in $BadAddres) {
                $scopeBad_Address += [pscustomobject] @{
                    Server      = $($server);
                    Scope       = $scope.ScopeId;
                    Name        = $($scope.name);
                    IP          = $badAdd.IPAddress;
                    State       = $badAdd.AddressState;
                    Description = $badAdd.description
                }
            }
        }
        $scopeOutput += [pscustomobject] @{
            Server   = $($server);
            Name     = $($scope.name);
            Scope    = $scope.ScopeId;
            State    = $scope.State;
            Free     = $scopeStats.AddressesFree -as [int];
            BADCount = $badAddressCount
        }
    }
}

$scopeOutput | ? {$_.free -lt 100 -and $_.state -ne 'inactive'} | sort free | ft -AutoSize
$scopeBad_Address | ft -AutoSize
