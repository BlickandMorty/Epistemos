import Testing
import Foundation
@testable import Epistemos

/// SS-C/SS-E (owner: "automate the defaults; reduce complexity; it should just
/// work"): the setup wizard now offers the auto-derived default vault
/// (~/Documents/Epistemos via FirstRunBootstrap.defaultVaultURL — which was DEAD
/// code, never invoked) as a one-tap path, instead of forcing an NSOpenPanel.
@Suite("Onboarding default vault (SS-C/SS-E)")
struct OnboardingDefaultVaultTests {

    @Test("defaultVaultURL derives ~/Documents/Epistemos (or the ~/Epistemos fallback)")
    func defaultVaultURLDerivesDocumentsEpistemos() {
        let url = FirstRunBootstrap.defaultVaultURL()
        #expect(url.lastPathComponent == "Epistemos")
        #expect(
            url.deletingLastPathComponent().lastPathComponent == "Documents"
                || url.path.hasSuffix("/Epistemos")
        )
    }

    @Test("the setup wizard offers the derived default vault (revives the dead auto-default)")
    func wizardOffersDefaultVault() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Onboarding/SetupAssistantView.swift"
        )
        // A one-tap "Use Default" button that connects FirstRunBootstrap.defaultVaultURL
        // through the same path a picked folder takes.
        #expect(src.contains("Button(\"Use Default\")"))
        #expect(src.contains("FirstRunBootstrap.defaultVaultURL()"))
        #expect(src.contains("VaultConnectionActions.connectSelectedVault(url: url, vaultSync: vaultSync)"))
    }
}
