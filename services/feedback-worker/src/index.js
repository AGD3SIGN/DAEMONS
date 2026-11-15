// DAEMONS feedback relay (Cloudflare Worker).
//
// The game never talks to GitHub directly (a token inside a game build can be pulled out by anyone).
// Instead:
//   1. POST /drafts            the game sends {category, message, context}; we validate it, rate-limit by IP,
//                              store it in KV for an hour and answer {id, confirm_url}.
//   2. GET  /confirm/<id>      the game opens this page in the player's browser: a preview of their message
//                              and a Cloudflare Turnstile "I'm human" check.
//   3. POST /confirm/<id>      we verify the Turnstile token, then create the issue in the private feedback repo
//                              and delete the draft. Drafts nobody confirms expire and never reach GitHub.
//
// Secrets (wrangler secret put):  GITHUB_TOKEN (fine-grained, Issues: read & write on the feedback repo only),
//                                 TURNSTILE_SECRET.
// Vars (wrangler.toml):           GITHUB_REPO, TURNSTILE_SITE_KEY, ALLOWED_ORIGINS.
// KV binding:                     FEEDBACK_KV.

export const LIMITS = {
  minMessage: 10,
  maxMessage: 2000,
  draftTtl: 3600, // seconds a draft waits for its "I'm human" click
  draftsPerHour: 5, // per IP
};
export const CATEGORIES = ["bug", "idea", "other"];
export const PLATFORMS = ["web", "macos", "windows", "ios", "android", "linux"];
const CONTEXT_KEYS = ["version", "build", "platform", "map", "x", "y", "play_minutes", "certs", "daemons", "language"];

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const cors = corsHeaders(request, env);
    try {
      if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
      if (url.pathname === "/drafts" && request.method === "POST") return withHeaders(await createDraft(request, env, url), cors);
      const match = url.pathname.match(/^\/confirm\/([0-9a-f-]{36})$/);
      if (match && request.method === "GET") return await confirmPage(match[1], env);
      if (match && request.method === "POST") return await confirmSubmit(match[1], request, env);
      if (url.pathname === "/") return new Response("DAEMONS feedback relay", { headers: { "content-type": "text/plain" } });
      return new Response("Not found", { status: 404 });
    } catch (err) {
      console.error(err);
      return new Response("Something went wrong on our side.", { status: 500 });
    }
  },
};

// --- 1. drafts ---------------------------------------------------------------

async function createDraft(request, env, url) {
  let data;
  try {
    data = await request.json();
  } catch {
    return json({ error: "Expected JSON." }, 400);
  }
  const problem = validateDraft(data);
  if (problem) return json({ error: problem }, 400);

  const ip = request.headers.get("CF-Connecting-IP") || "unknown";
  const rateKey = `rate:${ip}:${Math.floor(Date.now() / 3600000)}`;
  const count = parseInt((await env.FEEDBACK_KV.get(rateKey)) || "0", 10);
  if (count >= LIMITS.draftsPerHour) return json({ error: "Too much feedback from here this hour. Try again later." }, 429);
  await env.FEEDBACK_KV.put(rateKey, String(count + 1), { expirationTtl: 3600 });

  const id = crypto.randomUUID();
  const draft = {
    category: data.category,
    message: data.message.trim(),
    context: cleanContext(data.context),
    created: new Date().toISOString(),
  };
  await env.FEEDBACK_KV.put(`draft:${id}`, JSON.stringify(draft), { expirationTtl: LIMITS.draftTtl });
  return json({ id, confirm_url: `${url.origin}/confirm/${id}` }, 200);
}

export function validateDraft(data) {
  if (!data || typeof data !== "object") return "Expected an object.";
  if (!CATEGORIES.includes(data.category)) return `category must be one of ${CATEGORIES.join(", ")}.`;
  if (typeof data.message !== "string") return "message must be text.";
  const length = data.message.trim().length;
  if (length < LIMITS.minMessage) return `Please write at least ${LIMITS.minMessage} characters.`;
  if (length > LIMITS.maxMessage) return `Please keep it under ${LIMITS.maxMessage} characters.`;
  return null;
}

/** Only known context fields, short strings or numbers; nothing else gets through. */
export function cleanContext(context) {
  const out = {};
  if (!context || typeof context !== "object") return out;
  for (const key of CONTEXT_KEYS) {
    const value = context[key];
    if (typeof value === "number" && Number.isFinite(value)) out[key] = value;
    else if (typeof value === "string") out[key] = value.slice(0, 64);
  }
  if (out.platform && !PLATFORMS.includes(out.platform)) delete out.platform;
  return out;
}

// --- 2. confirm page ------------------------------------------------------------

async function confirmPage(id, env) {
  const draft = await getDraft(env, id);
  if (!draft) return page("Link expired", "<p>This feedback link has expired. Please send it again from the game.</p>", 404);
  const body = `
    <p>Here's what you're sending. One click to prove you're a person, and it goes straight to the DAEMONS team.</p>
    <div class="card"><div class="tag">${escapeHtml(draft.category.toUpperCase())}</div><pre>${escapeHtml(draft.message)}</pre></div>
    <form method="POST">
      <div class="cf-turnstile" data-sitekey="${escapeHtml(env.TURNSTILE_SITE_KEY || "")}" data-theme="dark"></div>
      <button type="submit">Send feedback</button>
    </form>
    <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>`;
  return page("Send your feedback", body);
}

