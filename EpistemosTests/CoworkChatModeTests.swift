import Testing
import Foundation
@testable import Epistemos

/// P7.6 — locks the Chat/Act depth model + its honest gating. Act must only be
/// offered when an agent route genuinely exists (`.agent` in the available
/// modes), and the Chat/Act ↔ operatingMode mapping must preserve the tier.
@Suite("Cowork Chat/Act depth")
struct CoworkChatModeTests {

    @Test("Act is available iff .agent is in the available modes — LOCAL-FIRST, never faked")
    func actAvailabilityGate() {
        // A surface with no agent route (Fast/Think/Code only, no .agent) → Act is
        // honestly NOT available (not faked, not cloud-forced).
        #expect(!CoworkChatMode.actAvailable(in: [.fast, .thinking, .pro]))
        #expect(!CoworkChatMode.actAvailable(in: [.fast]))
        #expect(!CoworkChatMode.actAvailable(in: []))
        // An agent route present → Act available. `.agent` comes from a LOCAL
        // agent-capable model (e.g. Qwen) with ZERO cloud, OR from a cloud model —
        // the predicate is local-first, not cloud-gated.
        #expect(CoworkChatMode.actAvailable(in: [.fast, .agent]))
        #expect(CoworkChatMode.actAvailable(in: [.fast, .thinking, .pro, .agent]))
    }

    @Test("the Act-unavailable reason is local-first honest — never implies cloud is required")
    func actUnavailableReasonIsLocalFirst() {
        let reason = CoworkChatMode.actUnavailableReason
        // Mentions the LOCAL on-device path.
        #expect(reason.localizedCaseInsensitiveContains("local"))
        #expect(
            reason.localizedCaseInsensitiveContains("on-device")
                || reason.localizedCaseInsensitiveContains("zero cloud")
        )
        // Must NOT imply cloud is the only/required path (the old misleading copy).
        #expect(!reason.localizedCaseInsensitiveContains("connect a cloud model to enable"))
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

    @MainActor
    @Test("Act runs LOCALLY on a local agent-capable model with ZERO cloud — never a silent cloud/GPT route")
    func actRunsLocallyWithZeroCloud() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3_4B4Bit.rawValue])
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen3_4B4Bit.rawValue))
        // No cloud configured → no auto-route. The local agent-capable model puts
        // `.agent` in the available modes, so Act is available with ZERO cloud.
        #expect(inference.availableOperatingModes.contains(.agent))
        #expect(CoworkChatMode.actAvailable(in: inference.availableOperatingModes))
        // And Act RESOLVES LOCAL — the owner's #1 rule: never a silent cloud/GPT route.
        let actSelection = inference.effectiveChatSurfaceSelection(for: .agent)
        let actIsLocal: Bool
        if case .localMLX = actSelection { actIsLocal = true } else { actIsLocal = false }
        #expect(actIsLocal)
    }
}
