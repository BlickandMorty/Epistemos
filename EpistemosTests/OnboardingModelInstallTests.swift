import Testing
import Foundation
@testable import Epistemos

/// Free onboarding must stay model-free while retaining optional Kokoro voice
/// setup as a first-run concern.
@Suite("Onboarding Free V1 foundation")
struct OnboardingModelInstallTests {

    @Test("the wizard keeps the Free foundation free of agent and generative setup")
    func wizardKeepsFreeFoundationFreeOfAgentAndGenerativeSetup() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Onboarding/SetupAssistantView.swift"
        )

        #expect(!src.contains("localModelManager.installEpistemosFoundationPackage()"))
        #expect(!src.contains("Install Epistemos AI"))
        #expect(!src.contains("CloudProviderSetupCard("))
        #expect(!src.contains("Cloud AI"))
        #expect(!src.contains("Button(\"Open Settings → Inference\")"))
        #expect(src.contains("Text(\"Free V1 Foundation\")"))
        #expect(src.contains("without agent or generative-model features."))
        #expect(src.contains("statusRow(\"Epdoc planning and tasks\", done: true)"))
        #expect(src.contains("statusRow(\"Meeting, PDF import, and Kokoro voice\", done: true)"))
        #expect(!src.contains("Text(\"June Foundation\")"))
        #expect(!src.contains("statusRow(\"MAS June\", done: true)"))
        #expect(!src.contains("statusRow(\"Approval-gated tools\", done: true)"))
    }

    @Test("the wizard offers optional Kokoro read-aloud setup")
    func wizardOffersOptionalKokoroReadAloudSetup() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Onboarding/SetupAssistantView.swift"
        )

        #expect(src.contains("case .voice"))
        #expect(src.contains("private var voiceStep"))
        #expect(src.contains("KokoroVoiceDownloadControls("))
        #expect(src.contains("@State private var selectedKokoroTier: KokoroModelDownloadService.Tier = .starter"))
        #expect(src.contains("currentStep = .voice"))
        #expect(src.contains("KokoroVoiceInstallPresentation.installTitle(for: selectedKokoroTier)"))
        #expect(src.contains("KokoroVoiceInstallPresentation.installHelp(for: selectedKokoroTier)"))
        #expect(!src.contains("idleButtonTitle: \"Download Voice\""))
        #expect(src.contains("case .installed:\n                let status = KokoroVoiceGateStatus.status()"))
        #expect(src.contains("kokoroInstallMessage = installedKokoroMessage(for: status)"))
        #expect(src.contains("statusRow(\"Kokoro voice\""))
        #expect(src.contains("KokoroModelDownloadService.shared.startInstall"))
    }
}
