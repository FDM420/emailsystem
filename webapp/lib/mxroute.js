// MXroute REST API client.
// Reads credentials from environment variables (set in Railway / local .env):
//   MXROUTE_SERVER, MXROUTE_USERNAME, MXROUTE_API_KEY
// Node 18+ has global fetch, so no extra HTTP dependency is needed.

import crypto from "crypto";

const BASE = "https://api.mxroute.com";

function headers() {
  const server = process.env.MXROUTE_SERVER;
  const username = process.env.MXROUTE_USERNAME;
  const apiKey = process.env.MXROUTE_API_KEY;
  if (!server || !username || !apiKey) {
    throw new Error(
      "MXroute credentials missing. Set MXROUTE_SERVER, MXROUTE_USERNAME, MXROUTE_API_KEY."
    );
  }
  return {
    "X-Server": server,
    "X-Username": username,
    "X-API-Key": apiKey,
    "Content-Type": "application/json",
    Accept: "application/json",
  };
}

async function api(method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: headers(),
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await res.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }

  if (!res.ok) {
    const msg =
      (data && data.message) || (typeof data === "string" && data) ||
      `MXroute API ${res.status}`;
    const err = new Error(msg);
    err.status = res.status;
    err.body = data;
    throw err;
  }
  return data;
}

// --- Domains -------------------------------------------------------------

export async function listDomains() {
  const r = await api("GET", "/domains");
  return r?.data ?? [];
}

export async function getDomainInfo(domain) {
  const r = await api("GET", `/domains/${encodeURIComponent(domain)}`);
  return r?.data ?? null;
}

export async function domainExists(domain) {
  try {
    await getDomainInfo(domain);
    return true;
  } catch (e) {
    if (e.status === 404 || e.status === 403) return false;
    throw e;
  }
}

export async function addDomain(domain) {
  return api("POST", "/domains", { domain });
}

// --- DNS -----------------------------------------------------------------

export async function getDnsRaw(domain) {
  const r = await api("GET", `/domains/${encodeURIComponent(domain)}/dns`);
  return r?.data ?? null;
}

// Returns a flat, display-friendly list of the records to paste at the DNS host.
export async function getDnsRecords(domain) {
  const dns = await getDnsRaw(domain);
  const records = [];

  for (const mx of dns.mx_records ?? []) {
    records.push({
      type: "MX",
      name: "@",
      priority: mx.priority,
      value: mx.hostname,
    });
  }
  if (dns.spf) {
    records.push({ type: "TXT", name: "@", value: dns.spf.value, label: "SPF" });
  }
  if (dns.dkim) {
    records.push({
      type: "TXT",
      name: dns.dkim.name,
      value: String(dns.dkim.value).replace(/^"|"$/g, ""),
      label: "DKIM",
    });
  }
  // DMARC is not auto-provided by MXroute; recommend a sensible default.
  records.push({
    type: "TXT",
    name: "_dmarc",
    value: `v=DMARC1; p=quarantine; rua=mailto:dmarc@${domain}; pct=100; adkim=s; aspf=s`,
    label: "DMARC",
  });

  return { records, verification: dns.verification ?? null };
}

// --- Mailboxes -----------------------------------------------------------

export async function listMailboxes(domain) {
  const r = await api(
    "GET",
    `/domains/${encodeURIComponent(domain)}/email-accounts`
  );
  return r?.data ?? [];
}

export async function createMailbox(domain, username, password, quotaMB = 1024, sendLimit = 200) {
  return api("POST", `/domains/${encodeURIComponent(domain)}/email-accounts`, {
    username,
    password,
    quota: quotaMB,
    limit: sendLimit,
  });
}

export async function deleteMailbox(domain, username) {
  return api(
    "DELETE",
    `/domains/${encodeURIComponent(domain)}/email-accounts/${encodeURIComponent(username)}`
  );
}

// --- Helpers -------------------------------------------------------------

export function strongPassword(length = 16) {
  const chars =
    "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*";
  const bytes = crypto.randomBytes(length);
  let out = "";
  for (let i = 0; i < length; i++) out += chars[bytes[i] % chars.length];
  return out;
}
