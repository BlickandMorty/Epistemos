import Darwin
import Foundation

nonisolated struct BrowserUseEnvironmentPair: Equatable, Sendable {
    let name: String
    let value: String
}

nonisolated struct BrowserUseProviderSettings: Codable, Equatable, Sendable {
    var defaultLLM: String
    var openAIEndpoint: String
    var anthropicEndpoint: String
    var googleEndpoint: String
    var azureOpenAIEndpoint: String
    var azureOpenAIAPIVersion: String
    var deepSeekEndpoint: String
    var mistralEndpoint: String
    var ollamaEndpoint: String
    var alibabaEndpoint: String
    var modelScopeEndpoint: String
    var moonshotEndpoint: String
    var unboundEndpoint: String
    var siliconFlowEndpoint: String
    var ibmEndpoint: String
    var grokEndpoint: String
    var awsRegion: String
    var awsDefaultRegion: String

    init(
        defaultLLM: String = "openai",
        openAIEndpoint: String = "https://api.openai.com/v1",
        anthropicEndpoint: String = "https://api.anthropic.com",
        googleEndpoint: String = "",
        azureOpenAIEndpoint: String = "",
        azureOpenAIAPIVersion: String = "2025-01-01-preview",
        deepSeekEndpoint: String = "https://api.deepseek.com",
        mistralEndpoint: String = "https://api.mistral.ai/v1",
        ollamaEndpoint: String = "http://localhost:11434",
        alibabaEndpoint: String = "https://dashscope.aliyuncs.com/compatible-mode/v1",
        modelScopeEndpoint: String = "https://api-inference.modelscope.cn/v1",
        moonshotEndpoint: String = "https://api.moonshot.cn/v1",
        unboundEndpoint: String = "https://api.getunbound.ai",
        siliconFlowEndpoint: String = "https://api.siliconflow.cn/v1/",
        ibmEndpoint: String = "https://us-south.ml.cloud.ibm.com",
        grokEndpoint: String = "https://api.x.ai/v1",
        awsRegion: String = "",
        awsDefaultRegion: String = "us-east-1"
    ) {
        self.defaultLLM = defaultLLM
        self.openAIEndpoint = openAIEndpoint
        self.anthropicEndpoint = anthropicEndpoint
        self.googleEndpoint = googleEndpoint
        self.azureOpenAIEndpoint = azureOpenAIEndpoint
        self.azureOpenAIAPIVersion = azureOpenAIAPIVersion
        self.deepSeekEndpoint = deepSeekEndpoint
        self.mistralEndpoint = mistralEndpoint
        self.ollamaEndpoint = ollamaEndpoint
        self.alibabaEndpoint = alibabaEndpoint
        self.modelScopeEndpoint = modelScopeEndpoint
        self.moonshotEndpoint = moonshotEndpoint
        self.unboundEndpoint = unboundEndpoint
        self.siliconFlowEndpoint = siliconFlowEndpoint
        self.ibmEndpoint = ibmEndpoint
        self.grokEndpoint = grokEndpoint
        self.awsRegion = awsRegion
        self.awsDefaultRegion = awsDefaultRegion
    }

    var environmentPairs: [BrowserUseEnvironmentPair] {
        [
            .init(name: "OPENAI_ENDPOINT", value: openAIEndpoint),
            .init(name: "ANTHROPIC_ENDPOINT", value: anthropicEndpoint),
            .init(name: "GOOGLE_ENDPOINT", value: googleEndpoint),
            .init(name: "AZURE_OPENAI_ENDPOINT", value: azureOpenAIEndpoint),
            .init(name: "AZURE_OPENAI_API_VERSION", value: azureOpenAIAPIVersion),
            .init(name: "DEEPSEEK_ENDPOINT", value: deepSeekEndpoint),
            .init(name: "MISTRAL_ENDPOINT", value: mistralEndpoint),
            .init(name: "OLLAMA_ENDPOINT", value: ollamaEndpoint),
            .init(name: "ALIBABA_ENDPOINT", value: alibabaEndpoint),
            .init(name: "MODELSCOPE_ENDPOINT", value: modelScopeEndpoint),
            .init(name: "MOONSHOT_ENDPOINT", value: moonshotEndpoint),
            .init(name: "UNBOUND_ENDPOINT", value: unboundEndpoint),
            .init(name: "SiliconFLOW_ENDPOINT", value: siliconFlowEndpoint),
            .init(name: "IBM_ENDPOINT", value: ibmEndpoint),
            .init(name: "GROK_ENDPOINT", value: grokEndpoint),
            .init(name: "AWS_REGION", value: awsRegion),
            .init(name: "AWS_DEFAULT_REGION", value: awsDefaultRegion),
            .init(name: "DEFAULT_LLM", value: defaultLLM),
        ]
    }
}

