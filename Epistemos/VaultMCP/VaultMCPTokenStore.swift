import Foundation

nonisolated struct VaultMCPTokenStore {
    static let keychainKey = "vault_mcp_bearer"

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
        if let stored = load(key)?.trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty {
            return stored
        }
        let token = makeToken()
        _ = save(token, key)
        return token
    }

    func rotateToken() -> String {
        let token = makeToken()
        _ = save(token, key)
        return token
    }

    static func masked(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return trimmed.isEmpty ? "" : "****" }
        return "\(trimmed.prefix(4))...\(trimmed.suffix(4))"
    }
}
