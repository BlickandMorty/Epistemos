import Foundation

nonisolated enum CodeEditorLineMetrics {
    /// Count text lines without splitting the full buffer into an array.
    ///
    /// NSTextView represents an empty document as one visual line, and a
    /// trailing newline creates an additional blank line, so the counter starts
    /// at one and increments only on LF bytes. CRLF files are covered by the LF.
    nonisolated static func lineCount(_ text: String) -> Int {
        var count = 1
        for byte in text.utf8 where byte == UInt8(ascii: "\n") {
            count += 1
        }
        return count
    }

    nonisolated static func lineStartUTF16Offsets(in text: String) -> [Int] {
        var offsets: [Int] = [0]
        offsets.reserveCapacity(max(1, text.utf8.count / 32))

        var offset = 0
        var previousWasCR = false
        for codeUnit in text.utf16 {
            offset += 1
            switch codeUnit {
            case 10:
                if previousWasCR {
                    previousWasCR = false
                } else {
                    offsets.append(offset)
                }
            case 13:
                offsets.append(offset)
                previousWasCR = true
            default:
                previousWasCR = false
            }
        }

        return offsets
    }

    nonisolated static func textWindow(
        in text: String,
        lineRange: ClosedRange<Int>,
        lineStartUTF16Offsets: [Int]
    ) -> (text: String, baseLineNumber: Int)? {
        guard !lineStartUTF16Offsets.isEmpty,
              lineRange.lowerBound > 0,
              lineRange.lowerBound <= lineRange.upperBound else { return nil }

        let lowerIndex = min(lineStartUTF16Offsets.count - 1, lineRange.lowerBound - 1)
        let startOffset = lineStartUTF16Offsets[lowerIndex]
        let endOffset: Int
        if lineRange.upperBound < lineStartUTF16Offsets.count {
            endOffset = lineStartUTF16Offsets[lineRange.upperBound]
        } else {
            endOffset = (text as NSString).length
        }
        guard endOffset >= startOffset else { return nil }

        let nsText = text as NSString
        let range = NSRange(location: startOffset, length: endOffset - startOffset)
        return (nsText.substring(with: range), lineRange.lowerBound)
    }
}

nonisolated enum CodeEditorSearchDirection {
    case forward
    case backward
}

nonisolated enum CodeEditorSearchEngine {
    static func find(
        in text: String,
        query: String,
        caseSensitive: Bool,
        direction: CodeEditorSearchDirection,
        currentRange: NSRange?
    ) -> NSRange? {
        let queryLength = (query as NSString).length
        guard !text.isEmpty, queryLength > 0 else { return nil }

        let source = text as NSString
        let textLength = source.length
        let options: NSString.CompareOptions = caseSensitive ? [] : [.caseInsensitive]

        switch direction {
        case .forward:
            let start = forwardSearchStart(currentRange: currentRange, textLength: textLength)
            if let range = firstMatch(
                in: source,
                query: query,
                options: options,
                range: NSRange(location: start, length: textLength - start)
            ) {
                return range
            }
            guard start > 0 else { return nil }
            return firstMatch(
                in: source,
                query: query,
                options: options,
                range: NSRange(location: 0, length: start)
            )

        case .backward:
            let end = backwardSearchEnd(currentRange: currentRange, textLength: textLength)
            if let range = firstMatch(
                in: source,
                query: query,
                options: options.union(.backwards),
                range: NSRange(location: 0, length: end)
            ) {
                return range
            }
            guard end < textLength else { return nil }
            return firstMatch(
                in: source,
                query: query,
                options: options.union(.backwards),
                range: NSRange(location: end, length: textLength - end)
            )
        }
    }

    private static func firstMatch(
        in source: NSString,
        query: String,
        options: NSString.CompareOptions,
        range: NSRange
    ) -> NSRange? {
        guard range.location >= 0,
              range.length >= 0,
              range.location <= source.length,
              range.length <= source.length - range.location else {
            return nil
        }
        let match = source.range(of: query, options: options, range: range)
        return match.location == NSNotFound ? nil : match
    }

    private static func forwardSearchStart(currentRange: NSRange?, textLength: Int) -> Int {
        guard let currentRange else { return 0 }
        guard currentRange.location != NSNotFound else { return 0 }
        let location = min(textLength, max(0, currentRange.location))
        let length = max(0, currentRange.length)
        if currentRange.length > 0 {
            return min(textLength, location + min(length, textLength - location))
        }
        return location
    }

    private static func backwardSearchEnd(currentRange: NSRange?, textLength: Int) -> Int {
        guard let currentRange else { return textLength }
        guard currentRange.location != NSNotFound else { return textLength }
        return min(textLength, max(0, currentRange.location))
    }
}
