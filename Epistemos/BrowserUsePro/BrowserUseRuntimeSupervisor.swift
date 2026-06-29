import Foundation

nonisolated struct BrowserUseRuntimePaths: Equatable, Sendable {
    let vendorRoot: URL
    let buildRoot: URL
    let stateRoot: URL

    init(vendorRoot: URL, buildRoot: URL, stateRoot: URL) {
        self.vendorRoot = vendorRoot
        self.buildRoot = buildRoot
        self.stateRoot = stateRoot
    }

    var vendorManifestURL: URL {
        vendorRoot.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
    }

    var buildManifestURL: URL {
        vendorRoot.appendingPathComponent("BUILD_MANIFEST.json", isDirectory: false)
    }

    var pythonExecutableURL: URL {
        buildRoot
            .appendingPathComponent(".venv", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("python", isDirectory: false)
    }

    var webUIEntrypointURL: URL {
        vendorRoot
            .appendingPathComponent("web-ui", isDirectory: true)
            .appendingPathComponent("webui.py", isDirectory: false)
    }

    var wheelhouseURL: URL {
        vendorRoot.appendingPathComponent("wheels", isDirectory: true)
    }

    var playwrightURL: URL {
        vendorRoot.appendingPathComponent("playwright", isDirectory: true)
    }

    var environmentFileURL: URL {
        stateRoot.appendingPathComponent(".env", isDirectory: false)
    }

    static func defaultPaths(
        fileManager: FileManager = .default,
        filePath: String = #filePath,
        resourceRootURL: URL? = Bundle.main.resourceURL
    ) -> BrowserUseRuntimePaths? {
        if let resourceRootURL {
            let bundledRoot = resourceRootURL.appendingPathComponent("BrowserUsePro", isDirectory: true)
            if fileManager.fileExists(atPath: bundledRoot.appendingPathComponent("VENDOR_MANIFEST.json").path) {
                return BrowserUseRuntimePaths(
                    vendorRoot: bundledRoot,
                    buildRoot: bundledRoot,
                    stateRoot: defaultStateRoot(fileManager: fileManager, filePath: filePath)
                )
            }
        }

        var cursor = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let vendorRoot = cursor.appendingPathComponent("agent_core/vendor/browser-use", isDirectory: true)
            if fileManager.fileExists(atPath: vendorRoot.appendingPathComponent("VENDOR_MANIFEST.json").path) {
                return BrowserUseRuntimePaths(
                    vendorRoot: vendorRoot,
                    buildRoot: cursor.appendingPathComponent("build/browser-use-pro", isDirectory: true),
                    stateRoot: defaultStateRoot(fileManager: fileManager, filePath: filePath)
                )
            }

            let parent = cursor.deletingLastPathComponent()
            guard parent.path != cursor.path else { break }
            cursor = parent
        }
        return nil
    }

    private static func defaultStateRoot(
        fileManager: FileManager,
        filePath: String
    ) -> URL {
        if let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return applicationSupport
                .appendingPathComponent("Epistemos", isDirectory: true)
                .appendingPathComponent("BrowserUsePro", isDirectory: true)
                .appendingPathComponent("Runtime", isDirectory: true)
        }

        return URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("browser-use-runtime", isDirectory: true)
    }
}

nonisolated struct BrowserUseRuntimeLaunchPlan: Equatable, Sendable {
    let pythonExecutableURL: URL
    let webUIEntrypointURL: URL
    let workingDirectoryURL: URL
    let environmentFileURL: URL
    let loopbackURL: URL
    let arguments: [String]
    let environment: [String: String]
    let environmentFileContents: String
}

nonisolated enum BrowserUseRuntimeReadiness: Equatable, Sendable {
    case unavailable(String)
    case ready(BrowserUseRuntimeLaunchPlan)

    var isReady: Bool {
        if case .ready = self {
            return true
        }
        return false
    }

    var message: String {
        switch self {
        case .unavailable(let reason):
            return reason
        case .ready(let plan):
            return "browser-use Pro runtime ready at \(plan.loopbackURL.absoluteString)"
        }
    }
}

nonisolated enum BrowserUseRuntimeSupervisorError: Error, Equatable, LocalizedError {
    case unavailable(String)
    case appStoreBuild

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return reason
        case .appStoreBuild:
            return "browser-use Pro runtime launch is not compiled into App Store builds."
        }
    }
}

nonisolated struct BrowserUseRuntimeProcessHandle {
    private let terminateProcess: () -> Void

    init(terminate: @escaping () -> Void) {
        self.terminateProcess = terminate
    }

    func terminate() {
        terminateProcess()
    }
}

typealias BrowserUseRuntimeProcessLauncher = (BrowserUseRuntimeLaunchPlan) throws -> BrowserUseRuntimeProcessHandle

private enum BrowserUseRuntimeArtifactKind {
    case file
    case executableFile
    case directory
}

private struct BrowserUseRuntimeArtifactRequirement {
    let name: String
    let url: URL
    let kind: BrowserUseRuntimeArtifactKind
    let rootURL: URL
}

