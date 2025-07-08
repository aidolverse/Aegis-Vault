<script lang="ts">
  import { onMount } from 'svelte'
  import { goto } from '$app/navigation'
  import { authService, isAuthenticated, principal } from '$lib/services/AuthService'
  import { cryptoService } from '$lib/services/CryptoService'
  import { actorService } from '$lib/services/ActorService'

  let hasData = $state(false)
  let isUploading = $state(false)
  let uploadError = $state('')
  let uploadSuccess = $state(false)
  let pendingQuery = $state('')
  let fileInput: HTMLInputElement = $state()

  onMount(async () => {
    if (!$isAuthenticated) {
      goto('/')
      return
    }

    try {
      // Check if user has data
      const userVaultActor = await actorService.createUserVaultActor()
      hasData = await userVaultActor.hasData()
      
      // Check for pending queries
      const pendingQueries = await userVaultActor.getPendingQueries()
      if (pendingQueries.ok && pendingQueries.ok.length > 0) {
        pendingQuery = pendingQueries.ok[0].description
      }
    } catch (error) {
      console.error('Failed to load dashboard data:', error)
    }
  })

  async function handleFileUpload(event: Event) {
    const target = event.target as HTMLInputElement
    const file = target.files?.[0]
    
    if (!file) return

    if (!file.name.endsWith('.csv')) {
      uploadError = 'Please select a CSV file'
      return
    }

    isUploading = true
    uploadError = ''
    uploadSuccess = false

    try {
      // Encrypt the file
      const encryptionResult = await cryptoService.encryptFile(file, $principal!)
      
      // Upload to user vault
      const userVaultActor = await actorService.createUserVaultActor()
      const uploadResult = await userVaultActor.uploadData(
        Array.from(encryptionResult.encryptedData),
        encryptionResult.checksum
      )

      if (uploadResult.ok) {
        uploadSuccess = true
        hasData = true
        // Clear the file input
        if (fileInput) fileInput.value = ''
      } else {
        uploadError = 'Upload failed: ' + uploadResult.err
      }
    } catch (error) {
      uploadError = 'Upload failed: ' + error
    } finally {
      isUploading = false
    }
  }

  async function handleApproveQuery() {
    try {
      const userVaultActor = await actorService.createUserVaultActor()
      const result = await userVaultActor.approveRequest(1) // Assuming query ID 1
      
      if (result.ok) {
        pendingQuery = ''
        alert('Query approved successfully!')
      } else {
        alert('Failed to approve query: ' + result.err)
      }
    } catch (error) {
      alert('Failed to approve query: ' + error)
    }
  }

  async function handleRejectQuery() {
    try {
      const userVaultActor = await actorService.createUserVaultActor()
      const result = await userVaultActor.rejectRequest(1) // Assuming query ID 1
      
      if (result.ok) {
        pendingQuery = ''
        alert('Query rejected successfully!')
      } else {
        alert('Failed to reject query: ' + result.err)
      }
    } catch (error) {
      alert('Failed to reject query: ' + error)
    }
  }

  async function handleLogout() {
    await authService.logout()
    goto('/')
  }
</script>

<svelte:head>
  <title>Dashboard - Aegis Vault</title>
