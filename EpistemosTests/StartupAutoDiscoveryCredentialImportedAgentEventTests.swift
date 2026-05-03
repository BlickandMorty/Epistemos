import Foundation
import Testing
@testable import Epistemos

nonisolated private final class StartupCredentialImportEventSink: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [AgentProvenanceEvent] = []

    var events: [AgentProvenanceEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ event: AgentProvenanceEvent) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        storage.append(event)
        return true
    }
}

@Suite("Startup Auto-Discovery Credential Import AgentEvent")
struct StartupAutoDiscoveryCredentialImportedAgentEventTests {
    @Test("environment import records one sanitized auth credential imported event")
    func environmentImportRecordsOneSanitizedAuthCredentialImportedEvent() throws {
        let mapping = try #require(
            StartupAutoDiscovery.keyMappings.first { $0.envVar == "BROWSERBASE_API_KEY" }
        )
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        var fakeKeychain: [String: String] = [:]
        let sink = StartupCredentialImportEventSink()
        let recorder = AgentToolProvenanceSyncRecorder(
            nowMilliseconds: { 123 },
            persist: { event in sink.append(event) }
        )

        _ = StartupAutoDiscovery.perform(
            environment: [
                mapping.envVar: "bb-env-secret",
                "PATH": "/usr/bin:/bin",
            ],
            fileManager: .default,
            homeDirectoryURL: tempRoot,
            localModelRootURL: tempRoot,
            configFileURLs: [],
            readFile: { _ in nil },
            keychainLoad: { fakeKeychain[$0] },
            keychainSave: { value, key in
                fakeKeychain[key] = value
                return true
            },
            agentProvenanceRecorder: recorder
        )

        #expect(fakeKeychain[mapping.keychainKey] == "bb-env-secret")
        let event = try #require(sink.events.only)
        #expect(event.kind == .toolCallCompleted)
        #expect(event.tool?.status == .completed)
        #expect(event.tool?.toolName == "auth.credential.imported")
        #expect(event.runID == "auth-credential-imported-startup")
        #expect(event.metadata["source"] == "startup_auto_discovery")
        #expect(event.metadata["surface"] == "credential_auto_discovery")
        #expect(event.metadata["credential_source"] == StartupAutoDiscoveryCredentialSource.environment.rawValue)
        #expect(event.metadata["env_var"] == mapping.envVar)
        #expect(event.metadata["keychain_key"] == mapping.keychainKey)
        #expect(event.tool?.argumentsJSON.contains(mapping.envVar) == true)
        #expect(event.tool?.argumentsJSON.contains(mapping.keychainKey) == true)

        let encodedEvents = try encodedAgentEvents(sink.events)
        #expect(!encodedEvents.contains("bb-env-secret"))
    }

    @Test("config import records filename provenance without leaking credential value")
    func configImportRecordsFilenameProvenanceWithoutLeakingCredentialValue() throws {
        let mapping = try #require(
            StartupAutoDiscovery.keyMappings.first { $0.envVar == "BROWSERBASE_API_KEY" }
        )
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let configURL = tempRoot.appendingPathComponent("config.toml")
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try Data(
            """
            [services.browserbase]
            api_key = "bb-config-secret"
            """.utf8
        ).write(to: configURL, options: .atomic)

        var fakeKeychain: [String: String] = [:]
        let sink = StartupCredentialImportEventSink()
        let recorder = AgentToolProvenanceSyncRecorder(
            nowMilliseconds: { 456 },
            persist: { event in sink.append(event) }
        )

        _ = StartupAutoDiscovery.perform(
            environment: [
                "PATH": "/usr/bin:/bin",
            ],
            fileManager: .default,
            homeDirectoryURL: tempRoot,
            localModelRootURL: tempRoot,
            configFileURLs: [configURL],
            readFile: { try? String(contentsOf: $0, encoding: .utf8) },
            keychainLoad: { fakeKeychain[$0] },
            keychainSave: { value, key in
                fakeKeychain[key] = value
                return true
            },
            agentProvenanceRecorder: recorder
        )

        #expect(fakeKeychain[mapping.keychainKey] == "bb-config-secret")
        let event = try #require(sink.events.only)
        #expect(event.kind == .toolCallCompleted)
        #expect(event.tool?.status == .completed)
        #expect(event.tool?.toolName == "auth.credential.imported")
        #expect(event.metadata["credential_source"] == StartupAutoDiscoveryCredentialSource.configFile.rawValue)
        #expect(event.metadata["origin"] == configURL.lastPathComponent)
        #expect(event.tool?.argumentsJSON.contains(configURL.lastPathComponent) == true)

        let encodedEvents = try encodedAgentEvents(sink.events)
        #expect(encodedEvents.contains(configURL.lastPathComponent))
        #expect(!encodedEvents.contains("bb-config-secret"))
    }

    @Test("existing keychain credential is not reported as a new import")
    func existingKeychainCredentialIsNotReportedAsNewImport() throws {
        let mapping = try #require(
            StartupAutoDiscovery.keyMappings.first { $0.envVar == "BROWSERBASE_API_KEY" }
        )
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        var fakeKeychain = [
            mapping.keychainKey: "bb-existing-secret",
        ]
        let sink = StartupCredentialImportEventSink()
        let recorder = AgentToolProvenanceSyncRecorder(
            persist: { event in sink.append(event) }
        )

        _ = StartupAutoDiscovery.perform(
            environment: [
                mapping.envVar: "bb-env-secret",
                "PATH": "/usr/bin:/bin",
            ],
            fileManager: .default,
            homeDirectoryURL: tempRoot,
            localModelRootURL: tempRoot,
            configFileURLs: [],
            readFile: { _ in nil },
            keychainLoad: { fakeKeychain[$0] },
            keychainSave: { value, key in
                fakeKeychain[key] = value
                return true
            },
            agentProvenanceRecorder: recorder
        )

        #expect(fakeKeychain[mapping.keychainKey] == "bb-existing-secret")
        #expect(sink.events.isEmpty)
    }

    @Test("failed keychain save is not reported as an imported credential")
    func failedKeychainSaveIsNotReportedAsImportedCredential() throws {
        let mapping = try #require(
            StartupAutoDiscovery.keyMappings.first { $0.envVar == "BROWSERBASE_API_KEY" }
        )
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let sink = StartupCredentialImportEventSink()
        let recorder = AgentToolProvenanceSyncRecorder(
            persist: { event in sink.append(event) }
        )

        _ = StartupAutoDiscovery.perform(
            environment: [
                mapping.envVar: "bb-env-secret",
                "PATH": "/usr/bin:/bin",
            ],
            fileManager: .default,
            homeDirectoryURL: tempRoot,
            localModelRootURL: tempRoot,
            configFileURLs: [],
            readFile: { _ in nil },
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in false },
            agentProvenanceRecorder: recorder
        )

        #expect(sink.events.isEmpty)
    }

    private func encodedAgentEvents(_ events: [AgentProvenanceEvent]) throws -> String {
        let data = try JSONEncoder().encode(events)
        return try #require(String(data: data, encoding: .utf8))
    }
}

private extension Array {
    var only: Element? {
        count == 1 ? self[0] : nil
    }
}
