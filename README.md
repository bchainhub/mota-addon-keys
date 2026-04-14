# Keys registry MOTA addon

Keys registry MOTA addon for SvelteKit projects. Adds a **Keys Registry** route at `/keys` that loads **optional** well-known files: **`signing-keys.json`**, **`oric.json`**, and **`fintag.json`**. Each file is fetched independently; **missing files (404) are ignored** with no error. Invalid JSON or wrong shape adds a **warning** and skips that section. Uses [typesafe-i18n](https://github.com/ivanhofer/typesafe-i18n) for translations: en, sk, ru, de, es, ja, pt-br, th, zh-cn (Simplified Chinese).

**Repository:** [https://github.com/bchainhub/mota-addon-keys](https://github.com/bchainhub/mota-addon-keys)

## Requirements

- A SvelteKit project that uses the **MOTA addon CLI** (e.g. from [dapp-starter](https://github.com/bchainhub/dapp-starter)).
- Project must have `src/i18n/<lang>/index.ts` (e.g. typesafe-i18n) so the addon can merge translation keys.
- Routes use `[[lang]]` (optional lang segment); adjust paths if your app uses a different layout.
- Place files under **`static/.well-known/`** in the host app so they are served at **`/.well-known/…`**. There is **no** combined `keys.json`; ORIC and FinTag are **not** embedded in the signing file.

## Well-known files (optional, any subset)

| File | URL | Purpose |
| --- | --- | --- |
| Signing keys | `/.well-known/signing-keys.json` | JOSE/JWK public keys (`issuer` optional, `keys` required array) |
| ORIC | `/.well-known/oric.json` | JSON **array of strings** (ORIC codes) |
| FinTag | `/.well-known/fintag.json` | JSON **array of objects** (each object has at least one property) |

### `static/.well-known/signing-keys.json`

Object with:

- `issuer` (string, optional)
- `keys` (array): each object must include `kid`; other JWK fields optional.

Detail hash: `signing--{kid}` (URL-encoded).

### `static/.well-known/oric.json`

The **entire file** is a JSON array of strings:

```json
["PINGCHB2XCB", "WALLUS01XXX"]
```

Detail hash: `oric--{key}` (URL-encoded).

### `static/.well-known/fintag.json`

The **entire file** is a JSON array of objects (typically one FinTag property per object):

```json
[{ "ican:xcb": "" }, { "ican:xcb": "cb00…" }, { "void:plus": "8FWR5XCG+VM" }]
```

Detail hash: `fintag--0`, `fintag--1`, … (array index).

## Install

From your project root:

```bash
npx addon bchainhub/mota-addon-keys keys install
```

With optional flags:

```bash
npx addon bchainhub/mota-addon-keys keys install --cache
npx addon bchainhub/mota-addon-keys keys install --dry-run
```

### What gets added

- **Routes**
  - `src/routes/[[lang]]/keys/+page.svelte` — fetches the three well-known files in the browser (`onMount`). Missing files are skipped; the registry is not loaded during SSR.
- **Translations** — Merged into `src/i18n/<locale>/index.ts` for each bundled locale under `modules.keyRegistry`.

After install, run your i18n step if needed (e.g. `npx typesafe-i18n --no-watch`).

## Uninstall

```bash
npx addon bchainhub/mota-addon-keys keys uninstall
```

### What gets removed

- `src/routes/[[lang]]/keys/+page.svelte` and empty `keys` directory when possible.
- The `keyRegistry` block from `modules` in each matching `src/i18n/<locale>/index.ts`.

Optional flags (same as install):

```bash
npx addon bchainhub/mota-addon-keys keys uninstall --dry-run
npx addon bchainhub/mota-addon-keys keys uninstall --no-translations
npx addon bchainhub/mota-addon-keys keys uninstall --no-scripts
```

## Addon options

| Flag | Short | Description |
| --- | --- | --- |
| `--cache` | `-c` | Use cache dir for repo (faster re-runs). |
| `--dry-run` | `-d` | No writes; scripts and _lang steps are skipped. |
| `--no-translations` | `-nt` | Skip _lang (translations) processing. |
| `--no-scripts` | `-ns` | Skip _scripts execution (uninstall only: skips file removal). |

## Pinning a version

```bash
npx addon bchainhub/mota-addon-keys#1.0.0 keys install
npx addon bchainhub/mota-addon-keys#main keys uninstall
```

## License

Licensed under the MIT License.
