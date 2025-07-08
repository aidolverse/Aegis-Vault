<script lang="ts">
  import { run } from 'svelte/legacy';

  import { authService, isAuthenticated } from '$lib/services/AuthService'
  import { goto } from '$app/navigation'

  async function handleLogin() {
    try {
      await authService.login()
      if ($isAuthenticated) {
        goto('/dashboard')
      }
    } catch (error) {
      console.error('Login failed:', error)
    }
  }

  run(() => {
    if ($isAuthenticated) {
      goto('/dashboard')
    }
  });
</script>

<svelte:head>
  <title>Aegis Vault - Secure Decentralized Data Analysis</title>
</svelte:head>

<div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
  <!-- Header -->
  <header class="bg-white shadow-sm">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between items-center py-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <h1 class="text-2xl font-bold text-gray-900">🛡️ Aegis Vault</h1>
          </div>
        </div>
        <nav class="hidden md:flex space-x-8">
          <a href="#features" class="text-gray-500 hover:text-gray-900">Features</a>
          <a href="#how-it-works" class="text-gray-500 hover:text-gray-900">How It Works</a>
          <a href="#security" class="text-gray-500 hover:text-gray-900">Security</a>
        </nav>
      </div>
    </div>
  </header>

  <!-- Hero Section -->
  <section class="relative py-20">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="text-center">
        <h1 class="text-4xl tracking-tight font-extrabold text-gray-900 sm:text-5xl md:text-6xl">
          <span class="block">Secure Data Analysis</span>
          <span class="block text-blue-600">Without Compromising Privacy</span>
        </h1>
        <p class="mt-3 max-w-md mx-auto text-base text-gray-500 sm:text-lg md:mt-5 md:text-xl md:max-w-3xl">
          Aegis Vault enables researchers to analyze aggregated data while keeping individual data encrypted and private in personal vaults on the Internet Computer.
        </p>
        <div class="mt-5 max-w-md mx-auto sm:flex sm:justify-center md:mt-8">
          <div class="rounded-md shadow">
            <button
              onclick={handleLogin}
              class="w-full flex items-center justify-center px-8 py-3 border border-transparent text-base font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 md:py-4 md:text-lg md:px-10"
            >
              Login with Internet Identity
            </button>
          </div>
        </div>
      </div>
    </div>
  </section>

  <!-- Features Section -->
  <section id="features" class="py-16 bg-white">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="text-center">
        <h2 class="text-3xl font-extrabold text-gray-900">Key Features</h2>
        <p class="mt-4 text-lg text-gray-500">
          Built on the Internet Computer for maximum security and decentralization
        </p>
      </div>

      <div class="mt-16">
        <div class="grid grid-cols-1 gap-8 md:grid-cols-3">
          <div class="text-center">
            <div class="flex items-center justify-center h-12 w-12 rounded-md bg-blue-500 text-white mx-auto">
              🔒
            </div>
            <h3 class="mt-6 text-lg font-medium text-gray-900">End-to-End Encryption</h3>
            <p class="mt-2 text-base text-gray-500">
              Your data is encrypted on your device and never leaves your personal vault unencrypted.
            </p>
          </div>

          <div class="text-center">
            <div class="flex items-center justify-center h-12 w-12 rounded-md bg-blue-500 text-white mx-auto">
              🏛️
            </div>
            <h3 class="mt-6 text-lg font-medium text-gray-900">Decentralized Storage</h3>
            <p class="mt-2 text-base text-gray-500">
              Each user has their own canister vault on the Internet Computer blockchain.
            </p>
          </div>

          <div class="text-center">
            <div class="flex items-center justify-center h-12 w-12 rounded-md bg-blue-500 text-white mx-auto">
              📊
            </div>
            <h3 class="mt-6 text-lg font-medium text-gray-900">Privacy-Preserving Analytics</h3>
            <p class="mt-2 text-base text-gray-500">
              Researchers get insights without ever seeing individual user data.
            </p>
          </div>
        </div>
      </div>
    </div>
  </section>

  <!-- How It Works Section -->
  <section id="how-it-works" class="py-16 bg-gray-50">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="text-center">
        <h2 class="text-3xl font-extrabold text-gray-900">How It Works</h2>
        <p class="mt-4 text-lg text-gray-500">
          A simple 4-step process that ensures your privacy
        </p>
      </div>

      <div class="mt-16">
        <div class="grid grid-cols-1 gap-8 md:grid-cols-2 lg:grid-cols-4">
          <div class="text-center">
            <div class="flex items-center justify-center h-16 w-16 rounded-full bg-blue-100 text-blue-600 mx-auto text-2xl font-bold">
              1
            </div>
            <h3 class="mt-4 text-lg font-medium text-gray-900">Upload Data</h3>
            <p class="mt-2 text-sm text-gray-500">
              Upload your CSV data which gets encrypted and stored in your personal vault
            </p>
          </div>

          <div class="text-center">
            <div class="flex items-center justify-center h-16 w-16 rounded-full bg-blue-100 text-blue-600 mx-auto text-2xl font-bold">
              2
            </div>
            <h3 class="mt-4 text-lg font-medium text-gray-900">Receive Query</h3>
            <p class="mt-2 text-sm text-gray-500">
              Researchers submit analysis queries that you can approve or reject
            </p>
          </div>

          <div class="text-center">
            <div class="flex items-center justify-center h-16 w-16 rounded-full bg-blue-100 text-blue-600 mx-auto text-2xl font-bold">
              3
            </div>
            <h3 class="mt-4 text-lg font-medium text-gray-900">Private Analysis</h3>
            <p class="mt-2 text-sm text-gray-500">
              Your vault processes the query locally and returns only anonymous results
            </p>
          </div>

          <div class="text-center">
            <div class="flex items-center justify-center h-16 w-16 rounded-full bg-blue-100 text-blue-600 mx-auto text-2xl font-bold">
              4
            </div>
            <h3 class="mt-4 text-lg font-medium text-gray-900">Aggregated Insights</h3>
            <p class="mt-2 text-sm text-gray-500">
              Researchers receive statistical insights without accessing raw data
            </p>
          </div>
        </div>
      </div>
    </div>
  </section>

  <!-- Security Section -->
  <section id="security" class="py-16 bg-white">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="text-center">
        <h2 class="text-3xl font-extrabold text-gray-900">Security First</h2>
        <p class="mt-4 text-lg text-gray-500">
          Built with the highest security standards
        </p>
      </div>

      <div class="mt-16 grid grid-cols-1 gap-8 md:grid-cols-2">
        <div>
          <h3 class="text-xl font-semibold text-gray-900 mb-4">🔐 Cryptographic Security</h3>
          <ul class="space-y-2 text-gray-600">
            <li>• AES-256 encryption for all data</li>
            <li>• PBKDF2 key derivation</li>
            <li>• SHA-256 integrity verification</li>
            <li>• Client-side encryption only</li>
          </ul>
        </div>

        <div>
          <h3 class="text-xl font-semibold text-gray-900 mb-4">🌐 Blockchain Benefits</h3>
          <ul class="space-y-2 text-gray-600">
            <li>• Immutable audit logs</li>
            <li>• Decentralized infrastructure</li>
            <li>• No single point of failure</li>
            <li>• Transparent smart contracts</li>
          </ul>
        </div>
      </div>
    </div>
  </section>

  <!-- Footer -->
  <footer class="bg-gray-800">
    <div class="max-w-7xl mx-auto py-12 px-4 sm:px-6 lg:px-8">
      <div class="text-center">
        <h3 class="text-white text-lg font-semibold">🛡️ Aegis Vault</h3>
        <p class="mt-2 text-gray-400">
          Secure, private, decentralized data analysis on the Internet Computer
        </p>
        <div class="mt-4 text-gray-500 text-sm">
          Built with Internet Computer Protocol • Powered by Motoko Smart Contracts
        </div>
      </div>
    </div>
  </footer>
</div>
