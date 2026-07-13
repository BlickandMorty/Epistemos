import Foundation

// The MAS app exposes only the native browser/scraper and privacy posture.
// It intentionally has no automation, stealth, or external-browser runtime.
//
// Every entry below was verified in code (ObscuraBrowserEngine NotConfigured stub at
// browser_engine/mod.rs:264+; web_extract/web_crawl/web_search/web_extract_schema schemas in tools/web.rs;
// nonPersistent() on MAS-safe WKWebView hosts; and BrowserTrackerContentBlocker
// WKContentRuleList wiring).
enum BrowserCapabilityStatus {

    struct Capability: Sendable, Equatable {
        let name: String
        /// True = works today in the MAS product. False = an intentionally unavailable seam.
        let isLive: Bool
        let note: String
    }

    static let capabilities: [Capability] = {
        let webViewPrivacyNote = "MAS-safe WKWebViews use nonPersistent() data stores"

        return [
            Capability(name: "Web fetch / extract", isLive: true, note: "Real HTTP fetch + HTML→text, SSRF-guarded"),
            Capability(name: "Web crawl (BFS)", isLive: true, note: "Same-host BFS frontier, page/depth caps"),
            Capability(name: "Web search", isLive: true, note: "Tavily / Brave / Perplexity (env-key gated)"),
            Capability(name: "In-app web view privacy", isLive: true, note: webViewPrivacyNote),
            Capability(name: "Tracker / ad blocking (WKContentRuleList)", isLive: true, note: "Native Browser installs a local WebKit content rule list for common tracker/ad domains"),
            Capability(name: "Agentic extract-to-schema scraper", isLive: true, note: "Registered web.extract_schema tool fills caller JSON Schema from title/meta/JSON-LD/text with validation evidence"),
        ]
    }()

    static var liveCount: Int { capabilities.filter(\.isLive).count }
    static var deferredCount: Int { capabilities.filter { !$0.isLive }.count }

    /// One honest line for the diagnostics row — real scraping + privacy exist; the stealth browser does not.
    static var summary: String {
        "\(liveCount) active MAS capabilities — real HTTP fetch/extract/crawl/schema extraction, private in-app WKWebViews, and WKContentRuleList tracker/ad blocking."
    }
}
