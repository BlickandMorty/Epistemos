import Foundation

extension InferenceState {
    func routeProfiles() -> [RouteProfile] {
        RuntimeRouter.defaultRouteProfiles()
    }
}
