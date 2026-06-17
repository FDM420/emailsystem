# Scripts — MXroute Automation

The "backend" of your email system. **The MXroute side is fully automated; DNS entry is manual** (each client's domain lives in their own registrar/Gmail account, so you paste the printed records there yourself).

## What's automated vs manual

| Step | How |
|---|---|
| Add domain to MXroute | ✅ automated (API) |
| Create mailboxes + passwords | ✅ automated (API) |
| Fetch MX/SPF/DKIM records | ✅ automated (API) |
| Generate welcome email + save credentials | ✅ automated |
| Update clients.csv | ✅ automated |
| **Add DNS records at the client's DNS host** | ✋ **manual** — script prints them, you paste |

## One-time setup

Edit `.config/mxroute.json` → paste your real API key in `"apiKey"`.

## Onboard a client (the main command)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Onboard-Client.ps1 `
  -Domain "acmeshop.com" -Mailboxes "info","sales" -ClientName "Acme Shop"
```

What it does:
1. Adds the domain to MXroute (if not already there)
2. Creates each mailbox with a strong 16-char password
3. Fetches the live DNS records for that domain (incl. the unique DKIM key)
4. Writes to `clients/<name>/`:
   - `dns-records.txt` — the records to paste at the client's DNS host
   - `credentials.json` — mailbox passwords (gitignored)
   - `welcome-email.txt` — ready to send
5. Appends a row to `clients.csv`
6. Prints the DNS records so you can paste them immediately

Optional flags: `-QuotaMB 500` (mailbox size), `-PricePerYear 80`, `-ClientContactEmail "x@y.com"`, `-ShowPasswords` (print passwords to console).

> **Passwords are NOT printed by default** — open `clients/<name>/credentials.json` to get them. This keeps them out of your terminal scrollback.

## After running: the manual DNS step

Paste the 4 printed records (MX ×2, SPF, DKIM, DMARC) at wherever the client's domain DNS is managed. Then:
- Check `mxtoolbox.com` → MX lookup → should show `tuesday.mxrouting.net`
- Send a test from the mailbox to `mail-tester.com` → aim 9–10/10

## Helper functions (interactive use)

```powershell
. .\scripts\MXroute.ps1     # load the module

Get-MXrouteDomains
Get-MXrouteMailboxes -Domain "acmeshop.com"
Add-MXrouteMailbox  -Domain "acmeshop.com" -User "info" -Password (New-StrongPassword)
Remove-MXrouteMailbox -Domain "acmeshop.com" -User "old"
Get-MXrouteDns      -Domain "acmeshop.com"   # full record set incl. DKIM
Get-Dns.ps1         -Domain "acmeshop.com"   # same, standalone
```

## Confirmed MXroute API endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/domains` | list domains |
| GET | `/domains/{d}` | domain info |
| POST | `/domains` | add domain |
| GET | `/domains/{d}/dns` | MX/SPF/DKIM/verification |
| GET | `/domains/{d}/email-accounts` | list mailboxes |
| POST | `/domains/{d}/email-accounts` | create mailbox (`username,password,quota,limit`) |
| DELETE | `/domains/{d}/email-accounts/{user}` | delete mailbox |

## Parked: Hostinger.ps1

`Hostinger.ps1` is an **optional** helper for domains that happen to live in your
own Hostinger account (it can read/write their DNS via API). It is NOT part of the
standard flow because client domains are scattered across their own accounts.
Keep it for the occasional domain you fully control.
