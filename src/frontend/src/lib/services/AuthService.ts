import { AuthClient } from "@dfinity/auth-client"
import type { Identity } from "@dfinity/agent"
import type { Principal } from "@dfinity/principal"
import { writable, derived } from "svelte/store"

// Enhanced auth state management
export const authClient = writable<AuthClient | null>(null)
export const identity = writable<Identity | null>(null)
export const principal = writable<Principal | null>(null)
export const isAuthenticated = derived(
  [identity, principal],
  ([$identity, $principal]) => $identity !== null && $principal !== null && !$principal.isAnonymous(),
)

// Enhanced error handling
export const authError = writable<string | null>(null)
export const authLoading = writable<boolean>(false)

class AuthService {
  private client: AuthClient | null = null
  private readonly maxRetries = 3
  private retryCount = 0

  async init(): Promise<void> {
    try {
      authLoading.set(true)
      authError.set(null)

      this.client = await AuthClient.create({
        idleOptions: {
          idleTimeout: 1000 * 60 * 30, // 30 minutes
          disableDefaultIdleCallback: true,
        },
      })

      authClient.set(this.client)

      const isAuthenticated = await this.client.isAuthenticated()

      if (isAuthenticated) {
        await this.updateAuthState()
      }
    } catch (error) {
      console.error("Auth initialization failed:", error)
      authError.set("Failed to initialize authentication")
    } finally {
      authLoading.set(false)
    }
  }

  async login(): Promise<void> {
    if (!this.client) {
      throw new Error("Auth client not initialized")
    }

    return new Promise((resolve, reject) => {
      authLoading.set(true)
      authError.set(null)

      const identityProvider = this.getIdentityProvider()

      this.client!.login({
        identityProvider,
        maxTimeToLive: BigInt(7 * 24 * 60 * 60 * 1000 * 1000 * 1000), // 7 days in nanoseconds
        windowOpenerFeatures: "toolbar=0,location=0,menubar=0,width=500,height=500,left=100,top=100",
        onSuccess: async () => {
          try {
            await this.updateAuthState()
            authLoading.set(false)
            resolve()
          } catch (error) {
            authLoading.set(false)
            authError.set("Failed to update authentication state")
            reject(error)
          }
        },
        onError: (error) => {
          authLoading.set(false)
          authError.set("Login failed: " + (error || "Unknown error"))
          reject(error)
        },
      })
    })
  }

  async logout(): Promise<void> {
    if (!this.client) {
      throw new Error("Auth client not initialized")
    }

    try {
      authLoading.set(true)
      await this.client.logout()
      this.clearAuthState()
    } catch (error) {
      console.error("Logout failed:", error)
      authError.set("Logout failed")
    } finally {
      authLoading.set(false)
    }
  }

  private async updateAuthState(): Promise<void> {
    if (!this.client) return

    const currentIdentity = this.client.getIdentity()
    const currentPrincipal = currentIdentity.getPrincipal()

    identity.set(currentIdentity)
    principal.set(currentPrincipal)

    console.log("Auth state updated:", {
      principal: currentPrincipal.toString(),
      isAnonymous: currentPrincipal.isAnonymous(),
    })
  }

  private clearAuthState(): void {
    identity.set(null)
    principal.set(null)
    authError.set(null)
  }

  private getIdentityProvider(): string {
    const isDevelopment = import.meta.env.DEV || import.meta.env.DFX_NETWORK === "local"

    if (isDevelopment) {
      const canisterId = import.meta.env.VITE_INTERNET_IDENTITY_CANISTER_ID || "rdmx6-jaaaa-aaaaa-aaadq-cai"
      return `http://localhost:4943/?canisterId=${canisterId}`
    }

    return "https://identity.ic0.app"
  }

  getIdentity(): Identity | null {
    return this.client?.getIdentity() || null
  }

  getPrincipal(): Principal | null {
    const currentIdentity = this.getIdentity()
    return currentIdentity?.getPrincipal() || null
  }

  // Enhanced session management
  async checkSession(): Promise<boolean> {
    if (!this.client) return false

    try {
      const isAuthenticated = await this.client.isAuthenticated()
      if (isAuthenticated) {
        await this.updateAuthState()
        return true
      }
      return false
    } catch (error) {
      console.error("Session check failed:", error)
      return false
    }
  }

  // Retry mechanism for failed operations
  async retryOperation<T>(operation: () => Promise<T>): Promise<T> {
    try {
      return await operation()
    } catch (error) {
      if (this.retryCount < this.maxRetries) {
        this.retryCount++
        console.log(`Retrying operation (attempt ${this.retryCount})`)
        await new Promise((resolve) => setTimeout(resolve, 1000 * this.retryCount))
        return this.retryOperation(operation)
      }
      this.retryCount = 0
      throw error
    }
  }
}

export const authService = new AuthService()
