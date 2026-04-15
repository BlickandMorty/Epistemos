import Foundation
import NaturalLanguage
import os
import SwiftData

// MARK: - Phase 6.5: Text Capture Pipeline
//
// The smallest real vertical slice of the Epistemos launch loop:
//   capture → structure → memory → evidence → trace
//
// Accepts raw text, produces a structured CaptureResult with:
//   - title, summary, entities, tasks
//   - source spans (provenance back to raw text)
//   - persisted note via existing NoteFileStorage/SDPage
//   - graph nodes/edges via existing GraphBuilder patterns
//   - trace events via existing TraceCollector
//
// No microphone, no STT, no cloud APIs required. Text-first.
// Voice/STT plugs into the same pipeline later via AudioTranscriber.

private let log = Logger(subsystem: "com.epistemos", category: "TextCapture")

// MARK: - Source Span (Provenance)

/// A span linking a derived field back to its source in the captured text.
/// Coarse character-offset spans — stable enough for debugging and provenance,
/// without requiring full AST-level precision.
struct SourceSpan: Codable, Sendable, Equatable {
    /// UTF-16 offset into the raw capture text (matches NSString indexing).
    let start: Int
    /// UTF-16 offset end (exclusive).
    let end: Int
    /// The raw source text this span covers. Stored for resilience against
    /// later edits to the source document.
    let text: String
    /// What this span was used for (e.g. "title", "task", "entity:person").
    let role: String
}

// MARK: - Extracted Task

/// A task extracted from captured text via pattern matching.
struct ExtractedTask: Codable, Sendable, Equatable {
    let text: String
    let isCompleted: Bool
    let sourceSpan: SourceSpan
}

// MARK: - Extracted Entity

/// An entity extracted from captured text via NL analysis.
struct ExtractedEntity: Codable, Sendable, Equatable {
    let text: String
    let kind: String // "person", "place", "organization"
    let sourceSpan: SourceSpan
}

// MARK: - Graph Write Summary

/// Summary of what was written (or skipped) in the graph.
struct GraphWriteSummary: Codable, Sendable {
    let noteNodeCreated: Bool
    let entityNodesCreated: Int
    let edgesCreated: Int
    let skippedReason: String?
}

// MARK: - Capture Result

/// The complete result of a text capture pipeline run.
struct CaptureResult: Sendable {
    let rawText: String
    let cleanedText: String
    let title: String
    let summary: String
    let entities: [ExtractedEntity]
    let tasks: [ExtractedTask]
    let sourceSpans: [SourceSpan]
    let createdNoteID: String?
    let draftNoteID: String?
    let graphWriteSummary: GraphWriteSummary
    let traceID: String
}

// MARK: - Capture Error

enum TextCaptureError: Error, LocalizedError, Sendable, Equatable {
    case emptyCapture
    case persistenceFailed(String)
    case graphUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .emptyCapture:
            return "Capture text is empty after cleaning."
        case .persistenceFailed(let reason):
            return "Note persistence failed: \(reason)"
        case .graphUnavailable(let reason):
            return "Graph write unavailable: \(reason)"
        }
    }
}

// MARK: - Capture Trace Events

extension TraceEvent {
    static func captureReceived(
        sessionId: String, traceId: String, textLength: Int
    ) -> TraceEvent {
        TraceEvent(
            ts: isoNow(), type: .captureReceived, sessionId: sessionId, taskId: traceId,
            harnessVersion: "capture-v1", turn: nil,
            provider: nil, model: nil, tool: "text_capture", toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil, content: "length=\(textLength)",
            tokensUsed: nil, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: nil, domain: "capture", progressSnapshot: nil, bootstrapPacket: nil
        )
    }

    static func structureGenerated(
        sessionId: String, traceId: String,
        entityCount: Int, taskCount: Int, title: String
    ) -> TraceEvent {
        TraceEvent(
            ts: isoNow(), type: .structureGenerated, sessionId: sessionId, taskId: traceId,
            harnessVersion: "capture-v1", turn: nil,
            provider: nil, model: nil, tool: "text_capture", toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil,
            content: "title=\(String(title.prefix(80))) entities=\(entityCount) tasks=\(taskCount)",
            tokensUsed: nil, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: nil, domain: "capture", progressSnapshot: nil, bootstrapPacket: nil
        )
    }

    static func notePersisted(
        sessionId: String, traceId: String, noteId: String
    ) -> TraceEvent {
        TraceEvent(
            ts: isoNow(), type: .notePersisted, sessionId: sessionId, taskId: traceId,
            harnessVersion: "capture-v1", turn: nil,
            provider: nil, model: nil, tool: "text_capture", toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil, content: "noteId=\(noteId)",
            tokensUsed: nil, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: nil, domain: "capture", progressSnapshot: nil, bootstrapPacket: nil
        )
    }

