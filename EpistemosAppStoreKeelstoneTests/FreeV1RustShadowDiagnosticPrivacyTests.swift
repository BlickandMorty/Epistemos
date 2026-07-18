import Foundation
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 Rust Shadow diagnostic-privacy tests must compile in the App Store target.")
#endif

@Suite("Free V1 Rust Shadow diagnostic privacy")
struct FreeV1RustShadowDiagnosticPrivacyTests {
    @Test("Rust Shadow failures do not embed raw query text in typed errors")
    func rustShadowSearchDoesNotInterpolateTheRawQueryIntoAnError() throws {
        let source = try sourceText("Epistemos/Engine/RustShadowFFIClient.swift")
        let searchMethod = try #require(
            sourceSection(
                named: "public func search(query: String, limit: Int) throws -> [ShadowHit]",
                in: source,
                endingBefore: "    public func flush()"
            )
        )

        #expect(!searchMethod.contains("query=\\(query)"))
        #expect(!searchMethod.contains("detail: \"query=\\(query)\""))
        #expect(searchMethod.contains("ShadowFFIError.from(rustCode: errorCode)"))
    }

    private func sourceSection(named start: String, in source: String, endingBefore end: String) -> String? {
        guard let startRange = source.range(of: start),
              let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex) else {
            return nil
        }
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
