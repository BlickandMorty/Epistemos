import AppKit

enum NoteCalloutKind: String, CaseIterable, Sendable {
    case note
    case tip
    case warning
    case quote

    var title: String {
        switch self {
        case .note: "Note"
        case .tip: "Tip"
        case .warning: "Warning"
        case .quote: "Quote"
        }
    }
}

enum MarkdownEditorCommands {
    struct Continuation: Equatable, Sendable {
        let insertedText: String
    }

    static let markdownTableTemplate =
        "\n| Column 1 | Column 2 | Column 3 |\n| -------- | -------- | -------- |\n| cell     | cell     | cell     |\n"

    static func continuedInsertion(for line: String) -> Continuation? {
        let trimmedLine = line.replacingOccurrences(of: "\r", with: "")
        let lineBody = trimmedLine.hasSuffix("\n") ? String(trimmedLine.dropLast()) : trimmedLine
        let indentation = String(lineBody.prefix { $0 == " " || $0 == "\t" })
        let content = String(lineBody.dropFirst(indentation.count))
        guard !content.isEmpty else { return nil }

        if let prefix = taskListPrefix(for: content) {
            return Continuation(insertedText: "\n\(indentation)\(prefix)")
        }
        if let prefix = orderedListPrefix(for: content) {
            return Continuation(insertedText: "\n\(indentation)\(prefix)")
        }
        if let prefix = unorderedListPrefix(for: content) {
            return Continuation(insertedText: "\n\(indentation)\(prefix)")
        }
        if let prefix = quotePrefix(for: content) {
            return Continuation(insertedText: "\n\(indentation)\(prefix)")
        }
        return nil
    }

    static func strippedLineMarker(from line: String) -> String {
        if let range = line.range(of: #"^[-*+] \[(?: |x|X)\] "#, options: .regularExpression) {
            return String(line[range.upperBound...])
        }
        if let range = line.range(of: #"^\d+\. "#, options: .regularExpression) {
            return String(line[range.upperBound...])
        }
        if let range = line.range(of: #"^[-*+] "#, options: .regularExpression) {
            return String(line[range.upperBound...])
        }
        if let range = line.range(of: #"^(?:>\s*)+"#, options: .regularExpression) {
            return String(line[range.upperBound...])
        }
        return line
    }

    static func calloutTemplate(for kind: NoteCalloutKind) -> String {
        "> [!\(kind.rawValue)] \(kind.title)\n> "
    }

    @MainActor
    static func handleContinuationNewline(in textView: NSTextView) -> Bool {
        let str = textView.string as NSString
        guard str.length > 0 else { return false }

        let selection = textView.selectedRange()
        guard selection.length == 0 else { return false }

        let safeLocation = min(selection.location, max(0, str.length - 1))
        let lineRange = str.lineRange(for: NSRange(location: safeLocation, length: 0))
        let line = str.substring(with: lineRange)

        guard let continuation = continuedInsertion(for: line) else { return false }
        let insertionRange = NSRange(location: selection.location, length: 0)
        if textView.shouldChangeText(in: insertionRange, replacementString: continuation.insertedText) {
            textView.textStorage?.replaceCharacters(in: insertionRange, with: continuation.insertedText)
            textView.didChangeText()
            let newLocation = selection.location + continuation.insertedText.utf16.count
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))
            return true
        }
        return false
    }

    private static func taskListPrefix(for line: String) -> String? {
        guard let range = line.range(of: #"^[-*+] \[(?: |x|X)\] "#, options: .regularExpression),
              range.lowerBound == line.startIndex else { return nil }
        let bullet = line[line.startIndex]
        return "\(bullet) [ ] "
    }

    private static func unorderedListPrefix(for line: String) -> String? {
        guard let range = line.range(of: #"^[-*+] "#, options: .regularExpression),
              range.lowerBound == line.startIndex else { return nil }
        return String(line[range])
    }

    private static func orderedListPrefix(for line: String) -> String? {
        guard let range = line.range(of: #"^\d+\. "#, options: .regularExpression),
              range.lowerBound == line.startIndex else { return nil }
        let marker = String(line[range]).trimmingCharacters(in: .whitespaces)
        let numberText = marker.dropLast()
        let next = (Int(numberText) ?? 0) + 1
        return "\(next). "
    }

    private static func quotePrefix(for line: String) -> String? {
        var index = line.startIndex
        var depth = 0

        while index < line.endIndex, line[index] == ">" {
            depth += 1
            index = line.index(after: index)
            while index < line.endIndex, line[index] == " " {
                index = line.index(after: index)
            }
        }

        guard depth > 0 else { return nil }
        return Array(repeating: ">", count: depth).joined(separator: " ") + " "
    }
}
