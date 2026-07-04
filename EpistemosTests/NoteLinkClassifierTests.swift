import Foundation
import Testing

@testable import Epistemos

/// Security: a clicked note link is UNTRUSTED. These prove NoteLinkClassifier's deny-by-default rule —
/// only http/https/mailto open externally; file://, custom app schemes, and everything else are
/// consumed (never handed to NSWorkspace). Pure classification, so verified directly here.
@Suite("NoteLinkClassifier — untrusted note-link classification")
struct NoteLinkClassifierTests {

    @Test("http / https / mailto open externally")
    func safeSchemesOpen() {
        #expect(NoteLinkClassifier.classify("http://example.com")
            == .openExternal(URL(string: "http://example.com")!))
        #expect(NoteLinkClassifier.classify("https://example.com")
            == .openExternal(URL(string: "https://example.com")!))
        #expect(NoteLinkClassifier.classify("mailto:a@b.com")
            == .openExternal(URL(string: "mailto:a@b.com")!))
    }

    @Test("file:// is consumed — never launches apps or opens local files")
    func fileSchemeConsumed() {
        #expect(NoteLinkClassifier.classify("file:///etc/passwd") == .consume)
        #expect(NoteLinkClassifier.classify("file:///Applications/Calculator.app") == .consume)
    }

    @Test("custom / dangerous schemes are consumed — never trigger other apps or JS")
    func dangerousSchemesConsumed() {
        #expect(NoteLinkClassifier.classify("myapp://do-something") == .consume)
        #expect(NoteLinkClassifier.classify("javascript:alert(1)") == .consume)
        #expect(NoteLinkClassifier.classify("ftp://host/file") == .consume)
    }

    @Test("scheme matching is case-insensitive for both allow and deny")
    func caseInsensitive() {
        #expect(NoteLinkClassifier.classify("HTTPS://example.com")
            == .openExternal(URL(string: "HTTPS://example.com")!))
        #expect(NoteLinkClassifier.classify("FILE:///x") == .consume)
    }

    @Test("wikilink:// and blockref:// route in-app")
    func inAppLinks() {
        #expect(NoteLinkClassifier.classify("wikilink://My Note") == .wikilink("My Note"))
        #expect(NoteLinkClassifier.classify("blockref://abc123") == .blockReference("abc123"))
    }

    @Test("schemeless / unparseable / unknown-type all consume")
    func fallbacksConsumed() {
        #expect(NoteLinkClassifier.classify("just text") == .consume)
        #expect(NoteLinkClassifier.classify(42) == .consume)  // not String/URL
    }

    @Test("accepts a URL value, not only a String")
    func urlValue() {
        #expect(NoteLinkClassifier.classify(URL(string: "https://x.com")!)
            == .openExternal(URL(string: "https://x.com")!))
        #expect(NoteLinkClassifier.classify(URL(string: "file:///x")!) == .consume)
    }
}
