import AppKit
import CoreGraphics
import Foundation
import SwiftData
import os

// MARK: - Activity Tracker
// Adaptive paragraph-level change detection for workspace summaries.
// Uses idle detection (CGEventSource) instead of rigid polling — scans only after
// 5 seconds of user idle following activity. Deterministic FNV-1a hashing for
// cross-session paragraph diffing. Events persisted to ring buffer (hot cache)
// and flushed to EventStore for permanent history.

private actor ActivityFlagState {
    private var isMarkedActive = false

    func markActive() {
        isMarkedActive = true
    }

    func isActive() -> Bool {
        isMarkedActive
    }

    func clear() {
        isMarkedActive = false
    }
}

@MainActor @Observable
final class ActivityTracker {
    nonisolated private static let log = Logger(subsystem: "com.epistemos", category: "ActivityTracker")
    private static let idleScanDelay: Duration = .seconds(5)
    private static let maxEvents = 2000
    private static let maxTrackedTabs = 10
    private static let flushFileLabel = "activity tracker cache"

    private(set) var events: [ActivityEvent] = []
    private var paragraphHashes: [String: [UInt64]] = [:] // pageId -> [FNV-1a hash per paragraph]
    private var scanTask: Task<Void, Never>?
    private var eventMonitor: Any?
    nonisolated private let activityFlagState = ActivityFlagState()
    private(set) var trackingStartedAt: Date?
    let sessionId = UUID().uuidString
    private let eventStoreProvider: @MainActor @Sendable () -> EventStore?
    private let cacheFileURLProvider: @Sendable () -> URL

    init(
        eventStoreProvider: @escaping @MainActor @Sendable () -> EventStore? = { EventStore.shared },
        cacheFileURLProvider: @escaping @Sendable () -> URL = ActivityTracker.defaultFlushFileURL
    ) {
        self.eventStoreProvider = eventStoreProvider
        self.cacheFileURLProvider = cacheFileURLProvider
    }

    // MARK: - Lifecycle

