import Foundation

// W-R2/W-R3 option-B provisioning (recipe RUNTIME-PROVEN 2026-06-24 against the live worker): after the OpenWork
// worker is up, register the app-hosted native MCP (`epistemos-native`) with the worker's managed OpenCode over its
// HTTP API, so the OpenCode agent can call the FULL native Epistemos tool surface (computer use, browser, …) — not
// just the vault MCP.
//
// WHY HTTP (not config files / env): the worker spawns its OWN managed OpenCode and builds that engine's config
// from its per-workspace RUNTIME DB; it OVERRIDES `OPENCODE_CONFIG`, so neither an env var nor a workspace
// `opencode.json` we pre-write can reach it. The supported path is the donor's `POST /workspace/:id/mcp` →
// `addMcp` → runtime DB → the managed OpenCode picks it up. Auth = the worker's own per-launch token (collaborator
// scope — the same credential the SPA uses); writes are auto-approved because the worker is launched with
// `--approval auto` (see `WorkOpenWorkSupervisor.workerArguments`). Both facts verified end-to-end with curl.
//
// Best-effort + NON-FATAL by design: a failure leaves the agent with the vault MCP only (honest degrade) and never
// blocks the Work surface. The worker BLOCKS the POST until it connects the new MCP url, so callers MUST have the
// native server already listening before calling; the registration write lands in the runtime DB BEFORE that
// engine sync, so even a connect-timeout is non-fatal (the row persists and is consumed on the next engine build).
enum WorkOpenWorkProvisioner {
    /// Register `epistemos-native` for the worker's vault workspace. Returns true only on a confirmed HTTP 2xx.
    nonisolated static func registerNativeMCP(
        workerBaseURL: URL,
        workerToken: String,
        workspacePath: String,
        nativeURL: String,
        nativeToken: String,
        session: URLSession = .shared
    ) async -> Bool {
        guard let workspaceID = await discoverWorkspaceID(
            workerBaseURL: workerBaseURL, workerToken: workerToken,
            workspacePath: workspacePath, session: session) else { return false }
        guard let body = WorkOpenWorkSupervisor.nativeMCPRegistrationBody(url: nativeURL, token: nativeToken)
        else { return false }

        let endpoint = workerBaseURL
            .appending(path: "workspace").appending(path: workspaceID).appending(path: "mcp")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(workerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        // Cap the wait so a slow engine-sync can't hang the surface. The native server should already be listening
        // (caller's responsibility) so this returns quickly in practice.
        request.timeoutInterval = 6

        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }

    /// `GET <worker>/workspaces` (Bearer worker token) → the `id` of the workspace whose `path` matches the vault.
    nonisolated static func discoverWorkspaceID(
        workerBaseURL: URL,
        workerToken: String,
        workspacePath: String,
        session: URLSession = .shared
    ) async -> String? {
        var request = URLRequest(url: workerBaseURL.appending(path: "workspaces"))
        request.setValue("Bearer \(workerToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 6
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return WorkOpenWorkSupervisor.workspaceID(fromWorkspacesJSON: data, matchingPath: workspacePath)
    }

    /// Mini-session live binding (increment 6b): fetch the worker's sessions for a workspace and map them to native
    /// `[WorkSession]` (via `WorkSessionMapper`). Best-effort + non-fatal: returns `[]` on any failure (the rail
    /// just shows nothing rather than erroring). Callers feed the result into `WorkSessionStore.upsert`.
    nonisolated static func fetchWorkSessions(
        workerBaseURL: URL,
        workerToken: String,
        workspaceID: String,
        session: URLSession = .shared
    ) async -> [WorkSession] {
        let endpoint = workerBaseURL.appending(path: "workspace").appending(path: workspaceID).appending(path: "sessions")
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(workerToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 6
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
        return WorkSessionMapper.workSessions(fromSessionsJSON: data, workspaceID: workspaceID)
    }
}
