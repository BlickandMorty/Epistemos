import Foundation

// MARK: - NoteLinkClassifier
// Pure, testable classification of a link clicked inside a note (see ProseEditorRepresentable2's
// `textView(_:clickedOnLink:)`). A note is UNTRUSTED content — it may be shared, synced, or imported —
// so the SECURITY rule is deny-by-default for external opening: only http/https/mailto open via
// NSWorkspace; file://, custom app schemes, and anything else are CONSUMED (never handed to the OS).
// Internal wikilink:// / blockref:// links route in-app.
//
// The classification is pure so it can be unit-tested without a live NSTextView; the handler performs
// the side effects (in-app routing, NSWorkspace.open) based on the returned Action.
enum NoteLinkClassifier {

    enum Action: Equatable {
        case wikilink(String)          // in-app: navigate to a note by title
        case blockReference(String)    // in-app: navigate to a block by id
        case openExternal(URL)         // safe web/mail scheme — open via NSWorkspace
        case consume                   // untrusted/unknown — swallow, do NOT open
    }

    /// Safe schemes that may be handed to the OS from untrusted note text.
    static let externallyOpenableSchemes: Set<String> = ["http", "https", "mailto"]

    /// Classify a clicked link value (NSTextView passes either a String or a URL).
    static func classify(_ link: Any) -> Action {
        let urlString: String
        if let string = link as? String {
            urlString = string
        } else if let url = link as? URL {
            urlString = url.absoluteString
        } else {
            return .consume  // unknown link type — swallow
        }
        if urlString.hasPrefix("wikilink://") {
            return .wikilink(String(urlString.dropFirst("wikilink://".count)))
        }
        if urlString.hasPrefix("blockref://") {
            return .blockReference(String(urlString.dropFirst("blockref://".count)))
        }
        if let url = URL(string: urlString),
            let scheme = url.scheme?.lowercased(),
            externallyOpenableSchemes.contains(scheme) {
            return .openExternal(url)
        }
        return .consume  // file://, custom schemes, schemeless, unparseable — all swallowed
    }
}
