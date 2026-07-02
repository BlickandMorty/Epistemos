import Testing
import Foundation

@testable import Epistemos

// L1821 staleness / honest-capability-gating (CLAUDE.md: "Never fake agent capability for local
// models"). The agent-mode-unavailable suggestion copy listed "Qwen 3.5 4B+" as supporting local
// tool loops — but `qwen35_4B4Bit` falls to supportsNativeToolCalling=false ("Small models lack
// reliable tool call formatting"), while Qwen 3 4B/8B (`qwen3_4B4Bit`/`qwen3_8B4Bit`) ARE true. So
// the copy over-claimed an un-capable model. This locks the corrected, honest reference so it can't
// regress.
@Suite("L1821 — agent-capability suggestion copy honesty")
struct AgentModeUnavailableCopyTests {

    @Test("the suggestion copy references the tool-capable Qwen 3 family, not the over-claimed 3.5 4B")
    func copyReferencesToolCapableModel() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        #expect(src.contains("case .qwen3_4B4Bit, .qwen3_8B4Bit:\n            .fullAgent"))
        #expect(src.contains("case .qwen35_4B4Bit, .gemma4_4B4Bit, .bonsai8B2Bit"))
        #expect(LocalTextModelID.qwen3_4B4Bit.agentToolTier == .fullAgent)
        #expect(LocalTextModelID.qwen35_4B4Bit.agentToolTier != .fullAgent)
    }
}
