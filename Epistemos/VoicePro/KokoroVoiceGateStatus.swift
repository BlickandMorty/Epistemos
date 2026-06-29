import Foundation

nonisolated enum KokoroVoiceGateStatus {
    static let flagName = "EPISTEMOS_KOKORO_VOICE_PRO_V0"
    static let modelDirectoryName = "kokoro-82m-coreml"
    static let manifestFileName = "manifest.json"
    static let modelPackageName = "Kokoro82M.mlpackage"

    enum State: String, Equatable, Sendable {
        case unavailable
        case missingModel
        case ready
    }

    struct Status: Equatable, Sendable {
        let state: State
        let isReady: Bool
        let headline: String
        let detail: String
    }

    static func isEnabled(_ raw: String?) -> Bool {
        FeatureGateOverride.isTruthy(raw)
    }

    static func defaultModelRoot(fileManager: FileManager = .default) -> URL? {
        fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("VoicePro", isDirectory: true)
    }

    static func status(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        modelRoot: URL? = defaultModelRoot(),
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> Status {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return Status(
            state: .unavailable,
            isReady: false,
            headline: "Kokoro voice: unavailable in App Store build",
            detail: "The App Store build uses Apple AVSpeech voices only. Kokoro is a Pro-only neural voice lane and no model runtime is launched."
        )
        #else
        guard isEnabled(environment[flagName]) else {
            return Status(
                state: .unavailable,
                isReady: false,
                headline: "Kokoro voice: off",
                detail: "Set \(flagName)=1 in a Pro build after installing the checked model package. Off means AVSpeech remains the voice runtime."
            )
        }

        guard let modelRoot else {
            return Status(
                state: .missingModel,
                isReady: false,
                headline: "Kokoro voice: model location unavailable",
                detail: "Application Support could not be resolved. AVSpeech remains the voice runtime."
            )
        }

        let modelDirectory = modelRoot.appendingPathComponent(modelDirectoryName, isDirectory: true)
        let manifestURL = modelDirectory.appendingPathComponent(manifestFileName, isDirectory: false)
        let modelPackageURL = modelDirectory.appendingPathComponent(modelPackageName, isDirectory: true)
        let missing = [
            fileExists(manifestURL) ? nil : manifestFileName,
            fileExists(modelPackageURL) ? nil : modelPackageName,
        ].compactMap { $0 }

        guard missing.isEmpty else {
            return Status(
                state: .missingModel,
                isReady: false,
                headline: "Kokoro voice: model package missing",
                detail: "Expected \(modelDirectory.path) with \(missing.joined(separator: ", ")). AVSpeech remains the voice runtime."
            )
        }

        return Status(
            state: .ready,
            isReady: true,
            headline: "Kokoro voice: model package ready",
            detail: "The checked Pro model package is present at \(modelDirectory.path). Picker/runtime integration must still choose this lane explicitly."
        )
        #endif
    }
}
