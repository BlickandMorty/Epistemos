import Foundation
import Testing

@testable import Epistemos

/// Wave 3.3 tests for the typed cognitive-artifact GraphNodeType cases
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 3.3,
///  cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §2)
/// and the ArtifactKind ↔ GraphNodeType bridges.
///
/// Three contracts covered:
///   1. The four new app-level cases (proseNote/document/code/output)
///      are present and listed in `appLevelCases`.
///   2. The FFI contract (`allCases.count == 14`) is preserved — the new
///      cases are app-level only and do not leak into the FFI batch
///      payload (rustIndex stays 0 for them).
///   3. `mapsToArtifactKind` and `init(from: ArtifactKind)` round-trip
///      the canonical 7 ArtifactKind variants.
@Suite("GraphNodeType ↔ ArtifactKind bridge (Wave 3.3)")
nonisolated struct GraphNodeTypeArtifactBridgeTests {

    static let newAppLevelCases: [GraphNodeType] = [
        .proseNote, .document, .code, .output,
    ]

    // MARK: - new cases present

    @Test("Wave 3.3 cases live in appLevelCases, not allCases")
    func newCasesAreAppLevelOnly() {
        for kind in Self.newAppLevelCases {
            #expect(GraphNodeType.appLevelCases.contains(kind),
                    "GraphNodeType.appLevelCases must contain \(kind) (Wave 3.3 typed cognitive artifact)")
            #expect(!GraphNodeType.allCases.contains(kind),
                    "GraphNodeType.allCases (FFI) must NOT contain \(kind) — would break the 14-case Rust contract enforced by FFIVersionSyncTests")
        }
    }

    @Test("FFI contract: GraphNodeType.allCases has exactly 14 cases")
    func ffiContractStable() {
        #expect(GraphNodeType.allCases.count == 14,
                "GraphNodeType.allCases must remain 14 (Rust NodeType enum 0-13). Adding a new FFI case requires updating graph-engine + FFIVersionSyncTests.")
    }

    @Test("Wave 3.3 cases keep rustIndex 0 (sentinel for non-FFI cases)")
    func newCasesHaveSafeRustIndex() {
        for kind in Self.newAppLevelCases {
            #expect(kind.rustIndex == 0,
                    "\(kind) is app-level only and must report rustIndex 0 so a misuse cannot read off the end of the FFI enum table")
        }
    }

    // MARK: - displayName + icon coverage

    @Test("Wave 3.3 cases have displayName + icon defined")
    func newCasesHaveDisplayMetadata() {
        for kind in Self.newAppLevelCases {
            #expect(!kind.displayName.isEmpty,
                    "\(kind) must declare a non-empty displayName")
            #expect(!kind.icon.isEmpty,
                    "\(kind) must declare a non-empty SF Symbol icon")
        }
    }

    // MARK: - bridge round-trip

    @Test("ArtifactKind round-trips via init(from:) → mapsToArtifactKind")
    func artifactKindRoundTrip() {
        for artifactKind in ArtifactKind.allCases {
            let nodeType = GraphNodeType(from: artifactKind)
            let recovered = nodeType.mapsToArtifactKind
            #expect(recovered == artifactKind,
                    "round-trip ArtifactKind.\(artifactKind) → GraphNodeType.\(nodeType) → \(String(describing: recovered)) must be identity")
        }
    }

    @Test("Legacy GraphNodeType.note bridges to ArtifactKind.proseNote")
    func legacyNoteBridgesToProseNote() {
        // Per COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md §2: legacy
        // GraphNodeType.note maps to the new ArtifactKind.proseNote
        // so legacy node visits flow into the typed pipeline without
        // a call-site rewrite.
        #expect(GraphNodeType.note.mapsToArtifactKind == .proseNote,
                "Legacy .note must bridge to ArtifactKind.proseNote per the cognitive plan migration policy")
    }

    @Test("Non-artifact GraphNodeType cases return nil from mapsToArtifactKind")
    func legacyOntologyReturnsNil() {
        let legacyNonArtifactCases: [GraphNodeType] = [
            .chat, .idea, .folder, .quote, .tag, .block,
            .person, .project, .topic, .decision, .event, .resource,
            .toolTrace,
        ]
        for kind in legacyNonArtifactCases {
            #expect(kind.mapsToArtifactKind == nil,
                    "\(kind) is not a cognitive artifact in the Wave 3.2 taxonomy and must return nil from mapsToArtifactKind")
        }
    }
}
