import { describe, it, expect, vi, beforeEach, afterEach } from "vitest"
import { get } from "svelte/store"
import { AuthClient } from "@dfinity/auth-client"
import { authService, isAuthenticated, principal, authError, authLoading } from "../AuthService"

// Mock @dfinity/auth-client
vi.mock("@dfinity/auth-client", () => ({
  AuthClient: {
    create: vi.fn(),
  },
}))

// Mock @dfinity/principal
vi.mock("@dfinity/principal", () => ({
  Principal: {
    fromText: vi.fn((text) => ({ toString: () => text, isAnonymous: () => false })),
  },
}))

describe("AuthService", () => {
  let mockAuthClient: any

  beforeEach(() => {
    // Reset all mocks
    vi.clearAllMocks()

    // Create mock auth client
    mockAuthClient = {
      isAuthenticated: vi.fn(),
      login: vi.fn(),
      logout: vi.fn(),
      getIdentity: vi.fn(),
    }

    // Mock AuthClient.create to return our mock
    vi.mocked(AuthClient.create).mockResolvedValue(mockAuthClient)
  })

  afterEach(() => {
    // Reset stores
    isAuthenticated.set(false)
    principal.set(null)
    authError.set(null)
    authLoading.set(false)
  })

  describe("init", () => {
    it("should initialize successfully when not authenticated", async () => {
      mockAuthClient.isAuthenticated.mockResolvedValue(false)

      await authService.init()

      expect(AuthClient.create).toHaveBeenCalledWith({
        idleOptions: {
          idleTimeout: 1000 * 60 * 30,
          disableDefaultIdleCallback: true,
        },
      })
      expect(mockAuthClient.isAuthenticated).toHaveBeenCalled()
      expect(get(authLoading)).toBe(false)
      expect(get(authError)).toBe(null)
    })

    it("should initialize and update auth state when authenticated", async () => {
      const mockIdentity = {
        getPrincipal: () => ({ toString: () => "test-principal", isAnonymous: () => false }),
      }

      mockAuthClient.isAuthenticated.mockResolvedValue(true)
      mockAuthClient.getIdentity.mockReturnValue(mockIdentity)

      await authService.init()

      expect(get(isAuthenticated)).toBe(true)
      expect(get(principal)?.toString()).toBe("test-principal")
    })

    it("should handle initialization errors", async () => {
      vi.mocked(AuthClient.create).mockRejectedValue(new Error("Init failed"))

      await authService.init()

      expect(get(authError)).toBe("Failed to initialize authentication")
      expect(get(authLoading)).toBe(false)
    })
  })

  describe("login", () => {
    beforeEach(async () => {
      await authService.init()
    })

    it("should login successfully", async () => {
      const mockIdentity = {
        getPrincipal: () => ({ toString: () => "test-principal", isAnonymous: () => false }),
      }

      mockAuthClient.getIdentity.mockReturnValue(mockIdentity)
      mockAuthClient.login.mockImplementation(({ onSuccess }) => {
        onSuccess()
      })

      await authService.login()

      expect(mockAuthClient.login).toHaveBeenCalledWith({
        identityProvider: expect.any(String),
        maxTimeToLive: expect.any(BigInt),
        windowOpenerFeatures: expect.any(String),
        onSuccess: expect.any(Function),
        onError: expect.any(Function),
      })
      expect(get(isAuthenticated)).toBe(true)
      expect(get(authLoading)).toBe(false)
    })

    it("should handle login errors", async () => {
      mockAuthClient.login.mockImplementation(({ onError }) => {
        onError("Login failed")
      })

      await expect(authService.login()).rejects.toBe("Login failed")
      expect(get(authError)).toBe("Login failed: Login failed")
      expect(get(authLoading)).toBe(false)
    })

    it("should throw error if client not initialized", async () => {
      const uninitializedService = new (authService.constructor as any)()

      await expect(uninitializedService.login()).rejects.toThrow("Auth client not initialized")
    })
  })

  describe("logout", () => {
    beforeEach(async () => {
      await authService.init()
      // Set authenticated state
      isAuthenticated.set(true)
      principal.set({ toString: () => "test-principal" } as any)
    })

    it("should logout successfully", async () => {
      mockAuthClient.logout.mockResolvedValue(undefined)

      await authService.logout()

      expect(mockAuthClient.logout).toHaveBeenCalled()
      expect(get(isAuthenticated)).toBe(false)
      expect(get(principal)).toBe(null)
      expect(get(authLoading)).toBe(false)
    })

    it("should handle logout errors", async () => {
      mockAuthClient.logout.mockRejectedValue(new Error("Logout failed"))

      await authService.logout()

      expect(get(authError)).toBe("Logout failed")
      expect(get(authLoading)).toBe(false)
    })
  })

  describe("checkSession", () => {
    beforeEach(async () => {
      await authService.init()
    })

    it("should return true for valid session", async () => {
      const mockIdentity = {
        getPrincipal: () => ({ toString: () => "test-principal", isAnonymous: () => false }),
      }

      mockAuthClient.isAuthenticated.mockResolvedValue(true)
      mockAuthClient.getIdentity.mockReturnValue(mockIdentity)

      const result = await authService.checkSession()

      expect(result).toBe(true)
      expect(get(isAuthenticated)).toBe(true)
    })

    it("should return false for invalid session", async () => {
      mockAuthClient.isAuthenticated.mockResolvedValue(false)

      const result = await authService.checkSession()

      expect(result).toBe(false)
    })

    it("should handle session check errors", async () => {
      mockAuthClient.isAuthenticated.mockRejectedValue(new Error("Session check failed"))

      const result = await authService.checkSession()

      expect(result).toBe(false)
    })
  })

  describe("retryOperation", () => {
    beforeEach(async () => {
      await authService.init()
    })

    it("should succeed on first try", async () => {
      const mockOperation = vi.fn().mockResolvedValue("success")

      const result = await authService.retryOperation(mockOperation)

      expect(result).toBe("success")
      expect(mockOperation).toHaveBeenCalledTimes(1)
    })

    it("should retry on failure and eventually succeed", async () => {
      const mockOperation = vi
        .fn()
        .mockRejectedValueOnce(new Error("First failure"))
        .mockRejectedValueOnce(new Error("Second failure"))
        .mockResolvedValue("success")

      const result = await authService.retryOperation(mockOperation)

      expect(result).toBe("success")
      expect(mockOperation).toHaveBeenCalledTimes(3)
    })

    it("should fail after max retries", async () => {
      const mockOperation = vi.fn().mockRejectedValue(new Error("Persistent failure"))

      await expect(authService.retryOperation(mockOperation)).rejects.toThrow("Persistent failure")
      expect(mockOperation).toHaveBeenCalledTimes(4) // Initial + 3 retries
    })
  })
})
