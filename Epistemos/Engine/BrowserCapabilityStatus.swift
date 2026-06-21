import Foundation

// SS-M / Obscura (owner 2026-06-19: "Obscura ... agent scraper things like that, privacy"). The owner
// queued Obscura as loop-buildable, but its stealth engine is doctrine-landed-yet-UNBUILT: the Rust
// ObscuraBrowserEngine is a trait stub that returns NotConfigured for every call, and there are no
// obscura/deno_core/V8 deps — building that runtime is Pro-gated and owner-domain. What DOES exist is a
// real, MAS-safe browser/scraper + privacy posture. The honest, no-fake-green move (same as SS-HW) is
// to make the real-vs-stub state scannable, so a silent NotConfigured stub never reads as a working
// stealth browser.
//
// Every entry below was verified in code (ObscuraBrowserEngine NotConfigured stub at
// browser_engine/mod.rs:264+; web_extract/web_crawl/web_search schemas in tools/web.rs; nonPersistent()
// on 5 WKWebView hosts; zero customUserAgent / WKContentRuleList / obscura-dep references).
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
        Capability(name: "In-app web view privacy", isLive: true, note: "nonPersistent() on all web views — no persistent cookies/cache"),
        Capability(name: "Obscura stealth engine", isLive: false, note: "Trait stub — returns NotConfigured; Pro runtime not built"),
        Capability(name: "Anti-fingerprint (UA / canvas / WebGL spoof)", isLive: false, note: "Absent — Pro stealth work"),
        Capability(name: "Tracker / ad blocking (WKContentRuleList)", isLive: false, note: "Not wired yet — MAS-safe future"),
        Capability(name: "Agentic extract-to-schema scraper", isLive: false, note: "Crawl is goal-blind BFS today; no LLM extract loop"),
    ]

    static var liveCount: Int { capabilities.filter(\.isLive).count }
    static var deferredCount: Int { capabilities.filter { !$0.isLive }.count }

    /// One honest line for the diagnostics row — real scraping + privacy exist; the stealth browser does not.
    static var summary: String {
        "\(liveCount) live, \(deferredCount) stub/Pro/unbuilt — real HTTP fetch/extract/crawl + private in-app web views work today; the Obscura stealth engine is a NotConfigured stub, and anti-fingerprint, tracker-blocking, and agentic schema-scraping are not built."
    }
}
