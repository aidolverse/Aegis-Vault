import { describe, it, expect, vi, beforeEach } from "vitest"
import { cryptoService } from "../CryptoService"
import type { Principal } from "@dfinity/principal"

// Mock crypto-js
vi.mock("crypto-js", () => ({
  default: {
    AES: {
      encrypt: vi.fn((data, key) => ({ toString: () => `encrypted-${data}-${key}` })),
      decrypt: vi.fn((data, key) => ({ toString: () => `decrypted-${data}-${key}` })),
    },
    SHA256: vi.fn((data) => ({ toString: () => `hash-${data}` })),
    PBKDF2: vi.fn((password, salt, options) => ({ toString: () => `pbkdf2-${password}-${salt}` })),
    enc: {
      Utf8: "utf8",
    },
    lib: {
      WordArray: {
        random: vi.fn((length) => ({ toString: () => `random-${length}` })),
      },
    },
  },
}))

describe("CryptoService", () => {
  let mockPrincipal: Principal

  beforeEach(() => {
    vi.clearAllMocks()
    mockPrincipal = { toString: () => "test-principal" } as Principal
  })

  describe("encryptFile", () => {
    it("should encrypt file successfully", async () => {
      const mockFile = new File(["test content"], "test.csv", { type: "text/csv" })

      // Mock FileReader
      const mockFileReader = {
        onload: null as any,
        onerror: null as any,
        readAsText: vi.fn(),
        result: "test content",
      }

      global.FileReader = vi.fn(() => mockFileReader) as any

      const encryptPromise = cryptoService.encryptFile(mockFile, mockPrincipal)

      // Simulate FileReader onload
      setTimeout(() => {
        mockFileReader.onload({ target: { result: "test content" } })
      }, 0)

      const result = await encryptPromise

      expect(result).toHaveProperty("encryptedData")
      expect(result).toHaveProperty("checksum")
      expect(result).toHaveProperty("metadata")
      expect(result.metadata).toHaveProperty("algorithm", "AES")
      expect(result.metadata).toHaveProperty("originalSize", 12)
    })

    it("should handle file read errors", async () => {
      const mockFile = new File(["test content"], "test.csv", { type: "text/csv" })

      const mockFileReader = {
        onload: null as any,
        onerror: null as any,
        readAsText: vi.fn(),
      }

      global.FileReader = vi.fn(() => mockFileReader) as any

      const encryptPromise = cryptoService.encryptFile(mockFile, mockPrincipal)

      // Simulate FileReader onerror
      setTimeout(() => {
        mockFileReader.onerror()
      }, 0)

      await expect(encryptPromise).rejects.toThrow("Failed to read file")
    })
  })

  describe("decryptData", () => {
    it("should decrypt data successfully", async () => {
      const encryptedData = new TextEncoder().encode("encrypted-data")
      const expectedChecksum = "hash-encrypted-data"

      const result = await cryptoService.decryptData(encryptedData, mockPrincipal, expectedChecksum)

      expect(result).toHaveProperty("data")
      expect(result).toHaveProperty("verified", true)
      expect(result).toHaveProperty("metadata")
    })

    it("should fail on integrity check failure", async () => {
      const encryptedData = new TextEncoder().encode("encrypted-data")
      const wrongChecksum = "wrong-checksum"

      await expect(cryptoService.decryptData(encryptedData, mockPrincipal, wrongChecksum)).rejects.toThrow(
        "Data integrity check failed",
      )
    })
  })

  describe("parseCSV", () => {
    it("should parse valid CSV data", () => {
      const csvContent = "Date,Category,Amount\n2023-01-01,Food,50.00\n2023-01-02,Transport,25.50"

      const result = cryptoService.parseCSV(csvContent)

      expect(result).toHaveLength(2)
      expect(result[0]).toEqual({
        date: "2023-01-01",
        category: "Food",
        amount: 50.0,
      })
      expect(result[1]).toEqual({
        date: "2023-01-02",
        category: "Transport",
        amount: 25.5,
      })
    })

    it("should handle CSV without headers", () => {
      const csvContent = "2023-01-01,Food,50.00\n2023-01-02,Transport,25.50"

      const result = cryptoService.parseCSV(csvContent)

      expect(result).toHaveLength(2)
    })

    it("should handle malformed CSV data", () => {
      const csvContent = "Date,Category,Amount\n2023-01-01,Food\n2023-01-02,Transport,invalid-amount"

      const result = cryptoService.parseCSV(csvContent)

      expect(result).toHaveLength(0) // Should filter out invalid rows
    })

    it("should handle empty CSV", () => {
      const csvContent = ""

      const result = cryptoService.parseCSV(csvContent)

      expect(result).toHaveLength(0)
    })
  })

  describe("analyzeSpendingData", () => {
    const testData = [
      { date: "2023-01-01", category: "Food", amount: 60.0 },
      { date: "2023-01-02", category: "Food", amount: 40.0 },
      { date: "2023-01-03", category: "Transport", amount: 30.0 },
    ]

    it("should return true when average spending exceeds threshold", () => {
      const result = cryptoService.analyzeSpendingData(testData, "Food", 45.0)
      expect(result).toBe(true) // Average food spending is 50, which > 45
    })

    it("should return false when average spending is below threshold", () => {
      const result = cryptoService.analyzeSpendingData(testData, "Food", 55.0)
      expect(result).toBe(false) // Average food spending is 50, which < 55
    })

    it("should return false for non-existent category", () => {
      const result = cryptoService.analyzeSpendingData(testData, "Entertainment", 10.0)
      expect(result).toBe(false)
    })

    it("should handle empty data", () => {
      const result = cryptoService.analyzeSpendingData([], "Food", 50.0)
      expect(result).toBe(false)
    })
  })

  describe("utility functions", () => {
    it("should generate secure random data", () => {
      const result = cryptoService.generateSecureRandom(16)
      expect(result).toBe("random-16")
    })

    it("should hash data correctly", () => {
      const result = cryptoService.hashData("test data")
      expect(result).toBe("hash-test data")
    })

    it("should verify data integrity", () => {
      const data = "test data"
      const hash = "hash-test data"

      const result = cryptoService.verifyIntegrity(data, hash)
      expect(result).toBe(true)
    })

    it("should detect integrity violations", () => {
      const data = "test data"
      const wrongHash = "wrong-hash"

      const result = cryptoService.verifyIntegrity(data, wrongHash)
      expect(result).toBe(false)
    })
  })
})
