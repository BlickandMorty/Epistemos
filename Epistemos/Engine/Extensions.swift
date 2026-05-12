import Foundation

nonisolated enum FoundationSafety {
    private static let readableTextInspectionScalarLimit = 16_384

    static let applicationSupportOverrideEnvironmentKey = "EPISTEMOS_APPLICATION_SUPPORT_ROOT"

    static func isRunningTests(
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        processInfoEnvironment["XCTestConfigurationFilePath"] != nil
    }

    static func runtimeApplicationSupportDirectory(
        fileManager: FileManager = .default,
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) -> URL {
        let directory: URL
        if let override = applicationSupportOverrideDirectory(
            fileManager: fileManager,
            processInfoEnvironment: processInfoEnvironment
        ) {
            directory = override
        } else if isRunningTests(processInfoEnvironment: processInfoEnvironment) {
            directory = fileManager.temporaryDirectory
                .appendingPathComponent("Epistemos-TestRuntime", isDirectory: true)
                .appendingPathComponent(String(processIdentifier), isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        } else {
            directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory.appendingPathComponent(
                    "Application Support",
                    isDirectory: true
                )
        }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.standardizedFileURL
    }

    private static func applicationSupportOverrideDirectory(
        fileManager: FileManager,
        processInfoEnvironment: [String: String]
    ) -> URL? {
        guard let rawPath = processInfoEnvironment[applicationSupportOverrideEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawPath.isEmpty,
              rawPath.hasPrefix("/")
        else {
            return nil
        }

        let directory = URL(fileURLWithPath: rawPath, isDirectory: true).standardizedFileURL
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func regularExpression(
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression? {
        regularExpression(pattern, options: options)
    }

    static func regularExpression(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: options)
    }

    static func dataDetector(
        types: NSTextCheckingResult.CheckingType
    ) -> NSDataDetector? {
        try? NSDataDetector(types: types.rawValue)
    }

    static func userApplicationSupportDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        runtimeApplicationSupportDirectory(fileManager: fileManager)
    }

    static func modelVaultsDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        let directory = userApplicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("model_vaults", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.standardizedFileURL
    }

    static func managedToolRuntimeVaultDirectory(
        preferredVaultPath: String?,
        fileManager: FileManager = .default
    ) -> URL {
        if let preferredVaultPath {
            let trimmed = preferredVaultPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return URL(fileURLWithPath: trimmed, isDirectory: true).standardizedFileURL
            }
        }

        let directory = userApplicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("ManagedToolRuntime", isDirectory: true)
            .appendingPathComponent("ScratchVault", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.standardizedFileURL
    }

    static func utf8String(from data: Data) throws -> String {
        guard let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return string
    }

    static func decodedText(from data: Data) -> String? {
        guard !data.isEmpty else { return "" }

        var encodings: [String.Encoding] = [.utf8]
        appendDetectedUnicodeEncodings(from: data, to: &encodings)
        let fallbackEncodings: [String.Encoding] = [
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .utf32,
            .utf32LittleEndian,
            .utf32BigEndian,
        ]
        for encoding in fallbackEncodings {
            if !encodings.contains(encoding) {
                encodings.append(encoding)
            }
        }

        for encoding in encodings {
            guard let string = String(data: data, encoding: encoding) else { continue }
            let normalized = normalizedDecodedText(string)
            if looksLikeReadableText(normalized) {
                return normalized
            }
        }

        return nil
    }

    private static func appendDetectedUnicodeEncodings(from data: Data, to encodings: inout [String.Encoding]) {
        if data.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            encodings.append(.utf32LittleEndian)
            encodings.append(.utf32)
            return
        }
        if data.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            encodings.append(.utf32BigEndian)
            encodings.append(.utf32)
            return
        }
        if data.starts(with: [0xFF, 0xFE]) {
            encodings.append(.utf16LittleEndian)
            encodings.append(.utf16)
            return
        }
        if data.starts(with: [0xFE, 0xFF]) {
            encodings.append(.utf16BigEndian)
            encodings.append(.utf16)
            return
        }

        let sample = Array(data.prefix(128))
        let pairCount = sample.count / 2
        guard pairCount >= 4 else { return }

        let oddNulls = stride(from: 1, to: pairCount * 2, by: 2).reduce(into: 0) { result, index in
            if sample[index] == 0 { result += 1 }
        }
        let evenNulls = stride(from: 0, to: pairCount * 2, by: 2).reduce(into: 0) { result, index in
            if sample[index] == 0 { result += 1 }
        }

        if oddNulls * 2 >= pairCount {
            encodings.append(.utf16LittleEndian)
        }
        if evenNulls * 2 >= pairCount {
            encodings.append(.utf16BigEndian)
        }
    }

    private static func looksLikeReadableText(_ string: String) -> Bool {
        guard !string.isEmpty else { return true }

        var inspectedCount = 0
        var suspiciousCount = 0

        for scalar in string.unicodeScalars {
            guard inspectedCount < readableTextInspectionScalarLimit else { break }
            inspectedCount += 1
            let value = scalar.value
            if value == 0xFFFD {
                suspiciousCount += 1
                continue
            }
            if value == 0x09 || value == 0x0A || value == 0x0D {
                continue
            }
            if value < 0x20 || (0x7F...0x9F).contains(value) {
                suspiciousCount += 1
            }
        }

        guard inspectedCount > 0 else { return true }
        return Double(suspiciousCount) / Double(inspectedCount) <= 0.05
    }

    private static func normalizedDecodedText(_ string: String) -> String {
        var text = string
        while text.unicodeScalars.first == "\u{FEFF}" {
            text.removeFirst()
        }
        return text
    }
}

