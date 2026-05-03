import Foundation
import Testing

/// Handoff H7: keep OAuth setup UI user-initiated and free of credential
/// persistence logic. Tokens belong in `CloudProviderAuthService`, not the
/// SwiftUI setup card.
@Suite("Cloud Provider Setup Card Source Guard")
struct CloudProviderSetupCardSourceGuardTests {

    @Test("OAuth setup card does not instantiate biometric policy")
    func oauthSetupCardDoesNotInstantiateBiometricPolicy() throws {
        let source = try loadMirroredSourceTextFile(Self.setupCardPath)

        #expect(!source.contains("LAContext("), "OAuth setup UI must not own biometric context creation")
        #expect(!source.contains("canEvaluatePolicy"), "OAuth setup UI must not evaluate biometric policy")
        #expect(!source.contains("evaluatePolicy"), "OAuth setup UI must not prompt biometric policy")
        #expect(!source.contains("SovereignGate.confirm"), "Sensitive OAuth setup is user-initiated UI, not a Sovereign prompt")
    }

    @Test("OAuth setup card delegates account sign-in instead of persisting tokens")
    func oauthSetupCardDelegatesAccountSignInInsteadOfPersistingTokens() throws {
        let source = try loadMirroredSourceTextFile(Self.setupCardPath)

        #expect(source.contains("inference.signInToOpenAI"), "OpenAI account sign-in should stay behind InferenceState")
        #expect(source.contains("inference.importAnthropicAccount"), "Anthropic account import should stay behind InferenceState")
        #expect(source.contains("inference.signInToGoogle(configuration:"), "Google OAuth sign-in should stay behind InferenceState")
        #expect(!source.contains("storeOAuthCredential("), "The setup card must not directly write OAuth credentials")
        #expect(!source.contains("CloudProviderOAuthCredential("), "The setup card must not construct token-bearing credentials")
    }

    @Test("OAuth setup card does not carry raw token names")
    func oauthSetupCardDoesNotCarryRawTokenNames() throws {
        let source = try loadMirroredSourceTextFile(Self.setupCardPath).lowercased()
        let forbiddenMarkers = [
            "access_token",
            "accesstoken",
            "refresh_token",
            "refreshtoken",
            "bearer",
        ]

        let hits = forbiddenMarkers.filter { source.contains($0) }
        #expect(hits.isEmpty, "OAuth setup UI must not name raw token payloads: \(hits.joined(separator: ", "))")
    }

    @Test("OAuth client configuration secret stays Keychain-backed")
    func oauthClientConfigurationSecretStaysKeychainBacked() throws {
        let source = try loadMirroredSourceTextFile(Self.setupCardPath)

        #expect(source.contains("Keychain.save(data.base64EncodedString(), for: googleOAuthClientConfigKeychainKey)"))
        #expect(source.contains("Keychain.delete(for: googleOAuthClientConfigKeychainKey)"))
        #expect(source.contains("UserDefaults.standard.set(filename, forKey: googleOAuthClientFilenameDefaultsKey)"))
        #expect(source.contains("UserDefaults.standard.set(trimmed, forKey: googleOAuthProjectIDDraftDefaultsKey)"))
    }

    @Test("UserDefaults writes in setup card remain non-secret metadata")
    func userDefaultsWritesInSetupCardRemainNonSecretMetadata() throws {
        let source = try loadMirroredSourceTextFile(Self.setupCardPath)
        let writes = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { index, line -> String? in
                let text = String(line)
                guard text.contains("UserDefaults.standard.set(") ||
                    text.contains("UserDefaults.standard.removeObject(") else {
                    return nil
                }
                return "\(Self.setupCardPath):\(index + 1): \(text.trimmingCharacters(in: .whitespaces))"
            }

        let unexpectedWrites = writes.filter { write in
            !write.contains("googleOAuthClientFilenameDefaultsKey") &&
            !write.contains("googleOAuthProjectIDDraftDefaultsKey")
        }

        #expect(unexpectedWrites.isEmpty, """
        OAuth setup UserDefaults writes must remain filename/project-ID metadata:
        \(unexpectedWrites.joined(separator: "\n"))
        """)
    }

    private static let setupCardPath = "Epistemos/Views/Shared/CloudProviderSetupCard.swift"
}
