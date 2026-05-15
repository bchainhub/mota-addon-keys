---
to: src/routes/[[lang]]/keys/+page.svelte
---
<script lang="ts">
	import { onMount } from 'svelte';
	import { Copy, Download } from 'lucide-svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { copyToClipboard } from '$lib/helpers/keys';
	import { LL } from '$lib/helpers/i18n';

	type SigningKeyJwk = { kid: string } & Record<string, unknown>;

	type SigningDoc = {
		issuer?: string;
		keys: SigningKeyJwk[];
	};

	type NostrNames = Record<string, string>;
	type NostrRelays = Record<string, string[]>;

	type NostrDoc = {
		names: NostrNames;
		relays?: NostrRelays;
	};

	type FintagEntry = Record<string, unknown>;

	type KeysRegistryDoc = {
		signing?: SigningDoc;
		nostr?: NostrDoc;
		oric?: string[];
		fintag?: FintagEntry[];
	};

	function isSigningDoc(v: unknown): v is SigningDoc {
		if (!v || typeof v !== 'object' || Array.isArray(v)) return false;
		const o = v as Record<string, unknown>;
		if (!Array.isArray(o.keys)) return false;
		return o.keys.every(
			(k) => k && typeof k === 'object' && typeof (k as SigningKeyJwk).kid === 'string'
		);
	}

	function isHexPubkey(v: unknown): v is string {
		return typeof v === 'string' && /^[0-9a-f]{64}$/i.test(v);
	}

	function isNostrDoc(v: unknown): v is NostrDoc {
		if (!v || typeof v !== 'object' || Array.isArray(v)) return false;
		const o = v as Record<string, unknown>;
		if (!o.names || typeof o.names !== 'object' || Array.isArray(o.names)) return false;
		if (
			!Object.values(o.names as Record<string, unknown>).every((pubkey) => isHexPubkey(pubkey))
		) {
			return false;
		}
		if (o.relays === undefined) return true;
		if (!o.relays || typeof o.relays !== 'object' || Array.isArray(o.relays)) return false;
		return Object.values(o.relays as Record<string, unknown>).every(
			(relays) => Array.isArray(relays) && relays.every((relay) => typeof relay === 'string')
		);
	}

	function isOricFileBody(v: unknown): v is string[] {
		if (!Array.isArray(v)) return false;
		return v.every((item) => typeof item === 'string');
	}

	function isFintagFileBody(v: unknown): v is FintagEntry[] {
		if (!Array.isArray(v)) return false;
		return v.every(
			(item) =>
				item !== null &&
				typeof item === 'object' &&
				!Array.isArray(item) &&
				Object.keys(item as object).length >= 1
		);
	}

	let loading = $state(true);
	let loadError = $state<string | null>(null);
	let doc = $state<KeysRegistryDoc | null>(null);
	let warnings = $state<string[]>([]);

	async function loadRegistry() {
		const w: string[] = [];
		const out: KeysRegistryDoc = {};

		const paths = [
			'/.well-known/jwks.json',
			'/.well-known/nostr.json',
			'/.well-known/oric.json',
			'/.well-known/fintag.json'
		] as const;

		const [signRes, nostrRes, oricRes, finRes] = await Promise.all(paths.map((p) => fetch(p)));

		if (signRes.ok) {
			try {
				const raw: unknown = await signRes.json();
				if (isSigningDoc(raw)) {
					out.signing = {
						keys: raw.keys,
						...(typeof (raw as Record<string, unknown>).issuer === 'string'
							? { issuer: raw.issuer }
							: {})
					};
				} else {
					w.push('jwks.json: expected an object with keys[] (each entry needs kid)');
				}
			} catch {
				w.push('jwks.json: invalid JSON');
			}
		}

		if (nostrRes.ok) {
			try {
				const raw: unknown = await nostrRes.json();
				if (isNostrDoc(raw)) {
					out.nostr = {
						names: raw.names,
						...(raw.relays ? { relays: raw.relays } : {})
					};
				} else {
					w.push(
						'nostr.json: expected an object with names{} mapped to 64-char hex pubkeys and optional relays{} arrays'
					);
				}
			} catch {
				w.push('nostr.json: invalid JSON');
			}
		}

		if (oricRes.ok) {
			try {
				const raw: unknown = await oricRes.json();
				if (isOricFileBody(raw)) {
					out.oric = raw;
				} else {
					w.push('oric.json: expected a JSON array of strings');
				}
			} catch {
				w.push('oric.json: invalid JSON');
			}
		}

		if (finRes.ok) {
			try {
				const raw: unknown = await finRes.json();
				if (isFintagFileBody(raw)) {
					out.fintag = raw;
				} else {
					w.push(
						'fintag.json: expected a JSON array of objects (each with at least one property)'
					);
				}
			} catch {
				w.push('fintag.json: invalid JSON');
			}
		}

		warnings = w;
		doc = out;
	}

	onMount(async () => {
		loading = true;
		loadError = null;
		warnings = [];
		doc = null;
		try {
			await loadRegistry();
		} catch {
			loadError = 'Failed to load registry files';
		} finally {
			loading = false;
		}
	});

	const hasAnySection = $derived(
		doc &&
			((doc.signing && doc.signing.keys.length > 0) ||
				(doc.nostr && Object.keys(doc.nostr.names).length > 0) ||
				(doc.oric && doc.oric.length > 0) ||
				(doc.fintag && doc.fintag.length > 0))
	);

	const hash = $derived($page.url.hash.slice(1) || '');
	const hashParsed = $derived.by(() => {
		const i = hash.indexOf('--');
		if (i <= 0) return { type: null as string | null, id: null as string | null };
		return {
			type: hash.slice(0, i),
			id: decodeURIComponent(hash.slice(i + 2)) || null
		};
	});

	const selectedSigningKey = $derived(
		doc?.signing && hashParsed.id && hashParsed.type === 'signing'
			? doc.signing.keys.find((k) => k.kid === hashParsed.id) ?? null
			: null
	);

	const selectedOricCode = $derived(
		doc?.oric && hashParsed.id && hashParsed.type === 'oric'
			? doc.oric.includes(hashParsed.id)
				? hashParsed.id
				: null
			: null
	);

	const selectedNostrName = $derived(
		doc?.nostr && hashParsed.id && hashParsed.type === 'nostr'
			? Object.prototype.hasOwnProperty.call(doc.nostr.names, hashParsed.id)
				? hashParsed.id
				: null
			: null
	);

	const selectedNostrPubkey = $derived(
		selectedNostrName && doc?.nostr ? doc.nostr.names[selectedNostrName] : null
	);

	const selectedNostrRelays = $derived(
		selectedNostrPubkey && doc?.nostr?.relays ? doc.nostr.relays[selectedNostrPubkey] ?? [] : []
	);

	const selectedFintagIndex = $derived(
		doc?.fintag && hashParsed.type === 'fintag' && hashParsed.id !== null
			? (() => {
					const n = Number.parseInt(hashParsed.id, 10);
					if (!Number.isInteger(n) || n < 0 || n >= doc.fintag.length) return null;
					return n;
				})()
			: null
	);

	const selectedFintagEntry = $derived(
		selectedFintagIndex !== null && doc?.fintag ? doc.fintag[selectedFintagIndex] : null
	);

	function keyJson(key: SigningKeyJwk) {
		return JSON.stringify(key, null, '\t');
	}

	function nostrEntryJson(name: string, pubkey: string) {
		return JSON.stringify(
			{
				names: {
					[name]: pubkey
				},
				...(selectedNostrRelays.length > 0
					? {
							relays: {
								[pubkey]: selectedNostrRelays
							}
						}
					: {})
			},
			null,
			'\t'
		);
	}

	function fintagEntryJson(entry: FintagEntry) {
		return JSON.stringify(entry, null, '\t');
	}

	function fintagRowLabel(entry: FintagEntry, index: number): string {
		const keys = Object.keys(entry);
		if (keys.length === 1) {
			const k = keys[0];
			const v = entry[k];
			const vs =
				typeof v === 'string'
					? v === ''
						? '""'
						: v.length > 48							? `${v.slice(0, 45)}…`
							: v
					: JSON.stringify(v);
			return `${k}: ${vs}`;
		}
		return `${index + 1}. ${keys.join(', ')}`;
	}

	function signingIssuer() {
		return doc?.signing?.issuer;
	}

	function downloadJson(filename: string, text: string) {
		const blob = new Blob([text], { type: 'application/json;charset=utf-8' });
		const a = document.createElement('a');
		a.href = URL.createObjectURL(blob);
		a.download = filename;
		a.click();
		URL.revokeObjectURL(a.href);
	}

	function goHash(fragment: string) {
		const path = $page.url.pathname + (fragment ? `#${fragment}` : '');
		goto(path, { replaceState: false, noScroll: true, keepFocus: true });
	}

	function selectSigningKid(kid: string) {
		goHash(`signing--${encodeURIComponent(kid)}`);
	}

	function selectOricCode(code: string) {
		goHash(`oric--${encodeURIComponent(code)}`);
	}

	function selectNostrName(name: string) {
		goHash(`nostr--${encodeURIComponent(name)}`);
	}

	function selectFintagIndex(index: number) {
		goHash(`fintag--${index}`);
	}

	function clearDetail() {
		goHash('');
	}

	function copyKeyJson(key: SigningKeyJwk) {
		copyToClipboard(
			keyJson(key),
			$LL.modules.keyRegistry.copiedToClipboard(),
			$LL.modules.keyRegistry.failedToCopy()
		);
	}

	function copyOricString(code: string) {
		copyToClipboard(
			code,
			$LL.modules.keyRegistry.copiedToClipboard(),
			$LL.modules.keyRegistry.failedToCopy()
		);
	}

	function copyNostrEntry(name: string, pubkey: string) {
		copyToClipboard(
			nostrEntryJson(name, pubkey),
			$LL.modules.keyRegistry.copiedToClipboard(),
			$LL.modules.keyRegistry.failedToCopy()
		);
	}

	function copyFintagFull() {
		if (!doc?.fintag) return;
		copyToClipboard(
			JSON.stringify(doc.fintag, null, '\t'),
			$LL.modules.keyRegistry.copiedToClipboard(),
			$LL.modules.keyRegistry.failedToCopy()
		);
	}

	function copyFintagEntry(entry: FintagEntry) {
		copyToClipboard(
			fintagEntryJson(entry),
			$LL.modules.keyRegistry.copiedToClipboard(),
			$LL.modules.keyRegistry.failedToCopy()
		);
	}

	const fintagPretty = $derived(doc?.fintag ? JSON.stringify(doc.fintag, null, '\t') : '');

	const fintagFormatExample = '[{"ican:xcb": ""}]';