nonisolated struct BrowserUseBrowserSettings: Codable, Equatable, Sendable {
    var browserPath: String
    var browserUserData: String
    var debuggingPort: Int
    var debuggingHost: String
    var keepBrowserOpen: Bool
    var useOwnBrowser: Bool
    var browserCDP: String
    var resolutionWidth: Int
    var resolutionHeight: Int
    var resolutionDepth: Int
    var executablePath: String
    var headless: Bool
    var userDataDirectory: String

    init(
        browserPath: String = "",
        browserUserData: String = "",
        debuggingPort: Int = 9222,
        debuggingHost: String = "localhost",
        keepBrowserOpen: Bool = true,
        useOwnBrowser: Bool = false,
        browserCDP: String = "",
        resolutionWidth: Int = 1920,
        resolutionHeight: Int = 1080,
        resolutionDepth: Int = 24,
        executablePath: String = "",
        headless: Bool = false,
        userDataDirectory: String = ""
    ) {
        self.browserPath = browserPath
        self.browserUserData = browserUserData
        self.debuggingPort = debuggingPort
        self.debuggingHost = debuggingHost
        self.keepBrowserOpen = keepBrowserOpen
        self.useOwnBrowser = useOwnBrowser
        self.browserCDP = browserCDP
        self.resolutionWidth = resolutionWidth
        self.resolutionHeight = resolutionHeight
        self.resolutionDepth = resolutionDepth
        self.executablePath = executablePath
        self.headless = headless
        self.userDataDirectory = userDataDirectory
    }

    var resolution: String {
        "\(resolutionWidth)x\(resolutionHeight)x\(resolutionDepth)"
    }

    var environmentPairs: [BrowserUseEnvironmentPair] {
        [
            .init(name: "BROWSER_PATH", value: browserPath),
            .init(name: "BROWSER_USER_DATA", value: browserUserData),
            .init(name: "BROWSER_DEBUGGING_PORT", value: String(debuggingPort)),
            .init(name: "BROWSER_DEBUGGING_HOST", value: debuggingHost),
            .init(name: "KEEP_BROWSER_OPEN", value: BrowserUseSettings.boolString(keepBrowserOpen)),
            .init(name: "USE_OWN_BROWSER", value: BrowserUseSettings.boolString(useOwnBrowser)),
            .init(name: "BROWSER_CDP", value: browserCDP),
            .init(name: "RESOLUTION", value: resolution),
            .init(name: "RESOLUTION_WIDTH", value: String(resolutionWidth)),
            .init(name: "RESOLUTION_HEIGHT", value: String(resolutionHeight)),
            .init(name: "BROWSER_USE_EXECUTABLE_PATH", value: executablePath),
            .init(name: "BROWSER_USE_HEADLESS", value: BrowserUseSettings.boolString(headless)),
            .init(name: "BROWSER_USE_USER_DATA_DIR", value: userDataDirectory),
        ]
    }
}

