#!/usr/bin/env bash
set -euo pipefail

# Remove data files added by keys install (paths relative to project root)
DATA_BASE="src/data"
rm -f "${DATA_BASE}/keys.gpg.ts"
rm -f "${DATA_BASE}/keys.oric.ts"

# Remove route files added by keys install
KEYS_BASE="src/routes/[[lang]]/keys"
rm -f "${KEYS_BASE}/+page.svelte"
rm -f "${KEYS_BASE}/oric/+page.svelte"
rm -f "${KEYS_BASE}/gpg/+page.svelte"

# Remove empty dirs (optional; rmdir no-ops if not empty)
rmdir "${KEYS_BASE}/oric" 2>/dev/null || true
rmdir "${KEYS_BASE}/gpg" 2>/dev/null || true
rmdir "${KEYS_BASE}" 2>/dev/null || true
