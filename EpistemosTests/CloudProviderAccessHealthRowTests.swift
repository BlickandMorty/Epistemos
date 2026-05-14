import Testing

@Suite("Cloud Provider Access Health Row")
struct CloudProviderAccessHealthRowTests {
    @Test("Diagnostics count OAuth account sessions as cloud access")
    func diagnosticsCountOAuthAccountSessionsAsCloudAccess() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/APIKeysHealthRow.swift")

        #expect(source.contains("oauthCredential(for: provider)"))
        #expect(source.contains("hasOAuthSession"))
        #expect(source.contains("Account session saved"))
        #expect(source.contains("No provider access stored"))
        #expect(!source.contains("No provider keys stored"))
        #expect(!source.contains("Agents need at least one cloud provider's API key."))
    }
}
