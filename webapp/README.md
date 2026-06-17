# Email System — Admin Portal

Web frontend + backend for provisioning business email via the MXroute API.
A password-protected admin dashboard: list domains, view mailboxes & DNS, and
provision new clients in one form. DNS entry remains manual (the app shows you
the exact records to paste at the client's DNS host).

## Stack
- Node.js + Express (single service, serves both API and static frontend)
- Vanilla JS frontend (no build step)
- Stateless — MXroute is the source of truth (no database)

## Run locally
```bash
cd webapp
npm install
cp .env.example .env   # then edit .env with your MXroute creds + ADMIN_PASSWORD
node --env-file=.env server.js
# open http://localhost:3000
```

## Environment variables
| Var | Purpose |
|---|---|
| `MXROUTE_SERVER` | e.g. `tuesday.mxrouting.net` |
| `MXROUTE_USERNAME` | MXroute API username |
| `MXROUTE_API_KEY` | MXroute API key |
| `ADMIN_PASSWORD` | password to log into the portal |
| `SESSION_SECRET` | (optional) HMAC secret for the auth cookie |
| `PORT` | set automatically by Railway |

## Deploy (Railway)
The service is built with Nixpacks and started via `npm start`. Set the env
vars above in the Railway service, then deploy. See the root project notes for
the exact CLI commands used.

## Security notes
- The portal is internet-facing — `ADMIN_PASSWORD` is the only gate. Use a long,
  unique password.
- Never commit `.env`. Secrets live in Railway service variables.
- Mailbox passwords are generated server-side and shown once in the UI; copy them
  immediately into the client's welcome email.

## API endpoints
| Method | Path | Purpose |
|---|---|---|
| POST | `/api/login` | log in (`{password}`) |
| POST | `/api/logout` | log out |
| GET | `/api/me` | auth check |
| GET | `/api/domains` | list domains |
| GET | `/api/domains/:domain/mailboxes` | list mailboxes |
| GET | `/api/domains/:domain/dns` | DNS records to paste |
| POST | `/api/provision` | add domain + mailboxes, return passwords + DNS |
| DELETE | `/api/domains/:domain/mailboxes/:user` | delete a mailbox |
