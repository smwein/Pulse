#!/usr/bin/env bash
set -euo pipefail

# Generates ios/PulseApp/Secrets.swift from worker/.dev.vars.
# Idempotent — safe to re-run. Run before every Xcode build.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEV_VARS="$REPO_ROOT/worker/.dev.vars"
TEMPLATE="$REPO_ROOT/ios/PulseApp/Secrets.swift.template"
OUTPUT="$REPO_ROOT/ios/PulseApp/Secrets.swift"

if [[ ! -f "$DEV_VARS" ]]; then
  echo "error: $DEV_VARS not found — cannot bake secrets" >&2
  exit 1
fi
if [[ ! -f "$TEMPLATE" ]]; then
  echo "error: $TEMPLATE not found" >&2
  exit 1
fi

# Source the .dev.vars file (KEY=VALUE lines, possibly quoted)
set -a
# shellcheck disable=SC1090
source "$DEV_VARS"
set +a

WORKER_URL="${WORKER_URL:-https://pulse-proxy.smwein.workers.dev/}"
DEVICE_TOKEN="${DEVICE_TOKEN:?DEVICE_TOKEN missing from worker/.dev.vars}"
MANIFEST_URL="${MANIFEST_URL:-https://pub-5b5246fd91ca43198f55ea2e02173da2.r2.dev/exercises/manifest.json}"

sed \
  -e "s|__WORKER_URL__|${WORKER_URL}|g" \
  -e "s|__DEVICE_TOKEN__|${DEVICE_TOKEN}|g" \
  -e "s|__MANIFEST_URL__|${MANIFEST_URL}|g" \
  "$TEMPLATE" > "$OUTPUT"

echo "baked: $OUTPUT"
