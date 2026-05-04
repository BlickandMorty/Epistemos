//  AgentService.swift
//  AgentXPC — Service Implementation
//
//  Stateless executor. Every request carries its own capability grant
//  in the shared arena; the helper only verifies, never authorizes.
//

import Foundation

final class AgentService: NSObject, AgentServiceProtocol {

    /// Bridge to the Rust runtime inside the XPC helper process.
    /// Holds no authoritative state; dispatches to the Rust `agent_core`
    /// runtime which verifies grants via `capability.rs`.
    private let runtime = AgentRuntimeBridge()

    // MARK: - AgentServiceProtocol

    func submit(sequence: UInt64, reply: @escaping (NSError?) -> Void) {
        Task.detached { [weak self] in
            guard let self else {
                reply(XPCError.connectionInvalid.asNSError())
                return
            }
            do {
                try await self.runtime.process(sequence: sequence)
                reply(nil)
            } catch {
                reply(error as NSError)
            }
        }
    }

    func cancel(sequence: UInt64, reply: @escaping (NSError?) -> Void) {
        runtime.cancel(sequence: sequence)
        reply(nil)
    }

    func ping(reply: @escaping (String, NSError?) -> Void) {
        reply("AgentXPC ok", nil)
    }
}

// MARK: - AgentRuntimeBridge (placeholder for Rust FFI integration)

/// Thin Swift wrapper that bridges to the Rust `agent_core` runtime.
///
/// The real implementation lives in the UniFFI-generated bindings.
/// This placeholder documents the required surface area.
actor AgentRuntimeBridge {

    /// Process the request staged at the given arena sequence number.
    /// - Parameter sequence: Arena slot sequence number.
    /// - Throws: Any error from the Rust runtime (capability failure, tool error, etc.).
    func process(sequence: UInt64) async throws {
        // TODO: UniFFI bridge call into `agent_core::runtime::process_request(sequence)`
        // The Rust side reads the arena slot, verifies the capability grant,
        // executes the tool, and writes the response back into the arena.
        _ = sequence
    }

    /// Best-effort cancellation signal.
    /// - Parameter sequence: The sequence number to cancel.
    func cancel(sequence: UInt64) {
        // TODO: UniFFI bridge call into `agent_core::runtime::cancel_request(sequence)`
        _ = sequence
    }
}
