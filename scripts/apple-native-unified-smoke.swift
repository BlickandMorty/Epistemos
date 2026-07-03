import Foundation

@main
struct AppleNativeUnifiedSmoke {
    @MainActor
    static func main() {
        let suite = "AppleNativeUnifiedSmoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        require(AgentSurface.isEnabled(environment: [:], userDefaults: defaults), "native Goose frame should be live by default")
        require(!AgentSurface.isEnabled(environment: [AgentSurface.environmentKey: "0"], userDefaults: defaults), "env override should disable frame")
        require(AgentSurface.isEnabled(environment: [AgentSurface.environmentKey: "on"], userDefaults: defaults), "env override should enable frame")

        defaults.set(false, forKey: AgentSurface.userDefaultsKey)
        require(!AgentSurface.isEnabled(environment: [:], userDefaults: defaults), "UserDefaults false should disable frame")
        defaults.set(true, forKey: AgentSurface.userDefaultsKey)
        require(AgentSurface.isEnabled(environment: [:], userDefaults: defaults), "UserDefaults true should enable frame")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let rootView = read("Epistemos/Agent/AgentSurfaceRootView.swift", root: root)
        let window = read("Epistemos/Agent/AgentSurfaceWindowController.swift", root: root)
        let fallbackWindow = read("Epistemos/Goose/GooseSurfaceWindowController.swift", root: root)
        let app = read("Epistemos/App/EpistemosApp.swift", root: root)
        let gooseWeb = read("Epistemos/Goose/GooseWebSurfaceView.swift", root: root)

        require(!exists("Epistemos/Goose/GooseSurfaceRouter.swift", root: root), "Goose must not keep a native route router")
        require(!exists("Epistemos/Goose/GooseNativeModelsView.swift", root: root), "Goose must not keep a native Models route")
        require(rootView.contains("GooseWebSurfaceView(theme: theme)"), "native frame must host Goose WebView directly")
        require(!rootView.contains("ChatView("), "native frame must not host native chat")
        require(!rootView.contains("AgentNavigationRailView("), "Goose window must not stack the native rail")
        require(!rootView.contains("AgentLauncherPanelView("), "Goose window must not stack the native launcher panel")
        require(window.contains("Epistemos Goose"), "window title should name Goose, not a second agent")
        require(window.contains("window.titleVisibility = .hidden"), "Goose frame must hide native title chrome")
        require(window.contains("window.backgroundColor = .clear"), "Goose frame must not paint a box behind the WebView")
        require(window.contains("window.contentView = host"), "Goose frame must mount the WebView full-bleed")
        require(!window.contains("WindowThemeStyler.themedContentView"), "Goose frame must not wrap the WebView in a themed box")
        require(fallbackWindow.contains("window.titleVisibility = .hidden"), "fallback Goose frame must hide native title chrome")
        require(fallbackWindow.contains("window.contentView = host"), "fallback Goose frame must mount the WebView full-bleed")
        require(!fallbackWindow.contains("WindowThemeStyler.themedContentView"), "fallback Goose frame must not wrap the WebView in a themed box")
        require(app.contains("Epistemos Goose"), "menu should name Goose")
        require(!app.contains("Epistemos Agent (Native Frame)"), "menu must not expose a second Agent product")
        require(gooseWeb.contains("WebView(page)"), "Goose surface must remain a WebView-backed surface")
        require(!gooseWeb.contains("GooseNativeModelsView(bridge: acpBridge)"), "Goose window must not promote Models to native")
        require(!gooseWeb.contains("router.isNative(.models)"), "Goose window must not keep native route promotion")
        require(!gooseWeb.contains("GooseSurfaceRouter()"), "Goose window must not instantiate a native route router")

        print("apple-native unified smoke OK: goose_frame_live=true webview_oracle=true native_chat=false")
    }

    private static func read(_ relativePath: String, root: URL) -> String {
        let url = root.appendingPathComponent(relativePath, isDirectory: false)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            fail("could not read \(relativePath)")
        }
        return text
    }

    private static func exists(_ relativePath: String, root: URL) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath, isDirectory: false).path)
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("apple-native unified smoke failed: \(message)\n".utf8))
        Foundation.exit(1)
    }
}
