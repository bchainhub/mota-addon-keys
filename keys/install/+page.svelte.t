---
to: src/routes/[[lang]]/keys/+page.svelte
---
<script lang="ts">
	import { LL } from '$lang/i18n-svelte';
	const keys = ['gpg', 'oric'];
</script>

<div class="max-w-4xl mx-auto p-6">
	<h1 class="text-xl md:text-3xl font-semibold mb-4">{$LL.modules.keyRegistry.keyRegistry()}</h1>
	<p class="mb-4">
		{$LL.modules.keyRegistry.welcome()}
	</p>

	<h2 class="text-lg font-semibold mb-2">{$LL.modules.keyRegistry.keyTypes()}</h2>
	<ul class="space-y-2 list-disc list-inside">
		{#each keys as type}
			<li>
				<a href="/keys/{type}" class="text-blue-600 hover:text-blue-800 hover:underline">
					{type.toUpperCase()}
				</a>
			</li>
		{/each}
	</ul>
</div>
