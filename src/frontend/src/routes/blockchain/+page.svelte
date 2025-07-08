<script lang="ts">
    import { onMount } from 'svelte';
    import { goto } from '$app/navigation';
    import { authService, isAuthenticated, principal } from '../../lib/services/AuthService';
    import { blockchainService } from '../../lib/services/BlockchainService';

    let tokenBalance: any = $state(null);
    let transactions: any[] = $state([]);
    let proposals: any[] = $state([]);
    let blockchainStats: any = $state(null);
    let loading = $state(false);
    let error = $state(null);

    // Transfer form
    let transferTo = $state('');
    let transferAmount = $state('');
    let transferring = $state(false);

    // Proposal form
    let proposalTitle = $state('');
    let proposalDescription = $state('');
    let proposalType = $state('ParameterChange');
    let submittingProposal = $state(false);

    onMount(() => {
        const unsubscribe = isAuthenticated.subscribe(async (value) => {
            if (!value) {
                goto('/');
            } else {
                await loadBlockchainData();
            }
        });

        return unsubscribe;
    });

    async function loadBlockchainData() {
        loading = true;
        error = null;

        try {
            await blockchainService.init();
            
            if (principal) {
                tokenBalance = await blockchainService.getTokenBalance(principal);
                transactions = await blockchainService.getTransactionHistory(0, 10);
            }
            
            proposals = await blockchainService.getAllProposals();
            blockchainStats = await blockchainService.getBlockchainStats();
        } catch (err) {
            console.error('Failed to load blockchain data:', err);
            error = 'Failed to load blockchain data';
        } finally {
            loading = false;
        }
    }

    async function handleTransfer() {
        if (!transferTo || !transferAmount || !principal) return;

        transferring = true;
        try {
            const amount = BigInt(Number(transferAmount) * Math.pow(10, tokenBalance.decimals));
            const result = await blockchainService.transferTokens(
                { toString: () => transferTo } as any,
                amount
            );

            if (result.success) {
                alert(`Transfer successful! Transaction ID: ${result.txId}`);
                transferTo = '';
                transferAmount = '';
                await loadBlockchainData(); // Refresh data
            } else {
                alert(`Transfer failed: ${result.error}`);
            }
        } catch (err) {
            console.error('Transfer failed:', err);
            alert('Transfer failed. Please try again.');
        } finally {
            transferring = false;
        }
    }

    async function handleProposalSubmit() {
        if (!proposalTitle || !proposalDescription) return;

        submittingProposal = true;
        try {
            const proposalTypeObj = {
                [proposalType]: proposalType === 'ParameterChange' 
                    ? { parameter: 'example', newValue: 'value' }
                    : { feature: 'example', enabled: true }
            };

            const result = await blockchainService.submitProposal(
                proposalTitle,
                proposalDescription,
                proposalTypeObj
            );

            if (result.success) {
                alert(`Proposal submitted successfully! ID: ${result.proposalId}`);
                proposalTitle = '';
                proposalDescription = '';
                await loadBlockchainData(); // Refresh proposals
            } else {
                alert(`Proposal submission failed: ${result.error}`);
            }
        } catch (err) {
            console.error('Proposal submission failed:', err);
            alert('Proposal submission failed. Please try again.');
        } finally {
            submittingProposal = false;
        }
    }

    async function voteOnProposal(proposalId: number, support: boolean) {
        try {
            const result = await blockchainService.voteOnProposal(proposalId, support);
            
            if (result.success) {
                alert('Vote recorded successfully!');
                await loadBlockchainData(); // Refresh proposals
            } else {
                alert(`Vote failed: ${result.error}`);
            }
        } catch (err) {
            console.error('Vote failed:', err);
            alert('Vote failed. Please try again.');
        }
    }

    function formatTokenAmount(amount: bigint, decimals: number): string {
        const divisor = BigInt(Math.pow(10, decimals));
        const whole = amount / divisor;
        const fraction = amount % divisor;
        return `${whole}.${fraction.toString().padStart(decimals, '0').slice(0, 4)}`;
    }

    function formatTimestamp(timestamp: bigint): string {
        return new Date(Number(timestamp) / 1_000_000).toLocaleString();
    }

    async function logout() {
        await authService.logout();
    }
</script>

<svelte:head>
    <title>Blockchain - Aegis Vault</title>
</svelte:head>

