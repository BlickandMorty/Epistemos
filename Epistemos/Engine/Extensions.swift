import Foundation

nonisolated enum ThinkingTagSyntax {
    private static let tagPairs: [(open: String, close: String)] = [
        ("<thinking>", "</thinking>"),
        ("<think>", "</think>"),
    ]

    static func openingMatch(in text: String) -> (range: Range<String.Index>, closingTag: String)? {
        tagPairs
            .compactMap { pair in
                text.range(of: pair.open).map { ($0, pair.close) }
            }
            .min { $0.range.lowerBound < $1.range.lowerBound }
    }
}

nonisolated enum ThinkingPreludeSyntax {
    private static let openingMarkers = [
        "Thinking Process:",
        "Thought Process:",
        "Reasoning:",
        "Analyze the Request:",
        "Analyze the Input:",
        "1. Analyze the Request:",
        "1. Analyze the Input:",
        "1. **Analyze the Request:**",
        "1. **Analyze the Input:**",
        "## Thinking Process",
        "## Thought Process",
        "## Reasoning",
        "**Thinking Process:**",
        "**Thought Process:**",
        "**Reasoning:**",
    ]

    private static let answerMarkers = [
        "\nFinal Answer:",
        "\nAnswer:",
        "\nFinal Response:",
        "\nResponse:",
        "\n## Final Answer",
        "\n## Answer",
        "\n**Final Answer:**",
        "\n**Answer:**",
    ]

    private static let proseOpeningCues = [
        "let me think",
        "let's think",
        "i need to think",
        "i should think",
        "let me reason through",
        "i need to reason through",
        "let me work through",
        "i'll work through",
        "i'm going to think through",
        "thinking this through",
    ]

    private static let proseOpeningPrefixes = [
        "okay, ",
        "ok, ",
        "alright, ",
        "well, ",
        "hmm, ",
        "first, ",
    ]

    private static let conclusionMarkers = [
        "\n\nTherefore",
        "\nTherefore",
        "\n\nSo ",
        "\nSo ",
        "\n\nOverall",
        "\nOverall",
        "\n\nIn short",
        "\nIn short",
        "\n\nIn summary",
        "\nIn summary",
        "\n\nThe answer is",
        "\nThe answer is",
        "\n\nThat means",
        "\nThat means",
        "\n\nBottom line",
        "\nBottom line",
        "\n\nTaken together",
        "\nTaken together",
    ]

    static var maxOpeningMarkerLength: Int {
        openingMarkers.map(\.count).max() ?? 0
    }

    static var maxAnswerMarkerLength: Int {
        answerMarkers.map(\.count).max() ?? 0
    }

    static var maxNarrativeOpeningProbeLength: Int {
        let cueLength = proseOpeningCues.map(\.count).max() ?? 0
        let prefixLength = proseOpeningPrefixes.map(\.count).max() ?? 0
        return cueLength + prefixLength + 32
    }

    static func openingMatch(in text: String) -> Range<String.Index>? {
        let trimmedStart = text.firstIndex(where: { !$0.isWhitespace && !$0.isNewline }) ?? text.endIndex
        guard trimmedStart < text.endIndex else { return nil }
        return firstMatch(in: text, markers: openingMarkers, range: trimmedStart..<text.endIndex, anchored: true)
    }

    static func answerMatch(in text: String) -> Range<String.Index>? {
        firstMatch(in: text, markers: answerMarkers, range: text.startIndex..<text.endIndex, anchored: false)
    }

    static func proseOpeningDetected(in text: String) -> Bool {
        let trimmedStart = text.firstIndex(where: { !$0.isWhitespace && !$0.isNewline }) ?? text.endIndex
        guard trimmedStart < text.endIndex else { return false }
        let probeEnd = text.index(
            trimmedStart,
            offsetBy: min(maxNarrativeOpeningProbeLength, text.distance(from: trimmedStart, to: text.endIndex)),
            limitedBy: text.endIndex
        ) ?? text.endIndex
        let probe = text[trimmedStart..<probeEnd]
            .lowercased()
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if proseOpeningCues.contains(where: { probe.hasPrefix($0) }) {
            return true
        }

        return proseOpeningPrefixes.contains { prefix in
            proseOpeningCues.contains { cue in
                probe.hasPrefix(prefix + cue)
            }
        }
    }

    static func answerBoundary(in text: String) -> (reasoningEnd: String.Index, answerStart: String.Index)? {
        let explicitBoundary = answerMatch(in: text).map { range in
            (reasoningEnd: range.lowerBound, answerStart: range.upperBound)
        }
        let conclusionBoundary = firstMatch(
            in: text,
            markers: conclusionMarkers,
            range: text.startIndex..<text.endIndex,
            anchored: false
        ).map { range in
            (reasoningEnd: range.lowerBound, answerStart: range.lowerBound)
        }

        switch (explicitBoundary, conclusionBoundary) {
        case let (explicit?, conclusion?):
            return explicit.reasoningEnd <= conclusion.reasoningEnd ? explicit : conclusion
        case let (explicit?, nil):
            return explicit
        case let (nil, conclusion?):
            return conclusion
        case (nil, nil):
            return nil
        }
    }

    static func strippingOpeningMarker(in text: String) -> String {
        guard let range = openingMatch(in: text) else { return text }
        return String(text[range.upperBound...]).trimmingLeadingWhitespaceAndNewlines()
    }

    static func splitReasoningAndAnswer(in text: String) -> (reasoning: String, answer: String)? {
        let explicitOpening = openingMatch(in: text) != nil
        let proseOpening = proseOpeningDetected(in: text)
        guard explicitOpening || proseOpening else { return nil }

        let stripped = strippingOpeningMarker(in: text)
        let normalized = stripped
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if let boundary = answerBoundary(in: normalized) {
            let reasoning = String(normalized[..<boundary.reasoningEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            let answer = String(normalized[boundary.answerStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reasoning.isEmpty, !answer.isEmpty else { return nil }
            return (reasoning, answer)
        }

        let paragraphs = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if paragraphs.count >= 2 {
            for answerIndex in stride(from: paragraphs.count - 1, through: 1, by: -1) {
                let candidate = paragraphs[answerIndex]
                if isHeadingLike(candidate) || isBulletOnlyParagraph(candidate) {
                    continue
                }
                let reasoning = paragraphs[..<answerIndex]
                    .joined(separator: "\n\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let answer = paragraphs[answerIndex...]
                    .joined(separator: "\n\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !reasoning.isEmpty, !answer.isEmpty {
                    return (reasoning, answer)
                }
            }
        }

        let lines = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.count >= 2,
           let answerLine = lines.last,
           !isHeadingLike(answerLine),
           !answerLine.hasPrefix("-"),
           !answerLine.hasPrefix("*"),
           !answerLine.hasPrefix("•"),
           answerLine.count >= 20 {
            let reasoning = lines.dropLast().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reasoning.isEmpty else { return nil }
            return (reasoning, answerLine)
        }

        return nil
    }

    static func flushableReasoningPrefix(in text: String) -> (flush: String, remainder: String)? {
        guard answerBoundary(in: text) == nil else { return nil }

        if let paragraphBreak = text.range(of: "\n\n", options: .backwards) {
            let flush = String(text[text.startIndex..<paragraphBreak.upperBound])
            let remainder = String(text[paragraphBreak.upperBound...])
            if !flush.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (flush, remainder)
            }
        }

        if let lineBreak = text.lastIndex(of: "\n") {
            let remainderStart = text.index(after: lineBreak)
            let flush = String(text[text.startIndex..<remainderStart])
            let remainder = String(text[remainderStart...])
            if !flush.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (flush, remainder)
            }
        }

        if text.count > 1024 {
            let splitIndex = text.index(text.endIndex, offsetBy: -256)
            let flush = String(text[text.startIndex..<splitIndex])
            let remainder = String(text[splitIndex...])
            if !flush.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (flush, remainder)
            }
        }

        return nil
    }

    static func likelyAnswerCandidate(in text: String) -> Bool {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }

        if isHeadingLike(normalized) || isBulletOnlyParagraph(normalized) {
            return false
        }

        let lowercased = normalized.lowercased()
        let reasoningPrefixes = [
            "first,",
            "second,",
            "third,",
            "then ",
            "next,",
            "let me",
            "let's",
            "i need to",
            "i should",
            "okay,",
            "ok,",
            "alright,",
            "well,",
            "hmm,",
            "user query:",
            "analyze the request",
        ]
        if reasoningPrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return false
        }

        return normalized.count >= 20
    }

    static func salvagedAnswer(in text: String) -> String? {
        if let split = splitReasoningAndAnswer(in: text) {
            return split.answer
        }

        let stripped = strippingOpeningMarker(in: text)
        let normalized = stripped
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if let drafted = draftedAnswerCandidate(in: normalized) {
            return drafted
        }

        if let answerRange = answerMatch(in: normalized) {
            let answer = String(normalized[answerRange.upperBound...]).trimmingLeadingWhitespaceAndNewlines()
            return answer.isEmpty ? nil : answer
        }

        let paragraphs = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for paragraph in paragraphs.reversed() {
            if isHeadingLike(paragraph) { continue }
            if isBulletOnlyParagraph(paragraph) && paragraphs.count > 1 { continue }
            return paragraph
        }

        let lines = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines.reversed() {
            if line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("•") { continue }
            if isHeadingLike(line) { continue }
            if line.count < 12 { continue }
            return line
        }

        return nil
    }

    private static func draftedAnswerCandidate(in text: String) -> String? {
        let markers = [
            "let's write:",
            "lets write:",
            "i'll write:",
            "ill write:",
            "let's go with:",
            "lets go with:",
            "go with:",
            "response:",
            "answer:",
            "the safest and most supportive response is:",
            "the safest response is:",
        ]

        let lines = text
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "*", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        for line in lines.reversed() {
            let lowercased = line.lowercased()
            guard let marker = markers.first(where: { lowercased.contains($0) }),
                  let markerRange = lowercased.range(of: marker) else {
                continue
            }
            let distance = lowercased.distance(from: lowercased.startIndex, to: markerRange.upperBound)
            let originalIndex = line.index(line.startIndex, offsetBy: distance)
            let candidate = String(line[originalIndex...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”"))
            if candidate.count >= 12 {
                return candidate
            }
        }

        return nil
    }

    private static func isHeadingLike(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let normalized = trimmed
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if openingMarkers.contains(where: { normalized == $0.lowercased().replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "#", with: "") }) {
            return true
        }

        let wordCount = normalized.split(whereSeparator: \.isWhitespace).count
        return normalized.hasSuffix(":") && wordCount <= 4
    }

    private static func isBulletOnlyParagraph(_ text: String) -> Bool {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return false }
        return lines.allSatisfy { line in
            line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("•")
        }
    }

    private static func firstMatch(
        in text: String,
        markers: [String],
        range: Range<String.Index>,
        anchored: Bool
    ) -> Range<String.Index>? {
        markers
            .compactMap { marker in
                text.range(
                    of: marker,
                    options: anchored ? [.caseInsensitive, .anchored] : [.caseInsensitive],
                    range: range
                )
            }
            .min { $0.lowerBound < $1.lowerBound }
    }
}

// MARK: - Collection Safe Subscript

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension String {
    nonisolated func strippingThinkingBlocks() -> String {
        var cleaned = self
        while let match = ThinkingTagSyntax.openingMatch(in: cleaned),
              let endRange = cleaned.range(
                  of: match.closingTag,
                  range: match.range.upperBound..<cleaned.endIndex
              ) {
            cleaned.removeSubrange(match.range.lowerBound..<endRange.upperBound)
        }
        return cleaned
    }

    nonisolated func trimmingLeadingWhitespaceAndNewlines() -> String {
        let trimmedStart = firstIndex(where: { !$0.isWhitespace && !$0.isNewline }) ?? endIndex
        return String(self[trimmedStart...])
    }
}