    static func graphWriteAttempted(
        sessionId: String, traceId: String, summary: GraphWriteSummary
    ) -> TraceEvent {
        let content: String
        if let reason = summary.skippedReason {
            content = "skipped: \(reason)"
        } else {
            content = "noteNode=\(summary.noteNodeCreated) entities=\(summary.entityNodesCreated) edges=\(summary.edgesCreated)"
        }
        return TraceEvent(
            ts: isoNow(), type: .graphWriteAttempted, sessionId: sessionId, taskId: traceId,
            harnessVersion: "capture-v1", turn: nil,
            provider: nil, model: nil, tool: "text_capture", toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil, content: content,
            tokensUsed: nil, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: nil, domain: "capture", progressSnapshot: nil, bootstrapPacket: nil
        )
    }

    static func evidenceLinked(
        sessionId: String, traceId: String, spanCount: Int
    ) -> TraceEvent {
        TraceEvent(
            ts: isoNow(), type: .evidenceLinked, sessionId: sessionId, taskId: traceId,
            harnessVersion: "capture-v1", turn: nil,
            provider: nil, model: nil, tool: "text_capture", toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil, content: "spans=\(spanCount)",
            tokensUsed: nil, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: nil, domain: "capture", progressSnapshot: nil, bootstrapPacket: nil
        )
    }

    private static let _isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    fileprivate static func isoNow() -> String { _isoFormatter.string(from: Date()) }
}

// MARK: - Text Capture Pipeline

/// Orchestrates the capture → structure → memory → evidence → trace pipeline.
/// Text-first: no microphone, no STT, no cloud APIs.
/// Deterministic extraction (NL framework + regex) — no LLM required.
@MainActor
final class TextCapturePipeline {

    private let traceCollector: TraceCollector
    private let sessionId: String

    init(
        traceCollector: TraceCollector = .shared,
        sessionId: String = UUID().uuidString
    ) {
        self.traceCollector = traceCollector
        self.sessionId = sessionId
    }

    /// Run the full capture pipeline on raw text.
    /// Returns a CaptureResult with the structured output, persisted note, graph writes, and trace.
    ///
    /// - Parameters:
    ///   - rawText: The user's captured text input.
    ///   - modelContext: SwiftData context for note and graph persistence.
    ///                   Pass nil to skip persistence (useful for dry-run / testing extraction only).
    /// - Throws: `TextCaptureError.emptyCapture` if the cleaned text is empty.
    func run(
        rawText: String,
        modelContext: ModelContext? = nil
    ) async throws -> CaptureResult {
        let traceId = UUID().uuidString

        // Step 1: Receive and clean
        traceCollector.record(.captureReceived(
            sessionId: sessionId, traceId: traceId, textLength: rawText.count
        ))

        let cleaned = cleanText(rawText)
        guard !cleaned.isEmpty else {
            throw TextCaptureError.emptyCapture
        }

        // Step 2: Extract structure
        let title = extractTitle(from: cleaned)
        let summary = extractSummary(from: cleaned)
        let entities = extractEntities(from: cleaned)
        let tasks = extractTasks(from: cleaned)

        // Collect all source spans
        var allSpans: [SourceSpan] = []
        if let titleSpan = findSpan(for: title, in: cleaned, role: "title") {
            allSpans.append(titleSpan)
        }
        allSpans.append(contentsOf: entities.map(\.sourceSpan))
        allSpans.append(contentsOf: tasks.map(\.sourceSpan))

        traceCollector.record(.structureGenerated(
            sessionId: sessionId, traceId: traceId,
            entityCount: entities.count, taskCount: tasks.count, title: title
        ))

        // Step 3: Persist note
        var createdNoteID: String?
        if let context = modelContext {
            do {
                createdNoteID = try persistNote(
                    title: title,
                    summary: summary,
                    cleanedText: cleaned,
                    tasks: tasks,
                    entities: entities,
                    sourceSpans: allSpans,
                    context: context
                )
                traceCollector.record(.notePersisted(
                    sessionId: sessionId, traceId: traceId, noteId: createdNoteID ?? "unknown"
                ))
            } catch {
                log.error("TextCapturePipeline: note persistence failed — \(error.localizedDescription)")
                // Non-fatal: we still return the structured result
            }
        }

        // Step 4: Graph write
        let graphSummary: GraphWriteSummary
        if let context = modelContext, let noteId = createdNoteID {
            graphSummary = writeGraph(
                noteId: noteId,
                title: title,
                entities: entities,
                context: context
            )
        } else {
            graphSummary = GraphWriteSummary(
                noteNodeCreated: false,
                entityNodesCreated: 0,
                edgesCreated: 0,
                skippedReason: modelContext == nil ? "no model context" : "note not persisted"
            )
        }

        traceCollector.record(.graphWriteAttempted(
            sessionId: sessionId, traceId: traceId, summary: graphSummary
        ))

        // Step 5: Evidence linking trace
        traceCollector.record(.evidenceLinked(
            sessionId: sessionId, traceId: traceId, spanCount: allSpans.count
        ))

        return CaptureResult(
            rawText: rawText,
            cleanedText: cleaned,
            title: title,
            summary: summary,
            entities: entities,
            tasks: tasks,
            sourceSpans: allSpans,
            createdNoteID: createdNoteID,
            draftNoteID: nil,
            graphWriteSummary: graphSummary,
            traceID: traceId
        )
    }

