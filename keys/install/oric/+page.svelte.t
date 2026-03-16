---
to: src/routes/[[lang]]/keys/oric/+page.svelte
---
<script lang="ts">
	import { keys } from './keys.data';

	import { page } from '$app/stores';
	import { LL } from '$lang/i18n-svelte';
	// Get the last part of the URL path (after the last /)
	$: lastPathSegment = $page.url.pathname.split('/').filter(Boolean).pop() || '';
</script>

<div class="max-w-4xl mx-auto p-6">
	<h1 class="text-xl md:text-3xl font-semibold mb-4">{$LL.modules.keyRegistry.keyTypeRegistry({key: (lastPathSegment && lastPathSegment.toUpperCase())})}</h1>
	<p class="mb-4">
		{$LL.modules.keyRegistry.welcomeTypeRegistry({key: (lastPathSegment && lastPathSegment.toUpperCase())})}
	</p>

	<h2 class="text-lg font-semibold mb-2">{$LL.modules.keyRegistry.keyTypeInfo()}</h2>
	<ul class="space-y-2 list-disc list-inside">
		{#each keys as key}
			<li>
				<a href="https://core.exposed/obp/v6.0.0/banks/{key.toLowerCase()}/certificate" target="_blank" class="text-blue-600 hover:text-blue-800 hover:underline">
					{key.toUpperCase()}
				</a>
			</li>
		{/each}
	</ul>
</div>