nonisolated struct BrowserUseRuntimeSettings: Codable, Equatable, Sendable {
    var anonymizedTelemetry: Bool
    var loggingLevel: String
    var debugLogFile: String
    var infoLogFile: String
    var cdpLoggingLevel: String
    var cloudAPIURL: String
    var cloudUIURL: String
    var cloudBaseURL: String
    var cloudSync: Bool
    var versionCheck: Bool
    var proxyServer: String
    var noProxy: String

    init(
        anonymizedTelemetry: Bool = false,
        loggingLevel: String = "info",
        debugLogFile: String = "",
        infoLogFile: String = "",
        cdpLoggingLevel: String = "WARNING",
        cloudAPIURL: String = "https://api.browser-use.com",
        cloudUIURL: String = "",
        cloudBaseURL: String = "",
        cloudSync: Bool = false,
        versionCheck: Bool = false,
        proxyServer: String = "",
        noProxy: String = "localhost,127.0.0.1"
    ) {
        self.anonymizedTelemetry = anonymizedTelemetry
        self.loggingLevel = loggingLevel
        self.debugLogFile = debugLogFile
        self.infoLogFile = infoLogFile
        self.cdpLoggingLevel = cdpLoggingLevel
        self.cloudAPIURL = cloudAPIURL
        self.cloudUIURL = cloudUIURL
        self.cloudBaseURL = cloudBaseURL
        self.cloudSync = cloudSync
        self.versionCheck = versionCheck
        self.proxyServer = proxyServer
        self.noProxy = noProxy
    }

    var environmentPairs: [BrowserUseEnvironmentPair] {
        [
            .init(name: "ANONYMIZED_TELEMETRY", value: BrowserUseSettings.boolString(anonymizedTelemetry)),
            .init(name: "BROWSER_USE_LOGGING_LEVEL", value: loggingLevel),
            .init(name: "BROWSER_USE_DEBUG_LOG_FILE", value: debugLogFile),
            .init(name: "BROWSER_USE_INFO_LOG_FILE", value: infoLogFile),
            .init(name: "CDP_LOGGING_LEVEL", value: cdpLoggingLevel),
            .init(name: "BROWSER_USE_CLOUD_API_URL", value: cloudAPIURL),
            .init(name: "BROWSER_USE_CLOUD_UI_URL", value: cloudUIURL),
            .init(name: "BROWSER_USE_CLOUD_BASE_URL", value: cloudBaseURL),
            .init(name: "BROWSER_USE_CLOUD_SYNC", value: BrowserUseSettings.boolString(cloudSync)),
            .init(name: "BROWSER_USE_VERSION_CHECK", value: BrowserUseSettings.boolString(versionCheck)),
            .init(name: "BROWSER_USE_PROXY_SERVER", value: proxyServer),
            .init(name: "BROWSER_USE_PROXY_URL", value: proxyServer),
            .init(name: "BROWSER_USE_NO_PROXY", value: noProxy),
        ]
    }
}

nonisolated struct BrowserUseSettings: Codable, Equatable, Sendable {
    var providers: BrowserUseProviderSettings
    var browser: BrowserUseBrowserSettings
    var runtime: BrowserUseRuntimeSettings

    static let `default` = BrowserUseSettings()

    init(
        providers: BrowserUseProviderSettings = BrowserUseProviderSettings(),
        browser: BrowserUseBrowserSettings = BrowserUseBrowserSettings(),
        runtime: BrowserUseRuntimeSettings = BrowserUseRuntimeSettings()
    ) {
        self.providers = providers
        self.browser = browser
        self.runtime = runtime
    }

    var nonSecretEnvironmentPairs: [BrowserUseEnvironmentPair] {
        providers.environmentPairs + browser.environmentPairs + runtime.environmentPairs
    }

    static func boolString(_ value: Bool) -> String {
        value ? "true" : "false"
    }
}

