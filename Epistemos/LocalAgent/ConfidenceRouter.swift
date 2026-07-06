import Foundation

/// Compatibility mirror for diagnostics that need route profiles without
/// owning the routing policy table. RuntimeRouter remains the source of truth.
public enum ConfidenceRouter {
    public static func routeProfiles() -> [RouteProfile] {
        RuntimeRouter.defaultRouteProfiles().map { $0 }
    }
}
