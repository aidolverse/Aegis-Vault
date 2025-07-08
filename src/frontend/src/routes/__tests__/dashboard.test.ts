import { describe, it, expect, vi, beforeEach } from "vitest"
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte"
import Dashboard from "../dashboard/+page.svelte"
import { authService } from "$lib/services/AuthService"
import { actorService } from "$lib/services/ActorService"
import { cryptoService } from "$lib/services/CryptoService"

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
  principal: {
    subscribe: vi.fn((callback) => {
      callback({ toString: () => "test-principal-id" })
      return () => {}
    }),
  },
  authError: {
    subscribe: vi.fn((callback) => {
      callback(null)
      return () => {}
    }),
  },
  authLoading: {
    subscribe: vi.fn((callback) => {
      callback(false)
      return () => {}
    }),
  },
}))

vi.mock("$lib/services/ActorService", () => ({
  actorService: {
    createUserVaultActor: vi.fn(),
    performHealthCheck: vi.fn(),
  },
}))

vi.mock("$lib/services/CryptoService", () => ({
  cryptoService: {
    encryptFile: vi.fn(),
  },
}))

vi.mock("$app/navigation", () => ({
  goto: vi.fn(),
}))

describe("Dashboard Component", () => {
  let mockUserVaultActor: any

  beforeEach(() => {
    vi.clearAllMocks()

    mockUserVaultActor = {
      getVaultStats: vi.fn().mockResolvedValue({
        ok: {
          owner: { toString: () => "test-principal" },
          dataEntries: 2,
          totalQueries: 5,
          approvedQueries: 3,
          rejectedQueries: 2,
          lastActivity: Date.now() * 1_000_000,
          vaultVersion: 1,
        },
      }),
      getPendingQueries: vi.fn().mockResolvedValue({ ok: [] }),
      getAccessLogs: vi.fn().mockResolvedValue({ ok: [] }),
      uploadData: vi.fn().mockResolvedValue({ ok: 1 }),
      approveRequest: vi.fn().mockResolvedValue({ ok: true }),
      rejectRequest: vi.fn().mockResolvedValue({ ok: "Request rejected" }),
    }

    vi.mocked(actorService.createUserVaultActor).mockResolvedValue(mockUserVaultActor)
    vi.mocked(actorService.performHealthCheck).mockResolvedValue({
      aggregator: { status: "healthy" },
      userVault: { status: "healthy" },
      agent: true,
    })
  })

  it("should render dashboard with vault statistics", async () => {
    render(Dashboard)

    await waitFor(() => {
      expect(screen.getByText("Aegis Vault Dashboard")).toBeInTheDocument()
      expect(screen.getByText("Vault Statistics")).toBeInTheDocument()
    })

    // Check if statistics are displayed
    await waitFor(() => {
      expect(screen.getByText("2")).toBeInTheDocument() // Data entries
      expect(screen.getByText("3")).toBeInTheDocument() // Approved queries
      expect(screen.getByText("2")).toBeInTheDocument() // Rejected queries
      expect(screen.getByText("5")).toBeInTheDocument() // Total queries
    })
  })

  it("should handle file upload", async () => {
    const mockFile = new File(["test,data,content"], "test.csv", { type: "text/csv" })

    vi.mocked(cryptoService.encryptFile).mockResolvedValue({
      encryptedData: new Uint8Array([1, 2, 3]),
      checksum: "test-checksum",
      metadata: {
        algorithm: "AES",
        keyDerivation: "PBKDF2",
        timestamp: Date.now(),
        originalSize: 100,
      },
    })

    render(Dashboard)

    const fileInput = screen.getByRole("textbox", { hidden: true }) as HTMLInputElement
    const uploadButton = screen.getByText("Upload Data")

    // Simulate file selection
    Object.defineProperty(fileInput, "files", {
      value: [mockFile],
      writable: false,
    })

    fireEvent.change(fileInput)
    fireEvent.click(uploadButton)

    await waitFor(() => {
      expect(cryptoService.encryptFile).toHaveBeenCalledWith(mockFile, expect.any(Object))
      expect(mockUserVaultActor.uploadData).toHaveBeenCalled()
    })
  })

  it("should handle query approval", async () => {
    const mockPendingQuery = {
      id: 1,
      recipeId: 1,
      description: "Test query",
      timestamp: Date.now() * 1_000_000,
      requester: { toString: () => "test-requester" },
      status: { active: null },
      expiresAt: (Date.now() + 86400000) * 1_000_000,
    }

    mockUserVaultActor.getPendingQueries.mockResolvedValue({ ok: [mockPendingQuery] })

    render(Dashboard)

    await waitFor(() => {
      expect(screen.getByText("Pending Research Queries")).toBeInTheDocument()
      expect(screen.getByText("Test query")).toBeInTheDocument()
    })

    const approveButton = screen.getByText("Approve")
    fireEvent.click(approveButton)

    await waitFor(() => {
      expect(mockUserVaultActor.approveRequest).toHaveBeenCalledWith(1)
    })
  })

  it("should handle query rejection", async () => {
    const mockPendingQuery = {
      id: 2,
      recipeId: 1,
      description: "Test query for rejection",
      timestamp: Date.now() * 1_000_000,
      requester: { toString: () => "test-requester" },
      status: { active: null },
      expiresAt: (Date.now() + 86400000) * 1_000_000,
    }

    mockUserVaultActor.getPendingQueries.mockResolvedValue({ ok: [mockPendingQuery] })

    render(Dashboard)

    await waitFor(() => {
      expect(screen.getByText("Test query for rejection")).toBeInTheDocument()
    })

    const rejectButton = screen.getByText("Reject")
    fireEvent.click(rejectButton)

    await waitFor(() => {
      expect(mockUserVaultActor.rejectRequest).toHaveBeenCalledWith(2)
    })
  })

  it("should handle logout", async () => {
    render(Dashboard)

    const logoutButton = screen.getByText("Logout")
    fireEvent.click(logoutButton)

    expect(authService.logout).toHaveBeenCalled()
  })

  it("should display error messages", async () => {
    mockUserVaultActor.getVaultStats.mockResolvedValue({ err: "Failed to load stats" })

    render(Dashboard)

    await waitFor(() => {
      expect(screen.getByText("Failed to load dashboard data")).toBeInTheDocument()
    })
  })

  it("should toggle advanced view", async () => {
    render(Dashboard)

    const toggleButton = screen.getByText("Show Advanced")
    fireEvent.click(toggleButton)

    await waitFor(() => {
      expect(screen.getByText("Hide Advanced")).toBeInTheDocument()
    })
  })
})