nonisolated enum BrowserUseEnvironmentFileWriter {
    static func write(
        _ contents: String,
        to url: URL,
        fileManager: FileManager = .default
    ) throws {
        let directory = url.deletingLastPathComponent()
        try rejectEnvironmentSymlink(at: directory, label: "directory", fileManager: fileManager)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try rejectEnvironmentSymlink(at: directory, label: "directory", fileManager: fileManager)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        let temporaryURL = directory.appendingPathComponent(".env.\(UUID().uuidString).tmp", isDirectory: false)
        do {
            try rejectEnvironmentSymlink(at: temporaryURL, label: "temporary file", fileManager: fileManager)
            try rejectEnvironmentSymlink(at: url, label: "file", fileManager: fileManager)
            try Data(contents.utf8).write(to: temporaryURL, options: [.atomic])
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporaryURL.path)
            if fileManager.fileExists(atPath: url.path) {
                try rejectEnvironmentSymlink(at: url, label: "file", fileManager: fileManager)
                try fileManager.removeItem(at: url)
            }
            try fileManager.moveItem(at: temporaryURL, to: url)
            try rejectEnvironmentSymlink(at: url, label: "file", fileManager: fileManager)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    private static func rejectEnvironmentSymlink(
        at url: URL,
        label: String,
        fileManager: FileManager
    ) throws {
        if (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil {
            throw BrowserUseRuntimeSupervisorError.unavailable(
                "browser-use environment \(label) must not be a symlink"
            )
        }
    }
}

nonisolated final class BrowserUseRuntimeSupervisor: @unchecked Sendable {
    private static let inheritedEnvironmentAllowlist: Set<String> = [
        "PATH",
        "HOME",
        "USER",
        "LOGNAME",
        "TMPDIR",
        "LANG",
        "LC_ALL",
        "LC_CTYPE",
        "TERM",
        "TZ",
    ]

    private let paths: BrowserUseRuntimePaths
    private let secretStore: BrowserUseSecretStore
    private let fileManager: FileManager
    private let launchProcess: BrowserUseRuntimeProcessLauncher
    private let lifecycleLock = NSLock()

    #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
    private var process: BrowserUseRuntimeProcessHandle?
    #endif

    init?(
        paths: BrowserUseRuntimePaths? = BrowserUseRuntimePaths.defaultPaths(),
        secretStore: BrowserUseSecretStore = BrowserUseSecretStore(),
        fileManager: FileManager = .default,
        launchProcess: @escaping BrowserUseRuntimeProcessLauncher = BrowserUseRuntimeSupervisor.defaultLaunchProcess
    ) {
        guard let paths else {
            return nil
        }
        self.paths = paths
        self.secretStore = secretStore
        self.fileManager = fileManager
        self.launchProcess = launchProcess
    }

    init(
        paths: BrowserUseRuntimePaths,
        secretStore: BrowserUseSecretStore = BrowserUseSecretStore(),
        fileManager: FileManager = .default,
        launchProcess: @escaping BrowserUseRuntimeProcessLauncher = BrowserUseRuntimeSupervisor.defaultLaunchProcess
    ) {
        self.paths = paths
        self.secretStore = secretStore
        self.fileManager = fileManager
        self.launchProcess = launchProcess
    }

    func readiness(
        settings: BrowserUseSettings = .default,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        host: String = "127.0.0.1",
        port: Int = 7788,
        theme: String = "Ocean"
    ) -> BrowserUseRuntimeReadiness {
        Self.readiness(
            paths: paths,
            settings: settings,
            secretStore: secretStore,
            fileManager: fileManager,
            processEnvironment: processEnvironment,
            host: host,
            port: port,
            theme: theme
        )
    }

    @discardableResult
    func start(
        settings: BrowserUseSettings = .default,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        host: String = "127.0.0.1",
        port: Int = 7788,
        theme: String = "Ocean",
        shouldCancel: @Sendable () -> Bool = { false }
    ) throws -> BrowserUseRuntimeLaunchPlan {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        switch readiness(
            settings: settings,
            processEnvironment: processEnvironment,
            host: host,
            port: port,
            theme: theme
        ) {
        case .unavailable(let reason):
            throw BrowserUseRuntimeSupervisorError.unavailable(reason)
        case .ready(let plan):
            if shouldCancel() {
                throw CancellationError()
            }
            try BrowserUseEnvironmentFileWriter.write(
                plan.environmentFileContents,
                to: plan.environmentFileURL,
                fileManager: fileManager
            )
            if shouldCancel() {
                throw CancellationError()
            }

            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            throw BrowserUseRuntimeSupervisorError.appStoreBuild
            #else
            stopLocked()
            process = try launchProcess(plan)
            return plan
            #endif
        }
    }

    func stop() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        stopLocked()
    }

    private func stopLocked() {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        process?.terminate()
        process = nil
        #endif
    }

    private static func defaultLaunchProcess(_ plan: BrowserUseRuntimeLaunchPlan) throws -> BrowserUseRuntimeProcessHandle {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        throw BrowserUseRuntimeSupervisorError.appStoreBuild
        #else
        let runtime = Process()
        runtime.executableURL = plan.pythonExecutableURL
        runtime.arguments = plan.arguments
        runtime.currentDirectoryURL = plan.workingDirectoryURL
        runtime.environment = plan.environment
        try runtime.run()
        return BrowserUseRuntimeProcessHandle {
            runtime.terminate()
        }
        #endif
    }

    static func readiness(
        paths: BrowserUseRuntimePaths,
        settings: BrowserUseSettings,
        secretStore: BrowserUseSecretStore = BrowserUseSecretStore(),
        fileManager: FileManager = .default,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        host: String = "127.0.0.1",
        port: Int = 7788,
        theme: String = "Ocean"
    ) -> BrowserUseRuntimeReadiness {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return .unavailable("browser-use Pro runtime is unavailable in App Store builds; use the native Browser tab.")
        #else
        let gate = BrowserUseProGateStatus.status(
            environment: processEnvironment,
            manifestURL: paths.vendorManifestURL,
            fileManager: fileManager
        )
        guard gate.isActive else {
            return .unavailable("\(gate.headline): \(gate.detail)")
        }

        for requirement in requiredArtifacts(paths: paths) {
            if let problem = artifactProblem(
                name: requirement.name,
                url: requirement.url,
                kind: requirement.kind,
                rootURL: requirement.rootURL,
                fileManager: fileManager
            ) {
                return .unavailable("browser-use Pro runtime \(problem)")
            }
        }

        guard let loopbackURL = BrowserUseLoopbackPolicy.loopbackURL(host: host, port: port) else {
            return .unavailable("browser-use Pro runtime has invalid loopback address \(host):\(port)")
        }

        let browserUseEnvironment = BrowserUseEnvironmentRenderer.dictionary(
            settings: settings,
            secretStore: secretStore
        )
        let inheritedEnvironment = inheritedRuntimeEnvironment(from: processEnvironment)
        var environment = inheritedEnvironment.merging(browserUseEnvironment) { _, new in new }
        environment["PYTHON_DOTENV_DISABLED"] = "true"
        let environmentFileContents = BrowserUseEnvironmentRenderer.render(
            settings: settings,
            secretStore: secretStore
        )

        return .ready(BrowserUseRuntimeLaunchPlan(
            pythonExecutableURL: paths.pythonExecutableURL,
            webUIEntrypointURL: paths.webUIEntrypointURL,
            workingDirectoryURL: paths.stateRoot,
            environmentFileURL: paths.environmentFileURL,
            loopbackURL: loopbackURL,
            arguments: [
                paths.webUIEntrypointURL.path,
                "--ip", host,
                "--port", String(port),
                "--theme", theme,
            ],
            environment: environment,
            environmentFileContents: environmentFileContents
        ))
        #endif
    }

    private static func inheritedRuntimeEnvironment(from processEnvironment: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: processEnvironment.compactMap { key, value in
            guard inheritedEnvironmentAllowlist.contains(key), !value.isEmpty else {
                return nil
            }
            return (key, value)
        })
    }

    private static func artifactProblem(
        name: String,
        url: URL,
        kind: BrowserUseRuntimeArtifactKind,
        rootURL: URL,
        fileManager: FileManager
    ) -> String? {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return "missing \(name) at \(url.path)"
        }
        guard resolvesInsideRuntimeRoot(url, relativeTo: rootURL) else {
            return "\(name) resolves outside browser-use runtime root at \(url.path)"
        }

        switch kind {
        case .file:
            return isDirectory.boolValue ? "\(name) is a directory at \(url.path)" : nil
        case .executableFile:
            if isDirectory.boolValue {
                return "\(name) is a directory at \(url.path)"
            }
            return fileManager.isExecutableFile(atPath: url.path) ? nil : "\(name) is not executable at \(url.path)"
        case .directory:
            return isDirectory.boolValue ? nil : "\(name) is not a directory at \(url.path)"
        }
    }

    private static func resolvesInsideRuntimeRoot(_ url: URL, relativeTo rootURL: URL) -> Bool {
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        return resolved.path == root.path || resolved.path.hasPrefix(root.path + "/")
    }

    private static func requiredArtifacts(paths: BrowserUseRuntimePaths) -> [BrowserUseRuntimeArtifactRequirement] {
        [
            .init(
                name: "Python 3.11 executable",
                url: paths.pythonExecutableURL,
                kind: .executableFile,
                rootURL: paths.buildRoot
            ),
            .init(
                name: "web-ui entrypoint",
                url: paths.webUIEntrypointURL,
                kind: .file,
                rootURL: paths.vendorRoot
            ),
            .init(
                name: "BUILD_MANIFEST.json",
                url: paths.buildManifestURL,
                kind: .file,
                rootURL: paths.vendorRoot
            ),
            .init(
                name: "wheelhouse",
                url: paths.wheelhouseURL,
                kind: .directory,
                rootURL: paths.vendorRoot
            ),
            .init(
                name: "Playwright Chromium payload",
                url: paths.playwrightURL,
                kind: .directory,
                rootURL: paths.vendorRoot
            ),
        ]
    }

}
