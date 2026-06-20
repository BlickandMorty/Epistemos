import Testing
import Foundation

@testable import Epistemos

// SS-IR (owner 2026-06-20): "the recall popup → on the EDITORS (Epdoc + TK2), NOT chat." This slice
// stops the chat composer, landing search, and mini-chat from feeding Surface B (Contextual
// Shadows): the feed functions no longer fire a recall query — they cancel + clear their `.chat`
// scope, so the recall button (which needs a payload to render) goes away on those surfaces. The
// recall brain (ContextualShadowsState) and the editor scopes are untouched.
@Suite("SS-IR recall is editor-scoped (off chat/landing/mini-chat)")
struct SSIRRecallEditorScopedTests {

    @Test("chat/landing/mini-chat feeds stop requesting recall + clear their scope")
    func feedsStopFeedingSurfaceB() throws {
        let surfaces: [(file: String, fn: String)] = [
            ("Epistemos/Views/Chat/ChatInputBar.swift", "scheduleContextualShadowsRecall"),
            ("Epistemos/Views/Landing/LandingView.swift", "scheduleLandingContextualShadowsRecall"),
            ("Epistemos/Views/MiniChat/MiniChatView.swift", "scheduleContextualShadowsRecall"),
        ]
        for surface in surfaces {
            let src = try loadMirroredSourceTextFile(surface.file)
            // The feed still exists (called on text change)…
            #expect(src.contains("private func \(surface.fn)"))
            // …but it no longer dispatches a recall query — it clears the chat scope instead.
            #expect(src.contains("contextualShadows.closePanel(kind: .chat"))
            #expect(!src.contains("state.requestRecall("))
        }
    }
}
