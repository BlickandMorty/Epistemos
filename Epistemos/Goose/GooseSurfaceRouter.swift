import Foundation

/// A Goose surface route. The embedded web SPA owns navigation via hash routes; on the Swift side
/// a route is just the stable key + the web hash path the WebView is pointed at. Step 3 of the
/// native-UI migration promotes routes one at a time: a route is served by a native SwiftUI view
/// ONLY when its parity test is green and it has been explicitly enabled — otherwise it stays on
/// the WebView, which remains the default AND the parity oracle for every route.
nonisolated enum GooseSurfaceRoute: String, CaseIterable, Sendable {
    /// Models / model-switch surface. Today's web oracle is `/settings?section=models`.
    case models

    // Future routes (auth, apps, sessions, recipes, skills, extensions, scheduler) are added here
    // as each gains a native view + a green parity test. Until then they are not even listed, so
    // there is no way to accidentally route them anywhere but the WebView.

    /// The web SPA hash route this surface corresponds to (the oracle the native view is gated
    /// against). Used to fall back to the WebView whenever the route is not promoted to native.
    var webRoute: String {
        switch self {
        case .models:
            return "/settings?section=models"
        }
    }
}

/// How a given route should be presented this launch.
nonisolated enum GooseSurfacePresentation: Equatable, Sendable {
    /// The existing reskinned-Goose WebView (DEFAULT for every route; the parity oracle).
    case web
    /// A native Epistemos SwiftUI implementation (only for promoted, native-capable routes).
    case native
}

/// Per-route native/web decision for the Goose surface.
///
/// HARD GATES this encodes (owner green-light 2026-06-29):
/// - The WebView is the DEFAULT + ORACLE for EVERY route. No route is native by default, so a
///   regression can never silently drop a feature — the WebView always backs it.
/// - A route resolves to `.native` ONLY when it is BOTH (a) native-capable — a native view exists
///   and its parity test is green — AND (b) explicitly enabled via `EPISTEMOS_GOOSE_NATIVE_ROUTES`
///   (env, comma/space-separated route keys, or the literal `all`) or the
///   `epistemos.goose.nativeRoutes` UserDefaults key. Flipping that flag is the single, explicit
///   promotion point; naming a route with no native impl is a safe no-op.
@MainActor
final class GooseSurfaceRouter {
    /// Routes that actually HAVE a native implementation whose parity has been demonstrated. A
    /// route absent here always resolves to `.web`, even if the flag names it — you cannot promote
    /// a route that has no native view to compare against the oracle.
    static let nativeCapableRoutes: Set<GooseSurfaceRoute> = [.models]

    /// UserDefaults key holding a comma/space-separated list of route keys to promote to native.
    static let userDefaultsKey = "epistemos.goose.nativeRoutes"

    /// Environment variable holding the same list (takes union with UserDefaults).
    static let environmentKey = "EPISTEMOS_GOOSE_NATIVE_ROUTES"
    static let maxNativeRouteListCharacters = 4096
    static let maxNativeRouteTokens = 64

    private let enabledRoutes: Set<GooseSurfaceRoute>

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard
    ) {
        var requested = Self.parse(environment[Self.environmentKey])
        if let stored = userDefaults.string(forKey: Self.userDefaultsKey) {
            requested.formUnion(Self.parse(stored))
        }
        // Intersect with the native-capable set: a route can only be promoted if a native view
        // exists for it. This is the structural guarantee that an unimplemented route can never be
        // pointed away from the WebView oracle.
        enabledRoutes = requested.intersection(Self.nativeCapableRoutes)
    }

    /// The presentation for a route this launch. WebView unless the route is promoted to native.
    func presentation(for route: GooseSurfaceRoute) -> GooseSurfacePresentation {
        enabledRoutes.contains(route) ? .native : .web
    }

    /// Convenience predicate: is this route served by the native SwiftUI view this launch?
    func isNative(_ route: GooseSurfaceRoute) -> Bool {
        presentation(for: route) == .native
    }

    /// Parse a comma/space-separated route list. `all` promotes every native-capable route. Unknown
    /// tokens are ignored (forward-compatible: naming a future route before it exists is harmless).
    private static func parse(_ raw: String?) -> Set<GooseSurfaceRoute> {
        guard let raw, !raw.isEmpty else { return [] }
        let boundedRaw = String(raw.prefix(maxNativeRouteListCharacters))
        let tokens = boundedRaw
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .prefix(maxNativeRouteTokens)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if tokens.contains("all") {
            return nativeCapableRoutes
        }
        var routes: Set<GooseSurfaceRoute> = []
        for token in tokens {
            if let route = GooseSurfaceRoute(rawValue: token) {
                routes.insert(route)
            }
        }
        return routes
    }
}
