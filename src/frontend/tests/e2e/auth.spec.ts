import { test, expect } from "@playwright/test"

test.describe("Authentication Flow", () => {
  test("should display login page", async ({ page }) => {
    await page.goto("/")

    await expect(page.getByText("Aegis Vault")).toBeVisible()
    await expect(page.getByText("Secure decentralized data analytics platform")).toBeVisible()
    await expect(page.getByRole("button", { name: "Login with Internet Identity" })).toBeVisible()
  })

  test("should handle login button click", async ({ page }) => {
    await page.goto("/")

    const loginButton = page.getByRole("button", { name: "Login with Internet Identity" })
    await loginButton.click()

    // Should show loading state
    await expect(page.getByText("Connecting...")).toBeVisible()
  })

  test("should redirect to dashboard after successful login", async ({ page }) => {
    // Mock successful authentication
    await page.addInitScript(() => {
      window.localStorage.setItem("aegis-vault-auth", "true")
    })

    await page.goto("/")

    // Should redirect to dashboard
    await expect(page).toHaveURL("/dashboard")
  })
})
