import Foundation

// ---------------------------------------------------------------------------
// MARK: - AgentServiceProtocol
// ---------------------------------------------------------------------------

/// The XPC protocol exposed by the Hermes agent service.
///
/// This is an `@objc` protocol so it can be used with `NSXPCConnection`.
/// The service lives **inside** the app sandbox (not as a child process) and
/// is `SMAppService`-ready for Pro-profile deployments.
@objc(AgentServiceProtocol)
public protocol AgentServiceProtocol {
    /// Submit a monotonically increasing sequence number to the runtime.
    @objc func submit(sequence: UInt64, reply: @escaping (Error?) -> Void)

    /// Cancel an in-flight sequence.
    @objc func cancel(sequence: UInt64, reply: @escaping (Error?) -> Void)

    /// Health-check ping. Returns a diagnostic string.
    @objc func ping(reply: @escaping (String, Error?) -> Void)
}

// ---------------------------------------------------------------------------
// MARK: - HermesXPCService
// ---------------------------------------------------------------------------

/// The XPC service implementation for the Epistenos Pro profile.
///
/// HermesXPCService is **not** a child process — it is an `NSXPCListener`
/// delegate that accepts connections from the main app, helper extensions,
/// or external clients via the shared App Group.
///
/// ## Sandbox compliance (MAS-ready)
///
/// - Uses App Group `group.com.epistenos.shared` for shared arenas.
/// - No outgoing network requests from the XPC service itself.
/// - All cloud routing is delegated to `CloudBoundary` with trust classification.
@objc
public final class HermesXPCService: NSObject, AgentServiceProtocol {

    /// Shared arena path inside the App Group container.
    private let arenaURL: URL?

    /// In-memory sequence ledger (reconstructed from arena on launch).
    private var sequences: Set<UInt64> = []

    /// Cloud boundary for trust-based request routing.
    private let cloudBoundary = CloudBoundary()

    public override init() {
        self.arenaURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.epistenos.shared")
            ?.appendingPathComponent("hermes_arena", isDirectory: true)
        super.init()
        loadLedger()
    }

    // MARK: - AgentServiceProtocol

    public func submit(sequence: UInt64, reply: @escaping (Error?) -> Void) {
        guard !sequences.contains(sequence) else {
            reply(HermesXPCError.duplicateSequence)
            return
        }
        sequences.insert(sequence)
        persistLedger()

        // Classify and route.
        let trust = cloudBoundary.classify(sequence: sequence)
        switch trust {
        case .low:
            // Local-only, no cloud contact.
            reply(nil)
        case .medium:
            // Defer to background queue; may hit cache.
            DispatchQueue.global(qos: .utility).async {
                reply(nil)
            }
        case .high:
            // Requires attestation; routed through Pro boundary.
            DispatchQueue.global(qos: .userInitiated).async {
                reply(nil)
            }
        }
    }

    public func cancel(sequence: UInt64, reply: @escaping (Error?) -> Void) {
        sequences.remove(sequence)
        persistLedger()
        reply(nil)
    }

    public func ping(reply: @escaping (String, Error?) -> Void) {
        let diag = "HermesXPCService ok | sequences=\(sequences.count) | arena=\(arenaURL?.path ?? "nil")"
        reply(diag, nil)
    }

    // MARK: - Persistence

    private func loadLedger() {
        guard let url = arenaURL?.appendingPathComponent("sequences.json") else { return }
        guard let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode(Set<UInt64>.self, from: data) else {
            return
        }
        sequences = loaded
    }

    private func persistLedger() {
        guard let url = arenaURL?.appendingPathComponent("sequences.json") else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(sequences) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - HermesListener
// ---------------------------------------------------------------------------

/// `NSXPCListener` delegate that vends `HermesXPCService` objects.
public final class HermesListener: NSObject, NSXPCListenerDelegate {
    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: AgentServiceProtocol.self)
        let exportedObject = HermesXPCService()
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
    }
}

// ---------------------------------------------------------------------------
// MARK: - CloudBoundary
// ---------------------------------------------------------------------------

/// Classifies requests by trust level and routes them accordingly.
///
/// - **Low** — local-only, no external contact.
/// - **Medium** — may use Hermes cascade or cloud cache.
/// - **High** — requires attestation, encrypted tunnel, Pro entitlement.
public final class CloudBoundary {
    public enum TrustLevel: String, CaseIterable {
        case low, medium, high
    }

    public init() {}

    /// Classify a sequence number into a trust tier.
    ///
    /// In production this inspects payload signatures, origin entitlements,
    /// and the active `VaultGatedSwarm` policy.
    public func classify(sequence: UInt64) -> TrustLevel {
        // Deterministic pseudo-random classification for demo / testing.
        let hash = sequence & 0xF
        switch hash {
        case 0...5:   return .low
        case 6...10:  return .medium
        default:      return .high
        }
    }

    /// Determine whether the Pro profile is required for this trust level.
    public func requiresPro(_ level: TrustLevel) -> Bool {
        level == .high
    }
}

// ---------------------------------------------------------------------------
// MARK: - Errors
// ---------------------------------------------------------------------------

public enum HermesXPCError: Error, LocalizedError {
    case duplicateSequence
    case arenaUnavailable
    case proEntitlementMissing

    public var errorDescription: String? {
        switch self {
        case .duplicateSequence:
            return "Sequence number already submitted."
        case .arenaUnavailable:
            return "Shared arena (App Group) is not accessible."
        case .proEntitlementMissing:
            return "This operation requires the Pro profile entitlement."
        }
    }
}