    // MARK: - Text Cleaning

    nonisolated func cleanText(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Title Extraction

    /// Extracts a title from the first line or first sentence.
    /// If the first line is short enough (<= 120 chars), use it as title.
    /// Otherwise, use the first sentence up to 120 chars.
    nonisolated func extractTitle(from text: String) -> String {
        guard !text.isEmpty else { return "" }

        // Try first line
        let firstLine: String
        if let newlineIndex = text.firstIndex(of: "\n") {
            firstLine = String(text[text.startIndex..<newlineIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            firstLine = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Strip markdown heading prefix
        let stripped: String
        if firstLine.hasPrefix("# ") {
            stripped = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        } else if firstLine.hasPrefix("## ") {
            stripped = String(firstLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        } else {
            stripped = firstLine
        }

        if !stripped.isEmpty && stripped.count <= 120 {
            return stripped
        }

        // Fall back to first sentence
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var firstSentence = ""
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            firstSentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            return false // stop after first
        }

        if firstSentence.count > 120 {
            return String(firstSentence.prefix(117)) + "..."
        }
        return firstSentence.isEmpty ? String(text.prefix(120)) : firstSentence
    }

    // MARK: - Summary Extraction

    /// Extracts a summary: first paragraph or first 300 characters.
    nonisolated func extractSummary(from text: String) -> String {
        guard !text.isEmpty else { return "" }

        // Find first paragraph break
        let paragraphs = text.components(separatedBy: "\n\n")
        let firstParagraph = paragraphs.first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !firstParagraph.isEmpty && firstParagraph.count <= 300 {
            return firstParagraph
        }

        if firstParagraph.count > 300 {
            return String(firstParagraph.prefix(297)) + "..."
        }

        return String(text.prefix(300))
    }

    // MARK: - Entity Extraction

    /// Extracts named entities using Apple NaturalLanguage framework.
    /// Each entity includes a source span back to the original text.
    nonisolated func extractEntities(from text: String) -> [ExtractedEntity] {
        guard !text.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var seen = Set<String>()
        var entities: [ExtractedEntity] = []

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, range in
            guard let tag else { return true }

            let kind: String?
            switch tag {
            case .personalName:      kind = "person"
            case .placeName:         kind = "place"
            case .organizationName:  kind = "organization"
            default:                 kind = nil
            }

            if let kind {
                let entityText = String(text[range])
                let key = "\(kind):\(entityText.lowercased())"
                if !seen.contains(key) {
                    seen.insert(key)

                    let nsText = text as NSString
                    let nsRange = NSRange(range, in: text)
                    let span = SourceSpan(
                        start: nsRange.location,
                        end: nsRange.location + nsRange.length,
                        text: entityText,
                        role: "entity:\(kind)"
                    )
                    entities.append(ExtractedEntity(
                        text: entityText,
                        kind: kind,
                        sourceSpan: span
                    ))
                }
            }
            return true
        }

        return entities
    }

    // MARK: - Task Extraction

    /// Extracts tasks from text using common patterns:
    /// - `- [ ]` or `- [x]` markdown checkboxes
    /// - Lines starting with `TODO:` or `FIXME:`
    /// - Lines starting with `ACTION:` or `TASK:`
    nonisolated func extractTasks(from text: String) -> [ExtractedTask] {
        guard !text.isEmpty else { return [] }

        let nsText = text as NSString
        var tasks: [ExtractedTask] = []

        let patterns: [(pattern: String, completedGroup: Int?)] = [
            // Markdown checkbox: - [ ] or - [x] or - [X]
            ("^\\s*[-*]\\s*\\[([ xX])\\]\\s*(.+)$", 1),
            // TODO/FIXME/ACTION/TASK prefix
            ("^\\s*(?:TODO|FIXME|ACTION|TASK):\\s*(.+)$", nil),
        ]

        for (pattern, completedGroup) in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.anchorsMatchLines]
            ) else { continue }

            let matches = regex.matches(
                in: text,
                range: NSRange(location: 0, length: nsText.length)
            )

            for match in matches {
                let fullRange = match.range(at: 0)

                let isCompleted: Bool
                if let cg = completedGroup, cg < match.numberOfRanges {
                    let checkChar = nsText.substring(with: match.range(at: cg))
                    isCompleted = checkChar == "x" || checkChar == "X"
                } else {
                    isCompleted = false
                }

                // Get the task text (last capture group)
                let textGroupIndex = match.numberOfRanges - 1
                let taskText = nsText.substring(with: match.range(at: textGroupIndex))
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !taskText.isEmpty else { continue }

                let span = SourceSpan(
                    start: fullRange.location,
                    end: fullRange.location + fullRange.length,
                    text: nsText.substring(with: fullRange)
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    role: "task"
                )

                tasks.append(ExtractedTask(
                    text: taskText,
                    isCompleted: isCompleted,
                    sourceSpan: span
                ))
            }
        }

        return tasks
    }

