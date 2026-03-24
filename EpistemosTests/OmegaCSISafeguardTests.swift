import Testing
@testable import Epistemos

@Suite("CSI Safeguard")
@MainActor
struct CSISafeguardTests {

    @Test("Starts untriggered")
    func initialState() {
        let safeguard = CSISafeguard()
        #expect(!safeguard.isTriggered)
        #expect(safeguard.csiHistory.isEmpty)
        #expect(safeguard.triggerMeasurement == nil)
    }

    @Test("Allows training with healthy CSI")
    func healthyCSI() {
        let safeguard = CSISafeguard(threshold: 0.3)
        let shouldContinue = safeguard.recordMeasurement(value: 0.8, epoch: 1, experimentId: "exp-1")
        #expect(shouldContinue)
        #expect(!safeguard.isTriggered)
    }

    @Test("Halts training when CSI drops below threshold")
    func belowThreshold() {
        let safeguard = CSISafeguard(threshold: 0.3)
        _ = safeguard.recordMeasurement(value: 0.5, epoch: 1, experimentId: "exp-1")
        let shouldContinue = safeguard.recordMeasurement(value: 0.2, epoch: 2, experimentId: "exp-1")
        #expect(!shouldContinue)
        #expect(safeguard.isTriggered)
        #expect(safeguard.triggerMeasurement != nil)
        #expect(safeguard.triggerMeasurement?.epoch == 2)
    }

    @Test("Detects rapid CSI decline")
    func rapidDecline() {
        let safeguard = CSISafeguard(threshold: 0.1) // Very low threshold
        _ = safeguard.recordMeasurement(value: 1.0, epoch: 1, experimentId: "exp-1")
        _ = safeguard.recordMeasurement(value: 0.6, epoch: 2, experimentId: "exp-1")
        let shouldContinue = safeguard.recordMeasurement(value: 0.3, epoch: 3, experimentId: "exp-1")
        // 1.0 → 0.3 = 70% decline > 50% threshold
        #expect(!shouldContinue)
        #expect(safeguard.isTriggered)
    }

    @Test("Reset clears state")
    func reset() {
        let safeguard = CSISafeguard(threshold: 0.3)
        _ = safeguard.recordMeasurement(value: 0.1, epoch: 1, experimentId: "exp-1")
        #expect(safeguard.isTriggered)

        safeguard.reset()
        #expect(!safeguard.isTriggered)
        #expect(safeguard.csiHistory.isEmpty)
        #expect(safeguard.triggerMeasurement == nil)
    }

    @Test("computeCSI returns high value for good separation")
    func computeCSIGoodSeparation() {
        let csi = CSISafeguard.computeCSI(
            intraClusterDistances: [0.1, 0.2, 0.15],
            interClusterDistances: [0.8, 0.9, 0.85]
        )
        #expect(csi > 4.0) // inter >> intra
    }

    @Test("computeCSI returns low value for poor separation")
    func computeCSIPoorSeparation() {
        let csi = CSISafeguard.computeCSI(
            intraClusterDistances: [0.5, 0.6, 0.55],
            interClusterDistances: [0.5, 0.4, 0.45]
        )
        #expect(csi < 1.0) // inter ≈ intra
    }

    @Test("computeCSI handles empty arrays")
    func computeCSIEmpty() {
        let csi = CSISafeguard.computeCSI(intraClusterDistances: [], interClusterDistances: [])
        #expect(csi == 1.0) // default safe value
    }
}
