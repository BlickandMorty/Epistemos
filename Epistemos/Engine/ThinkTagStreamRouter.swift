import Foundation

/// Streaming splitter that routes inline `<think>…</think>` segments of
/// a model's visible-text stream to the reasoning channel instead of
/// letting them land in the main chat bubble.
///
/// Local reasoning models (DeepSeek-R1, Qwen3 thinking variants, Bonsai
/// + hermes deep-reasoning) emit their chain-of-thought INSIDE the
/// `content` / `output_text` stream using explicit `<think>` tags,
/// rather than a separate `reasoning_content` field. Without a stream-
/// aware splitter the UI shows:
///
///   1. The reasoning streams live into the main bubble
///   2. On turn completion, `UserFacingModelOutput.finalVisibleText`
///      strips the tags and the text "disappears"
///   3. The real answer (which was after `</think>`) remains
///
/// The user sees that as the chat bubble filling with a monologue,
/// then vanishing, then the real answer appearing. This router fixes
/// it by classifying each incoming chunk and emitting two output
/// strings per ingest: `visible` goes to `streamingText`, `thinking`
/// goes to `streamingThinking`.
///
/// Handles tag boundaries that split across network chunks (e.g. the
/// stream delivers "<thi" then "nk>"): if a partial-tag suffix is
/// possible at the tail of a chunk, we hold those characters in a
/// pending buffer until the next ingest resolves them.
nonisolated final class ThinkTagStreamRouter {
    /// Output of a single ingest. Either / both may be empty.
    struct Emit: Equatable {
        let visible: String
        let thinking: String

        static let empty = Emit(visible: "", thinking: "")
        var isEmpty: Bool { visible.isEmpty && thinking.isEmpty }

        fileprivate static func + (lhs: Emit, rhs: Emit) -> Emit {
            Emit(
                visible: lhs.visible + rhs.visible,
                thinking: lhs.thinking + rhs.thinking
            )
        }
    }

    private enum Mode {
        case visible
        case thinking(closeTag: String)
    }

    /// Reasoning-tag pairs we split. DeepSeek-R1 uses `<think>…</think>`,
    /// Claude and some tool-use models emit `<thinking>…</thinking>`
    /// when not using structured thinking blocks, and various Qwen /
    /// Bonsai fine-tunes have been observed using `<thought>…</thought>`
    /// or `<reasoning>…</reasoning>`. All match case-insensitively
    /// since some models emit uppercase variants.
    private static let tagPairs: [(open: String, close: String)] = [
        ("<scratch_pad>", "</scratch_pad>"),
        ("<think>", "</think>"),
        ("<thinking>", "</thinking>"),
        ("<thought>", "</thought>"),
        ("<reasoning>", "</reasoning>"),
    ]

    /// Longest trailing substring we'll hold back waiting for a tag to
    /// finish forming. Max open-tag length is `<reasoning>` (11) —
    /// give a bit of headroom.
    private static let maxPartialTagLength = 12

    /// Safety valve: if pending buffer grows past this without ever
    /// finding an open tag, force-flush as visible so a misbehaving
    /// model can't cause the router to buffer forever. Chosen high
    /// enough (16k chars ≈ 4k tokens) that real `<think>` blocks
    /// always complete before the cap fires.
    private static let maxPendingBufferChars = 16_384

    private var mode: Mode = .visible
    private var pending: String = ""

    /// Ingest a streamed text chunk. Emits the parts that can be
    /// classified unambiguously. Partial-tag suffixes stay in `pending`
    /// until the next call completes them.
    func ingest(_ chunk: String) -> Emit {
        guard !chunk.isEmpty else { return .empty }
        pending.append(chunk)

        // Safety valve — a misbehaving model that spews text without
        // ever closing a tag (or confused whitespace that looks like
        // a tag prefix forever) can't balloon memory. If we're well
        // past any plausible partial-tag window, flush what we have
        // via the current mode's channel.
        if pending.count > Self.maxPendingBufferChars {
            let drained = pending
            pending = ""
            switch mode {
            case .visible:
                return Emit(visible: drained, thinking: "")
            case .thinking:
                return Emit(visible: "", thinking: drained)
            }
        }

        var emit = Emit.empty

        while !pending.isEmpty {
            switch mode {
            case .visible:
                // Find the earliest open tag of any known pair. Among
                // multiple matches the smallest lowerBound wins so we
                // don't skip over a `<think>` looking for a later
                // `<reasoning>`.
                let earliest = Self.tagPairs.compactMap { pair -> (Range<String.Index>, String)? in
                    guard let range = pending.range(of: pair.open, options: .caseInsensitive) else {
                        return nil
                    }
                    return (range, pair.close)
                }.min(by: { $0.0.lowerBound < $1.0.lowerBound })

                if let (range, closeTag) = earliest {
                    let head = String(pending[..<range.lowerBound])
                    if !head.isEmpty {
                        emit = emit + Emit(visible: head, thinking: "")
                    }
                    pending.removeSubrange(pending.startIndex..<range.upperBound)
                    mode = .thinking(closeTag: closeTag)
                    continue
                }
                // No open tag in pending. Flush everything except a
                // trailing window that could still be the prefix of
                // any known open tag. Use the longest candidate's
                // prefix to be safe.
                var holdCount = 0
                for pair in Self.tagPairs {
                    let h = partialTagHoldCount(in: pending, candidate: pair.open)
                    if h > holdCount { holdCount = h }
                }
                let emitEnd = pending.index(pending.endIndex, offsetBy: -holdCount)
                let ready = String(pending[..<emitEnd])
                if !ready.isEmpty {
                    emit = emit + Emit(visible: ready, thinking: "")
                }
                pending.removeSubrange(pending.startIndex..<emitEnd)
                return emit

            case .thinking(let closeTag):
                if let range = pending.range(of: closeTag, options: .caseInsensitive) {
                    let inside = String(pending[..<range.lowerBound])
                    if !inside.isEmpty {
                        emit = emit + Emit(visible: "", thinking: inside)
                    }
                    pending.removeSubrange(pending.startIndex..<range.upperBound)
                    mode = .visible
                    continue
                }
                let holdCount = partialTagHoldCount(in: pending, candidate: closeTag)
                let emitEnd = pending.index(pending.endIndex, offsetBy: -holdCount)
                let ready = String(pending[..<emitEnd])
                if !ready.isEmpty {
                    emit = emit + Emit(visible: "", thinking: ready)
                }
                pending.removeSubrange(pending.startIndex..<emitEnd)
                return emit
            }
        }

        return emit
    }

    /// Called when the stream ends. Flushes anything still in `pending`
    /// as visible text (in visible mode) or as thinking (if the stream
    /// closed mid-reasoning — shouldn't happen with a well-formed
    /// model, but if it does we keep the reasoning visible in the
    /// popover rather than dropping it silently).
    func flush() -> Emit {
        let remainder = pending
        pending = ""
        guard !remainder.isEmpty else { return .empty }
        switch mode {
        case .visible:
            return Emit(visible: remainder, thinking: "")
        case .thinking:
            return Emit(visible: "", thinking: remainder)
        }
    }

    /// True iff the router is currently accumulating thinking text.
    /// Callers can use this to drive `isThinkingActive` on chat state.
    var isCurrentlyThinking: Bool {
        if case .thinking = mode { return true }
        return false
    }

    // MARK: - Partial-tag detection

    /// Returns the number of trailing characters of `text` that might
    /// be the prefix of `candidate`. Used to hold back a small tail
    /// until the next chunk disambiguates whether the sequence turns
    /// into an actual tag or is just literal text.
    private func partialTagHoldCount(in text: String, candidate: String) -> Int {
        let maxCheck = min(Self.maxPartialTagLength, text.count, candidate.count - 1)
        guard maxCheck > 0 else { return 0 }
        // Look for the longest non-empty suffix of text that is a
        // prefix of candidate (case-insensitive to match ingest).
        let lowerText = text.lowercased()
        let lowerCandidate = candidate.lowercased()
        var bestHold = 0
        var suffixLen = 1
        while suffixLen <= maxCheck {
            let start = lowerText.index(lowerText.endIndex, offsetBy: -suffixLen)
            let suffix = lowerText[start...]
            if lowerCandidate.hasPrefix(suffix) {
                bestHold = suffixLen
            }
            suffixLen += 1
        }
        return bestHold
    }
}

