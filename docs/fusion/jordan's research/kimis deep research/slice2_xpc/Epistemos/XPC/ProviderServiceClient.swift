//  ProviderServiceClient.swift
//  Epistemos — ProviderXPC Client
//
//  @MainActor-bound client that connects to `com.epistenos.providerxpc`.
//  Mirrors AgentServiceClient exactly; duplicated intentionally so that
//  future provider-specific semantics (rate-limit, retry, circuit-breaker)
//  can be added without coupling to agent semantics.
//

import Foundation

/// Client for the cloud-provider routing XPC helper.
///
/// The main app stages a provider request in the shared arena, then calls
/// `submitProviderRequest(sequence:providerID:)`. The helper reads the
/// arena slot, verifies the capability grant, and routes to the named provider.
@MainActor
public final class ProviderServiceClient: @unchecked Sendable {

    // MARK: - State

    private var connection: NSXPCConnection?
    private let stateLock = NSLock()

    private static let serviceName = "com.epistenos.providerxpc"
    private static let replyTimeout: Duration = .seconds(30)

    // MARK: - Lifecycle

    public init() {}

    deinit {
        disconnect()
    }

    // MARK: - Connection Management

    /// Establishes a new XPC connection to ProviderXPC.
    public func connect() throws {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard connection == nil else { return }

        let newConnection = NSXPCConnection(serviceName: Self.serviceName)
        newConnection.remoteObjectInterface = NSXPCInterface(with: ProviderServiceProtocol.self)
        newConnection.exportedInterface = nil
        newConnection.exportedObject = nil

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

    /// Tears down the current connection.
    public func disconnect() {
        stateLock.lock()
        defer { stateLock.unlock() }
        connection?.invalidate()
        connection = nil
    }

    // MARK: - Public API

    /// Submit a provider request that has been staged in the shared arena.
    ///
    /// - Parameters:
    ///   - sequence: Arena request-slot sequence number.
    ///   - providerID: Curated provider identifier (e.g. "anthropic", "openai", "perplexity").
    /// - Throws: `XPCError` on transport or capability failure.
    public func submitProviderRequest(sequence: UInt64, providerID: String) async throws {
        let proxy = try remoteProxy()

        return try await withCheckedThrowingContinuation { continuation in
            let deadline = Task {
                try await Task.sleep(for: Self.replyTimeout)
                continuation.resume(throwing: XPCError.replyTimeout)
            }

            proxy.submitProviderRequest(sequence: sequence, providerID: providerID) { error in
                deadline.cancel()
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

    /// Best-effort cancellation of an in-flight provider request.
    ///
    /// - Parameter sequence: The sequence number previously submitted.
    public func cancelProviderRequest(sequence: UInt64) async {
        guard let proxy = try? remoteProxy() else { return }

        await withCheckedContinuation { continuation in
            proxy.cancelProviderRequest(sequence: sequence) { _ in
                continuation.resume()
            }
        }
    }

    /// Health check.
    ///
    /// - Returns: The helper's status string (e.g. "ProviderXPC ok").
    /// - Throws: `XPCError` on transport failure.
    public func pingProvider() async throws -> String {
        let proxy = try remoteProxy()

        return try await withCheckedThrowingContinuation { continuation in
            let deadline = Task {
                try await Task.sleep(for: Self.replyTimeout)
                continuation.resume(throwing: XPCError.replyTimeout)
            }

            proxy.pingProvider { status, error in
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

    private func remoteProxy() throws -> ProviderServiceProtocol {
        stateLock.lock()
        defer { stateLock.unlock() }

        if connection == nil {
            let newConnection = NSXPCConnection(serviceName: Self.serviceName)
            newConnection.remoteObjectInterface = NSXPCInterface(with: ProviderServiceProtocol.self)
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

        guard let proxy = connection?.remoteObjectProxy as? ProviderServiceProtocol else {
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
