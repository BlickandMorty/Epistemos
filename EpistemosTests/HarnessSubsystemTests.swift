import Testing
import Foundation
@testable import Epistemos

@Suite("SanitizedEnvironment — safe baseline env")
struct SanitizedEnvironmentTests {

    @Test("Preserves baseline keys (PATH, HOME, USER)")
    func preservesBaselineKeys() {
        let environment = SanitizedEnvironment.build()
        #expect(environment["PATH"] != nil)
        #expect(environment["HOME"] != nil)
        #expect(environment["USER"] != nil)
    }

    @Test("Strips API keys and sensitive tokens")
    func stripsAPIKeys() {
        let environment = SanitizedEnvironment.build(extras: [:])
        #expect(SanitizedEnvironment.deniedPatterns.contains("ANTHROPIC_"))
        #expect(SanitizedEnvironment.deniedPatterns.contains("OPENAI_"))
        #expect(SanitizedEnvironment.deniedPatterns.contains("GITHUB_TOKEN"))
        #expect(SanitizedEnvironment.deniedPatterns.contains("AWS_SECRET"))

        for key in environment.keys {
            let uppercasedKey = key.uppercased()
            for deniedPattern in SanitizedEnvironment.deniedPatterns {
                #expect(!uppercasedKey.contains(deniedPattern), "Key \(key) matches denied pattern \(deniedPattern)")
            }
        }
    }

    @Test("Preserves XDG_* prefix keys but not denied ones")
    func preservesXDGPrefix() {
        let allowedPrefixes = SanitizedEnvironment.allowedPrefixes
        #expect(allowedPrefixes.contains("XDG_"))
        #expect(allowedPrefixes.contains("HOMEBREW_"))
    }

    @Test("Filters sensitive extras before child launch")
    func filtersSensitiveExtrasBeforeChildLaunch() {
        let environment = SanitizedEnvironment.build(extras: [
            "TMPDIR": "/tmp/epistemos-safe",
            "OPENAI_API_KEY": "must-not-leak",
            "XDG_RUNTIME_DIR": "/tmp/epistemos-xdg",
        ])

        #expect(environment["TMPDIR"] == "/tmp/epistemos-safe")
        #expect(environment["XDG_RUNTIME_DIR"] == "/tmp/epistemos-xdg")
        #expect(environment["OPENAI_API_KEY"] == nil)
    }
}
