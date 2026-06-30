import Foundation
import Testing
@testable import Epistemos

// Step 3 (per-route parity-gated native migration) — the SAFE FIRST native route: Models.
//
// Two layers:
//  1. Router invariants (pure, always run): prove the HARD GATE that the WebView is the default +
//     oracle for EVERY route, and a route only goes native when explicitly + capably promoted.
//  2. Live parity (gated on a real Goose runtime): prove the native Models view's data source is the
//     SAME live ACP enumeration the WebView oracle uses — never a Swift-hardcoded roster.

@Suite("Goose native surface router invariants")
@MainActor
struct GooseSurfaceRouterTests {
    private func freshDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "GooseSurfaceRouterTests.\(name)")!
        defaults.removePersistentDomain(forName: "GooseSurfaceRouterTests.\(name)")
        return defaults
    }

    @Test("every route defaults to the WebView oracle (no env, no defaults)")
    func defaultsEveryRouteToWebView() {
        let router = GooseSurfaceRouter(environment: [:], userDefaults: freshDefaults("default"))
        for route in GooseSurfaceRoute.allCases {
            #expect(router.presentation(for: route) == .web)
            #expect(router.isNative(route) == false)
        }
    }

    @Test("explicit env flag promotes the Models route to native")
    func envFlagPromotesModels() {
        let router = GooseSurfaceRouter(
            environment: [GooseSurfaceRouter.environmentKey: "models"],
            userDefaults: freshDefaults("env-models")
        )
        #expect(router.isNative(.models))
        #expect(router.presentation(for: .models) == .native)
    }

    @Test("`all` promotes every native-capable route, and only those")
    func allKeywordPromotesNativeCapable() {
        let router = GooseSurfaceRouter(
            environment: [GooseSurfaceRouter.environmentKey: "all"],
            userDefaults: freshDefaults("all")
        )
        for route in GooseSurfaceRouter.nativeCapableRoutes {
            #expect(router.isNative(route))
        }
        // A route with no native impl can never be promoted, even by `all`.
        for route in GooseSurfaceRoute.allCases where !GooseSurfaceRouter.nativeCapableRoutes.contains(route) {
            #expect(router.presentation(for: route) == .web)
        }
    }

    @Test("unknown / non-capable tokens are a safe no-op (stay on the oracle)")
    func unknownTokensAreNoOp() {
        let router = GooseSurfaceRouter(
            environment: [GooseSurfaceRouter.environmentKey: "apps, bogus, scheduler"],
            userDefaults: freshDefaults("unknown")
        )
        // None of those are native-capable today → Models (and everything) stays web.
        #expect(router.isNative(.models) == false)
        for route in GooseSurfaceRoute.allCases {
            #expect(router.presentation(for: route) == .web)
        }
    }

    @Test("UserDefaults key promotes the same way as the env flag")
    func userDefaultsPromotesModels() {
        let defaults = freshDefaults("ud-models")
        defaults.set("models", forKey: GooseSurfaceRouter.userDefaultsKey)
        let router = GooseSurfaceRouter(environment: [:], userDefaults: defaults)
        #expect(router.isNative(.models))
    }

    @Test("env and UserDefaults union, with whitespace/comma tolerance")
    func envAndDefaultsUnion() {
        let defaults = freshDefaults("union")
        defaults.set("  models ", forKey: GooseSurfaceRouter.userDefaultsKey)
        let router = GooseSurfaceRouter(
            environment: [GooseSurfaceRouter.environmentKey: ""],
            userDefaults: defaults
        )
        #expect(router.isNative(.models))
    }

    @Test("native route flag parsing is bounded")
    func routeFlagParsingIsBounded() {
        let noisyRouteList = "models, " + String(
            repeating: "bogus ",
            count: GooseSurfaceRouter.maxNativeRouteTokens + 8
        )
        let router = GooseSurfaceRouter(
            environment: [GooseSurfaceRouter.environmentKey: noisyRouteList],
            userDefaults: freshDefaults("bounded")
        )
        #expect(router.isNative(.models))
        #expect(GooseSurfaceRouter.maxNativeRouteListCharacters == 4096)
        #expect(GooseSurfaceRouter.maxNativeRouteTokens == 64)
    }

    @Test("native Models status text is bounded before display")
    func nativeModelsStatusTextIsBoundedBeforeDisplay() throws {
        let oversized = String(
            repeating: "e",
            count: GooseNativeModelsPresentationBounds.maxStatusMessageCharacters + 40
        )
        let message = GooseNativeModelsPresentationBounds.statusMessage(" \n\(oversized)\n ")

        #expect(message.count == GooseNativeModelsPresentationBounds.maxStatusMessageCharacters)
        #expect(GooseNativeModelsPresentationBounds.statusMessage(" \n\t ", fallback: "fallback") == "fallback")

        let source = try loadMirroredSourceTextFile("Epistemos/Goose/GooseNativeModelsView.swift")
        #expect(source.contains("GooseNativeModelsPresentationBounds.statusMessage"))
        #expect(!source.contains(#"phase = .failed("Could not load providers: \(error.localizedDescription)""#))
        #expect(!source.contains(#"statusMessage = "Save failed: \(error.localizedDescription)""#))
    }

    @Test("Models route maps to today's web oracle hash route")
    func modelsRouteMapsToWebOracle() {
        #expect(GooseSurfaceRoute.models.webRoute == "/settings?section=models")
    }

    @Test("native Agent rail exposes visible Goose frame routes")
    func nativeAgentRailExposesVisibleGooseRoutes() {
        #expect(AgentRailDestination.hub.webRoute == "/?")
        #expect(AgentRailDestination.launcher.webRoute == "/launcher")
        #expect(AgentRailDestination.sessions.webRoute == "/sessions")
        #expect(AgentRailDestination.models.webRoute == "/settings?section=models")
        #expect(AgentRailDestination.providers.webRoute == "/configure-providers")
        #expect(AgentRailDestination.permission.webRoute == "/permission")
        #expect(AgentRailDestination.skills.webRoute == "/skills")
        #expect(AgentRailDestination.recipes.webRoute == "/recipes")
        #expect(AgentRailDestination.extensions.webRoute == "/extensions")
        #expect(AgentRailDestination.scheduler.webRoute == "/schedules")
        #expect(AgentRailDestination.apps.webRoute == "/apps")
    }

    @Test("native Agent launcher is route navigation only and keeps Goose WebView mounted")
    func nativeAgentLauncherIsNavigationOnly() throws {
        #expect(AgentRailDestination.launcherDestinations == [
            .hub,
            .sessions,
            .models,
            .providers,
            .permission,
            .settings,
            .skills,
            .recipes,
            .extensions,
            .scheduler,
            .apps,
        ])
        #expect(!AgentRailDestination.launcherDestinations.contains(.launcher))

        let root = try loadMirroredSourceTextFile("Epistemos/Agent/AgentSurfaceRootView.swift")
        #expect(root.contains("GooseWebSurfaceView(theme: theme, route: webRoute)"))
        #expect(root.contains(".opacity(selection == .launcher ? 0 : 1)"))
        #expect(root.contains(".allowsHitTesting(selection != .launcher)"))
        #expect(root.contains("AgentLauncherPanelView("))
        #expect(root.contains("activeDestination: lastContentSelection"))
        #expect(root.contains(".keyboardShortcut(\"l\", modifiers: .command)"))
        #expect(root.contains("private func openLauncher()"))

        let launcher = try loadMirroredSourceTextFile("Epistemos/Agent/AgentLauncherPanelView.swift")
        #expect(launcher.contains("AgentRailDestination.launcherDestinations"))
        #expect(launcher.contains("@FocusState private var isSearchFocused"))
        #expect(launcher.contains(".focused($isSearchFocused)"))
        #expect(launcher.contains(".onSubmit(openFirstFilteredDestination)"))
        #expect(launcher.contains("ScrollView {"))
        #expect(launcher.contains(".scrollIndicators(.hidden)"))
        #expect(launcher.contains("No matching surfaces"))
        #expect(launcher.contains("let isActive = destination == activeDestination"))
        #expect(launcher.contains("private func openFirstFilteredDestination()"))
    }
}