</svelte:head>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <header class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between items-center py-6">
        <div class="flex items-center">
          <h1 class="text-2xl font-bold text-gray-900">🛡️ Aegis Vault Dashboard</h1>
        </div>
        <div class="flex items-center space-x-4">
          <span class="text-sm text-gray-500">
            {$principal?.toString().slice(0, 8)}...
          </span>
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
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        
        <!-- Data Upload Section -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
              📁 Data Upload
            </h3>
            
            {#if hasData}
              <div class="bg-green-50 border border-green-200 rounded-md p-4 mb-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm font-medium text-green-800">
                      Data uploaded successfully!
                    </p>
                    <p class="text-sm text-green-700">
                      Your data is encrypted and stored in your personal vault.
                    </p>
                  </div>
                </div>
              </div>
            {:else}
              <p class="text-sm text-gray-600 mb-4">
                Upload your CSV file containing spending data (Date, Category, Amount).
              </p>
            {/if}

            <div class="mt-4">
              <label for="file-upload" class="block text-sm font-medium text-gray-700">
                Select CSV File
              </label>
              <div class="mt-1">
                <input
                  bind:this={fileInput}
                  id="file-upload"
                  name="file-upload"
                  type="file"
                  accept=".csv"
                  onchange={handleFileUpload}
                  disabled={isUploading}
                  class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
                />
              </div>
            </div>

            {#if isUploading}
              <div class="mt-4 flex items-center">
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
                <span class="ml-2 text-sm text-gray-600">Encrypting and uploading...</span>
              </div>
            {/if}

            {#if uploadError}
              <div class="mt-4 bg-red-50 border border-red-200 rounded-md p-4">
                <p class="text-sm text-red-800">{uploadError}</p>
              </div>
            {/if}

            {#if uploadSuccess}
              <div class="mt-4 bg-green-50 border border-green-200 rounded-md p-4">
                <p class="text-sm text-green-800">File uploaded successfully!</p>
              </div>
            {/if}
          </div>
        </div>

        <!-- Query Approval Section -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
              🔍 Query Requests
            </h3>
            
            {#if pendingQuery}
              <div class="bg-yellow-50 border border-yellow-200 rounded-md p-4 mb-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm font-medium text-yellow-800">
                      New Query Request
                    </p>
                    <p class="text-sm text-yellow-700 mt-1">
                      {pendingQuery}
                    </p>
                  </div>
                </div>
              </div>

              <div class="flex space-x-3">
                <button
                  onclick={handleApproveQuery}
                  class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                >
                  ✅ Approve
                </button>
                <button
                  onclick={handleRejectQuery}
                  class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                >
                  ❌ Reject
                </button>
              </div>
            {:else}
              <div class="text-center py-8">
                <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                  <path d="M34 40h10v-4a6 6 0 00-10.712-3.714M34 40H14m20 0v-4a9.971 9.971 0 00-.712-3.714M14 40H4v-4a6 6 0 0110.713-3.714M14 40v-4c0-1.313.253-2.566.713-3.714m0 0A10.003 10.003 0 0124 26c4.21 0 7.813 2.602 9.288 6.286M30 14a6 6 0 11-12 0 6 6 0 0112 0zm12 6a4 4 0 11-8 0 4 4 0 018 0zm-28 0a4 4 0 11-8 0 4 4 0 018 0z" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
                <h3 class="mt-2 text-sm font-medium text-gray-900">No pending queries</h3>
                <p class="mt-1 text-sm text-gray-500">
                  When researchers submit analysis requests, they will appear here for your approval.
                </p>
              </div>
            {/if}
          </div>
        </div>

        <!-- Vault Status Section -->
        <div class="bg-white overflow-hidden shadow rounded-lg lg:col-span-2">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
              🏛️ Vault Status
            </h3>
            
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <div class="bg-blue-50 rounded-lg p-4">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
                      <span class="text-white text-sm font-bold">🔒</span>
                    </div>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm font-medium text-blue-900">Encryption</p>
                    <p class="text-sm text-blue-700">AES-256 Active</p>
                  </div>
                </div>
              </div>

              <div class="bg-green-50 rounded-lg p-4">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
                      <span class="text-white text-sm font-bold">🏛️</span>
                    </div>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm font-medium text-green-900">Vault</p>
                    <p class="text-sm text-green-700">{hasData ? 'Data Stored' : 'Empty'}</p>
                  </div>
                </div>
              </div>

              <div class="bg-purple-50 rounded-lg p-4">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <div class="w-8 h-8 bg-purple-500 rounded-full flex items-center justify-center">
                      <span class="text-white text-sm font-bold">🌐</span>
                    </div>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm font-medium text-purple-900">Network</p>
                    <p class="text-sm text-purple-700">ICP Connected</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </main>
</div>
