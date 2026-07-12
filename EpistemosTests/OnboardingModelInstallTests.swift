import Testing
import Foundation
@testable import Epistemos

/// The setup wizard does not duplicate June's model picker/download controls.
/// Model selection belongs to June and MAS Settings, while optional Kokoro
/// voice setup remains a first-run concern.
@Suite("Onboarding model stack pruning")
struct OnboardingModelInstallTests {

    @Test("the wizard does not mount local model install or inference setup")
    func wizardDoesNotMountLocalModelInstallOrInferenceSetup() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Onboarding/SetupAssistantView.swift"
        )

        #expect(!src.contains("localModelManager.installEpistemosFoundationPackage()"))
        #expect(!src.contains("Install Epistemos AI"))
        #expect(!src.contains("CloudProviderSetupCard("))
        #expect(!src.contains("Cloud AI"))
        #expect(!src.contains("Button(\"Open Settings → Inference\")"))
        #expect(src.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX\n            Text(\"June Foundation\")"))
        #expect(src.contains("MAS June uses your vault, fast search, provenance, and approval-gated tools."))
        #expect(src.contains("connected OpenAI or Anthropic models, Apple Intelligence when available, and your selected local GGUF models."))
        #expect(src.contains("statusRow(\"MAS June\", done: true)"))
        #expect(src.contains("statusRow(\"Approval-gated tools\", done: true)"))
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
