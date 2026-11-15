// Run: npm test   (Node 20+, no dependencies; fetch and KV are faked)
import { test } from "node:test";
import assert from "node:assert/strict";
import worker, { buildIssue, cleanContext, validateDraft, LIMITS } from "../src/index.js";

function fakeKV() {
  const store = new Map();
  return {
    store,
    async get(k) { return store.has(k) ? store.get(k) : null; },
    async put(k, v) { store.set(k, v); },
    async delete(k) { store.delete(k); },
  };
}

function env(overrides = {}) {
  return { FEEDBACK_KV: fakeKV(), GITHUB_REPO: "AGD3SIGN/daemons-feedback", GITHUB_TOKEN: "tok", TURNSTILE_SECRET: "sec",
    TURNSTILE_SITE_KEY: "site-key-123", ALLOWED_ORIGINS: "https://agd3sign.github.io", ...overrides };
}

const BASE = "https://feedback.example.workers.dev";
const good = { category: "bug", message: "Kevin walked through a wall on Route 2.", context: { platform: "web", map: "route_2", build: 57, secret: "nope" } };

function post(path, body, headers = {}) {
  return new Request(BASE + path, { method: "POST", body: JSON.stringify(body),
    headers: { "content-type": "application/json", "CF-Connecting-IP": "1.2.3.4", ...headers } });
}

async function newDraft(e, body = good) {
  const res = await worker.fetch(post("/drafts", body), e);
  return { res, data: await res.json() };
}

test("a valid draft is stored and gets a confirm link", async () => {
  const e = env();
  const { res, data } = await newDraft(e);
  assert.equal(res.status, 200);
  assert.match(data.confirm_url, new RegExp(`^${BASE}/confirm/[0-9a-f-]{36}$`));
  const stored = JSON.parse(e.FEEDBACK_KV.store.get(`draft:${data.id}`));
  assert.equal(stored.message, good.message);
  assert.equal(stored.context.secret, undefined, "unknown context keys are dropped");
});

test("bad drafts are rejected", async () => {
  assert.match(validateDraft({ category: "rant", message: "x".repeat(20) }), /category/);
  assert.match(validateDraft({ category: "bug", message: "short" }), /at least/);
  assert.match(validateDraft({ category: "bug", message: "x".repeat(LIMITS.maxMessage + 1) }), /under/);
  const { res } = await newDraft(env(), { category: "bug", message: "hi" });
  assert.equal(res.status, 400);
});

test("each address can only send a few drafts an hour", async () => {
  const e = env();
  for (let i = 0; i < LIMITS.draftsPerHour; i++) assert.equal((await newDraft(e)).res.status, 200);
  assert.equal((await newDraft(e)).res.status, 429);
});

test("the confirm page shows the message safely with the Turnstile widget", async () => {
  const e = env();
  const { data } = await newDraft(e, { ...good, message: "<script>alert(1)</script> breaks the shop" });
  const res = await worker.fetch(new Request(`${BASE}/confirm/${data.id}`), e);
  const html = await res.text();
  assert.equal(res.status, 200);
  assert.ok(html.includes('data-sitekey="site-key-123"'));
  assert.ok(html.includes("&lt;script&gt;"), "escaped");
  assert.ok(!html.includes("<script>alert"), "not executable");
});

function confirmRequest(id, token = "tok-from-widget") {
  const form = new FormData();
  if (token) form.append("cf-turnstile-response", token);
  return new Request(`${BASE}/confirm/${id}`, { method: "POST", body: form, headers: { "CF-Connecting-IP": "1.2.3.4" } });
}

test("no issue is created when the captcha fails", async (t) => {
  const e = env();
  const { data } = await newDraft(e);
  const calls = [];
  t.mock.method(globalThis, "fetch", async (url) => {
    calls.push(String(url));
    return new Response(JSON.stringify({ success: false }));
  });
  const res = await worker.fetch(confirmRequest(data.id), e);
  assert.equal(res.status, 403);
  assert.ok(!calls.some((u) => u.includes("api.github.com")), "GitHub never called");
  assert.ok(e.FEEDBACK_KV.store.has(`draft:${data.id}`), "the draft waits for a real try");
});

test("a confirmed draft becomes a labeled issue and is deleted", async (t) => {
  const e = env();
  const { data } = await newDraft(e, { ...good, message: "@everyone ~~~~ look at this ![img](x)" });
  let issue = null;
  t.mock.method(globalThis, "fetch", async (url, init) => {
    if (String(url).includes("turnstile")) return new Response(JSON.stringify({ success: true }));
    issue = JSON.parse(init.body);
    assert.equal(init.headers.Authorization, "Bearer tok");
    assert.ok(String(url).endsWith("/repos/AGD3SIGN/daemons-feedback/issues"));
    return new Response(JSON.stringify({ number: 7 }), { status: 201 });
  });
  const res = await worker.fetch(confirmRequest(data.id), e);
  assert.equal(res.status, 200);
  assert.ok((await res.text()).includes("#7"));
  assert.deepEqual(issue.labels, ["feedback", "bug", "platform:web"]);
  assert.ok(issue.body.includes("~~~~text\n@everyone"), "message sits inside a code fence (no mentions or images render)");
  assert.ok(!issue.body.includes("@everyone ~~~~"), "a fence in the message can't close ours");
  assert.ok(!e.FEEDBACK_KV.store.has(`draft:${data.id}`));
});

test("issue titles are short and context only keeps known keys", () => {
  const issue = buildIssue({ category: "idea", message: "x".repeat(200), context: {}, created: "now" });
  assert.ok(issue.title.length <= 80);
  assert.deepEqual(cleanContext({ map: "port_city", x: 4, evil: "<b>", platform: "toaster" }), { map: "port_city", x: 4 });
});

test("CORS only for the web build's origin", async () => {
  const e = env();
  const ok = await worker.fetch(post("/drafts", good, { Origin: "https://agd3sign.github.io" }), e);
  assert.equal(ok.headers.get("Access-Control-Allow-Origin"), "https://agd3sign.github.io");
  const other = await worker.fetch(post("/drafts", good, { Origin: "https://evil.example", "CF-Connecting-IP": "5.6.7.8" }), e);
  assert.equal(other.headers.get("Access-Control-Allow-Origin"), null);
});
