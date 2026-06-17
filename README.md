# Business Email System

Offer cheap business email to clients using **MXroute** as the backend. The MXroute
side is **automated via API**; DNS entry is **manual** (each client domain lives in
their own registrar/Gmail account).

## Account info

- **Provider:** MXroute — Lite plan (~$45/yr, unlimited domains, 10GB total)
- **Server:** `tuesday.mxrouting.net`
- **Account panel:** https://panel.mxroute.com (billing, add domains)
- **DirectAdmin:** `https://tuesday.mxrouting.net:2222` (manual UI — rarely needed now)
- **Webmail:** https://tuesday.mxrouting.net/webmail
- **API:** `https://api.mxroute.com` (key in `.config/mxroute.json`)

## The onboarding flow

```
                  ┌─────────────────────────────────────────────┐
   ONE COMMAND →  │  scripts\Onboard-Client.ps1                  │
                  │  -Domain x.com -Mailboxes "info","sales"     │
                  └───────────────────┬─────────────────────────┘
                                      │  (MXroute API)
        ┌─────────────────────────────┼─────────────────────────────┐
        ▼                             ▼                             ▼
   add domain               create mailboxes              fetch MX/SPF/DKIM
   to MXroute               (auto passwords)              for this domain
        │                             │                             │
        └─────────────────────────────┴─────────────────────────────┘
                                      │
                                      ▼
                   writes clients/<name>/ : dns-records.txt,
                   credentials.json, welcome-email.txt  + clients.csv
                                      │
                                      ▼
              ✋ YOU: paste the 4 DNS records at the client's DNS host
                                      │
                                      ▼
                       test send/receive → send welcome email
```

## Add a new client (the whole job)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Onboard-Client.ps1 `
  -Domain "clientdomain.com" -Mailboxes "info","sales" -ClientName "Client Name"
```

Then paste the printed DNS records at the client's DNS host. See
[scripts/README.md](scripts/README.md) for full details and flags.

## Folder map

| Path | What it is |
|---|---|
| `scripts/` | The automation (run `Onboard-Client.ps1` per client) |
| `.config/` | API keys — **never commit/share** (gitignored) |
| `clients.csv` | Master list of clients/domains/status |
| `clients/<name>/` | Per-client: dns-records.txt, credentials.json, welcome-email.txt |
| `pricing.md` | Cost vs. what you charge |
| `templates/` | Reference templates (the script auto-fills per client now) |

## Security

API keys live only in `.config/` (gitignored). Never paste keys/passwords into
chat, screenshots, or commits. Rotate the MXroute key and Hostinger token that
were shared during setup once everything is stable (see `.config/README.md`).

## Cost & pricing

See [pricing.md](pricing.md). Raw cost ≈ $45/yr for ALL clients; charge each
client $30–150/yr. ~99% margin.
