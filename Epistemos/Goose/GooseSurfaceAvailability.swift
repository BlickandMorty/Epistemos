import Foundation

struct GooseSurfaceAvailability: Equatable {
    let runtimeBinary: URL?
    let webUIIndex: URL?

    var isReady: Bool {
        #if EPISTEMOS_APP_STORE
        webUIIndex != nil
        #else
        runtimeBinary != nil && webUIIndex != nil
        #endif
    }

    var menuTitle: String {
        #if EPISTEMOS_APP_STORE
        isReady ? "Open Epistemos Goose" : "Epistemos Goose (Web UI missing)"
        #else
        isReady ? "Open Epistemos Goose" : "Epistemos Goose (runtime/UI missing)"
        #endif
    }

    var unavailableMessage: String {
        #if EPISTEMOS_APP_STORE
        if webUIIndex == nil {
            return "Goose Web UI is not bundled or staged for this build."
        }
        return ""
        #else
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
        #endif
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
