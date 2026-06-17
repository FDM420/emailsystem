# New Client Onboarding Checklist (MXroute)

Use this every time you add a new business email client. Should take ~20 minutes per client once you're practiced.

## 1. Collect client info

- [ ] Client name / business name
- [ ] Domain (e.g. `client.com`)
- [ ] List of mailboxes the client wants (e.g. `info@`, `sales@`, `firstname@`)
- [ ] Optional: aliases / forwarding addresses
- [ ] Decide pricing tier (see `pricing.md`)

## 2. Set up the folder

- [ ] Copy `clients/_template/` → `clients/<clientname>/`
- [ ] Fill in `client-info.md` with everything above
- [ ] Add row to `clients.csv` with status = `pending`

## 3. Add the domain to MXroute

- [ ] Go to https://panel.mxroute.com/domains.php → click **Add Domain**
- [ ] Type the client's domain (no http://, no www.)
- [ ] MXroute will show a verification TXT record like:
      Name: `_da-verify-<hash>`
      Value: `domain-verified`
- [ ] Save this TXT record in `clients/<clientname>/dns-records.txt`
- [ ] Add the TXT record at the domain's DNS host
- [ ] Wait 5–15 min, check propagation at https://dnschecker.org
- [ ] Click "Add Domain" again → should succeed
- [ ] (Optional) delete the `_da-verify` TXT record after success — no longer needed

## 4. Enable DKIM in DirectAdmin

- [ ] Log in to DirectAdmin: `https://tuesday.mxrouting.net:2222` (credentials from MXroute welcome email)
- [ ] Email Manager → DKIM Management
- [ ] Select the new domain → Enable DKIM
- [ ] Copy the generated DKIM TXT record (selector name + value)

## 5. Set the production DNS records

- [ ] At the domain's DNS host, add ALL of these (see `dns-mxroute.txt` for full reference):
  - [ ] **MX** `@` → priority 10 → `tuesday.mxrouting.net.`
  - [ ] **TXT (SPF)** `@` → `v=spf1 include:mxlogin.com -all`
  - [ ] **TXT (DKIM)** `<selector>._domainkey` → `<value from DirectAdmin>`
  - [ ] **TXT (DMARC)** `_dmarc` → `v=DMARC1; p=quarantine; rua=mailto:dmarc@<domain>; pct=100; adkim=s; aspf=s`
- [ ] (Optional) CNAME `autodiscover` → `tuesday.mxrouting.net.`
- [ ] (Optional) CNAME `autoconfig` → `tuesday.mxrouting.net.`
- [ ] Wait 10–30 min for propagation
- [ ] Verify in DirectAdmin if it offers a DNS check, or use https://mxtoolbox.com

## 6. Create mailboxes

- [ ] In DirectAdmin → Email Manager → Email Accounts → Create Account
- [ ] For each mailbox: username, strong temporary password, quota (start with 1024 MB / 1 GB)
- [ ] Save the temporary password securely (1Password / Bitwarden / KeePass / etc.)
- [ ] Tell client to change it on first login

## 7. Test before handing over

- [ ] Log in at https://tuesday.mxrouting.net/webmail with the new mailbox → confirm it opens
- [ ] Send a test email from a Gmail account TO the new mailbox → should arrive in inbox (not spam)
- [ ] Send a test FROM the new mailbox to https://www.mail-tester.com → aim for 9–10/10
- [ ] If score is low: re-check DKIM and SPF records, give DNS another 30 min

## 8. Hand off to client

- [ ] Use `templates/welcome-email.md` — fill in placeholders
- [ ] Send to client's personal email with:
  - Webmail URL (https://tuesday.mxrouting.net/webmail)
  - Username (full email address)
  - Temporary password
  - IMAP/SMTP settings for Outlook/Gmail/iPhone

## 9. Final bookkeeping

- [ ] Update `clients.csv`: status = `active`, fill in renewal date
- [ ] Add reminder in your calendar/CRM for renewal (1 year out)
- [ ] If billing: send first invoice
