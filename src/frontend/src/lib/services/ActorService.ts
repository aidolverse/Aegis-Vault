import { Actor, HttpAgent } from "@dfinity/agent"
import { authService } from "./AuthService"

// Enhanced actor service with better error handling and caching
class ActorService {
  private agent: HttpAgent | null = null
  private actorCache = new Map<string, any>()
  private readonly maxRetries = 3

  async init(): Promise<void> {
    try {
      const host = this.getHost()

      this.agent = new HttpAgent({
        host,
        retryTimes: this.maxRetries,
      })

      // Fetch root key for local development
      if (this.isLocalDevelopment()) {
        await this.agent.fetchRootKey()
      }

      console.log("Actor service initialized with host:", host)
    } catch (error) {
      console.error("Failed to initialize actor service:", error)
      throw new Error("Actor service initialization failed")
    }
  }

  async createAggregatorActor() {
    const canisterId = this.getCanisterId("AGGREGATOR")
    const cacheKey = `aggregator-${canisterId}`

    if (this.actorCache.has(cacheKey)) {
      return this.actorCache.get(cacheKey)
    }

    try {
      const actor = await this.createActor(canisterId, this.getAggregatorIdl())
      this.actorCache.set(cacheKey, actor)
      return actor
    } catch (error) {
      console.error("Failed to create aggregator actor:", error)
      throw new Error("Failed to create aggregator actor")
    }
  }

  async createUserVaultActor(canisterId?: string) {
    const vaultCanisterId = canisterId || this.getCanisterId("USERVAULT")
    const cacheKey = `uservault-${vaultCanisterId}`

    if (this.actorCache.has(cacheKey)) {
      return this.actorCache.get(cacheKey)
    }

    try {
      const actor = await this.createActor(vaultCanisterId, this.getUserVaultIdl())
      this.actorCache.set(cacheKey, actor)
      return actor
    } catch (error) {
      console.error("Failed to create user vault actor:", error)
      throw new Error("Failed to create user vault actor")
    }
  }

  private async createActor(canisterId: string, idlFactory: any) {
    if (!this.agent) {
      throw new Error("Agent not initialized")
    }

    // Update agent identity if user is authenticated
    const identity = authService.getIdentity()
    if (identity) {
      this.agent.replaceIdentity(identity)
    }

    return Actor.createActor(idlFactory, {
      agent: this.agent,
      canisterId,
    })
  }

  private getHost(): string {
    if (this.isLocalDevelopment()) {
      return "http://localhost:4943"
    }
    return "https://ic0.app"
  }

  private isLocalDevelopment(): boolean {
    return import.meta.env.DEV || import.meta.env.DFX_NETWORK === "local"
  }

  private getCanisterId(canisterName: string): string {
    const envKey = `VITE_${canisterName}_CANISTER_ID`
    const canisterId = import.meta.env[envKey]

    if (!canisterId) {
      console.warn(`Canister ID not found for ${canisterName}. Using placeholder.`)
      return "rdmx6-jaaaa-aaaah-qcaiq-cai" // Placeholder canister ID
    }

    return canisterId
  }

  // Enhanced IDL factories with proper typing
  private getAggregatorIdl() {
    return ({ IDL }: any) => {
      const QueryStatus = IDL.Variant({
        pending: IDL.Null,
        active: IDL.Null,
        completed: IDL.Null,
        expired: IDL.Null,
      })

      const Query = IDL.Record({
        id: IDL.Nat,
        recipeId: IDL.Nat,
        description: IDL.Text,
        timestamp: IDL.Int,
        requester: IDL.Principal,
        status: QueryStatus,
        expiresAt: IDL.Int,
      })

      const QueryResult = IDL.Record({
        queryId: IDL.Nat,
        trueCount: IDL.Nat,
        falseCount: IDL.Nat,
        totalResponses: IDL.Nat,
        participationRate: IDL.Float64,
        completedAt: IDL.Opt(IDL.Int),
      })

      const AnalysisRecipe = IDL.Record({
        id: IDL.Nat,
        name: IDL.Text,
        description: IDL.Text,
        category: IDL.Text,
        parameters: IDL.Vec(IDL.Tuple(IDL.Text, IDL.Text)),
      })

      const Result = IDL.Variant({
        ok: IDL.Text,
        err: IDL.Text,
      })

      const ResultNat = IDL.Variant({
        ok: IDL.Nat,
        err: IDL.Text,
      })

      const ResultQueryResult = IDL.Variant({
        ok: QueryResult,
        err: IDL.Text,
      })

      return IDL.Service({
        registerMyVault: IDL.Func([], [Result], []),
        submitQuery: IDL.Func([IDL.Nat], [ResultNat], []),
        submitAnonymousResult: IDL.Func([IDL.Nat, IDL.Bool], [Result], []),
        getQueryResults: IDL.Func([IDL.Nat], [ResultQueryResult], ["query"]),
        getAnalysisRecipes: IDL.Func([], [IDL.Vec(AnalysisRecipe)], ["query"]),
        getActiveQueries: IDL.Func([IDL.Opt(QueryStatus)], [IDL.Vec(Query)], ["query"]),
        getRegisteredVaultCount: IDL.Func([], [IDL.Nat], ["query"]),
        healthCheck: IDL.Func(
          [],
          [
            IDL.Record({
              status: IDL.Text,
              version: IDL.Nat,
              cyclesBalance: IDL.Nat,
              memoryUsage: IDL.Nat,
            }),
          ],
          ["query"],
        ),
      })
    }
  }

