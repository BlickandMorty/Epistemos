import Foundation

// MARK: - ArtifactKind (unified Rust + Swift)
//
// Per docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md §2 and
// docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md Wave 3.2.
//
// Mirrors agent_core/src/artifacts/kind.rs. Numeric raw values are CONTRACTS:
// they MUST match the Rust `repr(u8)` discriminants byte-for-byte. Drift is
// caught by EpistemosTests/ArtifactKindParityTests.swift.
//
// Adding a new variant is a 4-step ritual:
//   1. Add the variant + numeric id to the Rust enum (declaration order).
//   2. Append the matching variant here with the same id.
//   3. Update ArtifactKindParityTests (canonicalVariants list).
//   4. Document the variant's intent on both sides.
//
// Kept distinct from:
//   - `ChatArtifactKind` (Models/Artifact.swift) — chat content block
//     discriminator (json/yaml/csv/codeBlock/etc.)
//   - `GraphNodeType` (Models/GraphTypes.swift) — graph render category
//     (legacy compatibility, separate ontology)
//   - substrate-core's `EntityKind` — slotmap entity discriminator (Rust-only)

nonisolated public enum ArtifactKind: UInt8, Codable, Sendable, CaseIterable, Hashable {
    /// Canonical user note — ProseMirror JSON document persisted as
    /// `SDPage` + vault `.md` file. Default kind for hand-authored
    /// rich text in the Notes surface.
    case proseNote = 1

    /// Rich `.epdoc` package — ProseMirror canonical + projections + assets.
    /// Used for long-form documents, research reports, importable Word/PDF.
    case document = 2

    /// One thinking-block sequence inside an agent run. Captures
    /// thinking_delta + signature_delta pairs (see Raw Thoughts V0).
    case rawThought = 3

    /// External reference — web page, PDF, book, paper. Source material
    /// the user is drawing from but did not author.
    case source = 4

    /// Source code file. May carry syntax-core highlighting metadata when
    /// the inspector displays it.
    case code = 5

    /// One agent execution span — parent of its rawThought + tool trace
    /// children (see Raw Thoughts V0 manifest.json + final.json).
    case run = 6

    /// Captured terminal / REPL / build output. The text the user wants
    /// to remember from a tool execution, separable from the tool's
    /// invocation record.
    case output = 7

    /// Stable lower_snake_case identifier — matches the Rust serde rename
    /// and `as_str()`. Use this when persisting to disk or wire formats
    /// outside of the Codable path.
    public var snakeCaseString: String {
        switch self {
        case .proseNote:  return "prose_note"
        case .document:   return "document"
        case .rawThought: return "raw_thought"
        case .source:     return "source"
        case .code:       return "code"
        case .run:        return "run"
        case .output:     return "output"
        }
    }

    /// Round-trip a numeric id back into a typed kind. Returns `nil`
    /// for unknown ids — callers MUST handle the optional (do not
    /// force-unwrap on an old vault that contains a kind id this build
    /// doesn't yet understand).
    public static func from(id: UInt8) -> ArtifactKind? {
        ArtifactKind(rawValue: id)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self),
           let kind = ArtifactKind(snakeCaseString: value) {
            self = kind
            return
        }
        if let value = try? container.decode(UInt8.self),
           let kind = ArtifactKind.from(id: value) {
            self = kind
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unknown artifact kind"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(snakeCaseString)
    }

    private init?(snakeCaseString: String) {
        switch snakeCaseString {
        case "prose_note": self = .proseNote
        case "document": self = .document
        case "raw_thought": self = .rawThought
        case "source": self = .source
        case "code": self = .code
        case "run": self = .run
        case "output": self = .output
        default: return nil
        }
    }

    /// Human-readable display name for the inspector UI.
    public var displayName: String {
        switch self {
        case .proseNote:  return "Prose Note"
        case .document:   return "Document"
        case .rawThought: return "Raw Thought"
        case .source:     return "Source"
        case .code:       return "Code"
        case .run:        return "Run"
        case .output:     return "Output"
        }
    }
}
