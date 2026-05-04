//  AgentServiceProtocol.swift
//  Epistemos — XPC Service Protocols
//
//  Control-plane only. Handles and sequence numbers cross the XPC boundary;
//  payloads live in the App Group arena or blob store.
//

import Foundation

// MARK: - AgentXPC Protocol

/// Protocol for the bounded agent execution helper (AgentXPC).
/// The main app places request metadata in the shared arena, then calls
/// `submit(sequence:)` with the arena slot sequence number. The helper
/// reads the slot, verifies the enclosed capability grant, executes,
/// and writes the response back into the arena.
@objc(EPAgentServiceProtocol)
public protocol AgentServiceProtocol {
    /// The app has placed a request in the shared arena and wants the helper to process it.
    /// - Parameters:
    ///   - sequence: Arena request-slot sequence number.
    ///   - reply: nil on success, or an `NSError` with domain `EPXPCErrorDomain`.
    func submit(sequence: UInt64, reply: @escaping (NSError?) -> Void)

    /// Best-effort cancellation for a cooperative in-flight task.
    /// - Parameters:
    ///   - sequence: The sequence number previously submitted.
    ///   - reply: nil when the cancellation signal has been relayed.
    func cancel(sequence: UInt64, reply: @escaping (NSError?) -> Void)

    /// Health and version probe for diagnostics / review notes.
    /// - Parameter reply: A human-readable status string and an optional error.
    func ping(reply: @escaping (String, NSError?) -> Void)
}

// MARK: - ProviderXPC Protocol

/// Protocol for the cloud-provider routing helper (ProviderXPC).
/// Same control-plane discipline as AgentXPC: the app writes the
/// provider request into the shared arena, then signals via sequence number.
@objc(EPProviderServiceProtocol)
public protocol ProviderServiceProtocol {
    /// Submit a provider-bound request that has been staged in the shared arena.
    /// - Parameters:
    ///   - sequence: Arena request-slot sequence number.
    ///   - providerID: Curated provider identifier (e.g. "anthropic", "openai").
    ///   - reply: nil on success, or an `NSError` with domain `EPXPCErrorDomain`.
    func submitProviderRequest(sequence: UInt64, providerID: String, reply: @escaping (NSError?) -> Void)

    /// Best-effort cancellation of an in-flight provider request.
    /// - Parameters:
    ///   - sequence: The sequence number previously submitted.
    ///   - reply: nil when the cancellation signal has been relayed.
    func cancelProviderRequest(sequence: UInt64, reply: @escaping (NSError?) -> Void)

    /// Health and version probe.
    /// - Parameter reply: A human-readable status string and an optional error.
    func pingProvider(reply: @escaping (String, NSError?) -> Void)
}

// MARK: - XPC Error Domain and Typed Errors

/// Domain for all XPC-layer errors originating from Epistemos helpers.
public let EPXPCErrorDomain = "com.epistenos.xpc"

/// Typed error enum mapped into `NSError` for XPC transport.
///
/// Raw values are stable; add new cases at the end only.
public enum XPCError: Error, Sendable {
    case connectionInterrupted
    case connectionInvalid
    case replyTimeout
    case capabilityDenied
    case capabilityExpired
    case capabilityTampered
    case arenaFull
    case arenaCorrupted
    case helperBusy
    case unknown(Int)
}

extension XPCError {
    /// Stable error code for `NSError` interoperability.
    public var code: Int {
        switch self {
        case .connectionInterrupted: return 1001
        case .connectionInvalid:     return 1002
        case .replyTimeout:          return 1003
        case .capabilityDenied:      return 2001
        case .capabilityExpired:     return 2002
        case .capabilityTampered:    return 2003
        case .arenaFull:             return 3001
        case .arenaCorrupted:        return 3002
        case .helperBusy:            return 4001
        case .unknown(let c):        return c
        }
    }

    /// Human-readable description suitable for logs and UI.
    public var localizedDescription: String {
        switch self {
        case .connectionInterrupted:
            return "XPC connection interrupted — helper may have crashed or been terminated."
        case .connectionInvalid:
            return "XPC connection invalid — cannot reach helper."
        case .replyTimeout:
            return "XPC reply timed out — helper did not respond within deadline."
        case .capabilityDenied:
            return "Capability grant denied — action not allowed by issued grant."
        case .capabilityExpired:
            return "Capability grant expired — re-authenticate to continue."
        case .capabilityTampered:
            return "Capability grant tampered — signature verification failed."
        case .arenaFull:
            return "Shared arena ring buffer full — backpressure signaled."
        case .arenaCorrupted:
            return "Shared arena header corrupted — re-initialization required."
        case .helperBusy:
            return "Helper busy — too many concurrent requests."
        case .unknown(let c):
            return "Unknown XPC error (code \(c))."
        }
    }
}

extension XPCError {
    /// Bridge to `NSError` for NSXPCConnection reply blocks.
    public func asNSError() -> NSError {
        return NSError(
            domain: EPXPCErrorDomain,
            code: code,
            userInfo: [NSLocalizedDescriptionKey: localizedDescription]
        )
    }

    /// Bridge from `NSError` received in an XPC reply block.
    public static func from(_ error: NSError?) -> XPCError? {
        guard let error = error else { return nil }
        guard error.domain == EPXPCErrorDomain else {
            return .unknown(error.code)
        }
        switch error.code {
        case 1001: return .connectionInterrupted
        case 1002: return .connectionInvalid
        case 1003: return .replyTimeout
        case 2001: return .capabilityDenied
        case 2002: return .capabilityExpired
        case 2003: return .capabilityTampered
        case 3001: return .arenaFull
        case 3002: return .arenaCorrupted
        case 4001: return .helperBusy
        default:   return .unknown(error.code)
        }
    }
}
