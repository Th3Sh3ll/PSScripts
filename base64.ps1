<#
    Use this to set the environement variables for credentials
    This will encrypt with base64 and decode from base64 to build the credential to be used
#>
# encrypt and create variables
# user
$CU = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('username'))
[System.Environment]::SetEnvironmentVariable("CU", $CU, "Machine")  
# pass
$CP = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('Password'))
[System.Environment]::SetEnvironmentVariable("CP", $CP, "Machine")  

# decrypt and build credential
# to be used in script
$cUser   = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String("$($env:CU)"))
$cPassB64= [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String("$($env:CP)"))
$cPass   = $cPassB64 | ConvertTo-SecureString -AsPlainText -Force
$creds = [System.Management.Automation.PSCredential]::new($cUser, $cPass)
