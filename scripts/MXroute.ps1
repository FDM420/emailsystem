# MXroute API wrapper module
# Loads credentials from ..\.config\mxroute.json (never hardcodes them)
# Usage:
#   . .\scripts\MXroute.ps1
#   Test-MXrouteConnection
#   Get-MXrouteDomains
#   Add-MXrouteDomain -Domain "example.com"
#   Add-MXrouteMailbox -Domain "example.com" -User "info" -Password "..."
#   Get-MXrouteDkim -Domain "example.com"

# -----------------------------------------------------------------------------
# Config loader
# -----------------------------------------------------------------------------

function Get-MXrouteConfig {
    $configPath = Join-Path $PSScriptRoot "..\.config\mxroute.json"
    if (-not (Test-Path $configPath)) {
        throw "Config not found at $configPath. Copy .config/mxroute.json from the template and fill in your credentials."
    }
    $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
    if ($cfg.apiKey -eq "PASTE_YOUR_API_KEY_HERE" -or [string]::IsNullOrWhiteSpace($cfg.apiKey)) {
        throw "API key not set in $configPath. Edit the file and paste your real key."
    }
    return $cfg
}

# -----------------------------------------------------------------------------
# Core API call
# -----------------------------------------------------------------------------

function Invoke-MXrouteApi {
    param(
        [Parameter(Mandatory)][ValidateSet("GET","POST","PUT","DELETE")][string]$Method,
        [Parameter(Mandatory)][string]$Endpoint,
        [object]$Body = $null
    )

    $cfg = Get-MXrouteConfig

    $headers = @{
        "X-Server"   = $cfg.server
        "X-Username" = $cfg.username
        "X-API-Key"  = $cfg.apiKey
    }

    $params = @{
        Uri         = "https://api.mxroute.com$Endpoint"
        Method      = $Method
        Headers     = $headers
        ContentType = "application/json"
    }
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
    }

    try {
        return Invoke-RestMethod @params
    } catch {
        Write-Host ""
        Write-Host "API call failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                Write-Host "Response body:" -ForegroundColor Yellow
                Write-Host $body
            } catch {}
        }
        throw
    }
}

# -----------------------------------------------------------------------------
# Public functions
# -----------------------------------------------------------------------------

function Test-MXrouteConnection {
    Write-Host "Testing MXroute API connection..." -ForegroundColor Cyan
    try {
        $r = Invoke-MXrouteApi -Method GET -Endpoint "/domains"
        Write-Host "API connection OK" -ForegroundColor Green
        Write-Host ""
        Write-Host "Domains on your account:" -ForegroundColor Cyan
        $r | ConvertTo-Json -Depth 5
        return $true
    } catch {
        Write-Host "Connection test failed" -ForegroundColor Red
        return $false
    }
}

function Get-MXrouteDomains {
    Invoke-MXrouteApi -Method GET -Endpoint "/domains"
}

function Add-MXrouteDomain {
    param([Parameter(Mandatory)][string]$Domain)
    Write-Host "Adding domain $Domain to MXroute..." -ForegroundColor Cyan
    Invoke-MXrouteApi -Method POST -Endpoint "/domains" -Body @{ domain = $Domain }
}

function Remove-MXrouteDomain {
    param([Parameter(Mandatory)][string]$Domain)
    Invoke-MXrouteApi -Method DELETE -Endpoint "/domains/$Domain"
}

function Get-MXrouteMailboxes {
    # Confirmed endpoint: /domains/{domain}/email-accounts
    param([Parameter(Mandatory)][string]$Domain)
    Invoke-MXrouteApi -Method GET -Endpoint "/domains/$Domain/email-accounts"
}

function Add-MXrouteMailbox {
    param(
        [Parameter(Mandatory)][string]$Domain,
        [Parameter(Mandatory)][string]$User,
        [Parameter(Mandatory)][string]$Password,
        [int]$QuotaMB = 1024,
        [int]$SendLimit = 200
    )
    Write-Host "Creating mailbox $User@$Domain..." -ForegroundColor Cyan
    Invoke-MXrouteApi -Method POST -Endpoint "/domains/$Domain/email-accounts" -Body @{
        username = $User
        password = $Password
        quota    = $QuotaMB
        limit    = $SendLimit
    }
}

function Remove-MXrouteMailbox {
    param(
        [Parameter(Mandatory)][string]$Domain,
        [Parameter(Mandatory)][string]$User
    )
    Write-Host "Deleting mailbox $User@$Domain..." -ForegroundColor Cyan
    Invoke-MXrouteApi -Method DELETE -Endpoint "/domains/$Domain/email-accounts/$User"
}

function Get-MXrouteDns {
    # Returns the full DNS record set (MX, SPF, DKIM, verification) for a domain.
    # DKIM lives inside this response under .data.dkim (selector is "x").
    param([Parameter(Mandatory)][string]$Domain)
    Invoke-MXrouteApi -Method GET -Endpoint "/domains/$Domain/dns"
}

function Get-MXrouteDkim {
    # Convenience: pull just the DKIM record out of the DNS response.
    param([Parameter(Mandatory)][string]$Domain)
    (Get-MXrouteDns -Domain $Domain).data.dkim
}

function Get-MXrouteDomainInfo {
    param([Parameter(Mandatory)][string]$Domain)
    Invoke-MXrouteApi -Method GET -Endpoint "/domains/$Domain"
}

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

function New-StrongPassword {
    param([int]$Length = 16)
    $chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*'
    -join (1..$Length | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

Write-Host "MXroute.ps1 loaded. Available commands:" -ForegroundColor Green
Write-Host "  Test-MXrouteConnection"
Write-Host "  Get-MXrouteDomains"
Write-Host "  Add-MXrouteDomain -Domain 'example.com'"
Write-Host "  Add-MXrouteMailbox -Domain 'example.com' -User 'info' -Password '...'"
Write-Host "  Get-MXrouteDns -Domain 'example.com'      (full record set incl. DKIM)"
Write-Host "  Get-MXrouteDkim -Domain 'example.com'     (just the DKIM record)"
Write-Host "  Get-MXrouteDomainInfo -Domain 'example.com'"
Write-Host "  New-StrongPassword"
