import CryptoKit
import Foundation

@main
enum VoiceLiveSmoke {
    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("voice live smoke failed: \(message)\n".utf8))
        exit(1)
    }

    static func main() async {
        let oversized = String(
            repeating: "v",
            count: LiveVoiceInputService.maxTranscriptCharacters + 11
        )
        guard LiveVoiceInputService.boundedTranscript(oversized).count == LiveVoiceInputService.maxTranscriptCharacters else {
            fail("transcript bound was not enforced")
        }
        guard LiveVoiceInputService.cleanedFinalTranscript(" \n\t ") == "" else {
            fail("empty final transcript was not cleaned")
        }
        guard VoiceCapturePresentationBounds.modelDownloadProgress(-1) == 0,
              VoiceCapturePresentationBounds.modelDownloadProgress(2) == 1,
              VoiceCapturePresentationBounds.modelDownloadProgress(.nan) == nil
        else {
            fail("model download progress was not bounded")
        }

        let privatePath = "/private/var/folders/voice/model.bundle"
        let error = NSError(
            domain: privatePath,
            code: 13,
            userInfo: [NSLocalizedDescriptionKey: "failed to open \(privatePath)"]
        )
        let diagnostic = VoiceCaptureDiagnostics.externalErrorDescription(error, fallback: "audio engine failed")
        guard diagnostic.contains("domain=Error"),
              diagnostic.contains("code=13"),
              !diagnostic.contains(privatePath),
              !diagnostic.contains("failed to open")
        else {
            fail("voice diagnostic leaked a private path: \(diagnostic)")
        }

        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-voice-smoke-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        let manifestURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName)
        let modelURL = modelDirectory.appendingPathComponent(KokoroVoiceGateStatus.modelPackageName, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let off = KokoroVoiceGateStatus.status(environment: [:], modelRoot: root)
        guard off.state == .unavailable, !off.isReady else {
            fail("Kokoro gate did not stay off without the Pro flag")
        }
        let offPresentation = KokoroVoiceProSettingsModel.presentation(for: off)
        guard offPresentation.selectedRuntime == .appleAVSpeech,
              !offPresentation.proRuntimeEnabled else {
            fail("Kokoro Pro presentation did not fall back while the Pro flag was off")
        }

        let missing = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )
        guard missing.state == .missingModel, !missing.isReady else {
            fail("Kokoro gate did not report missing model for an empty root")
        }
        let missingPresentation = KokoroVoiceProSettingsModel.presentation(for: missing)
        guard missingPresentation.selectedRuntime == .appleAVSpeech,
              !missingPresentation.proRuntimeEnabled,
              missingPresentation.badgeTitle == "Model required" else {
            fail("Kokoro Pro presentation did not fall back while the model was missing")
        }

        do {
            try FileManager.default.createDirectory(at: modelURL, withIntermediateDirectories: true)
            try Data("{}".utf8).write(to: manifestURL)
        } catch {
            fail("could not create temporary Kokoro placeholder shape: \(error)")
        }

        let placeholder = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )
        guard placeholder.state == .missingModel,
              !placeholder.isReady,
              placeholder.detail.contains("manifest.json schemaVersion must be 1") else {
            fail("Kokoro gate accepted a placeholder package shape: \(placeholder.detail)")
        }

        do {
            let packageManifest = Data(#"{"fileFormatVersion":"1.0.0"}"#.utf8)
            let payload = Data("fixture kokoro payload\n".utf8)
            let packageManifestURL = modelURL.appendingPathComponent(
                KokoroVoiceGateStatus.packageManifestFileName,
                isDirectory: false
            )
            let payloadURL = modelURL
                .appendingPathComponent("Data", isDirectory: true)
                .appendingPathComponent("com.apple.CoreML", isDirectory: true)
                .appendingPathComponent("model.mlmodel", isDirectory: false)
            try FileManager.default.createDirectory(
                at: payloadURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try packageManifest.write(to: packageManifestURL)
            try payload.write(to: payloadURL)
            try kokoroInstallManifestData(packageManifest: packageManifest, payload: payload)
                .write(to: manifestURL)
        } catch {
            fail("could not create temporary Kokoro model shape: \(error)")
        }

        let packageReady = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )
        guard packageReady.state == .packageReady, !packageReady.isReady else {
            fail("Kokoro gate did not keep the checked package distinct from runtime readiness: \(packageReady.detail)")
        }
        let packageReadyPresentation = KokoroVoiceProSettingsModel.presentation(for: packageReady)
        guard packageReadyPresentation.selectedRuntime == .appleAVSpeech,
              !packageReadyPresentation.proRuntimeEnabled,
              packageReadyPresentation.badgeTitle == "Package ready" else {
            fail("Kokoro Pro presentation did not keep AVSpeech selected while neural inference is deferred")
        }

        let installerTargetRoot = root.appendingPathComponent("InstallerTarget", isDirectory: true)
        do {
            let installed = try KokoroVoicePackageInstaller.installCheckedPackage(
                from: modelDirectory,
                modelRoot: installerTargetRoot
            )
            guard installed.status.state == .packageReady, !installed.status.isReady else {
                fail("Kokoro installer did not stage a checked package without enabling runtime: \(installed.status.detail)")
            }
            let removed = try KokoroVoicePackageInstaller.removeInstalledPackage(modelRoot: installerTargetRoot)
            guard removed.status.state == .missingModel, !removed.status.isReady else {
                fail("Kokoro installer removal did not return to missing-model gate status: \(removed.status.detail)")
            }
            let installedModelPath = installerTargetRoot
                .appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
                .path
            guard !FileManager.default.fileExists(atPath: installedModelPath) else {
                fail("Kokoro installer removal left the local model package behind")
            }
        } catch {
            fail("Kokoro installer install/remove smoke failed: \(KokoroVoicePackageInstaller.statusMessage(for: error))")
        }
        #endif

        if #available(macOS 26.0, *) {
            let readiness = await EpistemosSpeechAnalyzer.shared.readiness()
            print("voice live smoke OK: helper_bounds=true kokoro_gate=true kokoro_pro_settings=true kokoro_installer=true speech_readiness=\(readiness)")
        } else {
            print("voice live smoke OK: helper_bounds=true kokoro_gate=true kokoro_pro_settings=true kokoro_installer=true speech_readiness=macos_26_required")
        }
    }

    static func kokoroInstallManifestData(packageManifest: Data, payload: Data) throws -> Data {
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

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
