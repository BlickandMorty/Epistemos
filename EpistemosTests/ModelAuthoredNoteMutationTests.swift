import Testing
@testable import Epistemos

@Suite("Model Authored Note Mutation")
struct ModelAuthoredNoteMutationTests {
    @Test("append section plan builds committed typed mutation envelope")
    func appendSectionPlanBuildsCommittedTypedMutationEnvelope() throws {
        let plan = try ModelAuthoredNoteMutation.appendSectionPlan(
            artifactID: "note-1",
            title: "Typed Mutation Note",
            beforeBody: "Existing body.",
            insertedMarkdown: "Model-authored paragraph.",
            blockID: "block-typed-1",
            runID: "run-typed-1",
            sequence: 7,
            causedByEventID: "event-1",
            approvalID: "approval-1",
            createdAtMs: 1_800_000_000_000
        )

        #expect(plan.afterBody == "Existing body.\n\nModel-authored paragraph.")
        #expect(plan.rollback.body == "Existing body.")
        #expect(plan.envelope.status == .committed)
        #expect(plan.envelope.actor == .agent(runID: "run-typed-1"))
        #expect(plan.envelope.runID == "run-typed-1")
        #expect(plan.envelope.sequence == 7)
        #expect(plan.envelope.causedByEventID == "event-1")
        #expect(plan.envelope.approvalID == "approval-1")
        #expect(plan.envelope.op == .artifactUpdate(artifactID: "note-1"))
        #expect(plan.envelope.touchedArtifacts == [
            EpdocArtifactRef(id: "note-1", kind: .proseNote, title: "Typed Mutation Note")
        ])
        #expect(plan.envelope.touchedBlocks == [
            MutationBlockRef(artifactID: "note-1", blockID: "block-typed-1")
        ])
        #expect(plan.envelope.affectsBody)
        #expect(plan.envelope.affectsOutline)
        #expect(plan.envelope.affectsSearchProjection)
        #expect(plan.envelope.affectsSummary)
        #expect(plan.envelope.reversibility == .reversible)
        #expect(plan.envelope.integrityHash.hasPrefix("sha256:"))
        #expect(plan.witness.envelopeMutationID == plan.envelope.mutationID)
        #expect(plan.witness.beforeBodyHash == plan.rollback.bodyHash)
        #expect(plan.witness.afterBodyHash != plan.witness.beforeBodyHash)
        #expect(plan.traceID == "tri-fusion-\(plan.envelope.mutationID)")
    }

    @Test("commit persists body and envelope together")
    func commitPersistsBodyAndEnvelopeTogether() throws {
        let plan = try ModelAuthoredNoteMutation.appendSectionPlan(
            artifactID: "note-2",
            title: nil,
            beforeBody: "Before",
            insertedMarkdown: "After",
            blockID: "block-2",
            runID: "run-2",
            sequence: 1,
            createdAtMs: 1_800_000_000_001
        )
        var body = plan.beforeBody
        var savedEnvelope: MutationEnvelope?
        var savedTraceID: String?

        let witness = try ModelAuthoredNoteMutation.commit(
            plan,
            persistBody: { body = $0 },
            saveEnvelope: { envelope, traceID in
                savedEnvelope = envelope
                savedTraceID = traceID
                return true
            }
        )

        #expect(body == plan.afterBody)
        #expect(savedEnvelope == plan.envelope)
        #expect(savedTraceID == plan.traceID)
        #expect(witness == plan.witness)
    }

    @Test("commit rolls body back if envelope persistence fails")
    func commitRollsBodyBackIfEnvelopePersistenceFails() throws {
        let plan = try ModelAuthoredNoteMutation.appendSectionPlan(
            artifactID: "note-3",
            title: nil,
            beforeBody: "Before",
            insertedMarkdown: "After",
            blockID: "block-3",
            runID: "run-3",
            sequence: 1,
            createdAtMs: 1_800_000_000_002
        )
        var body = plan.beforeBody

        do {
            _ = try ModelAuthoredNoteMutation.commit(
                plan,
                persistBody: { body = $0 },
                saveEnvelope: { _, _ in false }
            )
            Issue.record("Expected envelope persistence failure")
        } catch ModelAuthoredNoteMutationError.envelopePersistenceFailed {
            #expect(body == plan.beforeBody)
        }
    }

    @Test("invalid model-authored edits are rejected before mutation construction")
    func invalidModelAuthoredEditsAreRejectedBeforeMutationConstruction() throws {
        #expect(throws: ModelAuthoredNoteMutationError.emptyArtifactID) {
            _ = try ModelAuthoredNoteMutation.appendSectionPlan(
                artifactID: " ",
                title: nil,
                beforeBody: "",
                insertedMarkdown: "body",
                blockID: "b",
                runID: "r",
                sequence: 1
            )
        }

        #expect(throws: ModelAuthoredNoteMutationError.emptyInsertion) {
            _ = try ModelAuthoredNoteMutation.appendSectionPlan(
                artifactID: "note",
                title: nil,
                beforeBody: "",
                insertedMarkdown: " ",
                blockID: "b",
                runID: "r",
                sequence: 1
            )
        }
    }

    @Test("source guard keeps typed mutation commit from bypassing envelope")
    func sourceGuardKeepsTypedMutationCommitFromBypassingEnvelope() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Engine/ModelAuthoredNoteMutation.swift"
        )

        #expect(source.contains("MutationEnvelope("))
        #expect(source.contains("actor: .agent(runID: runID)"))
        #expect(source.contains("op: .artifactUpdate(artifactID: artifactID)"))
        #expect(source.contains("saveEnvelope(plan.envelope, plan.traceID)"))
        #expect(source.contains("try? persistBody(plan.rollback.body)"))
        #expect(!source.contains("page.saveBody("))
        #expect(!source.contains("DispatchQueue.main.asyncAfter"))
    }
}
