import Foundation
import WebKit

@main
struct BrowserPrivacySmoke {
    enum Failure: Error, CustomStringConvertible {
        case invalidRuleJSON
        case missingDomain(String)
        case compileFailed(String)
        case contentBlockerNotLive
        case schemaExtractionNotLive
        case stealthOverclaimed

        var description: String {
            switch self {
            case .invalidRuleJSON:
                return "BrowserTrackerContentBlocker.ruleListJSON is not a valid non-empty JSON rule array"
            case .missingDomain(let domain):
                return "content blocker missing expected domain \(domain)"
            case .compileFailed(let message):
                return "WKContentRuleList compile failed: \(message)"
            case .contentBlockerNotLive:
                return "BrowserCapabilityStatus did not mark tracker/ad blocking live"
            case .schemaExtractionNotLive:
                return "BrowserCapabilityStatus did not mark schema extraction live"
            case .stealthOverclaimed:
                return "BrowserCapabilityStatus overclaimed Obscura stealth or anti-fingerprint as live"
            }
        }
    }

    static func main() async throws {
        let data = Data(BrowserTrackerContentBlocker.ruleListJSON.utf8)
        guard let rules = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !rules.isEmpty else {
            throw Failure.invalidRuleJSON
        }

        let json = BrowserTrackerContentBlocker.ruleListJSON
        for domain in ["*doubleclick.net", "*google-analytics.com", "*googletagmanager.com"] {
            guard json.contains(domain) else { throw Failure.missingDomain(domain) }
        }

        _ = try await compileRuleList()

        let tracker = BrowserCapabilityStatus.capabilities.first { $0.name.contains("Tracker") || $0.name.contains("ad blocking") }
        guard tracker?.isLive == true else {
            throw Failure.contentBlockerNotLive
        }

        let schemaExtraction = BrowserCapabilityStatus.capabilities.first { $0.name.contains("schema") || $0.note.contains("web.extract_schema") }
        guard schemaExtraction?.isLive == true else {
            throw Failure.schemaExtractionNotLive
        }

        let deferredNames = BrowserCapabilityStatus.capabilities.filter { !$0.isLive }.map(\.name)
        guard deferredNames.contains(where: { $0.contains("Obscura") }),
              deferredNames.contains(where: { $0.contains("Anti-fingerprint") }) else {
            throw Failure.stealthOverclaimed
        }

        print("browser privacy smoke OK: wk_content_rule_list_compiled=true rules=\(rules.count) tracker_blocking_live=true schema_extraction_live=true stealth_deferred=true")
    }

    @MainActor
    private static func compileRuleList() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            guard let store = WKContentRuleListStore.default() else {
                continuation.resume(throwing: Failure.compileFailed("default WKContentRuleListStore unavailable"))
                return
            }
            store.compileContentRuleList(
                forIdentifier: "\(BrowserTrackerContentBlocker.identifier).smoke.\(UUID().uuidString)",
                encodedContentRuleList: BrowserTrackerContentBlocker.ruleListJSON
            ) { ruleList, error in
                if let error {
                    let nsError = error as NSError
                    continuation.resume(throwing: Failure.compileFailed(
                        "domain=\(safeDomain(nsError.domain)) code=\(nsError.code)"
                    ))
                    return
                }
                guard let identifier = ruleList?.identifier else {
                    continuation.resume(throwing: Failure.compileFailed("no compiled rule list returned"))
                    return
                }
                continuation.resume(returning: identifier)
            }
        }
    }

    private static func safeDomain(_ domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard !trimmed.isEmpty,
              trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Error"
        }
        return String(trimmed.prefix(96))
    }
}
