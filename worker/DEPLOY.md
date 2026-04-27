# pulse-proxy — Deployment Status

**Production URL:** `https://pulse-proxy.smwein.workers.dev/`

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

## Local development

```
cd worker
wrangler dev
```

`.dev.vars` (gitignored) holds local-only values for `ANTHROPIC_API_KEY` and `DEVICE_TOKEN`. The same `DEVICE_TOKEN` value should be set in both `.dev.vars` and via `wrangler secret put` for production so iOS can use one token across environments (or rotate them independently if you want stricter isolation).
