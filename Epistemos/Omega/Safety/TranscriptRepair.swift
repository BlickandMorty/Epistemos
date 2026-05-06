import Foundation
import os

private let repairLog = Logger(subsystem: "com.epistemos", category: "TranscriptRepair")

// MARK: - Transcript Repair
// Repairs context windows corrupted by LLM malformed tool calls before
// they are sent back to the model or persisted. Fixes:
//   1. Orphaned tool_use blocks (no matching tool_result)
//   2. Orphaned tool_result blocks (no matching tool_use)
//   3. Duplicate tool_use IDs
//   4. Adjacent same-role messages (must alternate user/assistant)
//
// Without this, the Anthropic API returns "unexpected tool_use_id" errors
// that break the agent loop permanently.

enum TranscriptRepair {

    /// A minimal message representation for repair operations.
    /// Works with both Omega's internal format and LocalAgent bridge JSON.
    struct Message: Sendable {
        let role: String // "user", "assistant", "system"
        var content: [[String: Any]]

        /// Extract all tool_use IDs from this message's content blocks.
        var toolUseIDs: Set<String> {
            Set(content.compactMap { block in
                guard block["type"] as? String == "tool_use" else { return nil }
                return block["id"] as? String
            })
        }

        /// Extract all tool_result IDs from this message's content blocks.
        var toolResultIDs: Set<String> {
            Set(content.compactMap { block in
                guard block["type"] as? String == "tool_result" else { return nil }
                return block["tool_use_id"] as? String
            })
        }
    }

    // MARK: - JSON Array Repair

    /// Repair a JSON messages array (Anthropic format).
    /// Returns the repaired array suitable for re-submission to the API.
    static func repair(messages: [[String: Any]]) -> [[String: Any]] {
        var parsed = messages.map { msg -> Message in
            let role = msg["role"] as? String ?? "user"
            let content: [[String: Any]]
            if let contentArray = msg["content"] as? [[String: Any]] {
                content = contentArray
            } else if let contentStr = msg["content"] as? String {
                content = [["type": "text", "text": contentStr]]
            } else {
                content = []
            }
            return Message(role: role, content: content)
        }

        let beforeCount = parsed.count
        parsed = removeOrphanedToolResults(parsed)
        parsed = removeOrphanedToolUses(parsed)
        parsed = deduplicateToolUseIDs(parsed)
        parsed = fixAdjacentSameRole(parsed)
        let afterCount = parsed.count

        if beforeCount != afterCount {
            repairLog.info("Transcript repaired: \(beforeCount) → \(afterCount) messages")
        }

        // Convert back to dictionary format
        return parsed.map { msg in
            var dict: [String: Any] = ["role": msg.role]
            if msg.content.count == 1,
               msg.content[0]["type"] as? String == "text",
               let text = msg.content[0]["text"] as? String {
                dict["content"] = text
            } else {
                dict["content"] = msg.content
            }
            return dict
        }
    }

    // MARK: - Repair Passes

    /// Remove tool_result blocks whose tool_use_id has no matching tool_use in any prior assistant message.
    private static func removeOrphanedToolResults(_ messages: [Message]) -> [Message] {
        // Collect all tool_use IDs from assistant messages
        var allToolUseIDs = Set<String>()
        for msg in messages where msg.role == "assistant" {
            allToolUseIDs.formUnion(msg.toolUseIDs)
        }

        var repaired: [Message] = []
        for var msg in messages {
            if msg.role == "user" {
                let originalCount = msg.content.count
                msg.content = msg.content.filter { block in
                    guard block["type"] as? String == "tool_result",
                          let toolUseId = block["tool_use_id"] as? String else {
                        return true // Keep non-tool-result blocks
                    }
                    let hasMatch = allToolUseIDs.contains(toolUseId)
                    if !hasMatch {
                        repairLog.debug("Removing orphaned tool_result for ID: \(toolUseId)")
                    }
                    return hasMatch
                }
                // Don't add empty user messages
                if !msg.content.isEmpty {
                    repaired.append(msg)
                } else if originalCount > 0 {
                    repairLog.debug("Dropped empty user message after orphan cleanup")
                }
            } else {
                repaired.append(msg)
            }
        }
        return repaired
    }

    /// Remove tool_use blocks whose ID has no matching tool_result in any subsequent user message.
    private static func removeOrphanedToolUses(_ messages: [Message]) -> [Message] {
        // Collect all tool_result IDs from user messages
        var allToolResultIDs = Set<String>()
        for msg in messages where msg.role == "user" {
            allToolResultIDs.formUnion(msg.toolResultIDs)
        }

        var repaired: [Message] = []
        for var msg in messages {
            if msg.role == "assistant" {
                msg.content = msg.content.filter { block in
                    guard block["type"] as? String == "tool_use",
                          let id = block["id"] as? String else {
                        return true // Keep thinking and text blocks
                    }
                    let hasResult = allToolResultIDs.contains(id)
                    if !hasResult {
                        repairLog.debug("Removing orphaned tool_use ID: \(id)")
                    }
                    return hasResult
                }
                if !msg.content.isEmpty {
                    repaired.append(msg)
                }
            } else {
                repaired.append(msg)
            }
        }
        return repaired
    }

    /// Deduplicate tool_use blocks with the same ID (keeps the last occurrence).
    private static func deduplicateToolUseIDs(_ messages: [Message]) -> [Message] {
        var seenIDs = Set<String>()
        var result: [Message] = []

        // Walk backwards to keep the last occurrence
        for var msg in messages.reversed() {
            if msg.role == "assistant" {
                msg.content = msg.content.filter { block in
                    guard block["type"] as? String == "tool_use",
                          let id = block["id"] as? String else {
                        return true
                    }
                    if seenIDs.contains(id) {
                        repairLog.debug("Removing duplicate tool_use ID: \(id)")
                        return false
                    }
                    seenIDs.insert(id)
                    return true
                }
            }
            if !msg.content.isEmpty || msg.role == "system" {
                result.append(msg)
            }
        }

        return result.reversed()
    }

    /// Fix adjacent messages with the same role by merging content.
    private static func fixAdjacentSameRole(_ messages: [Message]) -> [Message] {
        guard !messages.isEmpty else { return [] }

        var merged: [Message] = [messages[0]]
        for msg in messages.dropFirst() {
            if msg.role == merged[merged.count - 1].role && msg.role != "system" {
                repairLog.debug("Merging adjacent \(msg.role) messages")
                merged[merged.count - 1].content.append(contentsOf: msg.content)
            } else {
                merged.append(msg)
            }
        }
        return merged
    }
}
