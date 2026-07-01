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
        let rules = blockedDomainPatterns.compactMap { domain -> [String: Any]? in
            guard let urlFilter = urlFilter(forBlockedDomainPattern: domain) else { return nil }
            return [
                "trigger": [
                    "url-filter": urlFilter,
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

    static func urlFilter(forBlockedDomainPattern pattern: String) -> String? {
        guard let suffix = normalizedDomainSuffix(pattern) else { return nil }
        let escaped = NSRegularExpression.escapedPattern(for: suffix)
        return #"^https?://([^/?#@]+\.)*"# + escaped + #"([/:?#]|$)"#
    }

    private static func normalizedDomainSuffix(_ pattern: String) -> String? {
        var suffix = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        while suffix.hasPrefix("*") || suffix.hasPrefix(".") {
            suffix.removeFirst()
        }
        suffix = suffix.lowercased()
        guard suffix.contains("."),
              suffix.count <= 253,
              !suffix.hasPrefix("."),
              !suffix.hasSuffix(".") else {
            return nil
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        guard suffix.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              suffix.split(separator: ".").allSatisfy({ label in
                  !label.isEmpty
                      && label.count <= 63
                      && !label.hasPrefix("-")
                      && !label.hasSuffix("-")
              }) else {
            return nil
        }
        return suffix
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