    // MARK: - Source Span Finder

    /// Find a source span for a given substring in the text.
    nonisolated func findSpan(for substring: String, in text: String, role: String) -> SourceSpan? {
        let nsText = text as NSString
        let range = nsText.range(of: substring)
        guard range.location != NSNotFound else { return nil }
        return SourceSpan(
            start: range.location,
            end: range.location + range.length,
            text: substring,
            role: role
        )
    }

    // MARK: - Note Persistence

    /// Creates an SDPage from the capture result and persists it.
    /// Returns the created page ID.
    private func persistNote(
        title: String,
        summary: String,
        cleanedText: String,
        tasks: [ExtractedTask],
        entities: [ExtractedEntity],
        sourceSpans: [SourceSpan],
        context: ModelContext
    ) throws -> String {
        let page = SDPage(title: title)
        page.summary = summary
        page.wordCount = NLAnalysisService.wordCount(cleanedText)

        // Build note body with metadata
        var body = cleanedText

        // Append provenance metadata as YAML front matter comment
        let provenanceJSON: String
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let spansData = try encoder.encode(sourceSpans)
            provenanceJSON = String(data: spansData, encoding: .utf8) ?? "[]"
        } catch {
            provenanceJSON = "[]"
        }

        body += "\n\n<!-- capture-provenance: \(provenanceJSON) -->"

        page.saveBody(body)

        // Extract tags from entities for SDPage.tags
        let entityTags = entities.map { $0.text.lowercased() }
        page.tags = Array(Set(entityTags))

        context.insert(page)
        do {
            try context.save()
        } catch {
            throw TextCaptureError.persistenceFailed(error.localizedDescription)
        }

        return page.id
    }

    // MARK: - Graph Write

    /// Creates graph nodes and edges for the captured note and its entities.
    /// Uses the existing GraphBuilder-compatible SDGraphNode/SDGraphEdge model.
    private func writeGraph(
        noteId: String,
        title: String,
        entities: [ExtractedEntity],
        context: ModelContext
    ) -> GraphWriteSummary {
        var entityNodesCreated = 0
        var edgesCreated = 0

        // Create note node
        let noteNode = SDGraphNode(
            type: .note,
            label: title,
            sourceId: noteId,
            weight: 1.0
        )
        context.insert(noteNode)

        // Create entity nodes and edges
        for entity in entities {
            let nodeType: GraphNodeType
            switch entity.kind {
            case "person": nodeType = .person
            case "place": nodeType = .topic // places map to topic in current ontology
            case "organization": nodeType = .project // orgs map to project
            default: nodeType = .topic
            }

            let entityNode = SDGraphNode(
                type: nodeType,
                label: entity.text,
                sourceId: "capture-entity-\(entity.text.lowercased().replacingOccurrences(of: " ", with: "-"))"
            )
            context.insert(entityNode)
            entityNodesCreated += 1

            // Edge: note → entity (mentions)
            let edge = SDGraphEdge(
                source: noteNode.id,
                target: entityNode.id,
                type: .mentions,
                weight: 1.0
            )
            context.insert(edge)
            edgesCreated += 1
        }

        do {
            try context.save()
            return GraphWriteSummary(
                noteNodeCreated: true,
                entityNodesCreated: entityNodesCreated,
                edgesCreated: edgesCreated,
                skippedReason: nil
            )
        } catch {
            log.error("TextCapturePipeline: graph write failed — \(error.localizedDescription)")
            return GraphWriteSummary(
                noteNodeCreated: false,
                entityNodesCreated: 0,
                edgesCreated: 0,
                skippedReason: "save failed: \(error.localizedDescription)"
            )
        }
    }
}
