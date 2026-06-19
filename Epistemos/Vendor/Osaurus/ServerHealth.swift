// VENDORED — osaurus-ai/osaurus (MIT). Pro-gated `direct_import`. See
// OsaurusVendorProvenance.swift in this directory for the full license + record.
// The enum body between the VERBATIM markers is byte-for-byte from
// Packages/OsaurusCore/Models/Configuration/ServerHealth.swift; the surrounding
// `#if !EPISTEMOS_APP_STORE` (Epistemos MAS/Pro boundary) and these headers are the
// only Epistemos additions. `L(_:)` is provided by OsaurusVendorLocalization.swift.
#if !EPISTEMOS_APP_STORE

// --- BEGIN VERBATIM (osaurus-ai/osaurus, MIT) ---
//
//  ServerHealth.swift
//  osaurus
//
//  Created by Terence on 8/17/25.
//

import Foundation

/// Represents the health state of the server
public enum ServerHealth: Equatable {
    case stopped
    case starting
    case restarting
    case running
    case stopping
    case error(String)

    /// User-friendly description of the current server state
    var displayTitle: String {
        switch self {
        case .stopped: return L("Server Stopped")
        case .starting: return L("Starting Server...")
        case .restarting: return L("Restarting Server...")
        case .running: return L("Server Running")
        case .stopping: return L("Stopping Server...")
        case .error: return L("Server Error")
        }
    }

    /// Short status description
    var statusDescription: String {
        switch self {
        case .stopped: return L("Stopped")
        case .starting: return L("Starting...")
        case .restarting: return L("Restarting...")
        case .running: return L("Running")
        case .stopping: return L("Stopping...")
        case .error: return L("Error")
        }
    }
}
// --- END VERBATIM ---

#endif
