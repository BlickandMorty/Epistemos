import Foundation

// ---------------------------------------------------------------------------
// MARK: - AgentProvenanceEvent
// ---------------------------------------------------------------------------

/// A domain event emitted by agents and surfaced to the SwiftUI layer.
///
/// `AgentProvenanceEvent` is the canonical event vocabulary for the Epistenos
/// event-driven substrate. The Simulation Mode v1.6 companion reacts to this
/// stream via the Resonance Gate (§4.1).
public struct AgentProvenanceEvent: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let kind: EventKind
    public let timestamp: Date
    public var payload: String
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        kind: EventKind,
        timestamp: Date = Date(),
        payload: String = "",
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.payload = payload
        self.metadata = metadata
    }
}

// ---------------------------------------------------------------------------
// MARK: - EventKind (v1.6 forward vocabulary)
// ---------------------------------------------------------------------------

extension AgentProvenanceEvent {
    /// Canonical event kinds for the agent event stream.
    ///
    /// Forward vocabulary (PR34, v1.6):
    /// - `steer_requested`: User requested a steering delta.
    /// - `summary_started`: A summarisation run began.
    /// - `summary_delta`: Incremental summary fragment arrived.
    /// - `summary_completed`: Summarisation finished successfully.
    /// - `vault_created`: A new vault was created.
    /// - `vault_archived`: A vault (or companion) was archived / deleted.
    /// - `tool_completed`: A tool invocation succeeded.
    /// - `tool_failed`: A tool invocation failed.
    public enum EventKind: String, Codable, Equatable, Sendable, CaseIterable {
        case steer_requested    = "steer_requested"
        case summary_started    = "summary_started"
        case summary_delta      = "summary_delta"
        case summary_completed  = "summary_completed"
        case vault_created      = "vault_created"
        case vault_archived     = "vault_archived"
        case tool_completed     = "tool_completed"
        case tool_failed        = "tool_failed"
    }
}

// ---------------------------------------------------------------------------
// MARK: - EventStore
// ---------------------------------------------------------------------------

/// A lightweight, in-memory event store that publishes agent diagnostics.
///
/// In production this is backed by the Rust `EventStore` over UniFFI.
/// For the Core tier we keep a ring buffer of the last N events and expose
/// a Combine publisher for live SwiftUI reaction.
@MainActor
public final class EventStore: @unchecked Sendable {
    /// Shared singleton.
    public static let shared = EventStore()

    /// Maximum number of retained events.
    public let capacity: Int

    /// All retained events, oldest-first.
    public private(set) var events: [AgentProvenanceEvent] = []

    /// Closure-based observers (simpler than Combine for @Observable era).
    private var observers: [(AgentProvenanceEvent) -> Void] = []

    public init(capacity: Int = 256) {
        self.capacity = capacity
    }

    /// Append an event to the store and notify observers.
    public func append(_ event: AgentProvenanceEvent) {
        events.append(event)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
        // Notify observers on MainActor
        for observer in observers {
            observer(event)
        }
    }

    /// Subscribe to live events.
    public func onEvent(_ handler: @escaping (AgentProvenanceEvent) -> Void) {
        observers.append(handler)
    }

    /// Remove all observers (useful in previews / tests).
    public func removeAllObservers() {
        observers.removeAll()
    }

    /// Return the N most recent events.
    public func recent(_ n: Int = 10) -> [AgentProvenanceEvent] {
        Array(events.suffix(n))
    }

    /// Filter events by kind.
    public func events(ofKind kind: AgentProvenanceEvent.EventKind) -> [AgentProvenanceEvent] {
        events.filter { $0.kind == kind }
    }
}
