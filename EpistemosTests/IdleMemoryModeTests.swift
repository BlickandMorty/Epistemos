import Testing
import Foundation

@testable import Epistemos

// The Performance Settings "Idle Memory Mode" picker (keepWarm / lowMemory) had ZERO consumers app-wide
// — PerformanceSettingsReader.idleMemoryMode was never read by the idle-unload logic, so the picker did
// nothing AND its keepWarm copy falsely claimed the model "stays resident" (it always unloaded after
// the hardware-tuned 2–15 s). Now MLXInferenceService applies IdleMemoryMode.idleUnloadDelay to the
// computed delay. These pin that wiring: keepWarm preserves the balanced default (no idle regression),
// lowMemory caps it to release promptly; and a source guard pins the live consumer so the picker can't
// silently regress to a do-nothing-picker.
@Suite("IdleMemoryMode.idleUnloadDelay — Performance Settings picker actually controls idle unload")
struct IdleMemoryModeTests {

    @Test("keepWarm preserves the hardware-tuned base delay (no regression to the default)")
    func keepWarmPreservesBase() {
        #expect(IdleMemoryMode.keepWarm.idleUnloadDelay(base: .seconds(6)) == .seconds(6))
        #expect(IdleMemoryMode.keepWarm.idleUnloadDelay(base: .seconds(15)) == .seconds(15))
    }

    @Test("lowMemory caps the delay to release promptly (~2s)")
    func lowMemoryCaps() {
        #expect(IdleMemoryMode.lowMemory.idleUnloadDelay(base: .seconds(6)) == .seconds(2))
        #expect(IdleMemoryMode.lowMemory.idleUnloadDelay(base: .seconds(15)) == .seconds(2))
    }

    @Test("lowMemory only CAPS — it never extends an already-short (e.g. thermal-capped) delay")
    func lowMemoryNeverExtends() {
        #expect(IdleMemoryMode.lowMemory.idleUnloadDelay(base: .seconds(1)) == .seconds(1))
    }

    @Test("MLXInferenceService actually consumes the picker (no silent do-nothing-picker regression)")
    func mlxConsumesTheMode() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/MLXInferenceService.swift")
        #expect(src.contains("PerformanceSettingsReader.idleMemoryMode.idleUnloadDelay(base: idleUnloadDelay)"))
    }
}
