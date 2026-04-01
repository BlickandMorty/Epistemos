import Foundation
import os

// MARK: - CoT Ring Buffer Token-Level Interceptor
//
// Parses the <think>...</think> token stream at the TOKEN ID level,
// not the character level. This prevents multi-byte UTF-8 sequences
// and partial token fragments from splitting across buffer boundaries.
//
// Uses a fixed-capacity ring buffer to enforce bounded allocation —
// the interceptor never grows beyond its fixed capacity regardless
// of how long the reasoning chain runs.

nonisolated(unsafe) private let cotLog = Logger(subsystem: "com.epistemos.bridge", category: "CoTInterceptor")

// MARK: - Ring Buffer

struct TokenRingBuffer: @unchecked Sendable {
    private var storage: [Int32]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private var count: Int = 0
    let capacity: Int

    nonisolated init(capacity: Int) {
        self.capacity = capacity
        self.storage = [Int32](repeating: 0, count: capacity)
    }

    nonisolated var isEmpty: Bool { count == 0 }
    nonisolated var isFull: Bool { count == capacity }

    nonisolated mutating func write(_ value: Int32) {
        storage[writeIndex] = value
        writeIndex = (writeIndex + 1) % capacity
        if count == capacity {
            readIndex = (readIndex + 1) % capacity
        } else {
            count += 1
        }
    }

    nonisolated mutating func drainAll() -> [Int32] {
        var result: [Int32] = []
        result.reserveCapacity(count)
        while count > 0 {
            result.append(storage[readIndex])
            readIndex = (readIndex + 1) % capacity
            count -= 1
        }
        return result
    }
}

// MARK: - Token Classification

enum TokenClassification: Sendable {
    /// Token is part of the <think> block (buffered, not shown to user).
    case thinkToken
    /// The </think> closing token was received — here are all buffered think tokens.
    case thinkBlockComplete(tokens: [Int32])
    /// Token is part of the final response (stream to user immediately).
    case responseToken(Int32)
}

// MARK: - CoT Stream Interceptor

actor CoTStreamInterceptor {

    // Fixed-size ring buffer for think-block tokens.
    // Capacity = max expected CoT length at ~4 bytes/token.
    // 32K tokens ≈ 128KB — well within memory budget.
    private var thinkRingBuffer: TokenRingBuffer

    private var isInThinkBlock = false
    private var thinkBlockCount = 0

    /// Qwen3 </think> token ID.
    /// Configurable per model family.
    private let thinkEndTokenID: Int32
    private let thinkStartTokenID: Int32

    init(
        capacity: Int = 32_768,
        thinkStartTokenID: Int32 = 151667,
        thinkEndTokenID: Int32 = 151668
    ) {
        self.thinkRingBuffer = TokenRingBuffer(capacity: capacity)
        self.thinkStartTokenID = thinkStartTokenID
        self.thinkEndTokenID = thinkEndTokenID
    }

    /// Consume a single token ID and classify it.
    func consumeTokenID(_ tokenID: Int32) -> TokenClassification {
        // Check for <think> start
        if tokenID == thinkStartTokenID {
            isInThinkBlock = true
            thinkBlockCount += 1
            cotLog.debug("Think block #\(self.thinkBlockCount) started")
            return .thinkToken
        }

        // Check for </think> end
        if tokenID == thinkEndTokenID && isInThinkBlock {
            isInThinkBlock = false
            let tokens = thinkRingBuffer.drainAll()
            cotLog.debug("Think block #\(self.thinkBlockCount) complete: \(tokens.count) tokens")
            return .thinkBlockComplete(tokens: tokens)
        }

        // Inside think block — buffer the token
        if isInThinkBlock {
            thinkRingBuffer.write(tokenID)
            return .thinkToken
        }

        // Outside think block — response token
        return .responseToken(tokenID)
    }

    /// Reset the interceptor for a new generation.
    func reset() {
        _ = thinkRingBuffer.drainAll()
        isInThinkBlock = false
        thinkBlockCount = 0
    }

    /// Whether we're currently inside a <think> block.
    var isThinking: Bool {
        isInThinkBlock
    }

    /// Number of think blocks seen so far.
    var totalThinkBlocks: Int {
        thinkBlockCount
    }
}

// MARK: - String-Level Fallback

/// For models that don't expose token IDs (cloud APIs that return text deltas),
/// this provides a regex-based fallback that operates on accumulated text.
///
/// This is less reliable than token-level parsing (can be fooled by
/// multi-byte boundary splits) but covers the cloud API path.
actor CoTTextInterceptor {
    private var accumulatedText = ""
    private var isInThinkBlock = false
    private(set) var thinkText = ""
    private(set) var responseText = ""

    /// Feed a text delta from the streaming API.
    /// Returns the text that should be displayed to the user (response only).
    func feed(_ delta: String) -> String {
        accumulatedText += delta

        // Check for <think> opening
        if !isInThinkBlock && accumulatedText.hasSuffix("<think>") {
            isInThinkBlock = true
            // Remove the tag from response
            let beforeTag = String(accumulatedText.dropLast(7))
            responseText = beforeTag
            return ""
        }

        // Check for </think> closing
        if isInThinkBlock && accumulatedText.contains("</think>") {
            isInThinkBlock = false
            // Split at </think>
            if let range = accumulatedText.range(of: "</think>") {
                let afterTag = String(accumulatedText[range.upperBound...])
                responseText += afterTag
                // Extract think content
                if let thinkStart = accumulatedText.range(of: "<think>") {
                    let thinkContent = accumulatedText[thinkStart.upperBound..<range.lowerBound]
                    thinkText += thinkContent
                }
                accumulatedText = afterTag
                return afterTag
            }
        }

        if isInThinkBlock {
            // Buffer — don't show to user
            return ""
        }

        // Normal response text
        responseText += delta
        return delta
    }

    func reset() {
        accumulatedText = ""
        isInThinkBlock = false
        thinkText = ""
        responseText = ""
    }
}
