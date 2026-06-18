import Testing
import Foundation

/// NO-SIDECAR invariant lock (owner P5.H / LF-1..3). The MoLoRA inference service
/// uses a Python subprocess on the Pro/dev build, but it MUST stay compiled out
/// of the App Store (MAS) build — the sandbox + hardened runtime forbid spawning
/// a subprocess. This guards that the spawn is inside `#if !EPISTEMOS_APP_STORE`
/// and the MAS branch fails honestly (never spawns), so a future refactor can't
/// silently leak the sidecar onto the shipped MAS path.
///
/// (The full in-process MLX-Swift port that removes the Python subprocess even on
/// Pro/dev is LF-1/W7-H — a larger item; this locks the MAS safety that already
/// holds.)
@Suite("MoLoRA NO-SIDECAR guard")
struct MoLoRANoSidecarGuardTests {

    @Test("the Python subprocess spawn is compiled out of the App Store build")
    func pythonSubprocessIsMASCompiledOut() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift"
        )

        // The subprocess spawn exists (Pro/dev) ...
        #expect(src.contains("proc.executableURL = URL(fileURLWithPath: pythonPath)"))
        // ... gated behind the App Store compile flag ...
        #expect(src.contains("#if !EPISTEMOS_APP_STORE"))
        // ... and the MAS branch fails honestly instead of spawning.
        #expect(src.contains("MoLoRA inference is not available in the App Store sandbox build."))

        // The spawn must appear AFTER an `#if !EPISTEMOS_APP_STORE` guard opens
        // and BEFORE the matching `#else` MAS branch — i.e., inside the gated
        // region, never on the shipped MAS path.
        guard let guardOpen = src.range(of: "#if !EPISTEMOS_APP_STORE"),
              let spawn = src.range(of: "proc.executableURL = URL(fileURLWithPath: pythonPath)"),
              let masBranch = src.range(of: "MoLoRA inference is not available in the App Store sandbox build.")
        else {
            Issue.record("expected the guard, the spawn, and the MAS-honest error to all be present")
            return
        }
        #expect(guardOpen.upperBound <= spawn.lowerBound, "spawn must be inside the !EPISTEMOS_APP_STORE guard")
        #expect(spawn.upperBound <= masBranch.lowerBound, "MAS-honest error is the #else branch after the spawn")
    }
}
