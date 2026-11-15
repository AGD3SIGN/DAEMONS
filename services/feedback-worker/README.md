# DAEMONS feedback relay

A small Cloudflare Worker that turns in-game feedback into issues in the **private**
`AGD3SIGN/daemons-feedback` repo. The game never holds a GitHub token.

```
game  ──POST /drafts──▶  Worker (validate, 5/hour per IP, store draft 1 h)
game  ──opens browser──▶ GET /confirm/<id>   preview + Cloudflare Turnstile "I'm human"
player clicks Send ────▶ POST /confirm/<id>  verify Turnstile → create GitHub issue → delete draft
```

Drafts nobody confirms expire after an hour and never reach GitHub. The message is placed in a code
fence on the issue, so @mentions, links and images in it can't render.

## One-time setup (you do these; they touch your accounts)

Run from `services/feedback-worker/`.

1. **Sign in to Cloudflare**
   ```bash
   npx wrangler login
   ```
2. **Create the KV namespace** and paste the printed `id` into `wrangler.toml`
   (replace `REPLACE_WITH_KV_NAMESPACE_ID`).
   ```bash
   npx wrangler kv namespace create FEEDBACK_KV
   ```
3. **Deploy once** so you get the Worker URL (`https://daemons-feedback.<you>.workers.dev`).
   ```bash
   npm run deploy
   ```
4. **Create a Turnstile widget** in the Cloudflare dashboard → Turnstile → Add widget.
   Hostname: the `workers.dev` host from step 3. Mode: Managed.
   Put the **site key** in `wrangler.toml` (`TURNSTILE_SITE_KEY`). Keep the **secret key** for step 6.
5. **Create a fine-grained GitHub token**: GitHub → Settings → Developer settings → Fine-grained tokens.
   Repository access: *Only* `AGD3SIGN/daemons-feedback`. Permissions: **Issues: Read and write**. Nothing else.
6. **Store the secrets** (each command prompts; nothing goes in git):
   ```bash
   npx wrangler secret put GITHUB_TOKEN
   ```
   ```bash
   npx wrangler secret put TURNSTILE_SECRET
   ```
7. **Deploy again** with the real site key:
   ```bash
   npm run deploy
   ```
8. **Point the game at it**: set `"endpoint"` in `data/feedback.json` to the Worker URL
   (must start with `https://`), run the tests, commit. Until then the game says
   "Feedback isn't set up in this build yet."

If the web build is served from somewhere other than `https://agd3sign.github.io`, add that origin to
`ALLOWED_ORIGINS` in `wrangler.toml`.

## Day to day

- New reports appear at the start of every Claude Code session in this repo
  (`.claude/settings.json` → `tools/feedback/feedback_report.sh`). Run the script by hand any time.
- `gh issue view <n> -R AGD3SIGN/daemons-feedback` to read one;
  `gh issue close <n> -R AGD3SIGN/daemons-feedback -c "Fixed in <commit>"` when it ships.
- Tests: `npm test` (Node's built-in runner; no dependencies).

## Limits (keep in sync with `data/feedback.json`)

| | |
|---|---|
| message | 10–2000 characters |
| drafts | 5 per hour per IP |
| draft lifetime | 1 hour |
| categories | bug, idea, other |
