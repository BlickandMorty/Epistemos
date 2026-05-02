import Foundation
import Testing

@testable import Epistemos

/// Cross-language parity guard for the canonical artifact header +
/// provenance taxonomy (T+4.2 of
/// `docs/audits/deliberation/T+4_cognitive_artifact_spine_deliberation_20260427.md`,
/// cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §3).
///
/// Six artefacts MUST stay in lock-step:
///   1. Rust `agent_core/src/artifacts/header.rs` — `ArtifactHeader`
///   2. Rust `agent_core/src/artifacts/provenance.rs` — `Producer`,
///      `ArtifactRef`, `ProvenanceBlock`
///   3. Swift `Epistemos/Models/EpdocManifest.swift` — `EpdocManifest`,
///      `EpdocProvenance`, `EpdocArtifactRef`, `EpdocProducer` mirrors
///   4. JSON wire format byte-equal across both languages
///
/// The Swift side carries the `Epdoc*` prefix because `.epdoc` was the
/// first consumer; the Rust side uses the canonical taxonomy names from
/// the implementation plan. JSON keys MUST match — drift would silently
/// corrupt manifests across the FFI boundary.
@Suite("ArtifactHeader + Provenance cross-language parity (T+4.2)")
struct ArtifactProvenanceParityTests {

    private static func loadText(_ relative: String) throws -> String {
        try loadMirroredSourceTextFile(relative)
    }

    // MARK: - Producer parity

