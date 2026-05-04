//  AgentServiceClient.swift
//  Epistemos — AgentXPC Client
//
//  @MainActor-bound client that connects to `com.epistenos.agentxpc`.
//  All public methods are async; XPC reply callbacks are bridged
//  through continuations with automatic connection recovery.
//

import Foundation

/// Client for the bounded agent execution XPC helper.
///
/// Usage:
/// ```swift
/// let client = AgentServiceClient()
/// try await client.connect()
/// let status = try await client.ping()
/// try await client.submit(sequence: 42)
/// ```
@MainActor
public final class AgentServiceClient: @unchecked Sendable {

    // MARK: - State

    /// The underlying NSXPCConnection. `nil` when disconnected.
    private var connection: NSXPCConnection?

    /// Serializes connect/disconnect/reconnect logic.
    private let stateLock = NSLock()

    /// Service name registered in the XPC service Info.plist.
    private static let serviceName = "com.epistenos.agentxpc"

    /// Maximum time to wait for an XPC reply before failing.
    private static let replyTimeout: Duration = .seconds(30)

    // MARK: - Lifecycle

    public init() {}

    deinit {
        disconnect()
    }

    // MARK: - Connection Management

    /// Establishes a new XPC connection to AgentXPC.
    ///
    /// Idempotent: if already connected, returns immediately.
    /// Throws `XPCError.connectionInvalid` if the interface cannot be configured.
    public func connect() throws {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard connection == nil else { return }

        let newConnection = NSXPCConnection(serviceName: Self.serviceName)
        newConnection.remoteObjectInterface = NSXPCInterface(with: AgentServiceProtocol.self)

        // Exported interface is nil — the client does not vend services to the helper.
        newConnection.exportedInterface = nil
        newConnection.exportedObject = nil

        // Interruption / invalidation handlers run on a private queue.
        // We trampoline back to MainActor via Task for state cleanup.
        newConnection.interruptionHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleInterruption()
            }
        }
        newConnection.invalidationHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleInvalidation()
            }
        }

        newConnection.resume()
        self.connection = newConnection
    }

    /// Tears down the current connection. Safe to call repeatedly.
    public func disconnect() {
        stateLock.lock()
        defer { stateLock.unlock() }
        connection?.invalidate()
        connection = nil
    }

    // MARK: - Public API

    /// Submit a sequence number to the AgentXPC helper.
    ///
    /// The caller must have already written the request into the shared arena
    /// at the slot indexed by `sequence % SLOT_COUNT`.
    ///
    /// - Parameter sequence: Arena request-slot sequence number.
    /// - Throws: `XPCError` on transport or capability failure.
    public func submit(sequence: UInt64) async throws {
        let proxy = try remoteProxy()

        return try await withCheckedThrowingContinuation { continuation in
            let deadline = Task {
                try await Task.sleep(for: Self.replyTimeout)
                continuation.resume(throwing: XPCError.replyTimeout)
            }

            proxy.submit(sequence: sequence) { [weak self] error in
                deadline.cancel()
                guard let self else {
                    continuation.resume(throwing: XPCError.connectionInvalid)
                    return
                }
                if let xpcErr = XPCError.from(error) {
                    continuation.resume(throwing: xpcErr)
                } else if let nsErr = error {
                    continuation.resume(throwing: XPCError.unknown(nsErr.code))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Best-effort cancellation of an in-flight task.
    ///
    /// Does not throw on transport failure — cancellation is a hint, not a guarantee.
    /// - Parameter sequence: The sequence number previously submitted.
    public func cancel(sequence: UInt64) async {
        guard let proxy = try? remoteProxy() else { return }

        await withCheckedContinuation { continuation in
            proxy.cancel(sequence: sequence) { _ in
                // Cancellation is fire-and-forget from the caller's perspective.
                continuation.resume()
            }
        }
    }

    /// Health check.
    ///
    /// - Returns: The helper's status string (e.g. "AgentXPC ok").
    /// - Throws: `XPCError` on transport failure.
    public func ping() async throws -> String {
        let proxy = try remoteProxy()

        return try await withCheckedThrowingContinuation { continuation in
            let deadline = Task {
                try await Task.sleep(for: Self.replyTimeout)
                continuation.resume(throwing: XPCError.replyTimeout)
            }

            proxy.ping { status, error in
                deadline.cancel()
                if let xpcErr = XPCError.from(error) {
                    continuation.resume(throwing: xpcErr)
                } else if let nsErr = error {
                    continuation.resume(throwing: XPCError.unknown(nsErr.code))
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    // MARK: - Private

    /// Returns the remote proxy, reconnecting lazily if needed.
    private func remoteProxy() throws -> AgentServiceProtocol {
        stateLock.lock()
        defer { stateLock.unlock() }

        if connection == nil {
            // Auto-reconnect on first use or after interruption.
            // We must create the connection while holding the lock,
            // then resume it (resume is safe to call without further locking).
            let newConnection = NSXPCConnection(serviceName: Self.serviceName)
            newConnection.remoteObjectInterface = NSXPCInterface(with: AgentServiceProtocol.self)
            newConnection.interruptionHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleInterruption()
                }
            }
            newConnection.invalidationHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleInvalidation()
                }
            }
            newConnection.resume()
            self.connection = newConnection
        }

        guard let proxy = connection?.remoteObjectProxy as? AgentServiceProtocol else {
            throw XPCError.connectionInvalid
        }
        return proxy
    }

    private func handleInterruption() {
        stateLock.lock()
        connection = nil
        stateLock.unlock()
    }

    private func handleInvalidation() {
        stateLock.lock()
        connection = nil
        stateLock.unlock()
    }
}
