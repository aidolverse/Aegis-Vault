import { writable } from "svelte/store"

interface AuthState {
  isAuthenticated: boolean
  principal: string | null
}

export const authStore = writable<AuthState>({
  isAuthenticated: false,
  principal: null,
})
