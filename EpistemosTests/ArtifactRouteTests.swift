import Foundation
import Testing

@testable import Epistemos

/// Exhaustiveness + parity tests for [`ArtifactRoute`]
/// (T+4.7 of
/// `docs/audits/deliberation/T+4_cognitive_artifact_spine_deliberation_20260427.md`,
/// cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §6).
///
/// The closed `ArtifactRoute` enum is the compile-time guarantee that
/// every typed artifact has exactly one renderable destination. These
/// tests assert:
///   - every [`ArtifactKind`] has a route via `ArtifactRoute.from(kind:id:)`
///   - every route's reverse `kind` projection round-trips
///   - `Equatable` / `Hashable` derive correctly so SwiftUI's
///     `NavigationPath` can deduplicate routes
@Suite("ArtifactRoute compile-time routing (T+4.7)")
nonisolated struct ArtifactRouteTests {

    @Test("Every ArtifactKind lifts to a non-nil ArtifactRoute")
    func everyKindLiftsToRoute() {
        for kind in ArtifactKind.allCases {
            let route = ArtifactRoute.from(kind: kind, id: "test-id-\(kind.rawValue)")
            #expect(route != nil,
                    "ArtifactRoute.from must support every ArtifactKind variant — \(kind) returned nil")
        }
    }

    @Test("Route.kind projection round-trips for routable kinds")
    func routeKindRoundTrips() {
        let pairs: [(ArtifactKind, ArtifactKind)] = [
            (.proseNote,  .proseNote),
            (.document,   .document),
            // RawThought + Run share the rawThoughtRun route — both
            // project back to .run because the route surfaces the run
            // timeline (raw-thought children are rendered inside it).
            (.rawThought, .run),
            (.source,     .source),
            (.code,       .code),
            (.run,        .run),
            (.output,     .output),
        ]
        for (input, expectedProjection) in pairs {
            guard let route = ArtifactRoute.from(kind: input, id: "id-\(input.rawValue)") else {
                #expect(Bool(false), "ArtifactRoute.from returned nil for \(input)")
                continue
            }
            #expect(route.kind == expectedProjection,
                    "ArtifactRoute(\(input)).kind expected \(expectedProjection), got \(route.kind)")
        }
    }

    @Test("Route.idString returns the original opaque id")
    func routeIdStringPreservesId() {
        let cases: [ArtifactRoute] = [
            .proseNote("note-1"),
            .document("doc-2"),
            .rawThoughtRun("run-3"),
            .source("src-4"),
            .code("code-5"),
            .output("out-6"),
        ]
        for route in cases {
            // idString MUST equal the inner String — this is the
            // contract that lets navigation paths persist a route
            // without the call site unwrapping the case manually.
            switch route {
            case .proseNote(let id),
                 .document(let id),
                 .rawThoughtRun(let id),
                 .source(let id),
                 .code(let id),
                 .output(let id):
                #expect(route.idString == id,
                        "ArtifactRoute.idString must match the inner id — got \(route.idString) vs \(id)")
            }
        }
    }

    @Test("ArtifactRoute is Equatable + Hashable for NavigationPath")
    func routeIsEquatableAndHashable() {
        let a = ArtifactRoute.document("the-same-doc-id")
        let b = ArtifactRoute.document("the-same-doc-id")
        let c = ArtifactRoute.document("a-different-doc-id")
        let d = ArtifactRoute.proseNote("the-same-doc-id")

        #expect(a == b, "Equal cases with equal ids must compare equal")
        #expect(a != c, "Equal cases with different ids must compare unequal")
        #expect(a != d, "Different cases with the same id must compare unequal")

        // Hashable: equal routes must hash equal so Set / Dictionary
        // dedupes correctly.
        var set: Set<ArtifactRoute> = []
        set.insert(a)
        set.insert(b)
        #expect(set.count == 1, "Equal routes must dedupe in a Set")
        set.insert(c)
        set.insert(d)
        #expect(set.count == 3, "Distinct routes must coexist in a Set")
    }

    @Test("Route count is exactly 6 (RawThought + Run share rawThoughtRun)")
    func routeCardinalityIsSix() {
        // Closed-enum expectation: 7 ArtifactKind variants → 6 routes.
        // RawThought (kind id 3) + Run (kind id 6) collapse onto the
        // single rawThoughtRun route per implementation plan §6.
        // Use a Set to count distinct route shapes when fed every kind.
        var distinctRoutes: Set<String> = []
        for kind in ArtifactKind.allCases {
            guard let route = ArtifactRoute.from(kind: kind, id: "fixed") else { continue }
            // Use the case label as the discriminator (idString is the
            // same fixed value for every kind here).
            switch route {
            case .proseNote:     distinctRoutes.insert("proseNote")
            case .document:      distinctRoutes.insert("document")
            case .rawThoughtRun: distinctRoutes.insert("rawThoughtRun")
            case .source:        distinctRoutes.insert("source")
            case .code:          distinctRoutes.insert("code")
            case .output:        distinctRoutes.insert("output")
            }
        }
        #expect(distinctRoutes.count == 6,
                "Expected exactly 6 distinct route cases — got \(distinctRoutes.sorted())")
    }
}
