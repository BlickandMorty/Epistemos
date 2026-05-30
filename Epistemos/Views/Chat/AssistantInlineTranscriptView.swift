import Foundation
import SwiftUI

struct AssistantInlineTranscriptTool: Equatable, Sendable {
    let id: String
    let name: String
    let input: [String: JSONValue]
    var result: String?
    var isError: Bool
}

struct AssistantInlineTranscriptSegment: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case text(String)
        case thinking(String)
        case tool(AssistantInlineTranscriptTool)
    }

    let id: String
    var kind: Kind

    var isThinking: Bool {
        if case .thinking = kind { return true }
        return false
    }

    var textContent: String? {
        switch kind {
        case .text(let text), .thinking(let text):
            return text
        case .tool:
            return nil
        }
    }

    var tool: AssistantInlineTranscriptTool? {
        if case .tool(let tool) = kind { return tool }
        return nil
    }
}

nonisolated enum AssistantInlineTranscriptBuilder {
    static func segments(
        rawContent: String,
        displayContent: String,
        contentBlocks: [MessageContentBlock]?
    ) -> [AssistantInlineTranscriptSegment] {
        let taggedSegments = segmentsFromTaggedToolCalls(rawContent)
        if !taggedSegments.isEmpty {
            return appendDisplayContentIfNeeded(displayContent, to: taggedSegments)
        }

        let structuredSegments = segmentsFromContentBlocks(contentBlocks)
        if !structuredSegments.isEmpty {
            return appendDisplayContentIfNeeded(displayContent, to: structuredSegments)
        }

        let visible = cleanedTranscriptText(displayContent)
        return visible.isEmpty ? [] : [segment(.text(visible), index: 0)]
    }

    static func segments(
        rawContent: String,
        displayContent: String,
        contentBlocks: [MessageContentBlock]?,
        persistedThinking: String?
    ) -> [AssistantInlineTranscriptSegment] {
        var built = segments(
            rawContent: rawContent,
            displayContent: displayContent,
            contentBlocks: contentBlocks
        )
        let thinking = cleanedTranscriptText(persistedThinking ?? "")
        guard !thinking.isEmpty,
              !built.contains(where: { segment in
                  guard case .thinking(let text) = segment.kind else { return false }
                  return text == thinking
              }) else {
            return built
        }

        built.insert(segment(.thinking(thinking), index: -1), at: 0)
        return rebuiltIDs(for: built)
    }

    private static let toolTagPairs: [(open: String, close: String)] = [
        ("<function_call>", "</function_call>"),
        ("<action>", "</action>"),
        ("<tool_call>", "</tool_call>"),
        ("```tool_call", "```"),
    ]

    private static func segmentsFromTaggedToolCalls(_ raw: String) -> [AssistantInlineTranscriptSegment] {
        var output: [AssistantInlineTranscriptSegment] = []
        var cursor = raw.startIndex

        while cursor < raw.endIndex,
              let match = nextToolTag(in: raw, from: cursor),
              let closeRange = raw.range(
                  of: match.close,
                  options: [.caseInsensitive],
                  range: match.open.upperBound..<raw.endIndex
              ) {
            appendThinkingSegment(String(raw[cursor..<match.open.lowerBound]), to: &output)

            let body = String(raw[match.open.upperBound..<closeRange.lowerBound])
            output.append(segment(.tool(parsedTool(from: body, index: output.count)), index: output.count))
            cursor = closeRange.upperBound
        }

        guard !output.isEmpty else { return [] }
        appendFinalTextSegment(String(raw[cursor...]), to: &output)
        return rebuiltIDs(for: output)
    }

    private static func segmentsFromContentBlocks(_ blocks: [MessageContentBlock]?) -> [AssistantInlineTranscriptSegment] {
        guard let blocks, !blocks.isEmpty else { return [] }

        var output: [AssistantInlineTranscriptSegment] = []
        var toolIndexByID: [String: Int] = [:]

        for block in blocks {
            switch block {
            case .text(let text):
                appendTextSegment(text, to: &output)
            case .thinking(let text):
                appendThinkingSegment(text, to: &output)
            case .toolUse(let id, let name, let input):
                let tool = AssistantInlineTranscriptTool(
                    id: id,
                    name: name,
                    input: input,
                    result: nil,
                    isError: false
                )
                toolIndexByID[id] = output.count
                output.append(segment(.tool(tool), index: output.count))
            case .toolResult(let toolUseId, let content, let isError):
                let result = cleanedTranscriptText(content)
                if let index = toolIndexByID[toolUseId],
                   case .tool(var tool) = output[index].kind {
                    tool.result = result
                    tool.isError = isError
                    output[index].kind = .tool(tool)
                } else {
                    let tool = AssistantInlineTranscriptTool(
                        id: toolUseId,
                        name: "tool",
                        input: [:],
                        result: result,
                        isError: isError
                    )
                    toolIndexByID[toolUseId] = output.count
                    output.append(segment(.tool(tool), index: output.count))
                }
            case .image:
                continue
            }
        }

        return rebuiltIDs(for: output)
    }

    private static func nextToolTag(
        in raw: String,
        from start: String.Index
    ) -> (open: Range<String.Index>, close: String)? {
        toolTagPairs
            .compactMap { pair -> (open: Range<String.Index>, close: String)? in
                guard let range = raw.range(
                    of: pair.open,
                    options: [.caseInsensitive],
                    range: start..<raw.endIndex
                ) else {
                    return nil
                }
                return (range, pair.close)
            }
            .min { lhs, rhs in lhs.open.lowerBound < rhs.open.lowerBound }
    }

    private static func appendThinkingSegment(_ text: String, to output: inout [AssistantInlineTranscriptSegment]) {
        let cleaned = cleanedTranscriptText(text)
        guard !cleaned.isEmpty else { return }
        output.append(segment(.thinking(cleaned), index: output.count))
    }

    private static func appendTextSegment(_ text: String, to output: inout [AssistantInlineTranscriptSegment]) {
        let cleaned = cleanedTranscriptText(text)
        guard !cleaned.isEmpty else { return }
        output.append(segment(.text(cleaned), index: output.count))
    }

    private static func appendFinalTextSegment(_ text: String, to output: inout [AssistantInlineTranscriptSegment]) {
        appendTextSegment(text, to: &output)
    }

    private static func appendDisplayContentIfNeeded(
        _ displayContent: String,
        to segments: [AssistantInlineTranscriptSegment]
    ) -> [AssistantInlineTranscriptSegment] {
        let display = cleanedTranscriptText(displayContent)
        guard !display.isEmpty else { return rebuiltIDs(for: segments) }

        let hasSameText = segments.contains { segment in
            guard case .text(let text) = segment.kind else { return false }
            return text == display
        }
        guard !hasSameText else { return rebuiltIDs(for: segments) }

        var merged = segments
        merged.append(segment(.text(display), index: merged.count))
        return rebuiltIDs(for: merged)
    }

    private static func parsedTool(from rawBody: String, index: Int) -> AssistantInlineTranscriptTool {
        let body = extractedJSONObjectText(from: rawBody) ?? cleanedTranscriptText(rawBody)
        let decoded = decodeJSONObject(body)
        let name = decoded.flatMap { stringValue($0["name"]) ?? stringValue($0["type"]) } ?? "tool"
        let input = decoded.map(toolInput(from:)) ?? ["raw": .string(body)]

        return AssistantInlineTranscriptTool(
            id: "inline-tool-\(index)-\(name)",
            name: name,
            input: input,
            result: nil,
            isError: false
        )
    }

    private static func toolInput(from decoded: [String: JSONValue]) -> [String: JSONValue] {
        if case .object(let arguments)? = decoded["arguments"] {
            return arguments
        }
        if case .object(let content)? = decoded["content"] {
            return content
        }
        if case .object(let parameters)? = decoded["parameters"] {
            return parameters
        }

        var input = decoded
        input.removeValue(forKey: "name")
        input.removeValue(forKey: "type")
        return input.isEmpty ? decoded : input
    }

    private static func decodeJSONObject(_ text: String) -> [String: JSONValue]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: JSONValue].self, from: data)
    }

    private static func extractedJSONObjectText(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start <= end else {
            return nil
        }
        return String(text[start...end])
    }

    private static func stringValue(_ value: JSONValue?) -> String? {
        guard case .string(let string)? = value else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func cleanedTranscriptText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed != "Tool" && trimmed != "Assistant"
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func segment(
        _ kind: AssistantInlineTranscriptSegment.Kind,
        index: Int
    ) -> AssistantInlineTranscriptSegment {
        AssistantInlineTranscriptSegment(id: "inline-transcript-\(index)", kind: kind)
    }

    private static func rebuiltIDs(
        for segments: [AssistantInlineTranscriptSegment]
    ) -> [AssistantInlineTranscriptSegment] {
        segments.enumerated().map { index, segment in
            AssistantInlineTranscriptSegment(id: "inline-transcript-\(index)", kind: segment.kind)
        }
    }
}

