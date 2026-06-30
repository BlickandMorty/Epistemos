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
typealias BrowserUseRuntimeHealthProbe = @Sendable (
    _ plan: BrowserUseRuntimeLaunchPlan,
    _ shouldCancel: @Sendable () -> Bool
) throws -> Void

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
        try rejectEnvironmentSymlinkPath(at: directory, label: "directory", fileManager: fileManager)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try rejectEnvironmentSymlinkPath(at: directory, label: "directory", fileManager: fileManager)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        let temporaryURL = directory.appendingPathComponent(".env.\(UUID().uuidString).tmp", isDirectory: false)
        do {
            try rejectEnvironmentSymlinkPath(at: temporaryURL, label: "temporary file", fileManager: fileManager)
            try rejectEnvironmentSymlinkPath(at: url, label: "file", fileManager: fileManager)
            try Data(contents.utf8).write(to: temporaryURL, options: [.atomic])
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporaryURL.path)
            if fileManager.fileExists(atPath: url.path) {
                try rejectEnvironmentSymlinkPath(at: url, label: "file", fileManager: fileManager)
                try fileManager.removeItem(at: url)
            }
            try fileManager.moveItem(at: temporaryURL, to: url)
            try rejectEnvironmentSymlinkPath(at: url, label: "file", fileManager: fileManager)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    private static func rejectEnvironmentSymlinkPath(
        at url: URL,
        label: String,
        fileManager: FileManager
    ) throws {
        try rejectEnvironmentSymlink(at: url, label: label, fileManager: fileManager)
        if let component = BrowserUseSymlinkPathGuard.firstSymlinkComponent(in: url, fileManager: fileManager) {
            throw BrowserUseRuntimeSupervisorError.unavailable(
                "browser-use environment \(label) path must not include symlink component at \(component.path)"
            )
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

nonisolated private final class BrowserUseLoopbackHealthProbeResult: @unchecked Sendable {
    private let lock = NSLock()
    private var problem: String?
    private var hasResult = false

    func store(problem: String?) {
        lock.lock()
        self.problem = problem
        hasResult = true
        lock.unlock()
    }

    func loadProblem() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard hasResult else {
            return "health probe returned no result"
        }
        return problem
    }
}

nonisolated private final class BrowserUseLoopbackHealthRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let expectedOrigin: BrowserUseLoopbackOrigin
    private let lock = NSLock()
    private var problem: String?

    init(expectedOrigin: BrowserUseLoopbackOrigin) {
        self.expectedOrigin = expectedOrigin
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        if let redirectProblem = BrowserUseRuntimeSupervisor.loopbackHTTPRedirectProblem(
            request.url,
            expectedOrigin: expectedOrigin
        ) {
            store(problem: redirectProblem)
            completionHandler(nil)
            return
        }

        completionHandler(request)
    }

    func loadProblem() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return problem
    }

    private func store(problem: String) {
        lock.lock()
        self.problem = problem
        lock.unlock()
    }
}

