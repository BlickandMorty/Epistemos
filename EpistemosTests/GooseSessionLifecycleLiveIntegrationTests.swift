import Foundation
import Testing
@testable import Epistemos

@Suite("Goose session lifecycle live integration", .serialized)
struct GooseSessionLifecycleLiveIntegrationTests {
    @Test(
        "live Goose serve lists, loads, and forks sessions through ACP"
    )
    @MainActor
    func liveGooseServeListsLoadsAndForksSessionsThroughACP() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-acp-session-lifecycle.log")
        try? FileManager.default.removeItem(at: proofURL)

        try await withLiveGooseACPClient(proofName: "acp-session-lifecycle") { binary, connection, client, progressURL in
            let repoPath = liveRepoRootURL().path
            let session = try await initializeLiveDesktopSession(
                client: client,
                cwd: repoPath,
                progressURL: progressURL
            )

            appendLiveProgress("before session/list", to: progressURL)
            let list = try await withLiveTimeout(
                seconds: 20,
                description: "ACP session/list response",
                onTimeout: { await client.close() },
                operation: {
                    try await client.listSessions(
                        metadata: ["types": .array([.string("user"), .string("scheduled")])]
                    )
                }
            )
            let initialListedSessionIDs = Set(list.sessions.map(\.sessionId))

            appendLiveProgress("before session/prompt persistence probe", to: progressURL)
            let promptResponse = try await withLiveTimeout(
                seconds: 90,
                description: "ACP session/prompt persistence response",
                onTimeout: { await client.close() },
                operation: {
                    try await client.prompt(
                        sessionId: session.sessionId,
                        text: "Reply with exactly this phrase and no markdown: phase0 session lifecycle ready"
                    )
                }
            )

            appendLiveProgress("before persisted session/list", to: progressURL)
            let persistedList = try await listSessionsIncluding(
                sessionId: session.sessionId,
                client: client,
                progressURL: progressURL
            )
            let persistedListedSessionIDs = Set(persistedList.sessions.map(\.sessionId))

            appendLiveProgress("before session/info", to: progressURL)
            let sessionInfo = try await withLiveTimeout(
                seconds: 20,
                description: "ACP session/info response",
                onTimeout: { await client.close() },
                operation: {
                    try await client.readGooseSessionInfo(sessionId: session.sessionId)
                }
            )
            // Raw value drives the honest proof breadcrumb; loadCWD keeps a non-nil
            // fallback only because load/fork require a cwd argument.
            let sessionInfoCWD = stringValue(for: "cwd", in: sessionInfo.session)
            let loadCWD = sessionInfoCWD ?? repoPath

            appendLiveProgress("before session/load", to: progressURL)
            let load = try await withLiveTimeout(
                seconds: 20,
                description: "ACP session/load response",
                onTimeout: { await client.close() },
                operation: {
                    try await client.loadSession(
                        sessionId: session.sessionId,
                        cwd: loadCWD
                    )
                }
            )

            appendLiveProgress("before session/fork", to: progressURL)
            let fork = try await withLiveTimeout(
                seconds: 20,
                description: "ACP session/fork response",
                onTimeout: { await client.close() },
                operation: {
                    try await client.forkSession(
                        sessionId: session.sessionId,
                        cwd: loadCWD
                    )
                }
            )

            guard promptResponse.stopReason == .endTurn else {
                throw GooseLiveIntegrationError.runtimeFailed("Session persistence prompt stopped with \(promptResponse.stopReason.rawValue), not end_turn.")
            }
            guard persistedListedSessionIDs.contains(session.sessionId) else {
                throw GooseLiveIntegrationError.runtimeFailed("session/list did not include the prompted ACP session.")
            }
            guard !fork.sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw GooseLiveIntegrationError.runtimeFailed("session/fork returned an empty fork session id.")
            }
            guard fork.sessionId != session.sessionId else {
                throw GooseLiveIntegrationError.runtimeFailed("session/fork returned the original session id.")
            }

            let proof = [
                "phase0_live_acp_session_lifecycle=pass",
                "goose_binary=\(binary.lastPathComponent)",
                "goose_base_url=\(connection.baseURL.absoluteString)",
                "session_id=\(session.sessionId)",
                "initial_listed_count=\(list.sessions.count)",
                "initial_listed_empty_session=\(initialListedSessionIDs.contains(session.sessionId))",
                "prompt_stop_reason=\(promptResponse.stopReason.rawValue)",
                "persisted_listed_count=\(persistedList.sessions.count)",
                "persisted_listed_session=\(persistedListedSessionIDs.contains(session.sessionId))",
                "session_info_cwd_matches_repo=\(sessionInfoCWD == repoPath)",
                "load_has_modes=\(load.modes != nil)",
                "load_has_models=\(load.models != nil)",
                "load_has_config_options=\(load.configOptions != nil)",
                "fork_session_id=\(fork.sessionId)",
                "fork_differs_from_original=\(fork.sessionId != session.sessionId)",
            ].joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_acp_session_lifecycle=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live ACP session lifecycle proof log was not written.")
            }
            try GoosePhase0CapabilityMatrix.record(
                [.sessionsListResumeFork],
                proofURL: proofURL,
                via: "goose serve ACP session/list+load+fork",
                details: ["fork_session_id": fork.sessionId]
            )
        }
    }
}

private func initializeLiveDesktopSession(
    client: GooseACPClient,
    cwd: String,
    progressURL: URL
) async throws -> GooseACPNewSessionResponse {
    appendLiveProgress("before initialize", to: progressURL)
    _ = try await withLiveTimeout(
        seconds: 12,
        description: "ACP initialize response",
        onTimeout: { await client.close() },
        operation: { try await client.initialize() }
    )

    appendLiveProgress("before desktop-compatible session/new", to: progressURL)
    let session = try await withLiveTimeout(
        seconds: 12,
        description: "ACP desktop-compatible session/new response",
        onTimeout: { await client.close() },
        operation: {
            try await client.newSession(
                cwd: cwd,
                metadata: [
                    "client": .string("goose-desktop"),
                    "compatibilityClient": .string("goose-desktop"),
                    "appName": .string("Epistemos"),
                    "brand": .string("epistemos"),
                ]
            )
        }
    )
    appendLiveProgress("session id=\(session.sessionId)", to: progressURL)
    return session
}

private func listSessionsIncluding(
    sessionId: String,
    client: GooseACPClient,
    progressURL: URL
) async throws -> GooseACPListSessionsResponse {
    var lastList: GooseACPListSessionsResponse?
    for attempt in 0..<30 {
        let list = try await withLiveTimeout(
            seconds: 20,
            description: "ACP persisted session/list response",
            onTimeout: { await client.close() },
            operation: {
                try await client.listSessions(
                    metadata: ["types": .array([.string("user"), .string("scheduled")])]
                )
            }
        )
        lastList = list
        let containsSession = list.sessions.contains { $0.sessionId == sessionId }
        if attempt % 5 == 0 || containsSession {
            appendLiveProgress(
                "persisted session/list attempt=\(attempt) count=\(list.sessions.count) contains=\(containsSession)",
                to: progressURL
            )
        }
        if containsSession {
            return list
        }
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    return lastList ?? GooseACPListSessionsResponse(sessions: [], nextCursor: nil, metadata: nil)
}

private func stringValue(for key: String, in value: JSONValue) -> String? {
    guard case .object(let object) = value,
          case .string(let string)? = object[key] else {
        return nil
    }
    return string
}