nonisolated enum BrowserUseSettingsValidation {
    private static let maxEnvironmentValueBytes = 4096
    private static let allowedProxyServerSchemes: Set<String> = [
        "http",
        "https",
        "socks4",
        "socks5",
        "socks5h",
    ]

    static func problem(in settings: BrowserUseSettings) -> String? {
        if let environmentProblem = nonSecretEnvironmentValueProblem(settings.nonSecretEnvironmentPairs) {
            return environmentProblem
        }
        if let providerEndpointProblem = providerEndpointProblem(settings.providers) {
            return providerEndpointProblem
        }
        if let cloudEndpointProblem = cloudEndpointProblem(settings.runtime) {
            return cloudEndpointProblem
        }
        let browser = settings.browser
        guard (1...65535).contains(browser.debuggingPort) else {
            return "browser debugging port must be between 1 and 65535"
        }
        guard BrowserUseLoopbackPolicy.allowsHost(browser.debuggingHost) else {
            return "browser debugging host must be localhost, 127.0.0.1, or [::1]"
        }
        if let browserCDPProblem = browserCDPProblem(browser.browserCDP) {
            return browserCDPProblem
        }
        if let proxyServerProblem = proxyServerProblem(settings.runtime.proxyServer) {
            return proxyServerProblem
        }
        guard (1...16_384).contains(browser.resolutionWidth),
              (1...16_384).contains(browser.resolutionHeight) else {
            return "browser resolution must be between 1 and 16384 pixels per side"
        }
        guard (1...128).contains(browser.resolutionDepth) else {
            return "browser resolution depth must be between 1 and 128"
        }
        return nil
    }

    private static func nonSecretEnvironmentValueProblem(_ pairs: [BrowserUseEnvironmentPair]) -> String? {
        for pair in pairs {
            if pair.value.utf8.count > maxEnvironmentValueBytes {
                return "\(pair.name) exceeds \(maxEnvironmentValueBytes) bytes"
            }
            if pair.value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
                return "\(pair.name) must not include control characters"
            }
            if pair.value != pair.value.trimmingCharacters(in: .whitespacesAndNewlines) {
                return "\(pair.name) must not include leading or trailing whitespace"
            }
        }
        return nil
    }

    private static func providerEndpointProblem(_ providers: BrowserUseProviderSettings) -> String? {
        for (name, value) in [
            ("OPENAI_ENDPOINT", providers.openAIEndpoint),
            ("ANTHROPIC_ENDPOINT", providers.anthropicEndpoint),
            ("GOOGLE_ENDPOINT", providers.googleEndpoint),
            ("AZURE_OPENAI_ENDPOINT", providers.azureOpenAIEndpoint),
            ("DEEPSEEK_ENDPOINT", providers.deepSeekEndpoint),
            ("MISTRAL_ENDPOINT", providers.mistralEndpoint),
            ("OLLAMA_ENDPOINT", providers.ollamaEndpoint),
            ("ALIBABA_ENDPOINT", providers.alibabaEndpoint),
            ("MODELSCOPE_ENDPOINT", providers.modelScopeEndpoint),
            ("MOONSHOT_ENDPOINT", providers.moonshotEndpoint),
            ("UNBOUND_ENDPOINT", providers.unboundEndpoint),
            ("SILICONFLOW_ENDPOINT", providers.siliconFlowEndpoint),
            ("IBM_ENDPOINT", providers.ibmEndpoint),
            ("GROK_ENDPOINT", providers.grokEndpoint),
        ] {
            if let problem = httpEndpointProblem(name: name, rawValue: value) {
                return problem
            }
        }
        return nil
    }

    private static func cloudEndpointProblem(_ runtime: BrowserUseRuntimeSettings) -> String? {
        for (name, value) in [
            ("BROWSER_USE_CLOUD_API_URL", runtime.cloudAPIURL),
            ("BROWSER_USE_CLOUD_UI_URL", runtime.cloudUIURL),
            ("BROWSER_USE_CLOUD_BASE_URL", runtime.cloudBaseURL),
        ] {
            if let problem = httpEndpointProblem(name: name, rawValue: value) {
                return problem
            }
        }
        return nil
    }

    private static func httpEndpointProblem(name: String, rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty else {
            return "\(name) must be an http or https URL"
        }
        if components.user != nil || components.password != nil {
            return "\(name) must not include username or password credentials"
        }
        if components.query != nil {
            return "\(name) must not include a URL query"
        }
        if components.fragment != nil {
            return "\(name) must not include a URL fragment"
        }
        return nil
    }

    private static func browserCDPProblem(_ rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https", "ws", "wss"].contains(scheme),
              let host = components.host else {
            return "browser CDP URL must be http, https, ws, or wss loopback URL"
        }
        guard BrowserUseLoopbackPolicy.allowsHost(host) else {
            return "browser CDP URL must point at localhost, 127.0.0.1, or [::1]"
        }
        if components.user != nil || components.password != nil {
            return "browser CDP URL must not include username or password credentials"
        }
        if components.query != nil {
            return "browser CDP URL must not include a URL query"
        }
        if components.fragment != nil {
            return "browser CDP URL must not include a URL fragment"
        }
        return nil
    }

    private static func proxyServerProblem(_ rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              allowedProxyServerSchemes.contains(scheme),
              let host = components.host,
              !host.isEmpty else {
            return "browser-use proxy server must be an http, https, socks4, socks5, or socks5h URL"
        }
        if components.user != nil || components.password != nil {
            return "browser-use proxy server must not include username or password credentials; use Keychain proxy bindings"
        }
        if !components.path.isEmpty, components.path != "/" {
            return "browser-use proxy server must not include a URL path"
        }
        if components.query != nil {
            return "browser-use proxy server must not include a URL query"
        }
        if components.fragment != nil {
            return "browser-use proxy server must not include a URL fragment"
        }
        return nil
    }
}

