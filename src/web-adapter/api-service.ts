// Adapter untuk backend tradisional
class WebApiService {
  private baseUrl = process.env.VITE_API_BASE_URL || "http://localhost:3000/api"

  async login(credentials: { email: string; password: string }) {
    const response = await fetch(`${this.baseUrl}/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(credentials),
    })
    return response.json()
  }

  async uploadData(file: File) {
    const formData = new FormData()
    formData.append("file", file)

    const response = await fetch(`${this.baseUrl}/data/upload`, {
      method: "POST",
      body: formData,
    })
    return response.json()
  }

  async getVaultStats() {
    const response = await fetch(`${this.baseUrl}/vault/stats`)
    return response.json()
  }

  async submitQuery(queryId: number) {
    const response = await fetch(`${this.baseUrl}/queries/submit`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ queryId }),
    })
    return response.json()
  }
}

export const webApiService = new WebApiService()
