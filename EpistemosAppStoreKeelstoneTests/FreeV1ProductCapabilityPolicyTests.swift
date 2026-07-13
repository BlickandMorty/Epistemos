import Foundation
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX
#error("Free V1 product-capability tests must compile with the Mac App Store sandbox lane.")
#endif

private nonisolated final class FreeV1KeychainReadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var keys: [String] = []

    func load(_ key: String) -> String? {
        lock.lock()
        keys.append(key)
        lock.unlock()
        return "unexpected"
    }

    var reads: [String] {
        lock.lock()
        defer { lock.unlock() }
        return keys
    }
}

@Suite("Free V1 Product Capability Policy")
@MainActor
struct FreeV1ProductCapabilityPolicyTests {
    @Test("free V1 has one explicit capability partition")
    func capabilityPartitionIsComplete() {
        let expectedFree: Set<ProductCapability> = [
            .epdocPlanner,
            .knowledgeGraph,
            .kokoroVoice,
            .meeting,
            .pdfImport,
            .quickCapture,
            .reckoner,
            .search,
            .sync,
            .workspaceExport,
        ]
        let expectedPaid: Set<ProductCapability> = [
            .agentAutomation,
            .browser,
            .epdocAssist,
            .generativeActions,
            .june,
            .models,
            .researchHub,
        ]

        #expect(ProductCapabilityPolicy.currentEdition == .freeV1)
        #expect(Set(ProductCapability.allCases) == expectedFree.union(expectedPaid))
        #expect(Set(ProductCapabilityPolicy.freeCapabilities) == expectedFree)
        #expect(Set(ProductCapabilityPolicy.paidCapabilities) == expectedPaid)
        #expect(ProductCapabilityPolicy.freeCapabilities.allSatisfy(ProductCapabilityPolicy.isAvailable))
        #expect(ProductCapabilityPolicy.paidCapabilities.allSatisfy { !ProductCapabilityPolicy.isAvailable($0) })
    }

    @Test("landing hides paid features but keeps their future routes classified")
    func landingVisibilityUsesTheReleasePolicy() {
        #expect(LandingFeatureButton.visibleCases == [.pdfImport, .meetingNote])
        #expect(LandingFeatureButton.pdfImport.productCapability == .pdfImport)
        #expect(LandingFeatureButton.meetingNote.productCapability == .meeting)
        #expect(LandingFeatureButton.arxiv.productCapability == .researchHub)
        #expect(LandingFeatureButton.browser.productCapability == .browser)
        #expect(LandingFeatureButton.agent.productCapability == .june)
        #expect(LandingFeatureButton.arxiv.isPaidOnly)
        #expect(LandingFeatureButton.browser.isPaidOnly)
        #expect(LandingFeatureButton.agent.isPaidOnly)
    }

    @Test("paid home routes fail closed while free routes remain intact")
    func homeRouteSanitizationFailsClosed() {
        #expect(LandingViewStateSync.sanitizedHomeContent(.agent) == .greeting)
        #expect(LandingViewStateSync.sanitizedHomeContent(.arxiv) == .greeting)
        #expect(LandingViewStateSync.sanitizedHomeContent(.browser) == .greeting)
        #expect(LandingViewStateSync.sanitizedHomeContent(.greeting) == .greeting)
        #expect(LandingViewStateSync.sanitizedHomeContent(.graph) == .graph)
        #expect(LandingViewStateSync.sanitizedHomeContent(.meeting) == .meeting)
    }

    @Test("settings and utility windows cannot deep-link around the free boundary")
    func deepLinksCannotBypassThePolicy() {
        #expect(SettingsView.SettingsSection.visibleSections.contains(.voice))
        #expect(!SettingsView.SettingsSection.visibleSections.contains(.cloudModels))
        #expect(SettingsView.SettingsSection.safeDetailSelection(for: .cloudModels) == .general)
        #expect(UtilityPanel.meetingNote.isAvailableInCurrentEdition)
        #expect(!UtilityPanel.browser.isAvailableInCurrentEdition)
    }

    @Test("generation admission fails before a model closure can run")
    func generationAdmissionFailsClosed() async {
        var didInvokeModel = false
        let service = AppleIntelligenceService(
            foundationModelsGenerate: { _, _ in
                didInvokeModel = true
                return "should never run"
            }
        )

        do {
            _ = try await service.generate(prompt: "test")
            Issue.record("Free V1 unexpectedly admitted generation.")
        } catch let error as ProductCapabilityUnavailableError {
            #expect(error.capability == .generativeActions)
        } catch {
            Issue.record("Unexpected generation error: \(error)")
        }

        #expect(!didInvokeModel)
    }

    @Test("paid App Intents are not discoverable in free V1")
    func paidIntentsAreHidden() {
        #expect(EpistemosShortcutsProvider.appShortcuts.count == 4)
        #expect(!AskAboutNotesIntent.isDiscoverable)
        #expect(!SummarizeNoteIntent.isDiscoverable)
        #expect(!DailyBriefingIntent.isDiscoverable)
        #expect(!RecallActiveThesisIntent.isDiscoverable)
        #expect(!OpenRawThoughtSandboxIntent.isDiscoverable)
        #expect(!DelegateToAgentIntent.isDiscoverable)
    }

    @Test("free V1 launch does not read model-provider secrets")
    func launchSkipsProviderCredentialReads() {
        let keychainReads = FreeV1KeychainReadRecorder()
        let inference = InferenceState(
            keychainLoad: { keychainReads.load($0) },
            keychainSave: { _, _ in false },
            keychainDelete: { _ in },
            deferCloudCredentialBootstrapOnLaunch: false,
            skipCloudCredentialBootstrapOnLaunch: false
        )

        #expect(keychainReads.reads.isEmpty)
        #expect(!inference.isDeferredCloudCredentialBootstrapInFlight)
        #expect(!inference.cloudModelsEnabled)
        #expect(inference.activeCloudProvider == nil)
        #expect(inference.configuredCloudProviders.isEmpty)
        #expect(inference.apiKey(for: .openAI) == nil)
    }

    @Test("free V1 app bundle omits paid runtime resources")
    func appBundleOmitsPaidRuntimeResources() {
        #expect(Bundle.main.bundleIdentifier == "com.epistemos.appstore")
        #expect(Bundle.main.url(forResource: "JuneWeb", withExtension: nil) == nil)
        #expect(Bundle.main.url(forResource: "model_manifest", withExtension: "json") == nil)
        #expect(Bundle.main.url(forResource: "DefaultSkills", withExtension: nil) == nil)
    }
}
