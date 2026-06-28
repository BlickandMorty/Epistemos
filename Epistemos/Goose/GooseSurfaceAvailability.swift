import Foundation

struct GooseSurfaceAvailability: Equatable {
    let runtimeBinary: URL?
    let webUIIndex: URL?

    var isReady: Bool {
        runtimeBinary != nil && webUIIndex != nil
    }

    var menuTitle: String {
        isReady ? "Open Epistemos Goose" : "Epistemos Goose (runtime/UI missing)"
    }

    var unavailableMessage: String {
        switch (runtimeBinary, webUIIndex) {
        case (nil, nil):
            return "Goose runtime and Web UI are not bundled or staged for this build."
        case (nil, _):
            return "Goose runtime is not bundled or staged for this build."
        case (_, nil):
            return "Goose Web UI is not bundled or staged for this build."
        case (.some, .some):
            return ""
        }
    }

    nonisolated static func current(
        bundle: Bundle? = .main,
        fileManager: FileManager = .default,
        appSupportDirectory: URL? = defaultAppSupportDirectory(fileManager: .default),
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        includeBundledWebUICandidates: Bool = true
    ) -> GooseSurfaceAvailability {
        GooseSurfaceAvailability(
            runtimeBinary: GooseRuntimeSupervisor.resolvedGooseBinary(
                bundle: bundle,
                appSupportDirectory: appSupportDirectory,
                currentDirectory: currentDirectory
            ),
            webUIIndex: GooseWebUIResolver.indexURL(
                bundle: bundle,
                fileManager: fileManager,
                appSupportDirectory: appSupportDirectory,
                currentDirectory: currentDirectory,
                environment: environment,
                includeBundledCandidates: includeBundledWebUICandidates
            )
        )
    }

    nonisolated private static func defaultAppSupportDirectory(fileManager: FileManager) -> URL? {
        try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
    }
}
