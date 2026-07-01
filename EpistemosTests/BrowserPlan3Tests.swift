import Foundation
import Testing

@testable import Epistemos

@Suite("Plan 3 browser")
struct BrowserPlan3Tests {
    @Test("URL guard allows only web navigation and resolves search input")
    func urlGuardAllowsOnlyWebNavigation() throws {
        #expect(BrowserURLGuard.resolve(raw: "https://example.com")?.absoluteString == "https://example.com")
        #expect(BrowserURLGuard.resolve(raw: "example.com/path")?.absoluteString == "https://example.com/path")

        let search = try #require(BrowserURLGuard.resolve(raw: "plan 3 browser"))
        #expect(search.scheme == "https")
        #expect(search.host == "duckduckgo.com")
        #expect(search.query?.contains("plan%203%20browser") == true)

        #expect(BrowserURLGuard.resolve(raw: "file:///tmp/secret") == nil)
        #expect(BrowserURLGuard.resolve(raw: "javascript:alert(1)") == nil)
        #expect(BrowserURLGuard.resolve(raw: "mailto:test@example.com") == nil)
        #expect(BrowserURLGuard.resolve(raw: "https://user:pass@example.com") == nil)
        #expect(BrowserURLGuard.resolve(raw: "plan 3 browser", searchTemplate: "file:///tmp/%@") == nil)
        #expect(BrowserURLGuard.resolve(raw: String(repeating: "a", count: BrowserURLGuard.maxRawInputLength + 1)) == nil)
        #expect(
            BrowserURLGuard.resolve(
                raw: String(repeating: " ", count: BrowserURLGuard.maxRawInputLength + 64) + "https://example.com"
            ) == nil
        )

