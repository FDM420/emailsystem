// Email System admin portal — frontend logic (vanilla JS).

const $ = (id) => document.getElementById(id);
const api = async (method, path, body) => {
  const res = await fetch(path, {
    method,
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `Error ${res.status}`);
  return data;
};

function toast(msg) {
  const t = $("toast");
  t.textContent = msg;
  t.classList.remove("hidden");
  setTimeout(() => t.classList.add("hidden"), 2000);
}

function copy(text) {
  navigator.clipboard.writeText(text).then(() => toast("Copied"));
}

function show(view) {
  $("login").classList.toggle("hidden", view !== "login");
  $("app").classList.toggle("hidden", view !== "app");
}

// --- Auth -----------------------------------------------------------------

async function checkAuth() {
  try {
    await api("GET", "/api/me");
    show("app");
    loadDomains();
  } catch {
    show("login");
  }
}

$("loginForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  $("loginError").textContent = "";
  try {
    await api("POST", "/api/login", { password: $("password").value });
    $("password").value = "";
    show("app");
    loadDomains();
  } catch (err) {
    $("loginError").textContent = err.message;
  }
});

$("logoutBtn").addEventListener("click", async () => {
  await api("POST", "/api/logout");
  show("login");
});

// --- Domains list ---------------------------------------------------------

async function loadDomains() {
  $("detailSection").classList.add("hidden");
  $("domainsSection").classList.remove("hidden");
  const grid = $("domains");
  grid.innerHTML = '<div class="spinner">Loading domains…</div>';
  try {
    const { domains } = await api("GET", "/api/domains");
    $("domainCount").textContent = domains.length;
    grid.innerHTML = "";
    $("domainsEmpty").classList.toggle("hidden", domains.length > 0);
    for (const d of domains) {
      const card = document.createElement("div");
      card.className = "domain-card";
      card.innerHTML = `<div class="name">${d}</div><div class="sub">View mailboxes & DNS →</div>`;
      card.addEventListener("click", () => openDomain(d));
      grid.appendChild(card);
    }
  } catch (err) {
    grid.innerHTML = `<div class="error">${err.message}</div>`;
  }
}

$("refreshBtn").addEventListener("click", loadDomains);
$("backBtn").addEventListener("click", loadDomains);

// --- Domain detail --------------------------------------------------------

async function openDomain(domain) {
  $("domainsSection").classList.add("hidden");
  $("detailSection").classList.remove("hidden");
  $("detailDomain").textContent = domain;
  $("mailboxes").innerHTML = '<div class="spinner">Loading…</div>';
  $("dns").innerHTML = '<div class="spinner">Loading…</div>';

  // Mailboxes
  try {
    const { mailboxes } = await api("GET", `/api/domains/${domain}/mailboxes`);
    $("mailboxes").innerHTML = mailboxes.length
      ? ""
      : '<div class="muted">No mailboxes yet.</div>';
    for (const m of mailboxes) {
      const row = document.createElement("div");
      row.className = "mailbox-row";
      const usage = (m.usage ?? 0).toFixed ? Number(m.usage).toFixed(2) : m.usage;
      row.innerHTML = `<div><div class="email">${m.email}</div>
        <div class="meta">${m.quota} MB quota · ${usage} MB used</div></div>`;
      $("mailboxes").appendChild(row);
    }
  } catch (err) {
    $("mailboxes").innerHTML = `<div class="error">${err.message}</div>`;
  }

  // DNS
  try {
    const { records } = await api("GET", `/api/domains/${domain}/dns`);
    renderDns($("dns"), records);
  } catch (err) {
    $("dns").innerHTML = `<div class="error">${err.message}</div>`;
  }
}

function renderDns(container, records) {
  container.innerHTML = "";
  for (const r of records) {
    const row = document.createElement("div");
    row.className = "dns-row";
    const tag = r.label || r.type;
    const prio = r.priority != null ? `<div class="field">Priority: ${r.priority}</div>` : "";
    row.innerHTML = `
      <div class="dns-head">
        <span class="tag">${tag}</span>
        <button class="copy-btn">Copy value</button>
      </div>
      <div class="field">Type: ${r.type} &nbsp;·&nbsp; Name: ${r.name}</div>
      ${prio}
      <div class="val">${r.value}</div>`;
    row.querySelector(".copy-btn").addEventListener("click", () => copy(r.value));
    container.appendChild(row);
  }
}

// --- Add client / provision ----------------------------------------------

$("addBtn").addEventListener("click", () => {
  $("provisionResult").innerHTML = "";
  $("provisionForm").reset();
  $("quota").value = 1024;
  $("modal").classList.remove("hidden");
});
$("cancelBtn").addEventListener("click", () => $("modal").classList.add("hidden"));
$("modal").addEventListener("click", (e) => {
  if (e.target === $("modal")) $("modal").classList.add("hidden");
});

$("provisionForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const domain = $("domain").value.trim();
  const mailboxes = $("mailboxesInput").value
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const quotaMB = parseInt($("quota").value, 10) || 1024;

  const btn = $("provisionBtn");
  btn.disabled = true;
  btn.textContent = "Provisioning…";
  $("provisionResult").innerHTML = "";

  try {
    const r = await api("POST", "/api/provision", { domain, mailboxes, quotaMB });
    renderProvisionResult(r);
    loadDomains();
  } catch (err) {
    $("provisionResult").innerHTML = `<div class="error">${err.message}</div>`;
  } finally {
    btn.disabled = false;
    btn.textContent = "Provision";
  }
});

function renderProvisionResult(r) {
  const out = $("provisionResult");
  let html = "";

  if (r.created?.length) {
    html += `<div class="result-block"><h4>✅ Mailboxes created</h4>`;
    html += `<p class="warn">⚠️ Save these passwords now — they are shown only once.</p>`;
    for (const c of r.created) {
      html += `<div class="cred"><span>${c.email}<br><b>${c.password}</b></span>
        <button class="copy-btn" data-copy="${c.email}  ${c.password}">Copy</button></div>`;
    }
    html += `</div>`;
  }
  if (r.skipped?.length) {
    html += `<div class="result-block"><h4>↪ Already existed</h4><div class="muted small">${r.skipped.join(", ")}</div></div>`;
  }
  if (r.verification) {
    html += `<div class="result-block"><h4>⚠️ Domain needs verification first</h4>
      <div class="dns-row"><div class="field">Type: TXT · Name: ${r.verification.name}</div>
      <div class="val">${r.verification.value}</div></div>
      <p class="warn">Add this TXT record, wait 5–15 min, then provision again.</p></div>`;
  }
  if (r.dns?.length) {
    html += `<div class="result-block"><h4>📋 DNS records — paste at the client's DNS host</h4><div id="provDns"></div></div>`;
  }
  if (r.errors?.length) {
    html += `<div class="result-block"><h4 style="color:var(--red)">Errors</h4><div class="small">${r.errors.join("<br>")}</div></div>`;
  }
  out.innerHTML = html || '<div class="muted">Nothing to do.</div>';

  if (r.dns?.length) renderDns($("provDns"), r.dns);
  out.querySelectorAll("[data-copy]").forEach((b) =>
    b.addEventListener("click", () => copy(b.dataset.copy))
  );
}

// --- Boot -----------------------------------------------------------------
checkAuth();
