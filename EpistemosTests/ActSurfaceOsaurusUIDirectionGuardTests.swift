import Testing

/// Owner 2026-06-22 (LOCKED act-UI direction, auditor pass 28): the act surface MOUNTS
/// Osaurus's OWN UI (`EpistemosOsaurusChatHost`, reskinned) — NOT the old Epistemos
/// `ChatView`. The owner's reported regression was a REVERT: option-(b) re-mounted the
/// old ChatView, so act became "the same chat, just with a badge" + send failures. This
/// source-guard locks the new direction so it can't silently revert again — a future edit
/// that drops the Osaurus-host mount for act fails here at test time (deterministic,
/// no runtime).
@Suite("Act surface = Osaurus's own UI (locked direction)")
struct ActSurfaceOsaurusUIDirectionGuardTests {

    @Test("RootView mounts Osaurus's own UI host for the act surface — Osaurus-routed, Pro-gated")
    func rootViewMountsOsaurusHostForAct() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        // Act mounts the genuine Osaurus chat surface, not the old ChatView shell.
        #expect(source.contains("EpistemosOsaurusChatHost()"))
        // It is the ACT surface specifically — gated on the shared act-routing decision.
        #expect(source.contains("shouldRouteActThroughOsaurus()"))
        // OsaurusCore is Pro-only → the import is build-config guarded (MAS keeps the old
        // surface; the canImport-on-MAS gotcha is closed by the `!EPISTEMOS_APP_STORE` term).
        #expect(source.contains("#if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)"))
        #expect(source.contains("import OsaurusCore"))
    }
}
