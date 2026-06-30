import Foundation
import Testing
@testable import Epistemos

@Suite("Plan 3 browser-use settings store")
struct BrowserUseSettingsStoreTests {
    @Test("defaults render privacy-first browser-use environment")
    func defaultsRenderPrivacyFirstEnvironment() {
        let environment = BrowserUseEnvironmentRenderer.render(
            settings: .default,
            secretStore: BrowserUseSecretStore(loadValue: { _ in nil })
        )

        #expect(environment.contains("DEFAULT_LLM=openai\n"))
        #expect(environment.contains("ANONYMIZED_TELEMETRY=false\n"))
        #expect(environment.contains("BROWSER_USE_CLOUD_SYNC=false\n"))
        #expect(environment.contains("BROWSER_USE_VERSION_CHECK=false\n"))
        #expect(environment.contains("BROWSER_DEBUGGING_HOST=localhost\n"))
        #expect(environment.contains("BROWSER_DEBUGGING_PORT=9222\n"))
        #expect(environment.contains("RESOLUTION=1920x1080x24\n"))
        #expect(environment.contains("BROWSER_USE_PROXY_URL=\n"))
        #expect(environment.contains("BROWSER_USE_EXECUTABLE_PATH=\n"))
        #expect(!environment.contains("OPENAI_API_KEY="))
        #expect(!environment.contains("BROWSER_USE_PROXY_PASSWORD="))
    }

    @Test("renderer appends non-empty Keychain-backed secrets")
    func rendererAppendsNonEmptySecrets() {
        let secrets = [
            BrowserUseSecretBinding.openAIAPIKey.keychainKey: "sk-test",
            BrowserUseSecretBinding.proxyPassword.keychainKey: "  ",
            BrowserUseSecretBinding.vncPassword.keychainKey: "vnc secret",
        ]
        let store = BrowserUseSecretStore(loadValue: { secrets[$0] })
        let environment = BrowserUseEnvironmentRenderer.render(settings: .default, secretStore: store)
        let dictionary = BrowserUseEnvironmentRenderer.dictionary(settings: .default, secretStore: store)

        #expect(environment.contains("OPENAI_API_KEY=sk-test\n"))
        #expect(environment.contains("VNC_PASSWORD=\"vnc secret\"\n"))
        #expect(!environment.contains("BROWSER_USE_PROXY_PASSWORD="))
        #expect(dictionary["OPENAI_API_KEY"] == "sk-test")
        #expect(dictionary["VNC_PASSWORD"] == "vnc secret")
        #expect(dictionary["BROWSER_USE_PROXY_PASSWORD"] == nil)
    }

    @Test("renderer escapes CRLF in quoted environment values")
    func rendererEscapesCRLFInQuotedEnvironmentValues() {
        let environment = BrowserUseEnvironmentRenderer.render([
            BrowserUseEnvironmentPair(name: "MULTILINE_SECRET", value: "first\r\nsecond"),
        ])

        #expect(environment.contains(#"MULTILINE_SECRET="first\r\nsecond""#))
        #expect(!environment.contains("first\r\nsecond"))
    }

