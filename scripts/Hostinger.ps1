# Hostinger API wrapper module
# Loads credentials from ..\.config\hostinger.json (never hardcodes them)
# Confirmed endpoints (DNS Zone API):
#   GET    /api/dns/v1/zones/{domain}           -> read records
#   PUT    /api/dns/v1/zones/{domain}           -> create/update records
#   DELETE /api/dns/v1/zones/{domain}           -> delete records
#   POST   /api/dns/v1/zones/{domain}/validate  -> validate before applying
# Auth: Authorization: Bearer <token>

function Get-HostingerConfig {
    $configPath = Join-Path $PSScriptRoot "..\.config\hostinger.json"
    if (-not (Test-Path $configPath)) {
        throw "Config not found at $configPath. Create it with baseUrl + apiToken."
    }
    $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
    if ($cfg.apiToken -eq "PASTE_YOUR_HOSTINGER_TOKEN_HERE" -or [string]::IsNullOrWhiteSpace($cfg.apiToken)) {
        throw "Hostinger API token not set in $configPath."
    }
    return $cfg
}

function Invoke-HostingerApi {
    param(
        [Parameter(Mandatory)][ValidateSet("GET","POST","PUT","DELETE")][string]$Method,
        [Parameter(Mandatory)][string]$Endpoint,
        [object]$Body = $null
    )
    $cfg = Get-HostingerConfig
    $headers = @{
        "Authorization" = "Bearer $($cfg.apiToken)"
        "Accept"        = "application/json"
    }
    $params = @{
        Uri         = "$($cfg.baseUrl)$Endpoint"
        Method      = $Method
        Headers     = $headers
        ContentType = "application/json"
    }
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
    }
    try {
        return Invoke-RestMethod @params
    } catch {
        Write-Host ""
        Write-Host "Hostinger API call failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $respBody = $reader.ReadToEnd()
                Write-Host "Response body:" -ForegroundColor Yellow
                Write-Host $respBody
            } catch {}
        }
        throw
    }
}

# -----------------------------------------------------------------------------
# DNS Zone functions
# -----------------------------------------------------------------------------

function Get-HostingerDns {
    param([Parameter(Mandatory)][string]$Domain)
    Invoke-HostingerApi -Method GET -Endpoint "/api/dns/v1/zones/$Domain"
}

function Test-HostingerConnection {
    param([string]$Domain = "pakzirve.com")
    Write-Host "Testing Hostinger API (reading DNS zone for $Domain)..." -ForegroundColor Cyan
    try {
        $z = Get-HostingerDns -Domain $Domain
        Write-Host "Hostinger API connection OK" -ForegroundColor Green
        Write-Host ""
        Write-Host "Current DNS zone for $Domain :" -ForegroundColor Cyan
        $z | ConvertTo-Json -Depth 8
        return $true
    } catch {
        Write-Host "Connection test failed" -ForegroundColor Red
        return $false
    }
}

Write-Host "Hostinger.ps1 loaded. Available commands:" -ForegroundColor Green
Write-Host "  Test-HostingerConnection [-Domain 'example.com']"
Write-Host "  Get-HostingerDns -Domain 'example.com'"
