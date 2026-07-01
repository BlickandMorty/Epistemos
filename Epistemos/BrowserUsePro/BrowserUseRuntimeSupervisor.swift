import Darwin
import Foundation

nonisolated struct BrowserUseRuntimePaths: Equatable, Sendable {
    let vendorRoot: URL
    let buildRoot: URL
    let stateRoot: URL
    let signedBundleURL: URL?

    init(vendorRoot: URL, buildRoot: URL, stateRoot: URL, signedBundleURL: URL? = nil) {
        self.vendorRoot = vendorRoot
        self.buildRoot = buildRoot
        self.stateRoot = stateRoot
        self.signedBundleURL = signedBundleURL
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

    var agentBrowserAdapterURL: URL {
        vendorRoot.appendingPathComponent("epistemos_agent_browser.py", isDirectory: false)
    }

    func hasExecutableAgentBrowserAdapter(fileManager: FileManager = .default) -> Bool {
        fileManager.isExecutableFile(atPath: agentBrowserAdapterURL.path)
    }

    static func defaultPaths(
        fileManager: FileManager = .default,
        filePath: String = #filePath,
        resourceRootURL: URL? = Bundle.main.resourceURL
    ) -> BrowserUseRuntimePaths? {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return nil
        #else
        if let resourceRootURL {
            let signedBundleURL = resourceRootURL.appendingPathComponent("BrowserUsePro.bundle", isDirectory: true)
            let signedBundlePayloadRoot = signedBundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("BrowserUsePro", isDirectory: true)
            if fileManager.fileExists(atPath: signedBundlePayloadRoot.appendingPathComponent("VENDOR_MANIFEST.json").path) {
                return BrowserUseRuntimePaths(
                    vendorRoot: signedBundlePayloadRoot,
                    buildRoot: signedBundlePayloadRoot,
                    stateRoot: defaultStateRoot(fileManager: fileManager, filePath: filePath),
                    signedBundleURL: signedBundleURL
                )
            }
        }

        var cursor = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let developmentSignedBundleURL = cursor
                .appendingPathComponent("build/browser-use-pro", isDirectory: true)
                .appendingPathComponent("BrowserUsePro.bundle", isDirectory: true)
            let developmentSignedBundlePayloadRoot = developmentSignedBundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("BrowserUsePro", isDirectory: true)
            if fileManager.fileExists(atPath: developmentSignedBundlePayloadRoot.appendingPathComponent("VENDOR_MANIFEST.json").path) {
                return BrowserUseRuntimePaths(
                    vendorRoot: developmentSignedBundlePayloadRoot,
                    buildRoot: developmentSignedBundlePayloadRoot,
                    stateRoot: defaultStateRoot(fileManager: fileManager, filePath: filePath),
                    signedBundleURL: developmentSignedBundleURL
                )
            }

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
        #endif
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
            return "browser-use Pro runtime ready at \(BrowserUseLoopbackPolicy.redactedDescription(for: plan.loopbackURL))"
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
    let allowsInternalSymlink: Bool

    init(
        name: String,
        url: URL,
        kind: BrowserUseRuntimeArtifactKind,
        rootURL: URL,
        allowsInternalSymlink: Bool = false
    ) {
        self.name = name
        self.url = url
        self.kind = kind
        self.rootURL = rootURL
        self.allowsInternalSymlink = allowsInternalSymlink
    }
}

nonisolated enum BrowserUseEnvironmentFileWriter {
    private static let maxPathDiagnosticLength = 160

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
            try writeExclusiveEnvironmentFile(contents, to: temporaryURL)
            if fileManager.fileExists(atPath: url.path) {
                try rejectEnvironmentSymlinkPath(at: url, label: "file", fileManager: fileManager)
                try validateExistingEnvironmentFileForReplacement(at: url)
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

    static func removeIfCurrent(
        _ contents: String,
        at url: URL,
        fileManager: FileManager = .default
    ) {
        do {
            try rejectEnvironmentSymlinkPath(at: url, label: "file", fileManager: fileManager)
            let expectedByteCount = contents.utf8.count
            guard readEnvironmentFileNoFollow(at: url, expectedByteCount: expectedByteCount) == contents else {
                return
            }
            try fileManager.removeItem(at: url)
        } catch {
            return
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
                "browser-use environment \(label) path must not include symlink component at \(pathDiagnostic(component))"
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

    private static func validateExistingEnvironmentFileForReplacement(at url: URL) throws {
        var fileStatus = stat()
        guard lstat(url.path, &fileStatus) == 0 else {
            throw BrowserUseRuntimeSupervisorError.unavailable(
                "browser-use environment file attributes unavailable"
            )
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            throw BrowserUseRuntimeSupervisorError.unavailable(
                "browser-use environment file must be a regular file"
            )
        }
        guard fileStatus.st_nlink <= 1 else {
            throw BrowserUseRuntimeSupervisorError.unavailable(
                "browser-use environment file has multiple hard links"
            )
        }
    }

    private static func writeExclusiveEnvironmentFile(_ contents: String, to url: URL) throws {
        let fd = url.path.withCString { path in
            open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
        }
        guard fd >= 0 else {
            throw BrowserUseRuntimeSupervisorError.unavailable(
                "browser-use environment temporary file could not be created safely"
            )
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: Data(contents.utf8))
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
    }

    private static func readEnvironmentFileNoFollow(at url: URL, expectedByteCount: Int) -> String? {
        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            return nil
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            return nil
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG,
              fileStatus.st_nlink <= 1,
              fileStatus.st_size == off_t(expectedByteCount) else {
            close(fd)
            return nil
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        guard let data = try? handle.readToEnd(),
              data.count == expectedByteCount else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func pathDiagnostic(_ url: URL) -> String {
        let filename = url.lastPathComponent.isEmpty ? "[path]" : url.lastPathComponent
        let diagnostic = cappedDiagnostic(filename, limit: maxPathDiagnosticLength)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return diagnostic.isEmpty ? "[path]" : diagnostic
    }

    private static func cappedDiagnostic(_ value: String, limit: Int) -> String {
        let limit = max(0, limit)
        let normalized = normalizedDiagnostic(value).trimmingCharacters(in: .whitespacesAndNewlines)
        let bounded = String(normalized.prefix(limit + 1))
        guard bounded.count > limit else {
            return bounded
        }
        guard limit > 3 else {
            return String(bounded.prefix(limit))
        }
        return (String(bounded.prefix(limit - 3)) + "...")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedDiagnostic(_ value: String) -> String {
        var normalized = ""
        normalized.reserveCapacity(value.count)
        var previousWasSeparator = false
        for scalar in value.unicodeScalars {
            let isSeparator = CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.controlCharacters.contains(scalar)
            if isSeparator {
                if !previousWasSeparator {
                    normalized.append(" ")
                    previousWasSeparator = true
                }
            } else {
                normalized.unicodeScalars.append(scalar)
                previousWasSeparator = false
            }
        }
        return normalized
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
    private static let maxInheritedEnvironmentValueLength = 4096
    private static let proEnvironmentFilePathEnvironmentName = "EPISTEMOS_BROWSER_USE_ENV_FILE"
    private static let webUICompatibilityShimPaths = [
        "browser-use/browser_use/browser/browser.py",
        "browser-use/browser_use/browser/context.py",
        "browser-use/browser_use/browser/chrome.py",
        "browser-use/browser_use/browser/utils/__init__.py",
        "browser-use/browser_use/browser/utils/screen_resolution.py",
        "browser-use/browser_use/controller/service.py",
        "browser-use/browser_use/controller/registry/__init__.py",
        "browser-use/browser_use/controller/registry/service.py",
        "browser-use/browser_use/controller/registry/views.py",
        "browser-use/browser_use/controller/views.py",
    ]

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
    private var activeEnvironmentFileCleanup: (() -> Void)?
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
            stopLocked()
            try BrowserUseEnvironmentFileWriter.write(
                plan.environmentFileContents,
                to: plan.environmentFileURL,
                fileManager: fileManager
            )
            let environmentFileContents = plan.environmentFileContents
            let environmentFileURL = plan.environmentFileURL
            let cleanupFileManager = fileManager
            let cleanupEnvironmentFile = {
                BrowserUseEnvironmentFileWriter.removeIfCurrent(
                    environmentFileContents,
                    at: environmentFileURL,
                    fileManager: cleanupFileManager
                )
            }
            if shouldCancel() {
                cleanupEnvironmentFile()
                throw CancellationError()
            }

            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            cleanupEnvironmentFile()
            throw BrowserUseRuntimeSupervisorError.appStoreBuild
            #else
            let launchedProcess: BrowserUseRuntimeProcessHandle
            do {
                launchedProcess = try launchProcess(plan)
            } catch {
                cleanupEnvironmentFile()
                throw error
            }
            process = launchedProcess
            do {
                try healthProbe(plan, shouldCancel)
            } catch {
                launchedProcess.terminate()
                process = nil
                cleanupEnvironmentFile()
                throw error
            }
            activeEnvironmentFileCleanup = cleanupEnvironmentFile
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
        activeEnvironmentFileCleanup?()
        activeEnvironmentFileCleanup = nil
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
            if let redirectProblem = redirectDelegate.loadProblem() {
                result.store(problem: redirectProblem)
                return
            }

            if let error {
                result.store(problem: BrowserUseDiagnostics.statusMessage(for: error, fallback: "request failed"))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                result.store(problem: "response was not HTTP")
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
        BrowserUseLoopbackPolicy.redactedDescription(for: url, maxLength: maxURLDiagnosticLength)
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
                allowsInternalSymlink: requirement.allowsInternalSymlink,
                fileManager: fileManager
            ) {
                return .unavailable("browser-use Pro runtime \(problem)")
            }
        }

        guard let loopbackURL = BrowserUseLoopbackPolicy.loopbackURL(host: host, port: port),
              let loopbackOrigin = BrowserUseLoopbackPolicy.origin(for: loopbackURL) else {
            return .unavailable(
                "browser-use Pro runtime has invalid loopback address \(loopbackAddressDiagnostic(host: host, port: port))"
            )
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
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        environment["PLAYWRIGHT_BROWSERS_PATH"] = paths.playwrightURL.path
        environment["GRADIO_ANALYTICS_ENABLED"] = "False"
        environment["BROWSER_USE_SETUP_LOGGING"] = "false"
        environment[proEnvironmentFilePathEnvironmentName] = paths.environmentFileURL.path
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
            guard inheritedEnvironmentAllowlist.contains(key),
                  let value = sanitizedInheritedEnvironmentValue(value) else {
                return nil
            }
            return (key, value)
        })
    }

    private static func sanitizedInheritedEnvironmentValue(_ value: String) -> String? {
        guard !value.isEmpty,
              value.utf8.count <= maxInheritedEnvironmentValueLength,
              value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            return nil
        }
        return value
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

    private static func loopbackAddressDiagnostic(host: String, port: Int) -> String {
        let safeHost = loopbackHostDiagnostic(host)
        let safePort = (1...65535).contains(port) ? String(port) : "[invalid-port]"
        return cappedDiagnostic("\(safeHost):\(safePort)", limit: maxURLDiagnosticLength)
    }

    private static func loopbackHostDiagnostic(_ host: String) -> String {
        let bounded = String(host.prefix(maxURLDiagnosticLength + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "[empty-host]"
        }

        if let parsed = URL(string: trimmed),
           parsed.scheme != nil,
           parsed.host != nil {
            return BrowserUseLoopbackPolicy.redactedDescription(for: parsed, maxLength: maxURLDiagnosticLength)
        }

        let withoutControlCharacters = String(trimmed.unicodeScalars.map { scalar in
            CharacterSet.controlCharacters.contains(scalar) ? " " : String(scalar)
        }.joined())
        let withoutCredentials = withoutControlCharacters.split(
            separator: "@",
            omittingEmptySubsequences: false
        ).last.map(String.init) ?? withoutControlCharacters
        let withoutPathOrTokenTail = withoutCredentials.split(
            whereSeparator: { character in
                character == "/" || character == "\\" || character == "?" || character == "#"
            }
        ).first.map(String.init) ?? withoutCredentials
        let scrubbed = withoutPathOrTokenTail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !scrubbed.isEmpty else {
            return "[blocked-host]"
        }
        return cappedDiagnostic(scrubbed, limit: maxURLDiagnosticLength)
    }

    private static func cappedDiagnostic(_ value: String, limit: Int) -> String {
        let limit = max(0, limit)
        let normalized = normalizedDiagnostic(value).trimmingCharacters(in: .whitespacesAndNewlines)
        let bounded = String(normalized.prefix(limit + 1))
        guard bounded.count > limit else {
            return bounded
        }
        guard limit > 3 else {
            return String(bounded.prefix(limit))
        }
        return (String(bounded.prefix(limit - 3)) + "...")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedDiagnostic(_ value: String) -> String {
        var normalized = ""
        normalized.reserveCapacity(value.count)
        var previousWasSeparator = false
        for scalar in value.unicodeScalars {
            let isSeparator = CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.controlCharacters.contains(scalar)
            if isSeparator {
                if !previousWasSeparator {
                    normalized.append(" ")
                    previousWasSeparator = true
                }
            } else {
                normalized.unicodeScalars.append(scalar)
                previousWasSeparator = false
            }
        }
        return normalized
    }

    private static func artifactProblem(
        name: String,
        url: URL,
        kind: BrowserUseRuntimeArtifactKind,
        rootURL: URL,
        allowsInternalSymlink: Bool,
        fileManager: FileManager
    ) -> String? {
        let diagnosticPath = runtimeArtifactPathDescription(url, relativeTo: rootURL)
        if let symlinkComponent = BrowserUseSymlinkPathGuard.firstSymlinkComponent(in: url, fileManager: fileManager) {
            if !resolvesInsideRuntimeRoot(url, relativeTo: rootURL) {
                return "\(name) resolves outside browser-use runtime root at \(diagnosticPath)"
            }
            if !allowsInternalSymlink || symlinkComponent.standardizedFileURL.path != url.standardizedFileURL.path {
                return "\(name) path must not include symlink component at \(diagnosticPath)"
            }
        }

        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return "missing \(name) at \(diagnosticPath)"
        }
        guard resolvesInsideRuntimeRoot(url, relativeTo: rootURL) else {
            return "\(name) resolves outside browser-use runtime root at \(diagnosticPath)"
        }
        let inspectedURL = allowsInternalSymlink
            ? url.standardizedFileURL.resolvingSymlinksInPath()
            : url.standardizedFileURL
        let artifactType = fileType(at: inspectedURL, fileManager: fileManager)

        switch kind {
        case .file:
            if isDirectory.boolValue {
                return "\(name) is a directory at \(diagnosticPath)"
            }
            return artifactType == .typeRegular ? nil : "\(name) is not a regular file at \(diagnosticPath)"
        case .executableFile:
            if isDirectory.boolValue {
                return "\(name) is a directory at \(diagnosticPath)"
            }
            guard artifactType == .typeRegular else {
                return "\(name) is not a regular file at \(diagnosticPath)"
            }
            return fileManager.isExecutableFile(atPath: url.path) ? nil : "\(name) is not executable at \(diagnosticPath)"
        case .directory:
            return isDirectory.boolValue ? nil : "\(name) is not a directory at \(diagnosticPath)"
        }
    }

    private static func fileType(at url: URL, fileManager: FileManager) -> FileAttributeType? {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return attributes?[.type] as? FileAttributeType
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

        let diagnostic = cappedDiagnostic(description, limit: maxPathDiagnosticLength)
        return diagnostic.isEmpty ? "[runtime path]" : diagnostic
    }

    private static func resolvesInsideRuntimeRoot(_ url: URL, relativeTo rootURL: URL) -> Bool {
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        return resolved.path == root.path || resolved.path.hasPrefix(root.path + "/")
    }

    private static func requiredArtifacts(paths: BrowserUseRuntimePaths) -> [BrowserUseRuntimeArtifactRequirement] {
        var requirements = [
            .init(
                name: "Python 3.11 executable",
                url: paths.pythonExecutableURL,
                kind: .executableFile,
                rootURL: paths.buildRoot,
                allowsInternalSymlink: true
            ),
            .init(
                name: "web-ui entrypoint",
                url: paths.webUIEntrypointURL,
                kind: .file,
                rootURL: paths.vendorRoot
            ),
            .init(
                name: "agent-browser adapter",
                url: paths.agentBrowserAdapterURL,
                kind: .executableFile,
                rootURL: paths.vendorRoot
            ),
            .init(
                name: "agent-browser environment helper",
                url: paths.vendorRoot.appendingPathComponent("epistemos_browser_env.py", isDirectory: false),
                kind: .file,
                rootURL: paths.vendorRoot
            ),
            .init(
                name: "agent-browser task helper",
                url: paths.vendorRoot.appendingPathComponent("epistemos_browser_task.py", isDirectory: false),
                kind: .file,
                rootURL: paths.vendorRoot
            ),
            .init(
                name: "build-pro-payload.sh",
                url: paths.vendorRoot.appendingPathComponent("build-pro-payload.sh", isDirectory: false),
                kind: .executableFile,
                rootURL: paths.vendorRoot
            ),
            .init(
                name: "BUILD_MANIFEST.json",
                url: paths.buildManifestURL,
                kind: .file,
                rootURL: paths.vendorRoot
            ),
            .init(
                name: "requirements.lock",
                url: paths.vendorRoot.appendingPathComponent("requirements.lock", isDirectory: false),
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
        requirements.append(contentsOf: webUICompatibilityShimPaths.map { relativePath in
            BrowserUseRuntimeArtifactRequirement(
                name: "web-ui compatibility shim",
                url: paths.vendorRoot.appendingPathComponent(relativePath, isDirectory: false),
                kind: .file,
                rootURL: paths.vendorRoot
            )
        })
        requirements.append(.init(
            name: "web-ui dry-run submit hook",
            url: paths.vendorRoot.appendingPathComponent(
                "web-ui/src/webui/components/browser_use_agent_tab.py",
                isDirectory: false
            ),
            kind: .file,
            rootURL: paths.vendorRoot
        ))
        return requirements
    }

}
