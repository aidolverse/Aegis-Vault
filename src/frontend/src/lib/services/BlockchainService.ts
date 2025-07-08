import { actorService } from "./ActorService"
import type { Principal } from "@dfinity/principal"

interface TokenBalance {
  balance: bigint
  symbol: string
  decimals: number
}

interface Transaction {
  index: number
  from: string
  to: string
  amount: bigint
  fee: bigint
  timestamp: bigint
  status: string
  op: string
}

interface Proposal {
  id: number
  title: string
  description: string
  status: string
  votesFor: bigint
  votesAgainst: bigint
  votingEnds: bigint
  executed: boolean
}

class BlockchainService {
  private tokenActor: any = null
  private governanceActor: any = null

  async init(): Promise<void> {
    try {
      // Initialize token and governance actors with fallback
      try {
        this.tokenActor = await this.createTokenActor()
      } catch (error) {
        console.warn("Token actor not available:", error)
      }

      try {
        this.governanceActor = await this.createGovernanceActor()
      } catch (error) {
        console.warn("Governance actor not available:", error)
      }
    } catch (error) {
      console.error("Failed to initialize blockchain service:", error)
      // Don't throw error to allow app to continue without blockchain features
    }
  }

  // Token Functions with fallbacks
  async getTokenBalance(principal: Principal): Promise<TokenBalance> {
    if (!this.tokenActor) {
      return {
        balance: BigInt(0),
        symbol: "AVT",
        decimals: 8,
      }
    }

    try {
      const balance = await this.tokenActor.balanceOf(principal)
      const symbol = await this.tokenActor.symbol()
      const decimals = await this.tokenActor.decimals()

      return {
        balance: BigInt(balance),
        symbol,
        decimals: Number(decimals),
      }
    } catch (error) {
      console.error("Failed to get token balance:", error)
      return {
        balance: BigInt(0),
        symbol: "AVT",
        decimals: 8,
      }
    }
  }

  async transferTokens(to: Principal, amount: bigint): Promise<{ success: boolean; txId?: number; error?: string }> {
    if (!this.tokenActor) {
      return { success: false, error: "Token service not available" }
    }

    try {
      const result = await this.tokenActor.transfer(to, Number(amount))

      if ("ok" in result) {
        return { success: true, txId: result.ok }
      } else {
        return { success: false, error: result.err }
      }
    } catch (error) {
      return { success: false, error: String(error) }
    }
  }

  async getTransactionHistory(start = 0, limit = 10): Promise<Transaction[]> {
    if (!this.tokenActor) return []

    try {
      const transactions = await this.tokenActor.getTransactions(start, limit)
      return transactions.map((tx: any) => ({
        index: tx.index,
        from: tx.from.toString(),
        to: tx.to.toString(),
        amount: BigInt(tx.amount),
        fee: BigInt(tx.fee),
        timestamp: BigInt(tx.timestamp),
        status: tx.status,
        op: tx.op,
      }))
    } catch (error) {
      console.error("Failed to get transaction history:", error)
      return []
    }
  }

  // Governance Functions with fallbacks
  async submitProposal(
    title: string,
    description: string,
    proposalType: any,
  ): Promise<{ success: boolean; proposalId?: number; error?: string }> {
    if (!this.governanceActor) {
      return { success: false, error: "Governance service not available" }
    }

    try {
      const result = await this.governanceActor.submitProposal(title, description, proposalType)

      if ("ok" in result) {
        return { success: true, proposalId: result.ok }
      } else {
        return { success: false, error: result.err }
      }
    } catch (error) {
      return { success: false, error: String(error) }
    }
  }

  async voteOnProposal(proposalId: number, support: boolean): Promise<{ success: boolean; error?: string }> {
    if (!this.governanceActor) {
      return { success: false, error: "Governance service not available" }
    }

    try {
      const result = await this.governanceActor.vote(proposalId, support)

      if ("ok" in result) {
        return { success: true }
      } else {
        return { success: false, error: result.err }
      }
    } catch (error) {
      return { success: false, error: String(error) }
    }
  }

  async getAllProposals(): Promise<Proposal[]> {
    if (!this.governanceActor) return []

    try {
      const proposals = await this.governanceActor.getAllProposals()
      return proposals.map((p: any) => ({
        id: p.id,
        title: p.title,
        description: p.description,
        status: Object.keys(p.status)[0],
        votesFor: BigInt(p.votesFor),
        votesAgainst: BigInt(p.votesAgainst),
        votingEnds: BigInt(p.votingEnds),
        executed: p.executed,
      }))
    } catch (error) {
      console.error("Failed to get proposals:", error)
      return []
    }
  }

