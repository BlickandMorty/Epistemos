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
        defer { try? FileManager.default.removeItem(at: root) }

        let off = KokoroVoiceGateStatus.status(environment: [:], modelRoot: root)
        guard off.state == .unavailable, !off.isReady else {
            fail("Kokoro gate did not stay off without the Pro flag")
        }
        let offPresentation = KokoroVoiceProSettingsModel.presentation(for: off)
        guard offPresentation.selectedRuntime == .textToSpeechUnavailable,
              !offPresentation.proRuntimeEnabled else {
            fail("Kokoro Pro presentation did not keep TTS unavailable while the Pro flag was off")
        }

        let missing = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )
        guard missing.state == .missingModel, !missing.isReady else {
            fail("Kokoro gate did not report missing model for an empty root")
        }
        let missingPresentation = KokoroVoiceProSettingsModel.presentation(for: missing)
        guard missingPresentation.selectedRuntime == .textToSpeechUnavailable,
              !missingPresentation.proRuntimeEnabled,
              missingPresentation.badgeTitle == "Model required" else {
            fail("Kokoro Pro presentation did not keep TTS unavailable while the model was missing")
        }

        do {
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
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
              placeholder.detail.contains("KokoroRuntimeManifest.json schema_version must be 1") else {
            fail("Kokoro gate accepted a placeholder package shape: \(placeholder.detail)")
        }

        do {
            try writeValidKokoroPackage(at: modelDirectory)
        } catch {
            fail("could not create temporary Kokoro model shape: \(error)")
        }

        let packageReady = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: root
        )
        guard packageReady.state == .packageReady, packageReady.isReady else {
            fail("Kokoro gate did not mark the checked package ready for native playback: \(packageReady.detail)")
        }
        guard let packageEvidence = packageReady.packageEvidence,
              packageEvidence.manifestFileCount == 23,
              packageEvidence.modelPackageCount == 10,
              packageEvidence.voiceCount == 1,
              packageEvidence.runtimeAssetCount == 2,
              packageEvidence.runtimeIdentifier == KokoroVoiceGateStatus.runtimeIdentifier,
              packageEvidence.settingsSummary.contains("Kokoro playback uses this native bundle") else {
            fail("Kokoro gate did not expose checked package evidence for native playback")
        }
        let packageReadyPresentation = KokoroVoiceProSettingsModel.presentation(for: packageReady)
        guard packageReadyPresentation.selectedRuntime == .kokoroNeural,
              packageReadyPresentation.proRuntimeEnabled,
              packageReadyPresentation.badgeTitle == "Ready",
              packageReadyPresentation.packageEvidenceSummary?.contains(KokoroVoiceGateStatus.manifestFileName) == true else {
            fail("Kokoro Pro presentation did not enable Kokoro neural voice for a checked package")
        }

        let installerTargetRoot = root.appendingPathComponent("InstallerTarget", isDirectory: true)
        do {
            let installed = try KokoroVoicePackageInstaller.installCheckedPackage(
                from: modelDirectory,
                modelRoot: installerTargetRoot
            )
            guard installed.status.state == .packageReady, installed.status.isReady else {
                fail("Kokoro installer did not enable native playback for a checked package: \(installed.status.detail)")
            }
            guard installed.status.packageEvidence?.manifestFileCount == 23,
                  installed.status.packageEvidence?.settingsSummary.contains("declared bytes") == true else {
                fail("Kokoro installer did not return checked package evidence")
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

    static func writeValidKokoroPackage(at modelDirectory: URL) throws {
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

    static func kokoroRuntimeManifestData(packageOverrides: [[String: Any]]) throws -> Data {
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
            "model_packages": packageOverrides,
            "voices": [
                kokoroFileObject(path: KokoroVoiceGateStatus.starterVoicePath, data: voice),
            ],
            "runtime_assets": [
                "vocab": kokoroFileObject(path: KokoroVoiceGateStatus.runtimeVocabPath, data: runtimeVocab),
                "hnsf_weights": kokoroFileObject(path: KokoroVoiceGateStatus.runtimeHNSFWeightsPath, data: hnsfWeights),
            ],
        ]
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    static func kokoroFixturePackagePaths() -> [String] {
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

    static func kokoroModelPackageObject(path: String, files: [[String: Any]]) -> [String: Any] {
        let bytes = files.compactMap { $0["bytes"] as? Int }.reduce(0, +)
        return [
            "path": path,
            "file_count": files.count,
            "bytes": bytes,
            "files": files,
        ]
    }

    static func kokoroFileObject(path: String, data: Data) -> [String: Any] {
        [
            "path": path,
            "bytes": data.count,
            "sha256": sha256Hex(data),
        ]
    }

    static func kokoroRuntimeVocabFixtureData() -> Data {
        Data(#"{"vocab":{"h":1,"e":2,"l":3,"o":4,"w":5,"r":6,"d":7," ":16}}"#.utf8)
    }

    static func kokoroHNSFWeightsFixtureData() -> Data {
        Data(#"{"linear_weights":[1,0,0,0,1,0,0,0,1],"linear_bias":0}"#.utf8)
    }

    static func kokoroStarterVoiceFixtureData() -> Data {
        let values = [Float](
            repeating: 0.125,
            count: KokoroVoiceGateStatus.starterVoiceEmbeddingDimensions
        )
        return values.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return Data() }
            return Data(bytes: UnsafeRawPointer(baseAddress), count: buffer.count * MemoryLayout<Float>.stride)
        }
    }

    static func writeFixtureFile(_ data: Data, relativePath: String, root: URL) throws {
        let url = root.appendingPathComponent(relativePath, isDirectory: false)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
