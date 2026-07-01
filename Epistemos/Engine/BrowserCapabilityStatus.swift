import Foundation

// SS-M / Obscura (owner 2026-06-19: "Obscura ... agent scraper things like that, privacy"). The owner
// later cut the native Obscura automation robot in favor of browser-use Pro automation. The Rust
// ObscuraBrowserEngine remains a trait stub that returns NotConfigured for every call, and there are no
// obscura/deno_core/V8 deps. What DOES exist is a real, MAS-safe browser/scraper + privacy posture. The
// honest, no-fake-green move is to keep the cut native stealth state scannable, so a silent
// NotConfigured stub never reads as a working stealth browser.
//
// Every entry below was verified in code (ObscuraBrowserEngine NotConfigured stub at
// browser_engine/mod.rs:264+; web_extract/web_crawl/web_search/web_extract_schema schemas in tools/web.rs;
// nonPersistent() on MAS-safe WKWebView hosts; browser-use Pro's Gradio shell uses an isolated named
// WKWebsiteDataStore so the full cloned UI can retain local state without sharing the default browser store;
// BrowserTrackerContentBlocker WKContentRuleList wiring; zero customUserAgent / obscura-dep references).
enum BrowserCapabilityStatus {

    struct Capability: Sendable, Equatable {
        let name: String
        /// True = works today (MAS-safe, real). False = a stub / Pro-gated / not-yet-built seam.
        let isLive: Bool
        let note: String
    }

    static let capabilities: [Capability] = [
        Capability(name: "Web fetch / extract", isLive: true, note: "Real HTTP fetch + HTML→text, SSRF-guarded"),
        Capability(name: "Web crawl (BFS)", isLive: true, note: "Same-host BFS frontier, page/depth caps"),
        Capability(name: "Web search", isLive: true, note: "Tavily / Brave / Perplexity (env-key gated)"),
        Capability(name: "In-app web view privacy", isLive: true, note: "MAS-safe WKWebViews use nonPersistent(); browser-use Pro uses an isolated named WK data store"),
        Capability(name: "Tracker / ad blocking (WKContentRuleList)", isLive: true, note: "Native Browser installs a local WebKit content rule list for common tracker/ad domains"),
        Capability(name: "Obscura stealth engine", isLive: false, note: "Owner-cut native path — trait stub returns NotConfigured; Pro automation is browser-use"),
        Capability(name: "Anti-fingerprint (UA / canvas / WebGL spoof)", isLive: false, note: "Absent by design on native WKWebView; browser-use Pro owns automation"),
        Capability(name: "Agentic extract-to-schema scraper", isLive: true, note: "Registered web.extract_schema tool fills caller JSON Schema from title/meta/JSON-LD/text with validation evidence"),
    ]

    static var liveCount: Int { capabilities.filter(\.isLive).count }
    static var deferredCount: Int { capabilities.filter { !$0.isLive }.count }

    /// One honest line for the diagnostics row — real scraping + privacy exist; the stealth browser does not.
    static var summary: String {
        "\(liveCount) live, \(deferredCount) cut/stub/unbuilt — real HTTP fetch/extract/crawl/schema extraction, private MAS-safe in-app web views, isolated browser-use Pro web state, and WKContentRuleList tracker/ad blocking work today; the native Obscura stealth path is owner-cut/superseded by browser-use, and anti-fingerprint spoofing is not built."
    }
}