struct AssistantInlineTranscriptView: View {
    let rawContent: String
    let displayContent: String
    let contentBlocks: [MessageContentBlock]?
    let persistedThinking: String?
    let thinkingDurationSeconds: Double?
    let isStreaming: Bool
    let theme: EpistemosTheme

    private var segments: [AssistantInlineTranscriptSegment] {
        AssistantInlineTranscriptBuilder.segments(
            rawContent: rawContent,
            displayContent: displayContent,
            contentBlocks: contentBlocks,
            persistedThinking: persistedThinking
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(segments) { segment in
                switch segment.kind {
                case .text(let text):
                    TaggedMarkdownTextView(
                        content: text,
                        theme: theme,
                        typographyRole: .assistant
                    )
                case .thinking(let text):
                    InlineThinkingTranscriptSegment(
                        content: text,
                        durationSeconds: thinkingDurationSeconds
                    )
                case .tool(let tool):
                    InlineToolTranscriptSegment(
                        tool: tool,
                        isStreaming: isStreaming
                    )
                }
            }
        }
    }
}

private struct InlineThinkingTranscriptSegment: View {
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let content: String
    let durationSeconds: Double?

    @State private var isExpanded = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text("Thinking")
                        .font(ClaudeAppTypography.assistantFont(size: 14, weight: .medium))
                        .foregroundStyle(theme.textSecondary)

