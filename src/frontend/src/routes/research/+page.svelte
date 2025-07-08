<script lang="ts">
  import { onMount } from 'svelte'
  import { goto } from '$app/navigation'
  import { authService, isAuthenticated } from '$lib/services/AuthService'
  import { actorService } from '$lib/services/ActorService'

  let selectedQuery = $state(1)
  let isSubmitting = $state(false)
  let queryResult: { trueCount: number; falseCount: number } | null = $state(null)
  let submitError = $state('')

  const availableQueries = [
    {
      id: 1,
      name: 'Food Spending Analysis',
      description: 'Analyze percentage of users with food spending > $50',
      category: 'Spending Patterns'
    },
    {
      id: 2,
      name: 'Entertainment Budget',
      description: 'Users spending more than $100 on entertainment monthly',
      category: 'Lifestyle Analysis'
    },
    {
      id: 3,
      name: 'Transportation Costs',
      description: 'Average transportation spending above $200',
      category: 'Mobility Patterns'
    }
  ]

  onMount(async () => {
    if (!$isAuthenticated) {
      goto('/')
      return
    }
  })

  async function handleSubmitQuery() {
    isSubmitting = true
    submitError = ''
    queryResult = null

    try {
      const aggregatorActor = await actorService.createAggregatorActor()
      const submitResult = await aggregatorActor.submitQuery(selectedQuery)
      
      if (submitResult.ok) {
        // Wait a moment for processing
        setTimeout(async () => {
          try {
            const results = await aggregatorActor.getQueryResults(submitResult.ok)
            if (results.ok) {
              queryResult = {
                trueCount: Number(results.ok.trueCount),
                falseCount: Number(results.ok.falseCount)
              }
            }
          } catch (error) {
            console.error('Failed to get results:', error)
          }
        }, 2000)
      } else {
        submitError = 'Failed to submit query: ' + submitResult.err
      }
    } catch (error) {
      submitError = 'Failed to submit query: ' + error
    } finally {
      isSubmitting = false
    }
  }

  async function handleLogout() {
    await authService.logout()
    goto('/')
  }

  let selectedQueryInfo = $derived(availableQueries.find(q => q.id === selectedQuery))
  let totalResponses = $derived(queryResult ? queryResult.trueCount + queryResult.falseCount : 0)
  let percentage = $derived(totalResponses > 0 ? Math.round((queryResult!.trueCount / totalResponses) * 100) : 0)
</script>

<svelte:head>
  <title>Research Portal - Aegis Vault</title>
