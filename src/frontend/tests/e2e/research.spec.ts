import { test, expect } from "@playwright/test"

test.describe("Research Portal", () => {
  test.beforeEach(async ({ page }) => {
    // Mock authentication
    await page.addInitScript(() => {
      window.localStorage.setItem("aegis-vault-auth", "true")
    })

    await page.goto("/research")
  })

  test("should display research portal", async ({ page }) => {
    await expect(page.getByText("Research Portal")).toBeVisible()
    await expect(page.getByText("Submit Research Query")).toBeVisible()
    await expect(page.getByText("Privacy-Preserving Research")).toBeVisible()
  })

  test("should submit research query", async ({ page }) => {
    const querySelect = page.locator("select")
    const submitButton = page.getByRole("button", { name: "Submit Query" })

    await querySelect.selectOption("1")
    await submitButton.click()

    // Should show submission confirmation
    await expect(page.getByText(/Query submitted|Waiting for user approvals/)).toBeVisible()
  })

  test("should display query results", async ({ page }) => {
    // Mock query results
    await page.addInitScript(() => {
      window.localStorage.setItem(
        "aegis-vault-query-results",
        JSON.stringify({
          queryId: 123,
          trueCount: 3,
          falseCount: 2,
          totalResponses: 5,
          percentage: 60,
        }),
      )
    })

    await page.reload()

    await expect(page.getByText("Query Results")).toBeVisible()
    await expect(page.getByText("60%")).toBeVisible()
  })
})
