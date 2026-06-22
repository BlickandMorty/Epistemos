import CryptoKit
import Foundation

/// VAULT-DEEP-INTEGRATION §720 (#4): the PROVENANCE half of in-editor agent edits. When an agent applies an
/// `AgentNoteEdit` batch to a note (via `VaultNoteEditor`), the change is recorded as a COMMITTED agent
/// `MutationEnvelope` (`SourceOp.artifactUpdate`) so every model-authored note edit has an auditable trail in
/// the `EventStore` — the same provenance spine `ModelAuthoredNoteMutation` uses (reuse the existing model,
/// never a parallel one). This is the editor-agnostic, filesystem-free CORE; it's pure + deterministic so it
/// unit-tests without an app or a database.
nonisolated struct AgentEditProvenanceContext: Sendable, Equatable {
    /// The note's stable artifact id (the `EpdocArtifactRef` id — the note this edit touches).
    let artifactID: String
    /// The agent run that authored the edit (becomes `MutationActor.agent(runID:)`).
    let runID: String
    /// Monotonic mutation sequence within the run (the §3.5 ordering field).
    let sequence: UInt64
    /// Optional human title for the touched-artifact ref (display/debug only).
    let title: String?

    init(artifactID: String, runID: String, sequence: UInt64, title: String? = nil) {
        self.artifactID = artifactID
        self.runID = runID
        self.sequence = sequence
        self.title = title
    }
}

nonisolated enum AgentNoteEditProvenance {
    /// Build a COMMITTED agent `artifactUpdate` envelope for a note edit that took `beforeBody` → `afterBody`.
    /// Mirrors `ModelAuthoredNoteMutation`'s envelope shape exactly (agent actor, sha256 integrity hash over
    /// the before/after bodies, `affectsBody` + `affectsSearchProjection`, the note as the touched artifact).
    /// DETERMINISTIC: the same context + before/after always yields the same `mutationID`/`integrityHash`, so
    /// a replayed edit is idempotent in the provenance log (no `Date()`/random in the id).
    static func envelope(
        context: AgentEditProvenanceContext,
        beforeBody: String,
        afterBody: String,
        createdAtMs: Int64
    ) -> MutationEnvelope {
        let beforeHash = sha256String(beforeBody)
        let afterHash = sha256String(afterBody)
        let mutationID = "agent-note-edit-\(shortHash([context.artifactID, context.runID, beforeHash, afterHash]))"
        let integrityHash = sha256String(
            [mutationID, context.artifactID, context.runID, beforeHash, afterHash].joined(separator: "\u{1f}")
        )
        return MutationEnvelope(
            mutationID: mutationID,
            runID: context.runID,
            sequence: context.sequence,
            actor: .agent(runID: context.runID),
            status: .committed,
            createdAtMs: createdAtMs,
            committedAtMs: createdAtMs,
            op: .artifactUpdate(artifactID: context.artifactID),
            sensitivity: .internal,
            reversibility: .reversible,
            integrityHash: integrityHash,
            touchedArtifacts: [
                EpdocArtifactRef(id: context.artifactID, kind: .proseNote, title: context.title)
            ],
            affectsSearchProjection: true,
            affectsBody: true
        )
    }

    /// `tri-fusion-<mutationID>` trace id, matching `ModelAuthoredNoteMutation`'s convention so both
    /// model-authored-mutation surfaces share one trace namespace in the EventStore.
    static func traceID(for envelope: MutationEnvelope) -> String {
        "tri-fusion-\(envelope.mutationID)"
    }

    private static func sha256String(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func shortHash(_ parts: [String]) -> String {
        String(sha256String(parts.joined(separator: "\u{1f}")).dropFirst("sha256:".count).prefix(16))
    }
}
