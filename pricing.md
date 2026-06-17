# Pricing & Margins

## Your cost

- **MXroute Lite plan:** ~$45/year flat (unlimited domains, 10GB storage total across all mailboxes)
- **Server:** `tuesday.mxrouting.net` (your assigned server)
- **Per-client cost:** at 100 clients/year → ~$0.45/client. Effectively free.

## Suggested client pricing

Pick a tier based on what the local market accepts. These are common reseller prices:

| Tier | Mailboxes | Charge client | Yearly revenue per client |
|---|---|---|---|
| Starter | 1 mailbox | $3/month or $30/year | $30 |
| Business | 3 mailboxes | $8/month or $80/year | $80 |
| Pro | 5+ mailboxes | $15/month or $150/year | $150 |

## Yearly math (example: 100 clients, mix of tiers)

- 50 × Starter ($30) = $1,500
- 40 × Business ($80) = $3,200
- 10 × Pro ($150) = $1,500
- **Gross revenue:** ~$6,200/year
- **Cost:** $45/year (MXroute) + domain costs (separate)
- **Net margin on email service alone:** ~99%

## Storage watch (the one MXroute Lite constraint)

MXroute Lite gives **10GB total** across all mailboxes on your account. For most
small business clients (light email use, no huge attachments), 10GB easily
covers ~50+ active mailboxes. Watch usage in DirectAdmin -> Email Accounts.

If you outgrow it:
- Upgrade to MXroute Standard (~$80/yr, 40GB) or higher
- Or set per-mailbox quotas in DirectAdmin to prevent any one client from hogging

## When to revisit pricing / provider

- If you outgrow 10GB and need to step up plans → re-do this math at the new cost
- If a client wants 10+ mailboxes or 100GB+ storage → consider charging premium or putting them on Zoho/Migadu directly
- If deliverability issues hit → check DKIM/DMARC first (DirectAdmin makes this easy)

## What to bundle vs. charge separately

- **Bundle into main service contract:** for clients on retainer, include 1–3 mailboxes free.
- **Charge as add-on:** for one-off domain clients who want email, sell as a yearly subscription.
