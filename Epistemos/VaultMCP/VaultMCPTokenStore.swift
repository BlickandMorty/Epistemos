import Foundation

nonisolated struct VaultMCPTokenStore {
    static let keychainKey = "vault_mcp_bearer"

    private static let minimumTokenLength = 24
    private static let maximumTokenLength = 256

    private let key: String
    private let load: @Sendable (String) -> String?
    private let save: @Sendable (String, String) -> Bool
    private let makeToken: @Sendable () -> String

    init(
        key: String = Self.keychainKey,
        load: @escaping @Sendable (String) -> String? = { Keychain.load(for: $0) },
        save: @escaping @Sendable (String, String) -> Bool = { value, key in Keychain.save(value, for: key) },
        makeToken: @escaping @Sendable () -> String = { WorkNativeMCPServer.randomToken() }
    ) {
        self.key = key
        self.load = load
        self.save = save
        self.makeToken = makeToken
    }

    func currentToken() -> String {
        if let stored = Self.usableToken(load(key)) {
            return stored
        }
        let token = mintToken()
        _ = save(token, key)
        return token
    }

    func rotateToken() -> String {
        let token = mintToken()
        _ = save(token, key)
        return token
    }

    static func masked(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return trimmed.isEmpty ? "" : "****" }
        return "\(trimmed.prefix(4))...\(trimmed.suffix(4))"
    }

    private func mintToken() -> String {
        Self.usableToken(makeToken()) ?? Self.uuidFallbackToken()
    }

    private static func usableToken(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.count >= minimumTokenLength,
              trimmed.count <= maximumTokenLength,
              trimmed.unicodeScalars.allSatisfy(isTokenScalar) else {
            return nil
        }
        return trimmed
    }

    private static func isTokenScalar(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value > 0x20 && scalar.value < 0x7f
    }

    private static func uuidFallbackToken() -> String {
        (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
    }
}
