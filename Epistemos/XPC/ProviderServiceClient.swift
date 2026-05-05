import Foundation

final class ProviderServiceClient {
    let serviceName: String

    init(serviceName: String = EpistemosXPCServiceNames.providerService) {
        self.serviceName = serviceName
    }

    func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(serviceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: ProviderServiceProtocol.self)
        XPCTrust.applyCanonicalRequirement(to: connection, serviceName: serviceName)
        return connection
    }

    func classifySurfaceInProcess(_ surfaceName: String) -> NSDictionary {
        ProviderXPCSurfaceEnvelope.response(for: surfaceName)
    }
}