    @Test("settings validation keeps browser debugging and CDP loopback-only")
    func settingsValidationKeepsBrowserDebuggingAndCDPLoopbackOnly() {
        var allowed = BrowserUseSettings.default
        allowed.browser.debuggingHost = "[::1]"
        allowed.browser.browserCDP = "ws://127.0.0.1:9222/devtools/browser/session"
        #expect(BrowserUseSettingsValidation.problem(in: allowed) == nil)

        let rejected: [((inout BrowserUseSettings) -> Void, String)] = [
            ({ (settings: inout BrowserUseSettings) in
                settings.browser.debuggingHost = "0.0.0.0"
            }, "browser debugging host"),
            ({ (settings: inout BrowserUseSettings) in
                settings.browser.browserCDP = "ws://example.com:9222/devtools/browser/session"
            }, "browser CDP URL must point"),
            ({ (settings: inout BrowserUseSettings) in
                settings.browser.browserCDP = "ws://user:pass@127.0.0.1:9222/devtools/browser/session"
            }, "username or password"),
            ({ (settings: inout BrowserUseSettings) in
                settings.browser.browserCDP = "ws://127.0.0.1:9222/devtools/browser/session?token=secret"
            }, "URL query"),
            ({ (settings: inout BrowserUseSettings) in
                settings.browser.browserCDP = "ws://127.0.0.1:9222/devtools/browser/session#token"
            }, "URL fragment"),
        ]
        for (mutate, expected) in rejected {
            var settings = BrowserUseSettings.default
            mutate(&settings)
            #expect(BrowserUseSettingsValidation.problem(in: settings)?.contains(expected) == true)
        }
    }

    @Test("settings validation keeps proxy credentials out of non-secret proxy URLs")
    func settingsValidationKeepsProxyCredentialsOutOfNonSecretProxyURLs() {
        for proxyServer in [
            "",
            "http://proxy.example.com:8080",
            "https://proxy.example.com",
            "socks5://127.0.0.1:9050",
            "socks5h://proxy.example.com:9050/",
        ] {
            var settings = BrowserUseSettings.default
            settings.runtime.proxyServer = proxyServer
            #expect(BrowserUseSettingsValidation.problem(in: settings) == nil)
        }

        let rejected: [(String, String)] = [
            ("http://user:pass@proxy.example.com:8080", "username or password"),
            ("http://proxy.example.com:8080/private/path", "URL path"),
            ("http://proxy.example.com:8080?token=secret", "URL query"),
            ("http://proxy.example.com:8080#token", "URL fragment"),
            ("ftp://proxy.example.com:21", "http, https, socks4"),
            ("proxy.example.com:8080", "http, https, socks4"),
        ]
        for (proxyServer, expected) in rejected {
            var settings = BrowserUseSettings.default
            settings.runtime.proxyServer = proxyServer
            #expect(BrowserUseSettingsValidation.problem(in: settings)?.contains(expected) == true)
        }
    }

    @Test("secret store saves values by environment-key binding")
    func secretStoreSavesValuesByEnvironmentKeyBinding() {
        let harness = SecretHarness()
        let store = BrowserUseSecretStore(
            loadValue: { harness.load($0) },
            saveValue: { value, key in harness.save(value, for: key) },
            deleteValue: { harness.delete($0) }
        )

        #expect(store.save("sk-live", for: .openAIAPIKey))
        #expect(harness.savedValue(for: BrowserUseSecretBinding.openAIAPIKey.keychainKey) == "sk-live")

        #expect(store.save("   ", for: .openAIAPIKey))
        #expect(harness.deletedKeys == [BrowserUseSecretBinding.openAIAPIKey.keychainKey])
    }

    @Test("settings store round-trips non-secret JSON only")
    func settingsStoreRoundTripsNonSecretJSONOnly() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-settings-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("settings.json", isDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        var settings = BrowserUseSettings.default
        settings.providers.defaultLLM = "anthropic"
        settings.browser.debuggingPort = 9333
        settings.runtime.proxyServer = "http://proxy.example.com:8080"

        let store = BrowserUseSettingsStore(settingsURL: url)
        try store.save(settings)

        let loaded = try store.load()
        #expect(loaded == settings)

        let json = try String(contentsOf: url, encoding: .utf8)
        let directoryMode = try mode(for: directory)
        let fileMode = try mode(for: url)
        #expect(directoryMode == 0o700)
        #expect(fileMode == 0o600)
        #expect(!json.contains("OPENAI_API_KEY"))
        #expect(!json.contains("ANTHROPIC_API_KEY"))
        #expect(!json.contains("BROWSER_USE_API_KEY"))
        #expect(!json.contains("BROWSER_USE_PROXY_PASSWORD"))
        #expect(!json.contains("VNC_PASSWORD"))
    }

