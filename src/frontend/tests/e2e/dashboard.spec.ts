import { test, expect } from "@playwright/test"

test.describe("Dashboard Functionality", () => {
  test.beforeEach(async ({ page }) => {
    // Mock authentication
    await page.addInitScript(() => {
      window.localStorage.setItem("aegis-vault-auth", "true")
    })

    await page.goto("/dashboard")
  })

  test("should display dashboard elements", async ({ page }) => {
    await expect(page.getByText("Aegis Vault Dashboard")).toBeVisible()
    await expect(page.getByText("Vault Statistics")).toBeVisible()
    await expect(page.getByText("Upload CSV Data")).toBeVisible()
  })

  test("should handle file upload", async ({ page }) => {
    const fileInput = page.locator('input[type="file"]')
    const uploadButton = page.getByRole("button", { name: "Upload Data" })

    // Create a test CSV file
    const csvContent = "Date,Category,Amount\n2023-01-01,Food,50.00\n2023-01-02,Transport,25.50"
    const buffer = Buffer.from(csvContent)

    await fileInput.setInputFiles({
      name: "test-data.csv",
      mimeType: "text/csv",
      buffer: buffer,
    })

    await uploadButton.click()

    // Should show upload progress or success message
    await expect(page.getByText(/Encrypting & Uploading|Data uploaded successfully/)).toBeVisible()
  })

  test("should toggle advanced view", async ({ page }) => {
    const toggleButton = page.getByText("Show Advanced")
    await toggleButton.click()

    await expect(page.getByText("Hide Advanced")).toBeVisible()
    await expect(page.getByText("Recent Activity")).toBeVisible()
  })

  test("should handle logout", async ({ page }) => {
    const logoutButton = page.getByRole("button", { name: "Logout" })
    await logoutButton.click()

    // Should redirect to login page
    await expect(page).toHaveURL("/")
  })
})
