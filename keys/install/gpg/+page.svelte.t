---
to: src/routes/[[lang]]/keys/gpg/+page.svelte
---
<script lang="ts">
	import { Copy, Download, ArrowUpRight, ArrowLeft } from 'lucide-svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { copyToClipboard, downloadGPGKey } from '$lib/helpers/keys';
	import { LL } from '$lang/i18n-svelte';
	import { keys } from './keys.data';

	const hash = $derived($page.url.hash.slice(1) || '');
	const selectedKeyName = $derived(decodeURIComponent(hash).toLowerCase() || null);
	const selectedKey = $derived(keys.find((k) => k.name.toLowerCase() === selectedKeyName) ?? null);

	/** ID = last 8 characters of fingerprint, uppercased. */
	const keyId = $derived(selectedKey?.fingerprint ? selectedKey.fingerprint.slice(-8).toUpperCase() : '');

	/** View-on-server link only when keyServer is defined; keyServer gets trailing / if missing, then fingerprint. */
	const keyServerLink = $derived(
		selectedKey?.keyServer && selectedKey?.fingerprint
			? (selectedKey.keyServer.endsWith('/') ? selectedKey.keyServer : selectedKey.keyServer + '/') +
				selectedKey.fingerprint
			: null
	);

	/** Base name for download; helper appends .asc → keyName (ID).asc */
	function downloadFilename(keyName: string, id: string) {
		return id ? `${keyName} (${id}) - Public` : keyName + ' - Public';
	}

	function selectKey(name: string) {
		goto(`${$page.url.pathname}#${encodeURIComponent(name.toLowerCase())}`, { replaceState: false });
	}

	function backToList() {
		goto($page.url.pathname, { replaceState: false });
	}

	function copyKey(keyBlock: string) {
		copyToClipboard(
			keyBlock,
			$LL.modules.keyRegistry.copiedToClipboard(),
			$LL.modules.keyRegistry.failedToCopy()
		);
	}

	function downloadKey(keyBlock: string, keyName: string, id: string) {
		downloadGPGKey(keyBlock, downloadFilename(keyName, id));
	}
</script>

<div class="max-w-4xl mx-auto p-6">
	<h1 class="text-xl md:text-3xl font-semibold mb-4">{$LL.modules.keyRegistry.keyTypeRegistry({key: 'GPG'})}</h1>
	<p class="mb-6">
		{$LL.modules.keyRegistry.welcomeTypeRegistry({key: 'GPG'})}
	</p>

	{#if selectedKey}
		<!-- Detail view: one key -->
		<h2 class="text-xl md:text-2xl font-semibold mb-2">{$LL.modules.keyRegistry.publicKeyFor({keyName: selectedKey.name})}</h2>

		{#if keyId}
			<div class="mb-4 text-gray-500 dark:text-gray-400 font-zephirum">
				{$LL.modules.keyRegistry.keyId({keyId})}
			</div>
		{/if}

		<div class="mb-6 flex flex-col sm:flex-row sm:flex-wrap gap-2">
			<button
				type="button"
				onclick={() => copyKey(selectedKey.key)}
				class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
			>
				<Copy class="h-4 w-4 mr-2" />
				{$LL.modules.keyRegistry.copyKey()}
			</button>

			<button
				type="button"
				onclick={() => downloadKey(selectedKey.key, selectedKey.name, keyId)}
				class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
			>
				<Download class="h-4 w-4 mr-2" />
				{$LL.modules.keyRegistry.downloadKey({keyName: selectedKey.name})}
			</button>

			{#if keyServerLink}
				<a
					href={keyServerLink}
					target="_blank"
					rel="noopener noreferrer"
					class="w-full sm:w-auto inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700! dark:text-gray-300! bg-white dark:bg-gray-800 no-underline! hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
				>
					{$LL.modules.keyRegistry.viewOnKeyServer()}
					<ArrowUpRight class="h-4 w-4 ml-1" />
				</a>
			{/if}
		</div>

		<div class="w-fit max-w-full bg-gray-100 dark:bg-gray-800 p-4 rounded-lg">
			<pre class="text-sm overflow-auto font-zephirum whitespace-pre-wrap break-all">{selectedKey.key}</pre>
		</div>
	{:else}
		<!-- List view: select key by name (lowercase) -->
		<h2 class="text-lg font-semibold mb-2">{$LL.modules.keyRegistry.keyTypeInfo()}</h2>
		<ul class="space-y-2 list-disc list-inside">
			{#each keys as keyItem}
				<li>
					<button
						type="button"
						onclick={() => selectKey(keyItem.name)}
						class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 hover:underline text-left"
					>
						{keyItem.name.toLowerCase()}
					</button>
				</li>
			{/each}
		</ul>
	{/if}
</div>