  // Blockchain analytics with fallbacks
  async getBlockchainStats(): Promise<{
    totalSupply: bigint
    totalTransactions: number
    activeProposals: number
    tokenHolders: number
  }> {
    try {
      const totalSupply = this.tokenActor ? await this.tokenActor.totalSupply() : 0
      const proposals = await this.getAllProposals()
      const activeProposals = proposals.filter((p) => p.status === "Open").length

      return {
        totalSupply: BigInt(totalSupply),
        totalTransactions: 0, // Would need to implement counter
        activeProposals,
        tokenHolders: 0, // Would need to implement counter
      }
    } catch (error) {
      console.error("Failed to get blockchain stats:", error)
      return {
        totalSupply: BigInt(0),
        totalTransactions: 0,
        activeProposals: 0,
        tokenHolders: 0,
      }
    }
  }

  // Private helper methods
  private async createTokenActor() {
    const canisterId = import.meta.env.VITE_TOKEN_CANISTER_ID || "rdmx6-jaaaa-aaaah-qcaiq-cai"
    return actorService.createActor(canisterId, this.getTokenIdl())
  }

  private async createGovernanceActor() {
    const canisterId = import.meta.env.VITE_GOVERNANCE_CANISTER_ID || "rdmx6-jaaaa-aaaah-qcaiq-cai"
    return actorService.createActor(canisterId, this.getGovernanceIdl())
  }

  private getTokenIdl() {
    return ({ IDL }: any) => {
      const Result = IDL.Variant({ ok: IDL.Nat, err: IDL.Text })
      const TxRecord = IDL.Record({
        caller: IDL.Opt(IDL.Principal),
        op: IDL.Text,
        index: IDL.Nat,
        from: IDL.Principal,
        to: IDL.Principal,
        amount: IDL.Nat,
        fee: IDL.Nat,
        timestamp: IDL.Int,
        status: IDL.Text,
      })

      return IDL.Service({
        name: IDL.Func([], [IDL.Text], ["query"]),
        symbol: IDL.Func([], [IDL.Text], ["query"]),
        decimals: IDL.Func([], [IDL.Nat8], ["query"]),
        totalSupply: IDL.Func([], [IDL.Nat], ["query"]),
        balanceOf: IDL.Func([IDL.Principal], [IDL.Nat], ["query"]),
        transfer: IDL.Func([IDL.Principal, IDL.Nat], [Result], []),
        approve: IDL.Func([IDL.Principal, IDL.Nat], [Result], []),
        allowance: IDL.Func([IDL.Principal, IDL.Principal], [IDL.Nat], ["query"]),
        getTransactions: IDL.Func([IDL.Nat, IDL.Nat], [IDL.Vec(TxRecord)], ["query"]),
        rewardDataContribution: IDL.Func([IDL.Principal, IDL.Nat], [Result], []),
        payForQuery: IDL.Func([IDL.Nat], [Result], []),
      })
    }
  }

  private getGovernanceIdl() {
    return ({ IDL }: any) => {
      const ProposalType = IDL.Variant({
        SystemUpgrade: IDL.Record({ wasmModule: IDL.Vec(IDL.Nat8) }),
        ParameterChange: IDL.Record({ parameter: IDL.Text, newValue: IDL.Text }),
        TokenMint: IDL.Record({ recipient: IDL.Principal, amount: IDL.Nat }),
        FeatureToggle: IDL.Record({ feature: IDL.Text, enabled: IDL.Bool }),
      })

      const ProposalStatus = IDL.Variant({
        Open: IDL.Null,
        Passed: IDL.Null,
        Rejected: IDL.Null,
        Executed: IDL.Null,
      })

      const Proposal = IDL.Record({
        id: IDL.Nat,
        proposer: IDL.Principal,
        title: IDL.Text,
        description: IDL.Text,
        proposalType: ProposalType,
        votingPower: IDL.Nat,
        votesFor: IDL.Nat,
        votesAgainst: IDL.Nat,
        status: ProposalStatus,
        createdAt: IDL.Int,
        votingEnds: IDL.Int,
        executed: IDL.Bool,
      })

      const Result = IDL.Variant({ ok: IDL.Nat, err: IDL.Text })
      const ResultText = IDL.Variant({ ok: IDL.Text, err: IDL.Text })

      return IDL.Service({
        submitProposal: IDL.Func([IDL.Text, IDL.Text, ProposalType], [Result], []),
        vote: IDL.Func([IDL.Nat, IDL.Bool], [ResultText], []),
        executeProposal: IDL.Func([IDL.Nat], [ResultText], []),
        getProposal: IDL.Func([IDL.Nat], [IDL.Opt(Proposal)], ["query"]),
        getAllProposals: IDL.Func([], [IDL.Vec(Proposal)], ["query"]),
      })
    }
  }
}

export const blockchainService = new BlockchainService()
