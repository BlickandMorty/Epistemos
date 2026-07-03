import Testing
import Foundation
@testable import Epistemos

/// P7.6 — locks the Chat/Act depth model + its honest gating. Act must only be
/// offered when an agent route genuinely exists (`.agent` in the available
/// modes), and the Chat/Act ↔ operatingMode mapping must preserve the tier.
/// Native local chat/agent surfaces were pruned on 2026-06-26, so local model
/// IDs must not be described as runnable Act routes.
@Suite("Cowork Chat/Act depth")
struct CoworkChatModeTests {

    @Test("Act is available iff .agent is in the available modes — never faked")
    func actAvailabilityGate() {
        // A surface with no agent route (Fast/Think/Code only, no .agent) → Act is
        // honestly NOT available.
        #expect(!CoworkChatMode.actAvailable(in: [.fast, .thinking, .pro]))
        #expect(!CoworkChatMode.actAvailable(in: [.fast]))
        #expect(!CoworkChatMode.actAvailable(in: []))
        // An agent route present → Act available. The predicate follows the
        // resolved capabilities list; it does not invent an agent route itself.
        #expect(CoworkChatMode.actAvailable(in: [.fast, .agent]))
        #expect(CoworkChatMode.actAvailable(in: [.fast, .thinking, .pro, .agent]))
    }

    @Test("the Act-unavailable reason matches the current cloud-backed Act route")
    func actUnavailableReasonIsLocalFirst() {
        let reason = CoworkChatMode.actUnavailableReason
        #expect(reason.localizedCaseInsensitiveContains("cloud"))
        #expect(reason.localizedCaseInsensitiveContains("connect"))
        #expect(!reason.localizedCaseInsensitiveContains("qwen"))
        #expect(!reason.localizedCaseInsensitiveContains("zero cloud"))
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

    // Cloud-only migration: "local Qwen selection normalizes away …" removed — it
    // exercised deleted local-model machinery (setInstalledLocalTextModelIDs,
    // LocalTextModelID, effectiveLocalAgentTextModelID). The Chat/Act depth model
    // (a kept feature) stays covered by the tests above.
}
