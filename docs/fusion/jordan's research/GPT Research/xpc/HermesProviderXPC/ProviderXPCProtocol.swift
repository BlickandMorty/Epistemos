import Foundation

@objc protocol ProviderXPCProtocol {
    func performAsk(_ request: Data, withReply reply: @escaping (Data?, Error?) -> Void)
    func setProvider(_ provider: String, withReply reply: @escaping (Bool) -> Void)
}
