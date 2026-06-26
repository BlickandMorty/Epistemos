import Foundation

enum StreamingReasoningTraceBuffer {
    static let postAnswerDisplaySeparator = "After-answer thought:\n"

    private static func deltaToAppend(current: String, incoming: String) -> String {
        guard !incoming.isEmpty else { return "" }
        guard !current.isEmpty else { return incoming }
        if incoming == current || current.hasSuffix(incoming) {
            return ""
        }
        if incoming.hasPrefix(current) {
            return String(incoming.dropFirst(current.count))
        }
        return incoming
    }

    static func append(
        _ text: String,
        streamingThinking: inout String,
        postAnswerThinking: inout String,
        hasStartedVisibleAnswer: Bool,
        isThinkingActive: inout Bool,
        thinkingStartedAt: inout Date?,
        thinkingEndedAt: inout Date?
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isThinkingActive || thinkingStartedAt != nil || !trimmed.isEmpty else { return }

        if thinkingStartedAt == nil {
            thinkingStartedAt = .now
            streamingThinking.removeAll(keepingCapacity: true)
            postAnswerThinking.removeAll(keepingCapacity: true)
        }

        let textToAppend = deltaToAppend(current: streamingThinking, incoming: text)
        guard !textToAppend.isEmpty else { return }

        if hasStartedVisibleAnswer {
            if isThinkingActive {
                isThinkingActive = false
            }
            if postAnswerThinking.isEmpty {
                if !streamingThinking.isEmpty {
                    streamingThinking.append("\n\n")
                }
                streamingThinking.append(postAnswerDisplaySeparator)
            }
            postAnswerThinking.append(textToAppend)
            thinkingEndedAt = .now
        } else {
            thinkingEndedAt = nil
        }

        streamingThinking.append(textToAppend)
    }

    static func append(
        _ text: String,
        streamingThinking: inout String,
        postAnswerThinking: inout String,
        hasStartedVisibleAnswer: Bool,
        thinkingStartedAt: inout Date?,
        thinkingEndedAt: inout Date?
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard thinkingStartedAt != nil || !trimmed.isEmpty else { return }

        if thinkingStartedAt == nil {
            thinkingStartedAt = .now
            streamingThinking.removeAll(keepingCapacity: true)
            postAnswerThinking.removeAll(keepingCapacity: true)
        }

        let textToAppend = deltaToAppend(current: streamingThinking, incoming: text)
        guard !textToAppend.isEmpty else { return }

        if hasStartedVisibleAnswer {
            if postAnswerThinking.isEmpty {
                if !streamingThinking.isEmpty {
                    streamingThinking.append("\n\n")
                }
                streamingThinking.append(postAnswerDisplaySeparator)
            }
            postAnswerThinking.append(textToAppend)
            thinkingEndedAt = .now
        } else {
            thinkingEndedAt = nil
        }

        streamingThinking.append(textToAppend)
    }
}

@MainActor
final class DisplayPacedTextBuffer {
    private let flushInterval: Duration
    private let flushThresholdBytes: Int
    private let onFlush: (String) -> Void

    private var pendingText = ""
    private var flushTask: Task<Void, Never>?

    init(
        flushInterval: Duration = .milliseconds(16),
        flushThresholdBytes: Int = 65_536,
        onFlush: @escaping (String) -> Void
    ) {
        self.flushInterval = flushInterval
        self.flushThresholdBytes = flushThresholdBytes
        self.onFlush = onFlush
        pendingText.reserveCapacity(16_384)
    }

    func append(_ text: String, scheduleFlush: Bool = true) {
        pendingText += text
        if pendingText.utf8.count > flushThresholdBytes {
            flushNow()
            return
        }
        guard scheduleFlush, flushTask == nil else { return }
        let interval = flushInterval
        flushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: interval)
            guard let self, !Task.isCancelled else { return }
            self.flushNow()
        }
    }

    func flushNow() {
        flushTask?.cancel()
        flushTask = nil
        guard !pendingText.isEmpty else { return }
        let delta = pendingText
        pendingText.removeAll(keepingCapacity: true)
        onFlush(delta)
    }

    func reset(releaseCapacity: Bool = false) {
        flushTask?.cancel()
        flushTask = nil
        pendingText.removeAll(keepingCapacity: !releaseCapacity)
    }
}
