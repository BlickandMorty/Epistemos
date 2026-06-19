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

    @Test("staged lobehub assets are referenced; un-staged brands fall back to SF Symbols")
    func stagedAssetsReferenced() {
        #expect(ProviderBrand.claudeCode.assetName == "ProviderLogoClaudeCode")
        #expect(ProviderBrand.kimi.assetName == "ProviderLogoKimi")
        #expect(ProviderBrand.gemma.assetName == nil)   // not staged → SF-Symbol fallback
        #expect(ProviderBrand.claude.assetName == nil)
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
}
