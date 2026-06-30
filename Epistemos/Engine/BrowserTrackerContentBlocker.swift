import Foundation
import WebKit

nonisolated enum BrowserTrackerContentBlocker {
    static let identifier = "com.epistemos.browser.tracker-blocker.v1"

    static let blockedDomainPatterns: [String] = [
        "*doubleclick.net",
        "*googlesyndication.com",
        "*google-analytics.com",
        "*googletagmanager.com",
        "*facebook.net",
        "*connect.facebook.net",
        "*ads-twitter.com",
        "*analytics.twitter.com",
        "*scorecardresearch.com",
        "*adnxs.com",
        "*adsystem.com",
        "*taboola.com",
        "*outbrain.com",
        "*hotjar.com",
        "*segment.io",
    ]

    static var ruleListJSON: String {
        let rules = blockedDomainPatterns.map { domain in
            [
                "trigger": [
                    "url-filter": ".*",
                    "if-domain": [domain],
                ],
                "action": [
                    "type": "block",
                ],
            ]
        }
        guard JSONSerialization.isValidJSONObject(rules),
              let data = try? JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    @MainActor
    static func install(
        on userContentController: WKUserContentController,
        store providedStore: WKContentRuleListStore? = nil
    ) {
        guard let store = providedStore ?? WKContentRuleListStore.default() else { return }
        store.compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: ruleListJSON
        ) { ruleList, _ in
            guard let ruleList else { return }
            Task { @MainActor in
                userContentController.add(ruleList)
            }
        }
    }
}
