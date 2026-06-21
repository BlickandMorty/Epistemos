import Testing
import Foundation

@testable import Epistemos

// SS-GE (owner 2026-06-21): Raw Thoughts V0 hides its per-vault sidebar surface
// when the emitter flag is off, so the owner "didn't see raw thoughts, wasn't
// sure it's still a thing." A read-only Settings diagnostics row makes it honest
// + discoverable. These pin the status copy: off explains how to enable it + that
// nothing records yet; on confirms recording + where to browse. The row is
// read-only and reflects the real env-gated emitter state — never a do-nothing
// toggle (flipping a UI control here would NOT make the Rust emitter write).
@Suite("SS-GE — raw thoughts diagnostic honesty")
struct SSGERawThoughtsDiagnosticTests {

    @Test("OFF status names the flag to enable + where runs land + where to browse")
    func offStatusIsActionable() {
        let off = RawThoughtsState.diagnosticStatus(isEnabled: false)
        #expect(off.contains("Off"))
        #expect(off.contains("EPISTEMOS_RAW_THOUGHTS_V0"))   // how to turn it on
        #expect(off.contains("Raw Thoughts/"))               // where runs land
        #expect(off.contains("model vault row"))             // where to browse
    }

    @Test("ON status confirms recording + where to browse, without the enable hint")
    func onStatusConfirmsRecording() {
        let on = RawThoughtsState.diagnosticStatus(isEnabled: true)
        #expect(on.contains("On"))
        #expect(on.contains("recording"))
        #expect(on.contains("Raw Thoughts/"))
        // The enable instruction belongs only to the off state.
        #expect(!on.contains("set EPISTEMOS_RAW_THOUGHTS_V0=1"))
    }

    @Test("the static emission flag mirrors the env (default off in a clean test process)")
    func emissionFlagMirrorsEnv() {
        // The test process doesn't set the flag, so the live default must be off —
        // this is the honest gate the diagnostics row reports.
        if ProcessInfo.processInfo.environment["EPISTEMOS_RAW_THOUGHTS_V0"] == nil {
            #expect(RawThoughtsState.isEmissionEnabled == false)
        }
    }
}
