import Foundation
import Testing

@testable import Epistemos

@Suite("App Group Arena Bridge")
struct ArenaTests {
    @Test("App Group container uses canonical Epistemos group and arena names")
    @MainActor
    func appGroupContainerUsesCanonicalNames() throws {
        let container = makeContainer()

        #expect(container.groupIdentifier == "group.com.epistemos.shared")
        #expect(container.arenaURL.lastPathComponent == "arena.dat")
        #expect(container.rootURL.lastPathComponent == "Epistemos")
        #expect(container.provenanceDBURL.lastPathComponent == "provenance.sqlite")
        #expect(container.vaultIndexURL.lastPathComponent == "vault_index.sqlite")
        #expect(container.resonanceDBURL.lastPathComponent == "resonance.sqlite")
    }

    @Test("App Group layout creates Core shared substrate directories")
    @MainActor
    func appGroupLayoutCreatesSharedDirectories() throws {
        let container = makeContainer()

        try container.ensureLayout()

        #expect(FileManager.default.fileExists(atPath: container.rootURL.path))
        #expect(FileManager.default.fileExists(atPath: container.blobsURL.path))
        #expect(FileManager.default.fileExists(atPath: container.sharedTempURL.path))
        #expect(FileManager.default.fileExists(atPath: container.sharedLogsURL.path))
    }

    @Test("Arena path resolver returns a NUL-terminated canonical path")
    @MainActor
    func arenaPathResolverReturnsCString() throws {
        let container = makeContainer()

        let cString = try ArenaPathResolver.resolveCString(container: container)

        #expect(cString.last == 0)
        #expect(String(decoding: cString.dropLast(), as: UTF8.self).hasSuffix("/Epistemos/arena.dat"))
    }

    @Test("Arena bridge assigns monotonic sequences and clamps inline payloads")
    func arenaBridgeAssignsSequencesAndClampsPayloads() async throws {
        let bridge = ArenaBridge(arenaURL: URL(fileURLWithPath: "/tmp/epistemos-arena-test.dat"))
        let largePayload = Data(repeating: 0xA7, count: ArenaBridge.maxInlinePayloadBytes + 128)

        let first = try await bridge.submitRequest(op: .retrieve, payload: Data("first".utf8))
        let second = try await bridge.submitRequest(op: .execute, payload: largePayload)
        let stored = await bridge.submittedRequest(sequence: second)

        #expect(first == 1)
        #expect(second == 2)
        #expect(stored?.op == .execute)
        #expect(stored?.payload.count == ArenaBridge.maxInlinePayloadBytes)
    }

    @Test("Arena bridge mirrors Rust arena budget constants")
    func arenaBridgeMirrorsRustArenaBudgetConstants() {
        #expect(ArenaBridge.arenaVersion == 2)
        #expect(ArenaBridge.slotCount == 16)
        #expect(ArenaBridge.maxInlinePayloadBytes == 2_048)
        #expect(ArenaBridge.maxInlineResponseBytes == 4_096)
        #expect(ArenaBridge.maxArtefactRefs == 8)
    }

    @Test("Arena bridge polls injected responses once")
    func arenaBridgePollsInjectedResponsesOnce() async throws {
        let bridge = ArenaBridge(arenaURL: URL(fileURLWithPath: "/tmp/epistemos-arena-test.dat"))
        let sequence = try await bridge.submitRequest(op: .plan, payload: Data("plan".utf8))
        let response = ArenaResponse(
            sequence: sequence,
            status: 0,
            payload: Data("ok".utf8),
            refs: []
        )

        await bridge.ingestResponse(response)

        #expect(await bridge.pollResponse(sequence: sequence) == response)
        #expect(await bridge.pollResponse(sequence: sequence) == nil)
        #expect(await bridge.submittedRequest(sequence: sequence) == nil)
    }

    @Test("Arena bridge clamps response payloads and artefact refs")
    func arenaBridgeClampsResponseBudget() async throws {
        let bridge = ArenaBridge(arenaURL: URL(fileURLWithPath: "/tmp/epistemos-arena-test.dat"))
        let sequence = try await bridge.submitRequest(op: .retrieve, payload: Data())
        let refs = (0..<12).map { index in
            ArenaArtefactRef(
                blobId: Data(repeating: UInt8(index), count: 16),
                offset: UInt64(index),
                length: 1,
                flags: 0
            )
        }
        let response = ArenaResponse(
            sequence: sequence,
            status: 0,
            payload: Data(repeating: 0xB1, count: ArenaBridge.maxInlineResponseBytes + 256),
            refs: refs
        )

        await bridge.ingestResponse(response)
        let polled = await bridge.pollResponse(sequence: sequence)

        #expect(polled?.payload.count == ArenaBridge.maxInlineResponseBytes)
        #expect(polled?.refs.count == ArenaBridge.maxArtefactRefs)
    }

