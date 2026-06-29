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
        fileManager: FileManager = .default
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
        let problems = [
            artifactProblem(
                name: manifestFileName,
                url: manifestURL,
                kind: .file,
                rootURL: modelDirectory,
                fileManager: fileManager
            ),
            artifactProblem(
                name: modelPackageName,
                url: modelPackageURL,
                kind: .directory,
                rootURL: modelDirectory,
                fileManager: fileManager
            ),
        ].compactMap { $0 }

        guard problems.isEmpty else {
            return Status(
                state: .missingModel,
                isReady: false,
                headline: "Kokoro voice: model package missing",
                detail: "Expected \(modelDirectory.path), but \(problems.joined(separator: ", ")). AVSpeech remains the voice runtime."
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

    private enum ArtifactKind {
        case file
        case directory
    }

    private static func artifactProblem(
        name: String,
        url: URL,
        kind: ArtifactKind,
        rootURL: URL,
        fileManager: FileManager
    ) -> String? {
        if let component = firstSymlinkComponent(in: url, fileManager: fileManager) {
            return "\(name) path must not include symlink component at \(component.path)"
        }
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return "missing \(name)"
        }
        guard resolvesInsideModelDirectory(url, relativeTo: rootURL) else {
            return "\(name) resolves outside \(modelDirectoryName)"
        }
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.attributesOfItem(atPath: url.path)
        } catch {
            return "\(name) attributes unavailable"
        }
        switch kind {
        case .file:
            guard !isDirectory.boolValue else {
                return "\(name) is a directory"
            }
            return attributes[.type] as? FileAttributeType == .typeRegular
                ? nil
                : "\(name) is not a regular file"
        case .directory:
            guard isDirectory.boolValue else {
                return "\(name) is not a directory"
            }
            return attributes[.type] as? FileAttributeType == .typeDirectory
                ? nil
                : "\(name) is not a real directory"
        }
    }

    private static func firstSymlinkComponent(
        in url: URL,
        fileManager: FileManager
    ) -> URL? {
        var cursor = URL(fileURLWithPath: "/", isDirectory: true)
        for component in URL(fileURLWithPath: url.path).standardizedFileURL.pathComponents.dropFirst() {
            cursor = cursor.appendingPathComponent(component)
            guard !isMacOSCompatibilitySymlink(cursor) else {
                continue
            }
            if (try? fileManager.destinationOfSymbolicLink(atPath: cursor.path)) != nil {
                return cursor
            }
        }
        return nil
    }

    private static func isMacOSCompatibilitySymlink(_ url: URL) -> Bool {
        switch url.path {
        case "/etc", "/tmp", "/var":
            return true
        default:
            return false
        }
    }

    private static func resolvesInsideModelDirectory(_ url: URL, relativeTo rootURL: URL) -> Bool {
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        return resolved.path == root.path || resolved.path.hasPrefix(root.path + "/")
    }
}