</script>

<div class="max-w-4xl mx-auto p-6">
	<h1 class="text-xl md:text-3xl font-semibold mb-4">{$LL.modules.keyRegistry.keyRegistry()}</h1>
	<p class="mb-4">
		{$LL.modules.keyRegistry.welcome()}
	</p>

	{#if loading}
		<p class="text-gray-600 dark:text-gray-400">Loading…</p>
	{:else if loadError}
		<p class="text-red-600 dark:text-red-400" role="alert">{loadError}</p>
	{:else if doc !== null}
		{#if warnings.length > 0}
			<ul class="mb-6 list-disc list-inside text-amber-700 dark:text-amber-400 text-sm" role="status">
				{#each warnings as w}
					<li>{w}</li>
				{/each}
			</ul>
		{/if}

		{#if !hasAnySection}
			<p class="text-gray-600 dark:text-gray-400 mb-4">
				No registry content to show. Add optional files under
				<code class="text-xs">static/.well-known/</code>:
				<code class="text-xs">jwks.json</code>,
				<code class="text-xs">nostr.json</code>,
				<code class="text-xs">oric.json</code>,
				<code class="text-xs">fintag.json</code>
				— missing files are ignored; empty or invalid files may be skipped (see messages above).
			</p>
		{/if}

		{#if doc.signing && doc.signing.keys.length > 0}
			<section id="keys-signing" class="mb-10 scroll-mt-20">
				<h2 class="text-lg md:text-2xl font-semibold mb-3">
					{$LL.modules.keyRegistry.keyTypeRegistry({ key: 'Signing' })}
				</h2>
				{#if signingIssuer()}
					<p class="mb-3 text-gray-600 dark:text-gray-400 text-sm">
						<span class="font-medium text-gray-800 dark:text-gray-200">Issuer</span>
						{' '}{signingIssuer()}
					</p>
				{/if}
				<p class="mb-4 text-sm text-gray-600 dark:text-gray-400">
					{$LL.modules.keyRegistry.welcomeTypeRegistry({ key: 'JOSE / JWK' })}
				</p>
				<p class="mb-2 text-xs text-gray-500 dark:text-gray-500">
					Source: <code>/.well-known/jwks.json</code>
				</p>

				{#if selectedSigningKey}
					<h3 class="text-base md:text-xl font-semibold mb-2">
						{$LL.modules.keyRegistry.publicKeyFor({ keyName: selectedSigningKey.kid })}
					</h3>
					<div class="mb-3 text-gray-500 dark:text-gray-400 font-zephirum text-sm">
						{$LL.modules.keyRegistry.keyId({ keyId: selectedSigningKey.kid })}
					</div>
					<div class="mb-4 flex flex-col sm:flex-row sm:flex-wrap gap-2">
						<button
							type="button"
							onclick={() => copyKeyJson(selectedSigningKey)}
							class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							<Copy class="h-4 w-4 mr-2" />
							{$LL.modules.keyRegistry.copyKey()}
						</button>
						<button
							type="button"
							onclick={() =>
								downloadJson(`${selectedSigningKey.kid}.json`, keyJson(selectedSigningKey))}
							class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							<Download class="h-4 w-4 mr-2" />
							{$LL.modules.keyRegistry.downloadKey({ keyName: selectedSigningKey.kid })}
						</button>
						<button
							type="button"
							onclick={clearDetail}
							class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							{$LL.modules.keyRegistry.backToList()}
						</button>
					</div>
					<div class="w-fit max-w-full bg-gray-100 dark:bg-gray-800 p-4 rounded-lg">
						<pre class="text-sm overflow-auto font-zephirum whitespace-pre-wrap break-all">{keyJson(
							selectedSigningKey
						)}</pre>
					</div>
				{:else}
					<h3 class="text-base font-semibold mb-2">{$LL.modules.keyRegistry.keyTypeInfo()}</h3>
					<ul class="space-y-2 list-disc list-inside">
						{#each doc.signing.keys as keyItem}
							<li>
								<button
									type="button"
									onclick={() => selectSigningKid(keyItem.kid)}
									class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 hover:underline text-left font-mono text-sm"
								>
									{keyItem.kid}
								</button>
							</li>
						{/each}
					</ul>
				{/if}
			</section>
		{/if}

		{#if doc.nostr && Object.keys(doc.nostr.names).length > 0}
			<section id="keys-nostr" class="mb-10 scroll-mt-20">
				<h2 class="text-lg md:text-2xl font-semibold mb-3">
					{$LL.modules.keyRegistry.keyTypeRegistry({ key: 'Nostr' })}
				</h2>
				<p class="mb-4 text-sm text-gray-600 dark:text-gray-400">
					{$LL.modules.keyRegistry.welcomeTypeRegistry({ key: 'NIP-05' })}
				</p>
				<p class="mb-2 text-xs text-gray-500 dark:text-gray-500">
					Source: <code>/.well-known/nostr.json</code>
				</p>

				{#if selectedNostrName && selectedNostrPubkey}
					<h3 class="text-base md:text-xl font-semibold mb-2 font-mono break-all">
						{selectedNostrName}
					</h3>
					<div class="mb-2 text-gray-500 dark:text-gray-400 font-zephirum text-sm break-all">
						<span class="font-medium text-gray-800 dark:text-gray-200">Pubkey</span>
						{' '}{selectedNostrPubkey}
					</div>
					{#if selectedNostrRelays.length > 0}
						<div class="mb-3 text-gray-500 dark:text-gray-400 text-sm">
							<span class="font-medium text-gray-800 dark:text-gray-200">Relays</span>
							<ul class="mt-2 list-disc list-inside">
								{#each selectedNostrRelays as relay}
									<li class="font-mono break-all">{relay}</li>
								{/each}
							</ul>
						</div>
					{/if}
					<div class="mb-4 flex flex-col sm:flex-row sm:flex-wrap gap-2">
						<button
							type="button"
							onclick={() => copyNostrEntry(selectedNostrName, selectedNostrPubkey)}
							class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							<Copy class="h-4 w-4 mr-2" />
							{$LL.modules.keyRegistry.copyKey()}
						</button>
						<button
							type="button"
							onclick={() =>
								downloadJson(
									`${selectedNostrName.replace(/[^a-zA-Z0-9._-]/g, '_')}.json`,
									nostrEntryJson(selectedNostrName, selectedNostrPubkey)
								)}
							class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							<Download class="h-4 w-4 mr-2" />
							{$LL.modules.keyRegistry.downloadKey({ keyName: selectedNostrName })}
						</button>
						<button
							type="button"
							onclick={clearDetail}
							class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							{$LL.modules.keyRegistry.backToList()}
						</button>
					</div>
					<div class="w-fit max-w-full bg-gray-100 dark:bg-gray-800 p-4 rounded-lg">
						<pre class="text-sm overflow-auto font-zephirum whitespace-pre-wrap break-all">{nostrEntryJson(
							selectedNostrName,
							selectedNostrPubkey
						)}</pre>
					</div>
				{:else}
					<h3 class="text-base font-semibold mb-2">{$LL.modules.keyRegistry.keyTypeInfo()}</h3>
					<ul class="space-y-2 list-disc list-inside">
						{#each Object.entries(doc.nostr.names) as [name, pubkey]}
							<li>
								<button
									type="button"
									onclick={() => selectNostrName(name)}
									class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 hover:underline text-left font-mono text-sm break-all"
								>
									{name}@{$page.url.hostname}
									<span class="text-gray-500 dark:text-gray-400"> → {pubkey}</span>
								</button>
							</li>
						{/each}
					</ul>
				{/if}
			</section>
		{/if}

		{#if doc.oric && doc.oric.length > 0}
			<section id="keys-oric" class="mb-10 scroll-mt-20">
				<h2 class="text-lg md:text-2xl font-semibold mb-3">
					{$LL.modules.keyRegistry.keyTypeRegistry({ key: 'ORIC' })}
				</h2>
				<p class="mb-4 text-sm text-gray-600 dark:text-gray-400">
					{$LL.modules.keyRegistry.welcomeTypeRegistry({ key: 'ORIC' })}
				</p>
				<p class="mb-2 text-xs text-gray-500 dark:text-gray-500">
					Source: <code>/.well-known/oric.json</code>
				</p>

				{#if selectedOricCode !== null}
					<h3 class="text-base md:text-xl font-semibold mb-2 font-mono tracking-wide">
						{selectedOricCode}
					</h3>
					<div class="mb-4 flex flex-col sm:flex-row sm:flex-wrap gap-2">
						<button
							type="button"
							onclick={() => copyOricString(selectedOricCode)}
							class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							<Copy class="h-4 w-4 mr-2" />
							{$LL.modules.keyRegistry.copyKey()}
						</button>
						<button
							type="button"
							onclick={() =>
								downloadJson(
									`${selectedOricCode.replace(/[^a-zA-Z0-9._-]/g, '_')}.json`,
									JSON.stringify(selectedOricCode, null, '\t')
								)}
							class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							<Download class="h-4 w-4 mr-2" />
							{$LL.modules.keyRegistry.downloadKey({ keyName: selectedOricCode })}
						</button>
						<button
							type="button"
							onclick={clearDetail}
							class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							{$LL.modules.keyRegistry.backToList()}
						</button>
					</div>
					<div class="w-fit max-w-full bg-gray-100 dark:bg-gray-800 p-4 rounded-lg">
						<pre class="text-sm overflow-auto font-zephirum whitespace-pre-wrap break-all">{JSON.stringify(
							selectedOricCode,
							null,
							'\t'
						)}</pre>
					</div>
				{:else}
					<h3 class="text-base font-semibold mb-2">{$LL.modules.keyRegistry.keyTypeInfo()}</h3>
					<ul class="space-y-2 list-disc list-inside">
						{#each doc.oric as code}
							<li>
								<button
									type="button"
									onclick={() => selectOricCode(code)}
									class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 hover:underline text-left font-mono text-sm tracking-wide"
								>
									{code}
								</button>
							</li>
						{/each}
					</ul>
				{/if}
			</section>
		{/if}

		{#if doc.fintag && doc.fintag.length > 0}
			<section id="keys-fintag" class="mb-6 scroll-mt-20">
				<h2 class="text-lg md:text-2xl font-semibold mb-3">
					{$LL.modules.keyRegistry.keyTypeRegistry({ key: 'FinTag' })}
				</h2>
				<p class="mb-4 text-sm text-gray-600 dark:text-gray-400">
					{$LL.modules.keyRegistry.welcomeTypeRegistry({ key: 'FinTag' })}
				</p>
				<p class="mb-2 text-xs text-gray-500 dark:text-gray-500">
					Source: <code>/.well-known/fintag.json</code>
				</p>

				{#if selectedFintagEntry}
					<h3 class="text-base md:text-xl font-semibold mb-2 font-mono break-all">
						{fintagRowLabel(selectedFintagEntry, selectedFintagIndex ?? 0)}
					</h3>
					<div class="mb-4 flex flex-col sm:flex-row sm:flex-wrap gap-2">
						<button
							type="button"
							onclick={() => copyFintagEntry(selectedFintagEntry)}
							class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							<Copy class="h-4 w-4 mr-2" />
							{$LL.modules.keyRegistry.copyKey()}
						</button>
						<button
							type="button"
							onclick={() =>
								downloadJson(
									`fintag-${selectedFintagIndex}.json`,
									fintagEntryJson(selectedFintagEntry)
								)}
							class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							<Download class="h-4 w-4 mr-2" />
							{$LL.modules.keyRegistry.downloadKey({
								keyName: String(selectedFintagIndex)
							})}
						</button>
						<button
							type="button"
							onclick={clearDetail}
							class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							{$LL.modules.keyRegistry.backToList()}
						</button>
					</div>
					<div class="w-fit max-w-full bg-gray-100 dark:bg-gray-800 p-4 rounded-lg">
						<pre class="text-sm overflow-auto font-zephirum whitespace-pre-wrap break-all">{fintagEntryJson(
							selectedFintagEntry
						)}</pre>
					</div>
				{:else}
					<div class="mb-4 flex flex-wrap gap-2">
						<button
							type="button"
							onclick={copyFintagFull}
							class="inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							<Copy class="h-4 w-4 mr-2" />
							{$LL.modules.keyRegistry.copyKey()}
						</button>
					</div>
					<h3 class="text-base font-semibold mb-2">{$LL.modules.keyRegistry.keyTypeInfo()}</h3>
					<p class="mb-3 text-sm text-gray-600 dark:text-gray-400">
						Array loaded from <code class="text-xs">fintag.json</code>. Example:
						<code class="text-xs">{fintagFormatExample}</code>
						URL hash: <code class="text-xs">fintag--0</code>, <code class="text-xs">fintag--1</code>, …
					</p>
					<ul class="space-y-2 list-disc list-inside">
						{#each doc.fintag as entry, i}
							<li>
								<button
									type="button"
									onclick={() => selectFintagIndex(i)}
									class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 hover:underline text-left font-mono text-sm break-all"
								>
									{fintagRowLabel(entry, i)}
								</button>
							</li>
						{/each}
					</ul>
					<div class="mt-6 w-fit max-w-full bg-gray-100 dark:bg-gray-800 p-4 rounded-lg">
						<pre class="text-sm overflow-auto font-zephirum whitespace-pre-wrap break-all">{fintagPretty}</pre>
					</div>
				{/if}
			</section>
		{/if}
	{/if}
</div>
