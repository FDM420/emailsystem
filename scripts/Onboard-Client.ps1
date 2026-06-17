<#
.SYNOPSIS
  Automated client onboarding for the MXroute side. DNS entry stays manual.

.DESCRIPTION
  One command does the whole MXroute side:
    1. Ensures the domain exists on your MXroute account (adds it if missing).
    2. Creates the requested mailbox(es) with strong auto-generated passwords.
    3. Fetches the live DNS records (MX/SPF/DKIM) from MXroute for THIS domain.
    4. Writes everything to clients/<name>/:
         - dns-records.txt   (the records you paste at the client's DNS host)
         - credentials.json  (mailbox passwords - gitignored)
         - welcome-email.txt (ready to send the client)
    5. Appends/updates the row in clients.csv.

  Passwords are NEVER printed to the console by default (use -ShowPasswords to
  override). Open clients/<name>/credentials.json or welcome-email.txt to get them.

  DNS is intentionally manual: each client's domain lives in their own registrar/
  Gmail account, so you paste the printed records there yourself.

.EXAMPLE
  .\scripts\Onboard-Client.ps1 -Domain "acmeshop.com" -Mailboxes "info","sales" -ClientName "Acme Shop"

.EXAMPLE
  .\scripts\Onboard-Client.ps1 -Domain "acmeshop.com" -Mailboxes "info" -QuotaMB 500 -ShowPasswords
#>

param(
    [Parameter(Mandatory)][string]$Domain,
    [Parameter(Mandatory)][string[]]$Mailboxes,
    [string]$ClientName,
    [int]$QuotaMB = 1024,
    [int]$SendLimit = 200,
    [string]$ClientContactEmail = "",
    [int]$PricePerYear = 0,
    [switch]$ShowPasswords
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\MXroute.ps1"

$Domain = $Domain.Trim().ToLower()
if (-not $ClientName) { $ClientName = $Domain.Split('.')[0] }
$folderName = ($ClientName -replace '[^\w\-]', '_').ToLower()
$clientDir  = Join-Path $PSScriptRoot "..\clients\$folderName"
if (-not (Test-Path $clientDir)) { New-Item -ItemType Directory -Path $clientDir -Force | Out-Null }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " ONBOARDING: $ClientName  ($Domain)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Step 1: Ensure the domain is on the MXroute account
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[1/5] Checking domain on MXroute..." -ForegroundColor Yellow
$domainExists = $false
try {
    $info = Get-MXrouteDomainInfo -Domain $Domain
    if ($info.success) { $domainExists = $true; Write-Host "      Domain already on account." -ForegroundColor Green }
} catch {
    $domainExists = $false
}

if (-not $domainExists) {
    Write-Host "      Domain not found. Adding it now..." -ForegroundColor Yellow
    try {
        $add = Add-MXrouteDomain -Domain $Domain
        Write-Host "      Add response:" -ForegroundColor Green
        $add | ConvertTo-Json -Depth 6
        # If MXroute requires DNS ownership verification, surface the token.
        $verify = $null
        try { $verify = (Get-MXrouteDns -Domain $Domain).data.verification } catch {}
        if ($verify) {
            Write-Host ""
            Write-Host "      >>> DOMAIN VERIFICATION REQUIRED <<<" -ForegroundColor Magenta
            Write-Host "      Add this TXT record at the client's DNS host, wait 5-15 min, then re-run:" -ForegroundColor Magenta
            Write-Host "        Type:  TXT" -ForegroundColor Magenta
            Write-Host "        Name:  $($verify.name)" -ForegroundColor Magenta
            Write-Host "        Value: $($verify.value)" -ForegroundColor Magenta
        }
    } catch {
        Write-Host "      Could not add domain automatically. Add it in panel.mxroute.com, then re-run." -ForegroundColor Red
        throw
    }
}

# ---------------------------------------------------------------------------
# Step 2: Create mailboxes
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/5] Creating mailboxes..." -ForegroundColor Yellow
$existing = @()
try { $existing = (Get-MXrouteMailboxes -Domain $Domain).data | ForEach-Object { $_.username } } catch {}

$created = @()
foreach ($user in $Mailboxes) {
    $user = $user.Trim().TrimEnd('@').ToLower()
    if ($user -like "*@*") { $user = $user.Split('@')[0] }
    if ($existing -contains $user) {
        Write-Host "      $user@$Domain already exists - skipping." -ForegroundColor DarkYellow
        continue
    }
    $pw = New-StrongPassword -Length 16
    try {
        Add-MXrouteMailbox -Domain $Domain -User $user -Password $pw -QuotaMB $QuotaMB -SendLimit $SendLimit | Out-Null
        Write-Host "      Created $user@$Domain" -ForegroundColor Green
        $created += [pscustomobject]@{ email = "$user@$Domain"; password = $pw; quota_mb = $QuotaMB }
    } catch {
        Write-Host "      FAILED to create $user@$Domain : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Save credentials (gitignored)
if ($created.Count -gt 0) {
    $credPath = Join-Path $clientDir "credentials.json"
    $created | ConvertTo-Json -Depth 5 | Out-File -FilePath $credPath -Encoding utf8
    Write-Host "      Credentials saved to $credPath" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Step 3: Fetch live DNS records from MXroute
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/5] Fetching DNS records from MXroute..." -ForegroundColor Yellow
$dns = (Get-MXrouteDns -Domain $Domain).data
$dkimName  = $dns.dkim.name
$dkimValue = ($dns.dkim.value -replace '^"','' -replace '"$','')
$spfValue  = $dns.spf.value
Write-Host "      Got MX, SPF, and DKIM." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Step 4: Write the DNS records sheet (for manual entry)
# ---------------------------------------------------------------------------
$dnsLines = @()
$dnsLines += "DNS RECORDS FOR: $Domain"
$dnsLines += "Provider: MXroute (tuesday.mxrouting.net)"
$dnsLines += "Generated by Onboard-Client.ps1"
$dnsLines += ">>> Paste these at the client's DNS host. TXT values: no surrounding quotes."
$dnsLines += ""
$dnsLines += "[ ] MX  (add both)"
foreach ($mx in $dns.mx_records) {
    $dnsLines += "    Type=MX  Name=@  Priority=$($mx.priority)  Value=$($mx.hostname)"
}
$dnsLines += ""
$dnsLines += "[ ] SPF"
$dnsLines += "    Type=TXT  Name=@  Value=$spfValue"
$dnsLines += ""
$dnsLines += "[ ] DKIM"
$dnsLines += "    Type=TXT  Name=$dkimName  Value=$dkimValue"
$dnsLines += ""
$dnsLines += "[ ] DMARC (recommended)"
$dnsLines += "    Type=TXT  Name=_dmarc  Value=v=DMARC1; p=quarantine; rua=mailto:dmarc@$Domain; pct=100; adkim=s; aspf=s"
$dnsLines += ""
$dnsLines += "VERIFY: mxtoolbox.com MX lookup -> tuesday.mxrouting.net ; mail-tester.com score 9-10/10"
$dnsPath = Join-Path $clientDir "dns-records.txt"
$dnsLines -join "`r`n" | Out-File -FilePath $dnsPath -Encoding utf8
Write-Host ""
Write-Host "[4/5] DNS sheet written to $dnsPath" -ForegroundColor Yellow

# ---------------------------------------------------------------------------
# Step 5: Welcome email + CSV
# ---------------------------------------------------------------------------
$boxList = ($created | ForEach-Object { "  - $($_.email)" }) -join "`r`n"
if (-not $boxList) { $boxList = ($Mailboxes | ForEach-Object { "  - $_@$Domain" }) -join "`r`n" }
$firstBox = if ($created.Count -gt 0) { $created[0].email } else { "$($Mailboxes[0])@$Domain" }

$welcome = @"
Subject: Your business email is ready - $Domain

Hi,

Your business email on $Domain is now live. Login details:

WEBMAIL (easiest):
  URL:      https://tuesday.mxrouting.net/webmail
  Username: your full email address (e.g. $firstBox)
  Password: see below (please change it on first login)

MAILBOXES:
$boxList

(Passwords are in credentials.json - copy each into this email per mailbox before sending.)

USE IN OUTLOOK / GMAIL APP / iPhone:
  Incoming (IMAP): tuesday.mxrouting.net  port 993  SSL/TLS
  Outgoing (SMTP): tuesday.mxrouting.net  port 465  SSL/TLS
  Username: full email address   Password: mailbox password
  (If 465 is blocked, try 587 or 2525.)

Tip: check Spam for the first week while the domain builds reputation.

Best,
Your Name
"@
$welcomePath = Join-Path $clientDir "welcome-email.txt"
$welcome | Out-File -FilePath $welcomePath -Encoding utf8

# Append/refresh clients.csv row
$csvPath = Join-Path $PSScriptRoot "..\clients.csv"
$mailboxField = ($Mailboxes -join "; ")
$row = "$ClientName,$Domain,$mailboxField,MXroute,2026-06-18,,$PricePerYear,active,onboarded via script"
Add-Content -Path $csvPath -Value $row -Encoding utf8

Write-Host ""
Write-Host "[5/5] Welcome email -> $welcomePath ; clients.csv updated." -ForegroundColor Yellow

# ---------------------------------------------------------------------------
# Summary + manual DNS reminder
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " DONE (MXroute side). NOW DO THE MANUAL DNS STEP:" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Get-Content $dnsPath | Write-Host
if ($ShowPasswords -and $created.Count -gt 0) {
    Write-Host ""
    Write-Host "PASSWORDS (shown because -ShowPasswords):" -ForegroundColor Magenta
    $created | ForEach-Object { Write-Host "  $($_.email)  =>  $($_.password)" }
}
Write-Host ""
Write-Host "Files in: $clientDir" -ForegroundColor Cyan