nonisolated enum BrowserUseSecretBinding: String, CaseIterable, Sendable, Hashable {
    case browserUseAPIKey = "BROWSER_USE_API_KEY"
    case openAIAPIKey = "OPENAI_API_KEY"
    case anthropicAPIKey = "ANTHROPIC_API_KEY"
    case googleAPIKey = "GOOGLE_API_KEY"
    case azureOpenAIAPIKey = "AZURE_OPENAI_API_KEY"
    case deepSeekAPIKey = "DEEPSEEK_API_KEY"
    case mistralAPIKey = "MISTRAL_API_KEY"
    case alibabaAPIKey = "ALIBABA_API_KEY"
    case modelScopeAPIKey = "MODELSCOPE_API_KEY"
    case moonshotAPIKey = "MOONSHOT_API_KEY"
    case unboundAPIKey = "UNBOUND_API_KEY"
    case siliconFlowAPIKey = "SiliconFLOW_API_KEY"
    case ibmAPIKey = "IBM_API_KEY"
    case ibmProjectID = "IBM_PROJECT_ID"
    case grokAPIKey = "GROK_API_KEY"
    case novitaAPIKey = "NOVITA_API_KEY"
    case awsAccessKeyID = "AWS_ACCESS_KEY_ID"
    case awsSecretAccessKey = "AWS_SECRET_ACCESS_KEY"
    case awsSessionToken = "AWS_SESSION_TOKEN"
    case proxyUsername = "BROWSER_USE_PROXY_USERNAME"
    case proxyPassword = "BROWSER_USE_PROXY_PASSWORD"
    case vncPassword = "VNC_PASSWORD"

    var environmentName: String {
        rawValue
    }

    var keychainKey: String {
        "browser_use_pro.env.\(rawValue)"
    }
}

nonisolated struct BrowserUseSecretStore: Sendable {
    static let maxSecretValueBytes = 4096

    private let loadValue: @Sendable (String) -> String?
    private let saveValue: @Sendable (String, String) -> Bool
    private let deleteValue: @Sendable (String) -> Void

    init(
        loadValue: @escaping @Sendable (String) -> String? = { Keychain.load(for: $0) },
        saveValue: @escaping @Sendable (String, String) -> Bool = { value, key in Keychain.save(value, for: key) },
        deleteValue: @escaping @Sendable (String) -> Void = { Keychain.delete(for: $0) }
    ) {
        self.loadValue = loadValue
        self.saveValue = saveValue
        self.deleteValue = deleteValue
    }

    func load(_ binding: BrowserUseSecretBinding) -> String? {
        guard let value = loadValue(binding.keychainKey),
              let sanitized = Self.sanitizedSecretValue(value) else {
            return nil
        }
        return sanitized
    }

    @discardableResult
    func save(_ value: String, for binding: BrowserUseSecretBinding) -> Bool {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            delete(binding)
            return true
        }
        guard Self.sanitizedSecretValue(value) != nil else {
            return false
        }
        return saveValue(value, binding.keychainKey)
    }

    func delete(_ binding: BrowserUseSecretBinding) {
        deleteValue(binding.keychainKey)
    }

    private static func sanitizedSecretValue(_ value: String) -> String? {
        guard value.utf8.count <= maxSecretValueBytes,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}

