import Testing
@testable import Epistemos

@Suite("Local Inference Serial Controller")
struct LocalInferenceSerialControllerTests {
    @Test("process available memory monitor returns a positive value")
    func processAvailableMemoryMonitorReturnsPositiveValue() {
        #expect(LocalInferenceMemoryPressureMonitor.availableMemoryBytes() > 0)
    }

    @Test("controller forbids disk reads during active gpu compute")
    func controllerForbidsDiskReadsDuringActiveGpuCompute() throws {
        let controller = LocalInferenceSerialController(
            pressureThresholdBytes: 1_200_000_000,
            recoveryThresholdBytes: 1_800_000_000,
            nonExpertResidentBytes: 3_000_000_000
        )

        try controller.beginTurn()
        try controller.beginGpuCompute()

        do {
            try controller.beginSsdRead()
            Issue.record("Expected beginSsdRead() to fail during GPU compute.")
        } catch {
            #expect(error.localizedDescription.contains("Disk reads are forbidden"))
        }
    }

    @Test("controller exposes fallback snapshot with expert prefetch disabled")
    func controllerExposesFallbackSnapshotWithExpertPrefetchDisabled() {
        let controller = LocalInferenceSerialController(
            pressureThresholdBytes: 1_200_000_000,
            recoveryThresholdBytes: 1_800_000_000,
            nonExpertResidentBytes: 3_000_000_000
        )

        let snapshot = controller.refreshAvailableMemory()

        #expect(snapshot.nonExpertResidentBytes == 3_000_000_000)
        #expect(snapshot.expertPrefetchAllowed == false)
    }
}
