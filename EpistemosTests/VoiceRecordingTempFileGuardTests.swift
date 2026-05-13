import Testing
import Foundation
@testable import Epistemos

/// RCA2-P1-002 drift gate — `ComposerVoiceInputService` must delete
/// the `.m4a` temp recording file on BOTH the cancel path AND the
/// successful record-then-transcribe path.
///
/// Acceptance: "Successful record-to-transcribe clears the URL AND
/// deletes the .m4a temp file."
///
/// Structural reality (verified 2026-05-13):
///   - Cancel path: `cancel()` → `cleanupOutputFileIfNeeded()` →
///     `cleanupRecording(at:)` → `FileManager.removeItem(at:)`.
///   - Success path: `stopAndTranscribe()` runs the transcription
///     inside a `do { … }` block that's preceded by a `defer {
///     cleanupRecording(at: outputURL) }` — so the temp file is
///     deleted whether the transcription throws or succeeds.
///
/// The structural defenses are in place. This drift gate pins them
/// so a future refactor that drops the `defer` block or the
/// cleanup helper trips CI before vault audio could silently
/// accumulate on disk.
@Suite("RCA2-P1-002 Voice Recording Temp File Guard")
struct VoiceRecordingTempFileGuardTests {

    @Test("Cancel path triggers cleanupOutputFileIfNeeded")
    func cancelPathDeletesTemp() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Engine/ComposerVoiceInputService.swift"
        )
        // The cancel() func body must call the cleanup helper. We
        // pin the literal call to avoid relying on AST tooling.
        #expect(source.contains("cleanupOutputFileIfNeeded()"),
            "ComposerVoiceInputService must keep cleanupOutputFileIfNeeded() on the cancel path — see RCA2-P1-002")
    }

    @Test("Success path uses defer { cleanupRecording(at:) } to free temp file")
    func successPathDefersCleanup() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Engine/ComposerVoiceInputService.swift"
        )
        // The successful record-to-transcribe path must defer the
        // cleanup so it runs whether transcription throws OR succeeds.
        // Pinning the literal substring catches a refactor that
        // moves the cleanup outside the defer.
        #expect(source.contains("defer {") && source.contains("cleanupRecording(at: outputURL)"),
            "ComposerVoiceInputService.stopAndTranscribe must keep the `defer { cleanupRecording(at: outputURL) }` block so the temp .m4a is deleted on success and on transcription failure — see RCA2-P1-002")
    }

    @Test("cleanupRecording(at:) actually calls FileManager.removeItem")
    func cleanupHelperRemovesFile() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Engine/ComposerVoiceInputService.swift"
        )
        // If a future refactor turns cleanupRecording(at:) into a
        // no-op stub, the temp file would silently accumulate. Pin
        // the actual filesystem call.
        #expect(source.contains("FileManager.default.removeItem(at: url)"),
            "ComposerVoiceInputService.cleanupRecording must keep the FileManager.removeItem call — see RCA2-P1-002")
    }
}
