# Plan 1 — Foundation Implementation Plan (Worker + Content Pipeline)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the two non-iOS pieces of the Pulse stack — a Cloudflare Worker that proxies Anthropic API calls (so the API key never ships in the app), and a one-time content import pipeline that loads Free Exercise DB into R2 with a fetchable manifest. After this plan, both services are deployed and verifiable end-to-end via curl, with no iOS code yet written.

**Architecture:** Two independent subprojects in the existing monorepo. The Worker is a stateless TypeScript service deployed to Cloudflare Workers; it holds the Anthropic key as a Worker secret and forwards Messages API requests with `stream: true`, piping SSE responses back. The content pipeline is a local Node script that fetches Free Exercise DB's combined JSON, downloads its photo assets, uses ffmpeg to convert each exercise's two reference photos into a 2-second looping MP4, uploads everything to R2, and publishes a `manifest.json` that the iOS app will fetch at launch.

**Tech Stack:** TypeScript 5.x · Wrangler CLI (Cloudflare Workers) · Vitest (unit tests for Worker) · Node 20.x (content script) · `@aws-sdk/client-s3` (R2 is S3-compatible) · `ffmpeg-static` (bundled ffmpeg binary) · Anthropic Messages API (Claude Sonnet 4.6 / Opus 4.7).

---

## Repository Layout (After This Plan)

```
/Users/smwein/Dev Project/Workout App/
├── design_handoff_pulse_workout_app/      (already committed)
├── docs/
│   ├── superpowers/
│   │   ├── specs/2026-04-26-pulse-ai-trainer-app-design.md
│   │   └── plans/2026-04-26-plan-1-foundation.md   ← this file
├── worker/                                ← NEW: Cloudflare Worker
│   ├── src/
│   │   └── index.ts                       Worker entry: proxy + token check
│   ├── test/
│   │   └── index.test.ts                  Vitest unit tests for the Worker
│   ├── wrangler.toml                      Worker config (name, compatibility, vars)
│   ├── package.json                       Deps: wrangler, vitest, @cloudflare/workers-types
│   ├── tsconfig.json                      TS config with Workers types
│   └── .dev.vars                          (gitignored) local secrets for `wrangler dev`
└── tools/
    └── import-exercises/                  ← NEW: One-time content import script
        ├── src/
        │   ├── index.ts                   Entry point — orchestrates the pipeline
        │   ├── fetchExercises.ts          Downloads source JSON from free-exercise-db
        │   ├── downloadImages.ts          Downloads exercise photos to a local cache
        │   ├── encodeMp4.ts               ffmpeg wrapper: 2 photos → 2s looping MP4
        │   ├── uploadR2.ts                S3-compatible client for Cloudflare R2
        │   ├── buildManifest.ts           Constructs the manifest JSON
        │   └── types.ts                   FreeExerciseDbEntry + PulseExerciseAsset
        ├── package.json                   Deps: @aws-sdk/client-s3, ffmpeg-static, etc.
        ├── tsconfig.json
        └── .env                           (gitignored) R2 credentials
```

---

## Prerequisites — Verify Before Starting

These must be true before Task 1. If anything is missing, install/configure first.

- [ ] **Node.js 20.x or later installed.** Run `node --version` — must show `v20.x` or newer.
- [ ] **npm available.** Run `npm --version`.
- [ ] **Cloudflare account exists.** If not, sign up at https://dash.cloudflare.com/sign-up (free tier is sufficient for this plan).
- [ ] **Anthropic account with API key.** Generate at https://console.anthropic.com/. Save the key — it'll be set as a Worker secret in Task 5.
- [ ] **`gh` CLI authenticated** (already verified during spec phase).
- [ ] **Working directory:** All commands assume cwd is `/Users/smwein/Dev Project/Workout App/` unless explicitly otherwise. Use absolute paths in your shell.

---

# Section A — Cloudflare Worker (Tasks 1–14)

## Task 1: Install Wrangler CLI globally

**Files:** None (global install).

- [ ] **Step 1: Install Wrangler**

```bash
npm install -g wrangler@latest
```

- [ ] **Step 2: Verify install**

```bash
wrangler --version
```

Expected: prints a version like `4.x.x` (any 3.x or newer is fine).

- [ ] **Step 3: Authenticate with Cloudflare**

```bash
wrangler login
```

This opens a browser. Approve the OAuth grant. Returns to terminal with "Successfully logged in."

- [ ] **Step 4: Verify auth**

```bash
wrangler whoami
```

Expected: shows your Cloudflare account email + account ID. **Note the account ID** — you'll need it for `wrangler.toml`.

---

## Task 2: Initialize the Worker project

**Files:**
- Create: `worker/package.json`
- Create: `worker/tsconfig.json`
- Create: `worker/wrangler.toml`
- Create: `worker/.gitignore`
- Create: `worker/src/index.ts` (stub)

- [ ] **Step 1: Create the worker directory structure**

```bash
mkdir -p "/Users/smwein/Dev Project/Workout App/worker/src"
mkdir -p "/Users/smwein/Dev Project/Workout App/worker/test"
cd "/Users/smwein/Dev Project/Workout App/worker"
```

- [ ] **Step 2: Initialize package.json**

Create `worker/package.json` with this content:

```json
{
  "name": "pulse-proxy",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "devDependencies": {
    "@cloudflare/vitest-pool-workers": "^0.5.0",
    "@cloudflare/workers-types": "^4.20250101.0",
    "typescript": "^5.4.0",
    "vitest": "^2.0.0",
    "wrangler": "^4.0.0"
  }
}
```

- [ ] **Step 3: Install dependencies**

```bash
cd "/Users/smwein/Dev Project/Workout App/worker"
npm install
```

Expected: completes without errors, creates `node_modules/` and `package-lock.json`.

- [ ] **Step 4: Create tsconfig.json**

Create `worker/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "Bundler",
    "lib": ["ES2022"],
    "types": ["@cloudflare/workers-types", "vitest"],
    "strict": true,
    "noEmit": true,
    "skipLibCheck": true,
    "isolatedModules": true,
    "resolveJsonModule": true,
    "esModuleInterop": true
  },
  "include": ["src/**/*", "test/**/*"]
}
```

- [ ] **Step 5: Create wrangler.toml**

Create `worker/wrangler.toml`. **Replace `YOUR_ACCOUNT_ID_HERE`** with the account ID from Task 1 step 4:

```toml
name = "pulse-proxy"
main = "src/index.ts"
compatibility_date = "2026-04-01"
account_id = "YOUR_ACCOUNT_ID_HERE"

# Secrets are set via `wrangler secret put` (not in this file):
#   ANTHROPIC_API_KEY
#   DEVICE_TOKEN

[observability]
enabled = true
```

- [ ] **Step 6: Create .gitignore for worker**

Create `worker/.gitignore`:

```
node_modules/
.dev.vars
.wrangler/
dist/
```

- [ ] **Step 7: Create stub index.ts**

Create `worker/src/index.ts`:

```typescript
export interface Env {
  ANTHROPIC_API_KEY: string;
  DEVICE_TOKEN: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return new Response("pulse-proxy stub", { status: 200 });
  },
} satisfies ExportedHandler<Env>;
```

- [ ] **Step 8: Verify the project builds**

```bash
cd "/Users/smwein/Dev Project/Workout App/worker"
npx tsc --noEmit
```

Expected: no output (success).

- [ ] **Step 9: Commit the scaffolding**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add worker/package.json worker/package-lock.json worker/tsconfig.json worker/wrangler.toml worker/.gitignore worker/src/index.ts
git commit -m "$(cat <<'EOF'
chore(worker): scaffold Cloudflare Worker project

