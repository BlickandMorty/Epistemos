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
            "Shared mic callbacks are capture-owner gated",
            "Live macOS 26 STT is surfaced",
            "bounded domain/code diagnostics",
            "Preferred voice floor is quality-first",
            "SSML/prosody fallback exists",
            "Pro Kokoro gate is honest",
            "Readiness rejects symlink-routed or non-regular model artifacts",
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
        #expect(capabilities.contains("domain/code-redacted status/error text"))
        #expect(capabilities.contains("Kokoro-82M is Pro-only status-gated"))
        #expect(capabilities.contains("rejects symlink-routed, non-regular, oversized, or"))
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
        let analyzer = try loadMirroredSourceTextFile("Epistemos/Engine/EpistemosSpeechAnalyzer.swift")

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
        #expect(facade.contains("maxTranscriptCharacters"))
        #expect(facade.contains("TextCapturePipeline.maxCleanedTextCharacters"))
        #expect(facade.contains("partialTranscript = Self.boundedTranscript(text)"))
        #expect(facade.contains("let cleaned = Self.cleanedFinalTranscript(text)"))
        #expect(facade.contains("compactFinalTranscriptBuffer()"))
        #expect(facade.contains("Self.boundedTranscript(pending.joined(separator: \"\\n\\n\"))"))
        #expect(facade.contains("VoiceCapturePresentationBounds.modelDownloadProgress(progress)"))
        #expect(facade.contains("VoiceCapturePresentationBounds.statusMessage"))
        #expect(facade.contains("VoiceCaptureDiagnostics.externalStatusMessage"))
        #expect(!facade.contains("String(describing: error)"))
        #expect(analyzer.contains("VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: \"model download failed\")"))
        #expect(analyzer.contains("VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: \"audio engine failed\")"))
        #expect(!analyzer.contains("throw SpeechError.downloadFailed(error.localizedDescription)"))
        #expect(!analyzer.contains("throw SpeechError.audioEngineFailed(error.localizedDescription)"))
    }

    @Test("live voice transcript helpers enforce the capture text envelope")
    func liveVoiceTranscriptHelpersEnforceCaptureEnvelope() {
        let oversized = String(
            repeating: "a",
            count: LiveVoiceInputService.maxTranscriptCharacters + 17
        )

        #expect(LiveVoiceInputService.boundedTranscript(oversized).count == LiveVoiceInputService.maxTranscriptCharacters)
        #expect(LiveVoiceInputService.boundedTranscript("short") == "short")
        #expect(
            LiveVoiceInputService.cleanedFinalTranscript(" \n\(oversized)\n ")
                .count == LiveVoiceInputService.maxTranscriptCharacters
        )
        #expect(LiveVoiceInputService.cleanedFinalTranscript(" \n\t ") == "")
    }

    @Test("live voice presentation helpers bound progress and status strings")
    func liveVoicePresentationHelpersBoundProgressAndStatusStrings() {
        let oversizedMessage = String(
            repeating: "e",
            count: VoiceCapturePresentationBounds.maxStatusMessageCharacters + 31
        )

        #expect(VoiceCapturePresentationBounds.modelDownloadProgress(nil) == nil)
        #expect(VoiceCapturePresentationBounds.modelDownloadProgress(.nan) == nil)
        #expect(VoiceCapturePresentationBounds.modelDownloadProgress(.infinity) == nil)
        #expect(VoiceCapturePresentationBounds.modelDownloadProgress(-0.25) == 0)
        #expect(VoiceCapturePresentationBounds.modelDownloadProgress(0.5) == 0.5)
        #expect(VoiceCapturePresentationBounds.modelDownloadProgress(2.0) == 1)
        #expect(
            VoiceCapturePresentationBounds.statusMessage(" \n\(oversizedMessage)\n ")
                .count == VoiceCapturePresentationBounds.maxStatusMessageCharacters
        )
        #expect(VoiceCapturePresentationBounds.statusMessage(" \n\t ") == "Voice input failed.")
    }

    @Test("voice diagnostics redact path-leaking external errors")
    func voiceDiagnosticsRedactPathLeakingExternalErrors() {
        let privatePath = "/private/var/folders/voice/model.bundle"
        let error = NSError(
            domain: privatePath,
            code: 9,
            userInfo: [NSLocalizedDescriptionKey: "failed to open \(privatePath)"]
        )
        let detail = VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: "audio engine failed")
        let status = VoiceCaptureDiagnostics.externalStatusMessage("Voice input failed", error: error)

        #expect(detail.contains("audio engine failed"))
        #expect(status.contains("Voice input failed"))
        #expect(detail.contains("domain=Error"))
        #expect(status.contains("code=9"))
        #expect(detail.count <= VoiceCapturePresentationBounds.maxStatusMessageCharacters)
        #expect(status.count <= VoiceCapturePresentationBounds.maxStatusMessageCharacters)
        #expect(!detail.contains(privatePath))
        #expect(!status.contains(privatePath))
        #expect(!status.contains("failed to open"))
    }

    @Test("voice button gates shared transcript callbacks to the capture owner")
    func voiceButtonGatesSharedTranscriptCallbacksToCaptureOwner() throws {
        let button = try loadMirroredSourceTextFile("Epistemos/Views/Shared/VoiceInputButton.swift")

        #expect(button.contains("@State private var ownsCapture = false"))
        #expect(button.contains("guard ownsCapture, !newValue.isEmpty else { return }\n            onPartial(newValue)"))
        #expect(button.contains("guard ownsCapture, !newValue.isEmpty else { return }\n            if let transcript = service.consumeTranscript()"))
        #expect(button.contains("ownsCapture = true\n        phase = .requesting"))
        #expect(button.contains("if ownsCapture {\n            service.tearDown()"))
        #expect(button.contains("ownsCapture = false"))
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
            "maxManifestBytes",
            "manifestProblem(",
            "readManifestDataNoFollow",
            "artifactProblem(",
            "firstSymlinkComponent(",
            "destinationOfSymbolicLink",
            "open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)",
            "fstat(fd",
            "JSONSerialization.jsonObject",
            "FileAttributeType == .typeRegular",
            "FileAttributeType == .typeDirectory",
            "path must not include symlink component",
            "pathDiagnostic(",
            "maxPathDiagnosticLength",
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
        #expect(status.detail.contains(root.path) == false)
        #expect(status.detail.contains(modelDirectory.path) == false)
        #else
        #expect(true)
        #endif
    }

    @Test("Kokoro Pro gate ready detail does not expose the local model root")
    func kokoroProGateReadyDetailDoesNotExposeLocalModelRoot() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-gate-ready-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        let manifestURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName)
        let modelPackageURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.modelPackageName, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: modelPackageURL, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: manifestURL)

        let status = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(status.isReady)
        #expect(status.state == .ready)
        #expect(status.detail.contains(KokoroVoiceGateStatus.modelDirectoryName))
        #expect(status.detail.contains(root.path) == false)
        #expect(status.detail.contains(modelDirectory.path) == false)
        #expect(status.detail.count < 240)
        #else
        #expect(true)
        #endif
    }

    @Test("Kokoro Pro gate rejects invalid or oversized manifests")
    func kokoroProGateRejectsInvalidOrOversizedManifests() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-gate-manifest-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        let manifestURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName)
        let modelPackageURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.modelPackageName, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: modelPackageURL, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: manifestURL)

        let invalid = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!invalid.isReady)
        #expect(invalid.state == .missingModel)
        #expect(invalid.detail.contains("manifest.json is not a JSON object"))

        try Data(repeating: UInt8(ascii: "{"), count: KokoroVoiceGateStatus.maxManifestBytes + 1)
            .write(to: manifestURL)

        let oversized = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!oversized.isReady)
        #expect(oversized.state == .missingModel)
        #expect(oversized.detail.contains("manifest.json could not be read safely"))
        #else
        #expect(true)
        #endif
    }

    @Test("Kokoro Pro gate rejects symlink-routed artifacts")
    func kokoroProGateRejectsSymlinkRoutedArtifacts() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-gate-symlink-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        let outsideManifest = root.appendingPathComponent("outside-manifest.json", isDirectory: false)
        let outsidePackage = root.appendingPathComponent("outside-package", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: outsideManifest)
        try FileManager.default.createDirectory(at: outsidePackage, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName, isDirectory: false),
            withDestinationURL: outsideManifest
        )
        try FileManager.default.createSymbolicLink(
            at: modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.modelPackageName, isDirectory: true),
            withDestinationURL: outsidePackage
        )

        let status = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!status.isReady)
        #expect(status.state == .missingModel)
        #expect(status.detail.contains("manifest.json path must not include symlink component"))
        #expect(status.detail.contains("Kokoro82M.mlpackage path must not include symlink component"))
        #expect(status.detail.contains(root.path) == false)
        #expect(status.detail.contains(modelDirectory.path) == false)
        #expect(status.detail.contains(outsideManifest.path) == false)
        #expect(status.detail.contains(outsidePackage.path) == false)
        #else
        #expect(true)
        #endif
    }
}
