import SwiftUI
import Combine

// MARK: - Raw Agent Event (bridge type)

/// A raw event returned from the Rust-backed event store via UniFFI.
/// Codable for any JSON-based transport; the bridge layer converts this
/// into `ProvenanceEventRow` for consumption by SwiftUI.
public struct RawAgentEvent: Codable {
    public let timestamp: Date
    public let actor: String
    public let action: String
    public let tier: String
    public let status: String
    public let hash: String
    public let prevHash: String
    public let metadata: [String: String]

    public init(
        timestamp: Date,
        actor: String,
        action: String,
        tier: String,
        status: String,
        hash: String,
        prevHash: String,
        metadata: [String: String]
    ) {
        self.timestamp = timestamp
        self.actor = actor
        self.action = action
        self.tier = tier
        self.status = status
        self.hash = hash
        self.prevHash = prevHash
        self.metadata = metadata
    }
}

// MARK: - EventStore Bridge

/// Actor-isolated bridge to the Rust event store.
/// All FFI calls go through here so the UI layer never blocks the main thread.
public actor EventStoreBridge {
    /// Fetch the most recent `limit` events from the store.
    public func recentEvents(limit: Int) async throws -> [RawAgentEvent] {
        // TODO: Wire to actual UniFFI-generated Rust FFI.
        // Example:
        //   let raw = try rustEventStore.recent_events(limit: UInt32(limit))
        //   return raw.map { … }
        return []
    }

    /// Stream new events as they arrive (push-based).
    public func eventStream() -> AsyncStream<RawAgentEvent> {
        // TODO: Wire to Rust-backed notification channel.
        return AsyncStream { _ in }
    }
}

// MARK: - Provenance Console State

@MainActor
@Observable
public final class ProvenanceConsoleState {

    // MARK: Public UI State

    /// All events loaded from the store.
    public var events: [ProvenanceEventRow] = []

    /// Active filter applied to the event list.
    public var filter: ProvenanceFilter = .all {
        didSet { applyFilter(filter) }
    }

    /// Whether live polling is active.
    public var isLive: Bool = true

    /// Currently selected event for the inspector pane.
    public var selectedEvent: ProvenanceEventRow?

    /// Free-text search query.
    public var searchQuery: String = ""

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()
    private let eventStore: EventStoreBridge

    // MARK: Init

    public init(eventStore: EventStoreBridge) {
        self.eventStore = eventStore
    }

    // MARK: Derived State

    /// The list of events after applying the active filter and search query.
    public var filteredEvents: [ProvenanceEventRow] {
        var result = events

        // Tier / actor filter
        if filter != .all {
            switch filter {
            case .error:
                result = result.filter { $0.status == .failure }
            case .security:
                result = result.filter {
                    $0.action.localizedCaseInsensitiveContains("vault")
                        || $0.action.localizedCaseInsensitiveContains("gate")
                        || $0.action.localizedCaseInsensitiveContains("auth")
                        || $0.actor.localizedCaseInsensitiveContains("sovereign")
                }
            default:
                let target = filter.rawValue.lowercased()
                result = result.filter {
                    $0.actor.localizedCaseInsensitiveContains(target)
                        || $0.tier.rawValue.lowercased() == target
                }
            }
        }

        // Free-text search
        if !searchQuery.isEmpty {
            let q = searchQuery
            result = result.filter {
                $0.action.localizedCaseInsensitiveContains(q)
                    || $0.actor.localizedCaseInsensitiveContains(q)
                    || $0.hash.localizedCaseInsensitiveContains(q)
                    || $0.metadata.values.contains(where: { $0.localizedCaseInsensitiveContains(q) })
            }
        }

        return result
    }

    // MARK: Actions

    /// Load the most recent events from the event store.
    public func loadEvents() async {
        do {
            let rawEvents = try await eventStore.recentEvents(limit: 500)
            self.events = rawEvents.map { ProvenanceEventRow(from: $0) }
        } catch {
            // Preserve existing events on failure; do not crash the UI.
            print("[ProvenanceConsole] Failed to load events: \(error)")
        }
    }

    /// Set the active filter.
    public func applyFilter(_ filter: ProvenanceFilter) {
        self.filter = filter
    }

    /// Update the search query.
    public func search(_ query: String) {
        self.searchQuery = query
    }

    /// Export all current events to a pretty-printed JSON payload.
    public func exportToJSON() async -> Data {
        let export: [[String: Any]] = events.map { event in
            [
                "id": event.id.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: event.timestamp),
                "actor": event.actor,
                "action": event.action,
                "tier": event.tier.rawValue,
                "status": event.status.rawValue,
                "hash": event.hash,
                "prevHash": event.prevHash,
                "metadata": event.metadata
            ]
        }

        guard JSONSerialization.isValidJSONObject(export) else {
            print("[ProvenanceConsole] Export object is not valid JSON")
            return Data()
        }

        do {
            return try JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
        } catch {
            print("[ProvenanceConsole] JSON serialization failed: \(error)")
            return Data()
        }
    }

    // MARK: Live Polling

    /// Start a 2-second Timer publisher that re-loads events.
    /// Safe to call multiple times — old timers are cancelled first.
    public func startLivePolling() {
        stopLivePolling()
        guard isLive else { return }

        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task { @MainActor [weak self] in
                    await self?.loadEvents()
                }
            }
            .store(in: &cancellables)
    }

    /// Cancel all active Combine subscriptions (stops the live timer).
    public func stopLivePolling() {
        cancellables.removeAll()
    }
}

// MARK: - ProvenanceEventRow Factory

extension ProvenanceEventRow {
    /// Bridge constructor: convert a `RawAgentEvent` from the FFI layer
    /// into the UI-friendly `ProvenanceEventRow`.
    init(from raw: RawAgentEvent) {
        self.id = UUID()
        self.timestamp = raw.timestamp
        self.actor = raw.actor
        self.action = raw.action
        self.tier = EventTier(rawValue: raw.tier) ?? .core
        self.status = EventStatus(rawValue: raw.status) ?? .pending
        self.hash = raw.hash
        self.prevHash = raw.prevHash
        self.metadata = raw.metadata
    }
}