nonisolated enum ThinkingTagSyntax {
    private static let tagPairs: [(open: String, close: String)] = [
        ("<thinking>", "</thinking>"),
        ("<think>", "</think>"),
        ("<thought>", "</thought>"),
        ("<reasoning>", "</reasoning>"),
    ]

    static func openingMatch(in text: String) -> (range: Range<String.Index>, closingTag: String)? {
        tagPairs
            .compactMap { pair in
                text.range(of: pair.open).map { ($0, pair.close) }
            }
            .min { $0.range.lowerBound < $1.range.lowerBound }
    }

    static func closingMatch(in text: String) -> Range<String.Index>? {
        tagPairs
            .compactMap { pair in
                text.range(of: pair.close)
            }
            .min { $0.lowerBound < $1.lowerBound }
    }
}

nonisolated enum AssistantControlTagSyntax {
    private static let tagPairs: [(open: String, close: String)] = [
        ("<scratch_pad>", "</scratch_pad>"),
        ("<tool_response>", "</tool_response>"),
        ("<tool_call>", "</tool_call>"),
        ("<tool_call<", "</tool_call>"),
    ]

    static func openingMatch(in text: String) -> (range: Range<String.Index>, closingTag: String)? {
        tagPairs
            .compactMap { pair in
                text.range(of: pair.open).map { ($0, pair.close) }
            }
            .min { $0.range.lowerBound < $1.range.lowerBound }
    }

    static func closingMatch(in text: String) -> Range<String.Index>? {
        tagPairs
            .compactMap { pair in
                text.range(of: pair.close)
            }
            .min { $0.lowerBound < $1.lowerBound }
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
        "Final Answer:",
        "Answer:",
        "Final Response:",
        "Response:",
        "## Final Answer",
        "## Answer",
        "**Final Answer:**",
        "**Answer:**",
    ]

    private static let proseOpeningCues = [
        "let me think",
        "let's think",
        "i need to think",
        "i should think",
        "i need to review the provided text",
        "i will analyze",
        "i'll analyze",
        "im going to analyze",
        "i'm going to analyze",
        "let me analyze the content",
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
        let searchRange = text.startIndex..<text.endIndex
        var lineStart = searchRange.lowerBound

        while lineStart < searchRange.upperBound {
            let contentStart = text[lineStart...]
                .firstIndex(where: { !$0.isWhitespace && !$0.isNewline })
                ?? searchRange.upperBound
            if contentStart < searchRange.upperBound,
               let match = firstMatch(
                   in: text,
                   markers: answerMarkers,
                   range: contentStart..<searchRange.upperBound,
                   anchored: true
               ) {
                return match
            }

            guard let nextNewline = text[lineStart..<searchRange.upperBound].firstIndex(of: "\n") else {
                break
            }
            lineStart = text.index(after: nextNewline)
        }

        return nil
    }

    static func containsOnlyAnswerMarker(_ text: String) -> Bool {
        let normalized = normalizedMarkerText(text)
        guard !normalized.isEmpty else { return false }
        return answerMarkers
            .map { normalizedMarkerText($0) }
            .contains(normalized)
    }

    private static func normalizedMarkerText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
                if isHeadingLike(candidate)
                    || isBulletOnlyParagraph(candidate)
                    || isStructuredToolPayload(candidate) {
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
           !isStructuredToolPayload(answerLine),
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
            "to answer this",
            "to answer the user",
            "to respond well",
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
            if isStructuredToolPayload(paragraph) { continue }
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

    private static func isStructuredToolPayload(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = normalized.lowercased()
        if lowercased.contains("here is the function call:") {
            return true
        }
        if lowercased.contains("```tool_call") {
            return true
        }
        guard normalized.contains("\"name\""), normalized.contains("\"arguments\"") else { return false }
        return true
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
        while let closingRange = ThinkingTagSyntax.closingMatch(in: cleaned) {
            cleaned.removeSubrange(closingRange)
        }
        return cleaned
    }

    nonisolated func trimmingLeadingWhitespaceAndNewlines() -> String {
        let trimmedStart = firstIndex(where: { !$0.isWhitespace && !$0.isNewline }) ?? endIndex
        return String(self[trimmedStart...])
    }
}

nonisolated enum UserFacingModelOutput {
    private enum IncompleteThinkingRecoveryMode {
        case streaming
        case final
    }

    // Reasoning-paragraph prefixes. These must stay tightly scoped to
    // reasoning-specific markers. Generic answer openers and answer markers
    // are handled separately so a natural answer that begins with
    // "Let me start by…" or "Answer:" does not get suppressed as if it were
    // scratchpad leakage.
    private static let reasoningParagraphPrefixes = [
        "here's a thinking process",
        "here is a thinking process",
        "here's the thinking process",
        "here is the thinking process",
        "thinking process:",
        "thinking process",
        "thought process:",
        "thought process",
        "reasoning:",
        "deconstruct the request",
        "analyze the request",
        "analyze the input",
        "implicit need:",
        "correction/refinement:",
        "most likely interpretation:",
        "self-correction during drafting:",
        "final review against safety guidelines:",
        "refining the tone:",
        "let's check if",
        "lets check if",
        "wait, one more possibility",
        "wait, is it possible",
        "wait, could it be",
        "does this promote hate speech?",
        "is it politically sensitive?",
        "ensure i don't validate",
        "maintain neutrality.",
        "acknowledge the complexity.",
        "detailed analysis",
        "detailed analysis with",
        "pattern identification:",
        "here is the function call:",
        "reduce strategy:",
        "i need to review the provided text",
        "i will analyze the provided text",
        "i'll analyze the provided text",
        "let me analyze the content",
        "key points include:",
    ]

    static func streamingVisibleText(from raw: String) -> String {
        let cleaned = cleanedStreamingText(from: raw)
        guard !cleaned.isEmpty else { return "" }
        guard !isOnlyDanglingAnswerMarker(cleaned) else { return "" }
        guard !isOnlyDanglingFenceLanguageMarker(raw: raw, cleaned: cleaned) else { return "" }
        guard !isOnlyStructuredToolPayloadFragment(cleaned) else { return "" }

        if let directAnswer = directAnswerText(in: cleaned) {
            return directAnswer
        }

        let hasReasoningArtifacts = containsReasoningArtifacts(raw: raw, cleaned: cleaned)
        guard hasReasoningArtifacts else {
            return cleaned
        }

        return containsResidualReasoningArtifacts(in: cleaned) ? "" : cleaned
    }

    static func streamingReasoningText(from raw: String) -> String {
        let cleaned = cleanedStreamingReasoningText(from: raw)
        guard !cleaned.isEmpty else { return "" }
        guard !isOnlyDanglingAnswerMarker(cleaned) else { return "" }
        guard streamingVisibleText(from: raw).isEmpty else { return "" }
        let hasReasoningArtifacts = containsReasoningArtifacts(raw: raw, cleaned: cleaned)
        guard hasReasoningArtifacts else { return "" }
        return cleaned
    }

    static func finalVisibleText(from raw: String) -> String {
        let cleaned = cleanedVisibleText(from: raw, suppressIncompleteThinkingTail: true)
        guard !cleaned.isEmpty else { return "" }
        guard !isOnlyDanglingAnswerMarker(cleaned) else { return "" }
        guard !isOnlyDanglingFenceLanguageMarker(raw: raw, cleaned: cleaned) else { return "" }
        guard !isOnlyStructuredToolPayloadFragment(cleaned) else { return "" }

        if let directAnswer = directAnswerText(in: cleaned) {
            return directAnswer
        }

        let hasReasoningArtifacts = containsReasoningArtifacts(raw: raw, cleaned: cleaned)
        guard hasReasoningArtifacts else {
            return cleaned
        }

        if let candidate = bestAnswerCandidate(in: cleaned) {
            return candidate
        }

        // Fail-open when the split heuristic can't find a clean
        // reasoning/answer boundary but the text DOESN'T look like a pure
        // reasoning dump (no explicit prelude, no prose opener, no structured
        // reasoning plan). Historically we returned "" here, which ate
        // legitimate natural-language answers when a single paragraph happened
        // to match a reasoning prefix. Surfacing `cleaned` beats silent empty:
        // worst case the user sees slightly verbose output, best case they
        // finally see their answer.
        let looksLikePureReasoningDump = rawLooksLikePureReasoning(raw: raw)
            || ThinkingPreludeSyntax.openingMatch(in: cleaned) != nil
            || ThinkingPreludeSyntax.proseOpeningDetected(in: cleaned)
            || containsStructuredReasoningPlan(in: cleaned)
            || allParagraphsAreReasoning(in: cleaned)
        return looksLikePureReasoningDump ? "" : cleaned
    }

    private static func rawLooksLikePureReasoning(raw: String) -> Bool {
        // Treat input that was delivered via explicit `<thinking>` tags or
        // assistant-control envelopes as a pure reasoning payload. We already
        // stripped those from `cleaned`, so if the raw stream contained them
        // AND we couldn't split an answer out, there's no user-facing text
        // to reveal — the model really only produced reasoning.
        ThinkingTagSyntax.openingMatch(in: raw) != nil
            || AssistantControlTagSyntax.openingMatch(in: raw) != nil
            || AssistantControlTagSyntax.closingMatch(in: raw) != nil
    }

    private static func allParagraphsAreReasoning(in text: String) -> Bool {
        let paragraphList = paragraphs(in: text)
        guard !paragraphList.isEmpty else { return false }
        return paragraphList.allSatisfy(isReasoningParagraph)
    }

    private static func isOnlyDanglingAnswerMarker(_ text: String) -> Bool {
        ThinkingPreludeSyntax.containsOnlyAnswerMarker(text)
    }

    private static func isOnlyDanglingFenceLanguageMarker(raw: String, cleaned: String) -> Bool {
        let normalizedRaw = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedRaw.hasPrefix("```"),
              !normalizedRaw.contains("\n") else {
            return false
        }

        let fenceLanguage = normalizedRaw
            .dropFirst(3)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedCleaned = cleaned
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalizedCleaned == normalizedRaw.lowercased() {
            return true
        }

        if fenceLanguage.isEmpty {
            return normalizedCleaned == "```"
        }

        return normalizedCleaned == fenceLanguage
    }

    private static func isOnlyStructuredToolPayloadFragment(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }

        let lowercased = normalized.lowercased()
        if lowercased.contains("<tool_call") || lowercased.contains("```tool_call") {
            return true
        }

        guard normalized.contains("\"name\""), normalized.contains("\"arguments\"") else {
            return false
        }

        return normalized.hasPrefix("{")
    }

    static func incompleteReasoningFallback(from rawThinking: String) -> String? {
        let trimmed = rawThinking.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "The model finished its thinking trace but never produced a final answer. Try Fast mode, a lower thinking level, or another model."
    }

    static func salvagedAnswerFromThinkingTrace(from rawThinking: String) -> String? {
        let trimmed = rawThinking.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directAnswer = directAnswerText(in: trimmed) {
            return directAnswer
        }

        if let boundary = ThinkingPreludeSyntax.answerBoundary(in: trimmed) {
            let answer = String(trimmed[boundary.answerStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return answer.isEmpty ? nil : answer
        }

        // Native reasoning summaries from cloud providers are often a
        // single short fragment ("Checking the note…" / "What's weaker")
        // rather than a hidden answer. Only salvage free-form thinking
        // when it has multiple paragraphs and the last paragraph looks
        // like a real user-facing sentence.
        guard paragraphs(in: trimmed).count >= 2,
              let candidate = bestAnswerCandidate(in: trimmed)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              isPlausibleThinkingSalvageCandidate(candidate) else {
            return nil
        }

        return candidate
    }

    static func streamingStandaloneAnswerChunk(
        _ chunk: String,
        afterReasoningRaw priorRaw: String
    ) -> String? {
        let trimmedChunk = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedChunk.isEmpty else { return nil }
        guard !isOnlyDanglingAnswerMarker(trimmedChunk) else { return nil }
        guard !isReasoningParagraph(trimmedChunk) else { return nil }
        guard !isStructuredToolPayload(trimmedChunk) else { return nil }

        if let directAnswer = directAnswerText(in: trimmedChunk) {
            return directAnswer
        }

        if ThinkingPreludeSyntax.answerMatch(in: priorRaw) != nil {
            let combinedFinal = finalVisibleText(from: priorRaw + chunk)
            if !combinedFinal.isEmpty {
                return combinedFinal
            }
        }

        let priorClosedHiddenReasoning =
            ThinkingTagSyntax.closingMatch(in: priorRaw) != nil
            || AssistantControlTagSyntax.closingMatch(in: priorRaw) != nil
        if priorClosedHiddenReasoning {
            return trimmedChunk
        }

        if containsStructuredReasoningPlan(in: priorRaw) {
            return trimmedChunk
        }

        return nil
    }

    private static func cleanedVisibleText(
        from raw: String,
        suppressIncompleteThinkingTail: Bool
    ) -> String {
        strippedThinkingArtifacts(
            in: raw,
            suppressIncompleteThinkingTail: suppressIncompleteThinkingTail,
            recoveryMode: .final
        )
        .replacingOccurrences(of: "\r\n", with: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanedStreamingText(from raw: String) -> String {
        strippedThinkingArtifacts(
            in: raw,
            suppressIncompleteThinkingTail: true,
            recoveryMode: .streaming
        )
        .replacingOccurrences(of: "\r\n", with: "\n")
        .trimmingLeadingWhitespaceAndNewlines()
    }

    private static func cleanedStreamingReasoningText(from raw: String) -> String {
        let cleaned = cleanedStreamingText(from: raw)
        guard !cleaned.isEmpty else { return "" }

        if let boundary = ThinkingPreludeSyntax.answerBoundary(in: cleaned) {
            let reasoning = String(cleaned[..<boundary.reasoningEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return reasoning
        }

        return cleaned
    }

    private static func strippedThinkingArtifacts(
        in raw: String,
        suppressIncompleteThinkingTail: Bool,
        recoveryMode: IncompleteThinkingRecoveryMode
    ) -> String {
        var cleaned = raw
        cleaned = stripDelimitedArtifacts(
            in: cleaned,
            openingMatch: ThinkingTagSyntax.openingMatch(in:),
            closingMatch: ThinkingTagSyntax.closingMatch(in:),
            suppressIncompleteTail: suppressIncompleteThinkingTail,
            recoveryMode: recoveryMode
        )
        cleaned = stripDelimitedArtifacts(
            in: cleaned,
            openingMatch: AssistantControlTagSyntax.openingMatch(in:),
            closingMatch: AssistantControlTagSyntax.closingMatch(in:),
            suppressIncompleteTail: suppressIncompleteThinkingTail,
            recoveryMode: recoveryMode
        )
        return cleaned
    }

    private static func stripDelimitedArtifacts(
        in text: String,
        openingMatch: (String) -> (range: Range<String.Index>, closingTag: String)?,
        closingMatch: (String) -> Range<String.Index>?,
        suppressIncompleteTail: Bool,
        recoveryMode: IncompleteThinkingRecoveryMode
    ) -> String {
        var cleaned = text

        while let match = openingMatch(cleaned) {
            if let endRange = cleaned.range(
                of: match.closingTag,
                range: match.range.upperBound..<cleaned.endIndex
            ) {
                cleaned.removeSubrange(match.range.lowerBound..<endRange.upperBound)
                continue
            }

            guard suppressIncompleteTail else { break }
            let incompleteTail = String(cleaned[match.range.upperBound...])
            if let recovered = recoveredTextFromIncompleteThinkingTail(
                incompleteTail,
                mode: recoveryMode
            ) {
                cleaned.replaceSubrange(match.range.lowerBound..<cleaned.endIndex, with: recovered)
            } else {
                cleaned.removeSubrange(match.range.lowerBound..<cleaned.endIndex)
            }
            break
        }

        while let closingRange = closingMatch(cleaned) {
            let trailingVisibleText = String(cleaned[closingRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if trailingVisibleText.isEmpty {
                cleaned.removeSubrange(closingRange)
            } else {
                cleaned = String(cleaned[closingRange.upperBound...])
            }
        }

        return cleaned
    }

    private static func recoveredTextFromIncompleteThinkingTail(
        _ tail: String,
        mode: IncompleteThinkingRecoveryMode
    ) -> String? {
        let normalized = tail
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if let answerRange = ThinkingPreludeSyntax.answerMatch(in: normalized) {
            let answer = String(normalized[answerRange.upperBound...]).trimmingLeadingWhitespaceAndNewlines()
            return answer.isEmpty ? nil : answer
        }

        if let boundary = ThinkingPreludeSyntax.answerBoundary(in: normalized) {
            let answer = String(normalized[boundary.answerStart...]).trimmingLeadingWhitespaceAndNewlines()
            return answer.isEmpty ? nil : answer
        }

        switch mode {
        case .streaming:
            return nil
        case .final:
            return bestAnswerCandidate(in: normalized)
        }
    }

    private static func containsReasoningArtifacts(raw: String, cleaned: String) -> Bool {
        if ThinkingTagSyntax.openingMatch(in: raw) != nil
            || AssistantControlTagSyntax.openingMatch(in: raw) != nil
            || AssistantControlTagSyntax.closingMatch(in: raw) != nil {
            return true
        }
        return containsResidualReasoningArtifacts(in: cleaned)
            || containsResidualAssistantControlArtifacts(in: cleaned)
    }

    private static func containsResidualReasoningArtifacts(in cleaned: String) -> Bool {
        if containsStructuredReasoningPlan(in: cleaned) {
            return true
        }
        if ThinkingPreludeSyntax.openingMatch(in: cleaned) != nil {
            return true
        }
        if ThinkingPreludeSyntax.proseOpeningDetected(in: cleaned) {
            return true
        }
        if hasIncompleteReasoningLeadIn(cleaned) {
            return true
        }

        return paragraphs(in: cleaned).contains(where: isReasoningParagraph)
    }

    private static func containsResidualAssistantControlArtifacts(in cleaned: String) -> Bool {
        AssistantControlTagSyntax.openingMatch(in: cleaned) != nil
            || AssistantControlTagSyntax.closingMatch(in: cleaned) != nil
    }

    private static func directAnswerText(in text: String) -> String? {
        guard let answerRange = ThinkingPreludeSyntax.answerMatch(in: text) else { return nil }
        let answer = String(text[answerRange.upperBound...]).trimmingLeadingWhitespaceAndNewlines()
        return answer.isEmpty ? nil : answer
    }

    private static func bestAnswerCandidate(in text: String) -> String? {
        // Gate structured-reasoning-plan detection FIRST. The generic salvage
        // path (below) will otherwise return a plan's trailing
        // "this approach will efficiently …" conclusion as the answer, even
        // though that line is itself a plan descriptor. Only trust a
        // structured-plan candidate when an explicit answer marker appears
        // elsewhere in the text.
        let textLooksLikeStructuredPlan = containsStructuredReasoningPlan(in: text)
        if textLooksLikeStructuredPlan,
           ThinkingPreludeSyntax.answerMatch(in: text) == nil {
            return nil
        }

        if let split = ThinkingPreludeSyntax.splitReasoningAndAnswer(in: text) {
            let answer = split.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !answer.isEmpty {
                return answer
            }
        }

        if let salvaged = ThinkingPreludeSyntax.salvagedAnswer(in: text)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !salvaged.isEmpty,
           !isReasoningParagraph(salvaged) {
            return salvaged
        }

        if textLooksLikeStructuredPlan,
           let structuredLineCandidate = bestStructuredPlanLineCandidate(in: text) {
            return structuredLineCandidate
        }

        let filteredParagraphs = paragraphs(in: text).filter {
            !isReasoningParagraph($0) && !isStructuredToolPayload($0)
        }
        if let lastParagraph = filteredParagraphs.last, !lastParagraph.isEmpty {
            return lastParagraph
        }

        return nil
    }

    private static func paragraphs(in text: String) -> [String] {
        text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func bestStructuredPlanLineCandidate(in text: String) -> String? {
        let filteredLines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !isStructuredReasoningLine($0) }

        guard let lastLine = filteredLines.last, !lastLine.isEmpty else { return nil }
        return lastLine
    }

    private static func isReasoningParagraph(_ paragraph: String) -> Bool {
        let normalized = normalizedReasoningText(paragraph)

        guard !normalized.isEmpty else { return true }

        if isToolPlanningNarrative(normalized) {
            return true
        }

        if isStructuredToolPayload(paragraph) {
            return true
        }

        if containsStructuredReasoningPlan(in: normalized) {
            return true
        }

        if reasoningParagraphPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return true
        }

        if normalized.hasPrefix("1.") || normalized.hasPrefix("2.") || normalized.hasPrefix("3.") {
            return normalized.contains("deconstruct") || normalized.contains("analyze")
        }

        if normalized.hasPrefix("- ") || normalized.hasPrefix("• ") {
            return normalized.contains("maintain neutrality") ||
                normalized.contains("acknowledge the complexity") ||
                normalized.contains("does this promote hate speech") ||
                normalized.contains("is it politically sensitive")
        }

        if normalized.hasPrefix("wait,") || normalized.hasPrefix("let's ") || normalized.hasPrefix("lets ") {
            return true
        }

        if normalized.hasPrefix("to answer this")
            || normalized.hasPrefix("to answer the user")
            || normalized.hasPrefix("to respond well")
            || normalized.hasPrefix("i need to review the provided text")
            || normalized.hasPrefix("let me analyze the content") {
            return true
        }

        return false
    }

    private static func isToolPlanningNarrative(_ normalized: String) -> Bool {
        let leadIns = [
            "i'll begin by",
            "ill begin by",
            "i will begin by",
            "let me start by",
            "i'll start by",
            "ill start by",
            "i will start by",
            "i'll call the",
            "ill call the",
            "i will call the",
            "i'm calling the",
            "im calling the",
            "i am calling the",
            "i'll use the",
            "ill use the",
            "i will use the",
            "i'm going to use the",
            "im going to use the",
            "i am going to use the",
            "i'll invoke the",
            "ill invoke the",
            "i will invoke the",
        ]
        guard leadIns.contains(where: { normalized.hasPrefix($0) }) else {
            return false
        }

        let actionMarkers = [
            " call ",
            " calling ",
            " test ",
            " testing ",
            " invoke ",
            " invoking ",
            " inspect ",
            " inspecting ",
            " try ",
            " trying ",
        ]
        let targetMarkers = [
            " function",
            " functions",
            " tool",
            " tools",
            " arguments",
            " parameters",
            " find_symbol",
            " file.read",
            " read_file",
            " web.search",
            " web_search",
        ]

        let containsAction = actionMarkers.contains(where: normalized.contains)
            || normalized.contains("functions available")
        let containsTarget = targetMarkers.contains(where: normalized.contains)

        return containsAction && containsTarget
    }

    private static func isStructuredReasoningLine(_ line: String) -> Bool {
        let normalized = normalizedReasoningText(line)
        guard !normalized.isEmpty else { return true }

        if normalized.hasPrefix("1. ") || normalized.hasPrefix("2. ") || normalized.hasPrefix("3. ") {
            return true
        }

        if normalized.hasPrefix("- ") || normalized.hasPrefix("• ") {
            return true
        }

        return reasoningParagraphPrefixes.contains(where: { normalized.hasPrefix($0) })
    }

    private static func containsStructuredReasoningPlan(in text: String) -> Bool {
        let normalized = normalizedReasoningText(text)
        let markers = [
            "1. query:",
            "2. detailed analysis",
            "3. pattern identification:",
            "input text:",
            "reduce strategy:",
        ]
        let matchedMarkers = markers.reduce(into: 0) { count, marker in
            if normalized.contains(marker) {
                count += 1
            }
        }
        return matchedMarkers >= 2
    }

    private static func hasIncompleteReasoningLeadIn(_ text: String) -> Bool {
        let normalized = normalizedReasoningText(text)
        guard normalized.count >= 8 else { return false }

        return reasoningParagraphPrefixes.contains { prefix in
            prefix.hasPrefix(normalized)
        }
    }

    private static func normalizedReasoningText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func isStructuredToolPayload(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = normalized.lowercased()
        if lowercased.contains("```tool_call") {
            return true
        }
        guard normalized.first == "{", normalized.last == "}" else { return false }
        return normalized.contains("\"name\"") && normalized.contains("\"arguments\"")
    }

    private static func isPlausibleThinkingSalvageCandidate(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !isReasoningParagraph(trimmed) else { return false }

        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
        guard wordCount >= 6, trimmed.count >= 24 else { return false }

        let hasSentencePunctuation = trimmed.contains { ".!?".contains($0) }
        let hasLineBreak = trimmed.contains("\n")
        return hasSentencePunctuation || hasLineBreak
    }
}

nonisolated struct BorrowedUTF8StringCacheStats: Sendable, Equatable {
    let hits: UInt64
    let misses: UInt64
    let uniqueStrings: Int
}

nonisolated final class BorrowedUTF8StringCache {
    private var buckets: [UInt64: [String]] = [:]
    private(set) var hits: UInt64 = 0
    private(set) var misses: UInt64 = 0

    init() {}

    func string(for slice: GraphEngineStringSlice) -> String {
        guard let ptr = slice.ptr, slice.len > 0 else { return "" }
        let bytes = UnsafeBufferPointer(start: ptr, count: Int(slice.len))
        let hash = Self.hash(bytes)
        if let bucket = buckets[hash] {
            for candidate in bucket where Self.matches(candidate, bytes: bytes) {
                hits &+= 1
                return candidate
            }
        }

        let decoded = String(decoding: bytes, as: UTF8.self)
        buckets[hash, default: []].append(decoded)
        misses &+= 1
        return decoded
    }

    func stats() -> BorrowedUTF8StringCacheStats {
        BorrowedUTF8StringCacheStats(
            hits: hits,
            misses: misses,
            uniqueStrings: buckets.values.reduce(0) { $0 + $1.count }
        )
    }

    private static func hash(_ bytes: UnsafeBufferPointer<UInt8>) -> UInt64 {
        var value: UInt64 = 0xcbf29ce484222325
        for byte in bytes {
            value ^= UInt64(byte)
            value &*= 0x100000001b3
        }
        return value
    }

    private static func matches(_ candidate: String, bytes: UnsafeBufferPointer<UInt8>) -> Bool {
        guard candidate.utf8.count == bytes.count else { return false }
        return candidate.utf8.elementsEqual(bytes)
    }
}

@discardableResult
nonisolated func withStableCStringArray<T>(
    _ strings: [String],
    _ body: (UnsafeMutableBufferPointer<UnsafePointer<CChar>?>) -> T
) -> T? {
    let cStrings = strings.compactMap { strdup($0) }
    guard cStrings.count == strings.count else {
        cStrings.forEach { free($0) }
        return nil
    }
    defer { cStrings.forEach { free($0) } }

    var pointers: [UnsafePointer<CChar>?] = cStrings.map { UnsafePointer($0) }
    return pointers.withUnsafeMutableBufferPointer { buffer in
        body(buffer)
    }
}

nonisolated struct TrigramSearchIndex<Key: Hashable> {
    private var postingLists: [String: [Key]] = [:]

    init() {}

    mutating func rebuild<S: Sequence>(_ entries: S) where S.Element == (key: Key, text: String) {
        postingLists.removeAll(keepingCapacity: true)

        for entry in entries {
            for trigram in Self.trigrams(from: entry.text) {
                postingLists[trigram, default: []].append(entry.key)
            }
        }
    }

    func orderedCandidates(for query: String) -> [Key]? {
        let queryTrigrams = Self.trigrams(from: query)
        guard !queryTrigrams.isEmpty else { return nil }

        let postings = queryTrigrams.compactMap { postingLists[$0] }.sorted { $0.count < $1.count }
        guard let base = postings.first else { return [] }
        guard postings.count > 1 else { return base }

        var remainderSets: [Set<Key>] = []
        remainderSets.reserveCapacity(postings.count - 1)
        for posting in postings.dropFirst() {
            remainderSets.append(Set(posting))
        }

        return base.filter { key in
            remainderSets.allSatisfy { $0.contains(key) }
        }
    }

    private static func trigrams(from text: String) -> Set<String> {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let characters = Array(normalized)
        guard characters.count >= 3 else { return [] }

        var trigrams: Set<String> = []
        trigrams.reserveCapacity(characters.count - 2)

        for index in 0..<(characters.count - 2) {
            trigrams.insert(String(characters[index...(index + 2)]))
        }

        return trigrams
    }
}