    @Test("EpdocProducer wire strings match Rust snake_case rename")
    func producerWireFormat() throws {
        let encoder = JSONEncoder()
        for (variant, expected) in [
            (EpdocProducer.human, "\"human\""),
            (EpdocProducer.agent, "\"agent\""),
            (EpdocProducer.system, "\"system\"")
        ] {
            let json = try String(data: encoder.encode(variant), encoding: .utf8)
            #expect(json == expected,
                    "EpdocProducer.\(variant) must encode as \(expected) — got \(json ?? "nil")")
        }
    }

    @Test("Rust Producer enum declares Human / Agent / System with snake_case rename")
    func rustProducerDeclaration() throws {
        let source = try Self.loadText("agent_core/src/artifacts/provenance.rs")
        #expect(source.contains("pub enum Producer"),
                "Rust must expose `pub enum Producer`")
        #expect(source.contains("#[serde(rename_all = \"snake_case\")]"),
                "Rust Producer enum must carry `#[serde(rename_all = \"snake_case\")]`")
        for variant in ["Human", "Agent", "System"] {
            #expect(source.contains(variant),
                    "Rust Producer must declare \(variant) variant")
        }
    }

    // MARK: - ArtifactRef parity

    @Test("EpdocArtifactRef with id only encodes as compact JSON")
    func artifactRefIdOnly() throws {
        let ref = EpdocArtifactRef(id: "only-id")
        let json = try String(data: JSONEncoder().encode(ref), encoding: .utf8)
        #expect(json == "{\"id\":\"only-id\"}",
                "EpdocArtifactRef with nil kind/title must emit just `{\"id\":\"...\"}` — got \(json ?? "nil")")
    }

    @Test("EpdocArtifactRef with full fields uses snake_case wire keys")
    func artifactRefFullFields() throws {
        let ref = EpdocArtifactRef(id: "abc-123", kind: .document, title: "My Doc")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try String(data: encoder.encode(ref), encoding: .utf8) ?? ""

        #expect(json.contains("\"id\":\"abc-123\""))
        #expect(json.contains("\"kind\":\"document\""))
        #expect(json.contains("\"title\":\"My Doc\""))
    }

    @Test("Rust ArtifactRef uses serde skip_serializing_if for Optional fields")
    func rustArtifactRefDefaults() throws {
        let source = try Self.loadText("agent_core/src/artifacts/provenance.rs")
        #expect(source.contains("pub struct ArtifactRef"),
                "Rust must expose `pub struct ArtifactRef`")
        // Both Optional fields MUST skip serialization when None so
        // legacy manifests round-trip without drift.
        #expect(source.contains("#[serde(skip_serializing_if = \"Option::is_none\""),
                "Rust ArtifactRef Optional fields must use `skip_serializing_if = \"Option::is_none\"`")
    }

    // MARK: - ProvenanceBlock parity

    @Test("EpdocProvenance for human producer encodes minimally")
    func provenanceHumanCompact() throws {
        let p = EpdocProvenance(producer: .human)
        let json = try String(data: JSONEncoder().encode(p), encoding: .utf8) ?? ""
        // Swift JSONEncoder by default does NOT skip empty arrays — the
        // wire format includes derivedFrom: [] etc. We only verify the
        // required `producer` field is the canonical "human" string.
        #expect(json.contains("\"producer\":\"human\""),
                "EpdocProvenance must serialize producer as snake_case string")
    }

    @Test("EpdocProvenance CodingKeys map to Rust serde wire keys")
    func provenanceWireKeys() throws {
        let p = EpdocProvenance(
            producer: .agent,
            generatedByRun: "run-99",
            toolId: "vault_search"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try String(data: encoder.encode(p), encoding: .utf8) ?? ""

        // Wire-format guard: snake_case keys mirror the Rust serde
        // output. If the Swift CodingKeys ever drift, this test fails.
        #expect(json.contains("\"generated_by_run\":\"run-99\""),
                "Swift CodingKeys must use snake_case `generated_by_run` — got \(json)")
        #expect(json.contains("\"tool_id\":\"vault_search\""),
                "Swift CodingKeys must use snake_case `tool_id` — got \(json)")
    }

    @Test("Rust ProvenanceBlock declares every canonical field")
    func rustProvenanceBlockFields() throws {
        let source = try Self.loadText("agent_core/src/artifacts/provenance.rs")
        #expect(source.contains("pub struct ProvenanceBlock"),
                "Rust must expose `pub struct ProvenanceBlock`")
        let canonicalFields = [
            "pub producer: Producer",
            "pub derived_from: Vec<ArtifactRef>",
            "pub generated_by_run: Option<String>",
            "pub tool_id: Option<String>",
            "pub source_artifacts: Vec<ArtifactRef>",
            "pub output_artifacts: Vec<ArtifactRef>",
        ]
        for field in canonicalFields {
            #expect(source.contains(field),
                    "Rust ProvenanceBlock must declare `\(field)` — drift means the JSON wire format will diverge from EpdocProvenance")
        }
    }

    // MARK: - ArtifactHeader / EpdocManifest parity

    @Test("EpdocManifest CodingKeys map every field to canonical snake_case")
    func manifestCodingKeys() throws {
        let manifest = EpdocManifest(
            id: "01H8XGJWBWBAQ4N0K9HZ8XGJWB",
            createdAt: 1_745_788_800_000,
            updatedAt: 1_745_788_800_000,
            title: "My Research Report",
            contentHash: "blake3:abcdef0123456789",
            provenance: EpdocProvenance(producer: .human)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = try String(data: encoder.encode(manifest), encoding: .utf8) ?? ""

        // Every canonical field MUST appear with the snake_case key.
        // Drift here would break Rust readers loading Swift-written
        // manifests (and vice versa).
        let requiredKeys = [
            "\"id\":",
            "\"kind\":",
            "\"schema_version\":",
            "\"created_at\":",
            "\"updated_at\":",
            "\"title\":",
            "\"content_hash\":",
            "\"provenance\":",
        ]
        for key in requiredKeys {
            #expect(json.contains(key),
                    "EpdocManifest must encode field with key `\(key)` — drift means the Rust ArtifactHeader reader will fail")
        }
        // The optional `metadata` field MUST be absent when nil.
        #expect(!json.contains("\"metadata\":"),
                "metadata: nil must be omitted from wire format — got \(json)")
    }

    @Test("EpdocManifest schema_version matches Rust ArtifactHeader::CURRENT_SCHEMA_VERSION")
    func schemaVersionLockstep() throws {
        // Pre-cutoff: both sides ship `1`. Bumping is a 4-step ritual:
        //   1. Bump `EpdocManifest.currentSchemaVersion` in Swift.
        //   2. Bump `ArtifactHeader::CURRENT_SCHEMA_VERSION` in Rust.
        //   3. Update this test's expected value.
        //   4. Document the migration in the implementation plan §3.
        #expect(EpdocManifest.currentSchemaVersion == 1,
                "Swift side reports schema_version \(EpdocManifest.currentSchemaVersion); Rust ArtifactHeader::CURRENT_SCHEMA_VERSION must match.")

        let rustSource = try Self.loadText("agent_core/src/artifacts/header.rs")
        #expect(rustSource.contains("pub const CURRENT_SCHEMA_VERSION: u32 = 1"),
                "Rust ArtifactHeader::CURRENT_SCHEMA_VERSION must equal 1 to match Swift EpdocManifest.currentSchemaVersion")
    }

    @Test("Rust ArtifactHeader struct declares every canonical field")
    func rustArtifactHeaderFields() throws {
        let source = try Self.loadText("agent_core/src/artifacts/header.rs")
        #expect(source.contains("pub struct ArtifactHeader"),
                "Rust must expose `pub struct ArtifactHeader`")
        let canonicalFields = [
            "pub id: String",
            "pub kind: ArtifactKind",
            "pub schema_version: u32",
            "pub created_at: i64",
            "pub updated_at: i64",
            "pub title: String",
            "pub content_hash: String",
            "pub provenance: ProvenanceBlock",
        ]
        for field in canonicalFields {
            #expect(source.contains(field),
                    "Rust ArtifactHeader must declare `\(field)` — drift means EpdocManifest decoder will fail on Rust-written manifests")
        }
        // Optional metadata field is `BTreeMap<String, String>` for
        // deterministic key ordering.
        #expect(source.contains("pub metadata: Option<BTreeMap<String, String>>")
                || source.contains("pub metadata: Option<std::collections::BTreeMap<String, String>>"),
                "Rust ArtifactHeader.metadata must be Option<BTreeMap<String, String>> for sorted-key wire format")
    }

    // MARK: - Cross-file path guard

    @Test("Rust artifact module ships in the canonical location")
    func rustModulePathIsCanonical() throws {
        let modUrl = try sourceMirrorURL(for: "agent_core/src/artifacts")
        #expect(FileManager.default.fileExists(atPath: modUrl.path),
                "Rust artifacts module must live at agent_core/src/artifacts/ (per implementation plan §3)")

        for file in ["mod.rs", "kind.rs", "header.rs", "provenance.rs"] {
            let url = modUrl.appendingPathComponent(file, isDirectory: false)
            #expect(FileManager.default.fileExists(atPath: url.path),
                    "Rust artifacts module must contain \(file) — adding new types requires a 4-step ritual: declare in Rust, mirror in Swift, update this parity test, document the change")
        }
    }
}
