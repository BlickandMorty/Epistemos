import Testing
import Foundation
@testable import Epistemos

/// The setup wizard stays out of chat-model/provider setup after the failed
/// native model stack deletion. Model chat/provider setup belongs to the
/// connected provider surfaces, not first-run Epistemos onboarding.
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
        #expect(src.contains("Download Voice"))
        #expect(src.contains("statusRow(\"Kokoro voice\""))
        #expect(src.contains("KokoroModelDownloadService.shared.startInstall"))
    }
}
