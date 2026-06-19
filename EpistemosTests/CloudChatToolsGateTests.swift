import Testing
@testable import Epistemos

/// S4 fix (research CHAT_TOOLS_INTEGRATION_AUDIT 2026-06-19): plain cloud chat
/// (Fast/Thinking/Pro) got NO vault tools on Google/Z.AI/Kimi/MiniMax/DeepSeek
/// because ChatCoordinator gated the tool path on `supportsAgentTier` (OpenAI/
/// Anthropic only). The fix opens it to all providers behind a flag. These tests
/// pin the pure gate logic (no env dependence).
@Suite("Cloud plain-chat tool gate (S4)")
struct CloudChatToolsGateTests {

    @Test("flag OFF → only supportsAgentTier providers (OpenAI/Anthropic) get plain-chat tools")
    func gateOffPreservesTodaysBehaviour() {
        for provider in CloudModelProvider.allCases {
            #expect(
                CloudModelProvider.allowsPlainChatTools(provider: provider, allProvidersArmed: false)
                    == provider.supportsAgentTier
            )
        }
        #expect(CloudModelProvider.allowsPlainChatTools(provider: .openAI, allProvidersArmed: false) == true)
        #expect(CloudModelProvider.allowsPlainChatTools(provider: .anthropic, allProvidersArmed: false) == true)
        #expect(CloudModelProvider.allowsPlainChatTools(provider: .google, allProvidersArmed: false) == false)
        #expect(CloudModelProvider.allowsPlainChatTools(provider: .deepseek, allProvidersArmed: false) == false)
    }

    @Test("flag ON → every provider that supports chat-tool-attachment gets plain-chat tools")
    func gateOnOpensAllProviders() {
        for provider in CloudModelProvider.allCases {
            #expect(
                CloudModelProvider.allowsPlainChatTools(provider: provider, allProvidersArmed: true) == true
            )
        }
        // The previously-excluded providers now qualify (the S4 fix).
        #expect(CloudModelProvider.allowsPlainChatTools(provider: .google, allProvidersArmed: true) == true)
        #expect(CloudModelProvider.allowsPlainChatTools(provider: .kimi, allProvidersArmed: true) == true)
        #expect(CloudModelProvider.allowsPlainChatTools(provider: .minimax, allProvidersArmed: true) == true)
    }

    @Test("every shipped cloud provider is function-calling capable (supportsChatToolAttachment)")
    func allProvidersSupportChatToolAttachment() {
        for provider in CloudModelProvider.allCases {
            #expect(provider.supportsChatToolAttachment == true)
        }
    }
}
