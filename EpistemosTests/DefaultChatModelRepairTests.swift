import Testing
import Foundation
@testable import Epistemos

/// Owner 2026-06-18 — the default chat model must be a Fast GEMMA, never Qwen
/// (both Qwens are explicit-only picks). Locks the three seams that used to
/// default/migrate/sanitize to Qwen 3 4B: the property defaults,
/// migrateStaleGemma4Selection, and sanitizedStoredLocalChatModelID.
@Suite("Default chat model is a Fast Gemma, not Qwen")
struct DefaultChatModelRepairTests {

    @Test("defaultChatModelID is the Fast tier representative — a Gemma, never Qwen")
    func defaultConstantIsFastGemma() {
        let id = EpistemosFoundationLineup.defaultChatModelID
        #expect(id == EpistemosFoundationLineup.representativeModelID(for: .fast))
        #expect(id.lowercased().contains("gemma"))
        #expect(!id.lowercased().contains("qwen"))
    }

    @Test("the default/migration/sanitizer seams use the Gemma default; the Qwen literal default is gone")
    func seamsUseGemmaDefault() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        // Property default + migration both point at the Gemma default constant.
        #expect(src.contains("var preferredLocalTextModelID: String = EpistemosFoundationLineup.defaultChatModelID"))
        #expect(src.contains("let fallbackLocalModelID = EpistemosFoundationLineup.defaultChatModelID"))
        // The sanitizer's awaiting-loader branch rewrites to the Gemma default
        // under the simplified lineup.
        #expect(src.contains("return EpistemosFoundationLineup.defaultChatModelID"))
        // The old hardcoded Qwen-4B property default is gone.
        #expect(!src.contains("var preferredLocalTextModelID: String = LocalTextModelID.qwen3_4B4Bit.rawValue"))
    }
}
