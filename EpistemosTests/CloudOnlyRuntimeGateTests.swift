import Foundation
import Testing
@testable import Epistemos

// RUNTIME GATE for the cloud-only migration (2026-07-03).
// After removing all local-model routing, the chat-surface resolver must, with a
// configured cloud provider, resolve to a cloud (or Apple Intelligence) surface and
// NEVER to a local runtime. This proves the removal did not silently break cloud
// inference into a "no model" state — the exact failure mode the surgery guarded.
@MainActor
private func makeCloudConfiguredInference() -> InferenceState {
    let store = TestKeychainStore(values: [
        CloudModelProvider.openAI.apiKeyKeychainKey: "sk-openai-test"
    ])
    let inference = InferenceState(
        keychainLoad: store.load(_:),
        keychainSave: store.save(_:_:),
        keychainDelete: store.delete(_:)
    )
    inference.setPreferredChatModelSelection(.cloud(.openAIGPT54))
    return inference
}

@Suite("Cloud-Only Runtime Gate")
@MainActor
struct CloudOnlyRuntimeGateTests {
    @Test("A configured cloud provider is recognized")
    func cloudProviderConfigured() {
        let inference = makeCloudConfiguredInference()
        #expect(inference.configuredCloudProviders.contains(.openAI))
        #expect(inference.hasConfiguredCloudModels)
    }

    @Test("effectiveChatSurfaceSelection never resolves to a local runtime")
    func chatSurfaceNeverLocal() {
        let inference = makeCloudConfiguredInference()
        for mode in EpistemosOperatingMode.allCases {
            let selection = inference.effectiveChatSurfaceSelection(for: mode)
            if case .localMLX = selection {
                Issue.record("effectiveChatSurfaceSelection(\(mode)) returned .localMLX — a local runtime must be impossible in a cloud-only build")
            }
        }
    }

    @Test("An explicit cloud pin resolves to .cloud")
    func explicitCloudPinHonored() {
        let inference = makeCloudConfiguredInference()
        let selection = inference.effectiveChatSurfaceSelection(for: .fast)
        guard case .cloud = selection else {
            Issue.record("A pinned cloud selection resolved to \(selection) instead of .cloud")
            return
        }
    }
}
