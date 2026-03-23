import Foundation
import SwiftData
import os

// MARK: - Activity Tracker
// Lightweight paragraph-level change detection for workspace summaries.
// Every 30 seconds, hashes paragraphs of open notes to detect edits.
// Records window open/close and chat message events in a ring buffer.

@MainActor @Observable
final class ActivityTracker {
    private static let log = Logger(subsystem: "com.epistemos", category: "ActivityTracker")
    private static let scanInterval: Duration = .seconds(30)
    private static let maxEvents = 200
    private static let maxTrackedTabs = 10

    private(set) var events: [ActivityEvent] = []
    private var paragraphHashes: [String: [Int]] = [:] // pageId -> [hash per paragraph]
    private var scanTask: Task<Void, Never>?
    private(set) var trackingStartedAt: Date?

    // MARK: - Lifecycle

    func startTracking() {
        guard scanTask == nil else { return }
        trackingStartedAt = Date()
        scanTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.scanInterval)
                guard !Task.isCancelled else { break }
                self?.scanOpenNotes()
            }
        }
        Self.log.info("Activity tracking started")
    }

    func stopTracking() {
        scanTask?.cancel()
        scanTask = nil
        Self.log.info("Activity tracking stopped")
    }

    // MARK: - Event Recording

    func recordNoteOpened(pageId: String, title: String) {
        appendEvent(.noteOpened(pageId: pageId, title: title))
        // Take initial paragraph snapshot
        snapshotParagraphs(for: pageId)
    }

    func recordNoteClosed(pageId: String, title: String) {
        appendEvent(.noteClosed(pageId: pageId, title: title))
        paragraphHashes.removeValue(forKey: pageId)
    }

    func recordChatMessage(chatId: String, snippet: String) {
        let truncated = String(snippet.prefix(80))
        appendEvent(.chatMessageSent(chatId: chatId, snippet: truncated))
    }

    // MARK: - Query

    func recentEvents(since date: Date) -> [ActivityEvent] {
        events.filter { $0.timestamp >= date }
    }

    func buildDigest(since date: Date) -> ActivityDigest {
        let recent = recentEvents(since: date)

        var editedNotes: [String: ActivityDigest.EditedNoteSummary] = [:]
        var chatCount = 0

        for event in recent {
            switch event.kind {
            case .noteEdited(let pageId, let title, let changed, let total):
                if var existing = editedNotes[pageId] {
                    existing.changedParagraphCount = max(existing.changedParagraphCount, changed)
                    existing.totalParagraphs = total
                    editedNotes[pageId] = existing
                } else {
                    editedNotes[pageId] = ActivityDigest.EditedNoteSummary(
                        pageId: pageId, title: title,
                        changedParagraphCount: changed, totalParagraphs: total
                    )
                }
            case .chatMessageSent:
                chatCount += 1
            case .noteOpened, .noteClosed:
                break
            }
        }

        let sessionMinutes = Int(Date().timeIntervalSince(trackingStartedAt ?? date) / 60)
        return ActivityDigest(
            editedNotes: Array(editedNotes.values),
            chatMessageCount: chatCount,
            sessionDurationMinutes: sessionMinutes
        )
    }

    // MARK: - Paragraph Scanning

    private func scanOpenNotes() {
        let pageIds = Array(NoteWindowManager.shared.orderedPageIds().prefix(Self.maxTrackedTabs))
        guard !pageIds.isEmpty else { return }

        for pageId in pageIds {
            let body = NoteFileStorage.readBody(pageId: pageId, mapped: true)
            guard !body.isEmpty else { continue }

            let paragraphs = body.components(separatedBy: "\n\n")
            let hashes = paragraphs.map { hashParagraph($0) }

            guard let previous = paragraphHashes[pageId] else {
                paragraphHashes[pageId] = hashes
                continue
            }

            // Detect changed paragraphs
            let maxCount = max(hashes.count, previous.count)
            var changedCount = 0
            for i in 0..<maxCount {
                let oldHash = i < previous.count ? previous[i] : 0
                let newHash = i < hashes.count ? hashes[i] : 0
                if oldHash != newHash { changedCount += 1 }
            }

            if changedCount > 0 {
                // Fetch title from SwiftData
                let title = fetchPageTitle(pageId: pageId) ?? "Untitled"
                appendEvent(.noteEdited(
                    pageId: pageId, title: title,
                    changedParagraphs: changedCount, totalParagraphs: paragraphs.count
                ))
            }

            paragraphHashes[pageId] = hashes
        }
    }

    private func snapshotParagraphs(for pageId: String) {
        let body = NoteFileStorage.readBody(pageId: pageId, mapped: true)
        guard !body.isEmpty else { return }
        let paragraphs = body.components(separatedBy: "\n\n")
        paragraphHashes[pageId] = paragraphs.map { hashParagraph($0) }
    }

    private nonisolated func hashParagraph(_ text: String) -> Int {
        var hasher = Hasher()
        hasher.combine(text)
        return hasher.finalize()
    }

    private func fetchPageTitle(pageId: String) -> String? {
        guard let context = AppBootstrap.shared?.modelContainer.mainContext else { return nil }
        let targetId = pageId
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == targetId }
        )
        return try? context.fetch(descriptor).first?.title
    }

    // MARK: - Ring Buffer

    private func appendEvent(_ kind: ActivityEventKind) {
        let event = ActivityEvent(timestamp: Date(), kind: kind)
        events.append(event)
        if events.count > Self.maxEvents {
            events.removeFirst(events.count - Self.maxEvents)
        }
    }
}

// MARK: - Activity Event Types

struct ActivityEvent: Codable {
    let timestamp: Date
    let kind: ActivityEventKind
}

enum ActivityEventKind: Codable {
    case noteEdited(pageId: String, title: String, changedParagraphs: Int, totalParagraphs: Int)
    case noteOpened(pageId: String, title: String)
    case noteClosed(pageId: String, title: String)
    case chatMessageSent(chatId: String, snippet: String)
}
