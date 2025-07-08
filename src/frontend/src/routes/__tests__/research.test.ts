import { describe, it, expect, vi, beforeEach } from "vitest"
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte"
import Research from "../research/+page.svelte"
import { actorService } from "$lib/services/ActorService"

// Mock services
vi.mock("$lib/services/AuthService", () => ({
  authService: {
    logout: vi.fn(),
  },
  isAuthenticated: {
    subscribe: vi.fn((callback) => {
      callback(true)
      return () => {}
    }),
  },
}))

vi.mock("$lib/services/ActorService", () => ({
  actorService: {
    createAggregatorActor: vi.fn(),
  },
}))

vi.mock("$app/navigation", () => ({
  goto: vi.fn(),
}))

describe("Research Component", () => {
  let mockAggregatorActor: any

  beforeEach(() => {
    vi.clearAllMocks()

    mockAggregatorActor = {
      getAnalysisRecipes: vi.fn().mockResolvedValue([
        {
          id: 1,
          name: "Food Spending Analysis",
          description: "Analisis: Persentase pengguna dengan pengeluaran Makanan > $50",
          category: "spending",
          parameters: [
            ["category", "Makanan"],
            ["threshold", "50"],
          ],
        },
        {
          id: 2,
          name: "Transportation Budget",
          description: "Analisis: Pengguna dengan pengeluaran transportasi > $100",
          category: "spending",
          parameters: [
            ["category", "Transportasi"],
            ["threshold", "100"],
          ],
        },
      ]),
      submitQuery: vi.fn().mockResolvedValue({ ok: 123 }),
      getQueryResults: vi.fn().mockResolvedValue({
        ok: {
          queryId: 123,
          trueCount: 3,
          falseCount: 2,
          totalResponses: 5,
          participationRate: 1.0,
          completedAt: Date.now() * 1_000_000,
        },
      }),
    }

    vi.mocked(actorService.createAggregatorActor).mockResolvedValue(mockAggregatorActor)
  })

  it("should render research portal with available queries", async () => {
    render(Research)

    await waitFor(() => {
      expect(screen.getByText("Research Portal")).toBeInTheDocument()
      expect(screen.getByText("Submit Research Query")).toBeInTheDocument()
    })

    // Check if analysis recipes are loaded
    await waitFor(() => {
      expect(screen.getByText("Food Spending Analysis")).toBeInTheDocument()
      expect(screen.getByText("Transportation Budget")).toBeInTheDocument()
    })
  })

  it("should submit query successfully", async () => {
    render(Research)

    await waitFor(() => {
      expect(screen.getByText("Food Spending Analysis")).toBeInTheDocument()
    })

    // Select a query
    const querySelect = screen.getByRole("combobox")
    fireEvent.change(querySelect, { target: { value: "1" } })

    // Submit query
    const submitButton = screen.getByText("Submit Query")
    fireEvent.click(submitButton)

    await waitFor(() => {
      expect(mockAggregatorActor.submitQuery).toHaveBeenCalledWith(1)
    })
  })

  it("should display query results", async () => {
    render(Research)

    // Select and submit query
    await waitFor(() => {
      expect(screen.getByText("Food Spending Analysis")).toBeInTheDocument()
    })

    const querySelect = screen.getByRole("combobox")
    fireEvent.change(querySelect, { target: { value: "1" } })

    const submitButton = screen.getByText("Submit Query")
    fireEvent.click(submitButton)

    // Wait for results to appear
    await waitFor(() => {
      expect(screen.getByText("Query Results")).toBeInTheDocument()
      expect(screen.getByText("3")).toBeInTheDocument() // True count
      expect(screen.getByText("2")).toBeInTheDocument() // False count
      expect(screen.getByText("60%")).toBeInTheDocument() // Percentage
    })
  })

  it("should handle query submission errors", async () => {
    mockAggregatorActor.submitQuery.mockResolvedValue({ err: "Query submission failed" })

    render(Research)

    await waitFor(() => {
      expect(screen.getByText("Food Spending Analysis")).toBeInTheDocument()
    })

    const querySelect = screen.getByRole("combobox")
    fireEvent.change(querySelect, { target: { value: "1" } })

    const submitButton = screen.getByText("Submit Query")
    fireEvent.click(submitButton)

    await waitFor(() => {
      expect(screen.getByText(/Failed to submit query/)).toBeInTheDocument()
    })
  })

  it("should prevent submission without query selection", async () => {
    render(Research)

    const submitButton = screen.getByText("Submit Query")
    fireEvent.click(submitButton)

    await waitFor(() => {
      expect(screen.getByText("Please select a query")).toBeInTheDocument()
    })

    expect(mockAggregatorActor.submitQuery).not.toHaveBeenCalled()
  })
})
