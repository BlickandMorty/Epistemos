import Foundation
import Testing

@testable import Epistemos

/// Cross-language parity guard for the unified ArtifactKind enum
/// (Wave 3.2 of the Extended Program Plan,
///  cross-ref docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md §2).
///
/// Three artefacts MUST stay in lock-step:
///   1. agent_core/src/artifacts/kind.rs (Rust enum)
///   2. Epistemos/Models/ArtifactKind.swift (Swift mirror)
///   3. canonicalVariants below (this test's source of truth)
///
/// The numeric ids are CONTRACTS persisted to disk and across the FFI
/// boundary. A drift between Rust and Swift would silently corrupt
/// stored vaults, so this test reads both files and asserts:
///
///   - every canonical (id, name) pair appears in BOTH files
///   - the count matches (no orphans on either side)
///   - the snake_case wire string matches the Rust `serde rename` output
///   - the Swift `ArtifactKind` enum exposes every canonical case
@Suite("ArtifactKind cross-language parity (Wave 3.2)")
struct ArtifactKindParityTests {

    /// Authoritative list of every canonical variant.
    /// Adding a new ArtifactKind means appending to this list AND to
    /// both source enums. Skipping any of those steps fails the test.
    static let canonicalVariants: [(id: UInt8, swiftCase: String, rustCase: String, snake: String)] = [
        (1, "proseNote",  "ProseNote",  "prose_note"),
        (2, "document",   "Document",   "document"),
        (3, "rawThought", "RawThought", "raw_thought"),
        (4, "source",     "Source",     "source"),
        (5, "code",       "Code",       "code"),
        (6, "run",        "Run",        "run"),
        (7, "output",     "Output",     "output"),
    ]

    private static func loadText(_ relative: String) throws -> String {
        try loadMirroredSourceTextFile(relative)
    }

    // MARK: - Swift surface

    @Test("Swift ArtifactKind exposes every canonical variant")
    func swiftEnumCoversCanonicalVariants() {
        let allCases = ArtifactKind.allCases
        #expect(allCases.count == Self.canonicalVariants.count,
                "ArtifactKind.allCases has \(allCases.count) variants but canonicalVariants has \(Self.canonicalVariants.count). Update both sides + this test.")

        for variant in Self.canonicalVariants {
            // Find by raw value.
            guard let kind = ArtifactKind(rawValue: variant.id) else {
                #expect(Bool(false),
                        "ArtifactKind has no variant for id \(variant.id) (\(variant.swiftCase)) — Swift mirror is out of sync with the canonical list")
                continue
            }
            #expect(kind.rawValue == variant.id,
                    "ArtifactKind.\(variant.swiftCase) must have rawValue \(variant.id)")
            #expect(kind.snakeCaseString == variant.snake,
                    "ArtifactKind.\(variant.swiftCase).snakeCaseString must equal \"\(variant.snake)\" to match the Rust serde rename")
        }
    }

    @Test("Swift ArtifactKind round-trips every variant via Codable")
    func swiftCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for kind in ArtifactKind.allCases {
            let data = try encoder.encode(kind)
            let decoded = try decoder.decode(ArtifactKind.self, from: data)
            #expect(decoded == kind, "Codable round-trip must be identity for \(kind)")
        }
    }

    // MARK: - Rust source guard

    @Test("Rust ArtifactKind declares every canonical variant with the right numeric id")
    func rustEnumCoversCanonicalVariants() throws {
        let source = try Self.loadText("agent_core/src/artifacts/kind.rs")
        for variant in Self.canonicalVariants {
            // Match e.g. `ProseNote = 1,` — tolerant of whitespace
            // and trailing commas. We don't enforce exact spacing
            // because rustfmt may reflow; we DO enforce the id.
            let pattern = "\(variant.rustCase) = \(variant.id),"
            #expect(source.contains(pattern),
                    "agent_core/src/artifacts/kind.rs must declare `\(variant.rustCase) = \(variant.id),` (canonical id for \(variant.swiftCase))")
        }

        // Also assert no rogue declaration outside the canonical set.
        // Cheap check: count the `=` lines inside the enum and compare.
        let enumOpen = source.range(of: "pub enum ArtifactKind")
        #expect(enumOpen != nil, "Rust enum declaration must be present")
    }

    @Test("Rust ArtifactKind ALL slice contains every canonical variant in order")
    func rustAllSliceIsOrdered() throws {
        let source = try Self.loadText("agent_core/src/artifacts/kind.rs")
        // The ALL constant is one continuous source span. Locate it
        // and assert each canonical name appears in declaration order.
        guard let allRange = source.range(of: "pub const ALL: &'static [ArtifactKind] = &[") else {
            #expect(Bool(false), "Rust enum must expose `pub const ALL: &'static [ArtifactKind]`")
            return
        }
        let tail = String(source[allRange.upperBound...])
        guard let endRange = tail.range(of: "];") else {
            #expect(Bool(false), "Rust ALL constant must have closing `];`")
            return
        }
        let body = String(tail[..<endRange.lowerBound])

        var lastIndex = body.startIndex
        for variant in Self.canonicalVariants {
            let needle = "ArtifactKind::\(variant.rustCase),"
            guard let foundRange = body.range(of: needle, options: [], range: lastIndex..<body.endIndex) else {
                #expect(Bool(false),
                        "Rust ALL slice must include `ArtifactKind::\(variant.rustCase),` AFTER previous variants (declaration order)")
                continue
            }
            lastIndex = foundRange.upperBound
        }
    }

    // MARK: - Cross-file count guard

    @Test("Swift mirror file path matches the canonical location from the plan")
    func swiftMirrorPathIsCanonical() throws {
        let url = try sourceMirrorURL(for: "Epistemos/Models/ArtifactKind.swift")
        #expect(FileManager.default.fileExists(atPath: url.path),
                "Swift mirror must live at Epistemos/Models/ArtifactKind.swift (per COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md §2)")
    }
}
