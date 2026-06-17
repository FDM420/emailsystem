# Fetch and pretty-print the full DNS record set for a domain from MXroute.
# Usage: .\scripts\Get-Dns.ps1 -Domain pakzirve.com
param([Parameter(Mandatory)][string]$Domain)
. "$PSScriptRoot\MXroute.ps1"

$dns = Invoke-MXrouteApi -Method GET -Endpoint "/domains/$Domain/dns"
$dns.data | ConvertTo-Json -Depth 10