Initial TypeScript Worker setup with Wrangler config, types, and a stub
handler that returns a 200. No proxy logic yet — that lands in the next
tasks via TDD.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Set up Vitest with the Workers pool

**Files:**
- Create: `worker/vitest.config.ts`

- [ ] **Step 1: Create vitest config**

Create `worker/vitest.config.ts`:

```typescript
import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.toml" },
        miniflare: {
          bindings: {
            ANTHROPIC_API_KEY: "test-anthropic-key",
            DEVICE_TOKEN: "test-device-token",
          },
        },
      },
    },
  },
});
```

- [ ] **Step 2: Sanity check vitest runs (with no tests)**

```bash
cd "/Users/smwein/Dev Project/Workout App/worker"
npx vitest run
```

Expected: prints `No test files found` or similar, exits 0. Confirms tooling works.

- [ ] **Step 3: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add worker/vitest.config.ts
git commit -m "chore(worker): wire up Vitest with @cloudflare/vitest-pool-workers"
```

---

## Task 4: TDD — Reject requests missing the device token

**Files:**
- Create: `worker/test/auth.test.ts`
- Modify: `worker/src/index.ts`

- [ ] **Step 1: Write the failing test**

Create `worker/test/auth.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { SELF } from "cloudflare:test";

describe("device token auth", () => {
  it("rejects requests without X-Device-Token header with 403", async () => {
    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      body: JSON.stringify({ model: "test", messages: [] }),
    });
    expect(response.status).toBe(403);
  });

  it("rejects requests with an invalid X-Device-Token with 403", async () => {
    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      headers: { "X-Device-Token": "wrong-token" },
      body: JSON.stringify({ model: "test", messages: [] }),
    });
    expect(response.status).toBe(403);
  });
});
```

- [ ] **Step 2: Run the tests — expect failure**

```bash
cd "/Users/smwein/Dev Project/Workout App/worker"
npx vitest run
```

Expected: Both tests FAIL because the stub returns 200 unconditionally.

- [ ] **Step 3: Implement the auth check**

Replace `worker/src/index.ts` with:

```typescript
export interface Env {
  ANTHROPIC_API_KEY: string;
  DEVICE_TOKEN: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== "POST") {
      return new Response("method not allowed", { status: 405 });
    }
    if (request.headers.get("X-Device-Token") !== env.DEVICE_TOKEN) {
      return new Response("forbidden", { status: 403 });
    }
    return new Response("authenticated stub", { status: 200 });
  },
} satisfies ExportedHandler<Env>;
```

- [ ] **Step 4: Run the tests — expect pass**

```bash
npx vitest run
```

Expected: Both tests PASS.

- [ ] **Step 5: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add worker/src/index.ts worker/test/auth.test.ts
git commit -m "feat(worker): reject requests without valid X-Device-Token (403)"
```

---

## Task 5: TDD — Reject non-POST methods

**Files:**
- Create: `worker/test/method.test.ts`

(Note: implementation already done in Task 4 — this test pins down behavior to prevent regressions.)

- [ ] **Step 1: Write the test**

Create `worker/test/method.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { SELF } from "cloudflare:test";

describe("HTTP method", () => {
  it("rejects GET with 405", async () => {
    const response = await SELF.fetch("https://example.com/", { method: "GET" });
    expect(response.status).toBe(405);
  });

  it("rejects PUT with 405", async () => {
    const response = await SELF.fetch("https://example.com/", { method: "PUT" });
    expect(response.status).toBe(405);
  });
});
```

- [ ] **Step 2: Run — expect pass (already implemented)**

```bash
cd "/Users/smwein/Dev Project/Workout App/worker"
npx vitest run
```

Expected: All 4 tests pass.

- [ ] **Step 3: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add worker/test/method.test.ts
git commit -m "test(worker): pin down 405 for non-POST requests"
```

---

## Task 6: TDD — Forward authenticated requests to Anthropic

**Files:**
- Create: `worker/test/forward.test.ts`
- Modify: `worker/src/index.ts`

This is the core behavior. We'll mock Anthropic's response with a Miniflare service binding, but the simplest approach is to override `globalThis.fetch` in the test.

- [ ] **Step 1: Write the failing test**

Create `worker/test/forward.test.ts`:

```typescript
import { describe, it, expect, beforeEach, vi } from "vitest";
import { SELF } from "cloudflare:test";

describe("forwarding to Anthropic", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("forwards POST body to api.anthropic.com with the configured API key", async () => {
    const fetchSpy = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      return new Response("ok", {
        status: 200,
        headers: { "content-type": "text/event-stream" },
      });
    });
    vi.stubGlobal("fetch", fetchSpy);

    const requestBody = { model: "claude-sonnet-4-6", messages: [{ role: "user", content: "hi" }] };

    await SELF.fetch("https://example.com/", {
      method: "POST",
      headers: {
        "X-Device-Token": "test-device-token",
        "content-type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    expect(fetchSpy).toHaveBeenCalledOnce();
    const [url, init] = fetchSpy.mock.calls[0];
    expect(String(url)).toBe("https://api.anthropic.com/v1/messages");
    expect(init?.method).toBe("POST");

    const headers = new Headers(init?.headers as HeadersInit);
    expect(headers.get("x-api-key")).toBe("test-anthropic-key");
    expect(headers.get("anthropic-version")).toBe("2023-06-01");
    expect(headers.get("content-type")).toBe("application/json");

    const forwardedBody = JSON.parse(init?.body as string);
    expect(forwardedBody.model).toBe("claude-sonnet-4-6");
    expect(forwardedBody.messages).toEqual(requestBody.messages);
    expect(forwardedBody.stream).toBe(true);
  });

  it("returns the upstream response status to the caller", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => new Response("ok", { status: 200 })));

    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      headers: { "X-Device-Token": "test-device-token" },
      body: JSON.stringify({ model: "x", messages: [] }),
    });

    expect(response.status).toBe(200);
  });

  it("returns 502 when upstream returns 5xx", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => new Response("upstream error", { status: 500 })));

    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      headers: { "X-Device-Token": "test-device-token" },
      body: JSON.stringify({ model: "x", messages: [] }),
    });

    expect(response.status).toBe(502);
  });
});
```

- [ ] **Step 2: Run — expect failures**

```bash
cd "/Users/smwein/Dev Project/Workout App/worker"
npx vitest run
```

Expected: 3 new tests FAIL (handler still returns "authenticated stub").

- [ ] **Step 3: Implement forwarding**

Replace `worker/src/index.ts` with:

```typescript
export interface Env {
  ANTHROPIC_API_KEY: string;
  DEVICE_TOKEN: string;
}

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== "POST") {
      return new Response("method not allowed", { status: 405 });
    }
    if (request.headers.get("X-Device-Token") !== env.DEVICE_TOKEN) {
      return new Response("forbidden", { status: 403 });
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return new Response("invalid json body", { status: 400 });
    }

    const upstreamBody = JSON.stringify({ ...(body as object), stream: true });

    const upstream = await fetch(ANTHROPIC_URL, {
      method: "POST",
      headers: {
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": ANTHROPIC_VERSION,
        "content-type": "application/json",
      },
      body: upstreamBody,
    });

    if (upstream.status >= 500) {
      return new Response(`upstream error ${upstream.status}`, { status: 502 });
    }

    return new Response(upstream.body, {
      status: upstream.status,
      headers: {
        "content-type": "text/event-stream",
        "cache-control": "no-cache",
      },
    });
  },
} satisfies ExportedHandler<Env>;
```

- [ ] **Step 4: Run — expect pass**

```bash
npx vitest run
```

Expected: All 7 tests PASS (2 auth + 2 method + 3 forward).

- [ ] **Step 5: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add worker/src/index.ts worker/test/forward.test.ts
git commit -m "$(cat <<'EOF'
feat(worker): forward authenticated requests to Anthropic with stream=true

Validates JSON body, injects stream=true, forwards with the configured
API key and anthropic-version header. Returns 502 on upstream 5xx so the
client can distinguish auth/proxy errors from upstream LLM errors.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: TDD — SSE pass-through preserves the stream body

**Files:**
- Create: `worker/test/streaming.test.ts`

(No implementation change needed — `new Response(upstream.body, ...)` already streams. This test pins the behavior.)

- [ ] **Step 1: Write the test**

Create `worker/test/streaming.test.ts`:

```typescript
import { describe, it, expect, vi, beforeEach } from "vitest";
import { SELF } from "cloudflare:test";

