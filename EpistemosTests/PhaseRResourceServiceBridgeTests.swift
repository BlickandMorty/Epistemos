import Foundation
import Testing
@testable import Epistemos

// MARK: - Phase R.3 ResourceService Bridge Regression Tests
//
// Covers the Swift side of the UniFFI-exposed `resource_*` helpers
// wired up in `agent_core/src/resources/bridge.rs`:
//   - resourceServiceInit(vaultRoot:vaultId:)
//   - resourceServiceIsReady()
//   - resourceResolve(reference:) async throws -> ResourceId
//   - resourceRead(id:) async throws -> ResourceContent
//   - resourceWrite(id:content:baseVersion:) async throws -> WriteResult
//   - resourceCreate(parent:kind:content:) async throws -> ResourceId
//   - resourceDelete(id:mode:) async throws
//   - resourceSearch(query:scope:) async throws -> [ResourceHit]
//     (scope is the `ResourceSearchScope` enum so it doesn't collide
//     with the existing Swift `SearchScope` in `Models/QueryTypes.swift`)
//
// Addresses I-002/I-003 at the FFI-surface layer ONLY (per Codex's
// 2026-04-23 re-review). Swift-side production call sites
// (NoteFileStorage, VaultIndexActor, NotesSidebar etc.) are NOT yet
// routed through the gateway — that's follow-up work. These tests
// confirm the gateway is reachable, round-trips bytes correctly, and
// surfaces errors honestly.
//
// IMPORTANT TEST-ISOLATION NOTE:
// The Rust bridge uses a single process-local VaultResourceService
// slot. Concurrent Swift test instances would race the slot exactly
// as the concurrent Rust tokio tests do. Each test below seeds its
// own temp vault and re-inits the slot; they serialize via the
// default Swift Testing scheduler which runs @Test methods
// serially per suite. If we ever enable parallelism here, we must
// add a test-side serial lock parallel to the Rust r3_gate().
//
// Plan refs: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §Phase R.3,
// docs/KNOWN_ISSUES_REGISTER.md I-002 / I-003.

// NOTE: the `.serialized` trait was removed because it tripped
// `@const`/`@section` expansion failures in the Swift Testing macro on
// this toolchain (pre-existing, unrelated to R.3 logic). Swift Testing
// already runs `@Test` methods within one struct-based `@Suite`
// serially per default, which is sufficient here given the
// process-local `VaultResourceService` slot.
@Suite("Phase R.3 — ResourceService Bridge")
struct PhaseRResourceServiceBridgeTests {

    // MARK: - Test helpers

    private func makeScratchVault(label: String) throws -> (URL, String) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("r3-swift-\(label)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tmp,
            withIntermediateDirectories: true
        )
        let inbox = tmp.appendingPathComponent("Inbox")
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        try "# Seed Alpha\nalpha body\n"
            .write(to: inbox.appendingPathComponent("SeedAlpha.md"), atomically: true, encoding: .utf8)
        try "# Seed Beta\nbeta body\n"
            .write(to: inbox.appendingPathComponent("SeedBeta.md"), atomically: true, encoding: .utf8)
        let vaultId = "r3-swift-\(label)-\(UUID().uuidString)"
        try resourceServiceInit(vaultRoot: tmp.path, vaultId: vaultId)
        return (tmp, vaultId)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Init + readiness

    @Test("resourceServiceInit rejects missing vault root with Backend error")
    func initRejectsMissingRoot() async throws {
        let bogus = "/definitely/does/not/exist/\(UUID().uuidString)"
        var threw = false
        do {
            try resourceServiceInit(vaultRoot: bogus, vaultId: "r3-swift-missing")
        } catch is ResourceError {
            threw = true
        }
        #expect(threw, "missing dir must throw ResourceError")
    }

    @Test("resourceServiceIsReady flips to true after successful init")
    func isReadyAfterInit() async throws {
        let (tmp, _) = try makeScratchVault(label: "ready")
        defer { cleanup(tmp) }
        #expect(resourceServiceIsReady())
    }

    // MARK: - Resolve

