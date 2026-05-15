import Foundation
import CryptoKit
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

private struct UpdatedExistingGraphNode {
    let node: SDGraphNode
    let label: String
    let updatedAt: Date
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
    let mutationEnvelope: MutationEnvelope?
    let mutationEnvelopePersisted: Bool
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

    static func mutationEnvelopeCommitted(
        sessionId: String, traceId: String, envelope: MutationEnvelope
    ) -> TraceEvent {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try? encoder.encode(envelope)
        let content = data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return TraceEvent(
            ts: isoNow(), type: .mutationEnvelopeCommitted, sessionId: sessionId, taskId: traceId,
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
@MainActor @Observable
final class TextCapturePipeline {

    nonisolated static let maxCleanedTextCharacters = 10_000

    private let traceCollector: TraceCollector
    private let sessionId: String
    private let eventStoreProvider: @Sendable () -> EventStore?

    init(
        traceCollector: TraceCollector = .shared,
        sessionId: String = UUID().uuidString,
        eventStoreProvider: @escaping @Sendable () -> EventStore? = { EventStore.shared }
    ) {
        self.traceCollector = traceCollector
        self.sessionId = sessionId
        self.eventStoreProvider = eventStoreProvider
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

        let cleaned = Self.stripHiddenCaptureMetadataComments(from: cleanText(rawText))
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
            if graphSummary.noteNodeCreated {
                AppBootstrap.shared?.graphState.needsRefresh = true
            }
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

        let mutationEnvelope: MutationEnvelope?
        let mutationEnvelopePersisted: Bool
        if let noteId = createdNoteID {
            mutationEnvelope = makeCaptureMutationEnvelope(
                noteId: noteId,
                title: title,
                cleanedText: cleaned,
                graphSummary: graphSummary,
                traceId: traceId
            )
            if let mutationEnvelope {
                mutationEnvelopePersisted = eventStoreProvider()?
                    .saveMutationEnvelope(mutationEnvelope, traceId: traceId) ?? false
                if !mutationEnvelopePersisted {
                    log.error(
                        "TextCapturePipeline: mutation envelope persistence failed for \(mutationEnvelope.mutationID, privacy: .public)"
                    )
                }
                traceCollector.record(.mutationEnvelopeCommitted(
                    sessionId: sessionId, traceId: traceId, envelope: mutationEnvelope
                ))
            } else {
                mutationEnvelopePersisted = false
            }
        } else {
            mutationEnvelope = nil
            mutationEnvelopePersisted = false
        }

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
            mutationEnvelope: mutationEnvelope,
            mutationEnvelopePersisted: mutationEnvelopePersisted,
            traceID: traceId
        )
    }

    private nonisolated func makeCaptureMutationEnvelope(
        noteId: String,
        title: String,
        cleanedText: String,
        graphSummary: GraphWriteSummary,
        traceId: String
    ) -> MutationEnvelope {
        let committedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        return MutationEnvelope(
            mutationID: "capture-\(traceId)",
            sequence: 1,
            causedByEventID: traceId,
            actor: .user,
            status: .committed,
            createdAtMs: committedAtMs,
            committedAtMs: committedAtMs,
            op: .artifactCreate(
                artifactID: noteId,
                artifactKind: ArtifactKind.proseNote.snakeCaseString
            ),
            sensitivity: .internal,
            reversibility: .reversible,
            integrityHash: captureIntegrityHash(
                noteId: noteId,
                title: title,
                cleanedText: cleanedText,
                graphSummary: graphSummary
            ),
            touchedArtifacts: [
                EpdocArtifactRef(id: noteId, kind: .proseNote, title: title)
            ],
            affectsSummary: true,
            affectsSearchProjection: true,
            affectsGraph: graphSummary.noteNodeCreated,
            affectsBody: true
        )
    }

    private nonisolated func captureIntegrityHash(
        noteId: String,
        title: String,
        cleanedText: String,
        graphSummary: GraphWriteSummary
    ) -> String {
        let canonical = [
            noteId,
            title,
            cleanedText,
            "\(graphSummary.noteNodeCreated)",
            "\(graphSummary.entityNodesCreated)",
            "\(graphSummary.edgesCreated)",
            graphSummary.skippedReason ?? ""
        ].joined(separator: "\u{1f}")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Text Cleaning

    nonisolated func cleanText(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > Self.maxCleanedTextCharacters else { return trimmed }
        return String(trimmed.prefix(Self.maxCleanedTextCharacters))
    }

    nonisolated static func stripHiddenCaptureMetadataComments(from body: String) -> String {
        let pattern = #"(?m)^[ \t]*<!--\s*(?:capture-provenance|audio-source):[\s\S]*?-->[ \t]*(?:\r?\n)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return body
        }
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        guard regex.firstMatch(in: body, options: [], range: range) != nil else {
            return body
        }

        return regex.stringByReplacingMatches(
            in: body,
            options: [],
            range: range,
            withTemplate: ""
        )
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// RCA-P0-003 migration pass: walk every managed-body file in
    /// `NoteFileStorage` and rewrite any body that still contains a
    /// hidden `<!-- capture-provenance: … -->` or `<!-- audio-source:
    /// … -->` comment.
    ///
    /// New captures already strip these via `run(rawText:)` /
    /// `runFromAudio(...)`. This method handles the existing-on-disk
    /// case so vaults that pre-date the 2026-05-09 sanitizer no longer
    /// leak metadata through raw markdown, export, or share.
    ///
    /// Idempotent — bodies without hidden comments are read, found
    /// clean, and skipped (no write). Bounded by
    /// `NoteFileStorage.managedBodyPageIds()` so the cost scales with
    /// the existing vault size, not with the per-launch cost. Callers
    /// should gate this behind a UserDefaults migration flag so it
    /// runs exactly once across all launches.
    ///
    /// Returns the count of bodies actually rewritten.
    nonisolated static func migrateLegacyCaptureMetadataInManagedBodies(
        in directory: URL? = nil
    ) -> Int {
        let pageIds = NoteFileStorage.managedBodyPageIds(in: directory)
        var migrated = 0
        for pageId in pageIds {
            // `fast: true` skips the integrity-hash verify on read
            // (it'd re-fire on the write below anyway) and avoids the
            // legacy-rich-text fallback path.
            let body = NoteFileStorage.readBody(pageId: pageId, fast: true)
            guard !body.isEmpty else { continue }
            let sanitized = stripHiddenCaptureMetadataComments(from: body)
            if sanitized != body {
                NoteFileStorage.writeBody(pageId: pageId, content: sanitized)
                migrated += 1
            }
        }
        return migrated
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
        let failedPageId = page.id

        let body = Self.stripHiddenCaptureMetadataComments(from: cleanedText)

        page.saveBody(body)
        page.needsVaultSync = true
        page.updatedAt = .now

        // Extract tags from entities for SDPage.tags
        let entityTags = entities.map { $0.text.lowercased() }
        page.tags = Array(Set(entityTags))

        context.insert(page)
        BlockMirror.sync(pageId: page.id, body: body, modelContext: context)
        do {
            try context.save()
        } catch {
            context.delete(page)
            let blockDescriptor = FetchDescriptor<SDBlock>(
                predicate: #Predicate<SDBlock> { $0.pageId == failedPageId }
            )
            do {
                let transientBlocks = try context.fetch(blockDescriptor)
                for block in transientBlocks {
                    context.delete(block)
                }
            } catch {
                log.error(
                    "TextCapturePipeline: failed to clean transient blocks for \(failedPageId, privacy: .public) — \(error.localizedDescription, privacy: .public)"
                )
            }
            NoteFileStorage.deleteBody(pageId: failedPageId)
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
        var insertedNodes: [SDGraphNode] = []
        var insertedEdges: [SDGraphEdge] = []
        var updatedExistingNodes: [UpdatedExistingGraphNode] = []

        // Create note node
        let noteNode = SDGraphNode(
            type: .note,
            label: title,
            sourceId: noteId,
            weight: 1.0
        )
        context.insert(noteNode)
        insertedNodes.append(noteNode)

        // Create entity nodes and edges.
        // Deduplicates: reuses existing node if one with the same sourceId exists.
        for entity in entities {
            let nodeType: GraphNodeType
            switch entity.kind {
            case "person": nodeType = .person
            case "place": nodeType = .topic // places map to topic in current ontology
            case "organization": nodeType = .project // orgs map to project
            default: nodeType = .topic
            }

            let entitySourceId = "capture-entity-\(entity.text.lowercased().replacingOccurrences(of: " ", with: "-"))"
            let entityNode: SDGraphNode
            if let existing = existingNode(sourceId: entitySourceId, context: context) {
                entityNode = existing
                // Update label in case casing changed
                if existing.label != entity.text {
                    updatedExistingNodes.append(
                        UpdatedExistingGraphNode(
                            node: existing,
                            label: existing.label,
                            updatedAt: existing.updatedAt
                        )
                    )
                    existing.label = entity.text
                    existing.updatedAt = .now
                }
            } else {
                entityNode = SDGraphNode(
                    type: nodeType,
                    label: entity.text,
                    sourceId: entitySourceId
                )
                context.insert(entityNode)
                insertedNodes.append(entityNode)
                entityNodesCreated += 1
            }

            // Edge: note → entity (mentions)
            let edge = SDGraphEdge(
                source: noteNode.id,
                target: entityNode.id,
                type: .mentions,
                weight: 1.0
            )
            context.insert(edge)
            insertedEdges.append(edge)
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
            for edge in insertedEdges {
                context.delete(edge)
            }
            for node in insertedNodes {
                context.delete(node)
            }
            for snapshot in updatedExistingNodes {
                snapshot.node.label = snapshot.label
                snapshot.node.updatedAt = snapshot.updatedAt
            }
            log.error("TextCapturePipeline: graph write failed — \(error.localizedDescription)")
            return GraphWriteSummary(
                noteNodeCreated: false,
                entityNodesCreated: 0,
                edgesCreated: 0,
                skippedReason: "save failed: \(error.localizedDescription)"
            )
        }
    }

    /// Checks if a graph node with the given sourceId already exists.
    /// Prevents duplicate entity nodes when the same entity appears across captures.
    private func existingNode(sourceId: String, context: ModelContext) -> SDGraphNode? {
        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate<SDGraphNode> { $0.sourceId == sourceId }
        )
        do {
            return try context.fetch(descriptor).first
        } catch {
            log.error("TextCapturePipeline: failed to fetch existing graph node for \(sourceId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Audio Capture Entry Point

    /// Runs the capture pipeline on transcribed audio output.
    /// This is the plug-in point for AudioTranscriber → capture pipeline.
    /// The transcribed text flows through the same extraction/persist/graph/trace
    /// path as typed text capture.
    ///
    /// - Parameters:
    ///   - transcription: The transcribed audio result from AudioTranscriber.
    ///   - modelContext: SwiftData context for persistence. Pass nil for dry run.
    func runFromAudio(
        transcription: TranscribedAudio,
        modelContext: ModelContext? = nil
    ) async throws -> CaptureResult {
        let rawText = transcription.fullText
        if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TextCaptureError.emptyCapture
        }

        return try await run(rawText: rawText, modelContext: modelContext)
    }
}