</svelte:head>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <header class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between items-center py-6">
        <div class="flex items-center">
          <h1 class="text-2xl font-bold text-gray-900">🔬 Research Portal</h1>
        </div>
        <div class="flex items-center space-x-4">
          <a href="/dashboard" class="text-blue-600 hover:text-blue-800 text-sm font-medium">
            Dashboard
          </a>
          <button
            onclick={handleLogout}
            class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium"
          >
            Logout
          </button>
        </div>
      </div>
    </div>
  </header>

  <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
    <div class="px-4 py-6 sm:px-0">
      
      <!-- Introduction -->
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-8">
        <h2 class="text-lg font-semibold text-blue-900 mb-2">
          Privacy-Preserving Data Analysis
        </h2>
        <p class="text-blue-800">
          Submit analysis queries to get insights from aggregated user data without accessing individual records. 
          All data remains encrypted in users' personal vaults.
        </p>
      </div>

      <div class="grid grid-cols-1 gap-8 lg:grid-cols-2">
        
        <!-- Query Selection -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Select Analysis Query</h3>
          </div>
          <div class="p-6">
            <div class="space-y-4">
              <div>
                <label for="query-select" class="block text-sm font-medium text-gray-700 mb-2">
                  Available Queries
                </label>
                <select
                  id="query-select"
                  bind:value={selectedQuery}
                  disabled={isSubmitting}
                  class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                >
                  {#each availableQueries as query}
                    <option value={query.id}>{query.name}</option>
                  {/each}
                </select>
              </div>

              {#if selectedQueryInfo}
                <div class="bg-gray-50 rounded-md p-4">
                  <h4 class="font-medium text-gray-900 mb-2">{selectedQueryInfo.name}</h4>
                  <p class="text-sm text-gray-600 mb-2">{selectedQueryInfo.description}</p>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    {selectedQueryInfo.category}
                  </span>
                </div>
              {/if}

              <button
                onclick={handleSubmitQuery}
                disabled={isSubmitting}
                class="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white font-medium py-2 px-4 rounded-md transition-colors"
              >
                {#if isSubmitting}
                  <div class="flex items-center justify-center">
                    <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                    Submitting Query...
                  </div>
                {:else}
                  Submit Query
                {/if}
              </button>

              {#if submitError}
                <div class="bg-red-50 border border-red-200 rounded-md p-4">
                  <p class="text-sm text-red-800">{submitError}</p>
                </div>
              {/if}
            </div>
          </div>
        </div>

        <!-- Results Display -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Analysis Results</h3>
          </div>
          <div class="p-6">
            {#if queryResult}
              <div class="space-y-6">
                <!-- Summary Stats -->
                <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                  <h4 class="font-medium text-green-900 mb-3">Query Results</h4>
                  <div class="grid grid-cols-2 gap-4">
                    <div class="text-center">
                      <div class="text-2xl font-bold text-green-600">{percentage}%</div>
                      <div class="text-sm text-green-700">Match Criteria</div>
                    </div>
                    <div class="text-center">
                      <div class="text-2xl font-bold text-gray-600">{totalResponses}</div>
                      <div class="text-sm text-gray-700">Total Responses</div>
                    </div>
                  </div>
                </div>

                <!-- Detailed Breakdown -->
                <div class="space-y-3">
                  <h4 class="font-medium text-gray-900">Response Breakdown</h4>
                  <div class="space-y-2">
                    <div class="flex justify-between items-center p-3 bg-gray-50 rounded">
                      <span class="text-sm font-medium text-gray-700">Positive Matches</span>
                      <span class="text-sm font-bold text-green-600">{queryResult.trueCount}</span>
                    </div>
                    <div class="flex justify-between items-center p-3 bg-gray-50 rounded">
                      <span class="text-sm font-medium text-gray-700">Negative Matches</span>
                      <span class="text-sm font-bold text-red-600">{queryResult.falseCount}</span>
                    </div>
                  </div>
                </div>

                <!-- Visual Progress Bar -->
                <div class="space-y-2">
                  <div class="flex justify-between text-sm text-gray-600">
                    <span>Distribution</span>
                    <span>{percentage}% / {100 - percentage}%</span>
                  </div>
                  <div class="w-full bg-gray-200 rounded-full h-3">
                    <div 
                      class="bg-green-500 h-3 rounded-full transition-all duration-500"
                      style="width: {percentage}%"
                    ></div>
                  </div>
                </div>
              </div>
            {:else}
              <div class="text-center py-12">
                <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                  <path d="M9 17a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0116.07 12h15.86a2 2 0 011.664.89l.812 1.22A2 2 0 0036.07 15H37a2 2 0 012 2v18a2 2 0 01-2 2H11a2 2 0 01-2-2V17zM15 26a9 9 0 1118 0 9 9 0 01-18 0z" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
                <h3 class="mt-2 text-sm font-medium text-gray-900">No Results Yet</h3>
                <p class="mt-1 text-sm text-gray-500">
                  Submit a query to see aggregated analysis results from user vaults.
                </p>
              </div>
            {/if}
          </div>
        </div>
      </div>

      <!-- How It Works -->
      <div class="mt-8 bg-white shadow rounded-lg">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-medium text-gray-900">How Privacy-Preserving Analysis Works</h3>
        </div>
        <div class="p-6">
          <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
            <div class="text-center">
              <div class="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-3">
                <span class="text-blue-600 font-bold">1</span>
              </div>
              <h4 class="font-medium text-gray-900 mb-2">Query Submission</h4>
              <p class="text-sm text-gray-600">Researcher submits analysis query to the aggregator</p>
            </div>
            <div class="text-center">
              <div class="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-3">
                <span class="text-blue-600 font-bold">2</span>
              </div>
              <h4 class="font-medium text-gray-900 mb-2">User Approval</h4>
              <p class="text-sm text-gray-600">Users receive and approve/reject the analysis request</p>
            </div>
            <div class="text-center">
              <div class="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-3">
                <span class="text-blue-600 font-bold">3</span>
              </div>
              <h4 class="font-medium text-gray-900 mb-2">Private Processing</h4>
              <p class="text-sm text-gray-600">Each vault processes query locally on encrypted data</p>
            </div>
            <div class="text-center">
              <div class="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-3">
                <span class="text-blue-600 font-bold">4</span>
              </div>
              <h4 class="font-medium text-gray-900 mb-2">Aggregated Results</h4>
              <p class="text-sm text-gray-600">Only anonymous boolean results are returned and aggregated</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </main>
</div>
