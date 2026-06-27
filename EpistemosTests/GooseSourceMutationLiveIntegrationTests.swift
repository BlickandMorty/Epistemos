import Foundation
import Testing
@testable import Epistemos

@Suite("Goose source mutation live integration", .serialized)
struct GooseSourceMutationLiveIntegrationTests {
    @Test(
        "live Goose serve creates, updates, exports, deletes, imports, and cleans up an isolated project skill source",
        .enabled(if: gooseLiveIntegrationTestsEnabled())
    )
    @MainActor
    func liveGooseServeMutatesProjectSkillSourceInIsolatedProject() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-source-mutation.log")
        try? FileManager.default.removeItem(at: proofURL)

        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-goose-source-mutation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        try await withLiveGooseACPClient(proofName: "source-mutation") { binary, connection, client, progressURL in
            appendLiveProgress("before initialize", to: progressURL)
            _ = try await withLiveTimeout(
                seconds: 12,
                description: "ACP initialize response",
                onTimeout: { await client.close() },
                operation: { try await client.initialize() }
            )

            let sourceName = "epistemos-phase0-source-\(UUID().uuidString.lowercased().prefix(8))"
            let target = GooseACPSourceScope.projectDir(projectURL.path)
            appendLiveProgress("before source create name=\(sourceName)", to: progressURL)
            let created = try await withLiveTimeout(
                seconds: 20,
                description: "Goose source create custom ACP response",
                onTimeout: { await client.close() },
                operation: {
                    try await client.createGooseSource(
                        type: .skill,
                        name: sourceName,
                        description: "Phase 0 isolated source mutation proof",
                        content: "Use the initial isolated source mutation proof steps.",
                        target: target,
                        properties: ["origin": .string("phase0-live-source-mutation")]
                    )
                }
            )

            let updated = try await withLiveTimeout(
                seconds: 20,
                description: "Goose source update custom ACP response",
                onTimeout: { await client.close() },
                operation: {
                    try await client.updateGooseSource(
                        type: .skill,
                        path: created.source.path,
                        name: sourceName,
                        description: "Phase 0 updated isolated source mutation proof",
                        content: "Use the updated isolated source mutation proof steps."
                    )
                }
            )
            let exported = try await withLiveTimeout(
                seconds: 20,
                description: "Goose source export custom ACP response",
                onTimeout: { await client.close() },
                operation: { try await client.exportGooseSource(type: .skill, path: updated.source.path) }
            )
            let exportJSONValid = isValidLiveSourceMutationJSON(exported.json)

            try await withLiveTimeout(
                seconds: 20,
                description: "Goose source delete custom ACP response",
                onTimeout: { await client.close() },
                operation: { try await client.deleteGooseSource(type: .skill, path: updated.source.path) }
            )
            let imported = try await withLiveTimeout(
                seconds: 20,
                description: "Goose source import custom ACP response",
                onTimeout: { await client.close() },
                operation: { try await client.importGooseSources(data: exported.json, target: target) }
            )
            for source in imported.sources {
                try await withLiveTimeout(
                    seconds: 20,
                    description: "Goose imported source cleanup custom ACP response",
                    onTimeout: { await client.close() },
                    operation: { try await client.deleteGooseSource(type: source.sourceType, path: source.path) }
                )
            }
            appendLiveProgress("after source mutation imported=\(imported.sources.count)", to: progressURL)

            let proof = [
                "phase0_live_source_mutation=pass",
                "goose_binary=\(binary.lastPathComponent)",
                "goose_base_url=\(connection.baseURL.absoluteString)",
                "isolated_project=true",
                "created_source_type=\(created.source.sourceType.rawValue)",
                "created_source_writable=\(created.source.writable)",
                "updated_content_chars=\(updated.source.content.count)",
                "export_filename=\(exported.filename)",
                "export_json_chars=\(exported.json.count)",
                "export_json_valid=\(exportJSONValid)",
                "imported_source_count=\(imported.sources.count)",
                "cleanup_deleted=true",
            ].joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard created.source.sourceType == .skill, !created.source.global, created.source.writable else {
                throw GooseLiveIntegrationError.runtimeFailed("Source create did not return a writable project skill.")
            }
            guard updated.source.description == "Phase 0 updated isolated source mutation proof" else {
                throw GooseLiveIntegrationError.runtimeFailed("Source update did not return the updated description.")
            }
            guard !exported.filename.isEmpty, !exported.json.isEmpty, exportJSONValid else {
                throw GooseLiveIntegrationError.runtimeFailed("Source export did not return valid portable JSON.")
            }
            guard !imported.sources.isEmpty, imported.sources.allSatisfy({ $0.sourceType == .skill }) else {
                throw GooseLiveIntegrationError.runtimeFailed("Source import did not return skill sources.")
            }
            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_source_mutation=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live source mutation proof log was not written.")
            }
        }
    }
}

private func isValidLiveSourceMutationJSON(_ string: String) -> Bool {
    guard let data = string.data(using: .utf8) else {
        return false
    }
    return (try? JSONSerialization.jsonObject(with: data)) != nil
}