  private getUserVaultIdl() {
    return ({ IDL }: any) => {
      const QueryStatus = IDL.Variant({
        pending: IDL.Null,
        active: IDL.Null,
        completed: IDL.Null,
        expired: IDL.Null,
      })

      const Query = IDL.Record({
        id: IDL.Nat,
        recipeId: IDL.Nat,
        description: IDL.Text,
        timestamp: IDL.Int,
        requester: IDL.Principal,
        status: QueryStatus,
        expiresAt: IDL.Int,
      })

      const VaultStats = IDL.Record({
        owner: IDL.Principal,
        dataEntries: IDL.Nat,
        totalQueries: IDL.Nat,
        approvedQueries: IDL.Nat,
        rejectedQueries: IDL.Nat,
        lastActivity: IDL.Int,
        vaultVersion: IDL.Nat,
      })

      const AccessLog = IDL.Record({
        timestamp: IDL.Int,
        action: IDL.Text,
        queryId: IDL.Opt(IDL.Nat),
        success: IDL.Bool,
      })

      const Result = IDL.Variant({
        ok: IDL.Text,
        err: IDL.Text,
      })

      const ResultNat = IDL.Variant({
        ok: IDL.Nat,
        err: IDL.Text,
      })

      const ResultBool = IDL.Variant({
        ok: IDL.Bool,
        err: IDL.Text,
      })

      const ResultQueries = IDL.Variant({
        ok: IDL.Vec(Query),
        err: IDL.Text,
      })

      const ResultVaultStats = IDL.Variant({
        ok: VaultStats,
        err: IDL.Text,
      })

      const ResultAccessLogs = IDL.Variant({
        ok: IDL.Vec(AccessLog),
        err: IDL.Text,
      })

      return IDL.Service({
        initialize: IDL.Func([], [Result], []),
        uploadData: IDL.Func([IDL.Vec(IDL.Nat8), IDL.Text], [ResultNat], []),
        receiveQuery: IDL.Func([Query], [Result], []),
        getPendingQueries: IDL.Func([], [ResultQueries], []),
        approveRequest: IDL.Func([IDL.Nat], [ResultBool], []),
        rejectRequest: IDL.Func([IDL.Nat], [Result], []),
        getOwner: IDL.Func([], [IDL.Principal], ["query"]),
        hasData: IDL.Func([], [IDL.Bool], ["query"]),
        getDataCount: IDL.Func([], [IDL.Nat], ["query"]),
        getVaultStats: IDL.Func([], [ResultVaultStats], []),
        getAccessLogs: IDL.Func([IDL.Opt(IDL.Nat)], [ResultAccessLogs], []),
        healthCheck: IDL.Func(
          [],
          [
            IDL.Record({
              status: IDL.Text,
              owner: IDL.Principal,
              dataEntries: IDL.Nat,
              pendingQueries: IDL.Nat,
              version: IDL.Nat,
              cyclesBalance: IDL.Nat,
            }),
          ],
          ["query"],
        ),
      })
    }
  }

  // Clear cache when identity changes
  clearCache(): void {
    this.actorCache.clear()
  }

  // Health check for all services
  async performHealthCheck(): Promise<{
    aggregator: any
    userVault: any
    agent: boolean
  }> {
    try {
      const results = {
        aggregator: null,
        userVault: null,
        agent: this.agent !== null,
      }

      try {
        const aggregatorActor = await this.createAggregatorActor()
        results.aggregator = await aggregatorActor.healthCheck()
      } catch (error) {
        console.error("Aggregator health check failed:", error)
      }

      try {
        const userVaultActor = await this.createUserVaultActor()
        results.userVault = await userVaultActor.healthCheck()
      } catch (error) {
        console.error("UserVault health check failed:", error)
      }

      return results
    } catch (error) {
      console.error("Health check failed:", error)
      throw error
    }
  }
}

export const actorService = new ActorService()