        #expect(BrowserURLGuard.allows(url: URL(string: "http://example.com")))
        #expect(BrowserURLGuard.allows(url: URL(string: "https://example.com")))
        #expect(!BrowserURLGuard.allows(url: URL(string: "https://user:pass@example.com")))
        #expect(!BrowserURLGuard.allows(url: URL(string: "file:///tmp/secret")))
        #expect(!BrowserURLGuard.allows(url: URL(string: "data:text/html,hi")))
    }

    @Test("browser implementation is MAS-safe Tier 1, not Goose or agent automation")
    func browserSourceStaysTierOne() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Browser/BrowserView.swift")

        #expect(source.contains("WKWebsiteDataStore.nonPersistent()"))
        #expect(source.contains("BrowserTrackerContentBlocker.install"))
        #expect(source.contains("webView.setValue(false, forKey: \"drawsBackground\")"))
        #expect(source.contains("BrowserURLGuard.allows"))
        #expect(source.contains("BrowserDisplayPolicy"))
        #expect(source.contains("IntegrationBrandMarkView(brand: .browser"))
        #expect(source.contains("ToolbarCapsuleButton("))
        #expect(source.contains(".textFieldStyle(.plain)"))
        #expect(source.contains("theme.resolved.card.color.opacity"))
        #expect(source.contains("maxRawInputLength"))
        #expect(source.contains("String(raw.prefix(maxRawInputLength + 1))"))
        #expect(source.contains("maxAddressLength"))
        #expect(source.contains("maxTitleLength"))
        #expect(source.contains("maxErrorLength"))
        #expect(source.contains("trimmedCapped"))
        #expect(source.contains("String(value.prefix(limit + 1))"))
        #expect(source.contains("String(bounded.prefix(limit - 3))"))
        #expect(source.contains("String(value.prefix(limit + 32))"))
        #expect(source.contains("String(domain.prefix(96))"))
        #expect(source.contains("decidePolicyFor navigationAction"))
        #expect(source.contains("decidePolicyFor navigationResponse"))
        #expect(source.contains("WKNavigationResponsePolicy"))
        #expect(source.contains("guard let url = navigationAction.request.url"))
        #expect(source.contains("webView.load(URLRequest(url: url))"))
        #expect(!source.contains("webView.load(navigationAction.request)"))
        #expect(source.contains("Navigation failed (domain="))
        #expect(!source.contains("error.localizedDescription"))
        #expect(!source.contains("String(describing: error)"))
        #expect(!source.contains(".foregroundStyle(.orange)"))
        #expect(!source.contains(".buttonStyle(.plain)"))
        #expect(!source.contains(".buttonStyle(.borderless)"))
        #expect(!source.contains(".stroke(theme.border"))
        #expect(source.contains("EpdocWebViewShared.notifyWebViewCreated()"))
        #expect(source.contains("EpdocWebViewShared.notifyWebViewDismantled()"))
        #expect(!source.contains("Goose"))
        #expect(!source.contains("Process("))
        #expect(!source.localizedCaseInsensitiveContains("python"))
        #expect(!source.localizedCaseInsensitiveContains("chromium"))
        #expect(!source.contains("WebKitBrowserEngine"))

        let blocker = try loadMirroredSourceTextFile("Epistemos/Engine/BrowserTrackerContentBlocker.swift")
        #expect(blocker.contains("WKContentRuleListStore"))
        #expect(blocker.contains("compileContentRuleList"))
        #expect(blocker.contains("urlFilter(forBlockedDomainPattern:"))
        #expect(blocker.contains("normalizedDomainSuffix"))
        #expect(blocker.contains("*doubleclick.net"))
        #expect(blocker.contains("*google-analytics.com"))
        #expect(!blocker.contains(#""if-domain""#))
        #expect(!blocker.contains("customUserAgent"))
    }

    @Test("content blocker rules match tracker request URLs, not only page domains")
    func contentBlockerRulesMatchRequestURLs() throws {
        let doubleClickFilter = try #require(
            BrowserTrackerContentBlocker.urlFilter(forBlockedDomainPattern: "*doubleclick.net")
        )
        let doubleClickRegex = try NSRegularExpression(pattern: doubleClickFilter)

        #expect(Self.matches(doubleClickRegex, "https://doubleclick.net/activity"))
        #expect(Self.matches(doubleClickRegex, "https://ad.doubleclick.net/activity"))
        #expect(Self.matches(doubleClickRegex, "http://stats.ad.doubleclick.net/pixel.gif"))
        #expect(!Self.matches(doubleClickRegex, "https://notdoubleclick.net/activity"))
        #expect(!Self.matches(doubleClickRegex, "https://doubleclick.net.evil.example/activity"))
        #expect(!Self.matches(doubleClickRegex, "https://doubleclick.net@evil.example/activity"))
        #expect(BrowserTrackerContentBlocker.urlFilter(forBlockedDomainPattern: "*bad_domain.test") == nil)

        let rulesData = Data(BrowserTrackerContentBlocker.ruleListJSON.utf8)
        let rules = try #require(try JSONSerialization.jsonObject(with: rulesData) as? [[String: Any]])
        #expect(rules.count == BrowserTrackerContentBlocker.blockedDomainPatterns.count)

        for rule in rules {
            let trigger = try #require(rule["trigger"] as? [String: Any])
            let action = try #require(rule["action"] as? [String: Any])
            let urlFilter = try #require(trigger["url-filter"] as? String)
            #expect(urlFilter.hasPrefix("^https?://"))
            #expect(trigger["if-domain"] == nil)
            #expect(action["type"] as? String == "block")
        }
    }

    @Test("navigation cancellation is not surfaced as a browser error")
    func navigationCancellationIsNotSurfacedAsError() throws {
        let cancelled = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        #expect(BrowserNavigationErrorPolicy.userVisibleMessage(for: cancelled) == nil)

        let timedOut = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        #expect(BrowserNavigationErrorPolicy.userVisibleMessage(for: timedOut) != nil)

        let longError = NSError(
            domain: "BrowserPlan3Tests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: String(repeating: "e", count: BrowserDisplayPolicy.maxErrorLength + 32)]
        )
        #expect(BrowserNavigationErrorPolicy.userVisibleMessage(for: longError) == "Navigation failed (domain=BrowserPlan3Tests code=1)")
        let longDomain = String(repeating: "d", count: 200)
        #expect(
            BrowserNavigationErrorPolicy.userVisibleMessage(
                for: NSError(domain: longDomain, code: 2)
            ) == "Navigation failed (domain=\(String(longDomain.prefix(80))) code=2)"
        )

        let pathLeakingError = NSError(
            domain: "/Users/jojo/PrivateVault/browser.swift",
            code: -101,
            userInfo: [
                NSLocalizedDescriptionKey: "Could not load /Users/jojo/PrivateVault/session.html"
            ]
        )
        let pathLeakingMessage = try #require(BrowserNavigationErrorPolicy.userVisibleMessage(for: pathLeakingError))
        #expect(pathLeakingMessage.contains("Navigation failed"))
        #expect(pathLeakingMessage.contains("code=-101"))
        for forbidden in [
            "/Users/jojo",
            "PrivateVault",
            "browser.swift",
            "session.html",
        ] {
            #expect(!pathLeakingMessage.contains(forbidden))
        }
    }

    @Test("browser display policy caps page-controlled UI strings")
    func browserDisplayPolicyCapsPageControlledUIStrings() throws {
        let longTitle = String(repeating: "t", count: BrowserDisplayPolicy.maxTitleLength + 32)
        #expect(BrowserDisplayPolicy.title(longTitle).count == BrowserDisplayPolicy.maxTitleLength)
        #expect(BrowserDisplayPolicy.title("  \(longTitle)\n").count == BrowserDisplayPolicy.maxTitleLength)
        #expect(BrowserDisplayPolicy.title(" \n ") == "Browser")
        #expect(
            BrowserDisplayPolicy.error("  \(String(repeating: "e", count: BrowserDisplayPolicy.maxErrorLength + 32))\n")
                .count == BrowserDisplayPolicy.maxErrorLength
        )

        let longURL = try #require(URL(string: "https://example.com/\(String(repeating: "p", count: BrowserDisplayPolicy.maxAddressLength + 32))"))
        #expect(BrowserDisplayPolicy.address(for: longURL).count == BrowserDisplayPolicy.maxAddressLength)
    }

    @Test("browser is reachable through utility window, menu, and landing button")
    func browserIsReachableFromPlan3Surfaces() throws {
        let utility = try loadMirroredSourceTextFile("Epistemos/App/UtilityWindowManager.swift")
        let app = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let buttons = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingFeatureButtons.swift")

        #expect(utility.contains("case browser"))
        #expect(utility.contains("BrowserView()"))
        #expect(utility.contains("NSSize(width: 1024, height: 720)"))
        #expect(app.contains("Button(\"Browser\")"))
        #expect(app.contains(".keyboardShortcut(\"b\", modifiers: [.command, .shift])"))
        #expect(landing.contains("UtilityWindowManager.shared.show(.browser)"))
        #expect(buttons.contains("case .browser:"))
        #expect(buttons.contains("return true"))
    }

    @Test("browser Tier 1 codepack is de-Obscura-named and preserves automation boundary")
    func browserTierOneCodepackUsesBrowserNamesAndBoundary() throws {
        let plan = try loadMirroredSourceTextFile("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")
        let codepack = try loadMirroredSourceTextFile("docs/research/PLAN_3_OBSCURA_TIER1_CODEPACK_2026_06_28.md")

        #expect(plan.contains("T1 is shipped"))
        #expect(plan.contains("standalone lite Browser tab (`BrowserView`, human-driven"))
        #expect(plan.contains("user-driven Browser tab is live"))
        #expect(plan.contains("ellipsis inside configured caps"))
        #expect(plan.contains("sanitized URL-only reloads for new-window navigations"))
        #expect(!plan.contains("`ObscuraBrowserView`"))

        for required in [
            "Plan 3 — Browser Tier 1 in-app browser",
            "shipped code",
            "Epistemos/Views/Browser/BrowserView.swift",
            "BrowserURLGuard",
            "BrowserTab",
            "BrowserView",
            "BrowserWebView",
            "Browser file contract [DELIVERED]",
            "new-window navigations are reloaded from a sanitized URL-only request",
            "host-anchored request URL filters",
            "ellipsis kept inside the configured display caps",
            "Summon — `UtilityPanel.browser` + ⌘⇧B [DELIVERED]",
            "UtilityWindowManager.shared.show(.browser)",
            "WebKitBrowserEngine` Rust stub stays `NotConfigured",
            "Pro automation is the separate browser-use Chromium lane",
            "does not and must not drive this native WKWebView tab"
        ] {
            #expect(codepack.contains(required), "Missing Browser Tier-1 codepack string: \(required)")
        }

        for forbidden in [
            "ObscuraBrowserView",
            "ObscuraTab",
            "ObscuraURLGuard",
            "ObscuraWebRepresentable",
            "ObscuraWebKitDriver",
            "Rust-native V8",
            "clone-ready code",
            "NEW `Epistemos/Views/Browser/BrowserView.swift`",
            "nothing renders a page in-app yet",
            "wire the standalone `BrowserView`"
        ] {
            #expect(!codepack.contains(forbidden), "Browser Tier-1 codepack kept stale Obscura string: \(forbidden)")
            #expect(!plan.contains(forbidden), "Plan 3 capability doc kept stale Browser Tier-1 string: \(forbidden)")
        }
    }

    private static func matches(_ regex: NSRegularExpression, _ value: String) -> Bool {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.firstMatch(in: value, range: range) != nil
    }
}
