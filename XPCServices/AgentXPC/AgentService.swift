import Foundation

@objc(EpistemosAgentService)
final class AgentService: NSObject, AgentServiceProtocol {
    func parseCoreCommand(_ rawCommand: String, withReply reply: @escaping (NSDictionary) -> Void) {
        reply(AgentXPCCommandEnvelope.response(for: rawCommand))
    }
}

final class AgentServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: AgentServiceProtocol.self)
        connection.exportedObject = AgentService()
        connection.resume()
        return true
    }
}
