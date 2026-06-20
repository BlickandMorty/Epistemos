import Testing
import Foundation
@testable import Epistemos

/// SS-C (the #1 onboarding blocker): the setup wizard installs the Epistemos AI
/// foundation model IN-flow — the SAME one-tap `installEpistemosFoundationPackage`
/// the model manager uses — instead of punting the user out to "Open Settings →
/// Inference" to find and download a model.
@Suite("Onboarding model install in-flow (SS-C)")
struct OnboardingModelInstallTests {

    @Test("the wizard installs the foundation model in-flow, not by punting to Settings")
    func wizardInstallsInFlow() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Onboarding/SetupAssistantView.swift"
        )
        // The model step triggers the same one-tap install the model manager uses.
        #expect(src.contains("localModelManager.installEpistemosFoundationPackage()"))
        #expect(src.contains("Install Epistemos AI"))
        // The old single "Open Settings → Inference" punt is gone (replaced by the
        // in-flow install + a secondary "More Models").
        #expect(!src.contains("Button(\"Open Settings → Inference\")"))
    }
}
