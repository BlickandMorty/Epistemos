import Testing
import Foundation

@testable import Epistemos

// SUBSTRATE Phase 4 (owner 2026-06-20): the System G health row honestly reflects the verified P3
// provider behavior — local MLX/GGUF missions get a REAL LocalModelHandoff (Swift host streams the
// live model), cloud providers fail HONESTLY (provider_not_bound, never a fake run), and System G
// green stays blocked on a primary falsifier witness. Pairs with the Rust guard
// start_run_with_cloud_provider_fails_honestly_without_fake_handoff. No fake-green.
@Suite("System G provider honesty (health row reflects verified P3 behavior)")
struct SystemGProviderHonestyTests {

    @Test("SystemGHealthRow states local handoff is real + cloud fails honestly, no fake-green")
    func healthRowReflectsProviderBehavior() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SystemGHealthRow.swift")
        #expect(src.contains("local MLX/GGUF missions get a real LocalModelHandoff"))
        #expect(src.contains("cloud providers fail honestly (provider_not_bound)"))
        // Still honest: green is NOT claimed, and cloud executors are acknowledged unbound.
        #expect(src.contains("falsifierPassed: false"))
        #expect(src.contains("Cloud executors aren't bound"))
    }
}