describe("SSE streaming", () => {
  beforeEach(() => vi.restoreAllMocks());

  it("returns text/event-stream content type", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => new Response("data: hi\n\n", { status: 200 })));

    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      headers: { "X-Device-Token": "test-device-token" },
      body: JSON.stringify({ model: "x", messages: [] }),
    });

    expect(response.headers.get("content-type")).toBe("text/event-stream");
    expect(response.headers.get("cache-control")).toBe("no-cache");
  });

  it("preserves the upstream body bytes exactly", async () => {
    const upstreamPayload = "event: checkpoint\ndata: {\"label\":\"reading\"}\n\nevent: done\ndata: {}\n\n";
    vi.stubGlobal("fetch", vi.fn(async () => new Response(upstreamPayload, { status: 200 })));

    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      headers: { "X-Device-Token": "test-device-token" },
      body: JSON.stringify({ model: "x", messages: [] }),
    });

    const text = await response.text();
    expect(text).toBe(upstreamPayload);
  });
});
```

- [ ] **Step 2: Run — expect pass**

```bash
cd "/Users/smwein/Dev Project/Workout App/worker"
npx vitest run
```

Expected: All 9 tests PASS.

- [ ] **Step 3: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add worker/test/streaming.test.ts
git commit -m "test(worker): pin SSE pass-through preserves upstream body and headers"
```

---

## Task 8: Set up local secrets for `wrangler dev`

**Files:**
- Create: `worker/.dev.vars` (gitignored)

- [ ] **Step 1: Create .dev.vars with your real Anthropic key + a chosen device token**

Create `worker/.dev.vars`. **Replace placeholder values:**

```
ANTHROPIC_API_KEY=sk-ant-api03-YOUR_REAL_KEY_HERE
DEVICE_TOKEN=pulse-dev-token-pick-something-long-and-random
```

For the device token, generate a strong random value:

```bash
openssl rand -hex 32
```

Use the output as your `DEVICE_TOKEN`. Save this value — the iOS app will need it later.

- [ ] **Step 2: Verify .dev.vars is gitignored**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git status worker/.dev.vars
```

Expected: file does not appear in `Untracked files`. (`.dev.vars` is in `worker/.gitignore`.) If it does appear, double-check the gitignore.

---

## Task 9: Smoke test — run the Worker locally with `wrangler dev`

**Files:** None.

- [ ] **Step 1: Start the dev server**

```bash
cd "/Users/smwein/Dev Project/Workout App/worker"
wrangler dev
```

Expected: prints `Ready on http://localhost:8787` (port may differ — note it). Leave this running in a separate terminal.

- [ ] **Step 2: Curl test — expect 403 without token**

In a new terminal:

```bash
curl -i -X POST http://localhost:8787/ -H "Content-Type: application/json" -d '{}'
```

Expected: `HTTP/1.1 403 Forbidden` with body `forbidden`.

- [ ] **Step 3: Curl test — expect real Anthropic streaming response**

Replace `YOUR_DEVICE_TOKEN` with the value from Task 8:

```bash
curl -N -X POST http://localhost:8787/ \
  -H "X-Device-Token: YOUR_DEVICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 50,
    "messages": [{"role": "user", "content": "Say hello in 5 words."}]
  }'
```

Expected: a stream of SSE events including `event: message_start`, `event: content_block_delta`, `event: message_stop`, etc. The model's text appears in the `content_block_delta` events. If you see this, end-to-end streaming works locally.

- [ ] **Step 4: Stop wrangler dev**

In the wrangler terminal: Ctrl-C.

(No commit — this was a runtime smoke test.)

---

## Task 10: Set production secrets

