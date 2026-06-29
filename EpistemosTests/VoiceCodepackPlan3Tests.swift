import Foundation
import Testing

@testable import Epistemos

@Suite("Plan 3 Voice codepack")
struct VoiceCodepackPlan3Tests {
    @Test("voice codepack matches the wired MAS-safe voice state")
    func voiceCodepackMatchesWiredState() throws {
        let plan = try loadMirroredSourceTextFile("docs/research/PLAN_3_VOICE_CODEPACK_2026_06_28.md")

        for required in [
            "Visible auto toggles are consumer-backed",
            "No-op Settings toggles are hidden",
            "Shared mic control is now backed by live Apple STT",
            "Live macOS 26 STT is surfaced",
            "Preferred voice floor is quality-first",
            "SSML/prosody fallback exists",
            "Pro Kokoro gate is honest",
            "[DONE] Patch the AVSpeech preferred voice floor",
            "[DONE] Wire or remove `agentResponseTTS`",
            "[DONE] Add `LiveVoiceInputService`",
            "[DONE] Rewire `VoiceInputButton`",
            "[DONE] Add SSML/prosody fallback",
            "[DONE] Add the Kokoro Pro gate"
        ] {
            #expect(plan.contains(required), "Missing voice codepack state: \(required)")
        }
    }

    @Test("voice codepack has no stale contradiction claims")
    func voiceCodepackHasNoStaleContradictions() throws {
        let plan = try loadMirroredSourceTextFile("docs/research/PLAN_3_VOICE_CODEPACK_2026_06_28.md")

        for stale in [
            "clone-ready",
            "[INFERRED]",
            "One Settings toggle is still inert",
            "Composer STT is currently disabled",
            "Live macOS 26 STT exists but is orphaned",
            "still renders a mic affordance over that stub",
            "no user-facing composer/meeting surface calls it",
            "runs summary through existing chat engines"
        ] {
            #expect(!plan.contains(stale), "Voice codepack kept stale contradiction: \(stale)")
        }
    }

    @Test("voice codepack and rollup mark shipped state honestly")
    func voiceCodepackAndRollupMarkShippedStateHonestly() throws {
        let plan = try loadMirroredSourceTextFile("docs/research/PLAN_3_VOICE_CODEPACK_2026_06_28.md")
        let capabilities = try loadMirroredSourceTextFile("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")

        #expect(plan.contains("shipped code"))
        #expect(plan.contains("## Shipped state"))
        #expect(plan.contains("## Delivered MAS-safe fixes"))
        #expect(plan.contains("## Pro Kokoro lane `[STATUS GATE DELIVERED; RUNTIME DEFERRED]`"))
        #expect(plan.contains("## Delivery order"))
        #expect(capabilities.contains("Voice — SHIPPED (Pass 8)"))
        #expect(capabilities.contains("Kokoro-82M is Pro-only status-gated"))
        #expect(capabilities.contains("no model asset, picker row, neural runtime, Python, or"))

        for stale in [
            "Research/code in a later pass",
            "Kokoro-82M Pro voice + SSML",
        ] where capabilities.contains(stale) {
            Issue.record("Plan 3 capabilities still contains stale Voice phrase: \(stale)")
        }
    }

    @Test("voice codepack preserves Plan 3 MAS and ownership boundaries")
    func voiceCodepackPreservesBoundaries() throws {
        let plan = try loadMirroredSourceTextFile("docs/research/PLAN_3_VOICE_CODEPACK_2026_06_28.md")

        for required in [
            "Do not edit `Epistemos/Goose/*`",
            "Do not build Plan 2 editor features here",
            "Apple Speech/AVSpeech are the MAS defaults",
            "Whisper/Kokoro are Pro options",
            "Do not add Python/subprocess inference on the MAS path"
        ] {
            #expect(plan.contains(required), "Missing voice boundary: \(required)")
        }
    }

