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
        #expect(source.contains("BrowserURLGuard.allows"))
        #expect(source.contains("BrowserDisplayPolicy"))
        #expect(source.contains("maxRawInputLength"))
        #expect(source.contains("maxAddressLength"))
        #expect(source.contains("maxTitleLength"))
        #expect(source.contains("maxErrorLength"))
        #expect(source.contains("decidePolicyFor navigationAction"))
        #expect(source.contains("decidePolicyFor navigationResponse"))
        #expect(source.contains("WKNavigationResponsePolicy"))
        #expect(source.contains("EpdocWebViewShared.notifyWebViewCreated()"))
        #expect(source.contains("EpdocWebViewShared.notifyWebViewDismantled()"))
        #expect(!source.contains("Goose"))
        #expect(!source.contains("Process("))
        #expect(!source.localizedCaseInsensitiveContains("python"))
        #expect(!source.localizedCaseInsensitiveContains("chromium"))
        #expect(!source.contains("WebKitBrowserEngine"))
    }

    @Test("navigation cancellation is not surfaced as a browser error")
    func navigationCancellationIsNotSurfacedAsError() {
        let cancelled = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        #expect(BrowserNavigationErrorPolicy.userVisibleMessage(for: cancelled) == nil)

        let timedOut = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        #expect(BrowserNavigationErrorPolicy.userVisibleMessage(for: timedOut) != nil)

        let longError = NSError(
            domain: "BrowserPlan3Tests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: String(repeating: "e", count: BrowserDisplayPolicy.maxErrorLength + 32)]
        )
        #expect(BrowserNavigationErrorPolicy.userVisibleMessage(for: longError)?.count == BrowserDisplayPolicy.maxErrorLength + 3)
    }

    @Test("browser display policy caps page-controlled UI strings")
    func browserDisplayPolicyCapsPageControlledUIStrings() throws {
        let longTitle = String(repeating: "t", count: BrowserDisplayPolicy.maxTitleLength + 32)
        #expect(BrowserDisplayPolicy.title(longTitle).count == BrowserDisplayPolicy.maxTitleLength + 3)
        #expect(BrowserDisplayPolicy.title(" \n ") == "Browser")

        let longURL = try #require(URL(string: "https://example.com/\(String(repeating: "p", count: BrowserDisplayPolicy.maxAddressLength + 32))"))
        #expect(BrowserDisplayPolicy.address(for: longURL).count == BrowserDisplayPolicy.maxAddressLength + 3)
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
}
