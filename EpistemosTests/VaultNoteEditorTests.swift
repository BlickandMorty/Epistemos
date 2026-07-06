import Testing
import Foundation
@testable import Epistemos

/// VAULT-DEEP-INTEGRATION §720 (#4): file-level agent note editing. Verifies the HONEST + ATOMIC contract —
/// writes only on full success, writes NOTHING when the atomic batch fails (missing anchor), and propagates
/// read/write errors. Injectable read/write so no filesystem is touched.
@Suite("Vault note editor — atomic, honest file-level agent edits")
struct VaultNoteEditorTests {
    private nonisolated final class Box: @unchecked Sendable {
        var stored: String
        var writeCount = 0
        init(_ s: String) { stored = s }
    }

    private func editor(_ box: Box, readError: Error? = nil) -> VaultNoteEditor {
        VaultNoteEditor(
            read: { _ in if let readError { throw readError }; return box.stored },
            write: { _, content in box.stored = content; box.writeCount += 1 }
        )
    }

    private let url = URL(fileURLWithPath: "/tmp/note.md")

    @Test("successful batch writes the new content once")
    func successWrites() async throws {
        let box = Box("foo")
        let result = try await editor(box).applyEdits([.replaceFirst(find: "foo", with: "bar"), .append("end")], to: url)
        #expect(result == "bar\nend")
        #expect(box.stored == "bar\nend")
        #expect(box.writeCount == 1)
    }

    @Test("a failing batch throws editDidNotApply and writes NOTHING (no partial corruption)")
    func atomicFailureWritesNothing() async {
        let box = Box("note")
        await expectVaultNoteEditError(.editDidNotApply) {
            try await editor(box).applyEdits([.append("ok"), .replaceFirst(find: "absent", with: "x")], to: url)
        }
        #expect(box.stored == "note")   // unchanged
        #expect(box.writeCount == 0)    // never wrote
    }

    @Test("read errors propagate (nothing written)")
    func readErrorPropagates() async {
        struct E: Error {}
        let box = Box("x")
        do {
            _ = try await editor(box, readError: E()).applyEdits([.append("y")], to: url)
            Issue.record("Expected read error to propagate")
        } catch {
            // expected
        }
        #expect(box.writeCount == 0)
    }

    // MARK: - Provenance (§720 #4) — every agent edit records a MutationEnvelope

    private let context = AgentEditProvenanceContext(
        artifactID: "note-123", runID: "run-abc", sequence: 7, title: "My Note")

    @Test("the provenance envelope is a committed agent artifactUpdate over the right artifact")
    func envelopeShape() {
        let envelope = AgentNoteEditProvenance.envelope(
            context: context, beforeBody: "old", afterBody: "old\nnew", createdAtMs: 1_700_000_000_000)
        #expect(envelope.actor == .agent(runID: "run-abc"))
        #expect(envelope.status == .committed)
        #expect(envelope.op == .artifactUpdate(artifactID: "note-123"))
        #expect(envelope.sequence == 7)
        #expect(envelope.affectsBody)
        #expect(envelope.affectsSearchProjection)
        #expect(envelope.integrityHash.hasPrefix("sha256:"))
        #expect(envelope.touchedArtifacts.first?.id == "note-123")
        // deterministic: same before/after/context → identical id + hash (idempotent in the log).
        let again = AgentNoteEditProvenance.envelope(
            context: context, beforeBody: "old", afterBody: "old\nnew", createdAtMs: 999)
        #expect(again.mutationID == envelope.mutationID)
        #expect(again.integrityHash == envelope.integrityHash)
        #expect(AgentNoteEditProvenance.traceID(for: envelope) == "tri-fusion-\(envelope.mutationID)")
    }

    @Test("a successful edit writes the body AND records the envelope once")
    func recordsEnvelopeOnSuccess() async throws {
        let box = Box("foo")
        let captured = Box("")  // reuse Box as a capture cell (stores the recorded artifact id)
        let result = try await editor(box).applyEdits(
            [.replaceFirst(find: "foo", with: "bar")], to: url,
            provenance: context, now: { 1_700_000_000_000 },
            recordEnvelope: { envelope, _ in
                if case .artifactUpdate(let id) = envelope.op { captured.stored = id }
                captured.writeCount += 1
                return true
            })
        #expect(result == "bar")
        #expect(box.stored == "bar")
        #expect(box.writeCount == 1)
        #expect(captured.stored == "note-123")
        #expect(captured.writeCount == 1)
    }

    @Test("a missing anchor records NOTHING and writes NOTHING (honest atomic with provenance)")
    func noProvenanceOnFailedEdit() async {
        let box = Box("note")
        let captured = Box("")
        await expectVaultNoteEditError(.editDidNotApply) {
            try await editor(box).applyEdits(
                [.replaceFirst(find: "absent", with: "x")], to: url,
                provenance: context,
                recordEnvelope: { _, _ in captured.writeCount += 1; return true })
        }
        #expect(box.writeCount == 0)
        #expect(captured.writeCount == 0)  // no edit → no provenance
    }

    @Test("a failed envelope save throws provenanceNotRecorded — but the body IS already written")
    func provenanceFailureIsReported() async {
        let box = Box("foo")
        await expectVaultNoteEditError(.provenanceNotRecorded) {
            try await editor(box).applyEdits(
                [.append("bar")], to: url, provenance: context,
                recordEnvelope: { _, _ in false })  // EventStore unavailable
        }
        #expect(box.stored == "foo\nbar")  // body persisted (the edit is the truth)
        #expect(box.writeCount == 1)
    }

    private func expectVaultNoteEditError(
        _ expected: VaultNoteEditError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected \(expected), but operation succeeded")
        } catch let error as VaultNoteEditError {
            #expect(error == expected)
        } catch {
            Issue.record("Expected \(expected), got \(error)")
        }
    }
}