nonisolated struct BrowserUseSettingsStore: Sendable {
    static let maxSettingsBytes = 256 * 1024
    private static let maxPathDiagnosticLength = 160

    let settingsURL: URL

    init(settingsURL: URL = Self.defaultSettingsURL()) {
        self.settingsURL = settingsURL
    }

    static func defaultSettingsURL(
        fileManager: FileManager = .default,
        filePath: String = #filePath
    ) -> URL {
        if let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return applicationSupport
                .appendingPathComponent("Epistemos", isDirectory: true)
                .appendingPathComponent("BrowserUsePro", isDirectory: true)
                .appendingPathComponent("settings.json", isDirectory: false)
        }

        return URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("browser-use-settings.json", isDirectory: false)
    }

    func load() throws -> BrowserUseSettings {
        let directory = settingsURL.deletingLastPathComponent()
        let settingsPath = Self.settingsPathDescription(settingsURL)
        try Self.rejectSettingsSymlinkPath(at: directory, label: "directory")
        try Self.rejectSettingsSymlinkPath(at: settingsURL, label: "file")
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: settingsURL.path, isDirectory: &isDirectory) else {
            return .default
        }
        guard !isDirectory.boolValue else {
            throw BrowserUseSettingsStoreError.invalidFile(
                "browser-use settings file is a directory at \(settingsPath)"
            )
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: settingsURL.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw BrowserUseSettingsStoreError.invalidFile(
                "browser-use settings file must be a regular file at \(settingsPath)"
            )
        }
        guard let size = (attributes[.size] as? NSNumber)?.uint64Value else {
            throw BrowserUseSettingsStoreError.invalidFile(
                "browser-use settings file size is unavailable at \(settingsPath)"
            )
        }
        if size > UInt64(Self.maxSettingsBytes) {
            throw BrowserUseSettingsStoreError.invalidFile(
                "browser-use settings file exceeds \(Self.maxSettingsBytes) bytes"
            )
        }

        let data = try Self.readSettingsData(at: settingsURL)
        return try JSONDecoder().decode(BrowserUseSettings.self, from: data)
    }

    func save(_ settings: BrowserUseSettings) throws {
        let directory = settingsURL.deletingLastPathComponent()
        try Self.rejectSettingsSymlinkPath(at: directory, label: "directory")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.rejectSettingsSymlinkPath(at: directory, label: "directory")
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        guard data.count <= Self.maxSettingsBytes else {
            throw BrowserUseSettingsStoreError.invalidFile(
                "browser-use settings file exceeds \(Self.maxSettingsBytes) bytes"
            )
        }
        let temporaryURL = directory.appendingPathComponent("settings.\(UUID().uuidString).tmp", isDirectory: false)
        do {
            try Self.rejectSettingsSymlinkPath(at: temporaryURL, label: "temporary file")
            try Self.rejectSettingsSymlinkPath(at: settingsURL, label: "file")
            try Self.writeExclusiveSettingsData(data, to: temporaryURL)
            if FileManager.default.fileExists(atPath: settingsURL.path) {
                try Self.rejectSettingsSymlinkPath(at: settingsURL, label: "file")
                try FileManager.default.removeItem(at: settingsURL)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: settingsURL)
            try Self.rejectSettingsSymlinkPath(at: settingsURL, label: "file")
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settingsURL.path)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    private static func rejectSettingsSymlinkPath(at url: URL, label: String) throws {
        try rejectSettingsSymlink(at: url, label: label)
        if let component = BrowserUseSymlinkPathGuard.firstSymlinkComponent(in: url) {
            let componentPath = settingsPathDescription(component)
            throw BrowserUseSettingsStoreError.unsafePath(
                "browser-use settings \(label) path must not include symlink component \(componentPath)"
            )
        }
    }

    private static func rejectSettingsSymlink(at url: URL, label: String) throws {
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil {
            throw BrowserUseSettingsStoreError.unsafePath(
                "browser-use settings \(label) must not be a symlink"
            )
        }
    }

    private static func readSettingsData(at url: URL) throws -> Data {
        let settingsPath = settingsPathDescription(url)
        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            throw BrowserUseSettingsStoreError.unsafePath(
                "browser-use settings file could not be opened safely"
            )
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            throw BrowserUseSettingsStoreError.invalidFile(
                "browser-use settings file attributes unavailable at \(settingsPath)"
            )
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            throw BrowserUseSettingsStoreError.invalidFile(
                "browser-use settings file must be a regular file at \(settingsPath)"
            )
        }
        guard fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(Self.maxSettingsBytes) else {
            close(fd)
            throw BrowserUseSettingsStoreError.invalidFile(
                "browser-use settings file exceeds \(Self.maxSettingsBytes) bytes"
            )
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        let data = try handle.readToEnd() ?? Data()
        guard data.count <= Self.maxSettingsBytes else {
            throw BrowserUseSettingsStoreError.invalidFile(
                "browser-use settings file exceeds \(Self.maxSettingsBytes) bytes"
            )
        }
        return data
    }

    private static func writeExclusiveSettingsData(_ data: Data, to url: URL) throws {
        let fd = url.path.withCString { path in
            open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
        }
        guard fd >= 0 else {
            throw BrowserUseSettingsStoreError.unsafePath(
                "browser-use settings temporary file could not be created safely"
            )
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
    }

    private static func settingsPathDescription(_ url: URL) -> String {
        let filename = url.lastPathComponent.isEmpty ? "settings.json" : url.lastPathComponent
        guard filename.count > maxPathDiagnosticLength else {
            return filename
        }
        return String(filename.prefix(maxPathDiagnosticLength - 3)) + "..."
    }
}

nonisolated enum BrowserUseSettingsStoreError: Error, Equatable, LocalizedError {
    case unsafePath(String)
    case invalidFile(String)

    var errorDescription: String? {
        switch self {
        case .unsafePath(let message):
            return message
        case .invalidFile(let message):
            return message
        }
    }
}

nonisolated enum BrowserUseEnvironmentRenderer {
    static func pairs(
        settings: BrowserUseSettings,
        secretStore: BrowserUseSecretStore = BrowserUseSecretStore()
    ) -> [BrowserUseEnvironmentPair] {
        var pairs = settings.nonSecretEnvironmentPairs
        for binding in BrowserUseSecretBinding.allCases {
            if let secret = secretStore.load(binding) {
                pairs.append(.init(name: binding.environmentName, value: secret))
            }
        }
        return pairsWithCompatibilityAliases(pairs)
    }

    static func dictionary(
        settings: BrowserUseSettings,
        secretStore: BrowserUseSecretStore = BrowserUseSecretStore()
    ) -> [String: String] {
        dictionary(pairs(settings: settings, secretStore: secretStore))
    }

    static func dictionary(_ pairs: [BrowserUseEnvironmentPair]) -> [String: String] {
        var values: [String: String] = [:]
        for pair in pairsWithCompatibilityAliases(pairs) {
            values[pair.name] = pair.value
        }
        return values
    }

    static func render(
        settings: BrowserUseSettings,
        secretStore: BrowserUseSecretStore = BrowserUseSecretStore()
    ) -> String {
        render(pairs(settings: settings, secretStore: secretStore))
    }

    static func render(_ pairs: [BrowserUseEnvironmentPair]) -> String {
        pairsWithCompatibilityAliases(pairs)
            .map { "\($0.name)=\(literal(for: $0.value))" }
            .joined(separator: "\n") + "\n"
    }

    private static func pairsWithCompatibilityAliases(_ pairs: [BrowserUseEnvironmentPair]) -> [BrowserUseEnvironmentPair] {
        var output = pairs
        var valuesByName: [String: String] = [:]
        for pair in pairs {
            valuesByName[pair.name] = pair.value
        }

        func appendAlias(_ alias: String, from source: String) {
            guard valuesByName[alias] == nil, let value = valuesByName[source] else {
                return
            }
            valuesByName[alias] = value
            output.append(.init(name: alias, value: value))
        }

        appendAlias("AZURE_OPENAI_KEY", from: "AZURE_OPENAI_API_KEY")
        appendAlias("MISTRAL_BASE_URL", from: "MISTRAL_ENDPOINT")
        appendAlias("SILICONFLOW_API_KEY", from: "SiliconFLOW_API_KEY")
        appendAlias("SILICONFLOW_ENDPOINT", from: "SiliconFLOW_ENDPOINT")
        appendAlias("NO_PROXY", from: "BROWSER_USE_NO_PROXY")
        return output
    }

    private static func literal(for value: String) -> String {
        guard !value.isEmpty else { return "" }

        let unquotedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_./:@-")
        if value.unicodeScalars.allSatisfy({ unquotedCharacters.contains($0) }) {
            return value
        }

        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
