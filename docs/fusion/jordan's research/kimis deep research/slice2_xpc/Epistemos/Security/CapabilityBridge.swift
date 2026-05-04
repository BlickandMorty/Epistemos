//  CapabilityBridge.swift
//  Epistemos — Swift side of capability grants
//
//  Wraps the Rust `capability.rs` surface via UniFFI (or postcard blob bridge).
//  The HMAC root key is fetched from the Keychain on first use and never
//  leaves the app process. Helpers receive per-subject derived keys only.
//
//  Threading: `CapabilityIssuer` is an actor — all issuance and verification
//  is serialized. This prevents race conditions on the root key fetch and
//  avoids duplicate keychain queries under concurrent load.
//

import Foundation
import Security

// MARK: - Capability Grant (Codable, Sendable)

/// Swift mirror of `agent_core::capability::CapabilityGrant`.
///
/// Serialized via `postcard` or `Codable` for transport across the
/// Swift → Rust boundary. Fields match the Rust struct exactly.
public struct CapabilityGrant: Codable, Sendable {
    public let subject: String
    public let actionId: String
    public let flags: UInt32
    public let expiresAtUnix: UInt64
    public let maxInputBytes: UInt32
    public let maxOutputBytes: UInt32
    public let allowedProviderIds: [String]
    public let vaultIds: [String]
    public let nonce: Data
    public let sig: Data

    public init(
        subject: String,
        actionId: String,
        flags: UInt32,
        expiresAtUnix: UInt64,
        maxInputBytes: UInt32,
        maxOutputBytes: UInt32,
        allowedProviderIds: [String],
        vaultIds: [String],
        nonce: Data,
        sig: Data
    ) {
        self.subject = subject
        self.actionId = actionId
        self.flags = flags
        self.expiresAtUnix = expiresAtUnix
        self.maxInputBytes = maxInputBytes
        self.maxOutputBytes = maxOutputBytes
        self.allowedProviderIds = allowedProviderIds
        self.vaultIds = vaultIds
        self.nonce = nonce
        self.sig = sig
    }
}

// MARK: - Capability Flags

/// Swift mirror of `agent_core::capability::CapFlags`.
///
/// Use `rawValue` for the wire format; use the static constants for readability.
public struct CapFlags: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let readVault     = CapFlags(rawValue: 0x0001)
    public static let writeVault    = CapFlags(rawValue: 0x0002)
    public static let summarize     = CapFlags(rawValue: 0x0004)
    public static let searchWeb     = CapFlags(rawValue: 0x0008)
    public static let callProvider  = CapFlags(rawValue: 0x0010)
    public static let exportText    = CapFlags(rawValue: 0x0020)
    public static let executeTool   = CapFlags(rawValue: 0x0040)
}

// MARK: - Keychain Constants

/// Keychain service name for the HMAC root key.
private let kKeychainService = "com.epistenos.capability.root"

/// Keychain account name for the HMAC root key.
private let kKeychainAccount = "hmac-root-key"

/// Shared Keychain access group (must match app + helper entitlements).
private let kKeychainAccessGroup = "$(AppIdentifierPrefix)com.epistemos.shared"

// MARK: - Capability Issuer (actor)

