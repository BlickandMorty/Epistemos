// VENDORED (adapter_wrap) — osaurus-ai/osaurus (MIT). See OsaurusVendorProvenance.swift
// in this directory for the full license + record. From
// Packages/OsaurusCore/Models/Chat/InternalMessage.swift. Posture is adapter_wrap
// (NOT verbatim direct_import): the type BODIES below are byte-for-byte from
// OsaurusCore, but wrapped in the `OsaurusVendor` namespace because Epistemos already
// declares a top-level `MessageRole` (Models/BrandedTypes.swift) and `Message` —
// namespacing avoids the collision. Pro-gated (the Act-Osaurus MAS/Pro boundary).
#if !EPISTEMOS_APP_STORE
import Foundation

/// Namespace for vendored Osaurus wire types (keeps them off Epistemos's top-level
/// names). The Act-Osaurus bridge shapes requests in this format.
enum OsaurusVendor {
    // --- BEGIN VERBATIM bodies (osaurus-ai/osaurus, MIT) ---

    /// Message role for chat interactions
    enum MessageRole: String, Codable, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    /// Chat message structure
    struct Message: Codable, Sendable {
        let role: MessageRole
        let content: String

        init(role: MessageRole, content: String) {
            self.role = role
            self.content = content
        }
    }

    // --- END VERBATIM bodies ---
}
#endif