    @Test("Arena bridge timeout stays explicit and bounded")
    func arenaBridgeTimeoutIsExplicit() async throws {
        let bridge = ArenaBridge(arenaURL: URL(fileURLWithPath: "/tmp/epistemos-arena-test.dat"))

        do {
            _ = try await bridge.awaitResponse(
                sequence: 99,
                timeout: .milliseconds(1),
                pollInterval: .milliseconds(1)
            )
            Issue.record("Expected timeout for missing arena response.")
        } catch let error as ArenaBridgeError {
            #expect(error == .timeout(sequence: 99))
        }
    }

    @Test("Arena diagnostics report path, materialization, and bridge budgets honestly")
    @MainActor
    func arenaDiagnosticsReportPathAndBudgets() throws {
        let container = makeContainer()

        var snapshot = ArenaHealthRow.snapshot(container: container)
        #expect(snapshot.ok)
        #expect(snapshot.path?.hasSuffix("/Epistemos/arena.dat") == true)
        #expect(snapshot.exists == false)
        #expect(snapshot.byteSize == nil)
        #expect(snapshot.detail.contains("v\(ArenaBridge.arenaVersion)"))
        #expect(snapshot.detail.contains("slots \(ArenaBridge.slotCount)"))
        #expect(snapshot.detail.contains("inline \(ArenaBridge.maxInlinePayloadBytes)/\(ArenaBridge.maxInlineResponseBytes) B"))
        #expect(snapshot.detail.contains("not materialized"))

        try Data(repeating: 0xA5, count: 128).write(to: container.arenaURL, options: .atomic)
        snapshot = ArenaHealthRow.snapshot(container: container)

        #expect(snapshot.exists)
        #expect(snapshot.byteSize == 128)
        #expect(snapshot.detail.contains("materialized"))
    }

    @Test("Settings mounts shared arena diagnostics without v2 authority copy")
    func settingsMountSharedArenaDiagnosticsWithoutV2Copy() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ArenaHealthRow.swift")

        #expect(settings.contains("ArenaHealthRow()"))
        #expect(settings.contains("Shared Arena reports the app-group arena path and bridge budgets without claiming runtime authority"))
        #expect(!settings.contains("Cognitive DAG (V2 final lane)"))
        #expect(row.contains("ArenaPathResolver.resolve(container: container)"))
        #expect(row.contains("ArenaBridge.arenaVersion"))
        #expect(row.contains("ArenaBridge.slotCount"))
        #expect(row.contains("not materialized"))
    }

    @Test("Arena source files reject Epistenos donor spelling drift")
    func arenaSourceFilesRejectDonorSpellingDrift() throws {
        let files = [
            "Epistemos/App/AppGroupContainer.swift",
            "Epistemos/Engine/ArenaPathResolver.swift",
            "Epistemos/Engine/ArenaBridge.swift",
        ]

        for file in files {
            let source = try loadMirroredSourceTextFile(file)

            #expect(!source.contains("Epistenos"))
            #expect(!source.contains("group.com.epistenos.shared"))
            #expect(!source.contains("epistenos.arena"))
        }

        let containerSource = try loadMirroredSourceTextFile("Epistemos/App/AppGroupContainer.swift")
        #expect(containerSource.contains("group.com.epistemos.shared"))
        #expect(containerSource.contains("arena.dat"))
    }

    @Test("AppBootstrap prepares shared substrate container at launch")
    func appBootstrapPreparesSharedSubstrateContainerAtLaunch() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        let prepareRange = try #require(
            source.range(of: "prepareSharedSubstrateContainer(AppGroupContainer.shared)")
        )
        let eventStoreRange = try #require(source.range(of: "EventStore.shared = EventStore()"))

        #expect(prepareRange.lowerBound < eventStoreRange.lowerBound)
        #expect(source.contains("AppGroupContainer.shared"))
        #expect(source.contains("appGroupContainer.ensureLayout()"))
        #expect(source.contains("appGroupContainer.migrateLegacyDatabasesIfNeeded()"))
    }

    @Test("App Store entitlement carries the TEMP-FREE-TIER App Group restoration trail")
    func appStoreEntitlementCarriesTemporaryAppGroupRestorationTrail() throws {
        let appStore = try loadMirroredSourceTextFile("Epistemos/Epistemos-AppStore.entitlements")
        let direct = try loadMirroredSourceTextFile("Epistemos/Epistemos.entitlements")
        let debug = try loadMirroredSourceTextFile("Epistemos/Epistemos-Debug.entitlements")

        #expect(appStore.contains("TEMP-FREE-TIER NOTE"))
        #expect(appStore.contains("Restore the App Group key with value `group.com.epistemos.shared`"))
        #expect(!appStore.contains("<key>com.apple.security.application-groups</key>"))
        #expect(!appStore.contains("group.com.epistenos.shared"))
        #expect(!direct.contains("com.apple.security.application-groups"))
        #expect(!debug.contains("com.apple.security.application-groups"))
    }

    @MainActor
    private func makeContainer() -> AppGroupContainer {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EpistemosArenaTests-\(UUID().uuidString)", isDirectory: true)

        return AppGroupContainer(
            legacyBaseURL: root.appendingPathComponent("Epistemos", isDirectory: true),
            containerURLProvider: { _ in nil }
        )
    }
}
