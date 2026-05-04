//  ProviderService.swift
//  ProviderXPC — Service Implementation
//
//  Stateless executor for cloud-provider calls. Verifies capability grants
//  from the shared arena; never holds provider credentials ambiently.
//

import Foundation

final class ProviderService: NSObject, ProviderServiceProtocol {

    /// Bridge to the Rust provider runtime inside the XPC helper process.
    /// Credentials are brokered per-request via capability grants; no ambient
    /// provider API keys are stored in the helper.
    private let runtime = ProviderRuntimeBridge()

    // MARK: - ProviderServiceProtocol

    func submitProviderRequest(
        sequence: UInt64,
        providerID: String,
        reply: @escaping (NSError?) -> Void
    ) {
        Task.detached { [weak self] in
            guard let self else {
                reply(XPCError.connectionInvalid.asNSError())
                return
            }
            do {
                try await self.runtime.process(sequence: sequence, providerID: providerID)
                reply(nil)
            } catch {
                reply(error as NSError)
            }
        }
    }

    func cancelProviderRequest(sequence: UInt64, reply: @escaping (NSError?) -> Void) {
        runtime.cancel(sequence: sequence)
        reply(nil)
    }

    func pingProvider(reply: @escaping (String, NSError?) -> Void) {
        reply("ProviderXPC ok", nil)
    }
}

// MARK: - ProviderRuntimeBridge (placeholder for Rust FFI integration)

/// Thin Swift wrapper that bridges to the Rust `agent_core::providers` module.
///
/// The real implementation lives in the UniFFI-generated bindings.
/// This placeholder documents the required surface area.
actor ProviderRuntimeBridge {

    /// Process a provider request staged at the given arena sequence number.
    /// - Parameters:
    ///   - sequence: Arena slot sequence number.
    ///   - providerID: Curated provider identifier.
    /// - Throws: Any error from the Rust runtime.
    func process(sequence: UInt64, providerID: String) async throws {
        // TODO: UniFFI bridge call into `agent_core::providers::process_request(sequence, provider_id)`
        // The Rust side reads the arena slot, verifies the capability grant,
        // checks that the providerID is in `allowed_provider_ids`, and executes
        // the provider adapter.
        _ = sequence
        _ = providerID
    }

    /// Best-effort cancellation signal.
    func cancel(sequence: UInt64) {
        // TODO: UniFFI bridge call into `agent_core::providers::cancel_request(sequence)`
        _ = sequence
    }
}
