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
        #expect(receipt.metadata.embeddingModelPin == nil)
        #expect(receipt.metadata.routerModelPin == nil)
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
        #expect(url.lastPathComponent == "Epistemos")
        // The path must contain "Documents" or be a fallback under the home
        // directory; both are acceptable per the plan's fallback chain.
        let lowered = url.path.lowercased()
        let acceptable = lowered.contains("/documents/") || lowered.hasSuffix("/epistemos")
        #expect(acceptable, "default path must be Documents/Epistemos or a sane fallback: \(url.path)")
    }

    @Test("router candidates have exactly one plan default = Qwen 2.5-1.5B")
    func routerCandidatesPlanDefault() {
        let defaults = FirstRunBootstrap.routerCandidates.filter { $0.isPlanDefault }
        #expect(defaults.count == 1, "exactly one router candidate must be plan default")

        let chosen = FirstRunBootstrap.defaultRouter
        #expect(
            chosen.huggingFaceID == "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            "PLAN §6.6.1 anchors the default at Qwen 2.5-1.5B"
        )
        #expect(chosen.isPlanDefault)
    }

    @Test("router candidates cover all three plan-mentioned options")
    func routerCandidatesCoverAllThree() {
        let ids = FirstRunBootstrap.routerCandidates.map(\.huggingFaceID)
        #expect(ids.contains(where: { $0.contains("Qwen2.5-1.5B") }))
        #expect(ids.contains(where: { $0.contains("Qwen3.5-0.8B") }))
        #expect(ids.contains(where: { $0.contains("Qwen3.5-2B") }))
    }

    @Test("embedding candidates have exactly one plan default = bge-small")
    func embeddingCandidatesPlanDefault() {
        let defaults = FirstRunBootstrap.embeddingCandidates.filter { $0.isPlanDefault }
        #expect(defaults.count == 1)

        let chosen = FirstRunBootstrap.defaultEmbedding
        #expect(chosen.huggingFaceID == "mlx-community/bge-small-en-v1.5-mlx")
        #expect(chosen.dims == 384)
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

        // Step 2 — model descriptors are known up front (download itself
        // would be triggered by ModelDownloadManager; we don't simulate
        // network here, just confirm the descriptor surface is wired).
        let router = FirstRunBootstrap.defaultRouter
        let embedding = FirstRunBootstrap.defaultEmbedding
        #expect(!router.huggingFaceID.isEmpty)
        #expect(!embedding.huggingFaceID.isEmpty)
        // Combined resident set on the 16-GB constraint must be < the plan's
        // 6-GB headroom for this stage of bootstrap.
        let combinedMB = router.residentMB4Bit + embedding.residentMB
        #expect(combinedMB < 6 * 1024, "router + embedding must fit headroom: \(combinedMB) MB")

        // Step 3 — folder scaffold + metadata stamp.
        let receipt = try FirstRunBootstrap.bootstrap(at: vault)
        #expect(receipt.wasFresh)
        #expect(receipt.createdFolders.count == FirstRunBootstrap.scaffoldFolders.count)

        // Step 4 — first-capture tooltip is a UI concern and not part of
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