    @Test("settings store rejects oversized JSON before loading")
    func settingsStoreRejectsOversizedJSONBeforeLoading() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-settings-huge-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("settings.json", isDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: UInt8(ascii: "{"), count: BrowserUseSettingsStore.maxSettingsBytes + 1)
            .write(to: url, options: .atomic)

        do {
            _ = try BrowserUseSettingsStore(settingsURL: url).load()
            Issue.record("Expected oversized browser-use settings JSON to be rejected")
        } catch let error as BrowserUseSettingsStoreError {
            #expect(error.errorDescription?.contains("exceeds \(BrowserUseSettingsStore.maxSettingsBytes) bytes") == true)
        }
    }

    @Test("settings store rejects sparse JSON whose size overflows Int32")
    func settingsStoreRejectsSparseJSONSizeOverflowBeforeLoading() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-settings-sparse-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("settings.json", isDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #expect(FileManager.default.createFile(atPath: url.path, contents: Data()))
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: UInt64(Int32.max) + 1)

        do {
            _ = try BrowserUseSettingsStore(settingsURL: url).load()
            Issue.record("Expected sparse oversized browser-use settings JSON to be rejected")
        } catch let error as BrowserUseSettingsStoreError {
            #expect(error.errorDescription?.contains("exceeds \(BrowserUseSettingsStore.maxSettingsBytes) bytes") == true)
        }
    }

    @Test("settings store rejects non-regular JSON paths before loading")
    func settingsStoreRejectsNonRegularJSONPathsBeforeLoading() throws {
        let url = URL(fileURLWithPath: "/dev/null", isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            _ = try BrowserUseSettingsStore(settingsURL: url).load()
            Issue.record("Expected non-regular browser-use settings JSON to be rejected")
        } catch let error as BrowserUseSettingsStoreError {
            #expect(error.errorDescription?.contains("settings file must be a regular file") == true)
        }
    }

    @Test("settings store rejects symlinked JSON paths before reading or writing")
    func settingsStoreRejectsSymlinkedJSONPathsBeforeReadingOrWriting() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-settings-symlink-\(UUID().uuidString)", isDirectory: true)
        let realDirectory = root.appendingPathComponent("real", isDirectory: true)
        let symlinkDirectory = root.appendingPathComponent("settings-link", isDirectory: true)
        let safeDirectory = root.appendingPathComponent("safe", isDirectory: true)
        let outsideFile = root.appendingPathComponent("outside.json", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: safeDirectory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: symlinkDirectory, withDestinationURL: realDirectory)
        try Data("{\"outside\":true}\n".utf8).write(to: outsideFile)

        do {
            try BrowserUseSettingsStore(
                settingsURL: symlinkDirectory.appendingPathComponent("settings.json", isDirectory: false)
            ).save(.default)
            Issue.record("Expected symlinked browser-use settings directory to be rejected")
        } catch let error as BrowserUseSettingsStoreError {
            #expect(error.errorDescription?.contains("settings directory must not be a symlink") == true)
        }

        do {
            _ = try BrowserUseSettingsStore(
                settingsURL: symlinkDirectory.appendingPathComponent("settings.json", isDirectory: false)
            ).load()
            Issue.record("Expected symlinked browser-use settings directory to be rejected on read")
        } catch let error as BrowserUseSettingsStoreError {
            #expect(error.errorDescription?.contains("settings directory must not be a symlink") == true)
        }

        do {
            try BrowserUseSettingsStore(
                settingsURL: symlinkDirectory
                    .appendingPathComponent("write-through", isDirectory: true)
                    .appendingPathComponent("settings.json", isDirectory: false)
            ).save(.default)
            Issue.record("Expected browser-use settings path below symlinked parent to be rejected")
        } catch let error as BrowserUseSettingsStoreError {
            #expect(error.errorDescription?.contains("settings directory path must not include symlink component") == true)
        }
        #expect(!FileManager.default.fileExists(
            atPath: realDirectory
                .appendingPathComponent("write-through", isDirectory: true)
                .appendingPathComponent("settings.json", isDirectory: false)
                .path
        ))

        let readThroughDirectory = realDirectory.appendingPathComponent("read-through", isDirectory: true)
        try FileManager.default.createDirectory(at: readThroughDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(BrowserUseSettings.default).write(
            to: readThroughDirectory.appendingPathComponent("settings.json", isDirectory: false)
        )
        do {
            _ = try BrowserUseSettingsStore(
                settingsURL: symlinkDirectory
                    .appendingPathComponent("read-through", isDirectory: true)
                    .appendingPathComponent("settings.json", isDirectory: false)
            ).load()
            Issue.record("Expected browser-use settings read below symlinked parent to be rejected")
        } catch let error as BrowserUseSettingsStoreError {
            #expect(error.errorDescription?.contains("settings directory path must not include symlink component") == true)
        }

        let symlinkFile = safeDirectory.appendingPathComponent("settings.json", isDirectory: false)
        try FileManager.default.createSymbolicLink(at: symlinkFile, withDestinationURL: outsideFile)
        do {
            try BrowserUseSettingsStore(settingsURL: symlinkFile).save(.default)
            Issue.record("Expected symlinked browser-use settings file to be rejected")
        } catch let error as BrowserUseSettingsStoreError {
            #expect(error.errorDescription?.contains("settings file must not be a symlink") == true)
        }

        do {
            _ = try BrowserUseSettingsStore(settingsURL: symlinkFile).load()
            Issue.record("Expected symlinked browser-use settings file to be rejected on read")
        } catch let error as BrowserUseSettingsStoreError {
            #expect(error.errorDescription?.contains("settings file must not be a symlink") == true)
        }

        let danglingSymlink = safeDirectory.appendingPathComponent("dangling-settings.json", isDirectory: false)
        try FileManager.default.createSymbolicLink(
            at: danglingSymlink,
            withDestinationURL: root.appendingPathComponent("missing-outside.json", isDirectory: false)
        )
        do {
            _ = try BrowserUseSettingsStore(settingsURL: danglingSymlink).load()
            Issue.record("Expected dangling symlinked browser-use settings file to be rejected on read")
        } catch let error as BrowserUseSettingsStoreError {
            #expect(error.errorDescription?.contains("settings file must not be a symlink") == true)
        }

        let outsideContents = try String(contentsOf: outsideFile, encoding: .utf8)
        #expect(outsideContents == "{\"outside\":true}\n")
    }

    @Test("settings store source keeps bounded no-follow JSON reads")
    func settingsStoreSourceKeepsBoundedNoFollowJSONReads() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/BrowserUsePro/BrowserUseSettingsStore.swift")
        for required in [
            "readSettingsData",
            "open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)",
            "fstat(fd",
            "readToEnd()",
            "data.count <= Self.maxSettingsBytes",
        ] {
            #expect(source.contains(required), "Missing browser-use settings read marker: \(required)")
        }
        #expect(!source.contains("Data(contentsOf: settingsURL)"))
    }

    private func mode(for url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        return mode.intValue
    }
}

private final class SecretHarness: @unchecked Sendable {
    nonisolated(unsafe) private var saved: [String: String] = [:]
    nonisolated(unsafe) private var deleted: [String] = []

    nonisolated func load(_ key: String) -> String? {
        saved[key]
    }

    nonisolated func save(_ value: String, for key: String) -> Bool {
        saved[key] = value
        return true
    }

    nonisolated func delete(_ key: String) {
        deleted.append(key)
    }

    nonisolated func savedValue(for key: String) -> String? {
        saved[key]
    }

    nonisolated var deletedKeys: [String] {
        deleted
    }
}
