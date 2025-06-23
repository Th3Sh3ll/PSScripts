# Define subject details
$CommonName = "*.domain.com"
$Country = "ZA"
$Organization = "COMPANYNAME"
$Locality = "CPT"
$FriendlyName = $($env:COMPUTERNAME)
$OutputPath = "C:\Temp\$($env:COMPUTERNAME)_CSR.txt"

# Define SANs (Subject Alternative Names)
$sanEntries = "dns=$CommonName"

# Build the INF content
$infContent = @"
[Version]
Signature="$Windows NT$"

[NewRequest]
Subject = "CN=$CommonName, C=$Country, O=$Organization, L=$Locality"
FriendlyName = "$FriendlyName"
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = PKCS10
KeyUsage = 0xa0

[Extensions]
2.5.29.17 = "{text}"
_continue_ = "$sanEntries"
2.5.29.37 = "{text}"
_continue_ = "1.3.6.1.5.5.7.3.1,1.3.6.1.5.5.7.3.2"

[RequestAttributes]
CertificateTemplate = WebServer
"@

# Save INF to file
$infPath = "$env:TEMP\request.inf"
$infContent | Out-File -FilePath $infPath -Encoding ascii

# Generate CSR file
$csrOutputPath = "$env:TEMP\certreq.req"
certreq.exe -new $infPath $csrOutputPath

# Read CSR content
$base64Csr = Get-Content $csrOutputPath -Raw

# Save Base64 CSR to a .txt file
$base64Csr | Out-File -FilePath $OutputPath -Encoding ascii

Write-Host "CSR created and saved to: $OutputPath"
