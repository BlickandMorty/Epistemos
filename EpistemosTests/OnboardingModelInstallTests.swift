import Testing
import Foundation
@testable import Epistemos

/// The setup wizard stays foundation-only after the failed native model stack
/// deletion. Model chat/provider setup belongs to the connected provider
/// surfaces, not first-run Epistemos onboarding.
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
}
