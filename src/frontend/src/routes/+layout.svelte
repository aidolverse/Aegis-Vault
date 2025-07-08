<script lang="ts">
  import '../app.css'
  import { onMount } from 'svelte'
  import { authService, isAuthenticated, authLoading, authError } from '$lib/services/AuthService'
  import { actorService } from '$lib/services/ActorService'
  interface Props {
    children?: import('svelte').Snippet;
  }

  let { children }: Props = $props();

  onMount(async () => {
    try {
      await authService.init()
      await actorService.init()
    } catch (error) {
      console.error('Failed to initialize services:', error)
    }
  })
</script>

<main class="min-h-screen bg-gray-50">
  {#if $authLoading}
    <div class="flex items-center justify-center min-h-screen">
      <div class="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
    </div>
  {:else if $authError}
    <div class="flex items-center justify-center min-h-screen">
      <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
        Error: {$authError}
      </div>
    </div>
  {:else}
    {@render children?.()}
  {/if}
</main>