    func startTracking() {
        guard scanTask == nil else { return }
        trackingStartedAt = Date()

        // Monitor user activity via NSEvent (keyDown, scrollWheel, leftMouseDown)
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .scrollWheel, .leftMouseDown]
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                await self?.activityFlagState.markActive()
            }
            return event
        }

        // Adaptive scan loop: check idle time, scan only after activity + idle
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                
                // Ensure we're on MainActor and self is still alive
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    
                    // Only scan if user was recently active and is now idle
                    Task {
                        guard await self.activityFlagState.isActive() else { return }
                        // Check idle across ALL input types — not just keyDown.
                        // Mouse edits (click, drag, paste via menu) don't register as keyDown.
                        let keyIdle = CGEventSource.secondsSinceLastEventType(
                            .combinedSessionState, eventType: .keyDown
                        )
                        let mouseIdle = CGEventSource.secondsSinceLastEventType(
                            .combinedSessionState, eventType: .leftMouseDown
                        )
                        let idleSeconds = min(keyIdle, mouseIdle)
                        guard idleSeconds >= 5 else { return }

                        await self.activityFlagState.clear()
                        self.scanOpenNotes()
                    }
                }
            }
        }
        Self.log.info("Activity tracking started (adaptive idle detection)")
    }

    func stopTracking() {
        scanTask?.cancel()
        scanTask = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
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

    /// Collects scan results before applying to minimize @Observable churn.
    /// Returns: [(pageId, hashes, changedCount, paragraphs, title)]
    private func collectScanResults(for pageIds: [String]) -> [(String, [UInt64], Int, [String], String)] {
        var results: [(String, [UInt64], Int, [String], String)] = []
        
        for pageId in pageIds {
            let body = NoteWindowManager.shared.currentBody(for: pageId, mapped: true)
            guard !body.isEmpty else { continue }

            let paragraphs = body.components(separatedBy: "\n\n")
            let hashes = paragraphs.map { hashParagraph($0) }

            let previous = paragraphHashes[pageId]
            var changedCount = 0
            
            if let prev = previous {
                let maxCount = max(hashes.count, prev.count)
                for i in 0..<maxCount {
                    let oldHash: UInt64 = i < prev.count ? prev[i] : 0
                    let newHash: UInt64 = i < hashes.count ? hashes[i] : 0
                    if oldHash != newHash { changedCount += 1 }
                }
            }

            let title = fetchPageTitle(pageId: pageId) ?? "Untitled"
            results.append((pageId, hashes, changedCount, paragraphs, title))
        }
        
        return results
    }

    private func scanOpenNotes() {
        let pageIds = Array(NoteWindowManager.shared.orderedPageIds().prefix(Self.maxTrackedTabs))
        guard !pageIds.isEmpty else { return }

        // Collect results first (reads paragraphHashes, doesn't modify)
        let results = collectScanResults(for: pageIds)
        
        // Apply all modifications in a single batch to minimize @Observable churn
        // and ensure proper isolation
        applyScanResults(results)
    }
    
    private func applyScanResults(_ results: [(String, [UInt64], Int, [String], String)]) {
        for (pageId, hashes, changedCount, paragraphs, title) in results {
            // Record edit event if changes detected
            if changedCount > 0 {
                appendEvent(.noteEdited(
                    pageId: pageId, title: title,
                    changedParagraphs: changedCount, totalParagraphs: paragraphs.count
                ))
            }
            
            // Update paragraph hashes - this is the @Observable modification point
            paragraphHashes[pageId] = hashes
        }
    }

    private func snapshotParagraphs(for pageId: String) {
        let body = NoteWindowManager.shared.currentBody(for: pageId, mapped: true)
        guard !body.isEmpty else { return }
        let paragraphs = body.components(separatedBy: "\n\n")
        paragraphHashes[pageId] = paragraphs.map { hashParagraph($0) }
    }

    /// Deterministic FNV-1a 64-bit hash — stable across process launches (unlike Swift's Hasher).
    /// Critical for cross-session paragraph diffing and Time Machine delta detection.
    private nonisolated func hashParagraph(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325 // FNV offset basis
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3 // FNV prime
        }
        return hash
    }

    private func fetchPageTitle(pageId: String) -> String? {
        guard let context = AppBootstrap.shared?.modelContainer.mainContext else { return nil }
        let targetId = pageId
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == targetId }
        )
        do {
            return try context.fetch(descriptor).first?.title
        } catch {
            Self.log.error("ActivityTracker: failed to fetch page title: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Ring Buffer

    private func appendEvent(_ kind: ActivityEventKind) {
        let event = ActivityEvent(timestamp: Date(), kind: kind)
        events.append(event)
        if events.count > Self.maxEvents {
            events.removeFirst(events.count - Self.maxEvents)
        }
        guard let eventStore = eventStoreProvider() else {
            Self.log.error("ActivityTracker: EventStore unavailable; skipping durable event append")
            return
        }
        eventStore.appendEvent(sessionId: sessionId, kind: kind)
    }

    /// Flush in-memory events to disk as JSON for crash resilience.
    func flushToDisk() {
        guard !events.isEmpty else { return }
        let eventsCopy = self.events
        let data: Data
        do {
            data = try JSONEncoder().encode(eventsCopy)
        } catch {
            Self.log.error("ActivityTracker: failed to encode events for flush: \(error.localizedDescription)")
            return
        }
        let text: String
        do {
            text = try FoundationSafety.utf8String(from: data)
        } catch {
            Self.log.error("ActivityTracker: failed to encode flush payload as UTF-8: \(error.localizedDescription)")
            return
        }
        let url = cacheFileURLProvider()
        guard NoteFileStorage.writeTextAtomically(text, to: url, itemLabel: Self.flushFileLabel) else {
            Self.log.error("ActivityTracker: durable flush write failed")
            return
        }
        Self.log.info("Flushed \(eventsCopy.count) events to disk")
    }

    /// Load previously flushed events on startup (crash recovery).
    func loadFlushedEvents() {
        let url = cacheFileURLProvider()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            Self.log.error("ActivityTracker: failed to load flushed event cache: \(error.localizedDescription)")
            return
        }
        let loaded: [ActivityEvent]
        do {
            loaded = try JSONDecoder().decode([ActivityEvent].self, from: data)
        } catch {
            Self.log.error("ActivityTracker: failed to decode flushed events: \(error.localizedDescription)")
            return
        }
        events = Array((loaded + events).suffix(Self.maxEvents))
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Self.log.error("ActivityTracker: failed to remove flushed event cache: \(error.localizedDescription)")
        }
        Self.log.info("Recovered \(loaded.count) flushed events")
    }

    private nonisolated static func defaultFlushFileURL() -> URL {
        let appSupport = FoundationSafety.userApplicationSupportDirectory()
        let dir = appSupport.appendingPathComponent("Epistemos")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            log.error("ActivityTracker: failed to create flush directory: \(error.localizedDescription)")
        }
        return dir.appendingPathComponent("activity-events-cache.json")
    }
}

