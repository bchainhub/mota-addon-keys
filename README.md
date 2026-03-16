# Keys registry MOTA addon

Keys registry MOTA addon for SvelteKit projects. Adds a **Keys Registry** route with GPG and ORIC key types: index page, type-specific pages, copy/download, and optional key-server links. Uses [typesafe-i18n](https://github.com/ivanhofer/typesafe-i18n) for translations (en, sk, ru).

**Repository:** [https://github.com/bchainhub/mota-addon-keys](https://github.com/bchainhub/mota-addon-keys)

## Requirements

- A SvelteKit project that uses the **MOTA addon CLI** (e.g. from [dapp-starter](https://github.com/bchainhub/dapp-starter)).
- Project must have `src/i18n/<lang>/index.ts` (e.g. typesafe-i18n) so the addon can merge translation keys.
- Routes use `[[lang]]` (optional lang segment); adjust paths if your app uses a different layout.

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
  - `src/routes/[[lang]]/keys/+page.svelte` — Keys Registry index (links to GPG and ORIC).
  - `src/routes/[[lang]]/keys/gpg/+page.svelte` — GPG keys page (copy, download, key server link).
  - `src/routes/[[lang]]/keys/gpg/keys.data.ts` — Sample GPG key data.
  - `src/routes/[[lang]]/keys/oric/+page.svelte` — ORIC keys page.
  - `src/routes/[[lang]]/keys/oric/keys.data.ts` — Sample ORIC key list.
- **Translations** — Merged into `src/i18n/en/index.ts`, `src/i18n/sk/index.ts`, `src/i18n/ru/index.ts` under `modules.keyRegistry` (e.g. keyRegistry, welcome, keyTypes, copyKey, downloadKey, …).

After install, run your i18n step if needed (e.g. `npx typesafe-i18n --no-watch`).

## Uninstall

From your project root:

```bash
npx addon bchainhub/mota-addon-keys keys uninstall
```

### What gets removed

- The five route files under `src/routes/[[lang]]/keys/` (index, gpg and oric pages and data files), and empty `keys` directories.
- The `keyRegistry` block from `modules` in each of `src/i18n/en/index.ts`, `src/i18n/sk/index.ts`, `src/i18n/ru/index.ts`.

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

Append `#<ref>` to the repo to use a tag, branch, or commit:

```bash
npx addon bchainhub/mota-addon-keys#1.0.0 keys install
npx addon bchainhub/mota-addon-keys#main keys uninstall
```

## License

Licensed under the MIT License.
