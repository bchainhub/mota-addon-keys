#!/usr/bin/env bash
set -euo pipefail

KEYS_BASE="src/routes/[[lang]]/keys"
rm -f "${KEYS_BASE}/+page.svelte"

rmdir "${KEYS_BASE}" 2>/dev/null || true