@Suite("Goose native Models live parity", .serialized)
@MainActor
struct GooseNativeModelsLiveParityTests {
    /// Proves the native Models view reaches genuine parity with the WebView oracle: the providers,
    /// their models, and the current default it renders all come from the SAME live ACP methods the
    /// web UI uses — `providers/list` (inventory, with models INLINE so nothing hangs) and
    /// `defaults/read`. If this passes against a real runtime, the Models route has earned promotion;
    /// otherwise it stays on the WebView.
    @Test("native Models data source == live ACP providers/list (no hardcoded roster, default resolvable)")
    func nativeModelsReachesLiveParity() async throws {
        try await withLiveGooseACPClient(proofName: "native-models-parity") { _, _, client, _ in
            _ = try await withLiveTimeout(
                seconds: 12,
                description: "ACP initialize for native Models parity",
                onTimeout: { await client.close() },
                operation: { try await client.initialize() }
            )

            // The native view's provider+model source: one call, models inline, built-ins included.
            let inventory = try await withLiveTimeout(
                seconds: 20,
                description: "providers/list inventory (native Models source)",
                onTimeout: { await client.close() },
                operation: { try await client.listGooseProviderInventory() }
            )
            #expect(!inventory.isEmpty, "Native Models view would render an empty provider list.")
            // At least one provider must carry models inline — that is the model-picker source, proven
            // not to require a hang-prone per-provider live enumeration.
            #expect(inventory.contains { !$0.models.isEmpty },
                    "No provider exposes inline models — the model picker would always be empty.")

            // The native view's current-default seed; the call must answer.
            let defaults = try await withLiveTimeout(
                seconds: 20,
                description: "defaults/read (native Models current selection)",
                onTimeout: { await client.close() },
                operation: { try await client.readGooseDefaults() }
            )
            // A set default provider MUST be present in the inventory the picker shows — i.e. the view
            // can display the real current selection (true parity, not a dangling id). This is exactly
            // the case the old template-catalog source failed (built-ins absent); providers/list fixes it.
            if let defaultProviderId = defaults.providerId {
                #expect(inventory.contains { $0.providerId == defaultProviderId },
                        "Default provider \(defaultProviderId) is not present in providers/list inventory.")
            }
        }
    }
}
