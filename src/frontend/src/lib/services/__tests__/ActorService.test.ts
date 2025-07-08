import { describe, it, expect, vi, beforeEach } from "vitest"
import { Actor, HttpAgent } from "@dfinity/agent"
import { actorService } from "../ActorService"
import { authService } from "../AuthService"

// Mock @dfinity/agent
vi.mock("@dfinity/agent", () => ({
  Actor: {
    createActor: vi.fn(),
  },
  HttpAgent: vi.fn(),
}))

// Mock AuthService
vi.mock("../AuthService", () => ({
  authService: {
    getIdentity: vi.fn(),
  },
}))

describe("ActorService", () => {
  let mockAgent: any
  let mockActor: any

  beforeEach(() => {
    vi.clearAllMocks()

    mockAgent = {
      fetchRootKey: vi.fn(),
      replaceIdentity: vi.fn(),
    }

    mockActor = {
      registerMyVault: vi.fn(),
      submitQuery: vi.fn(),
      healthCheck: vi.fn(),
    }

    vi.mocked(HttpAgent).mockReturnValue(mockAgent)
    vi.mocked(Actor.createActor).mockReturnValue(mockActor)

    // Mock environment variables
    vi.stubEnv("DEV", true)
    vi.stubEnv("VITE_AGGREGATOR_CANISTER_ID", "test-aggregator-id")
    vi.stubEnv("VITE_USERVAULT_CANISTER_ID", "test-uservault-id")
  })

  describe("init", () => {
    it("should initialize successfully in development", async () => {
      await actorService.init()

      expect(HttpAgent).toHaveBeenCalledWith({
        host: "http://localhost:4943",
        retryTimes: 3,
      })
      expect(mockAgent.fetchRootKey).toHaveBeenCalled()
    })

    it("should initialize successfully in production", async () => {
      vi.stubEnv("DEV", false)

      await actorService.init()

      expect(HttpAgent).toHaveBeenCalledWith({
        host: "https://ic0.app",
        retryTimes: 3,
      })
      expect(mockAgent.fetchRootKey).not.toHaveBeenCalled()
    })

    it("should handle initialization errors", async () => {
      vi.mocked(HttpAgent).mockImplementation(() => {
        throw new Error("Agent creation failed")
      })

      await expect(actorService.init()).rejects.toThrow("Actor service initialization failed")
    })
  })

  describe("createAggregatorActor", () => {
    beforeEach(async () => {
      await actorService.init()
    })

    it("should create aggregator actor successfully", async () => {
      const mockIdentity = { getPrincipal: () => "test-principal" }
      vi.mocked(authService.getIdentity).mockReturnValue(mockIdentity as any)

      const actor = await actorService.createAggregatorActor()

      expect(mockAgent.replaceIdentity).toHaveBeenCalledWith(mockIdentity)
      expect(Actor.createActor).toHaveBeenCalledWith(expect.any(Function), {
        agent: mockAgent,
        canisterId: "test-aggregator-id",
      })
      expect(actor).toBe(mockActor)
    })

    it("should cache actor instances", async () => {
      const actor1 = await actorService.createAggregatorActor()
      const actor2 = await actorService.createAggregatorActor()

      expect(actor1).toBe(actor2)
      expect(Actor.createActor).toHaveBeenCalledTimes(1)
    })

    it("should handle missing canister ID", async () => {
      vi.stubEnv("VITE_AGGREGATOR_CANISTER_ID", "")

      await expect(actorService.createAggregatorActor()).rejects.toThrow("Canister ID not found for AGGREGATOR")
    })
  })

  describe("createUserVaultActor", () => {
    beforeEach(async () => {
      await actorService.init()
    })

    it("should create user vault actor successfully", async () => {
      const actor = await actorService.createUserVaultActor()

      expect(Actor.createActor).toHaveBeenCalledWith(expect.any(Function), {
        agent: mockAgent,
        canisterId: "test-uservault-id",
      })
      expect(actor).toBe(mockActor)
    })

    it("should create user vault actor with custom canister ID", async () => {
      const customCanisterId = "custom-vault-id"

      const actor = await actorService.createUserVaultActor(customCanisterId)

      expect(Actor.createActor).toHaveBeenCalledWith(expect.any(Function), {
        agent: mockAgent,
        canisterId: customCanisterId,
      })
    })
  })

  describe("performHealthCheck", () => {
    beforeEach(async () => {
      await actorService.init()
    })

    it("should perform health check successfully", async () => {
      const mockAggregatorHealth = { status: "healthy", version: 1 }
      const mockVaultHealth = { status: "healthy", version: 1 }

      mockActor.healthCheck.mockResolvedValueOnce(mockAggregatorHealth).mockResolvedValueOnce(mockVaultHealth)

      const result = await actorService.performHealthCheck()

      expect(result).toEqual({
        aggregator: mockAggregatorHealth,
        userVault: mockVaultHealth,
        agent: true,
      })
    })

    it("should handle partial health check failures", async () => {
      mockActor.healthCheck
        .mockRejectedValueOnce(new Error("Aggregator health check failed"))
        .mockResolvedValueOnce({ status: "healthy", version: 1 })

      const result = await actorService.performHealthCheck()

      expect(result).toEqual({
        aggregator: null,
        userVault: { status: "healthy", version: 1 },
        agent: true,
      })
    })
  })

  describe("clearCache", () => {
    it("should clear actor cache", async () => {
      await actorService.init()

      // Create an actor to populate cache
      await actorService.createAggregatorActor()
      expect(Actor.createActor).toHaveBeenCalledTimes(1)

      // Clear cache
      actorService.clearCache()

      // Create actor again - should call createActor again
      await actorService.createAggregatorActor()
      expect(Actor.createActor).toHaveBeenCalledTimes(2)
    })
  })
})
