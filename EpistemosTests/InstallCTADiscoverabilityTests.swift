import Testing
@testable import Epistemos

/// Model-install discoverability (owner 2026-06-19, top blocker — "still cannot
/// find a way to install a local model"): the picker now shows an "Install local
/// AI" CTA that opens the model manager, but ONLY when no foundation model is
/// installed (otherwise the picker has real picks and the CTA would be noise).
@Suite("In-picker install CTA discoverability")
struct InstallCTADiscoverabilityTests {

    @Test("CTA shows only when no foundation model is installed")
    func ctaVisibility() {
        #expect(
            InlineRuntimePickerPanel.shouldShowInstallCTA(hasInstalledFoundationModel: false) == true
        )
        #expect(
            InlineRuntimePickerPanel.shouldShowInstallCTA(hasInstalledFoundationModel: true) == false
        )
    }
}