                    Text(summary)
                        .font(ClaudeAppTypography.userFont(size: 13))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ProcessDisclosureTextBlock(content: content, tone: .thinking)
                    .padding(.vertical, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var summary: String {
        if let duration = durationSeconds,
           duration.isFinite,
           duration >= 1 {
            return "for \(Int(duration.rounded()))s"
        }
        let firstLine = content
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.isEmpty ? "\(content.split(separator: " ").count) words" : firstLine
    }
}

private struct InlineToolTranscriptSegment: View {
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let tool: AssistantInlineTranscriptTool
    let isStreaming: Bool

    @State private var isExpanded = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Image(systemName: tool.isError ? "exclamationmark.octagon" : "terminal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(statusColor)

                    Text(statusVerb)
                        .font(ClaudeAppTypography.assistantFont(size: 14, weight: .medium))
                        .foregroundStyle(theme.textSecondary)

                    Text(summary)
                        .font(ClaudeAppTypography.monoFont(size: 12))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if isStreaming && tool.result == nil {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(statusColor)
                    } else {
                        Text(statusLabel)
                            .font(ClaudeAppTypography.monoFont(size: 10, weight: .semibold))
                            .foregroundStyle(statusColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if !inputDetail.isEmpty {
                        ProcessDisclosureDetailBlock(
                            title: "Input",
                            content: inputDetail,
                            tone: tool.isError ? .error : .tool
                        )
                    }
                    if let result = tool.result, !result.isEmpty {
                        ProcessDisclosureDetailBlock(
                            title: "Result",
                            content: String(result.prefix(800)),
                            tone: tool.isError ? .error : .success
                        )
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.card.opacity(theme.isDark ? 0.62 : 0.76))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(statusColor.opacity(theme.isDark ? 0.34 : 0.22), lineWidth: 0.8)
        }
    }

    private var statusVerb: String {
        if isStreaming && tool.result == nil { return "Running" }
        if tool.result != nil { return "Ran" }
        return "Tool use"
    }

    private var statusLabel: String {
        if tool.isError { return "ERROR" }
        if tool.result != nil { return "SUCCESS" }
        return "REQUESTED"
    }

    private var statusColor: Color {
        if tool.isError { return theme.error }
        if tool.result != nil { return theme.success }
        return theme.textTertiary
    }

    private var summary: String {
        let json = prettyPrintedJSON(tool.input)
        return ToolActivityNarrator.phrase(name: tool.name, inputJson: compactJSON(tool.input))
            ?? (json.isEmpty ? tool.name : "\(tool.name) \(String(json.prefix(80)))")
    }

    private var inputDetail: String {
        prettyPrintedJSON(tool.input)
    }

    private func compactJSON(_ object: [String: JSONValue]) -> String? {
        guard !object.isEmpty,
              JSONSerialization.isValidJSONObject(jsonObject(object)),
              let data = try? JSONSerialization.data(withJSONObject: jsonObject(object), options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private func prettyPrintedJSON(_ object: [String: JSONValue]) -> String {
        guard !object.isEmpty,
              JSONSerialization.isValidJSONObject(jsonObject(object)),
              let data = try? JSONSerialization.data(withJSONObject: jsonObject(object), options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func jsonObject(_ value: JSONValue) -> Any {
        switch value {
        case .string(let string): return string
        case .int(let int): return int
        case .double(let double): return double
        case .bool(let bool): return bool
        case .null: return NSNull()
        case .array(let values): return values.map(jsonObject)
        case .object(let object): return jsonObject(object)
        }
    }

    private func jsonObject(_ object: [String: JSONValue]) -> [String: Any] {
        object.mapValues { jsonObject($0) }
    }
}
