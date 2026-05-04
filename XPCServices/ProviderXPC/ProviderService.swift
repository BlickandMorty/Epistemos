import Foundation

@objc(EpistemosProviderService)
final class ProviderService: NSObject, ProviderServiceProtocol {
    func classifySurface(_ surfaceName: String, withReply reply: @escaping (NSDictionary) -> Void) {
        reply(ProviderXPCSurfaceEnvelope.response(for: surfaceName))
    }
}

final class ProviderServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: ProviderServiceProtocol.self)
        connection.exportedObject = ProviderService()
        connection.resume()
        return true
    }
}