**Files:** None (Wrangler stores these in Cloudflare's vault).

- [ ] **Step 1: Set the Anthropic API key as a Worker secret**

```bash
cd "/Users/smwein/Dev Project/Workout App/worker"
wrangler secret put ANTHROPIC_API_KEY
```

When prompted, paste your real Anthropic API key. Expected: `✓ Success!`

- [ ] **Step 2: Set the device token**

```bash
wrangler secret put DEVICE_TOKEN
```

When prompted, paste the same long random token from `.dev.vars`. Expected: `✓ Success!`

- [ ] **Step 3: Verify secrets are set**

```bash
wrangler secret list
```

Expected: shows both `ANTHROPIC_API_KEY` and `DEVICE_TOKEN` (values redacted).

---

## Task 11: Deploy the Worker to Cloudflare

**Files:** None (deploys built artifact).

- [ ] **Step 1: Deploy**

```bash
cd "/Users/smwein/Dev Project/Workout App/worker"
wrangler deploy
```

Expected: prints something like:

```
Total Upload: 2.45 KiB / gzip: 1.10 KiB
Worker Startup Time: 5 ms
Uploaded pulse-proxy (1.20 sec)
Deployed pulse-proxy (5.30 sec)
  https://pulse-proxy.<your-subdomain>.workers.dev
Current Version ID: <uuid>
```

**Note the workers.dev URL** — that's your production proxy URL. Save it; iOS code will hard-code it later.

- [ ] **Step 2: Smoke test the live deploy**

Replace `YOUR_WORKER_URL` and `YOUR_DEVICE_TOKEN`:

```bash
curl -N -X POST https://YOUR_WORKER_URL/ \
  -H "X-Device-Token: YOUR_DEVICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 50,
    "messages": [{"role": "user", "content": "Say hello in 5 words."}]
  }'
```

Expected: SSE stream with real content from Claude. If this works, the proxy is fully live.

- [ ] **Step 3: Smoke test wrong token rejected**

```bash
curl -i -X POST https://YOUR_WORKER_URL/ \
  -H "X-Device-Token: wrong" \
  -H "Content-Type: application/json" \
  -d '{}'
```

Expected: `HTTP/2 403`.

---

## Task 12: Add a deploy URL to a status file

**Files:**
- Create: `worker/DEPLOY.md`

- [ ] **Step 1: Document the deployed URL**

Create `worker/DEPLOY.md`. **Replace `YOUR_WORKER_URL` with the actual URL** from Task 11:

```markdown
# pulse-proxy — Deployment Status

**Production URL:** `https://YOUR_WORKER_URL/`

## How to deploy

```
cd worker
wrangler deploy
```

## How to view logs

```
wrangler tail
```

## How to rotate the device token

1. Generate new value: `openssl rand -hex 32`
2. `wrangler secret put DEVICE_TOKEN` — paste new value
3. Update the iOS app's hardcoded token + ship a new build

## How to rotate the Anthropic API key

1. Generate new key in Anthropic console
2. `wrangler secret put ANTHROPIC_API_KEY` — paste new key
3. Revoke old key in Anthropic console
```

- [ ] **Step 2: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add worker/DEPLOY.md
git commit -m "docs(worker): document deployed URL and operational procedures"
```

---

## Task 13: Push Worker work to origin

**Files:** None.

- [ ] **Step 1: Push**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git push origin main
```

Expected: pushes 8–10 commits to GitHub.

- [ ] **Step 2: Verify on GitHub**

```bash
gh repo view smwein/Pulse --json url
```

Open the URL in a browser, confirm the `worker/` folder is visible with the expected files (no `.dev.vars`).

---

## Task 14: (Optional) Add Worker test command to root for convenience

Skip if you prefer running tests from inside `worker/`. Otherwise:

**Files:**
- Create: `package.json` (root, only if you want monorepo-level commands)

- [ ] **Step 1: Decide — skip or add root package.json**

If skipping, mark this task complete with no changes.

If adding (recommended for convenience), create root `package.json`:

```json
{
  "name": "pulse-monorepo",
  "version": "0.1.0",
  "private": true,
  "workspaces": ["worker", "tools/*"],
  "scripts": {
    "test:worker": "npm --workspace worker run test",
    "deploy:worker": "npm --workspace worker run deploy"
  }
}
```

- [ ] **Step 2: Commit if added**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add package.json
git commit -m "chore: add root package.json for monorepo workspace commands"
```

---

# Section B — R2 Bucket Setup (Tasks 15–17)

## Task 15: Create the R2 bucket

**Files:** None (uses Cloudflare dashboard or wrangler).

- [ ] **Step 1: Create the bucket via Wrangler**

```bash
cd "/Users/smwein/Dev Project/Workout App/worker"
wrangler r2 bucket create pulse
```

Expected: `Successfully created bucket 'pulse'.`

- [ ] **Step 2: Verify bucket exists**

```bash
wrangler r2 bucket list
```

Expected: list includes `pulse`.

---

## Task 16: Enable public access on the bucket

R2 buckets are private by default. The exercise videos and manifest need to be fetched directly by iOS without auth. Two options:

- **Option A (chosen):** Public bucket via R2's public bucket feature with a custom domain or default `.r2.dev` domain. Simple, free.
- **Option B:** Signed URLs from the Worker. More secure but adds Worker work and per-request signing. Overkill for static public-domain exercise content.

- [ ] **Step 1: Enable public access via dashboard**

(Wrangler doesn't yet support enabling public bucket access via CLI cleanly. Use the dashboard.)

1. Open https://dash.cloudflare.com/
2. Navigate: **R2** → **pulse** bucket → **Settings** tab
3. Scroll to **Public access** → **R2.dev subdomain**
4. Click **Allow Access**, confirm the warning
5. Note the public URL: `https://pub-<hash>.r2.dev`

- [ ] **Step 2: Save the public R2 URL**

Append the public R2 URL to `worker/DEPLOY.md`:

```markdown

## R2 Bucket

**Bucket name:** `pulse`
**Public URL base:** `https://pub-<hash>.r2.dev`

All exercise videos, posters, and the manifest are fetched directly from
this URL by the iOS app (no Worker proxying needed for static assets).
```

Replace `<hash>` with your actual subdomain.

- [ ] **Step 3: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add worker/DEPLOY.md
git commit -m "docs(r2): enable public access on pulse bucket and document URL"
```

---

## Task 17: Generate R2 API credentials for the import script

The import script (in Section C) uses the S3-compatible API to upload to R2. This requires access keys.

- [ ] **Step 1: Create an R2 API token via dashboard**

1. Open https://dash.cloudflare.com/
2. Navigate: **R2** → **Manage R2 API Tokens** (top-right)
3. Click **Create API Token**
4. Name: `pulse-import-script`
5. Permissions: **Object Read & Write**
6. Specify bucket: `pulse` only
7. TTL: leave default (forever) or set to 1 year
8. Click **Create API Token**
9. **Save the displayed Access Key ID, Secret Access Key, and S3 endpoint URL** — they will not be shown again.

- [ ] **Step 2: Note the values for use in Task 21**

You'll need:
- `R2_ACCESS_KEY_ID` (the access key)
- `R2_SECRET_ACCESS_KEY` (the secret)
- `R2_ENDPOINT` (looks like `https://<account_id>.r2.cloudflarestorage.com`)
- `R2_BUCKET` (= `pulse`)

These will go into `tools/import-exercises/.env` later.

(No commit — credentials are never committed.)

---

# Section C — Content Import Pipeline (Tasks 18–32)

## Task 18: Verify ffmpeg is available

The import script uses `ffmpeg-static` (a bundled binary), so a system install isn't required, but it's worth verifying.

- [ ] **Step 1: Check system ffmpeg**

```bash
ffmpeg -version
```

Expected: prints version info. If not installed, `ffmpeg-static` will provide one bundled with npm later — no action needed.

---

## Task 19: Initialize the content pipeline project

**Files:**
- Create: `tools/import-exercises/package.json`
- Create: `tools/import-exercises/tsconfig.json`
- Create: `tools/import-exercises/.gitignore`
- Create: `tools/import-exercises/src/index.ts` (stub)

- [ ] **Step 1: Create the directory tree**

```bash
mkdir -p "/Users/smwein/Dev Project/Workout App/tools/import-exercises/src"
```

- [ ] **Step 2: Create package.json**

Create `tools/import-exercises/package.json`:

```json
{
  "name": "pulse-import-exercises",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc",
    "start": "tsx src/index.ts",
    "dryrun": "tsx src/index.ts --dry-run"
  },
  "dependencies": {
    "@aws-sdk/client-s3": "^3.600.0",
    "ffmpeg-static": "^5.2.0",
    "p-limit": "^5.0.0",
    "dotenv": "^16.4.0"
  },
  "devDependencies": {
    "@types/node": "^20.12.0",
    "tsx": "^4.16.0",
    "typescript": "^5.4.0"
  }
}
```

- [ ] **Step 3: Install dependencies**

```bash
cd "/Users/smwein/Dev Project/Workout App/tools/import-exercises"
npm install
```

Expected: completes successfully. `ffmpeg-static` will download a binary (~70 MB).

- [ ] **Step 4: Create tsconfig.json**

Create `tools/import-exercises/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "Bundler",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "allowImportingTsExtensions": false
  },
  "include": ["src/**/*"]
}
```

- [ ] **Step 5: Create .gitignore**

Create `tools/import-exercises/.gitignore`:

```
node_modules/
dist/
.env
cache/
output/
```

- [ ] **Step 6: Create stub index.ts**

Create `tools/import-exercises/src/index.ts`:

```typescript
console.log("import-exercises stub — pipeline not yet implemented");
```

- [ ] **Step 7: Verify it compiles**

```bash
cd "/Users/smwein/Dev Project/Workout App/tools/import-exercises"
npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 8: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add tools/import-exercises/package.json tools/import-exercises/package-lock.json tools/import-exercises/tsconfig.json tools/import-exercises/.gitignore tools/import-exercises/src/index.ts
git commit -m "$(cat <<'EOF'
chore(import-exercises): scaffold content pipeline project

TypeScript Node project with deps for S3 (R2), ffmpeg-static, and
concurrency limiting. Will fetch Free Exercise DB, convert photo pairs
to looping MP4s, upload to R2, publish manifest.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 20: Define types for the source and target schemas

**Files:**
- Create: `tools/import-exercises/src/types.ts`

- [ ] **Step 1: Create types**

Create `tools/import-exercises/src/types.ts`:

```typescript
// Source: free-exercise-db schema (one entry per exercise)
export interface FreeExerciseDbEntry {
  id: string;                      // e.g. "3_4_Sit-Up"
  name: string;
  force: "pull" | "push" | "static" | null;
  level: "beginner" | "intermediate" | "expert";
  mechanic: "compound" | "isolation" | null;
  equipment: string | null;
  primaryMuscles: string[];
  secondaryMuscles: string[];
  instructions: string[];
  category: string;                // "strength" | "stretching" | "plyometrics" | etc.
  images: string[];                // e.g. ["3_4_Sit-Up/0.jpg", "3_4_Sit-Up/1.jpg"]
}

// Target: what we publish to R2 in the Pulse manifest
export interface PulseExerciseAsset {
  id: string;                      // same as source id, lowercased + sanitized
  name: string;
  category: string;
  level: "beginner" | "intermediate" | "expert";
  equipment: string | null;
  primaryMuscles: string[];
  secondaryMuscles: string[];
  instructions: string[];
  videoURL: string;                // public R2 URL to the looping MP4
  posterURL: string;               // public R2 URL to the first-frame JPEG
}

export interface PulseManifest {
  version: number;                 // unix timestamp at build time
  generatedAt: string;             // ISO date
  exerciseCount: number;
  exercises: PulseExerciseAsset[];
}
```

- [ ] **Step 2: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add tools/import-exercises/src/types.ts
git commit -m "feat(import-exercises): define source and target schemas"
```

---

## Task 21: Set up environment variables

**Files:**
- Create: `tools/import-exercises/.env` (gitignored)

- [ ] **Step 1: Create .env**

Create `tools/import-exercises/.env`. **Replace placeholders with real values from Task 17:**

```
R2_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
R2_ENDPOINT=https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com
R2_BUCKET=pulse
R2_PUBLIC_URL=https://pub-<hash>.r2.dev
```

`R2_PUBLIC_URL` comes from Task 16.

- [ ] **Step 2: Verify it's gitignored**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git status tools/import-exercises/.env
```

Expected: file does not appear. (Already in `tools/import-exercises/.gitignore`.)

---

## Task 22: Implement source data fetching

**Files:**
- Create: `tools/import-exercises/src/fetchExercises.ts`

- [ ] **Step 1: Implement the fetch**

Create `tools/import-exercises/src/fetchExercises.ts`:

```typescript
import { FreeExerciseDbEntry } from "./types.ts";

const SOURCE_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json";

export async function fetchExerciseDb(): Promise<FreeExerciseDbEntry[]> {
  console.log(`Fetching source data from ${SOURCE_URL}…`);
  const response = await fetch(SOURCE_URL);
  if (!response.ok) {
    throw new Error(`Failed to fetch exercises.json: ${response.status} ${response.statusText}`);
  }
  const data = (await response.json()) as FreeExerciseDbEntry[];
  console.log(`Fetched ${data.length} exercises.`);
  return data;
}
```

- [ ] **Step 2: Smoke test inline**

Temporarily replace `tools/import-exercises/src/index.ts` with:

```typescript
import { fetchExerciseDb } from "./fetchExercises.ts";

const data = await fetchExerciseDb();
console.log(`First entry:`, JSON.stringify(data[0], null, 2));
console.log(`Total entries: ${data.length}`);
```

- [ ] **Step 3: Run it**

```bash
cd "/Users/smwein/Dev Project/Workout App/tools/import-exercises"
npm start
```

Expected: prints the first exercise object and a count near 800. If the fetch fails, debug before continuing — the rest of the pipeline depends on this.

- [ ] **Step 4: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add tools/import-exercises/src/fetchExercises.ts tools/import-exercises/src/index.ts
git commit -m "feat(import-exercises): fetch source JSON from free-exercise-db"
```

---

## Task 23: Implement image downloading with concurrency limit

**Files:**
- Create: `tools/import-exercises/src/downloadImages.ts`

- [ ] **Step 1: Implement download**

Create `tools/import-exercises/src/downloadImages.ts`:

```typescript
import { mkdir, writeFile, access } from "node:fs/promises";
import { dirname, join } from "node:path";
import pLimit from "p-limit";
import { FreeExerciseDbEntry } from "./types.ts";

const IMAGE_BASE = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises";
const CACHE_DIR = "./cache/images";
const DOWNLOAD_CONCURRENCY = 8;

async function fileExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

async function downloadOne(relativePath: string): Promise<string> {
  const localPath = join(CACHE_DIR, relativePath);

  if (await fileExists(localPath)) {
    return localPath; // skip — already downloaded
  }

  const url = `${IMAGE_BASE}/${relativePath}`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download ${url}: ${response.status}`);
  }
  const buffer = Buffer.from(await response.arrayBuffer());
  await mkdir(dirname(localPath), { recursive: true });
  await writeFile(localPath, buffer);
  return localPath;
}

