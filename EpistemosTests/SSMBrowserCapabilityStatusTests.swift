import Testing
import Foundation

@testable import Epistemos

// SS-M / Obscura (owner 2026-06-19). These pin the HONEST browser/scraper/privacy ledger: the real
// MAS-safe capabilities (HTTP fetch/extract/crawl, private in-app web views) are marked live, and the
// Obscura stealth engine + anti-fingerprint + agentic schema-scraping — all stub/Pro/unbuilt — are
// marked NOT live (no fake-green; the silent NotConfigured stub never reads as a working stealth
// browser). Verified against code (ObscuraBrowserEngine NotConfigured stub; web.rs scraper schemas;
// nonPersistent() web views; zero customUserAgent/WKContentRuleList/obscura-deps).
@Suite("SS-M — honest browser/scraper capability status")
struct SSMBrowserCapabilityStatusTests {

    @Test("the real MAS-safe scraper + privacy capabilities are marked live")
    func liveCapabilitiesAreReal() {
        let live = BrowserCapabilityStatus.capabilities.filter(\.isLive).map(\.name)
        #expect(live.contains { $0.contains("fetch") || $0.contains("extract") })
        #expect(live.contains { $0.contains("crawl") })
        #expect(live.contains { $0.contains("privacy") })
    }

    @Test("the Obscura stealth engine + anti-fingerprint are honestly marked NOT live (no fake-green)")
    func stealthSeamsAreMarkedNotLive() {
        let deferred = BrowserCapabilityStatus.capabilities.filter { !$0.isLive }.map(\.name)
        #expect(deferred.contains { $0.contains("Obscura") })          // stealth engine is a stub
        #expect(deferred.contains { $0.contains("Anti-fingerprint") }) // not built
        #expect(deferred.contains { $0.contains("scraper") })          // no agentic schema loop
    }

    @Test("counts + summary are consistent + honest (real-but-not-stealth, never 'complete')")
    func countsAndSummaryConsistent() {
        let total = BrowserCapabilityStatus.capabilities.count
        #expect(BrowserCapabilityStatus.liveCount + BrowserCapabilityStatus.deferredCount == total)
        #expect(BrowserCapabilityStatus.liveCount > 0)        // real scraping/privacy works
        #expect(BrowserCapabilityStatus.deferredCount > 0)    // the stealth browser does not
        #expect(BrowserCapabilityStatus.summary.contains("stub"))
    }
}
