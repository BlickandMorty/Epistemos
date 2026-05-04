import Foundation

final class HermesProviderXPC: NSObject, ProviderXPCProtocol {
    private var provider = "local"

    func performAsk(_ request: Data, withReply reply: @escaping (Data?, Error?) -> Void) {
        // Non-authoritative: returns provider response bytes only; core app verifies provenance.
        let envelope = ["provider": provider, "classification": "Composite", "bytes": String(data: request, encoding: .utf8) ?? ""]
        let data = try? JSONSerialization.data(withJSONObject: envelope)
        reply(data, nil)
    }

    func setProvider(_ provider: String, withReply reply: @escaping (Bool) -> Void) {
        self.provider = provider
        reply(true)
    }
}
