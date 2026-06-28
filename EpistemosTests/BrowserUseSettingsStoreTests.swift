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
        #expect(!json.contains("OPENAI_API_KEY"))
        #expect(!json.contains("ANTHROPIC_API_KEY"))
        #expect(!json.contains("BROWSER_USE_API_KEY"))
        #expect(!json.contains("BROWSER_USE_PROXY_PASSWORD"))
        #expect(!json.contains("VNC_PASSWORD"))
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
