import Testing
@testable import Epistemos

@Suite("AI Partner Control Panel")
struct AIPartnerControlPanelTests {
    @Test("control slider clamps invalid label indices")
    func controlSliderClampsInvalidLabelIndices() {
        let labels = ["Calm", "Balanced", "Frequent", "Aggressive"]

        #expect(ControlSlider.resolvedLabel(for: -1, labels: labels) == "Calm")
        #expect(ControlSlider.resolvedLabel(for: 9, labels: labels) == "Aggressive")
        #expect(ControlSlider.resolvedLabel(for: .nan, labels: labels) == "Calm")
        #expect(ControlSlider.resolvedLabel(for: .infinity, labels: []) == "")
    }

    @Test("enum slider selection clamps values and preserves current selection for non-finite input")
    func enumSliderSelectionClampsValuesAndPreservesCurrentSelectionForNonFiniteInput() {
        #expect(AIPartnerConfiguration.Frequency.caseForSliderValue(-4, current: .balanced) == .calm)
        #expect(AIPartnerConfiguration.Frequency.caseForSliderValue(8, current: .balanced) == .aggressive)
        #expect(AIPartnerConfiguration.Frequency.caseForSliderValue(.nan, current: .balanced) == .balanced)

        #expect(AIPartnerConfiguration.InsightDepth.caseForSliderValue(8, current: .standard) == .exhaustive)
        #expect(AIPartnerConfiguration.ContextWindow.caseForSliderValue(-2, current: .medium) == .narrow)
        #expect(AIPartnerConfiguration.ContextWindow.caseForSliderValue(.infinity, current: .wide) == .wide)
    }
}
