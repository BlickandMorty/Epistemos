import CryptoKit
import Foundation

nonisolated enum ModelAuthoredNoteMutationError: Error, Equatable {
    case emptyArtifactID
    case emptyBlockID
    case emptyRunID
    case emptyInsertion
    case insertionTooLarge(maxCharacters: Int)
    case bodyPersistenceFailed(String)
    case envelopePersistenceFailed
}

nonisolated struct ModelAuthoredNoteMutationWitness: Equatable, Sendable {
    let mutationID: String
    let runID: String
    let artifactID: String
    let blockID: String
    let beforeBodyHash: String
    let afterBodyHash: String
    let rollbackBodyHash: String
    let envelopeMutationID: String
    let createdAtMs: Int64
    let committedAtMs: Int64
}

nonisolated struct ModelAuthoredNoteMutationRollback: Equatable, Sendable {
    let body: String
    let bodyHash: String
}

nonisolated struct ModelAuthoredNoteMutationPlan: Equatable, Sendable {
    let beforeBody: String
    let afterBody: String
    let rollback: ModelAuthoredNoteMutationRollback
    let envelope: MutationEnvelope
    let witness: ModelAuthoredNoteMutationWitness
    let traceID: String
}

nonisolated enum ModelAuthoredNoteMutation {
    static let maxInsertedMarkdownCharacters = 24_000

    static func appendSectionPlan(
        artifactID: String,
        title: String?,
        beforeBody: String,
        insertedMarkdown: String,
        blockID: String,
        runID: String,
        sequence: UInt64,
        causedByEventID: String? = nil,
        approvalID: String? = nil,
        createdAtMs: Int64 = currentTimeMs()
    ) throws -> ModelAuthoredNoteMutationPlan {
        let artifactID = artifactID.trimmingCharacters(in: .whitespacesAndNewlines)
        let blockID = blockID.trimmingCharacters(in: .whitespacesAndNewlines)
        let runID = runID.trimmingCharacters(in: .whitespacesAndNewlines)
        let insertion = insertedMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !artifactID.isEmpty else { throw ModelAuthoredNoteMutationError.emptyArtifactID }
        guard !blockID.isEmpty else { throw ModelAuthoredNoteMutationError.emptyBlockID }
        guard !runID.isEmpty else { throw ModelAuthoredNoteMutationError.emptyRunID }
        guard !insertion.isEmpty else { throw ModelAuthoredNoteMutationError.emptyInsertion }
        guard insertion.count <= maxInsertedMarkdownCharacters else {
            throw ModelAuthoredNoteMutationError.insertionTooLarge(maxCharacters: maxInsertedMarkdownCharacters)
        }

        let separator: String
        if beforeBody.isEmpty || beforeBody.hasSuffix("\n\n") {
            separator = ""
        } else if beforeBody.hasSuffix("\n") {
            separator = "\n"
        } else {
            separator = "\n\n"
        }

        let afterBody = beforeBody + separator + insertion
        let beforeHash = sha256String(beforeBody)
        let afterHash = sha256String(afterBody)
        let mutationID = "model-note-\(shortHash([artifactID, blockID, runID, beforeHash, afterHash]))"
        let integrityHash = sha256String(
            [
                mutationID,
                artifactID,
                blockID,
                runID,
                beforeHash,
                afterHash,
                insertion,
            ].joined(separator: "\u{1f}")
        )
        let committedAtMs = createdAtMs
        let envelope = MutationEnvelope(
            mutationID: mutationID,
            runID: runID,
            sequence: sequence,
            causedByEventID: causedByEventID,
            actor: .agent(runID: runID),
            approvalID: approvalID,
            status: .committed,
            createdAtMs: createdAtMs,
            committedAtMs: committedAtMs,
            op: .artifactUpdate(artifactID: artifactID),
            sensitivity: .internal,
            reversibility: .reversible,
            integrityHash: integrityHash,
            touchedArtifacts: [
                EpdocArtifactRef(id: artifactID, kind: .proseNote, title: title)
            ],
            touchedBlocks: [
                MutationBlockRef(artifactID: artifactID, blockID: blockID)
            ],
            affectsSummary: true,
            affectsOutline: true,
            affectsSearchProjection: true,
            affectsBody: true
        )
        let rollback = ModelAuthoredNoteMutationRollback(body: beforeBody, bodyHash: beforeHash)
        let witness = ModelAuthoredNoteMutationWitness(
            mutationID: mutationID,
            runID: runID,
            artifactID: artifactID,
            blockID: blockID,
            beforeBodyHash: beforeHash,
            afterBodyHash: afterHash,
            rollbackBodyHash: rollback.bodyHash,
            envelopeMutationID: envelope.mutationID,
            createdAtMs: createdAtMs,
            committedAtMs: committedAtMs
        )

        return ModelAuthoredNoteMutationPlan(
            beforeBody: beforeBody,
            afterBody: afterBody,
            rollback: rollback,
            envelope: envelope,
            witness: witness,
            traceID: "tri-fusion-\(mutationID)"
        )
    }

    @discardableResult
    static func commit(
        _ plan: ModelAuthoredNoteMutationPlan,
        persistBody: (String) throws -> Void,
        saveEnvelope: (MutationEnvelope, String?) -> Bool = { envelope, traceID in
            EventStore.shared?.saveMutationEnvelope(envelope, traceId: traceID) ?? false
        }
    ) throws -> ModelAuthoredNoteMutationWitness {
        do {
            try persistBody(plan.afterBody)
        } catch {
            try? persistBody(plan.rollback.body)
            throw ModelAuthoredNoteMutationError.bodyPersistenceFailed(error.localizedDescription)
        }

        guard saveEnvelope(plan.envelope, plan.traceID) else {
            try? persistBody(plan.rollback.body)
            throw ModelAuthoredNoteMutationError.envelopePersistenceFailed
        }

        return plan.witness
    }

    private static func currentTimeMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1_000)
    }

    private static func sha256String(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func shortHash(_ parts: [String]) -> String {
        String(sha256String(parts.joined(separator: "\u{1f}")).dropFirst("sha256:".count).prefix(16))
    }
}
