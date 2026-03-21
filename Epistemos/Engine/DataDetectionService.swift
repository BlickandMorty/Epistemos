import AppKit

// MARK: - DataDetectionService
// On-device data detection using NSDataDetector. Finds dates, addresses,
// phone numbers, and URLs in text. Returns ranges and types for styling
// and click-to-open behavior.

enum DataDetectionService {

    final class DetectedItem: Sendable {
        enum Kind: Sendable {
            case date(Date)
            case address(String)
            case phoneNumber(String)
            case link(URL)
        }
        let range: NSRange
        let kind: Kind
        let text: String

        nonisolated init(range: NSRange, kind: Kind, text: String) {
            self.range = range
            self.kind = kind
            self.text = text
        }
    }

    /// Scans text for dates, addresses, phone numbers, and links.
    /// Runs synchronously — call on background thread for large documents.
    nonisolated static func detect(in text: String) -> [DetectedItem] {
        guard !text.isEmpty else { return [] }

        let types: NSTextCheckingResult.CheckingType = [.date, .address, .phoneNumber, .link]
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return [] }

        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        var items: [DetectedItem] = []
        items.reserveCapacity(16)

        detector.enumerateMatches(in: text, options: [], range: fullRange) { result, _, _ in
            guard let result else { return }
            let matchedText = nsString.substring(with: result.range)

            switch result.resultType {
            case .date:
                if let date = result.date {
                    items.append(DetectedItem(range: result.range, kind: .date(date), text: matchedText))
                }
            case .address:
                items.append(DetectedItem(range: result.range, kind: .address(matchedText), text: matchedText))
            case .phoneNumber:
                if let phone = result.phoneNumber {
                    items.append(DetectedItem(range: result.range, kind: .phoneNumber(phone), text: matchedText))
                }
            case .link:
                if let url = result.url {
                    items.append(DetectedItem(range: result.range, kind: .link(url), text: matchedText))
                }
            default:
                break
            }
        }

        return items
    }

    /// Runs data detection off the caller's actor so editor debounce paths do not
    /// spend their full scan time on the main actor.
    nonisolated static func detectAsync(
        in text: String,
        priority: TaskPriority = .utility
    ) async -> [DetectedItem] {
        let snapshot = text
        return await Task.detached(priority: priority) {
            detect(in: snapshot)
        }.value
    }

    /// Opens the appropriate system app for a detected item.
    nonisolated static func open(_ item: DetectedItem) {
        switch item.kind {
        case .date:
            // Open Calendar app
            NSWorkspace.shared.open(URL(string: "x-apple-calevent://")
                ?? URL(string: "webcal://")!)
        case .address(let address):
            // Open in Maps
            let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
            if let url = URL(string: "maps://?q=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
        case .phoneNumber(let phone):
            // Open FaceTime
            let cleaned = phone.filter { $0.isNumber || $0 == "+" }
            if let url = URL(string: "facetime://\(cleaned)") {
                NSWorkspace.shared.open(url)
            }
        case .link(let url):
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Styling

    /// Attribute key marking a range as data-detected. Value is a DetectedItem.
    nonisolated static let detectedDataKey = NSAttributedString.Key("EpistemosDetectedData")

    /// Applies subtle underline styling to detected data ranges in an NSTextStorage.
    /// Call this after text highlighting (e.g. after MarkdownTextStorage.processEditing).
    nonisolated static func styleDetectedRanges(
        in storage: NSTextStorage,
        items: [DetectedItem],
        isDark: Bool
    ) {
        let underlineColor: NSColor = isDark
            ? NSColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 0.4)
            : NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.35)

        for item in items {
            guard item.range.location + item.range.length <= storage.length else { continue }
            storage.addAttributes([
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: underlineColor,
                Self.detectedDataKey: item,
            ], range: item.range)
        }
    }
}
