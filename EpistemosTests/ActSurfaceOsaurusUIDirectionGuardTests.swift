import Testing

/// Owner 2026-06-22 — ACT ARCHITECTURE PIVOT (addendum §1994/§2029/§2048, auditor pass61c-66):
/// the act surface is NATIVE Epistemos SwiftUI (cream/monospace by construction) LINKED to the
/// Osaurus ENGINE in-process via the CERTIFIED 0.4 path — NOT the mounted Osaurus `ChatView`
/// (`EpistemosOsaurusChatHost`, the "wall that won't render") and NOT the old Epistemos `ChatView`
/// (option-b). This source-guard LOCKS the pivot direction so it can't silently revert to the
/// mount-and-reskin wall (the owner's recurring pain) — a future edit that re-mounts the Osaurus
/// host for act, or drops the native views, fails here at test time (deterministic, no runtime).
@Suite("Act surface = native Epistemos UI on the Osaurus engine (PIVOT, locked direction)")
struct ActSurfaceOsaurusUIDirectionGuardTests {

    @Test("RootView mounts the NATIVE act views (landing + chat) for the act surface — Osaurus-routed, Pro-gated")
    func rootViewMountsNativeActForAct() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        // PIVOT: act = fresh NATIVE views (cream by construction), not a mounted/reskinned Osaurus UI.
        #expect(source.contains("NativeActChatView("))
        #expect(source.contains("NativeActLandingView("))
        // It is the ACT surface specifically — gated on the shared act-routing (engine) decision.
        #expect(source.contains("shouldRouteActThroughOsaurus()"))
        // OsaurusCore (the engine) is Pro-only → build-config guarded (canImport-on-MAS gotcha closed).
        #expect(source.contains("#if !EPISTEMOS_APP_STORE"))
    }

    @Test("NativeActChatView drives the CERTIFIED in-process engine link (0.4) + composes the owner's rich composer (not a skeleton)")
    func nativeActDrivesEngineLinkWithOwnerChrome() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/ActOsaurus/NativeActChatView.swift")
        // The engine link = the exact call the green send harness (ActOsaurusSendHarnessTests) certifies.
        #expect(source.contains("OsaurusActBridge().runTurnStreamingInProcess"))
        // §pass66: COMPOSE the owner's existing rich chrome (ChatInputBar), not a bare skeleton composer.
        #expect(source.contains("ChatInputBar("))
        // Cream by construction (the pivot's whole point — no theme cascade).
        #expect(source.contains("0xFB") || source.contains("fbfaf5"))
    }
}
