import Foundation

// MARK: - ArtifactRoute (compile-time exhaustive routing)
//
// Cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §6.
//
// Closed enum that maps a typed artifact identity to an artifact route.
// Used by `ArtifactHostView` (`Epistemos/Views/Workspace/ArtifactHostView.swift`)
// to dispatch via an exhaustive `@ViewBuilder switch` — NO `AnyView`,
// per anti-pattern #7 (`docs/_consolidated/00_canonical_authority/MASTER_FUSION.md` §11).
//
// Every `ArtifactKind` from the unified taxonomy maps to exactly one
// route case here. The `Run` and `RawThought` kinds share the
// `rawThoughtRun(RunID)` route because viewing a raw-thought always
// surfaces the parent run timeline (per implementation plan §6, the
// timeline view is the canonical surface for both kinds).
//
// Adding a new ArtifactKind variant means:
//   1. Add the variant to the unified taxonomy
//      (`agent_core/src/artifacts/kind.rs` + `Epistemos/Models/ArtifactKind.swift`).
//   2. Decide whether it gets a new route case or shares an existing one.
//   3. Add (or extend) the `@ViewBuilder` switch in `ArtifactHostView`.
//   4. Update `ArtifactRouteParityTests`.
//   5. Document the routing in this file's header.

/// Stable opaque artifact id. Treated as a `String` at the routing layer
/// so generation strategy (UUID v4 / v7 / ULID) is decided downstream.
/// Persists across renames; never reused.
public typealias ArtifactID = String

/// Stable opaque run id. Same generation rules as `ArtifactID`. Used to
/// address an agent run (the parent of a raw-thought sequence).
public typealias RunID = String

/// Compile-time exhaustive route identity for artifact surfaces.
///
/// Closed enum. Equatable + Hashable so SwiftUI navigation stacks can
/// deduplicate identical routes and `NavigationPath` can encode them
/// without an `AnyHashable` ceremony.
nonisolated public enum ArtifactRoute: Equatable, Hashable, Sendable {
    /// Canonical user note — opens `ProseEditorView`. Kind id 1.
    case proseNote(ArtifactID)

    /// Rich `.epdoc` package. Kind id 2.
    case document(ArtifactID)

    /// One agent run timeline — opens `RawThoughtTimelineView`. Used for
    /// both `RawThought` (kind id 3) and `Run` (kind id 6) — viewing a
    /// raw-thought surfaces its parent run, so a single route case
    /// handles both kinds.
    case rawThoughtRun(RunID)

    /// External reference (web page, PDF, paper) — opens
    /// `SourceReaderView`. Kind id 4.
    case source(ArtifactID)

    /// Source code file — opens `CodeEditorView`. Kind id 5.
    case code(ArtifactID)

    /// Captured terminal / REPL / build output — opens
    /// `OutputArtifactView`. Kind id 7.
    case output(ArtifactID)

    /// Lift an `ArtifactKind` + id pair into the matching route.
    /// Returns `nil` for kinds that aren't directly routable (none today,
    /// but the optional return preserves forward compatibility for
    /// future kinds added before their route lands).
    public static func from(kind: ArtifactKind, id: String) -> ArtifactRoute? {
        switch kind {
        case .proseNote:   return .proseNote(id)
        case .document:    return .document(id)
        case .rawThought:  return .rawThoughtRun(id)
        case .source:      return .source(id)
        case .code:        return .code(id)
        case .run:         return .rawThoughtRun(id)
        case .output:      return .output(id)
        }
    }

    /// The canonical [`ArtifactKind`] this route renders. For
    /// `.rawThoughtRun` the kind is `.run` — the route surfaces the run
    /// timeline; the raw-thought children appear inside it.
    public var kind: ArtifactKind {
        switch self {
        case .proseNote:      return .proseNote
        case .document:       return .document
        case .rawThoughtRun:  return .run
        case .source:         return .source
        case .code:           return .code
        case .output:         return .output
        }
    }

    /// The opaque id this route addresses. Returned as `String` so
    /// callers can persist routes through `NavigationPath` / URL schemes
    /// without unwrapping the typealias.
    public var idString: String {
        switch self {
        case .proseNote(let id),
             .document(let id),
             .rawThoughtRun(let id),
             .source(let id),
             .code(let id),
             .output(let id):
            return id
        }
    }
}
