import Testing
@testable import Epistemos

/// P7.6 — locks the Chat/Act depth model + its honest gating. Act must only be
/// offered when an agent route genuinely exists (`.agent` in the available
/// modes), and the Chat/Act ↔ operatingMode mapping must preserve the tier.
@Suite("Cowork Chat/Act depth")
struct CoworkChatModeTests {

    @Test("Act is available only when an agent route exists (cloud/Pro); never faked for local-only")
    func actAvailabilityGate() {
        // Local-only (Fast/Think/Code, no .agent) → Act is NOT available.
        #expect(!CoworkChatMode.actAvailable(in: [.fast, .thinking, .pro]))
        #expect(!CoworkChatMode.actAvailable(in: [.fast]))
        #expect(!CoworkChatMode.actAvailable(in: []))
        // An agent route present (cloud/Pro) → Act available.
        #expect(CoworkChatMode.actAvailable(in: [.fast, .agent]))
        #expect(CoworkChatMode.actAvailable(in: [.fast, .thinking, .pro, .agent]))
    }

    @Test("current depth: .agent is Act, every tier is Chat")
    func currentDepthMapping() {
        #expect(CoworkChatMode.current(for: .agent) == .act)
        #expect(CoworkChatMode.current(for: .fast) == .chat)
        #expect(CoworkChatMode.current(for: .thinking) == .chat)
        #expect(CoworkChatMode.current(for: .pro) == .chat)
    }

    @Test("operatingMode mapping: Act → .agent; Chat → the remembered tier")
    func operatingModeMapping() {
        #expect(CoworkChatMode.act.operatingMode(rememberedTier: .fast) == .agent)
        #expect(CoworkChatMode.act.operatingMode(rememberedTier: .pro) == .agent)
        #expect(CoworkChatMode.chat.operatingMode(rememberedTier: .thinking) == .thinking)
        #expect(CoworkChatMode.chat.operatingMode(rememberedTier: .pro) == .pro)
        // Defensive: a remembered .agent (not a tier) falls back to .fast for Chat.
        #expect(CoworkChatMode.chat.operatingMode(rememberedTier: .agent) == .fast)
    }
}
