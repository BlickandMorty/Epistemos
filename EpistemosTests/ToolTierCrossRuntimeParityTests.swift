import Foundation
import Testing

@testable import Epistemos

/// Stage B.3 capability lattice consolidation contract.
///
/// The Swift surface (`ToolSurfacePolicy.coreAppStoreAllowedToolNames`) and the
/// Rust surface (`agent_core::tools::registry::ToolTier`) are two halves of the
/// same lattice: Swift decides which tool *names* the App Store build is
/// allowed to surface to the user, and Rust decides which tools each `ToolTier`
/// actually serves. If a name appears in the Swift allowlist but not in the
/// Rust registry, the user sees a phantom capability that errors at execute
/// time. If a write/destructive tool the Swift allowlist promises is silently
/// downgraded to ChatLite in Rust, the approval gate is bypassed.
///
/// These tests assert the two surfaces stay aligned. They are *contract tests*
/// — they don't exercise behavior, they pin the lattice shape so future renames
/// or tier rebalances on either side surface as a test failure rather than a
/// silent runtime bug.
@Suite("Tool tier cross-runtime parity (Stage B.3)")
struct ToolTierCrossRuntimeParityTests {

    /// Tools that Rust registers conditionally (e.g. only when a backend
    /// env var is set). The parity test sets a dummy env var for these
    /// before listing the registry so the conditional registration fires
    /// — the Rust handler only checks env-var presence at registration
    /// time, not validity, so a placeholder is enough.
    private static let conditionallyRegisteredEnv: [(name: String, value: String)] = [
        ("TAVILY_API_KEY", "epistemos-parity-test-placeholder"),
    ]

    /// Contract 1 — every name in `coreAppStoreAllowedToolNames` must exist
    /// somewhere in the Rust registry. The Rust `Full` tier is the union of
    /// every registered tool, so it's the right denominator: a name that's
    /// missing here means the Rust side has no handler for it at all.
    @Test("Every coreAppStoreAllowedToolNames entry resolves to a known Rust tool")
    func coreAppStoreAllowlistIsSubsetOfRustFullRegistry() throws {
        let vaultPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-tier-parity-\(UUID().uuidString)")
            .path
        try FileManager.default.createDirectory(
            atPath: vaultPath,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: vaultPath) }

        for entry in Self.conditionallyRegisteredEnv {
            setenv(entry.name, entry.value, 1)
        }
        defer {
            for entry in Self.conditionallyRegisteredEnv {
                unsetenv(entry.name)
            }
        }

        let schemas = try listToolsForTier(vaultPath: vaultPath, tier: "full")
        let rustNames = Set(schemas.map { $0.name.lowercased() })

        let swiftAllowed = ToolSurfacePolicy.coreAppStoreAllowedToolNames
        let missing = swiftAllowed.subtracting(rustNames)

        #expect(
            missing.isEmpty,
            """
            ToolSurfacePolicy.coreAppStoreAllowedToolNames references tool names \
            that the Rust agent_core registry does not register at any tier: \
            \(missing.sorted().joined(separator: ", ")). \
            Either rename the Swift allowlist entry to match the Rust handler, \
            register the missing handler in agent_core/src/tools/, or — if the \
            Rust side registers the tool only when a backend env var is set — \
            add that env var to conditionallyRegisteredEnv at the top of this \
            test file.
            """
        )
    }

    /// Contract 2 — destructive tools in the Swift allowlist must NOT be served
    /// at the Rust ChatLite tier. ChatLite is the safe-read-only band; if a
    /// write tool leaks down into ChatLite it bypasses the approval gate. The
    /// destructive tools the App Store build needs (vault_write / write_file /
    /// patch) must live at Agent tier in Rust and rely on the approval pipeline
    /// at runtime.
    @Test("Destructive App Store allowlist entries stay above ChatLite tier")
    func destructiveCoreAppStoreToolsAreNotChatLite() throws {
        let vaultPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-tier-parity-\(UUID().uuidString)")
            .path
        try FileManager.default.createDirectory(
            atPath: vaultPath,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: vaultPath) }

        let chatLiteSchemas = try listToolsForTier(vaultPath: vaultPath, tier: "chat_lite")
        let chatLiteNames = Set(chatLiteSchemas.map { $0.name.lowercased() })

        let destructiveNames: Set<String> = [
            "vault_write",
            "write_file",
            "patch",
        ]

        let leaked = destructiveNames.intersection(chatLiteNames)

        #expect(
            leaked.isEmpty,
            """
            Destructive tools \(leaked.sorted().joined(separator: ", ")) appear \
            at the Rust ChatLite tier — this bypasses the approval pipeline. \
            ChatLite must stay safe-read-only; raise the tier in \
            agent_core/src/tools/registry.rs.
            """
        )
    }
}