// --- 3. confirm + create the issue ------------------------------------------------

async function confirmSubmit(id, request, env) {
  const form = await request.formData();
  const token = form.get("cf-turnstile-response");
  const ip = request.headers.get("CF-Connecting-IP") || "";
  if (!token || !(await verifyTurnstile(token, ip, env))) {
    return page("Couldn't verify", `<p>We couldn't confirm you're a person. <a href="/confirm/${id}">Try again</a>.</p>`, 403);
  }
  const draft = await getDraft(env, id);
  if (!draft) return page("Link expired", "<p>This feedback link has expired. Please send it again from the game.</p>", 404);

  const issue = buildIssue(draft);
  const response = await fetch(`https://api.github.com/repos/${env.GITHUB_REPO}/issues`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.GITHUB_TOKEN}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "daemons-feedback-worker",
      "X-GitHub-Api-Version": "2022-11-28",
      "content-type": "application/json",
    },
    body: JSON.stringify(issue),
  });
  if (!response.ok) {
    console.error("GitHub said", response.status, await response.text());
    return page("Not sent", "<p>The feedback couldn't be filed right now. Please try again in a few minutes.</p>", 502);
  }
  const created = await response.json();
  await env.FEEDBACK_KV.delete(`draft:${id}`);
  return page("Thanks!", `<p>Feedback #${Number(created.number) || ""} sent. Thanks for helping make DAEMONS better.</p><p>You can close this tab and go back to the game.</p>`);
}

export async function verifyTurnstile(token, ip, env) {
  const body = new FormData();
  body.append("secret", env.TURNSTILE_SECRET || "");
  body.append("response", token);
  if (ip) body.append("remoteip", ip);
  const result = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", { method: "POST", body });
  const data = await result.json();
  return data.success === true;
}

/** The issue: a short title, the message in a fence (no @mentions, links or images can render), and the context. */
export function buildIssue(draft) {
  const firstLine = draft.message.split("\n")[0].trim();
  const title = `[${draft.category}] ${firstLine.length > 70 ? firstLine.slice(0, 67) + "..." : firstLine}`;
  const fence = "~~~~";
  const message = draft.message.replaceAll(fence, "~ ~ ~ ~");
  const rows = Object.entries(draft.context || {}).map(([k, v]) => `| ${k} | ${String(v).replaceAll("|", "/")} |`);
  const body = [
    "**Player feedback** (sent from the in-game Feedback form)",
    "",
    `${fence}text`,
    message,
    fence,
    "",
    rows.length ? ["| | |", "|---|---|", ...rows].join("\n") : "_No game context._",
    "",
    `<sub>Received ${draft.created}</sub>`,
  ].join("\n");
  const labels = ["feedback", draft.category];
  if (draft.context && draft.context.platform) labels.push(`platform:${draft.context.platform}`);
  return { title, body, labels };
}

// --- helpers ----------------------------------------------------------------------

async function getDraft(env, id) {
  const raw = await env.FEEDBACK_KV.get(`draft:${id}`);
  return raw ? JSON.parse(raw) : null;
}

function corsHeaders(request, env) {
  const origin = request.headers.get("Origin") || "";
  const allowed = (env.ALLOWED_ORIGINS || "").split(",").map((s) => s.trim()).filter(Boolean);
  if (!allowed.includes(origin)) return {};
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "content-type",
    Vary: "Origin",
  };
}

function withHeaders(response, headers) {
  for (const [k, v] of Object.entries(headers)) response.headers.set(k, v);
  return response;
}

function json(data, status) {
  return new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json" } });
}

export function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

function page(title, body, status = 200) {
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>DAEMONS · ${escapeHtml(title)}</title>
<style>
  :root { color-scheme: dark; }
  body { margin: 0; background: #0a1120; color: #e8f1ff; font: 16px/1.5 system-ui, sans-serif; }
  main { max-width: 560px; margin: 0 auto; padding: 32px 16px; }
  h1 { font-size: 22px; color: #3ee6ff; letter-spacing: .04em; }
  .card { background: #0c1626; border: 3px solid #3ee6ff; box-shadow: 6px 6px 0 #000; padding: 12px 16px; margin: 16px 0; }
  .tag { display: inline-block; background: #3ee6ff; color: #031318; font-weight: 700; font-size: 12px; padding: 2px 8px; }
  pre { white-space: pre-wrap; word-break: break-word; font: 15px/1.4 ui-monospace, monospace; color: #d9fbe6; }
  button { margin-top: 16px; background: #3ee6ff; color: #031318; border: 0; font-weight: 700; font-size: 16px; padding: 12px 20px; min-height: 44px; cursor: pointer; }
  a { color: #3ee6ff; }
</style></head><body><main><h1>${escapeHtml(title)}</h1>${body}</main></body></html>`;
  return new Response(html, { status, headers: { "content-type": "text/html; charset=utf-8" } });
}