    @Test("voice button routes through the live SpeechAnalyzer facade")
    func voiceButtonRoutesThroughLiveSpeechAnalyzerFacade() throws {
        let button = try loadMirroredSourceTextFile("Epistemos/Views/Shared/VoiceInputButton.swift")
        let facade = try loadMirroredSourceTextFile("Epistemos/Engine/LiveVoiceInputService.swift")

        #expect(button.contains("LiveVoiceInputService.shared"))
        #expect(button.contains(".onChange(of: service.partialTranscript)"))
        #expect(button.contains(".onChange(of: service.finalTranscript)"))
        #expect(!button.contains("ComposerVoiceInputService.shared"))
        #expect(!button.contains("service.latestTranscript"))

        #expect(facade.contains("EpistemosSpeechAnalyzer.shared.startLive"))
        #expect(facade.contains("EpistemosSpeechAnalyzer.shared.stop()"))
        #expect(facade.contains("@available(macOS 26.0, *)"))
        #expect(facade.contains("modelDownloadProgress"))
        #expect(facade.contains("finalTranscriptBuffer"))
        #expect(facade.contains("finalTranscriptBuffer.append(cleaned)"))
        #expect(facade.contains("pending.joined(separator: \"\\n\\n\")"))
    }

    @Test("voice MAS path has no Pro neural or hidden runtime dependency")
    func voiceMASPathHasNoProRuntimeDependency() throws {
        let files = [
            "Epistemos/Engine/EpistemosSpeechSynthesizer.swift",
            "Epistemos/Engine/LiveVoiceInputService.swift",
            "Epistemos/Views/Shared/VoiceInputButton.swift",
            "Epistemos/Views/Settings/VoicePreferencesSection.swift"
        ]

        for file in files {
            let source = try loadMirroredSourceTextFile(file)
            for forbidden in ["Kokoro", "Whisper", "Process(", "NSTask", "Python", "Chromium"] {
                #expect(!source.contains(forbidden), "\(file) crossed voice MAS boundary: \(forbidden)")
            }
        }
    }

    @Test("Kokoro Pro gate is honest and does not add a runtime")
    func kokoroProGateIsHonestAndRuntimeFree() throws {
        let gate = try loadMirroredSourceTextFile("Epistemos/VoicePro/KokoroVoiceGateStatus.swift")

        for required in [
            "nonisolated enum KokoroVoiceGateStatus",
            "EPISTEMOS_KOKORO_VOICE_PRO_V0",
            "case unavailable",
            "case missingModel",
            "case ready",
            "#if EPISTEMOS_APP_STORE || MAS_SANDBOX",
            "Kokoro voice: unavailable in App Store build",
            "modelDirectoryName = \"kokoro-82m-coreml\"",
            "manifestFileName = \"manifest.json\"",
            "modelPackageName = \"Kokoro82M.mlpackage\"",
            "artifactProblem(",
            "resolvesInsideModelDirectory",
            "AVSpeech remains the voice runtime",
            "Picker/runtime integration must still choose this lane explicitly"
        ] {
            #expect(gate.contains(required), "Kokoro gate missing honesty string: \(required)")
        }

        for forbidden in [
            "URLSession",
            "Process(",
            "NSTask",
            "Bundle.main.resourceURL",
            "Resources/Kokoro",
            "Python"
        ] {
            #expect(!gate.contains(forbidden), "Kokoro gate added forbidden runtime path: \(forbidden)")
        }
    }

    @Test("Kokoro Pro gate rejects malformed package shapes")
    func kokoroProGateRejectsMalformedPackageShapes() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-gate-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data("not a CoreML package\n".utf8).write(
            to: modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.modelPackageName, isDirectory: false)
        )

        let status = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!status.isReady)
        #expect(status.state == .missingModel)
        #expect(status.detail.contains("manifest.json is a directory"))
        #expect(status.detail.contains("Kokoro82M.mlpackage is not a directory"))
        #else
        #expect(true)
        #endif
    }
}
