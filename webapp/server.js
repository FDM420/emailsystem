// Email System admin portal — Express backend.
// Wraps the MXroute API and serves the admin UI. Password-protected.
//
// Required env vars (set in Railway):
//   MXROUTE_SERVER, MXROUTE_USERNAME, MXROUTE_API_KEY  — MXroute API creds
//   ADMIN_PASSWORD                                     — login password for the portal
//   SESSION_SECRET (optional)                          — HMAC secret for the auth cookie
//   PORT (provided by Railway automatically)

import express from "express";
import cookieParser from "cookie-parser";
import crypto from "crypto";
import path from "path";
import { fileURLToPath } from "url";
import * as mx from "./lib/mxroute.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
app.use(express.json());
app.use(cookieParser());

const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "";
const SECRET =
  process.env.SESSION_SECRET || crypto.randomBytes(32).toString("hex");
const COOKIE = "es_session";

// --- Auth helpers ---------------------------------------------------------

function sign(value) {
  const h = crypto.createHmac("sha256", SECRET).update(value).digest("hex");
  return `${value}.${h}`;
}
function verify(token) {
  if (!token || typeof token !== "string") return false;
  const i = token.lastIndexOf(".");
  if (i < 0) return false;
  const value = token.slice(0, i);
  const sig = token.slice(i + 1);
  const expected = crypto.createHmac("sha256", SECRET).update(value).digest("hex");
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b) ? value : false;
}
function timingSafeEqualStr(a, b) {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ab.length !== bb.length) return false;
  return crypto.timingSafeEqual(ab, bb);
}

function requireAuth(req, res, next) {
  const token = req.cookies?.[COOKIE];
  if (verify(token)) return next();
  return res.status(401).json({ error: "Not authenticated" });
}

// --- Auth routes ----------------------------------------------------------

app.post("/api/login", (req, res) => {
  const { password } = req.body || {};
  if (!ADMIN_PASSWORD) {
    return res.status(500).json({ error: "ADMIN_PASSWORD not configured on server." });
  }
  if (!password || !timingSafeEqualStr(String(password), ADMIN_PASSWORD)) {
    return res.status(401).json({ error: "Wrong password" });
  }
  const token = sign(`admin:${Date.now()}`);
  res.cookie(COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    maxAge: 1000 * 60 * 60 * 12, // 12h
  });
  res.json({ ok: true });
});

app.post("/api/logout", (req, res) => {
  res.clearCookie(COOKIE);
  res.json({ ok: true });
});

app.get("/api/me", (req, res) => {
  if (verify(req.cookies?.[COOKIE])) return res.json({ authed: true });
  res.status(401).json({ authed: false });
});

// --- API routes (protected) ----------------------------------------------

const wrap = (fn) => async (req, res) => {
  try {
    await fn(req, res);
  } catch (e) {
    console.error(e);
    res.status(e.status || 500).json({ error: e.message || "Server error" });
  }
};

app.get(
  "/api/domains",
  requireAuth,
  wrap(async (req, res) => {
    const domains = await mx.listDomains();
    res.json({ domains });
  })
);

app.get(
  "/api/domains/:domain/mailboxes",
  requireAuth,
  wrap(async (req, res) => {
    const mailboxes = await mx.listMailboxes(req.params.domain);
    res.json({ mailboxes });
  })
);

app.get(
  "/api/domains/:domain/dns",
  requireAuth,
  wrap(async (req, res) => {
    const dns = await mx.getDnsRecords(req.params.domain);
    res.json(dns);
  })
);

// Provision: add domain if missing, create requested mailboxes, return
// generated passwords + DNS records to paste manually.
app.post(
  "/api/provision",
  requireAuth,
  wrap(async (req, res) => {
    const { domain, mailboxes = [], quotaMB = 1024 } = req.body || {};
    if (!domain) return res.status(400).json({ error: "domain is required" });

    const cleanDomain = String(domain).trim().toLowerCase();
    const result = { domain: cleanDomain, created: [], skipped: [], errors: [] };

    // 1. Ensure domain exists on the account
    const exists = await mx.domainExists(cleanDomain);
    if (!exists) {
      try {
        await mx.addDomain(cleanDomain);
        result.domainAdded = true;
      } catch (e) {
        result.domainAdded = false;
        result.errors.push(`Add domain: ${e.message}`);
      }
    } else {
      result.domainAdded = false;
    }

    // 2. Existing mailboxes (to skip duplicates)
    let existing = [];
    try {
      existing = (await mx.listMailboxes(cleanDomain)).map((m) => m.username);
    } catch {}

    // 3. Create mailboxes
    for (let raw of mailboxes) {
      let user = String(raw).trim().toLowerCase().replace(/@.*$/, "").replace(/[^a-z0-9._-]/g, "");
      if (!user) continue;
      if (existing.includes(user)) {
        result.skipped.push(`${user}@${cleanDomain}`);
        continue;
      }
      const password = mx.strongPassword(16);
      try {
        await mx.createMailbox(cleanDomain, user, password, quotaMB);
        result.created.push({ email: `${user}@${cleanDomain}`, password });
      } catch (e) {
        result.errors.push(`${user}@${cleanDomain}: ${e.message}`);
      }
    }

    // 4. DNS records to paste manually
    try {
      const dns = await mx.getDnsRecords(cleanDomain);
      result.dns = dns.records;
      result.verification = dns.verification;
    } catch (e) {
      result.dns = [];
      result.errors.push(`DNS fetch: ${e.message}`);
    }

    res.json(result);
  })
);

app.delete(
  "/api/domains/:domain/mailboxes/:user",
  requireAuth,
  wrap(async (req, res) => {
    await mx.deleteMailbox(req.params.domain, req.params.user);
    res.json({ ok: true });
  })
);

// --- Static frontend ------------------------------------------------------

app.use(express.static(path.join(__dirname, "public")));
app.get("*", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Email System portal running on port ${PORT}`);
});