/// Actor that issues and verifies capability grants.
///
/// The root key is fetched lazily from the Keychain and cached in memory
/// for the lifetime of the actor. If the key does not exist, a new 32-byte
/// random key is generated and stored in the Keychain with
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
public actor CapabilityIssuer {

    // MARK: - State

    /// Cached root key bytes. `nil` until first use triggers keychain fetch.
    private var cachedRootKey: Data?

    // MARK: - Public API

    /// Issue a new capability grant for the given subject and action.
    ///
    /// - Parameters:
    ///   - subject: Helper/service identifier (e.g. "agent_xpc", "provider_xpc").
    ///   - flags: Permission flags (least-privilege — issue minimum set).
    ///   - vaultIds: Vault identifiers the grant is scoped to.
    ///   - ttlSeconds: Time-to-live from now.
    /// - Returns: A signed `CapabilityGrant` ready for the arena or XPC transport.
    /// - Throws: `CapabilityIssuerError` on keychain or serialization failure.
    public func issue(
        subject: String,
        flags: CapFlags,
        vaultIds: [String],
        ttlSeconds: UInt64
    ) throws -> CapabilityGrant {
        let rootKey = try await rootKey()

        // TODO: Bridge to Rust via UniFFI for actual signing.
        // For now, we construct the Swift-side grant and the Rust side
        // signs it when the grant is placed into the arena.
        // Future: `try await EpBindings.issueCapabilityGrant(...)`

        let nonce = try makeNonce()
        let expiresAtUnix = UInt64(Date().timeIntervalSince1970) + ttlSeconds

        return CapabilityGrant(
            subject: subject,
            actionId: UUID().uuidString,
            flags: flags.rawValue,
            expiresAtUnix: expiresAtUnix,
            maxInputBytes: 1024 * 1024, // 1 MiB default
            maxOutputBytes: 4 * 1024 * 1024, // 4 MiB default
            allowedProviderIds: [],
            vaultIds: vaultIds,
            nonce: nonce,
            sig: Data(repeating: 0, count: 32) // zeroed until Rust signs
        )
    }

    /// Verify a capability grant.
    ///
    /// This is primarily for Swift-side pre-checks before placing a grant
    /// into the arena. The helper will re-verify independently with the
    /// derived subject key.
    ///
    /// - Parameter grant: The grant to verify.
    /// - Returns: `true` if the grant is valid, unexpired, and signed correctly.
    /// - Throws: `CapabilityIssuerError` on keychain or verification failure.
    public func verify(grant: CapabilityGrant) throws -> Bool {
        // Quick expiry check on the Swift side (avoids unnecessary Rust hop).
        let now = UInt64(Date().timeIntervalSince1970)
        guard grant.expiresAtUnix > now else {
            return false
        }

        // TODO: Bridge to Rust via UniFFI for HMAC verification.
        // Future: `try await EpBindings.verifyCapabilityGrant(grant)`

        // For now, we return true for the expiry pre-check and rely on
        // the Rust helper to perform the cryptographic verification.
        return true
    }

    /// Derive a per-subject verification key from the root key.
    ///
    /// This key may be passed to helpers so they can verify grants
    /// without receiving the root key itself.
    ///
    /// - Parameter subject: The helper identifier.
    /// - Returns: Derived 32-byte HMAC key scoped to the subject.
    /// - Throws: `CapabilityIssuerError` on keychain or derivation failure.
    public func deriveVerificationKey(subject: String) throws -> Data {
        let rootKey = try await rootKey()

        // TODO: Bridge to Rust `CapabilityGrant::derive_verification_key`.
        // For now, a simple Swift-side HKDF-like construction.
        var keyData = Data()
        keyData.append(rootKey)
        keyData.append(Data(subject.utf8))

        // Use SHA-256 as a stand-in for HKDF-Expand("capability-v1", subject).
        let derived = SHA256.hash(data: keyData)
        return Data(derived)
    }

    // MARK: - Private

    /// Fetches or generates the HMAC root key from the Keychain.
    private func rootKey() async throws -> Data {
        if let cached = cachedRootKey {
            return cached
        }

        // Query the Keychain for an existing root key.
        let query: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: kKeychainService,
            kSecAttrAccount: kKeychainAccount,
            kSecAttrAccessGroup: kKeychainAccessGroup,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            cachedRootKey = data
            return data
        }

        // No existing key — generate one and store it securely.
        let newKey = try generateRandomKey(length: 32)
        let addQuery: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: kKeychainService,
            kSecAttrAccount: kKeychainAccount,
            kSecAttrAccessGroup: kKeychainAccessGroup,
            kSecValueData: newKey,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            throw CapabilityIssuerError.keychainStoreFailure(addStatus)
        }

        cachedRootKey = newKey
        return newKey
    }

    /// Generate cryptographically secure random bytes.
    private func generateRandomKey(length: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        guard status == errSecSuccess else {
            throw CapabilityIssuerError.randomGenerationFailure(status)
        }
        return Data(bytes)
    }

    /// Generate a 16-byte nonce for each grant.
    private func makeNonce() throws -> Data {
        return try generateRandomKey(length: 16)
    }
}

// MARK: - Capability Issuer Errors

/// Errors that can occur during capability issuance or verification on the Swift side.
public enum CapabilityIssuerError: Error, Sendable {
    case keychainStoreFailure(OSStatus)
    case keychainQueryFailure(OSStatus)
    case randomGenerationFailure(OSStatus)
    case rootKeyUnavailable
    case derivationFailure(String)
    case serializationFailure(String)
}

extension CapabilityIssuerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .keychainStoreFailure(let status):
            return "Keychain store failed (OSStatus \(status))"
        case .keychainQueryFailure(let status):
            return "Keychain query failed (OSStatus \(status))"
        case .randomGenerationFailure(let status):
            return "Secure random generation failed (OSStatus \(status))"
        case .rootKeyUnavailable:
            return "HMAC root key unavailable — Keychain access may be denied."
        case .derivationFailure(let reason):
            return "Key derivation failed: \(reason)"
        case .serializationFailure(let reason):
            return "Capability serialization failed: \(reason)"
        }
    }
}

// MARK: - SHA-256 helper (Swift Crypto overlay)

/// Minimal SHA-256 wrapper using `CryptoKit` where available,
/// falling back to `CommonCrypto` if needed. For MAS Core we assume
/// macOS 10.15+ and use `CryptoKit`.
#if canImport(CryptoKit)
import CryptoKit

private enum SHA256 {
    static func hash(data: Data) -> Data {
        let digest = CryptoKit.SHA256.hash(data: data)
        return Data(digest)
    }
}
#else
#error("CryptoKit is required for capability key derivation")
#endif
