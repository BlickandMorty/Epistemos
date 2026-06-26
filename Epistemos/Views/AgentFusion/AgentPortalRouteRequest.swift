import Foundation

/// App-local route request for surfaces that should become portals into the
/// shared AgentClone/fusion session instead of owning a separate chat engine.
enum AgentPortalRouteRequest {
    static let portalContextUserInfoKey = "portalContext"

    static func post(_ portalContext: AgentPortalContextSnapshot) {
        NotificationCenter.default.post(
            name: .openAgentPortal,
            object: nil,
            userInfo: [portalContextUserInfoKey: portalContext]
        )
    }

    static func portalContext(from notification: Notification) -> AgentPortalContextSnapshot? {
        notification.userInfo?[portalContextUserInfoKey] as? AgentPortalContextSnapshot
    }
}

extension Notification.Name {
    static let openAgentPortal = Notification.Name("epistemos.agent.portal.open")
}
