import Testing
import Foundation

@testable import Epistemos

// SS-M / Obscura (owner 2026-06-19). These pin the HONEST browser/scraper/privacy ledger: the real
// MAS-safe capabilities (HTTP fetch/extract/crawl, private in-app web views, WKContentRuleList tracker
// blocking) plus browser-use Pro's isolated WK shell state are marked live, and the
// Obscura stealth engine + anti-fingerprint stay cut/stub/unbuilt and are
// marked NOT live (no fake-green; the silent NotConfigured stub never reads as a working stealth
// browser). Verified against code (ObscuraBrowserEngine NotConfigured stub; web.rs scraper schemas;
// nonPersistent() MAS-safe web views; isolated named browser-use Pro WKWebsiteDataStore;
// BrowserTrackerContentBlocker; zero customUserAgent/obscura-deps).
@Suite("SS-M — honest browser/scraper capability status")
struct SSMBrowserCapabilityStatusTests {

    @Test("the real MAS-safe scraper + privacy capabilities are marked live")
    func liveCapabilitiesAreReal() {
        let live = BrowserCapabilityStatus.capabilities.filter(\.isLive).map(\.name)
        #expect(live.contains { $0.contains("fetch") || $0.contains("extract") })
        #expect(live.contains { $0.contains("crawl") })
        #expect(live.contains { $0.contains("schema") })
        #expect(live.contains { $0.contains("privacy") })
        #expect(live.contains { $0.contains("Tracker") || $0.contains("ad blocking") })
    }

    @Test("parked browser lanes follow the active product boundary")
    func parkedBrowserLanesFollowProductBoundary() {
        let deferred = BrowserCapabilityStatus.capabilities.filter { !$0.isLive }.map(\.name)
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        #expect(deferred.isEmpty)
        #expect(!BrowserCapabilityStatus.summary.localizedCaseInsensitiveContains("Pro"))
        #expect(!BrowserCapabilityStatus.summary.localizedCaseInsensitiveContains("Obscura"))
        #expect(!BrowserCapabilityStatus.summary.localizedCaseInsensitiveContains("browser-use"))
        #else
        #expect(deferred.contains { $0.contains("Obscura") })          // owner-cut native stealth engine is a stub
        #expect(deferred.contains { $0.contains("Anti-fingerprint") }) // not built
        #expect(!deferred.contains { $0.contains("scraper") })         // schema extraction is now live
        #endif
    }

    @Test("counts + summary are consistent + honest (real-but-not-stealth, never 'complete')")
    func countsAndSummaryConsistent() {
        let total = BrowserCapabilityStatus.capabilities.count
        #expect(BrowserCapabilityStatus.liveCount + BrowserCapabilityStatus.deferredCount == total)
        #expect(BrowserCapabilityStatus.liveCount > 0)        // real scraping/privacy works
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        #expect(BrowserCapabilityStatus.deferredCount == 0)
        #expect(BrowserCapabilityStatus.summary.contains("active MAS capabilities"))
        #else
        #expect(BrowserCapabilityStatus.deferredCount > 0)    // the stealth browser does not
        #expect(BrowserCapabilityStatus.summary.contains("cut/stub"))
        #expect(BrowserCapabilityStatus.summary.contains("superseded by browser-use"))
        #endif
        #expect(BrowserCapabilityStatus.summary.contains("WKContentRuleList"))
    }
}
