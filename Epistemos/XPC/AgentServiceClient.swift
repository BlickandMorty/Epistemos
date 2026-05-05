import Foundation

final class AgentServiceClient {
    let serviceName: String

    init(serviceName: String = EpistemosXPCServiceNames.agentService) {
        self.serviceName = serviceName
    }

    func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(serviceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: AgentServiceProtocol.self)
        XPCTrust.applyCanonicalRequirement(to: connection, serviceName: serviceName)
        return connection
    }

    func parseCoreCommandInProcess(_ rawCommand: String) -> NSDictionary {
        AgentXPCCommandEnvelope.response(for: rawCommand)
    }
}
