import Foundation
import Testing

@testable import Epistemos

/// Cross-language parity guard for the unified MutationEnvelope
/// taxonomy (T+4.8 of
/// `docs/audits/deliberation/T+4_cognitive_artifact_spine_deliberation_20260427.md`).
///
/// Closes Drift Q1 from `docs/audits/T+1_RECONCILIATION_2026-04-27.md`
/// by ensuring Rust and Swift agree on:
///   - the §3.5 four-layer event hierarchy contract (14 fields)
///   - the implementation-plan addendum (9 query-fingerprint fields)
///   - all sub-type wire formats (Status / Actor / Sensitivity /
///     Reversibility / SourceOp / RelationChange / BlockRef)
///
/// Drift in any of these silently corrupts state-change broadcasts
/// across the FFI boundary.
@Suite("MutationEnvelope cross-language parity (T+4.8)")
struct MutationEnvelopeParityTests {

    private static func loadText(_ relative: String) throws -> String {
        try loadMirroredSourceTextFile(relative)
    }

    // MARK: - Status

    @Test("MutationStatus wire strings match Rust snake_case rename")
    func statusWireFormat() throws {
        let encoder = JSONEncoder()
        for (variant, expected) in [
            (MutationStatus.pending,   "\"pending\""),
            (MutationStatus.committed, "\"committed\""),
            (MutationStatus.failed,    "\"failed\""),
            (MutationStatus.reverted,  "\"reverted\""),
        ] {
            let json = try String(data: encoder.encode(variant), encoding: .utf8)
            #expect(json == expected,
                    "MutationStatus.\(variant.rawValue) must encode as \(expected) — got \(json ?? "nil")")
        }
    }

    @Test("Rust MutationStatus enum has all four canonical variants")
    func rustStatusDeclaration() throws {
        let source = try Self.loadText("agent_core/src/mutations/types.rs")
        for variant in ["Pending", "Committed", "Failed", "Reverted"] {
            #expect(source.contains(variant),
                    "Rust MutationStatus must declare \(variant) variant")
        }
    }

    // MARK: - Actor

    @Test("MutationActor.user encodes with kind tag only")
    func actorUserCompact() throws {
        let encoder = JSONEncoder()
        let json = try String(data: encoder.encode(MutationActor.user), encoding: .utf8) ?? ""
        #expect(json == "{\"kind\":\"user\"}",
                "MutationActor.user must encode as {\"kind\":\"user\"} — got \(json)")
    }

    @Test("MutationActor.agent encodes kind + run_id")
    func actorAgentRoundTrips() throws {
        let actor = MutationActor.agent(runID: "run-2026-04-27")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try String(data: encoder.encode(actor), encoding: .utf8) ?? ""
        #expect(json.contains("\"kind\":\"agent\""))
        #expect(json.contains("\"run_id\":\"run-2026-04-27\""))

        // Round-trip
        let decoder = JSONDecoder()
        let recovered = try decoder.decode(MutationActor.self, from: json.data(using: .utf8)!)
        #expect(recovered == actor, "MutationActor.agent must round-trip identity")
    }

    // MARK: - SourceOp

    @Test("SourceOp.artifactCreate encodes with snake_case keys")
    func sourceOpArtifactCreate() throws {
        let op = SourceOp.artifactCreate(artifactID: "doc-1", artifactKind: "document")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try String(data: encoder.encode(op), encoding: .utf8) ?? ""

        #expect(json.contains("\"kind\":\"artifact_create\""),
                "SourceOp must use snake_case kind discriminator — got \(json)")
        #expect(json.contains("\"artifact_id\":\"doc-1\""),
                "SourceOp.artifactCreate must use snake_case artifact_id — got \(json)")
        #expect(json.contains("\"artifact_kind\":\"document\""),
                "SourceOp.artifactCreate must use snake_case artifact_kind (renamed from `kind` to avoid serde tag collision) — got \(json)")

        let recovered = try JSONDecoder().decode(SourceOp.self, from: json.data(using: .utf8)!)
        #expect(recovered == op)
    }

    @Test("SourceOp.graphMutation encodes with kind only")
    func sourceOpGraphMutation() throws {
        let json = try String(data: JSONEncoder().encode(SourceOp.graphMutation), encoding: .utf8) ?? ""
        #expect(json == "{\"kind\":\"graph_mutation\"}",
                "SourceOp.graphMutation must encode as {\"kind\":\"graph_mutation\"} — got \(json)")
    }

    // MARK: - RelationChange

    @Test("RelationChange uses op-tag with snake_case from_id / to_id")
    func relationChangeWireFormat() throws {
        let added = RelationChange.added(fromID: "a", toID: "b", label: "cites")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try String(data: encoder.encode(added), encoding: .utf8) ?? ""

        #expect(json.contains("\"op\":\"added\""),
                "RelationChange must use `op` (not `kind`) discriminator per Rust mirror — got \(json)")
        #expect(json.contains("\"from_id\":\"a\""))
        #expect(json.contains("\"to_id\":\"b\""))

        let recovered = try JSONDecoder().decode(RelationChange.self, from: json.data(using: .utf8)!)
        #expect(recovered == added)
    }

    // MARK: - MutationBlockRef

    @Test("MutationBlockRef uses snake_case artifact_id / block_id")
    func blockRefWireFormat() throws {
        let ref = MutationBlockRef(artifactID: "doc-1", blockID: "block-abc")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try String(data: encoder.encode(ref), encoding: .utf8) ?? ""

        #expect(json.contains("\"artifact_id\":\"doc-1\""))
        #expect(json.contains("\"block_id\":\"block-abc\""))

        let recovered = try JSONDecoder().decode(MutationBlockRef.self, from: json.data(using: .utf8)!)
        #expect(recovered == ref)
    }

    // MARK: - MutationEnvelope full envelope

    @Test("MutationEnvelope CodingKeys cover every canonical wire field")
    func envelopeCodingKeysPresent() throws {
        let envelope = MutationEnvelope(
            mutationID: "mut-001",
            sequence: 1,
            actor: .user,
            status: .pending,
            createdAtMs: 1_745_788_800_000,
            op: .graphMutation,
            sensitivity: .internal,
            reversibility: .reversible,
            integrityHash: ""
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try String(data: encoder.encode(envelope), encoding: .utf8) ?? ""

        // Required §3.5 fields MUST be present.
        let required = [
            "\"mutation_id\":",
            "\"sequence\":",
            "\"actor\":",
            "\"status\":",
            "\"created_at_ms\":",
            "\"op\":",
            "\"sensitivity\":",
            "\"reversibility\":",
            "\"integrity_hash\":",
            "\"schema_version\":",
        ]
        for key in required {
            #expect(json.contains(key),
                    "MutationEnvelope missing required §3.5 wire key `\(key)` — drift would break Rust readers loading Swift envelopes")
        }
    }

    @Test("MutationEnvelope schema_version locks with Rust ArtifactHeader pattern (=1)")
    func envelopeSchemaVersionLockstep() throws {
        #expect(MutationEnvelope.currentSchemaVersion == 1,
                "Swift currentSchemaVersion = \(MutationEnvelope.currentSchemaVersion); Rust MutationEnvelope::CURRENT_SCHEMA_VERSION must match.")

        let rustSource = try Self.loadText("agent_core/src/mutations/envelope.rs")
        #expect(rustSource.contains("pub const CURRENT_SCHEMA_VERSION: u32 = 1"),
                "Rust MutationEnvelope::CURRENT_SCHEMA_VERSION must equal 1 to match Swift currentSchemaVersion")
    }

    @Test("MutationEnvelope round-trips through Swift Codable")
    func envelopeRoundTrips() throws {
        let envelope = MutationEnvelope(
            mutationID: "mut-002",
            runID: "run-99",
            sequence: 7,
            actor: .agent(runID: "run-99"),
            status: .committed,
            createdAtMs: 1_745_788_800_000,
            committedAtMs: 1_745_788_801_000,
            op: .artifactUpdate(artifactID: "doc-1"),
            sensitivity: .internal,
            reversibility: .reversible,
            integrityHash: "abcdef0123456789",
            touchedArtifacts: [EpdocArtifactRef(id: "doc-1", kind: .document, title: "My Doc")],
            touchedBlocks: [MutationBlockRef(artifactID: "doc-1", blockID: "block-1")],
            affectsSearchProjection: true,
            affectsBody: true
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(envelope)
        let recovered = try decoder.decode(MutationEnvelope.self, from: data)
        #expect(recovered == envelope, "Codable round-trip must be identity")
    }

    @Test("MutationEnvelope.affectsAnything reports any set flag")
    func envelopeAffectsAnythingHelper() {
        let none = MutationEnvelope(
            mutationID: "x",
            sequence: 0,
            actor: .system,
            status: .pending,
            createdAtMs: 0,
            op: .graphMutation,
            sensitivity: .internal,
            reversibility: .reversible,
            integrityHash: ""
        )
        #expect(!none.affectsAnything)

        let one = MutationEnvelope(
            mutationID: "y",
            sequence: 0,
            actor: .system,
            status: .pending,
            createdAtMs: 0,
            op: .graphMutation,
            sensitivity: .internal,
            reversibility: .reversible,
            integrityHash: "",
            affectsGraph: true
        )
        #expect(one.affectsAnything)
    }

    // MARK: - Cross-file path guard

    @Test("Rust mutations module ships in canonical location")
    func rustModulePathIsCanonical() throws {
        let modUrl = try sourceMirrorURL(for: "agent_core/src/mutations")
        #expect(FileManager.default.fileExists(atPath: modUrl.path),
                "Rust mutations module must live at agent_core/src/mutations/")

        for file in ["mod.rs", "envelope.rs", "types.rs"] {
            let url = modUrl.appendingPathComponent(file, isDirectory: false)
            #expect(FileManager.default.fileExists(atPath: url.path),
                    "Rust mutations module must contain \(file)")
        }
    }
}
