function log-message {
    Param (
        $message
    )
    $dateTimeStamp = Get-Date -Format 'yyyy-MM-dd hh:mm:ss:ffff'
    $message = [ordered]@{
        timestamp = $dateTimeStamp;
        message   = $message
    }
    $messageOutJson = $message | ConvertTo-Json -Compress
    write-host $messageOutJson
}

# Test if server is windows or linux

function test-arch {
    Param (
        [string[]]$machines
    )
    $testOutput = @()
    try {
        foreach ($machine in $machines) {
            log-message -message "Checking archOS on machine: $($machine)"
            $testResult = Test-NetConnection -ComputerName $machine -Port 5985 -ErrorAction Stop -WarningAction SilentlyContinue
            if ($testResult.TcpTestSucceeded -eq $true) {
                log-message "Test passed on winRM port for $($machine)"
                $testOutputofMachine = [pscustomobject]@{
                    Machine   = $machine.toUpper();
                    Source    = $testResult.SourceAddress;
                    Remote    = $testResult.RemoteAddress;
                    TimeStamp = $(Get-Date -Format 'yyyy-MM-dd hh:mm:ss:ffff');
                    winRMTest = $testResult.TcpTestSucceeded
                }
                $testOutput += $testOutputofMachine
            } else {
                log-message "Test failed on winRM port for $($machine)"
                $testOutputofMachine = [pscustomobject]@{
                    Machine   = $machine.toupper();
                    Source    = $testResult.SourceAddress;
                    Remote    = $testResult.RemoteAddress;
                    TimeStamp = $(Get-Date -Format 'yyyy-MM-dd hh:mm:ss:ffff');
                    winRMTest = $testResult.TcpTestSucceeded
                }
                $testOutput += $testOutputofMachine
            }
        }
    } catch {
        log-message -message "Error in function: $($Error[0].exception.message)"
        return "Function failed with error: $($Error[0].exception.message)"
    }
    return $testOutput | ft -AutoSize
}
