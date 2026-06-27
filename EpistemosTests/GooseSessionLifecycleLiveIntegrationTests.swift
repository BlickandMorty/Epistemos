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
            let session = try await initializeLiveSession(client: client, progressURL: progressURL)
            let repoPath = liveRepoRootURL().path

            appendLiveProgress("before session/list", to: progressURL)
            let list = try await withLiveTimeout(
                seconds: 20,
                description: "ACP session/list response",
                onTimeout: { await client.close() },
                operation: {
                    try await client.listSessions(
                        cwd: repoPath,
                        metadata: ["types": .array([.string("user"), .string("scheduled")])]
                    )
                }
            )
            let listedSessionIDs = Set(list.sessions.map(\.sessionId))

            appendLiveProgress("before session/load", to: progressURL)
            let load = try await withLiveTimeout(
                seconds: 20,
                description: "ACP session/load response",
                onTimeout: { await client.close() },
                operation: {
                    try await client.loadSession(
                        sessionId: session.sessionId,
                        cwd: repoPath
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
                        cwd: repoPath
                    )
                }
            )

            let proof = [
                "phase0_live_acp_session_lifecycle=pass",
                "goose_binary=\(binary.lastPathComponent)",
                "goose_base_url=\(connection.baseURL.absoluteString)",
                "session_id=\(session.sessionId)",
                "listed_count=\(list.sessions.count)",
                "listed_original_session=\(listedSessionIDs.contains(session.sessionId))",
                "load_has_modes=\(load.modes != nil)",
                "load_has_models=\(load.models != nil)",
                "load_has_config_options=\(load.configOptions != nil)",
                "fork_session_id=\(fork.sessionId)",
                "fork_differs_from_original=\(fork.sessionId != session.sessionId)",
            ].joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard listedSessionIDs.contains(session.sessionId) else {
                throw GooseLiveIntegrationError.runtimeFailed("session/list did not include the newly-created ACP session.")
            }
            guard !fork.sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw GooseLiveIntegrationError.runtimeFailed("session/fork returned an empty fork session id.")
            }
            guard fork.sessionId != session.sessionId else {
                throw GooseLiveIntegrationError.runtimeFailed("session/fork returned the original session id.")
            }
            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_acp_session_lifecycle=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live ACP session lifecycle proof log was not written.")
            }
        }
    }
}
