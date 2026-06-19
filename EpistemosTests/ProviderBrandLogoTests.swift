import Testing
import Foundation
@testable import Epistemos

/// P6.1 — locks the provider→logo map: every brand is render-safe (has a fallback),
/// the owner's provider list all map to a distinct brand, and the staged lobehub
/// assets are referenced.
@Suite("Provider brand logos (P6.1)")
struct ProviderBrandLogoTests {

    @Test("every brand has a display name + a non-empty SF-Symbol fallback (render-safe)")
    func everyBrandRenderable() {
        for brand in ProviderBrand.allCases {
            #expect(!brand.displayName.isEmpty)
            #expect(!brand.sfSymbolFallback.isEmpty)
        }
    }

    @Test("the owner's provider list all map to a distinct brand (cloud + account runtime + local + Apple)")
    func ownerListCovered() {
        // Cloud
        #expect(ProviderBrand.cloud(.anthropic) == .claude)
        #expect(ProviderBrand.cloud(.openAI) == .chatGPT)
        #expect(ProviderBrand.cloud(.google) == .gemini)
        #expect(ProviderBrand.cloud(.kimi) == .kimi)
        // Account runtimes (the distinction the owner called out: Claude Code / Codex)
        #expect(ProviderBrand.cloud(.anthropic, accountRuntime: true) == .claudeCode)
        #expect(ProviderBrand.cloud(.openAI, accountRuntime: true) == .codex)
        // Local families
        #expect(ProviderBrand.local(modelID: "gemma-3-4b") == .gemma)
        #expect(ProviderBrand.local(modelID: "qwen3_4B4Bit") == .qwen)
        #expect(ProviderBrand.local(modelID: "qwopus27Bv3") == .qwen)
        #expect(ProviderBrand.local(modelID: "something-else") == .generic)
        // Apple is its own brand.
        #expect(ProviderBrand.apple.displayName == "Apple Intelligence")
        #expect(ProviderBrand.apple.sfSymbolFallback == "apple.logo")
    }

    @Test("the owner's full provider list references a staged lobehub SVG; only the long-tail falls back")
    func stagedAssetsReferenced() {
        // The owner's full list now has a real lobehub B&W SVG (MIT lobe-icons).
        #expect(ProviderBrand.claude.assetName == "ProviderLogoClaude")
        #expect(ProviderBrand.chatGPT.assetName == "ProviderLogoOpenAI")
        #expect(ProviderBrand.gemini.assetName == "ProviderLogoGemini")
        #expect(ProviderBrand.claudeCode.assetName == "ProviderLogoClaudeCode")
        #expect(ProviderBrand.codex.assetName == "ProviderLogoCodex")
        #expect(ProviderBrand.gemma.assetName == "ProviderLogoGemma")
        #expect(ProviderBrand.qwen.assetName == "ProviderLogoQwen")
        #expect(ProviderBrand.apple.assetName == "ProviderLogoApple")
        #expect(ProviderBrand.kimi.assetName == "ProviderLogoKimi")
        // The long-tail providers (no SVG yet) fall back to SF Symbols.
        #expect(ProviderBrand.zai.assetName == nil)
        #expect(ProviderBrand.minimax.assetName == nil)
        #expect(ProviderBrand.generic.assetName == nil)
    }

    @MainActor
    @Test("InferenceState resolves the brand honoring the active account runtime")
    func inferenceStateBrandDerivation() {
        let inference = InferenceState()
        // Without account runtimes active, the base brands resolve.
        #expect(inference.providerBrand(for: .anthropic) == .claude)
        #expect(inference.providerBrand(for: .openAI) == .chatGPT)
        #expect(inference.providerBrand(for: .google) == .gemini)
    }

    @Test("the provider logo is wired into a visible Settings surface (cloud access rows)")
    func wiredIntoSettings() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/APIKeysHealthRow.swift")
        #expect(src.contains("ProviderLogoView(brand: inference.providerBrand(for: provider)"))
    }

    @Test("fromLabel maps real per-message labels to the right brand")
    func fromLabelMapping() {
        #expect(ProviderBrand.fromLabel("Claude Opus 4.7") == .claude)
        #expect(ProviderBrand.fromLabel("GPT-5.4") == .chatGPT)
        #expect(ProviderBrand.fromLabel("Gemini 3.1 Pro") == .gemini)
        #expect(ProviderBrand.fromLabel("Qwen 3 4B") == .qwen)
        #expect(ProviderBrand.fromLabel("Gemma 4 E4B") == .gemma)
        #expect(ProviderBrand.fromLabel("Kimi K2") == .kimi)
        #expect(ProviderBrand.fromLabel("Apple Intelligence") == .apple)
        // Account-runtime names win over the base brand.
        #expect(ProviderBrand.fromLabel("Claude Code") == .claudeCode)
        #expect(ProviderBrand.fromLabel("Codex") == .codex)
        #expect(ProviderBrand.fromLabel("Mystery Model") == .generic)
    }

    @Test("the logo is wired into the picker rows + the chat per-message badge")
    func wiredIntoPickerAndChat() throws {
        let picker = try loadMirroredSourceTextFile("Epistemos/Views/Chat/InlineRuntimePickerPanel.swift")
        #expect(picker.contains("ProviderLogoView("))
        #expect(picker.contains("ProviderBrand.local(modelID: option.id)"))
        let bubble = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")
        #expect(bubble.contains("ProviderLogoView(brand: ProviderBrand.fromLabel(label)"))
    }
}
