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
            "raw status/domain strings bounded before trimming or punctuation validation",
            "Kokoro-only TTS is honestly unavailable until the native engine is wired",
            "Legacy Apple voice code is unwired from the shipped TTS path",
            "Personal Voice authorization is live",
            "Pro Kokoro gate is honest",
            "Local Kokoro package install/removal is real but runtime-disabled",
            "manifest-derived package evidence",
            "bounded-before-trim model-relative diagnostics with ellipsis inside configured caps",
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
            "[DONE] Add a local checked-package installer/remover"
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
        #expect(capabilities.contains("Voice — STT SHIPPED; TTS KOKORO-ONLY GATED (Pass 8)"))
        #expect(capabilities.contains("Kokoro-only read-aloud availability"))
        #expect(capabilities.contains("domain/code-redacted status/error text"))
        #expect(capabilities.contains("raw status/domain strings bounded before trimming"))
        #expect(capabilities.contains("status ellipsis kept inside the configured cap"))
        #expect(capabilities.contains("Kokoro-82M is Pro-only"))
        #expect(capabilities.contains("rejects symlink-routed, non-regular, placeholder, oversized, invalid-manifest, or digest-mismatched"))
        #expect(capabilities.contains("declared package byte caps"))
        #expect(capabilities.contains("bounded-before-trim model-relative status diagnostics"))
        #expect(capabilities.contains("ellipsis inside configured caps"))
        #expect(capabilities.contains("Pro-only Voice settings status/runtime affordance"))
        #expect(capabilities.contains("no Apple AVSpeech fallback"))
        #expect(capabilities.contains("local checked-package installer/remover"))
        #expect(capabilities.contains("manifest-derived package evidence"))
        #expect(capabilities.contains("no committed model asset, network downloader, neural inference"))
        #expect(capabilities.contains("runtime, Python, subprocess, or MAS-visible Kokoro row"))

        for stale in [
            "Research/code in a later pass",
            "Kokoro-82M Pro voice + SSML",
            "Apple AVSpeech TTS wrapper",
            "AVSpeech selected until real neural inference is proven",
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
        #expect(readAloud.contains("guard isTextToSpeechAvailable else { return }"))
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

    @Test("Kokoro Pro gate is honest and does not add a runtime")
    func kokoroProGateIsHonestAndRuntimeFree() throws {
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
            "manifestFileName = \"manifest.json\"",
            "modelPackageName = \"Kokoro82M.mlpackage\"",
            "packageManifestFileName = \"Manifest.json\"",
            "manifestSchemaVersion = 1",
            "modelIdentifier = \"kokoro-82m\"",
            "runtimeIdentifier = \"coreml\"",
            "maxManifestBytes",
            "maxManifestFileCount",
            "maxPackageFileBytes",
            "maxPackageTotalBytes",
            "manifestProblem(",
            "manifestContractProblem(",
            "readManifestDataNoFollow",
            "artifactProblem(",
            "packageContentsProblem(",
            "fileDigestNoFollow",
            "regularFileSizeNoFollow",
            "totalManifestBytes",
            "files[\\(index)].bytes exceeds package file limit",
            "files[\\(index)].bytes must be a positive integer",
            "files total exceeds package size limit",
            "CFBooleanGetTypeID",
            "rounded(.towardZero)",
            "fileDigestNoFollow(at: fileURL, expectedBytes: file.bytes)",
            "SHA256()",
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
            "rawBoundedDiagnostic(value, maxCharacters: maxPathDiagnosticLength",
            "limit - 3",
            "resolvesInsideModelDirectory",
            "files must list",
            "size mismatch",
            "digest mismatch",
            "package file digests match",
            "Apple AVSpeech is not used as a fallback",
            "Runtime readiness, not merely model-package readiness",
            "var packageEvidence: PackageEvidence? = nil",
            "Kokoro voice: model package ready, runtime deferred"
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
        #expect(section.contains("selectedRuntime: .textToSpeechUnavailable"))
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
        #expect(gate.contains("manifest.files.reduce(UInt64(0))"))
        #expect(installer.contains("nonisolated enum KokoroVoicePackageInstaller"))
        #expect(installer.contains("installCheckedPackage("))
        #expect(installer.contains("removeInstalledPackage("))
        #expect(installer.contains("packagePathExists"))
        #expect(installer.contains("package could not be removed"))
        #expect(installer.contains("rejectSymlinkDescendants"))
        #expect(installer.contains("sourceModelDirectory("))
        #expect(installer.contains("KokoroVoiceGateStatus.status("))
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
            "packageEvidence.settingsSummary.contains(\"Kokoro synthesis remains unavailable\")",
            "KokoroVoicePackageInstaller.removeInstalledPackage",
            "removed.status.state == .missingModel",
            "!FileManager.default.fileExists(atPath: installedModelPath)",
            "KokoroVoicePackageInstaller.statusMessage(for: error)",
            "kokoro_installer=true"
        ] {
            #expect(smoke.contains(required), "voice live smoke missing Kokoro installer guard: \(required)")
        }
    }

    @Test("Kokoro Pro settings presentation falls back to Apple voice while gate is missing")
    func kokoroProSettingsPresentationFallsBackWhileMissing() {
        let missing = KokoroVoiceGateStatus.Status(
            state: .missingModel,
            isReady: false,
            headline: "Kokoro voice: model package missing",
            detail: "Expected kokoro-82m-coreml. Text-to-speech is unavailable; Apple AVSpeech is not used as a fallback."
        )
        let packageReady = KokoroVoiceGateStatus.Status(
            state: .packageReady,
            isReady: false,
            headline: "Kokoro voice: model package ready, runtime deferred",
            detail: "The checked Pro model package manifest and package file digests match in kokoro-82m-coreml, but native Kokoro synthesis is not wired yet. Text-to-speech is unavailable; Apple AVSpeech is not used as a fallback."
        )
        let packageReadyWithEvidence = KokoroVoiceGateStatus.Status(
            state: .packageReady,
            isReady: false,
            headline: "Kokoro voice: model package ready, runtime deferred",
            detail: "The checked Pro model package manifest and package file digests match in kokoro-82m-coreml, but native Kokoro synthesis is not wired yet. Text-to-speech is unavailable; Apple AVSpeech is not used as a fallback.",
            packageEvidence: KokoroVoiceGateStatus.PackageEvidence(
                modelDirectoryName: KokoroVoiceGateStatus.modelDirectoryName,
                manifestFileName: KokoroVoiceGateStatus.manifestFileName,
                modelPackageName: KokoroVoiceGateStatus.modelPackageName,
                runtimeIdentifier: KokoroVoiceGateStatus.runtimeIdentifier,
                manifestFileCount: 2,
                declaredPackageBytes: 42
            )
        )

        let missingPresentation = KokoroVoiceProSettingsModel.presentation(for: missing)
        #expect(missingPresentation.selectedRuntime == .textToSpeechUnavailable)
        #expect(!missingPresentation.proRuntimeEnabled)
        #expect(missingPresentation.badgeTitle == "Model required")

        let packageReadyPresentation = KokoroVoiceProSettingsModel.presentation(for: packageReady)
        #expect(packageReadyPresentation.selectedRuntime == .textToSpeechUnavailable)
        #expect(!packageReadyPresentation.proRuntimeEnabled)
        #expect(packageReadyPresentation.badgeTitle == "Package ready")
        #expect(packageReadyPresentation.detail.contains("native Kokoro synthesis is not wired yet"))

        let evidencePresentation = KokoroVoiceProSettingsModel.presentation(for: packageReadyWithEvidence)
        #expect(evidencePresentation.packageEvidenceSummary?.contains(KokoroVoiceGateStatus.modelPackageName) == true)
        #expect(evidencePresentation.packageEvidenceSummary?.contains("2 checked files") == true)
        #expect(evidencePresentation.packageEvidenceSummary?.contains("42 declared bytes") == true)
        #expect(evidencePresentation.packageEvidenceSummary?.contains("Kokoro synthesis remains unavailable") == true)
    }

    @Test("Kokoro package installer stages checked local package without enabling runtime")
    func kokoroPackageInstallerStagesCheckedLocalPackageWithoutEnablingRuntime() throws {
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

        #expect(!result.status.isReady)
        #expect(result.status.state == .packageReady)
        #expect(result.status.packageEvidence?.modelDirectoryName == KokoroVoiceGateStatus.modelDirectoryName)
        #expect(result.status.packageEvidence?.manifestFileName == KokoroVoiceGateStatus.manifestFileName)
        #expect(result.status.packageEvidence?.modelPackageName == KokoroVoiceGateStatus.modelPackageName)
        #expect(result.status.packageEvidence?.runtimeIdentifier == KokoroVoiceGateStatus.runtimeIdentifier)
        #expect(result.status.packageEvidence?.manifestFileCount == 2)
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

    @Test("Kokoro Pro gate package-ready detail does not expose the local model root or enable runtime")
    func kokoroProGatePackageReadyDetailDoesNotExposeLocalModelRootOrEnableRuntime() throws {
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

        #expect(!status.isReady)
        #expect(status.state == .packageReady)
        #expect(status.headline.contains("runtime deferred"))
        #expect(status.detail.contains(KokoroVoiceGateStatus.modelDirectoryName))
        #expect(status.detail.contains("package file digests match"))
        #expect(status.detail.contains("Apple AVSpeech is not used as a fallback"))
        #expect(status.packageEvidence?.manifestFileCount == 2)
        #expect((status.packageEvidence?.declaredPackageBytes ?? 0) > 0)
        #expect(status.packageEvidence?.settingsSummary.contains(KokoroVoiceGateStatus.modelPackageName) == true)
        #expect(status.packageEvidence?.settingsSummary.contains("declared bytes") == true)
        #expect(status.packageEvidence?.settingsSummary.contains(root.path) == false)
        #expect(status.packageEvidence?.settingsSummary.contains(modelDirectory.path) == false)
        #expect(status.detail.contains(root.path) == false)
        #expect(status.detail.contains(modelDirectory.path) == false)
        #expect(status.detail.count < 240)
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
        let modelPackageURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.modelPackageName, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: modelPackageURL, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: manifestURL)

        let placeholder = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!placeholder.isReady)
        #expect(placeholder.state == .missingModel)
        #expect(placeholder.detail.contains("manifest.json schemaVersion must be 1"))

        let packageManifest = Data(#"{"fileFormatVersion":"1.0.0"}"#.utf8)
        let payload = Data("fixture kokoro payload\n".utf8)
        try kokoroInstallManifestData(packageManifest: packageManifest, payload: payload).write(to: manifestURL)

        let emptyPackage = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!emptyPackage.isReady)
        #expect(emptyPackage.state == .missingModel)
        #expect(emptyPackage.detail.contains("missing Kokoro82M.mlpackage/Manifest.json"))
        #expect(emptyPackage.detail.contains(root.path) == false)
        #expect(emptyPackage.detail.contains(modelDirectory.path) == false)
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

        let oversizedPackageManifest: [String: Any] = [
            "schemaVersion": KokoroVoiceGateStatus.manifestSchemaVersion,
            "modelId": KokoroVoiceGateStatus.modelIdentifier,
            "runtime": KokoroVoiceGateStatus.runtimeIdentifier,
            "modelPackageName": KokoroVoiceGateStatus.modelPackageName,
            "files": [
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
            ],
        ]
        try JSONSerialization.data(withJSONObject: oversizedPackageManifest, options: [.sortedKeys])
            .write(to: manifestURL)

        let oversizedPackage = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!oversizedPackage.isReady)
        #expect(oversizedPackage.state == .missingModel)
        #expect(oversizedPackage.detail.contains("files[1].bytes exceeds package file limit"))

        let fractionalSchemaManifest: [String: Any] = [
            "schemaVersion": Double(KokoroVoiceGateStatus.manifestSchemaVersion) + 0.5,
            "modelId": KokoroVoiceGateStatus.modelIdentifier,
            "runtime": KokoroVoiceGateStatus.runtimeIdentifier,
            "modelPackageName": KokoroVoiceGateStatus.modelPackageName,
            "files": [
                [
                    "path": KokoroVoiceGateStatus.packageManifestFileName,
                    "bytes": 1,
                    "sha256": String(repeating: "a", count: 64),
                ],
                [
                    "path": "Data/com.apple.CoreML/model.mlmodel",
                    "bytes": 1,
                    "sha256": String(repeating: "b", count: 64),
                ],
            ],
        ]
        try JSONSerialization.data(withJSONObject: fractionalSchemaManifest, options: [.sortedKeys])
            .write(to: manifestURL)

        let fractionalSchema = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!fractionalSchema.isReady)
        #expect(fractionalSchema.state == .missingModel)
        #expect(fractionalSchema.detail.contains("manifest.json schemaVersion must be 1"))

        let fractionalBytesManifest: [String: Any] = [
            "schemaVersion": KokoroVoiceGateStatus.manifestSchemaVersion,
            "modelId": KokoroVoiceGateStatus.modelIdentifier,
            "runtime": KokoroVoiceGateStatus.runtimeIdentifier,
            "modelPackageName": KokoroVoiceGateStatus.modelPackageName,
            "files": [
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
            ],
        ]
        try JSONSerialization.data(withJSONObject: fractionalBytesManifest, options: [.sortedKeys])
            .write(to: manifestURL)

        let fractionalBytes = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )

        #expect(!fractionalBytes.isReady)
        #expect(fractionalBytes.state == .missingModel)
        #expect(fractionalBytes.detail.contains("files[0].bytes must be a positive integer"))
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

    private func writeValidKokoroPackage(at modelDirectory: URL) throws {
        let packageURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.modelPackageName, isDirectory: true)
        let packageManifestURL = packageURL.appendingPathComponent(
            KokoroVoiceGateStatus.packageManifestFileName,
            isDirectory: false
        )
        let payloadURL = packageURL
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("com.apple.CoreML", isDirectory: true)
            .appendingPathComponent("model.mlmodel", isDirectory: false)
        let packageManifest = Data(#"{"fileFormatVersion":"1.0.0"}"#.utf8)
        let payload = Data("fixture kokoro payload\n".utf8)

        try FileManager.default.createDirectory(
            at: payloadURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try packageManifest.write(to: packageManifestURL)
        try payload.write(to: payloadURL)
        try kokoroInstallManifestData(packageManifest: packageManifest, payload: payload)
            .write(to: modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName))
    }

    private func kokoroInstallManifestData(packageManifest: Data, payload: Data) throws -> Data {
        let payloadPath = "Data/com.apple.CoreML/model.mlmodel"
        let object: [String: Any] = [
            "schemaVersion": KokoroVoiceGateStatus.manifestSchemaVersion,
            "modelId": KokoroVoiceGateStatus.modelIdentifier,
            "runtime": KokoroVoiceGateStatus.runtimeIdentifier,
            "modelPackageName": KokoroVoiceGateStatus.modelPackageName,
            "files": [
                [
                    "path": KokoroVoiceGateStatus.packageManifestFileName,
                    "bytes": packageManifest.count,
                    "sha256": sha256Hex(packageManifest),
                ],
                [
                    "path": payloadPath,
                    "bytes": payload.count,
                    "sha256": sha256Hex(payload),
                ],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