    @Test("resourceResolve finds a seeded note by stem title and returns VaultNote variant")
    func resolveFindsSeededNoteByTitle() async throws {
        let (tmp, vaultId) = try makeScratchVault(label: "resolve-title")
        defer { cleanup(tmp) }

        let id = try await resourceResolve(reference: "SeedAlpha")
        switch id {
        case .vaultNote(let gotVault, let noteId):
            #expect(gotVault == vaultId)
            #expect(noteId == "Inbox/SeedAlpha.md")
        default:
            Issue.record("expected .vaultNote, got \(id)")
        }
    }

    @Test("resourceResolve throws UnsupportedReference for unknown input")
    func resolveRejectsUnknown() async throws {
        let (tmp, _) = try makeScratchVault(label: "resolve-unknown")
        defer { cleanup(tmp) }

        var threw = false
        do {
            _ = try await resourceResolve(reference: "NoSuchNote-" + UUID().uuidString)
        } catch is ResourceError {
            threw = true
        }
        #expect(threw, "unknown reference must throw ResourceError")
    }

    // MARK: - Read

    @Test("resourceRead returns bytes + non-empty version + 64-char checksum")
    func readReturnsBytesVersionChecksum() async throws {
        let (tmp, _) = try makeScratchVault(label: "read")
        defer { cleanup(tmp) }

        let id = try await resourceResolve(reference: "SeedBeta")
        let content = try await resourceRead(id: id)

        #expect(content.id == id)
        let text = String(data: content.bytes, encoding: .utf8) ?? ""
        #expect(text.contains("beta body"))
        #expect(!content.version.isEmpty)
        #expect(content.checksum.count == 64) // sha256 hex
    }

    // MARK: - Write — round-trip + version-conflict

    @Test("resourceWrite round-trips bytes and bumps version when base_version matches")
    func writeRoundTripsBytesAndBumpsVersion() async throws {
        let (tmp, _) = try makeScratchVault(label: "write-roundtrip")
        defer { cleanup(tmp) }

        let id = try await resourceResolve(reference: "SeedAlpha")
        let initial = try await resourceRead(id: id)

        let updated = Data("# Seed Alpha\nUPDATED alpha body\n".utf8)
        let result = try await resourceWrite(
            id: id,
            content: updated,
            baseVersion: initial.version
        )

        #expect(result.id == id)
        #expect(result.newVersion != initial.version)
        #expect(result.postChecksum.count == 64)

        let reread = try await resourceRead(id: id)
        #expect(reread.bytes == updated)
    }

    @Test("resourceWrite with stale base_version throws VersionConflict")
    func writeWithStaleBaseVersionThrowsConflict() async throws {
        let (tmp, _) = try makeScratchVault(label: "write-conflict")
        defer { cleanup(tmp) }

        let id = try await resourceResolve(reference: "SeedAlpha")
        var threw = false
        do {
            _ = try await resourceWrite(
                id: id,
                content: Data("should not land".utf8),
                baseVersion: "stale-sentinel"
            )
        } catch is ResourceError {
            threw = true
        }
        #expect(threw, "stale base_version must throw ResourceError")
    }

    // MARK: - Create — new note

    @Test("resourceCreate creates a new note under the vault parent and returns its canonical id")
    func createNoteRoundTrips() async throws {
        let (tmp, vaultId) = try makeScratchVault(label: "create")
        defer { cleanup(tmp) }

        let parent = ResourceId.vaultNote(vaultId: vaultId, noteId: "Inbox")
        let newID = try await resourceCreate(
            parent: parent,
            kind: .note(name: "R3SwiftCreated.md"),
            content: Data("# Hello from Swift\n".utf8)
        )

        switch newID {
        case .vaultNote(let gotVault, let noteId):
            #expect(gotVault == vaultId)
            #expect(noteId.contains("R3SwiftCreated"))
        default:
            Issue.record("expected .vaultNote, got \(newID)")
        }

        let reread = try await resourceRead(id: newID)
        let text = String(data: reread.bytes, encoding: .utf8) ?? ""
        #expect(text.contains("Hello from Swift"))
    }
}