/// Stateful classifier for raw visible-text streams after explicit hidden
/// tags have already been stripped. This catches local-model runs that ignore
/// the `<think>` contract and instead emit prose like "I will analyze…"
/// before eventually producing a user-facing answer.
nonisolated final class UserFacingStreamRouter {
    private var rawText = ""
    private var emittedVisibleText = ""
    private var emittedReasoningText = ""

    func ingest(_ chunk: String) -> ThinkTagStreamRouter.Emit {
        guard !chunk.isEmpty else { return .empty }

        let priorRawText = rawText
        rawText.append(chunk)

        var emit = ThinkTagStreamRouter.Emit.empty

        let reasoningText = UserFacingModelOutput.streamingReasoningText(from: rawText)
        if !reasoningText.isEmpty, reasoningText.hasPrefix(emittedReasoningText) {
            let deltaStart = reasoningText.index(
                reasoningText.startIndex,
                offsetBy: emittedReasoningText.count
            )
            let delta = String(reasoningText[deltaStart...])
            if !delta.isEmpty {
                emittedReasoningText = reasoningText
                emit = emit + ThinkTagStreamRouter.Emit(visible: "", thinking: delta)
            }
        }

        let visibleText = UserFacingModelOutput.streamingVisibleText(from: rawText)
        if visibleText.hasPrefix(emittedVisibleText) {
            let deltaStart = visibleText.index(
                visibleText.startIndex,
                offsetBy: emittedVisibleText.count
            )
            let delta = String(visibleText[deltaStart...])
            if !delta.isEmpty {
                emittedVisibleText = visibleText
                emit = emit + ThinkTagStreamRouter.Emit(visible: delta, thinking: "")
                return emit
            }
        }

        if emittedVisibleText.isEmpty,
           let standaloneAnswer = UserFacingModelOutput
               .streamingStandaloneAnswerChunk(chunk, afterReasoningRaw: priorRawText),
           !standaloneAnswer.isEmpty {
            emittedVisibleText = standaloneAnswer
            emit = emit + ThinkTagStreamRouter.Emit(visible: standaloneAnswer, thinking: "")
        }

        return emit
    }

    func flush() -> ThinkTagStreamRouter.Emit {
        let finalVisibleText = UserFacingModelOutput.finalVisibleText(from: rawText)
        guard finalVisibleText.hasPrefix(emittedVisibleText) else { return .empty }

        let deltaStart = finalVisibleText.index(
            finalVisibleText.startIndex,
            offsetBy: emittedVisibleText.count
        )
        let delta = String(finalVisibleText[deltaStart...])
        guard !delta.isEmpty else { return .empty }

        emittedVisibleText = finalVisibleText
        return ThinkTagStreamRouter.Emit(visible: delta, thinking: "")
    }

    func reset() {
        rawText.removeAll(keepingCapacity: false)
        emittedVisibleText.removeAll(keepingCapacity: false)
        emittedReasoningText.removeAll(keepingCapacity: false)
    }
}
