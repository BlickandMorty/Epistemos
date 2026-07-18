import Foundation
import Testing
@testable import Epistemos

/// Phase 0.5 — first-run bootstrap simulation tests. Run end-to-end
/// against a temp directory to prove the scaffold spec from PLAN §11
/// Phase 0.5 is satisfied without any user interaction.
///
/// The plan's Phase-0.5 verification is "Manual: <90s for first capture +
/// trace" — that's a UI-level gate. These tests cover the *deterministic*
/// part of the bootstrap (folder scaffold + metadata stamp + idempotency)
/// so a regression in the headless path can't slip past code review.
@Suite("First-Run Bootstrap")
struct FirstRunBootstrapTests {

    /// Build a unique temp directory for one test, return its URL, and
    /// register cleanup. The directory contains no `.epistemos` stamp,
    /// so `FirstRunBootstrap.isFresh` reports true.
    private static func makeTempVault() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-bootstrap-\(UUID().uuidString)", isDirectory: true)
        // Caller invokes `bootstrap` which creates this directory; we don't
        // pre-create it so the "fresh" pre-condition is exact.
        return base
    }

    private static func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("fresh vault gets all four scaffold folders + metadata stamp")
    func freshVaultBootstrap() throws {
        let vault = try Self.makeTempVault()
        defer { Self.cleanup(vault) }

        #expect(FirstRunBootstrap.isFresh(at: vault), "pre-bootstrap must be fresh")

        let receipt = try FirstRunBootstrap.bootstrap(at: vault)

        #expect(receipt.wasFresh, "first call must report wasFresh = true")
        #expect(receipt.createdFolders.count == FirstRunBootstrap.scaffoldFolders.count)

        for relative in FirstRunBootstrap.scaffoldFolders {
            let abs = vault.appendingPathComponent(relative, isDirectory: true)
            var isDir: ObjCBool = false
            #expect(
                FileManager.default.fileExists(atPath: abs.path, isDirectory: &isDir),
                "scaffold folder \(relative) must exist"
            )
            #expect(isDir.boolValue, "\(relative) must be a directory")
        }

        #expect(FileManager.default.fileExists(atPath: receipt.metadataURL.path))
        #expect(receipt.metadata.schemaVersion == FirstRunBootstrap.schemaVersion)
        let freshMetadata = try Data(contentsOf: receipt.metadataURL)
        let freshMetadataText = String(decoding: freshMetadata, as: UTF8.self)
        #expect(!freshMetadataText.contains("\"embedding_model_pin\""))
        #expect(!freshMetadataText.contains("\"router_model_pin\""))
        #expect(!FirstRunBootstrap.isFresh(at: vault), "post-bootstrap must not be fresh")
    }

    @Test("re-bootstrap is idempotent and preserves createdAt")
    func idempotentBootstrap() throws {
        let vault = try Self.makeTempVault()
        defer { Self.cleanup(vault) }

        let first = try FirstRunBootstrap.bootstrap(at: vault)
        let second = try FirstRunBootstrap.bootstrap(at: vault)

        #expect(first.wasFresh)
        #expect(!second.wasFresh, "second call must not report wasFresh")
        #expect(second.createdFolders.isEmpty, "no new folders on idempotent re-run")
        #expect(
            first.metadata.createdAt == second.metadata.createdAt,
            "createdAt must survive idempotent re-bootstrap"
        )
    }

    @Test("metadata round-trips through JSON on disk")
    func metadataRoundTrip() throws {
        let vault = try Self.makeTempVault()
        defer { Self.cleanup(vault) }

        let receipt = try FirstRunBootstrap.bootstrap(at: vault)
        let read = try FirstRunBootstrap.readMetadata(at: receipt.metadataURL)
        #expect(read == receipt.metadata)
    }

    @Test("existing metadata compatibility bytes remain inert and preserved")
    func existingMetadataCompatibilityBytesRemainPreserved() throws {
        let vault = try Self.makeTempVault()
        defer { Self.cleanup(vault) }

        let metadataDirectory = vault.appendingPathComponent(".epistemos", isDirectory: true)
        try FileManager.default.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
        let metadataURL = vault.appendingPathComponent(FirstRunBootstrap.metadataRelativePath)
        let originalBytes = Data(
            """
            {
              "schema_version": 1,
              "created_at": "2026-07-15T00:00:00Z",
              "embedding_model_pin": "historical-embedding-pin",
              "router_model_pin": "historical-router-pin"
            }
            """.utf8
        )
        try originalBytes.write(to: metadataURL)

        let receipt = try FirstRunBootstrap.bootstrap(at: vault)

        #expect(!receipt.wasFresh)
        #expect(receipt.metadata.schemaVersion == FirstRunBootstrap.schemaVersion)
        #expect(try Data(contentsOf: metadataURL) == originalBytes)
    }

    @Test("invalid existing metadata fails before creating any scaffold folders")
    func invalidExistingMetadataFailsBeforeScaffolding() throws {
        let vault = try Self.makeTempVault()
        defer { Self.cleanup(vault) }

        let metadataDirectory = vault.appendingPathComponent(".epistemos", isDirectory: true)
        try FileManager.default.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
        let metadataURL = vault.appendingPathComponent(FirstRunBootstrap.metadataRelativePath)
        let originalBytes = Data("{not-json}".utf8)
        try originalBytes.write(to: metadataURL)

        #expect(throws: Error.self) {
            try FirstRunBootstrap.bootstrap(at: vault)
        }
        #expect(try Data(contentsOf: metadataURL) == originalBytes)
        for relative in FirstRunBootstrap.scaffoldFolders {
            #expect(!FileManager.default.fileExists(atPath: vault.appendingPathComponent(relative).path))
        }
    }

    @Test("unsupported, duplicate, unknown, and oversized metadata fail closed")
    func invalidMetadataEnvelopeFailsClosed() throws {
        let invalidMetadata: [Data] = [
            Data("{\"schema_version\":2,\"created_at\":\"2026-07-15T00:00:00Z\"}".utf8),
            Data("{\"schema_version\":1,\"schema_version\":1,\"created_at\":\"2026-07-15T00:00:00Z\"}".utf8),
            Data("{\"schema_version\":1,\"created_at\":\"2026-07-15T00:00:00Z\",\"unexpected\":true}".utf8),
            Data(repeating: 0x61, count: FirstRunBootstrap.maxMetadataBytes + 1),
        ]

        for originalBytes in invalidMetadata {
            let vault = try Self.makeTempVault()
            defer { Self.cleanup(vault) }
            let metadataDirectory = vault.appendingPathComponent(".epistemos", isDirectory: true)
            try FileManager.default.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
            let metadataURL = vault.appendingPathComponent(FirstRunBootstrap.metadataRelativePath)
            try originalBytes.write(to: metadataURL)

            #expect(throws: Error.self) {
                try FirstRunBootstrap.bootstrap(at: vault)
            }
            #expect(try Data(contentsOf: metadataURL) == originalBytes)
            #expect(!FileManager.default.fileExists(atPath: vault.appendingPathComponent("notes").path))
        }
    }

    @Test("unsafe existing filesystem objects do not become a vault scaffold")
    func unsafeExistingFilesystemObjectsFailClosed() throws {
        let fileManager = FileManager.default

        let wrongTypeVault = try Self.makeTempVault()
        defer { Self.cleanup(wrongTypeVault) }
        try fileManager.createDirectory(at: wrongTypeVault, withIntermediateDirectories: true)
        try Data("canary".utf8).write(to: wrongTypeVault.appendingPathComponent("notes"))
        #expect(throws: Error.self) {
            try FirstRunBootstrap.bootstrap(at: wrongTypeVault)
        }
        #expect(try Data(contentsOf: wrongTypeVault.appendingPathComponent("notes")) == Data("canary".utf8))

        let symlinkVault = try Self.makeTempVault()
        defer { Self.cleanup(symlinkVault) }
        let metadataDirectory = symlinkVault.appendingPathComponent(".epistemos", isDirectory: true)
        try fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
        let outside = fileManager.temporaryDirectory
            .appendingPathComponent("epistemos-bootstrap-external-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: outside) }
        try Data("outside-canary".utf8).write(to: outside)
        let metadataURL = symlinkVault.appendingPathComponent(FirstRunBootstrap.metadataRelativePath)
        try fileManager.createSymbolicLink(at: metadataURL, withDestinationURL: outside)

        #expect(throws: Error.self) {
            try FirstRunBootstrap.bootstrap(at: symlinkVault)
        }
        #expect(try Data(contentsOf: outside) == Data("outside-canary".utf8))
        #expect(!fileManager.fileExists(atPath: symlinkVault.appendingPathComponent("notes").path))
    }

    @Test("partial scaffold (some folders pre-created) recovers cleanly")
    func partialScaffoldRecovers() throws {
        let vault = try Self.makeTempVault()
        defer { Self.cleanup(vault) }

        // Simulate a crash mid-bootstrap: vault dir exists, `notes/` exists,
        // metadata stamp absent.
        try FileManager.default.createDirectory(
            at: vault.appendingPathComponent("notes", isDirectory: true),
            withIntermediateDirectories: true
        )
        #expect(
            FirstRunBootstrap.isFresh(at: vault),
            "vault without metadata stamp must be reported as fresh"
        )

        let receipt = try FirstRunBootstrap.bootstrap(at: vault)

        #expect(receipt.wasFresh)
        #expect(
            receipt.createdFolders.count == FirstRunBootstrap.scaffoldFolders.count - 1,
            "createdFolders excludes the pre-existing folder"
        )
        for relative in FirstRunBootstrap.scaffoldFolders {
            let abs = vault.appendingPathComponent(relative, isDirectory: true)
            #expect(FileManager.default.fileExists(atPath: abs.path))
        }
    }

    @Test("default vault path lands at ~/Documents/Epistemos")
    func defaultVaultPath() {
        let url = FirstRunBootstrap.defaultVaultURL()
        #expect(url.isFileURL)
        #expect(url.path.hasPrefix("/"))
        #expect(url.lastPathComponent == "Epistemos")
        // The path must contain "Documents" or be a fallback under the home
        // directory; both are acceptable per the plan's fallback chain.
        let lowered = url.path.lowercased()
        let acceptable = lowered.contains("/documents/") || lowered.hasSuffix("/epistemos")
        #expect(acceptable, "default path must be Documents/Epistemos or a sane fallback: \(url.path)")
    }

    @Test("Free bootstrap source remains a neutral vault scaffold")
    func freeBootstrapSourceRemainsNeutral() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Vault/FirstRunBootstrap.swift")

        for retainedContract in [
            "public enum FirstRunBootstrap",
            "public static let scaffoldFolders",
            "public static func bootstrap",
            "public static func readMetadata"
        ] {
            #expect(source.contains(retainedContract))
        }

        for retiredCatalogIdentity in [
            "RouterCandidate",
            "EmbeddingCandidate",
            "routerCandidates",
            "embeddingCandidates",
            "defaultRouter",
            "defaultEmbedding",
            "huggingFaceID",
            "Qwen",
            "BGE",
            "Nomic",
            "MLX",
            "agent_core",
            "model download",
            "background model"
        ] {
            #expect(!source.contains(retiredCatalogIdentity))
        }
    }

    /// End-to-end "first-run simulation" — combines the steps a real first
    /// launch would take, headlessly. This is the test the user asked for
    /// when they said "write the test that simulates the first-run."
    @Test("simulated first-run end-to-end against a fresh temp vault")
    func simulatedFirstRunEndToEnd() throws {
        let vault = try Self.makeTempVault()
        defer { Self.cleanup(vault) }

        // Step 1 — vault location chosen (here: temp dir, normally
        // ~/Documents/Epistemos via defaultVaultURL).
        #expect(FirstRunBootstrap.isFresh(at: vault))

        // Step 2 — folder scaffold + metadata stamp.
        let receipt = try FirstRunBootstrap.bootstrap(at: vault)
        #expect(receipt.wasFresh)
        #expect(receipt.createdFolders.count == FirstRunBootstrap.scaffoldFolders.count)

        // Step 3 — first-capture tooltip is a UI concern and not part of
        // this headless test. We confirm the precondition for it: the
        // `_inbox/` folder exists and a write to it would land cleanly.
        let inbox = vault.appendingPathComponent("_inbox", isDirectory: true)
        let canary = inbox.appendingPathComponent("phase-0-5-canary.txt")
        try "first-run canary".write(to: canary, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: canary.path))

        // Re-run idempotency one more time as a regression guard against
        // accidental "wipe-on-re-launch" bugs.
        let secondReceipt = try FirstRunBootstrap.bootstrap(at: vault)
        #expect(!secondReceipt.wasFresh)
        #expect(
            secondReceipt.metadata.createdAt == receipt.metadata.createdAt,
            "createdAt must survive across simulated re-launches"
        )
        // The canary written by the user must survive idempotent bootstrap.
        #expect(FileManager.default.fileExists(atPath: canary.path))
    }
}
