import Foundation
import os.log

/// Canonical XPC trust spine.
///
/// Codex 2026-05-05 advice items #5 + #9 named the missing piece:
/// every `NSXPCConnection` we open across our own services must
/// pin the peer's code signature via `setCodeSigningRequirement`.
/// Without this, any process can pose as the XPC service.
///
/// `setCodeSigningRequirement` is macOS 13+. Our deployment target
/// is macOS 26, so the API is unconditionally available.
///
/// The requirement string this module produces verifies three things
/// about the peer process:
///   1. `anchor apple generic` — the peer's certificate chain roots in
///      Apple, so a self-signed binary cannot satisfy.
///   2. `identifier "<expected>"` — the peer's bundle identifier
///      matches the XPC service we expect to talk to.
///   3. `certificate leaf[subject.OU] = "<TEAM>"` — the peer was signed
///      by us (Team ID `AL562BVF23` in DEVELOPMENT_TEAM).
///
/// This form is correct for both App Store distribution and
/// Developer ID + notarization. It does NOT pin a specific build hash,
/// so legitimate updates of either side don't break IPC.
enum XPCTrust {
    /// Team identifier from DEVELOPMENT_TEAM in Epistemos.xcodeproj.
    /// Public information — appears in every signed binary's certificate
    /// chain. Bake-in is intentional; a runtime-loaded value would be
    /// a TOCTOU surface (the trust requirement is what gates load).
    static let canonicalTeamIdentifier = "AL562BVF23"

    /// Build the canonical requirement string for `serviceName`.
    static func requirementString(for serviceName: String, teamIdentifier: String = canonicalTeamIdentifier) -> String {
        // The order of clauses is not significant to SecRequirement;
        // ordered here for human readability.
        "anchor apple generic and identifier \"\(serviceName)\" and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
    }

    /// Apply the canonical requirement to an outbound NSXPCConnection.
    ///
    /// `NSXPCConnection.setCodeSigningRequirement(_:)` is non-throwing.
    /// If the requirement string is malformed OR the peer fails to
    /// satisfy it at activation time, the connection's
    /// `invalidationHandler` fires and `remoteObjectProxy` calls error
    /// out — there is no compile-time error reported up front. Callers
    /// must wire `invalidationHandler` to surface the failure.
    static func applyCanonicalRequirement(
        to connection: NSXPCConnection,
        serviceName: String,
        teamIdentifier: String = canonicalTeamIdentifier
    ) {
        let requirement = requirementString(for: serviceName, teamIdentifier: teamIdentifier)
        connection.setCodeSigningRequirement(requirement)
        let logger = Logger(subsystem: "com.epistemos.xpc", category: "trust")
        logger.debug("XPCTrust pinned requirement for '\(serviceName, privacy: .public)'")
    }
}