<div class="min-h-screen bg-gray-50">
    <!-- Header -->
    <header class="bg-white shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex justify-between items-center py-6">
                <div class="flex items-center">
                    <div class="h-8 w-8 flex items-center justify-center rounded-full bg-blue-100 mr-3">
                        <svg class="h-5 w-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                        </svg>
                    </div>
                    <h1 class="text-2xl font-bold text-gray-900">Blockchain Dashboard</h1>
                </div>
                <div class="flex items-center space-x-4">
                    <a href="/dashboard" class="text-indigo-600 hover:text-indigo-500 text-sm font-medium">
                        Back to Dashboard
                    </a>
                    <button
                        onclick={logout}
                        class="bg-gray-200 hover:bg-gray-300 px-3 py-2 rounded-md text-sm font-medium text-gray-700 transition-colors"
                    >
                        Logout
                    </button>
                </div>
            </div>
        </div>
    </header>

    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div class="px-4 py-6 sm:px-0">
            {#if error}
                <div class="mb-6 bg-red-50 border border-red-200 rounded-lg p-4">
                    <p class="text-sm text-red-800">{error}</p>
                </div>
            {/if}

            <!-- Blockchain Stats -->
            {#if blockchainStats}
                <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4 mb-8">
                    <div class="bg-white overflow-hidden shadow rounded-lg">
                        <div class="p-5">
                            <div class="flex items-center">
                                <div class="flex-shrink-0">
                                    <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                                    </svg>
                                </div>
                                <div class="ml-5 w-0 flex-1">
                                    <dl>
                                        <dt class="text-sm font-medium text-gray-500 truncate">Total Supply</dt>
                                        <dd class="text-lg font-medium text-gray-900">
                                            {formatTokenAmount(blockchainStats.totalSupply, 8)} AVT
                                        </dd>
                                    </dl>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white overflow-hidden shadow rounded-lg">
                        <div class="p-5">
                            <div class="flex items-center">
                                <div class="flex-shrink-0">
                                    <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                                    </svg>
                                </div>
                                <div class="ml-5 w-0 flex-1">
                                    <dl>
                                        <dt class="text-sm font-medium text-gray-500 truncate">Active Proposals</dt>
                                        <dd class="text-lg font-medium text-gray-900">{blockchainStats.activeProposals}</dd>
                                    </dl>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white overflow-hidden shadow rounded-lg">
                        <div class="p-5">
                            <div class="flex items-center">
                                <div class="flex-shrink-0">
                                    <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                                    </svg>
                                </div>
                                <div class="ml-5 w-0 flex-1">
                                    <dl>
                                        <dt class="text-sm font-medium text-gray-500 truncate">Your Balance</dt>
                                        <dd class="text-lg font-medium text-gray-900">
                                            {tokenBalance ? formatTokenAmount(tokenBalance.balance, tokenBalance.decimals) : '0'} AVT
                                        </dd>
                                    </dl>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white overflow-hidden shadow rounded-lg">
                        <div class="p-5">
                            <div class="flex items-center">
                                <div class="flex-shrink-0">
                                    <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                                    </svg>
                                </div>
                                <div class="ml-5 w-0 flex-1">
                                    <dl>
                                        <dt class="text-sm font-medium text-gray-500 truncate">Transactions</dt>
                                        <dd class="text-lg font-medium text-gray-900">{transactions.length}</dd>
                                    </dl>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            {/if}

            <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
                <!-- Token Transfer -->
                <div class="bg-white shadow rounded-lg">
                    <div class="px-6 py-4 border-b border-gray-200">
                        <h3 class="text-lg font-medium text-gray-900">Transfer Tokens</h3>
                    </div>
                    <div class="p-6">
                        <div class="space-y-4">
                            <div>
                                <label for="transfer-to" class="block text-sm font-medium text-gray-700">To Principal</label>
                                <input
                                    id="transfer-to"
                                    type="text"
                                    bind:value={transferTo}
                                    placeholder="Enter recipient principal ID"
                                    class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                                />
                            </div>
                            <div>
                                <label for="transfer-amount" class="block text-sm font-medium text-gray-700">Amount (AVT)</label>
                                <input
                                    id="transfer-amount"
                                    type="number"
                                    step="0.0001"
                                    bind:value={transferAmount}
                                    placeholder="0.0000"
                                    class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                                />
                            </div>
                            <button
                                onclick={handleTransfer}
                                disabled={!transferTo || !transferAmount || transferring}
                                class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
                            >
                                {transferring ? 'Transferring...' : 'Transfer Tokens'}
                            </button>
                        </div>
                    </div>
                </div>

                <!-- Submit Proposal -->
                <div class="bg-white shadow rounded-lg">
                    <div class="px-6 py-4 border-b border-gray-200">
                        <h3 class="text-lg font-medium text-gray-900">Submit Governance Proposal</h3>
                    </div>
                    <div class="p-6">
                        <div class="space-y-4">
                            <div>
                                <label for="proposal-title" class="block text-sm font-medium text-gray-700">Title</label>
                                <input
                                    id="proposal-title"
                                    type="text"
                                    bind:value={proposalTitle}
                                    placeholder="Proposal title"
                                    class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                                />
                            </div>
                            <div>
                                <label for="proposal-description" class="block text-sm font-medium text-gray-700">Description</label>
                                <textarea
                                    id="proposal-description"
                                    bind:value={proposalDescription}
                                    rows="3"
                                    placeholder="Detailed description of the proposal"
                                    class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                                ></textarea>
                            </div>
                            <div>
                                <label for="proposal-type" class="block text-sm font-medium text-gray-700">Type</label>
                                <select
                                    id="proposal-type"
                                    bind:value={proposalType}
                                    class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                                >
                                    <option value="ParameterChange">Parameter Change</option>
                                    <option value="FeatureToggle">Feature Toggle</option>
                                </select>
                            </div>
                            <button
                                onclick={handleProposalSubmit}
                                disabled={!proposalTitle || !proposalDescription || submittingProposal}
                                class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-purple-600 hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 disabled:opacity-50 disabled:cursor-not-allowed"
                            >
                                {submittingProposal ? 'Submitting...' : 'Submit Proposal'}
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Recent Transactions -->
            {#if transactions.length > 0}
                <div class="mt-8 bg-white shadow rounded-lg">
                    <div class="px-6 py-4 border-b border-gray-200">
                        <h3 class="text-lg font-medium text-gray-900">Recent Transactions</h3>
                    </div>
                    <div class="overflow-x-auto">
                        <table class="min-w-full divide-y divide-gray-200">
                            <thead class="bg-gray-50">
                                <tr>
                                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">From</th>
                                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">To</th>
                                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount</th>
                                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Time</th>
                                </tr>
                            </thead>
                            <tbody class="bg-white divide-y divide-gray-200">
                                {#each transactions as tx}
                                    <tr>
                                        <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                                {tx.op}
                                            </span>
                                        </td>
                                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                            {tx.from.slice(0, 8)}...{tx.from.slice(-8)}
                                        </td>
                                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                            {tx.to.slice(0, 8)}...{tx.to.slice(-8)}
                                        </td>
                                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                            {formatTokenAmount(tx.amount, 8)} AVT
                                        </td>
                                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                            {formatTimestamp(tx.timestamp)}
                                        </td>
                                    </tr>
                                {/each}
                            </tbody>
                        </table>
                    </div>
                </div>
            {/if}

            <!-- Governance Proposals -->
            {#if proposals.length > 0}
                <div class="mt-8 bg-white shadow rounded-lg">
                    <div class="px-6 py-4 border-b border-gray-200">
                        <h3 class="text-lg font-medium text-gray-900">Governance Proposals</h3>
                    </div>
                    <div class="divide-y divide-gray-200">
                        {#each proposals as proposal}
                            <div class="p-6">
                                <div class="flex items-start justify-between">
                                    <div class="flex-1">
                                        <h4 class="text-sm font-medium text-gray-900">#{proposal.id} - {proposal.title}</h4>
                                        <p class="mt-1 text-sm text-gray-600">{proposal.description}</p>
                                        <div class="mt-2 flex items-center space-x-4 text-xs text-gray-500">
                                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-{proposal.status === 'Open' ? 'green' : 'gray'}-100 text-{proposal.status === 'Open' ? 'green' : 'gray'}-800">
                                                {proposal.status}
                                            </span>
                                            <span>For: {proposal.votesFor.toString()}</span>
                                            <span>Against: {proposal.votesAgainst.toString()}</span>
                                            <span>Ends: {formatTimestamp(proposal.votingEnds)}</span>
                                        </div>
                                    </div>
                                    {#if proposal.status === 'Open'}
                                        <div class="ml-4 flex space-x-2">
                                            <button
                                                onclick={() => voteOnProposal(proposal.id, true)}
                                                class="bg-green-100 hover:bg-green-200 text-green-800 px-3 py-2 rounded-md text-sm font-medium transition-colors"
                                            >
                                                Vote For
                                            </button>
                                            <button
                                                onclick={() => voteOnProposal(proposal.id, false)}
                                                class="bg-red-100 hover:bg-red-200 text-red-800 px-3 py-2 rounded-md text-sm font-medium transition-colors"
                                            >
                                                Vote Against
                                            </button>
                                        </div>
                                    {/if}
                                </div>
                            </div>
                        {/each}
                    </div>
                </div>
            {/if}
        </div>
    </main>
</div>