nonisolated final class BrowserUseRuntimeSupervisor: @unchecked Sendable {
    private static let healthProbeDeadlineSeconds: TimeInterval = 20
    private static let healthProbeRequestTimeoutSeconds: TimeInterval = 1
    private static let healthProbePollIntervalSeconds: TimeInterval = 0.25
    private static let maxThemeLength = 64
    private static let maxURLDiagnosticLength = 120
    private static let maxPathDiagnosticLength = 160

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
    private let healthProbe: BrowserUseRuntimeHealthProbe
    private let lifecycleLock = NSLock()

    #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
    private var process: BrowserUseRuntimeProcessHandle?
    #endif

    init?(
        paths: BrowserUseRuntimePaths? = BrowserUseRuntimePaths.defaultPaths(),
        secretStore: BrowserUseSecretStore = BrowserUseSecretStore(),
        fileManager: FileManager = .default,
        launchProcess: @escaping BrowserUseRuntimeProcessLauncher = BrowserUseRuntimeSupervisor.defaultLaunchProcess,
        healthProbe: @escaping BrowserUseRuntimeHealthProbe = BrowserUseRuntimeSupervisor.defaultHealthProbe
    ) {
        guard let paths else {
            return nil
        }
        self.paths = paths
        self.secretStore = secretStore
        self.fileManager = fileManager
        self.launchProcess = launchProcess
        self.healthProbe = healthProbe
    }

    init(
        paths: BrowserUseRuntimePaths,
        secretStore: BrowserUseSecretStore = BrowserUseSecretStore(),
        fileManager: FileManager = .default,
        launchProcess: @escaping BrowserUseRuntimeProcessLauncher = BrowserUseRuntimeSupervisor.defaultLaunchProcess,
        healthProbe: @escaping BrowserUseRuntimeHealthProbe = BrowserUseRuntimeSupervisor.defaultHealthProbe
    ) {
        self.paths = paths
        self.secretStore = secretStore
        self.fileManager = fileManager
        self.launchProcess = launchProcess
        self.healthProbe = healthProbe
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
            let launchedProcess = try launchProcess(plan)
            process = launchedProcess
            do {
                try healthProbe(plan, shouldCancel)
            } catch {
                launchedProcess.terminate()
                process = nil
                throw error
            }
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

    private static let defaultHealthProbe: BrowserUseRuntimeHealthProbe = { plan, shouldCancel in
        try BrowserUseRuntimeSupervisor.defaultHealthProbeImpl(plan, shouldCancel)
    }

    private static func defaultHealthProbeImpl(
        _ plan: BrowserUseRuntimeLaunchPlan,
        _ shouldCancel: @Sendable () -> Bool
    ) throws {
        guard BrowserUseLoopbackPolicy.allows(url: plan.loopbackURL) else {
            throw BrowserUseRuntimeSupervisorError.unavailable(
                "browser-use Pro Web UI health probe refused non-loopback URL \(redactedURLDescription(plan.loopbackURL))"
            )
        }

        let deadline = Date().addingTimeInterval(healthProbeDeadlineSeconds)
        var lastProblem = "timed out waiting for loopback response"
        while Date() < deadline {
            if shouldCancel() {
                throw CancellationError()
            }
            if let problem = loopbackHealthProblem(for: plan.loopbackURL, timeout: healthProbeRequestTimeoutSeconds) {
                lastProblem = problem
            } else {
                return
            }
            Thread.sleep(forTimeInterval: healthProbePollIntervalSeconds)
        }

        throw BrowserUseRuntimeSupervisorError.unavailable(
            "browser-use Pro Web UI health probe failed at \(redactedURLDescription(plan.loopbackURL)): \(lastProblem)"
        )
    }

    private static func loopbackHealthProblem(for url: URL, timeout: TimeInterval) -> String? {
        guard BrowserUseLoopbackPolicy.allows(url: url),
              let expectedOrigin = BrowserUseLoopbackPolicy.origin(for: url) else {
            return "non-loopback URL"
        }

        let semaphore = DispatchSemaphore(value: 0)
        let result = BrowserUseLoopbackHealthProbeResult()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.urlCache = nil
        let redirectDelegate = BrowserUseLoopbackHealthRedirectDelegate(expectedOrigin: expectedOrigin)
        let session = URLSession(configuration: configuration, delegate: redirectDelegate, delegateQueue: nil)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = timeout
        request.setValue("Epistemos-browser-use-health", forHTTPHeaderField: "User-Agent")

        let task = session.dataTask(with: request) { _, response, error in
            defer { semaphore.signal() }
            if let error {
                result.store(problem: BrowserUseDiagnostics.statusMessage(for: error, fallback: "request failed"))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                result.store(problem: "response was not HTTP")
                return
            }

            if let redirectProblem = redirectDelegate.loadProblem() {
                result.store(problem: redirectProblem)
                return
            }

            result.store(problem: loopbackHTTPStatusProblem(httpResponse.statusCode))
        }
        task.resume()

        if semaphore.wait(timeout: .now() + timeout + 0.25) == .timedOut {
            task.cancel()
            session.invalidateAndCancel()
            return "timed out waiting for loopback response"
        }

        session.finishTasksAndInvalidate()
        return result.loadProblem()
    }

    static func loopbackHTTPStatusProblem(_ statusCode: Int) -> String? {
        if (200..<400).contains(statusCode) {
            return nil
        }
        return "HTTP \(statusCode)"
    }

    private static func redactedURLDescription(_ url: URL) -> String {
        let sourceComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let scheme = sourceComponents?.scheme ?? url.scheme,
              let host = sourceComponents?.host ?? url.host,
              !host.isEmpty else {
            return "[redacted URL]"
        }

        var displayComponents = URLComponents()
        displayComponents.scheme = scheme
        displayComponents.host = host
        displayComponents.port = sourceComponents?.port ?? url.port
        let rendered = displayComponents.string ?? "\(scheme)://\(host)"
        if rendered.count <= maxURLDiagnosticLength {
            return rendered
        }
        return String(rendered.prefix(maxURLDiagnosticLength)) + "..."
    }

    static func loopbackHTTPRedirectProblem(
        _ url: URL?,
        expectedOrigin: BrowserUseLoopbackOrigin? = nil
    ) -> String? {
        guard let url else {
            return "redirected without a Location URL"
        }
        guard let origin = BrowserUseLoopbackPolicy.origin(for: url) else {
            return "redirected to non-loopback URL \(redactedURLDescription(url))"
        }
        if let expectedOrigin, origin != expectedOrigin {
            return "redirected to different loopback origin \(redactedURLDescription(url))"
        }
        return nil
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

        guard let loopbackURL = BrowserUseLoopbackPolicy.loopbackURL(host: host, port: port),
              let loopbackOrigin = BrowserUseLoopbackPolicy.origin(for: loopbackURL) else {
            return .unavailable("browser-use Pro runtime has invalid loopback address \(host):\(port)")
        }
        let launchHost = loopbackOrigin.host
        guard let theme = normalizedThemeArgument(theme) else {
            return .unavailable("browser-use Pro runtime has invalid Web UI theme")
        }
        if let settingsProblem = BrowserUseSettingsValidation.problem(in: settings) {
            return .unavailable("browser-use Pro runtime settings invalid: \(settingsProblem)")
        }

        let browserUsePairs = BrowserUseEnvironmentRenderer.pairs(
            settings: settings,
            secretStore: secretStore
        )
        let browserUseEnvironment = BrowserUseEnvironmentRenderer.dictionary(browserUsePairs)
        let inheritedEnvironment = inheritedRuntimeEnvironment(from: processEnvironment)
        var environment = inheritedEnvironment.merging(browserUseEnvironment) { _, new in new }
        environment["PYTHON_DOTENV_DISABLED"] = "true"
        let environmentFileContents = BrowserUseEnvironmentRenderer.render(browserUsePairs)

        return .ready(BrowserUseRuntimeLaunchPlan(
            pythonExecutableURL: paths.pythonExecutableURL,
            webUIEntrypointURL: paths.webUIEntrypointURL,
            workingDirectoryURL: paths.stateRoot,
            environmentFileURL: paths.environmentFileURL,
            loopbackURL: loopbackURL,
            arguments: [
                paths.webUIEntrypointURL.path,
                "--ip", launchHost,
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

    private static func normalizedThemeArgument(_ theme: String) -> String? {
        let normalized = theme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              normalized.count <= maxThemeLength else {
            return nil
        }

        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_./:-")
        guard normalized.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        return normalized
    }

    private static func artifactProblem(
        name: String,
        url: URL,
        kind: BrowserUseRuntimeArtifactKind,
        rootURL: URL,
        fileManager: FileManager
    ) -> String? {
        let diagnosticPath = runtimeArtifactPathDescription(url, relativeTo: rootURL)
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return "missing \(name) at \(diagnosticPath)"
        }
        guard resolvesInsideRuntimeRoot(url, relativeTo: rootURL) else {
            return "\(name) resolves outside browser-use runtime root at \(diagnosticPath)"
        }

        switch kind {
        case .file:
            return isDirectory.boolValue ? "\(name) is a directory at \(diagnosticPath)" : nil
        case .executableFile:
            if isDirectory.boolValue {
                return "\(name) is a directory at \(diagnosticPath)"
            }
            return fileManager.isExecutableFile(atPath: url.path) ? nil : "\(name) is not executable at \(diagnosticPath)"
        case .directory:
            return isDirectory.boolValue ? nil : "\(name) is not a directory at \(diagnosticPath)"
        }
    }

    private static func runtimeArtifactPathDescription(_ url: URL, relativeTo rootURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path

        let description: String
        if candidatePath == rootPath {
            description = "."
        } else if candidatePath.hasPrefix(rootPath + "/") {
            description = String(candidatePath.dropFirst(rootPath.count + 1))
        } else {
            description = "[outside runtime root]"
        }

        guard description.count > maxPathDiagnosticLength else {
            return description
        }
        return String(description.prefix(maxPathDiagnosticLength)) + "..."
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
