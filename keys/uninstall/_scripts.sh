#!/usr/bin/env bash
set -euo pipefail

# Remove route files added by keys install (paths relative to project root)
KEYS_BASE="src/routes/[[lang]]/keys"
rm -f "${KEYS_BASE}/+page.svelte"
rm -f "${KEYS_BASE}/oric/+page.svelte"
rm -f "${KEYS_BASE}/oric/keys.data.ts"
rm -f "${KEYS_BASE}/gpg/+page.svelte"
rm -f "${KEYS_BASE}/gpg/keys.data.ts"

# Remove empty dirs (optional; rmdir no-ops if not empty)
rmdir "${KEYS_BASE}/oric" 2>/dev/null || true
rmdir "${KEYS_BASE}/gpg" 2>/dev/null || true
rmdir "${KEYS_BASE}" 2>/dev/null || true
