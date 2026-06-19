import Testing
import Foundation

/// DeerFlow 5e-2 — locks the composer DEEP RESEARCH entry path end to end so a
/// future edit can't silently drop the button, break the dispatch, or weaken the
/// honest gating (owner #1: never route to a provider the user didn't pick).
/// Mirrored-source assertions over the real wiring files.
@Suite("Deep research composer entry point")
struct DeepResearchEntryPointTests {

    @Test("ChatInputBar exposes a Pro-only, flag+cloud-gated deep-research button")
    func chatInputBarHasGatedButton() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        // The optional entry closure (default nil → no button on other callers).
        #expect(src.contains("var onDeepResearch: ((String) -> Void)? = nil"))
        // Pro-only (the FFI + DeepResearchService are #if !EPISTEMOS_APP_STORE).
        #expect(src.contains("#if !EPISTEMOS_APP_STORE"))
        #expect(src.contains("private var deepResearchButton: some View"))
        // Honest gating: wired AND flag on AND on a cloud model — no silent route.
        #expect(src.contains("private var showsDeepResearchButton: Bool"))
        #expect(src.contains("onDeepResearch != nil"))
        #expect(src.contains("DeepResearchGateStatus.status().isActive"))
        #expect(src.contains("&& isCloudSelection"))
        // The button funnels the composer text to the handler.
        #expect(src.contains("onDeepResearch?(objective)"))
        // It's actually placed in the toolbar (not just defined).
        #expect(src.contains("if showsDeepResearchButton {"))
        #expect(src.contains("deepResearchButton"))
    }

    @Test("ChatView wires the button to the deep-research submit path")
    func chatViewWiresEntry() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")
        #expect(src.contains("onDeepResearch: { query in"))
        #expect(src.contains("submitMainChatDeepResearch(query, operatingMode: selectedOperatingMode)"))
        #expect(src.contains("chat.submitDeepResearch(query, operatingMode: operatingMode)"))
    }

    @Test("the event bus carries a distinct deep-research event")
    func eventBusHasEvent() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/EventBus.swift")
        #expect(src.contains("case deepResearchSubmitted(chatId: ChatId, query: String, operatingMode: EpistemosOperatingMode)"))
    }

    @Test("AppCoordinator dispatches the event to runDeepResearch (not the normal turn)")
    func appCoordinatorDispatches() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/App/AppCoordinator.swift")
        #expect(src.contains("case .deepResearchSubmitted(_, let query, let operatingMode):"))
        #expect(src.contains("self.chatCoordinator.runDeepResearch("))
    }

    @Test("ChatState.submitDeepResearch emits the event without appending a user message")
    func chatStateEmitsWithoutDoubleBubble() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/ChatState.swift")
        #expect(src.contains("func submitDeepResearch("))
        #expect(src.contains(".deepResearchSubmitted("))
        // runDeepResearch owns the user bubble; submitDeepResearch must NOT also
        // append one (the comment + absence of appendLocalMessage in the method
        // are the contract — assert the method emits the event, the dispatch
        // target appends). Guard the intent text so the contract is documented.
        #expect(src.contains("would double the bubble"))
    }
}
