import { vi } from "vitest"
import "@testing-library/jest-dom"

// Mock environment variables
vi.stubEnv("VITE_AGGREGATOR_CANISTER_ID", "test-aggregator-id")
vi.stubEnv("VITE_USERVAULT_CANISTER_ID", "test-uservault-id")
vi.stubEnv("VITE_INTERNET_IDENTITY_CANISTER_ID", "test-ii-id")
vi.stubEnv("DEV", "true")

// Mock global objects
Object.defineProperty(window, "crypto", {
  value: {
    getRandomValues: vi.fn((arr) => {
      for (let i = 0; i < arr.length; i++) {
        arr[i] = Math.floor(Math.random() * 256)
      }
      return arr
    }),
  },
})

// Mock FileReader
global.FileReader = class MockFileReader {
  onload: ((event: any) => void) | null = null
  onerror: (() => void) | null = null
  result: string | ArrayBuffer | null = null

  readAsText(file: File) {
    setTimeout(() => {
      this.result = "mocked file content"
      this.onload?.({ target: { result: this.result } })
    }, 0)
  }

  readAsArrayBuffer(file: File) {
    setTimeout(() => {
      this.result = new ArrayBuffer(8)
      this.onload?.({ target: { result: this.result } })
    }, 0)
  }
} as any

// Mock TextEncoder/TextDecoder
global.TextEncoder = class MockTextEncoder {
  encode(input: string): Uint8Array {
    return new Uint8Array(Array.from(input).map((char) => char.charCodeAt(0)))
  }
} as any

global.TextDecoder = class MockTextDecoder {
  decode(input: Uint8Array): string {
    return String.fromCharCode(...Array.from(input))
  }
} as any
