import Foundation
import Testing

/// Enforces the credential-storage rule from `CLAUDE.md`: API keys, OAuth
/// tokens, passwords, and provider secrets belong in Keychain, never
/// UserDefaults. UserDefaults may still store non-secret UI preferences such
/// as filenames, project IDs, toggles, and display settings.
@Suite("Credential UserDefaults Absence Guard")
struct CredentialUserDefaultsAbsenceGuardTests {

    @Test("production Swift never persists credential-shaped values through UserDefaults")
    func productionSwiftNeverPersistsCredentialShapedValuesThroughUserDefaults() throws {
        let violations = try productionSwiftFiles()
            .flatMap { try credentialShapedUserDefaultsLines(in: $0) }

        #expect(violations.isEmpty, """
        Credentials must use Keychain, not UserDefaults:
        \(violations.joined(separator: "\n"))
        """)
    }

    @Test("Keychain remains the credential primitive and does not wrap UserDefaults")
    func keychainPrimitiveDoesNotWrapUserDefaults() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/Keychain.swift")

        #expect(source.contains("SecItemAdd"), "Keychain.save must write through Security.framework")
        #expect(source.contains("SecItemCopyMatching"), "Keychain.load must read through Security.framework")
        #expect(source.contains("SecItemDelete"), "Keychain.delete must delete through Security.framework")
        #expect(!source.contains("UserDefaults"), "Keychain.swift must not use UserDefaults as a fallback")
    }

    private func productionSwiftFiles() throws -> [URL] {
        try mirroredSourceFileURLs(under: "Epistemos", includingExtensions: ["swift"])
    }

    private func credentialShapedUserDefaultsLines(in url: URL) throws -> [String] {
        let source = try String(contentsOf: url, encoding: .utf8)
        let relativePath = relativeMirroredPath(for: url)
        return source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { index, line in
                let text = String(line)
                let lowercased = text.lowercased()
                guard containsUserDefaultsSurface(lowercased),
                      containsCredentialMarker(lowercased) else {
                    return nil
                }
                return "\(relativePath):\(index + 1): \(text.trimmingCharacters(in: .whitespaces))"
            }
    }

    private func containsUserDefaultsSurface(_ line: String) -> Bool {
        line.contains("userdefaults") || line.contains("@appstorage")
    }

    private func containsCredentialMarker(_ line: String) -> Bool {
        for marker in [
            "apikey",
            "api_key",
            "access_token",
            "accesstoken",
            "refresh_token",
            "refreshtoken",
            "client_secret",
            "clientsecret",
            "secret",
            "password",
            "credential",
            "bearer",
        ] where line.contains(marker) {
            return true
        }
        return false
    }

    private func relativeMirroredPath(for url: URL) -> String {
        guard let root = try? sourceMirrorRootURL().path else {
            return url.lastPathComponent
        }
        return url.path.replacingOccurrences(of: root + "/", with: "")
    }
}
