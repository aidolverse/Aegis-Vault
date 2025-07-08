import CryptoJS from "crypto-js"
import type { Principal } from "@dfinity/principal"

interface EncryptionResult {
  encryptedData: Uint8Array
  checksum: string
  metadata: {
    algorithm: string
    keyDerivation: string
    timestamp: number
    originalSize: number
  }
}

interface DecryptionResult {
  data: string
  verified: boolean
  metadata: {
    algorithm: string
    timestamp: number
    originalSize: number
  }
}

class CryptoService {
  private readonly algorithm = "AES"
  private readonly keyDerivationRounds = 10000

  // Enhanced encryption with metadata and integrity checking
  async encryptFile(file: File, userPrincipal: Principal): Promise<EncryptionResult> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()

      reader.onload = async (event) => {
        try {
          const fileContent = event.target?.result as string
          const timestamp = Date.now()

          // Generate user-specific encryption key
          const encryptionKey = this.deriveKey(userPrincipal.toString(), timestamp)

          // Create metadata
          const metadata = {
            algorithm: this.algorithm,
            keyDerivation: "PBKDF2",
            timestamp,
            originalSize: fileContent.length,
          }

          // Encrypt the content
          const encrypted = CryptoJS.AES.encrypt(
            JSON.stringify({ content: fileContent, metadata }),
            encryptionKey,
          ).toString()

          // Generate checksum for integrity verification
          const checksum = CryptoJS.SHA256(encrypted).toString()

          // Convert to Uint8Array
          const uint8Array = new TextEncoder().encode(encrypted)

          resolve({
            encryptedData: uint8Array,
            checksum,
            metadata,
          })
        } catch (error) {
          reject(new Error(`Encryption failed: ${error}`))
        }
      }

      reader.onerror = () => reject(new Error("Failed to read file"))
      reader.readAsText(file)
    })
  }

  // Enhanced decryption with integrity verification
  async decryptData(
    encryptedData: Uint8Array,
    userPrincipal: Principal,
    expectedChecksum: string,
  ): Promise<DecryptionResult> {
    try {
      const encryptedString = new TextDecoder().decode(encryptedData)

      // Verify integrity
      const actualChecksum = CryptoJS.SHA256(encryptedString).toString()
      const verified = actualChecksum === expectedChecksum

      if (!verified) {
        throw new Error("Data integrity check failed")
      }

      // Try to decrypt with different possible keys (for backward compatibility)
      const possibleKeys = this.generatePossibleKeys(userPrincipal.toString())

      for (const key of possibleKeys) {
        try {
          const decrypted = CryptoJS.AES.decrypt(encryptedString, key)
          const decryptedString = decrypted.toString(CryptoJS.enc.Utf8)

          if (decryptedString) {
            const parsed = JSON.parse(decryptedString)
            return {
              data: parsed.content,
              verified,
              metadata: parsed.metadata || {
                algorithm: this.algorithm,
                timestamp: Date.now(),
                originalSize: parsed.content.length,
              },
            }
          }
        } catch (keyError) {
          // Try next key
          continue
        }
      }

      throw new Error("Failed to decrypt data with any available key")
    } catch (error) {
      throw new Error(`Decryption failed: ${error}`)
    }
  }

  // Enhanced key derivation with user-specific salt
  private deriveKey(principalId: string, timestamp?: number): string {
    const salt = this.generateSalt(principalId)
    const baseKey = principalId + (timestamp ? timestamp.toString() : "")

    return CryptoJS.PBKDF2(baseKey, salt, {
      keySize: 256 / 32,
      iterations: this.keyDerivationRounds,
    }).toString()
  }

  // Generate multiple possible keys for backward compatibility
  private generatePossibleKeys(principalId: string): string[] {
    const keys = []

    // Current key derivation method
    keys.push(this.deriveKey(principalId))

    // Legacy key derivation (for backward compatibility)
    keys.push(CryptoJS.SHA256(principalId + "aegis-vault-secret-key").toString())

    // Time-based keys (last 24 hours)
    const now = Date.now()
    const dayInMs = 24 * 60 * 60 * 1000
    for (let i = 0; i < 24; i++) {
      const timestamp = now - i * 60 * 60 * 1000 // Each hour
      keys.push(this.deriveKey(principalId, timestamp))
    }

    return keys
  }

  private generateSalt(principalId: string): string {
    return CryptoJS.SHA256("aegis-vault-salt-" + principalId)
      .toString()
      .substring(0, 16)
  }

  // Utility function to generate secure random data
  generateSecureRandom(length: number): string {
    return CryptoJS.lib.WordArray.random(length).toString()
  }

  // Hash function for data integrity
  hashData(data: string): string {
    return CryptoJS.SHA256(data).toString()
  }

  // Verify data integrity
  verifyIntegrity(data: string, expectedHash: string): boolean {
    const actualHash = this.hashData(data)
    return actualHash === expectedHash
  }

  // Enhanced CSV parsing with validation
  parseCSV(csvContent: string): Array<{ date: string; category: string; amount: number }> {
    try {
      const lines = csvContent.split("\n").filter((line) => line.trim())
      const data = []

      // Skip header if present
      const startIndex = lines[0].toLowerCase().includes("date") ? 1 : 0

      for (let i = startIndex; i < lines.length; i++) {
        const line = lines[i].trim()
        if (!line) continue

        const columns = line.split(",").map((col) => col.trim().replace(/"/g, ""))

        if (columns.length >= 3) {
          const [date, category, amountStr] = columns
          const amount = Number.parseFloat(amountStr.replace(/[^0-9.-]/g, ""))

          if (!isNaN(amount)) {
            data.push({
              date: date,
              category: category,
              amount: amount,
            })
          }
        }
      }

      return data
    } catch (error) {
      throw new Error(`CSV parsing failed: ${error}`)
    }
  }

  // Analyze spending data for queries
  analyzeSpendingData(
    data: Array<{ date: string; category: string; amount: number }>,
    category: string,
    threshold: number,
  ): boolean {
    try {
      const categoryData = data.filter((item) => item.category.toLowerCase().includes(category.toLowerCase()))

      if (categoryData.length === 0) return false

      const totalSpending = categoryData.reduce((sum, item) => sum + item.amount, 0)
      const averageSpending = totalSpending / categoryData.length

      return averageSpending > threshold
    } catch (error) {
      console.error("Analysis failed:", error)
      return false
    }
  }
}

export const cryptoService = new CryptoService()