export async function downloadAllImages(
  exercises: FreeExerciseDbEntry[]
): Promise<Map<string, string[]>> {
  const limit = pLimit(DOWNLOAD_CONCURRENCY);
  const results = new Map<string, string[]>();

  let completed = 0;
  const total = exercises.length;

  await Promise.all(
    exercises.map((ex) =>
      limit(async () => {
        const localPaths = await Promise.all(ex.images.map(downloadOne));
        results.set(ex.id, localPaths);
        completed++;
        if (completed % 50 === 0 || completed === total) {
          console.log(`  Downloaded images for ${completed}/${total} exercises`);
        }
      })
    )
  );

  return results;
}
```

- [ ] **Step 2: Smoke test with one exercise**

Replace `tools/import-exercises/src/index.ts` with:

```typescript
import { fetchExerciseDb } from "./fetchExercises.ts";
import { downloadAllImages } from "./downloadImages.ts";

const all = await fetchExerciseDb();
const sample = all.slice(0, 3);
console.log(`Downloading images for ${sample.length} exercises (smoke test)…`);
const results = await downloadAllImages(sample);
for (const [id, paths] of results) {
  console.log(`  ${id} → ${paths.length} images: ${paths.join(", ")}`);
}
```

- [ ] **Step 3: Run smoke test**

```bash
cd "/Users/smwein/Dev Project/Workout App/tools/import-exercises"
npm start
```

Expected: downloads ~6 images (3 exercises × 2 images), prints local paths under `cache/images/`. Verify files exist:

```bash
ls cache/images/
```

- [ ] **Step 4: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add tools/import-exercises/src/downloadImages.ts tools/import-exercises/src/index.ts
git commit -m "$(cat <<'EOF'
feat(import-exercises): download source images with concurrency limit and cache

Skips re-downloading files that already exist locally so the pipeline is
re-runnable without burning bandwidth.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 24: Implement ffmpeg encoding (2 photos → looping MP4)

**Files:**
- Create: `tools/import-exercises/src/encodeMp4.ts`

The strategy: ffmpeg takes the two start/end position photos, holds each for 1.5 seconds with a brief crossfade, outputs a 3-second H.264 MP4 sized 720×720 square. AVPlayer will loop it seamlessly.

- [ ] **Step 1: Implement encoding**

Create `tools/import-exercises/src/encodeMp4.ts`:

```typescript
import { spawn } from "node:child_process";
import { mkdir, copyFile, access } from "node:fs/promises";
import { dirname, join } from "node:path";
import ffmpegPath from "ffmpeg-static";

const OUTPUT_DIR = "./output";
const FRAME_DURATION_SEC = 1.5;
const CROSSFADE_SEC = 0.3;
const SIZE = 720;

if (!ffmpegPath) {
  throw new Error("ffmpeg-static did not provide a binary path");
}

async function fileExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

