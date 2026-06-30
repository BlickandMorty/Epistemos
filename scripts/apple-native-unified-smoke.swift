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

        let defaultRouter = GooseSurfaceRouter(environment: [:], userDefaults: freshRouterDefaults("default"))
        for route in GooseSurfaceRoute.allCases {
            require(defaultRouter.presentation(for: route) == .web, "Goose route \(route.rawValue) should default to WebView")
        }
        let modelsRouter = GooseSurfaceRouter(
            environment: [GooseSurfaceRouter.environmentKey: "models"],
            userDefaults: freshRouterDefaults("models")
        )
        require(modelsRouter.presentation(for: .models) == .native, "explicit Models promotion should go native")
        let nonCapableRouter = GooseSurfaceRouter(
            environment: [GooseSurfaceRouter.environmentKey: "apps scheduler"],
            userDefaults: freshRouterDefaults("non-capable")
        )
        require(nonCapableRouter.presentation(for: .models) == .web, "non-capable route tokens should not promote anything")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let rootView = read("Epistemos/Agent/AgentSurfaceRootView.swift", root: root)
        let rail = read("Epistemos/Agent/AgentNavigationRailView.swift", root: root)
        let window = read("Epistemos/Agent/AgentSurfaceWindowController.swift", root: root)
        let app = read("Epistemos/App/EpistemosApp.swift", root: root)
        let gooseWeb = read("Epistemos/Goose/GooseWebSurfaceView.swift", root: root)
        let browserUse = read("Epistemos/BrowserUsePro/BrowserUseProGateStatus.swift", root: root)

        require(rootView.contains("GooseWebSurfaceView(theme: theme, route: selection.webRoute)"), "native frame must host routed Goose WebView")
        require(!rootView.contains("ChatView("), "native frame must not host native chat")
        require(rail.contains("case .hub: return \"/?\""), "rail should route hub to Goose web oracle")
        require(rail.contains("case .apps: return \"/apps\""), "rail should route apps to Goose web oracle")
        require(window.contains("Epistemos Goose Native Frame"), "window title should name Goose, not a second agent")
        require(app.contains("Epistemos Goose (Native Frame)"), "menu should name Goose native frame")
        require(!app.contains("Epistemos Agent (Native Frame)"), "menu must not expose a second Agent product")
        require(gooseWeb.contains("WebView(page)"), "Goose surface must remain a WebView-backed surface")
        require(gooseWeb.contains("GooseNativeModelsView(bridge: acpBridge)"), "Models is the one native promoted leaf")
        require(gooseWeb.contains("router.isNative(.models)"), "native Models must stay behind router promotion")
        require(browserUse.contains("cannot drive the native WKWebView Browser"), "browser-use must remain outside native WKWebView Browser")
        require(browserUse.contains("Launch remains user-initiated and separate from the native WKWebView Browser"), "browser-use must remain subordinate/separate")

        print("apple-native unified smoke OK: goose_frame_live=true webview_oracle=true native_chat=false browser_use_subordinate=true")
    }

    private static func freshRouterDefaults(_ name: String) -> UserDefaults {
        let suite = "AppleNativeUnifiedSmoke.router.\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private static func read(_ relativePath: String, root: URL) -> String {
        let url = root.appendingPathComponent(relativePath, isDirectory: false)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            fail("could not read \(relativePath)")
        }
        return text
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