// MARK: - Per-Node Activity Scoring

extension ActivityTracker {

    /// Activity score for a specific page (0.0 to 1.0).
    /// Combines edit frequency, visit frequency, and recency of activity.
    /// Used by WeightedContextEngine to boost nodes the user actively works on.
    func activityScore(for pageId: String) -> Double {
        let now = Date()
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 24 * 3600)
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 3600)

        var editCount7d = 0
        var editCount30d = 0
        var openCount7d = 0
        var openCount30d = 0
        var lastActivity: Date?

        for event in events {
            guard event.timestamp >= thirtyDaysAgo else { continue }
            switch event.kind {
            case .noteEdited(let pid, _, _, _) where pid == pageId:
                editCount30d += 1
                if event.timestamp >= sevenDaysAgo { editCount7d += 1 }
                if lastActivity == nil || event.timestamp > (lastActivity ?? .distantPast) {
                    lastActivity = event.timestamp
                }
            case .noteOpened(let pid, _) where pid == pageId:
                openCount30d += 1
                if event.timestamp >= sevenDaysAgo { openCount7d += 1 }
                if lastActivity == nil || event.timestamp > (lastActivity ?? .distantPast) {
                    lastActivity = event.timestamp
                }
            default:
                break
            }
        }

        guard editCount30d > 0 || openCount30d > 0 else { return 0 }

        // Dual decay scoring (from research synthesis):
        // Fast signal (7-day half-life): captures "currently working on"
        // Slow signal (90-day half-life): captures "long-term importance"
        let fastDecay: Double
        let slowDecay: Double
        if let last = lastActivity {
            let days = now.timeIntervalSince(last) / (24 * 3600)
            fastDecay = exp(-days / 7.0)   // 7-day half-life
            slowDecay = exp(-days / 90.0)  // 90-day half-life
        } else {
            fastDecay = 0
            slowDecay = 0
        }

        // Edit intensity (7-day, normalized)
        let recentEditScore = min(Double(editCount7d) / 10.0, 1.0)
        // Total engagement (30-day, normalized)
        let totalEngagement = min(Double(editCount30d + openCount30d) / 20.0, 1.0)

        // Combined: fast decay weighted 70%, slow decay 30% (per research)
        let recencyBlend = fastDecay * 0.7 + slowDecay * 0.3

        return recentEditScore * 0.35 + totalEngagement * 0.25 + recencyBlend * 0.40
    }

    /// Global activity profile — cross-node patterns for AI context.
    func globalActivityProfile() -> GlobalActivityProfile {
        let now = Date()
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 3600)
        let recentEvents = events.filter { $0.timestamp >= sevenDaysAgo }

        var editsByPage: [String: Int] = [:]
        var opensByPage: [String: Int] = [:]
        var chatCount = 0

        for event in recentEvents {
            switch event.kind {
            case .noteEdited(let pid, _, _, _):
                editsByPage[pid, default: 0] += 1
            case .noteOpened(let pid, _):
                opensByPage[pid, default: 0] += 1
            case .chatMessageSent:
                chatCount += 1
            case .noteClosed:
                break
            }
        }

        let topEditedIds = editsByPage.sorted { $0.value > $1.value }.prefix(5).map(\.key)
        let topVisitedIds = opensByPage.sorted { $0.value > $1.value }.prefix(5).map(\.key)
        let totalEdits = editsByPage.values.reduce(0, +)
        let totalVisits = opensByPage.values.reduce(0, +)

        return GlobalActivityProfile(
            topEditedPageIds: Array(topEditedIds),
            topVisitedPageIds: Array(topVisitedIds),
            totalEdits7d: totalEdits,
            totalVisits7d: totalVisits,
            chatMessages7d: chatCount,
            activePageCount: editsByPage.count
        )
    }
}

struct GlobalActivityProfile {
    let topEditedPageIds: [String]
    let topVisitedPageIds: [String]
    let totalEdits7d: Int
    let totalVisits7d: Int
    let chatMessages7d: Int
    let activePageCount: Int

    /// Formats as context for AI prompt injection.
    func formatForPrompt() -> String {
        var lines: [String] = []
        lines.append("Activity (7d): \(totalEdits7d) edits, \(totalVisits7d) visits, \(chatMessages7d) chats across \(activePageCount) notes")
        return lines.joined(separator: "\n")
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