function runFfmpeg(args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const proc = spawn(ffmpegPath as string, args, { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    proc.stderr.on("data", (chunk) => (stderr += chunk.toString()));
    proc.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg exited with code ${code}: ${stderr.slice(-500)}`));
    });
    proc.on("error", reject);
  });
}

/**
 * Combines 1 or 2 source images into a 3s looping MP4.
 * - 2 images: hold each for 1.5s with a 0.3s crossfade between
 * - 1 image: 3s static MP4 (still loopable)
 *
 * Returns the path to the output MP4 + the path to the poster JPEG.
 */
export async function encodeExerciseClip(
  exerciseId: string,
  sourceImages: string[]
): Promise<{ mp4Path: string; posterPath: string }> {
  if (sourceImages.length === 0) {
    throw new Error(`Exercise ${exerciseId} has no source images`);
  }

  const mp4Path = join(OUTPUT_DIR, `${exerciseId}.mp4`);
  const posterPath = join(OUTPUT_DIR, `${exerciseId}-poster.jpg`);
  await mkdir(dirname(mp4Path), { recursive: true });

  // Skip if already encoded (re-runnable)
  if (await fileExists(mp4Path) && await fileExists(posterPath)) {
    return { mp4Path, posterPath };
  }

  // Poster: copy first source image (we'll re-encode to JPEG below)
  await runFfmpeg([
    "-y",
    "-i", sourceImages[0],
    "-vf", `scale=${SIZE}:${SIZE}:force_original_aspect_ratio=decrease,pad=${SIZE}:${SIZE}:(ow-iw)/2:(oh-ih)/2:color=black`,
    "-q:v", "2",
    posterPath,
  ]);

  if (sourceImages.length === 1) {
    // Single static frame held for 3s
    await runFfmpeg([
      "-y",
      "-loop", "1",
      "-t", "3",
      "-i", sourceImages[0],
      "-vf", `scale=${SIZE}:${SIZE}:force_original_aspect_ratio=decrease,pad=${SIZE}:${SIZE}:(ow-iw)/2:(oh-ih)/2:color=black`,
      "-c:v", "libx264",
      "-pix_fmt", "yuv420p",
      "-r", "30",
      "-movflags", "+faststart",
      mp4Path,
    ]);
  } else {
    // Two-frame oscillation with crossfade.
    // Hold each frame for FRAME_DURATION_SEC, then crossfade for CROSSFADE_SEC,
    // total: 2 * (FRAME_DURATION + CROSSFADE) = 3.6s
    const total = 2 * (FRAME_DURATION_SEC + CROSSFADE_SEC);
    await runFfmpeg([
      "-y",
      "-loop", "1", "-t", String(FRAME_DURATION_SEC + CROSSFADE_SEC), "-i", sourceImages[0],
      "-loop", "1", "-t", String(FRAME_DURATION_SEC + CROSSFADE_SEC), "-i", sourceImages[1],
      "-filter_complex",
        `[0:v]scale=${SIZE}:${SIZE}:force_original_aspect_ratio=decrease,pad=${SIZE}:${SIZE}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1[v0];` +
        `[1:v]scale=${SIZE}:${SIZE}:force_original_aspect_ratio=decrease,pad=${SIZE}:${SIZE}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1[v1];` +
        `[v0][v1]xfade=transition=fade:duration=${CROSSFADE_SEC}:offset=${FRAME_DURATION_SEC}[out]`,
      "-map", "[out]",
      "-c:v", "libx264",
      "-pix_fmt", "yuv420p",
      "-r", "30",
      "-t", String(total),
      "-movflags", "+faststart",
      mp4Path,
    ]);
  }

  return { mp4Path, posterPath };
}
```

- [ ] **Step 2: Smoke test with one exercise**

Replace `tools/import-exercises/src/index.ts`:

```typescript
import { fetchExerciseDb } from "./fetchExercises.ts";
import { downloadAllImages } from "./downloadImages.ts";
import { encodeExerciseClip } from "./encodeMp4.ts";

const all = await fetchExerciseDb();
const sample = all.slice(0, 1);
const downloaded = await downloadAllImages(sample);
for (const ex of sample) {
  const images = downloaded.get(ex.id)!;
  console.log(`Encoding ${ex.id} from ${images.length} images…`);
  const { mp4Path, posterPath } = await encodeExerciseClip(ex.id, images);
  console.log(`  MP4: ${mp4Path}`);
  console.log(`  Poster: ${posterPath}`);
}
```

- [ ] **Step 3: Run**

```bash
cd "/Users/smwein/Dev Project/Workout App/tools/import-exercises"
npm start
```

Expected: produces `output/3_4_Sit-Up.mp4` (or whichever exercise is first) and `output/3_4_Sit-Up-poster.jpg`. Open the MP4 in QuickTime / VLC to verify it shows the 2-frame oscillation.

- [ ] **Step 4: If MP4 looks correct, commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add tools/import-exercises/src/encodeMp4.ts tools/import-exercises/src/index.ts
git commit -m "$(cat <<'EOF'
feat(import-exercises): encode 2-photo exercise clips with ffmpeg crossfade

Each clip is 720x720 H.264, ~3.6s, two reference photos crossfaded.
Looped by AVPlayer in the iOS app for a "demonstration in motion" feel.
Falls back to a 3s static clip if only one source image exists.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 25: Implement R2 upload helper

**Files:**
- Create: `tools/import-exercises/src/uploadR2.ts`

- [ ] **Step 1: Implement upload**

Create `tools/import-exercises/src/uploadR2.ts`:

```typescript
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { readFile } from "node:fs/promises";
import "dotenv/config";

const {
  R2_ACCESS_KEY_ID,
  R2_SECRET_ACCESS_KEY,
  R2_ENDPOINT,
  R2_BUCKET,
} = process.env;

if (!R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY || !R2_ENDPOINT || !R2_BUCKET) {
  throw new Error("Missing R2 env vars — check .env");
}

const client = new S3Client({
  region: "auto",
  endpoint: R2_ENDPOINT,
  credentials: {
    accessKeyId: R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY,
  },
});

export async function uploadFile(localPath: string, key: string, contentType: string): Promise<void> {
  const body = await readFile(localPath);
  await client.send(
    new PutObjectCommand({
      Bucket: R2_BUCKET,
      Key: key,
      Body: body,
      ContentType: contentType,
      CacheControl: "public, max-age=31536000, immutable",
    })
  );
}

export async function uploadJson(key: string, value: unknown): Promise<void> {
  await client.send(
    new PutObjectCommand({
      Bucket: R2_BUCKET,
      Key: key,
      Body: JSON.stringify(value, null, 2),
      ContentType: "application/json; charset=utf-8",
      CacheControl: "public, max-age=300", // manifest can refresh
    })
  );
}
```

- [ ] **Step 2: Smoke test — upload one file**

Replace `tools/import-exercises/src/index.ts`:

```typescript
import { fetchExerciseDb } from "./fetchExercises.ts";
import { downloadAllImages } from "./downloadImages.ts";
import { encodeExerciseClip } from "./encodeMp4.ts";
import { uploadFile } from "./uploadR2.ts";

const all = await fetchExerciseDb();
const sample = all.slice(0, 1);
const downloaded = await downloadAllImages(sample);
for (const ex of sample) {
  const { mp4Path, posterPath } = await encodeExerciseClip(ex.id, downloaded.get(ex.id)!);
  console.log("Uploading MP4…");
  await uploadFile(mp4Path, `exercises/${ex.id}.mp4`, "video/mp4");
  console.log("Uploading poster…");
  await uploadFile(posterPath, `exercises/${ex.id}-poster.jpg`, "image/jpeg");
  console.log(`Done. Should be at:`);
  console.log(`  ${process.env.R2_PUBLIC_URL}/exercises/${ex.id}.mp4`);
  console.log(`  ${process.env.R2_PUBLIC_URL}/exercises/${ex.id}-poster.jpg`);
}
```

- [ ] **Step 3: Run**

```bash
cd "/Users/smwein/Dev Project/Workout App/tools/import-exercises"
npm start
```

Expected: prints "Done." and two URLs. Open the MP4 URL in a browser — it should load and play. Open the poster URL — it should display.

If you get a 403 or "AccessDenied", the bucket isn't public (re-do Task 16) or the API token lacks write perms (re-do Task 17).

- [ ] **Step 4: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add tools/import-exercises/src/uploadR2.ts tools/import-exercises/src/index.ts
git commit -m "feat(import-exercises): upload encoded clips and posters to R2 via S3 SDK"
```

---

## Task 26: Implement manifest building

**Files:**
- Create: `tools/import-exercises/src/buildManifest.ts`

- [ ] **Step 1: Implement**

Create `tools/import-exercises/src/buildManifest.ts`:

```typescript
import "dotenv/config";
import { FreeExerciseDbEntry, PulseExerciseAsset, PulseManifest } from "./types.ts";

const PUBLIC_URL = process.env.R2_PUBLIC_URL;
if (!PUBLIC_URL) {
  throw new Error("Missing R2_PUBLIC_URL env var");
}

export function buildExerciseAsset(entry: FreeExerciseDbEntry): PulseExerciseAsset {
  return {
    id: entry.id,
    name: entry.name,
    category: entry.category,
    level: entry.level,
    equipment: entry.equipment,
    primaryMuscles: entry.primaryMuscles,
    secondaryMuscles: entry.secondaryMuscles,
    instructions: entry.instructions,
    videoURL: `${PUBLIC_URL}/exercises/${entry.id}.mp4`,
    posterURL: `${PUBLIC_URL}/exercises/${entry.id}-poster.jpg`,
  };
}

export function buildManifest(entries: FreeExerciseDbEntry[]): PulseManifest {
  const exercises = entries.map(buildExerciseAsset);
  return {
    version: Math.floor(Date.now() / 1000),
    generatedAt: new Date().toISOString(),
    exerciseCount: exercises.length,
    exercises,
  };
}
```

- [ ] **Step 2: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add tools/import-exercises/src/buildManifest.ts
git commit -m "feat(import-exercises): build typed manifest from source entries"
```

---

## Task 27: Wire the full pipeline together with progress logging and resume safety

**Files:**
- Modify: `tools/import-exercises/src/index.ts`

- [ ] **Step 1: Replace index.ts with the full orchestrator**

Replace `tools/import-exercises/src/index.ts` with:

```typescript
import "dotenv/config";
import { writeFile } from "node:fs/promises";
import pLimit from "p-limit";
import { fetchExerciseDb } from "./fetchExercises.ts";
import { downloadAllImages } from "./downloadImages.ts";
import { encodeExerciseClip } from "./encodeMp4.ts";
import { uploadFile, uploadJson } from "./uploadR2.ts";
import { buildManifest } from "./buildManifest.ts";
import { FreeExerciseDbEntry } from "./types.ts";

const ENCODE_CONCURRENCY = 4;   // ffmpeg is CPU-heavy
const UPLOAD_CONCURRENCY = 8;   // network-bound

const dryRun = process.argv.includes("--dry-run");

async function processOne(
  ex: FreeExerciseDbEntry,
  imagesByExercise: Map<string, string[]>
): Promise<void> {
  const images = imagesByExercise.get(ex.id);
  if (!images || images.length === 0) {
    console.warn(`  SKIP ${ex.id} — no source images`);
    return;
  }

  const { mp4Path, posterPath } = await encodeExerciseClip(ex.id, images);

  if (dryRun) {
    return;
  }

  await uploadFile(mp4Path, `exercises/${ex.id}.mp4`, "video/mp4");
  await uploadFile(posterPath, `exercises/${ex.id}-poster.jpg`, "image/jpeg");
}

async function main() {
  console.log(`Starting Pulse content pipeline${dryRun ? " (DRY RUN — no uploads)" : ""}\n`);

  // 1. Fetch source data
  const all = await fetchExerciseDb();

  // 2. Download all source images
  console.log(`\nDownloading source images (resumes from cache)…`);
  const imagesByExercise = await downloadAllImages(all);

  // 3. Encode + upload (with concurrency)
  console.log(`\nEncoding + uploading ${all.length} exercises…`);
  const limit = pLimit(ENCODE_CONCURRENCY);
  let completed = 0;
  const errors: { id: string; error: string }[] = [];

  await Promise.all(
    all.map((ex) =>
      limit(async () => {
        try {
          await processOne(ex, imagesByExercise);
        } catch (e) {
          errors.push({ id: ex.id, error: String(e) });
        }
        completed++;
        if (completed % 25 === 0 || completed === all.length) {
          console.log(`  ${completed}/${all.length} processed (${errors.length} errors)`);
        }
      })
    )
  );

  // 4. Build + upload manifest (skip if errors > 5%)
  const errorRate = errors.length / all.length;
  if (errorRate > 0.05) {
    console.error(`\n${errors.length} errors (>5%). Not publishing manifest.`);
    console.error(errors.slice(0, 10));
    process.exit(1);
  }

  const manifest = buildManifest(all.filter((ex) => !errors.some((e) => e.id === ex.id)));
  await writeFile("./output/manifest.json", JSON.stringify(manifest, null, 2));
  console.log(`\nManifest: ${manifest.exerciseCount} exercises (${errors.length} skipped).`);

  if (dryRun) {
    console.log(`(DRY RUN — manifest written locally to output/manifest.json, not uploaded.)`);
    return;
  }

  await uploadJson("exercises/manifest.json", manifest);
  console.log(`\n✓ Manifest published.`);
  console.log(`  Public URL: ${process.env.R2_PUBLIC_URL}/exercises/manifest.json`);

  if (errors.length > 0) {
    console.warn(`\n${errors.length} exercises were skipped due to errors:`);
    errors.forEach((e) => console.warn(`  ${e.id}: ${e.error.slice(0, 200)}`));
  }
}

main().catch((e) => {
  console.error("Pipeline failed:", e);
  process.exit(1);
});
```

- [ ] **Step 2: Dry-run smoke test (no uploads, but encodes everything)**

```bash
cd "/Users/smwein/Dev Project/Workout App/tools/import-exercises"
npm run dryrun
```

Expected: downloads all source images (~30 min on first run, instant on re-runs from cache), encodes all 800 exercises (~30–60 min depending on Mac), writes `output/manifest.json` locally. Inspect:

```bash
head -40 output/manifest.json
```

Should show 2–3 exercise entries with proper URL formatting.

If anything errors, fix before running the upload pass.

- [ ] **Step 3: Commit (do this BEFORE the real upload run, so the orchestrator code is saved)**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add tools/import-exercises/src/index.ts
git commit -m "$(cat <<'EOF'
feat(import-exercises): wire full pipeline with concurrency, resume, dry-run

Orchestrates fetch → download → encode → upload → manifest with bounded
concurrency. Caches downloaded images and encoded MP4s on disk so re-runs
skip already-completed work. Aborts manifest publish if >5% of exercises
fail. --dry-run flag runs everything except R2 uploads.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 28: Run the full pipeline (the actual data load)

**Files:** None (data only).

- [ ] **Step 1: Run the full pipeline**

```bash
cd "/Users/smwein/Dev Project/Workout App/tools/import-exercises"
npm start
```

Expected: ~30–90 minutes total. Output ends with:

```
✓ Manifest published.
  Public URL: https://pub-<hash>.r2.dev/exercises/manifest.json
```

If errors > 5%, the script exits non-zero and prints the failures. Fix the cause and re-run (cached work is preserved).

- [ ] **Step 2: Verify manifest is fetchable**

```bash
curl -s "$R2_PUBLIC_URL/exercises/manifest.json" | head -40
```

(Or paste the URL into a browser.)

Expected: JSON manifest with `version`, `exerciseCount`, and an `exercises` array.

- [ ] **Step 3: Verify a video is fetchable**

Pick any exercise from the manifest, copy its `videoURL`, paste into a browser. Should play in browser's native HTML5 player.

---

## Task 29: Document the import script

**Files:**
- Create: `tools/import-exercises/README.md`

- [ ] **Step 1: Write the README**

Create `tools/import-exercises/README.md`:

```markdown
# pulse-import-exercises

One-time content pipeline that loads Free Exercise DB into R2 for the Pulse iOS app.

## What it does

1. Fetches `dist/exercises.json` from https://github.com/yuhonas/free-exercise-db
2. Downloads each exercise's reference photos (2 per exercise, typically) from the same repo
3. Uses ffmpeg to combine each photo pair into a 720×720, ~3.6s looping MP4 with a 0.3s crossfade between frames
4. Uploads MP4s + first-frame JPEG posters to R2 (`pulse` bucket, `exercises/` prefix)
5. Builds a typed `manifest.json` and uploads it to R2

## Setup

```bash
npm install
cp .env.example .env  # then fill in R2 credentials
```

`.env` requires:
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_ENDPOINT` (e.g. `https://<account_id>.r2.cloudflarestorage.com`)
- `R2_BUCKET` (= `pulse`)
- `R2_PUBLIC_URL` (e.g. `https://pub-<hash>.r2.dev`)

## Usage

```bash
# Dry run (encodes locally, no uploads)
npm run dryrun

# Full run
npm start
```

The pipeline is **resumable** — downloaded images and encoded MP4s are cached
under `cache/` and `output/`. Re-running skips completed work.

## Output

- R2: `exercises/<id>.mp4`, `exercises/<id>-poster.jpg` for each exercise
- R2: `exercises/manifest.json` (the catalog the iOS app fetches at launch)
- Local: same files in `output/` for inspection / re-upload

## License

Source data is from `yuhonas/free-exercise-db` under the Unlicense (public domain).
This pipeline code is unlicensed; treat it as private to the Pulse project.
```

- [ ] **Step 2: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add tools/import-exercises/README.md
git commit -m "docs(import-exercises): explain pipeline, setup, and usage"
```

---

## Task 30: Add a .env.example for safety

**Files:**
- Create: `tools/import-exercises/.env.example`

- [ ] **Step 1: Create the example**

Create `tools/import-exercises/.env.example`:

```
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_ENDPOINT=https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com
R2_BUCKET=pulse
R2_PUBLIC_URL=https://pub-XXXXXXXX.r2.dev
```

- [ ] **Step 2: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add tools/import-exercises/.env.example
git commit -m "chore(import-exercises): add .env.example template"
```

---

# Section D — End-to-End Smoke Test (Tasks 31–33)

## Task 31: Verify the full Foundation stack works as iOS will use it

This is a manual smoke test simulating what the iOS app will do at launch and during plan generation.

- [ ] **Step 1: Fetch the manifest (simulates iOS app launch)**

Replace `R2_PUBLIC_URL`:

```bash
curl -s "$R2_PUBLIC_URL/exercises/manifest.json" | python3 -c "
import json, sys
m = json.load(sys.stdin)
print(f'version: {m[\"version\"]}')
print(f'count: {m[\"exerciseCount\"]}')
print(f'sample: {m[\"exercises\"][0][\"name\"]} → {m[\"exercises\"][0][\"videoURL\"]}')
"
```

Expected: prints version, count near 800, and one exercise with a `pub-<hash>.r2.dev` URL.

- [ ] **Step 2: Fetch a video (simulates iOS pre-fetching demos)**

```bash
SAMPLE_URL=$(curl -s "$R2_PUBLIC_URL/exercises/manifest.json" | python3 -c "
import json, sys
print(json.load(sys.stdin)['exercises'][0]['videoURL'])
")
echo "Fetching $SAMPLE_URL"
curl -s -o /tmp/sample.mp4 "$SAMPLE_URL"
ls -lh /tmp/sample.mp4
```

Expected: file is ~50–200 KB, downloads cleanly.

- [ ] **Step 3: Generate a plan via the Worker (simulates iOS plan generation)**

This sends a Claude Sonnet 4.6 request through the Worker, asking for a tiny test plan. Replace `WORKER_URL` and `DEVICE_TOKEN`:

```bash
curl -N -X POST "$WORKER_URL" \
  -H "X-Device-Token: $DEVICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 200,
    "messages": [{
      "role": "user",
      "content": "Output exactly: ⟦CHECKPOINT: reading⟧ ⟦CHECKPOINT: planning⟧ done"
    }]
  }'
```

Expected: SSE stream where the model emits the checkpoint markers as text content. This proves the iOS streaming-checkpoint UX will work end-to-end through the proxy.

- [ ] **Step 4: Mark Foundation complete**

If all three pass, the Foundation is shippable. The iOS app can be built against it.

---

## Task 32: Push everything to origin

**Files:** None.

- [ ] **Step 1: Push**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git push origin main
```

Expected: pushes all Foundation commits to GitHub. Verify on https://github.com/smwein/Pulse — `worker/` and `tools/import-exercises/` both visible (no `.env`, no `.dev.vars`, no `node_modules/`).

---

## Task 33: Update the spec with realized URLs

**Files:**
- Modify: `docs/superpowers/specs/2026-04-26-pulse-ai-trainer-app-design.md`

The spec currently has placeholders like `https://pulse-r2.example.com`. Update them to the real URLs so Plan 2 (iOS app) can reference them.

- [ ] **Step 1: Search for placeholder URLs**

```bash
cd "/Users/smwein/Dev Project/Workout App"
grep -n "pulse-r2.example.com\|pulse-proxy" docs/superpowers/specs/*.md
```

- [ ] **Step 2: Add an "Operational URLs" section**

Append this to the end of `docs/superpowers/specs/2026-04-26-pulse-ai-trainer-app-design.md`. **Replace the bracketed placeholders with the real values from Tasks 11 and 16:**

```markdown

---

## Appendix A — Operational URLs (filled in after Plan 1)

- **Worker proxy URL:** `https://[YOUR-WORKER-URL]/`
- **R2 public bucket URL:** `https://pub-[HASH].r2.dev`
- **Manifest URL:** `https://pub-[HASH].r2.dev/exercises/manifest.json`
- **Device token:** stored in `worker/.dev.vars` (not in git). The same token must be baked into the iOS build's secrets.

These values are referenced by Plan 2 (iOS app) — keep them in sync.
```

- [ ] **Step 3: Commit**

```bash
cd "/Users/smwein/Dev Project/Workout App"
git add docs/superpowers/specs/2026-04-26-pulse-ai-trainer-app-design.md
git commit -m "docs(spec): add Appendix A with realized Foundation URLs"
git push origin main
```

---

# Done — Foundation Plan Complete

After this plan:
- ✓ Cloudflare Worker live at your `workers.dev` URL, proxying Anthropic with auth
- ✓ R2 bucket `pulse` populated with ~800 exercise MP4s + posters + manifest
- ✓ Manifest fetchable as a public URL
- ✓ End-to-end LLM streaming verifiable via curl
- ✓ All code in the GitHub repo, secrets out of git
- ✓ Operational procedures documented in `worker/DEPLOY.md`

**Next:** Plan 2 — iOS App + Watch (the vertical slice). Will be written separately and reference the URLs realized here.
