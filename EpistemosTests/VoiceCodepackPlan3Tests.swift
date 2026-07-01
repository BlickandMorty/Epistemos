import CryptoKit
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
            "Shared mic control uses native toolbar chrome",
            "Shared mic callbacks are capture-owner gated",
            "Live macOS 26 STT is surfaced",
            "bounded domain/code diagnostics",
            "raw status/domain strings bounded, control/whitespace-normalized, then punctuation-validated",
            "Kokoro-only TTS is live when a checked Pro CoreML package is installed",
            "Legacy Apple voice code is unwired from the shipped TTS path",
            "Personal Voice authorization is live",
            "Pro Kokoro gate is honest",
            "Native Kokoro Swift/CoreML playback is wired",
            "Local Kokoro package install/removal is real and playback-enabling",
            "manifest-derived package evidence",
            "bounded printable bundle profile",
            "bounded and control/whitespace-normalized model-relative diagnostics with ellipsis inside configured caps",
            "KokoroCoreMLRuntimeLoader",
            "KokoroCoreMLSynthesizer",
            "AVAudioEngine",
            "raw-vocabulary",
            "advances observable read-aloud progress",
            "preflight empty and over-cap text",
            "oversized text cannot flip the UI into speaking state",
            "LocalPackages/KokoroPipeline",
            "Voice settings section now shows",
            "TTS unavailable",
            "Kokoro neural voice",
            "Readiness rejects symlink-routed or non-regular model artifacts",
            "Pro Kokoro gate, settings presentation, and checked package install/removal",
            "failed replacement install rolls back to the previous package",
            "[DONE] Gate shipped TTS as Kokoro-only",
            "[DONE] Wire or remove `agentResponseTTS`",
            "[DONE] Add `LiveVoiceInputService`",
            "[DONE] Rewire `VoiceInputButton`",
            "[DONE] Add SSML/prosody fallback",
            "[DONE] Add Personal Voice authorization",
            "[DONE] Add the Kokoro Pro gate",
            "[DONE] Add the Pro-only Kokoro settings status/runtime affordance",
            "[DONE] Add a local checked-package installer/remover",
            "[DONE] Vendor native `KokoroPipeline` source"
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
        #expect(plan.contains("## Pro Kokoro lane `[NATIVE COREML PLAYBACK WIRED]`"))
        #expect(plan.contains("## Delivery order"))
        #expect(capabilities.contains("Voice — STT SHIPPED; TTS KOKORO-ONLY GATED (Pass 8)"))
        #expect(capabilities.contains("Kokoro-only read-aloud availability"))
        #expect(capabilities.contains("domain/code-redacted status/error text"))
        #expect(capabilities.contains("raw status/domain strings bounded and\n  control/whitespace-normalized"))
        #expect(capabilities.contains("status ellipsis kept inside the configured cap"))
        #expect(capabilities.contains("Kokoro-82M is Pro-only"))
        #expect(capabilities.contains("rejects symlink-routed, hardlinked, non-regular, placeholder, oversized, invalid-manifest, or digest-mismatched"))
        #expect(capabilities.contains("declared package byte caps"))
        #expect(capabilities.contains("bounded, control/whitespace-normalized model-relative\n  status diagnostics"))
        #expect(capabilities.contains("ellipsis inside configured caps"))
        #expect(capabilities.contains("Pro-only Voice settings status/runtime affordance"))
        #expect(capabilities.contains("no Apple AVSpeech fallback"))
        #expect(capabilities.contains("local checked-package installer/remover"))
        #expect(capabilities.contains("manifest-derived package evidence"))
        #expect(capabilities.contains("bounded printable\n  bundle profile"))
        #expect(capabilities.contains("observable read-aloud progress"))
        #expect(capabilities.contains("Swift/CoreML `KokoroPipeline` path tokenizes supported raw vocabulary text"))
        #expect(capabilities.contains("requires the complete manifest-declared duration/bucket CoreML package"))
        #expect(capabilities.contains("no Apple AVSpeech fallback, committed model asset, network downloader, Python, subprocess"))
        #expect(capabilities.contains("Python, subprocess, or MAS-visible Kokoro row"))

        for stale in [
            "Research/code in a later pass",
            "Kokoro-82M Pro voice + SSML",
            "Apple AVSpeech TTS wrapper",
            "AVSpeech selected until real neural inference is proven",
            "without enabling the neural runtime",
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
            "Apple Speech remains the native STT lane",
            "Kokoro is the only shipped TTS lane",
            "do not ship AVSpeech/basic system voice as read-aloud/TTS fallback",
            "Do not add Python/subprocess inference on the MAS path"
        ] {
            #expect(plan.contains(required), "Missing voice boundary: \(required)")
        }
    }

    @Test("voice button routes through the live SpeechAnalyzer facade")
    func voiceButtonRoutesThroughLiveSpeechAnalyzerFacade() throws {
        let button = try loadMirroredSourceTextFile("Epistemos/Views/Shared/VoiceInputButton.swift")
        let readAloud = try loadMirroredSourceTextFile("Epistemos/Views/Shared/ReadAloudButton.swift")
        let facade = try loadMirroredSourceTextFile("Epistemos/Engine/LiveVoiceInputService.swift")
        let analyzer = try loadMirroredSourceTextFile("Epistemos/Engine/EpistemosSpeechAnalyzer.swift")

        #expect(button.contains("LiveVoiceInputService.shared"))
        #expect(button.contains("@Environment(UIState.self)"))
        #expect(button.contains("ToolbarCapsuleButton("))
        #expect(button.contains("NativeControlRole"))
        #expect(button.contains("NativeControlChromePolicy"))
        #expect(button.contains("ui.theme.resolved.accent.color"))
        #expect(button.contains(".onChange(of: service.partialTranscript)"))
        #expect(button.contains(".onChange(of: service.finalTranscript)"))
        #expect(!button.contains("ComposerVoiceInputService.shared"))
        #expect(!button.contains("service.latestTranscript"))
        #expect(!button.contains(".buttonStyle(.borderless)"))
        #expect(!button.contains("Color.accentColor"))
        #expect(!button.contains("Color.primary"))
        #expect(!button.contains("system accent color"))
        #expect(readAloud.contains("@Environment(UIState.self)"))
        #expect(readAloud.contains("ToolbarCapsuleButton("))
        #expect(readAloud.contains("NativeControlChromePolicy"))
        #expect(readAloud.contains("EpistemosSpeechSynthesizer.isTextToSpeechAvailable()"))
        #expect(readAloud.contains("EpistemosSpeechSynthesizer.textToSpeechStatusMessage()"))
        #expect(readAloud.contains("EpistemosSpeechSynthesizer.isTextToSpeechInputSupported(text)"))
        #expect(readAloud.contains("EpistemosSpeechSynthesizer.textToSpeechStatusMessage(for: text)"))
        #expect(readAloud.contains("guard isTextToSpeechAvailable else { return }"))
        #expect(readAloud.contains("guard isTextToSpeechAvailable, isTextToSpeechInputSupported else { return }"))
        #expect(readAloud.contains("ui.theme.resolved.accent.color"))
        #expect(readAloud.contains("ui.theme.resolved.foreground.color.opacity"))
        #expect(!readAloud.contains(".buttonStyle(.borderless)"))
        #expect(!readAloud.contains("Color.accentColor"))
        #expect(!readAloud.contains("Color.secondary.opacity"))

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
        #expect(facade.contains("rawBoundedDiagnostic(message, maxCharacters: maxStatusMessageCharacters"))
        #expect(facade.contains("normalizedDisplayText(clipped)"))
        #expect(facade.contains("CharacterSet.controlCharacters"))
        #expect(facade.contains("String(domain.prefix(maxDomainCharacters))"))
        #expect(facade.contains("limit - 3"))
        #expect(facade.contains("VoiceCaptureDiagnostics.externalStatusMessage"))
        #expect(!facade.contains("String(describing: error)"))
        #expect(analyzer.contains("VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: \"asset inventory check failed\")"))
        #expect(analyzer.contains("VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: \"transcriber results failed\")"))
        #expect(analyzer.contains("VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: \"speech analysis failed\")"))
        #expect(analyzer.contains("VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: \"model download failed\")"))
        #expect(analyzer.contains("VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: \"audio engine failed\")"))
        #expect(!analyzer.contains("error.localizedDescription"))
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
        #expect(VoiceCapturePresentationBounds.modelDownloadProgress(Double.infinity) == nil)
        #expect(VoiceCapturePresentationBounds.modelDownloadProgress(-0.25) == 0)
        #expect(VoiceCapturePresentationBounds.modelDownloadProgress(0.5) == 0.5)
        #expect(VoiceCapturePresentationBounds.modelDownloadProgress(2.0) == 1)
        let boundedStatus = VoiceCapturePresentationBounds.statusMessage(" \n\(oversizedMessage)\n ")
        #expect(boundedStatus.count <= VoiceCapturePresentationBounds.maxStatusMessageCharacters)
        #expect(boundedStatus.hasSuffix("..."))
        #expect(VoiceCapturePresentationBounds.statusMessage(" \n\t ") == "Voice input failed.")
        #expect(VoiceCapturePresentationBounds.statusMessage("Voice\ninput\tready\u{0007}") == "Voice input ready")
        #expect(VoiceCaptureDiagnostics.safeDomain("NS\nCocoa\tError") == "Error")
    }

    @Test("Kokoro TTS input helpers reject empty and oversized text before playback")
    func kokoroTTSInputHelpersRejectEmptyAndOversizedTextBeforePlayback() throws {
        let synth = try loadMirroredSourceTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")
        let oversized = String(
            repeating: "a",
            count: EpistemosSpeechSynthesizer.maxTextToSpeechInputCharacters + 1
        )

        #expect(EpistemosSpeechSynthesizer.isTextToSpeechInputSupported(" short text "))
        #expect(!EpistemosSpeechSynthesizer.isTextToSpeechInputSupported(" \n\t "))
        #expect(!EpistemosSpeechSynthesizer.isTextToSpeechInputSupported(oversized))
        #expect(synth.contains("maxTextToSpeechInputCharacters = KokoroCoreMLSynthesizer.maxInputCharacters"))
        #expect(synth.contains("guard cleaned.count <= Self.maxTextToSpeechInputCharacters else"))
        #expect(synth.contains("text exceeds Kokoro input cap"))

        let lengthGuard = try #require(synth.range(of: "guard cleaned.count <= Self.maxTextToSpeechInputCharacters else")?.lowerBound)
        let stopPlayback = try #require(synth.range(of: "if synthesizer.isSpeaking || synthesizer.isPaused")?.lowerBound)
        #expect(lengthGuard < stopPlayback)
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

    @Test("voice settings surface uses native controls and theme tint")
    func voiceSettingsSurfaceUsesNativeControlsAndThemeTint() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/VoicePreferencesSection.swift")
        let preferences = try loadMirroredSourceTextFile("Epistemos/Engine/VoicePreferences.swift")

        #expect(settings.contains("@Environment(UIState.self)"))
        #expect(settings.contains("ToolbarCapsuleButton("))
        #expect(settings.contains("role: .disclosure"))
        #expect(settings.contains("role: .toolbarUtility"))
        #expect(settings.contains("private var rationaleBackground: Color"))
        #expect(settings.contains("ui.theme.resolved.mutedForeground.color"))
        #expect(settings.contains("ui.theme.resolved.foreground.color.opacity"))
        #expect(settings.contains(".environment(UIState())"))
        #expect(!settings.contains(".foregroundStyle(.secondary)"))
        #expect(!settings.contains(".buttonStyle(.borderless)"))
        #expect(!settings.contains("Color.secondary.opacity"))
        #expect(preferences.contains("shipped TTS is Kokoro-only"))
        #expect(preferences.contains("Apple AVSpeech is not used as a fallback"))
        #expect(!preferences.contains("Apple " + "system voice"))
        #expect(!preferences.contains("system " + "default voice"))
    }

    @Test("model voice picker exposes Personal Voice access on native theme chrome")
    func modelVoicePickerExposesPersonalVoiceAccessOnNativeThemeChrome() throws {
        let picker = try loadMirroredSourceTextFile("Epistemos/Views/Shared/ModelVoicePickerSection.swift")
        let synth = try loadMirroredSourceTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")

        #expect(synth.contains("PersonalVoiceAuthorization"))
        #expect(synth.contains("AVSpeechSynthesizer.personalVoiceAuthorizationStatus"))
        #expect(synth.contains("AVSpeechSynthesizer.requestPersonalVoiceAuthorization"))
        #expect(synth.contains("withCheckedContinuation"))
        #expect(synth.contains("if #available(macOS 14.0, *)"))
        #expect(synth.contains("Shipped text-to-speech remains Kokoro-only"))
        #expect(synth.contains("AVSpeech is not used as a fallback"))
        #expect(!synth.contains("highest-" + "quality TTS"))
        #expect(!synth.contains("For higher quality" + ", install"))
        #expect(!synth.contains("download an Enhanced" + " or Premium voice"))
        #expect(picker.contains("@Environment(UIState.self)"))
        #expect(picker.contains("personalVoiceAccessView"))
        #expect(picker.contains("personalVoiceAuthorization = EpistemosSpeechSynthesizer.personalVoiceAuthorization()"))
        #expect(picker.contains("await EpistemosSpeechSynthesizer.requestPersonalVoiceAuthorization()"))
        #expect(picker.contains("refreshVoicesAndHints()"))
        #expect(picker.contains("ToolbarCapsuleButton("))
        #expect(picker.contains("ui.theme.resolved.headingAccent.color"))
        #expect(picker.contains("ui.theme.resolved.mutedForeground.color"))
        #expect(!picker.contains(".buttonStyle(.bordered)"))
        #expect(!picker.contains(".buttonStyle(.link)"))
        #expect(!picker.contains(".foregroundStyle(.secondary)"))
        #expect(!picker.contains("return .green"))
        #expect(!picker.contains("return .yellow"))
        #expect(!picker.contains("return .secondary"))
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
            for forbidden in ["Whisper", "Process(", "NSTask", "Python", "Chromium"] {
                #expect(!source.contains(forbidden), "\(file) crossed voice MAS boundary: \(forbidden)")
            }
        }
    }

    @Test("Kokoro Pro gate is honest and status-only")
    func kokoroProGateIsHonestAndStatusOnly() throws {
        let gate = try loadMirroredSourceTextFile("Epistemos/VoicePro/KokoroVoiceGateStatus.swift")

        for required in [
            "nonisolated enum KokoroVoiceGateStatus",
            "EPISTEMOS_KOKORO_VOICE_PRO_V0",
            "case unavailable",
            "case missingModel",
            "case packageReady",
            "#if EPISTEMOS_APP_STORE || MAS_SANDBOX",
            "Kokoro voice: unavailable in App Store build",
            "modelDirectoryName = \"kokoro-82m-coreml\"",
            "manifestFileName = \"KokoroRuntimeManifest.json\"",
            "hostedManifestFileName = \"HostedManifest.json\"",
            "upstreamRepositoryID = \"mattmireles/kokoro-coreml\"",
            "coreMLDirectoryPrefix = \"coreml/\"",
            "packageManifestFileName = \"Manifest.json\"",
            "manifestSchemaVersion = 1",
            "modelIdentifier = \"kokoro-82m\"",
            "runtimeIdentifier = \"coreml\"",
            "coreMLDataPathPrefix = \"Data/com.apple.CoreML/\"",
            "runtimeVocabPath = \"runtime/kokoro-vocab.json\"",
            "runtimeHNSFWeightsPath = \"runtime/hnsf_weights.json\"",
            "starterVoicePath = \"voices/af_heart.bin\"",
            "sampleRateHz = 24_000",
            "starterVoiceEmbeddingDimensions = 256",
            "maxManifestBytes",
            "maxManifestFileCount",
            "maxPackageFileBytes",
            "maxPackageTotalBytes",
            "maxManifestMetadataCharacters",
            "manifestMetadataString(",
            "bundle_profile is invalid",
            "runtimeManifestProblem(",
            "runtimeManifest(from:",
            "duration_token_sizes",
            "model_packages",
            "runtime_assets",
            "voices must include",
            "readManifestDataNoFollow",
            "artifactProblem(",
            "runtimeBundleContentsProblem(",
            "bundleCoverageProblem(",
            "declaredBundleFiles(from:",
            "modelPackageFamilyProblem(",
            "f0FrameCountsByBucket",
            "fileDigestNoFollow",
            "regularFileSizeNoFollow",
            "totalManifestBytes",
            "bytes exceeds package size limit",
            "bytes must be a positive integer",
            "files must include \\(packageManifestFileName) and Core ML data",
            "model_packages must include duration Core ML packages for token sizes",
            "model_packages must include f0ntrain, decoder_pre, and decoder_har_post Core ML packages for buckets",
            "profile \\(bundleProfile)",
            "CFBooleanGetTypeID",
            "rounded(.towardZero)",
            "fileDigestNoFollow(at: fileURL, expectedBytes: declaredFile.bytes)",
            "SHA256()",
            "firstSymlinkComponent(",
            "destinationOfSymbolicLink",
            "open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)",
            "fstat(fd",
            "st_nlink <= 1",
            "JSONSerialization.jsonObject",
            "FileAttributeType == .typeRegular",
            "FileAttributeType == .typeDirectory",
            "path must not include symlink component",
            "character >= \"A\" && character <= \"F\"",
            "pathDiagnostic(",
            "maxPathDiagnosticLength",
            "rawBoundedDiagnostic(value, maxCharacters: maxPathDiagnosticLength",
            "VoiceCapturePresentationBounds.normalizedDisplayText(clipped)",
            "limit - 3",
            "resolvesInsideModelDirectory",
            "supported_languages must include en-US",
            "minimum_platforms.macOS must be at least 15.0",
            "size mismatch",
            "digest mismatch",
            "runtime manifest, segmented CoreML packages, runtime assets, and starter voice digests match",
            "Apple AVSpeech is not used as a fallback",
            "Runtime readiness, not merely model-package readiness",
            "var packageEvidence: PackageEvidence? = nil",
            "Kokoro voice: native CoreML playback ready",
            "Kokoro voice: CoreML runtime package ready, runtime not linked"
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

    @Test("Kokoro native runtime loader feeds playback bridge")
    func kokoroNativeRuntimeLoaderFeedsPlaybackBridge() throws {
        let loader = try loadMirroredSourceTextFile("Epistemos/VoicePro/KokoroCoreMLRuntimeLoader.swift")
        let bridge = try loadMirroredSourceTextFile("Epistemos/VoicePro/KokoroCoreMLSynthesizer.swift")
        let synthesizer = try loadMirroredSourceTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")
        let project = try loadMirroredSourceTextFile("project.yml")
        let upstream = try loadMirroredSourceTextFile("LocalPackages/KokoroPipeline/UPSTREAM.md")

        for required in [
            "nonisolated enum KokoroCoreMLRuntimeLoader",
            "#if canImport(KokoroPipeline)",
            "import KokoroPipeline",
            "KokoroPipeline(",
            "loadPipeline(resources: RuntimeResources)",
            "runtimeResourceShapeProblem(",
            "readRuntimeManifestShape(at:",
            "readHNSFWeights(at:",
            "readVocabulary(at:",
            "\"vocab\"",
            "linear_weights",
            "linear_bias",
            "validateStarterVoice(at:",
            "voice embedding must be a positive multiple of 256 Float32 values",
            "VoiceCapturePresentationBounds.normalizedDisplayText(clipped)",
            "starterVoiceEmbedding",
            "starterVoiceEmbeddingDimensions",
            "runtime starter voice is invalid",
            "open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)",
            "fstat(fd",
            "st_nlink <= 1",
            "CFBooleanGetTypeID",
            "runtimeNotLinked",
            "KokoroCoreMLRuntimeLoader.isLinked",
            "static func renderRawText(",
            "rawVocabularyChunks(",
            "replacementSymbols(for:",
            "return Array(\" percent \").map(String.init)",
            "return Array(\" slash \").map(String.init)",
            "attentionMask",
            "KokoroCoreMLSynthesizer.renderRawText",
            "PcmJoiner.join",
            "AVAudioEngine",
            "AVAudioPlayerNode",
            "scheduleBuffer",
            "kokoroProgressTask",
            "startKokoroProgressUpdates(",
            "updateKokoroPlaybackProgress(",
            "playerTime(forNodeTime:",
            "charactersSpoken: spoken"
        ] {
            let source: String
            if [
                "static func renderRawText(",
                "rawVocabularyChunks(",
                "replacementSymbols(for:",
                "return Array(\" percent \").map(String.init)",
                "return Array(\" slash \").map(String.init)",
                "attentionMask",
                "PcmJoiner.join"
            ].contains(required) {
                source = bridge
            } else if [
                "KokoroCoreMLRuntimeLoader.isLinked",
                "KokoroCoreMLSynthesizer.renderRawText",
                "AVAudioEngine",
                "AVAudioPlayerNode",
                "scheduleBuffer",
                "kokoroProgressTask",
                "startKokoroProgressUpdates(",
                "updateKokoroPlaybackProgress(",
                "playerTime(forNodeTime:",
                "charactersSpoken: spoken"
            ].contains(required) {
                source = synthesizer
            } else {
                source = loader
            }
            #expect(source.contains(required), "Kokoro runtime loader missing source guard: \(required)")
        }

        #expect(project.contains("KokoroPipeline:\n    path: LocalPackages/KokoroPipeline"))
        #expect(project.contains("- package: KokoroPipeline\n        product: KokoroPipeline"))
        #expect(upstream.contains("052bdcd8333d4ac38d77485a5067d9a1e3397cac"))
        #expect(upstream.contains("no model weights"))
        #expect(synthesizer.contains("private func stopKokoroPlayback()"))
        #expect(synthesizer.contains("if kokoroEngine.isRunning {\n            kokoroEngine.pause()\n        }"))
        #expect(!loader.contains("URLSession"))
        #expect(!loader.contains("Process("))
        #expect(!loader.contains("NSTask"))
        #expect(!loader.contains("Python"))
        #expect(!bridge.contains("URLSession"))
        #expect(!bridge.contains("Process("))
        #expect(!bridge.contains("NSTask"))
        #expect(!bridge.contains("Python"))
    }

    @Test("Kokoro Pro settings row is Pro-only and gate-backed")
    func kokoroProSettingsRowIsProOnlyAndGateBacked() throws {
        let wrapper = try loadMirroredSourceTextFile("Epistemos/Views/Settings/VoiceSettingsDetailView.swift")
        let section = try loadMirroredSourceTextFile("Epistemos/VoicePro/KokoroVoiceProSettingsSection.swift")
        let installer = try loadMirroredSourceTextFile("Epistemos/VoicePro/KokoroVoicePackageInstaller.swift")
        let gate = try loadMirroredSourceTextFile("Epistemos/VoicePro/KokoroVoiceGateStatus.swift")
        let appleSection = try loadMirroredSourceTextFile("Epistemos/Views/Settings/VoicePreferencesSection.swift")

        #expect(wrapper.contains("VoicePreferencesSection()"))
        #expect(wrapper.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(wrapper.contains("KokoroVoiceProSettingsSection()"))
        #expect(!appleSection.contains("Kokoro"))

        #expect(section.contains("KokoroVoiceGateStatus.status()"))
        #expect(section.contains("case kokoroNeural"))
        #expect(section.contains("case .packageReady"))
        #expect(section.contains("return \"Kokoro neural voice\""))
        #expect(section.contains("return \"TTS unavailable\""))
        #expect(section.contains("selectedRuntime: status.isReady ? .kokoroNeural : .textToSpeechUnavailable"))
        #expect(section.contains("proRuntimeEnabled: status.isReady"))
        #expect(section.contains("badgeTitle: status.isReady ? \"Ready\" : \"Package ready\""))
        #expect(section.contains("detail: status.detail"))
        #expect(section.contains(".disabled(!presentation.proRuntimeEnabled)"))
        #expect(section.contains("@Environment(UIState.self)"))
        #expect(section.contains("ToolbarCapsuleButton("))
        #expect(section.contains("theme.resolved.headingAccent.color"))
        #expect(section.contains("Install Package"))
        #expect(section.contains("Remove Package"))
        #expect(section.contains("NSOpenPanel()"))
        #expect(section.contains("systemImage: \"trash\""))
        #expect(section.contains("isBusy"))
        #expect(section.contains("startAccessingSecurityScopedResource()"))
        #expect(section.contains("KokoroVoicePackageInstaller.installCheckedPackage"))
        #expect(section.contains("KokoroVoicePackageInstaller.removeInstalledPackage"))
        #expect(section.contains("packageEvidenceSummary"))
        #expect(section.contains("installedPackageMessage(for:"))
        #expect(section.contains("evidence.settingsSummary"))
        #expect(gate.contains("struct PackageEvidence"))
        #expect(gate.contains("manifestFileCount"))
        #expect(gate.contains("declaredPackageBytes"))
        #expect(gate.contains("modelPackageCount"))
        #expect(gate.contains("voiceCount"))
        #expect(gate.contains("runtimeAssetCount"))
        #expect(gate.contains("declaredFiles.reduce(UInt64(0))"))
        #expect(installer.contains("nonisolated enum KokoroVoicePackageInstaller"))
        #expect(installer.contains("installCheckedPackage("))
        #expect(installer.contains("removeInstalledPackage("))
        #expect(installer.contains("packagePathExists"))
        #expect(installer.contains("package could not be removed"))
        #expect(installer.contains("rejectSymlinkDescendants"))
        #expect(installer.contains("sourceModelDirectory("))
        #expect(installer.contains("KokoroVoiceGateStatus.status("))
        #expect(installer.contains("VoiceCapturePresentationBounds.normalizedDisplayText(clipped)"))
        #expect(installer.contains("package could not be finalized"))
        #expect(installer.contains("rollbackFailedFinalization("))
        #expect(installer.contains("try? fileManager.removeItem(at: finalModelDirectory)"))
        #expect(installer.contains("try? fileManager.moveItem(at: backupModelDirectory, to: finalModelDirectory)"))
        #expect(installer.contains("rejectSymlinkedInstallRoute(modelRoot"))
        #expect(installer.contains("install path must not include symlink component"))
        #expect(installer.contains("firstExistingSymlinkComponent"))
        #expect(installer.contains("isMacOSCompatibilitySymlink"))
        #expect(installer.contains("VoiceCapturePresentationBounds.statusMessage"))
        #expect(installer.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX"))
        #expect(!section.contains("Color.green"))
        #expect(!section.contains("Color.orange"))
        #expect(!section.contains(".buttonStyle(.borderless)"))
        #expect(!section.contains("Process("))
        #expect(!section.contains("NSTask"))
        #expect(!section.contains("Python"))
        #expect(!installer.contains("URLSession"))
        #expect(!installer.contains("Process("))
        #expect(!installer.contains("NSTask"))
        #expect(!installer.contains("Python"))
    }

    @Test("voice live smoke exercises Kokoro checked package install removal")
    func voiceLiveSmokeExercisesKokoroCheckedPackageInstallRemoval() throws {
        let smoke = try loadMirroredSourceTextFile("scripts/voice-live-smoke.swift")

        for required in [
            "#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)",
            "InstallerTarget",
            "KokoroVoicePackageInstaller.installCheckedPackage",
            "from: modelDirectory",
            "modelRoot: installerTargetRoot",
            "installed.status.state == .packageReady",
            "packageReady.packageEvidence",
            "installed.status.packageEvidence",
            "installed.status.isReady",
            "packageEvidence.settingsSummary.contains(\"Kokoro playback uses this native bundle\")",
            "KokoroVoicePackageInstaller.removeInstalledPackage",
            "removed.status.state == .missingModel",
            "!FileManager.default.fileExists(atPath: installedModelPath)",
            "KokoroVoicePackageInstaller.statusMessage(for: error)",
            "kokoro_installer=true"
        ] {
            #expect(smoke.contains(required), "voice live smoke missing Kokoro installer guard: \(required)")
        }
    }

    @Test("Kokoro Pro settings presentation enables native playback only when ready")
    func kokoroProSettingsPresentationEnablesNativePlaybackOnlyWhenReady() {
        let missing = KokoroVoiceGateStatus.Status(
            state: .missingModel,
            isReady: false,
            headline: "Kokoro voice: model package missing",
            detail: "Expected kokoro-82m-coreml. Text-to-speech is unavailable; Apple AVSpeech is not used as a fallback."
        )
        let packageReady = KokoroVoiceGateStatus.Status(
            state: .packageReady,
            isReady: true,
            headline: "Kokoro voice: native CoreML playback ready",
            detail: "The checked Pro mattmireles/kokoro-coreml runtime manifest, segmented CoreML packages, runtime assets, and starter voice digests match in kokoro-82m-coreml. Native Swift/CoreML Kokoro playback is available; Apple AVSpeech is not used as a fallback."
        )
        let packageReadyWithEvidence = KokoroVoiceGateStatus.Status(
            state: .packageReady,
            isReady: true,
            headline: "Kokoro voice: native CoreML playback ready",
            detail: "The checked Pro mattmireles/kokoro-coreml runtime manifest, segmented CoreML packages, runtime assets, and starter voice digests match in kokoro-82m-coreml. Native Swift/CoreML Kokoro playback is available; Apple AVSpeech is not used as a fallback.",
            packageEvidence: KokoroVoiceGateStatus.PackageEvidence(
                modelDirectoryName: KokoroVoiceGateStatus.modelDirectoryName,
                manifestFileName: KokoroVoiceGateStatus.manifestFileName,
                runtimeIdentifier: KokoroVoiceGateStatus.runtimeIdentifier,
                hfRepositoryID: KokoroVoiceGateStatus.upstreamRepositoryID,
                bundleProfile: "test",
                modelPackageCount: 10,
                voiceCount: 1,
                runtimeAssetCount: 2,
                manifestFileCount: 23,
                declaredPackageBytes: 42
            )
        )

        let missingPresentation = KokoroVoiceProSettingsModel.presentation(for: missing)
        #expect(missingPresentation.selectedRuntime == .textToSpeechUnavailable)
        #expect(!missingPresentation.proRuntimeEnabled)
        #expect(missingPresentation.badgeTitle == "Model required")

        let packageReadyPresentation = KokoroVoiceProSettingsModel.presentation(for: packageReady)
        #expect(packageReadyPresentation.selectedRuntime == .kokoroNeural)
        #expect(packageReadyPresentation.proRuntimeEnabled)
        #expect(packageReadyPresentation.badgeTitle == "Ready")
        #expect(packageReadyPresentation.detail.contains("Native Swift/CoreML Kokoro playback is available"))

        let evidencePresentation = KokoroVoiceProSettingsModel.presentation(for: packageReadyWithEvidence)
        #expect(evidencePresentation.packageEvidenceSummary?.contains(KokoroVoiceGateStatus.manifestFileName) == true)
        #expect(evidencePresentation.packageEvidenceSummary?.contains("10 checked Core ML packages") == true)
        #expect(evidencePresentation.packageEvidenceSummary?.contains("1 voice") == true)
        #expect(evidencePresentation.packageEvidenceSummary?.contains("23 checked files") == true)
        #expect(evidencePresentation.packageEvidenceSummary?.contains("42 declared bytes") == true)
        #expect(evidencePresentation.packageEvidenceSummary?.contains("profile test") == true)
        #expect(evidencePresentation.packageEvidenceSummary?.contains("Kokoro playback uses this native bundle") == true)
    }

    @Test("Kokoro package installer stages checked local package and enables native runtime")
    func kokoroPackageInstallerStagesCheckedLocalPackageAndEnablesNativeRuntime() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-install-\(UUID().uuidString)", isDirectory: true)
        let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
        let targetRoot = root.appendingPathComponent("target", isDirectory: true)
        let sourceModelDirectory = sourceRoot.appendingPathComponent(
            KokoroVoiceGateStatus.modelDirectoryName,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try writeValidKokoroPackage(at: sourceModelDirectory)

        let result = try KokoroVoicePackageInstaller.installCheckedPackage(
            from: sourceModelDirectory,
            modelRoot: targetRoot
        )

        #expect(result.status.isReady)
        #expect(result.status.state == .packageReady)
        #expect(result.status.packageEvidence?.modelDirectoryName == KokoroVoiceGateStatus.modelDirectoryName)
        #expect(result.status.packageEvidence?.manifestFileName == KokoroVoiceGateStatus.manifestFileName)
        #expect(result.status.packageEvidence?.runtimeIdentifier == KokoroVoiceGateStatus.runtimeIdentifier)
        #expect(result.status.packageEvidence?.hfRepositoryID == KokoroVoiceGateStatus.upstreamRepositoryID)
        #expect(result.status.packageEvidence?.modelPackageCount == 10)
        #expect(result.status.packageEvidence?.voiceCount == 1)
        #expect(result.status.packageEvidence?.runtimeAssetCount == 2)
        #expect(result.status.packageEvidence?.manifestFileCount == 23)
        #expect((result.status.packageEvidence?.declaredPackageBytes ?? 0) > 0)
        #expect(FileManager.default.fileExists(
            atPath: targetRoot
                .appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
                .appendingPathComponent(KokoroVoiceGateStatus.manifestFileName, isDirectory: false)
                .path
        ))

        let removed = try KokoroVoicePackageInstaller.removeInstalledPackage(modelRoot: targetRoot)

        #expect(!removed.status.isReady)
        #expect(removed.status.state == .missingModel)
        #expect(!FileManager.default.fileExists(
            atPath: targetRoot
                .appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
                .path
        ))
        #else
        #expect(true)
        #endif
    }

    @Test("Kokoro package installer rejects symlinked install roots")
    func kokoroPackageInstallerRejectsSymlinkedInstallRoots() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("kokoro-install-route-\(UUID().uuidString)", isDirectory: true)
        let outside = root.appendingPathComponent("outside", isDirectory: true)
        let linkedRoot = root.appendingPathComponent("linked-root", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: linkedRoot, withDestinationURL: outside)

        do {
            _ = try KokoroVoicePackageInstaller.removeInstalledPackage(modelRoot: linkedRoot)
            Issue.record("Expected symlinked Kokoro install root to be rejected")
        } catch let error as KokoroVoicePackageInstaller.InstallError {
            #expect(error.errorDescription?.contains("install path must not include symlink component linked-root") == true)
            #expect(error.errorDescription?.contains(outside.path) == false)
        }

        #expect(!fm.fileExists(
            atPath: outside
                .appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
                .path
        ))
        #else
        #expect(true)
        #endif
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

        let status = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!status.isReady)
        #expect(status.state == .missingModel)
        #expect(status.detail.contains("KokoroRuntimeManifest.json is a directory"))
        #expect(status.detail.contains(root.path) == false)
        #expect(status.detail.contains(modelDirectory.path) == false)
        #else
        #expect(true)
        #endif
    }

    @Test("Kokoro Pro gate package-ready detail does not expose the local model root and enables runtime")
    func kokoroProGatePackageReadyDetailDoesNotExposeLocalModelRootAndEnablesRuntime() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-gate-ready-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeValidKokoroPackage(at: modelDirectory)

        let status = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(status.isReady)
        #expect(status.state == .packageReady)
        #expect(status.headline.contains("native CoreML playback ready"))
        #expect(status.detail.contains(KokoroVoiceGateStatus.modelDirectoryName))
        #expect(status.detail.contains("segmented CoreML packages"))
        #expect(status.detail.contains("Native Swift/CoreML Kokoro playback is available"))
        #expect(status.detail.contains(KokoroVoiceGateStatus.upstreamRepositoryID))
        #expect(status.detail.contains("Apple AVSpeech is not used as a fallback"))
        #expect(status.packageEvidence?.modelPackageCount == 10)
        #expect(status.packageEvidence?.voiceCount == 1)
        #expect(status.packageEvidence?.runtimeAssetCount == 2)
        #expect(status.packageEvidence?.manifestFileCount == 23)
        #expect((status.packageEvidence?.declaredPackageBytes ?? 0) > 0)
        #expect(status.packageEvidence?.bundleProfile == "test")
        #expect(status.packageEvidence?.settingsSummary.contains(KokoroVoiceGateStatus.manifestFileName) == true)
        #expect(status.packageEvidence?.settingsSummary.contains("10 checked Core ML packages") == true)
        #expect(status.packageEvidence?.settingsSummary.contains("declared bytes") == true)
        #expect(status.packageEvidence?.settingsSummary.contains("profile test") == true)
        #expect(status.packageEvidence?.settingsSummary.contains(root.path) == false)
        #expect(status.packageEvidence?.settingsSummary.contains(modelDirectory.path) == false)
        #expect(status.detail.contains(root.path) == false)
        #expect(status.detail.contains(modelDirectory.path) == false)
        #expect(status.detail.count < 280)
        #else
        #expect(true)
        #endif
    }

    @Test("Kokoro Pro gate rejects unmanifested package files")
    func kokoroProGateRejectsUnmanifestedPackageFiles() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-gate-extra-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        let packageURL = modelDirectory
            .appendingPathComponent("coreml", isDirectory: true)
            .appendingPathComponent("kokoro_duration_t32.mlpackage", isDirectory: true)
        let extraFileURL = packageURL
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("com.apple.CoreML", isDirectory: true)
            .appendingPathComponent("extra.mlmodel", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeValidKokoroPackage(at: modelDirectory)
        try Data("unmanifested payload\n".utf8).write(to: extraFileURL)

        let status = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!status.isReady)
        #expect(status.state == .missingModel)
        #expect(status.detail.contains("coreml/kokoro_duration_t32.mlpackage/Data/com.apple.CoreML/extra.mlmodel is not listed in KokoroRuntimeManifest.json"))
        #expect(status.detail.contains(root.path) == false)
        #expect(status.detail.contains(modelDirectory.path) == false)
        #else
        #expect(true)
        #endif
    }

    @Test("Kokoro Pro gate rejects non-CoreML package payloads")
    func kokoroProGateRejectsNonCoreMLPackagePayloads() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-gate-non-coreml-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        let manifestURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName)
        let packageURL = modelDirectory
            .appendingPathComponent("coreml", isDirectory: true)
            .appendingPathComponent("kokoro_duration_t32.mlpackage", isDirectory: true)
        let packageManifestURL = packageURL.appendingPathComponent(KokoroVoiceGateStatus.packageManifestFileName)
        let payloadURL = packageURL.appendingPathComponent("payload.bin")
        defer { try? FileManager.default.removeItem(at: root) }

        let packageManifest = Data(#"{"fileFormatVersion":"1.0.0"}"#.utf8)
        let payload = Data("not a CoreML package payload\n".utf8)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try packageManifest.write(to: packageManifestURL)
        try payload.write(to: payloadURL)

        try kokoroRuntimeManifestData(
            packageOverrides: [
                kokoroModelPackageObject(
                    path: "coreml/kokoro_duration_t32.mlpackage",
                    files: [
                        kokoroFileObject(path: KokoroVoiceGateStatus.packageManifestFileName, data: packageManifest),
                        kokoroFileObject(path: "payload.bin", data: payload),
                    ]
                )
            ]
        )
            .write(to: manifestURL)

        let status = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!status.isReady)
        #expect(status.state == .missingModel)
        #expect(status.detail.contains("model_packages[0].files[1].path is invalid"))
        #expect(status.detail.contains(root.path) == false)
        #expect(status.detail.contains(modelDirectory.path) == false)
        #else
        #expect(true)
        #endif
    }

    @Test("Kokoro Pro gate rejects control characters in package manifest paths")
    func kokoroProGateRejectsControlCharactersInPackageManifestPaths() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-gate-control-path-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        let manifestURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName)
        let packageURL = modelDirectory
            .appendingPathComponent("coreml", isDirectory: true)
            .appendingPathComponent("kokoro_duration_t32.mlpackage", isDirectory: true)
        let packageManifestURL = packageURL.appendingPathComponent(KokoroVoiceGateStatus.packageManifestFileName)
        let payloadURL = packageURL
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("com.apple.CoreML", isDirectory: true)
            .appendingPathComponent("model\nname.mlmodel", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let packageManifest = Data(#"{"fileFormatVersion":"1.0.0"}"#.utf8)
        let payload = Data("fixture kokoro payload\n".utf8)
        try FileManager.default.createDirectory(
            at: payloadURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try packageManifest.write(to: packageManifestURL)
        try payload.write(to: payloadURL)

        try kokoroRuntimeManifestData(
            packageOverrides: [
                kokoroModelPackageObject(
                    path: "coreml/kokoro_duration_t32.mlpackage",
                    files: [
                        kokoroFileObject(path: KokoroVoiceGateStatus.packageManifestFileName, data: packageManifest),
                        kokoroFileObject(path: "Data/com.apple.CoreML/model\nname.mlmodel", data: payload),
                    ]
                )
            ]
        )
            .write(to: manifestURL)

        let status = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!status.isReady)
        #expect(status.state == .missingModel)
        #expect(status.detail.contains("model_packages[0].files[1].path is invalid"))
        #expect(status.detail.contains(root.path) == false)
        #expect(status.detail.contains(modelDirectory.path) == false)
        #else
        #expect(true)
        #endif
    }

    @Test("Kokoro Pro gate rejects placeholder manifests and empty packages")
    func kokoroProGateRejectsPlaceholderManifestsAndEmptyPackages() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-gate-placeholder-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        let manifestURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: manifestURL)

        let placeholder = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!placeholder.isReady)
        #expect(placeholder.state == .missingModel)
        #expect(placeholder.detail.contains("KokoroRuntimeManifest.json schema_version must be 1"))

        try kokoroRuntimeManifestData().write(to: manifestURL)

        let emptyPackage = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!emptyPackage.isReady)
        #expect(emptyPackage.state == .missingModel)
        #expect(emptyPackage.detail.contains("missing coreml/kokoro_duration_t32.mlpackage"))
        #expect(emptyPackage.detail.contains(root.path) == false)
        #expect(emptyPackage.detail.contains(modelDirectory.path) == false)
        #else
        #expect(true)
        #endif
    }

    @Test("Kokoro Pro gate accepts uppercase SHA-256 manifest digests")
    func kokoroProGateAcceptsUppercaseSHA256ManifestDigests() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-gate-uppercase-digest-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        let manifestURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeValidKokoroPackage(at: modelDirectory)

        var manifest = try kokoroRuntimeManifestObject()
        var voices = try #require(manifest["voices"] as? [[String: Any]])
        var starterVoice = try #require(voices.first)
        let digest = try #require(starterVoice["sha256"] as? String)
        starterVoice["sha256"] = digest.uppercased()
        voices[0] = starterVoice
        manifest["voices"] = voices
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: manifestURL)

        let status = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(status.isReady)
        #expect(status.state == .packageReady)
        #expect(status.detail.contains("digest mismatch") == false)
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
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: manifestURL)

        let invalid = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!invalid.isReady)
        #expect(invalid.state == .missingModel)
        #expect(invalid.detail.contains("KokoroRuntimeManifest.json is not a JSON object"))

        try Data(repeating: UInt8(ascii: "{"), count: KokoroVoiceGateStatus.maxManifestBytes + 1)
            .write(to: manifestURL)

        let oversized = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!oversized.isReady)
        #expect(oversized.state == .missingModel)
        #expect(oversized.detail.contains("KokoroRuntimeManifest.json could not be read safely"))

        try kokoroRuntimeManifestData(
            packageOverrides: [
                kokoroModelPackageObject(
                    path: "coreml/kokoro_duration_t32.mlpackage",
                    files: [
                        [
                            "path": KokoroVoiceGateStatus.packageManifestFileName,
                            "bytes": 1,
                            "sha256": String(repeating: "a", count: 64),
                        ],
                        [
                            "path": "Data/com.apple.CoreML/oversized.mlmodel",
                            "bytes": Int(KokoroVoiceGateStatus.maxPackageFileBytes + 1),
                            "sha256": String(repeating: "b", count: 64),
                        ],
                    ]
                )
            ]
        )
            .write(to: manifestURL)

        let oversizedPackage = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!oversizedPackage.isReady)
        #expect(oversizedPackage.state == .missingModel)
        #expect(oversizedPackage.detail.contains("model_packages[0].files[1].bytes exceeds package size limit"))

        var fractionalSchemaManifest = try kokoroRuntimeManifestObject()
        fractionalSchemaManifest["schema_version"] = Double(KokoroVoiceGateStatus.manifestSchemaVersion) + 0.5
        try JSONSerialization.data(withJSONObject: fractionalSchemaManifest, options: [.sortedKeys])
            .write(to: manifestURL)

        let fractionalSchema = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!fractionalSchema.isReady)
        #expect(fractionalSchema.state == .missingModel)
        #expect(fractionalSchema.detail.contains("KokoroRuntimeManifest.json schema_version must be 1"))

        try kokoroRuntimeManifestData(
            packageOverrides: [
                kokoroModelPackageObject(
                    path: "coreml/kokoro_duration_t32.mlpackage",
                    files: [
                        [
                            "path": KokoroVoiceGateStatus.packageManifestFileName,
                            "bytes": 1.5,
                            "sha256": String(repeating: "a", count: 64),
                        ],
                        [
                            "path": "Data/com.apple.CoreML/model.mlmodel",
                            "bytes": 1,
                            "sha256": String(repeating: "b", count: 64),
                        ],
                    ]
                )
            ]
        )
            .write(to: manifestURL)

        let fractionalBytes = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!fractionalBytes.isReady)
        #expect(fractionalBytes.state == .missingModel)
        #expect(fractionalBytes.detail.contains("model_packages[0].files[0].bytes must be a positive integer"))

        var oversizedProfileManifest = try kokoroRuntimeManifestObject()
        oversizedProfileManifest["bundle_profile"] = String(repeating: "x", count: 97)
        try JSONSerialization.data(withJSONObject: oversizedProfileManifest, options: [.sortedKeys])
            .write(to: manifestURL)

        let oversizedProfile = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!oversizedProfile.isReady)
        #expect(oversizedProfile.state == .missingModel)
        #expect(oversizedProfile.detail.contains("KokoroRuntimeManifest.json bundle_profile is invalid"))

        var pathLikeProfileManifest = try kokoroRuntimeManifestObject()
        pathLikeProfileManifest["bundle_profile"] = "test/profile"
        try JSONSerialization.data(withJSONObject: pathLikeProfileManifest, options: [.sortedKeys])
            .write(to: manifestURL)

        let pathLikeProfile = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!pathLikeProfile.isReady)
        #expect(pathLikeProfile.state == .missingModel)
        #expect(pathLikeProfile.detail.contains("KokoroRuntimeManifest.json bundle_profile is invalid"))
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
        let status = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!status.isReady)
        #expect(status.state == .missingModel)
        #expect(status.detail.contains("KokoroRuntimeManifest.json path must not include symlink component"))
        #expect(status.detail.contains(root.path) == false)
        #expect(status.detail.contains(modelDirectory.path) == false)
        #expect(status.detail.contains(outsideManifest.path) == false)
        #expect(status.detail.contains(outsidePackage.path) == false)

        try FileManager.default.removeItem(at: modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName))
        try kokoroRuntimeManifestData().write(
            to: modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName)
        )
        try FileManager.default.createDirectory(
            at: modelDirectory.appendingPathComponent("coreml", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: modelDirectory
                .appendingPathComponent("coreml", isDirectory: true)
                .appendingPathComponent("kokoro_duration_t32.mlpackage", isDirectory: true),
            withDestinationURL: outsidePackage
        )

        let packageSymlink = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )
        #expect(!packageSymlink.isReady)
        #expect(packageSymlink.detail.contains("coreml/kokoro_duration_t32.mlpackage path must not include symlink component"))
        #expect(packageSymlink.detail.contains(outsidePackage.path) == false)
        #else
        #expect(true)
        #endif
    }

    @Test("Kokoro Pro gate rejects hardlinked artifacts")
    func kokoroProGateRejectsHardlinkedArtifacts() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-gate-hardlink-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        let manifestURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName, isDirectory: false)
        let manifestAlias = root.appendingPathComponent("manifest-alias.json", isDirectory: false)
        let voiceURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.starterVoicePath, isDirectory: false)
        let voiceAlias = root.appendingPathComponent("voice-alias.bin", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeValidKokoroPackage(at: modelDirectory)
        var exercisedHardlink = false

        if (try? FileManager.default.linkItem(at: manifestURL, to: manifestAlias)) != nil {
            exercisedHardlink = true
            let manifestStatus = KokoroVoiceGateStatus.status(
                environment: [KokoroVoiceGateStatus.flagName: "1"],
                modelRoot: root
            )

            #expect(!manifestStatus.isReady)
            #expect(manifestStatus.state == .missingModel)
            #expect(manifestStatus.detail.contains("KokoroRuntimeManifest.json could not be read safely"))
            #expect(manifestStatus.detail.contains(root.path) == false)
            #expect(manifestStatus.detail.contains(modelDirectory.path) == false)
            try FileManager.default.removeItem(at: manifestAlias)
        }

        if (try? FileManager.default.linkItem(at: voiceURL, to: voiceAlias)) != nil {
            exercisedHardlink = true
            let voiceStatus = KokoroVoiceGateStatus.status(
                environment: [KokoroVoiceGateStatus.flagName: "1"],
                modelRoot: root
            )

            #expect(!voiceStatus.isReady)
            #expect(voiceStatus.state == .missingModel)
            #expect(voiceStatus.detail.contains("voices/af_heart.bin could not be read safely"))
            #expect(voiceStatus.detail.contains(root.path) == false)
            #expect(voiceStatus.detail.contains(modelDirectory.path) == false)
        }

        guard exercisedHardlink else {
            return
        }
        #else
        #expect(true)
        #endif
    }

    @Test("Kokoro Pro gate rejects runtime assets that cannot feed native playback")
    func kokoroProGateRejectsRuntimeAssetsThatCannotFeedNativePlayback() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-gate-runtime-shape-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        let voiceURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.starterVoicePath, isDirectory: false)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeValidKokoroPackage(at: modelDirectory)

        let oversizedVoice = kokoroStarterVoiceFixtureData(
            dimensions: KokoroVoiceGateStatus.starterVoiceEmbeddingDimensions + 1
        )
        try oversizedVoice.write(to: voiceURL)

        var manifest = try kokoroRuntimeManifestObject()
        manifest["voices"] = [
            kokoroFileObject(path: KokoroVoiceGateStatus.starterVoicePath, data: oversizedVoice),
        ]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName))

        let status = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!status.isReady)
        #expect(status.state == .missingModel)
        #expect(status.detail.contains("runtime starter voice is invalid"))
        #expect(status.detail.contains("voice embedding must be a positive multiple of 256 Float32 values"))
        #expect(status.detail.contains(root.path) == false)
        #expect(status.detail.contains(modelDirectory.path) == false)
        #else
        #expect(true)
        #endif
    }

    private func writeValidKokoroPackage(at modelDirectory: URL) throws {
        var packageObjects = [[String: Any]]()
        for packagePath in kokoroFixturePackagePaths() {
            let packageURL = modelDirectory.appendingPathComponent(packagePath, isDirectory: true)
            let packageManifestURL = packageURL.appendingPathComponent(
                KokoroVoiceGateStatus.packageManifestFileName,
                isDirectory: false
            )
            let payloadURL = packageURL
                .appendingPathComponent("Data", isDirectory: true)
                .appendingPathComponent("com.apple.CoreML", isDirectory: true)
                .appendingPathComponent("model.mlmodel", isDirectory: false)
            let packageManifest = Data(#"{"fileFormatVersion":"1.0.0"}"#.utf8)
            let payload = Data("fixture \(packagePath)\n".utf8)

            try FileManager.default.createDirectory(
                at: payloadURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try packageManifest.write(to: packageManifestURL)
            try payload.write(to: payloadURL)
            packageObjects.append(kokoroModelPackageObject(
                path: packagePath,
                files: [
                    kokoroFileObject(path: KokoroVoiceGateStatus.packageManifestFileName, data: packageManifest),
                    kokoroFileObject(path: "Data/com.apple.CoreML/model.mlmodel", data: payload),
                ]
            ))
        }

        let runtimeVocab = kokoroRuntimeVocabFixtureData()
        let hnsfWeights = kokoroHNSFWeightsFixtureData()
        let voice = kokoroStarterVoiceFixtureData()
        try writeFixtureFile(runtimeVocab, relativePath: KokoroVoiceGateStatus.runtimeVocabPath, root: modelDirectory)
        try writeFixtureFile(hnsfWeights, relativePath: KokoroVoiceGateStatus.runtimeHNSFWeightsPath, root: modelDirectory)
        try writeFixtureFile(voice, relativePath: KokoroVoiceGateStatus.starterVoicePath, root: modelDirectory)
        try kokoroRuntimeManifestData(packageOverrides: packageObjects)
            .write(to: modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName))
    }

    private func kokoroRuntimeManifestData(packageOverrides: [[String: Any]]? = nil) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: kokoroRuntimeManifestObject(packageOverrides: packageOverrides),
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private func kokoroRuntimeManifestObject(packageOverrides: [[String: Any]]? = nil) throws -> [String: Any] {
        let runtimeVocab = kokoroRuntimeVocabFixtureData()
        let hnsfWeights = kokoroHNSFWeightsFixtureData()
        let voice = kokoroStarterVoiceFixtureData()
        let object: [String: Any] = [
            "schema_version": KokoroVoiceGateStatus.manifestSchemaVersion,
            "hf_repo_id": KokoroVoiceGateStatus.upstreamRepositoryID,
            "bundle_profile": "test",
            "minimum_platforms": [
                "macOS": "15.0",
                "iOS": "18.0",
            ],
            "supported_languages": ["en-US"],
            "buckets": [15],
            "duration_token_sizes": [32, 64, 128, 256, 320, 384, 512],
            "model_packages": packageOverrides ?? kokoroFixturePackagePaths().map { packagePath in
                let packageManifest = Data(#"{"fileFormatVersion":"1.0.0"}"#.utf8)
                let payload = Data("fixture \(packagePath)\n".utf8)
                return kokoroModelPackageObject(
                    path: packagePath,
                    files: [
                        kokoroFileObject(path: KokoroVoiceGateStatus.packageManifestFileName, data: packageManifest),
                        kokoroFileObject(path: "Data/com.apple.CoreML/model.mlmodel", data: payload),
                    ]
                )
            },
            "voices": [
                kokoroFileObject(path: KokoroVoiceGateStatus.starterVoicePath, data: voice),
            ],
            "runtime_assets": [
                "vocab": kokoroFileObject(path: KokoroVoiceGateStatus.runtimeVocabPath, data: runtimeVocab),
                "hnsf_weights": kokoroFileObject(path: KokoroVoiceGateStatus.runtimeHNSFWeightsPath, data: hnsfWeights),
            ],
        ]
        return object
    }

    private func kokoroFixturePackagePaths() -> [String] {
        [
            "coreml/kokoro_duration_t32.mlpackage",
            "coreml/kokoro_duration_t64.mlpackage",
            "coreml/kokoro_duration_t128.mlpackage",
            "coreml/kokoro_duration_t256.mlpackage",
            "coreml/kokoro_duration_t320.mlpackage",
            "coreml/kokoro_duration_t384.mlpackage",
            "coreml/kokoro_duration_t512.mlpackage",
            "coreml/kokoro_f0ntrain_t600.mlpackage",
            "coreml/kokoro_decoder_pre_15s.mlpackage",
            "coreml/kokoro_decoder_har_post_15s.mlpackage",
        ]
    }

    private func kokoroModelPackageObject(path: String, files: [[String: Any]]) -> [String: Any] {
        let bytes = files.compactMap { $0["bytes"] as? Int }.reduce(0, +)
        return [
            "path": path,
            "file_count": files.count,
            "bytes": bytes,
            "files": files,
        ]
    }

    private func kokoroFileObject(path: String, data: Data) -> [String: Any] {
        [
            "path": path,
            "bytes": data.count,
            "sha256": sha256Hex(data),
        ]
    }

    private func kokoroRuntimeVocabFixtureData() -> Data {
        Data(#"{"vocab":{"h":1,"e":2,"l":3,"o":4,"w":5,"r":6,"d":7," ":16}}"#.utf8)
    }

    private func kokoroHNSFWeightsFixtureData() -> Data {
        Data(#"{"linear_weights":[1,0,0,0,1,0,0,0,1],"linear_bias":0}"#.utf8)
    }

    private func kokoroStarterVoiceFixtureData(
        dimensions: Int = KokoroVoiceGateStatus.starterVoiceEmbeddingDimensions
    ) -> Data {
        let values = [Float](
            repeating: 0.125,
            count: dimensions
        )
        return values.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return Data() }
            return Data(bytes: UnsafeRawPointer(baseAddress), count: buffer.count * MemoryLayout<Float>.stride)
        }
    }

    private func writeFixtureFile(_ data: Data, relativePath: String, root: URL) throws {
        let url = root.appendingPathComponent(relativePath, isDirectory: false)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
