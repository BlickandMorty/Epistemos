import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import Epistemos

// MARK: - Phase R.3 Body Read Parity Regression Tests
//
// Proves byte-equality between the R.3 gateway read path
// (`resourceRead` via `agent_core::resources::bridge`) and the
// pre-R.3 legacy `NoteFileStorage.readBody` / filesystem-read path
// that Swift production code currently uses.
//
// This is the safety net that future Swift call-site migrations will
// rely on: if `loadBodyAsync` starts to drift from `loadBody` for any
// vault-note the parity test fails loudly, BEFORE a migration
// accidentally ships silent data corruption.
//
// Scope of this suite: read parity only. The write-pipeline + verified-
// commit work belongs in Phase R.6 and is tested separately.
//
// Plan refs: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §Phase R.3,
// docs/KNOWN_ISSUES_REGISTER.md I-002 / I-003 (both OPEN — these tests
// do not close them; they're the parity gate the upcoming migrations
// will rely on).

@Suite("Phase R.3 — Body Read Parity")
struct PhaseR3BodyReadParityTests {

    // MARK: - Helpers

    /// Build a scratch vault on disk with a seeded markdown note and
    /// return its absolute path + the seeded body content.
    private func seedVault(label: String, body: String) throws -> (URL, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("r3-parity-\(label)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let inbox = root.appendingPathComponent("Inbox")
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let noteURL = inbox.appendingPathComponent("ParitySeed.md")
        try body.write(to: noteURL, atomically: true, encoding: .utf8)
        return (root, noteURL)
    }

    private func removeIfExists(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Tests

    @Test("resourceRead via file:// URI returns byte-identical content to direct FileManager read")
    func resourceReadMatchesFileManager() async throws {
        let expectedBody = """
            # Parity Seed

            Line two of the parity body.
            Multibyte: café — 👋 — résumé
            """
        let (root, noteURL) = try seedVault(label: "file-uri", body: expectedBody)
        defer { removeIfExists(root) }

        try resourceServiceInit(vaultRoot: root.path, vaultId: "parity-file-uri-\(UUID().uuidString)")

        // Gateway read via file:// URI (covers the attached-code-file
        // path from I-006 — Finder-dropped files go through this variant).
        let fileID = ResourceId.file(absolutePath: noteURL.path)
        let gatewayContent = try await resourceRead(id: fileID)

        // Legacy read via FileManager directly — this is the ground
        // truth we want the gateway to match.
        let filesystemBytes = try Data(contentsOf: noteURL)

        #expect(
            gatewayContent.bytes == filesystemBytes,
            "R.3 gateway must return byte-identical content to FileManager"
        )
        let decoded = String(data: gatewayContent.bytes, encoding: .utf8)
        #expect(decoded == expectedBody)
    }

    @Test("resourceRead via vault-note URI returns the same bytes as the file on disk")
    func resourceReadViaVaultNoteMatchesDisk() async throws {
        let expectedBody = """
            # Canonical Vault Note

            Ground-truth check that `vault://{vault}/note/{path}` reads match
            the raw bytes on disk.
            """
        let vaultId = "parity-vault-note-\(UUID().uuidString)"
        let (root, noteURL) = try seedVault(label: "vault-note-uri", body: expectedBody)
        defer { removeIfExists(root) }

        try resourceServiceInit(vaultRoot: root.path, vaultId: vaultId)

        let vaultID = ResourceId.vaultNote(vaultId: vaultId, noteId: "Inbox/ParitySeed.md")
        let gatewayContent = try await resourceRead(id: vaultID)
        let filesystemBytes = try Data(contentsOf: noteURL)

        #expect(gatewayContent.bytes == filesystemBytes)
    }

    @Test("resolve-then-read round-trip matches a direct FileManager read")
    func resolveThenReadMatchesDisk() async throws {
        let expectedBody = "just a simple body line\n"
        let (root, noteURL) = try seedVault(label: "resolve-then-read", body: expectedBody)
        defer { removeIfExists(root) }

        try resourceServiceInit(
            vaultRoot: root.path,
            vaultId: "parity-resolve-\(UUID().uuidString)"
        )

        // Mimic the real Swift flow: resolve a stem title → canonical
        // ResourceId → read → compare to the disk bytes.
        let resolved = try await resourceResolve(reference: "ParitySeed")
        let gatewayContent = try await resourceRead(id: resolved)
        let filesystemBytes = try Data(contentsOf: noteURL)

        #expect(gatewayContent.bytes == filesystemBytes)
    }

    @Test("multibyte UTF-8 round-trips byte-identically through the gateway")
    func multibyteContentRoundTripsThroughGateway() async throws {
        // Emoji + combining accents + CJK — these are the failure modes
        // where a naive String-truncation layer might lose bytes. The
        // gateway must return the on-disk bytes verbatim.
        let expectedBody =
            "Hello 🌍\n" +
            "Café — Résumé — Piñata\n" +
            "日本語 한국어 العربية\n" +
            "Combining: e\u{0301} vs é\n"
        let (root, noteURL) = try seedVault(label: "multibyte", body: expectedBody)
        defer { removeIfExists(root) }

        try resourceServiceInit(
            vaultRoot: root.path,
            vaultId: "parity-multibyte-\(UUID().uuidString)"
        )

        let fileID = ResourceId.file(absolutePath: noteURL.path)
        let gatewayContent = try await resourceRead(id: fileID)
        let filesystemBytes = try Data(contentsOf: noteURL)

        #expect(gatewayContent.bytes == filesystemBytes)
        #expect(String(data: gatewayContent.bytes, encoding: .utf8) == expectedBody)
    }

    @Test("resourceRead checksum matches an independently-computed sha256 of the bytes")
    func resourceReadChecksumMatchesIndependentSha256() async throws {
        let expectedBody = "checksum sanity line — one, two, three.\n"
        let (root, noteURL) = try seedVault(label: "checksum", body: expectedBody)
        defer { removeIfExists(root) }

        try resourceServiceInit(
            vaultRoot: root.path,
            vaultId: "parity-checksum-\(UUID().uuidString)"
        )

        let fileID = ResourceId.file(absolutePath: noteURL.path)
        let gatewayContent = try await resourceRead(id: fileID)
        let filesystemBytes = try Data(contentsOf: noteURL)

        let expectedHex = Self.sha256Hex(filesystemBytes)
        #expect(gatewayContent.checksum.lowercased() == expectedHex.lowercased())
    }

    @Test("async SDPage primitive read strips markdown front matter like sync fallback")
    func asyncPrimitiveReadStripsMarkdownFrontMatter() async throws {
        let markdown = """
            ---
            title: Parity Seed
            tags: [release]
            ---
            # Body

            Actual note body.
            """
        let expectedBody = """
            # Body

            Actual note body.
            """
        let (root, noteURL) = try seedVault(label: "front-matter", body: markdown)
        defer { removeIfExists(root) }

        try resourceServiceInit(
            vaultRoot: root.path,
            vaultId: "parity-front-matter-\(UUID().uuidString)"
        )

        let body = await SDPage.loadBodyAsyncFromPrimitives(
            pageId: "front-matter-\(UUID().uuidString)",
            filePath: noteURL.path
        )

        #expect(body == expectedBody)
    }

    // MARK: - Utilities

    /// Independent sha256 reference (CryptoKit) for comparing against
    /// the Rust-side `sha2` checksum embedded in `ResourceContent`.
    private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
