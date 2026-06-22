//  EpistemosToolBridge.swift
//  OsaurusCore — EPISTEMOS TOOL / MCP SURFACE SEAM
//
//  P0-B (owner 2026-06-22; auditor 1582 "bring Osaurus's distinctive surfaces —
//  tool/MCP controls — into the old UI"): the act surface drives the old Epistemos
//  UI through the Osaurus engine, so the owner should SEE the engine's distinctive
//  controls — the tools the engine can call and the MCP servers they've wired.
//  Those live in `ToolRegistry` (internal @MainActor ObservableObject) and
//  `MCPProviderManager` (public @MainActor ObservableObject); neither is readable
//  from the Epistemos app module. This file is the read-only primitive seam:
//  it returns ONLY `Sendable` value types (no Osaurus internal type — ToolEntry,
//  OsaurusTool, MCP.Tool — crosses the boundary), exactly like EpistemosModelBridge.
//  Honest: empty when nothing is registered/configured.

import Foundation

/// One Osaurus tool the engine can call, as primitives for the act UI.
public struct EpistemosToolInfo: Sendable, Identifiable {
    public let name: String
    public let description: String
    public let enabled: Bool
    public var id: String { name }
    public init(name: String, description: String, enabled: Bool) {
        self.name = name
        self.description = description
        self.enabled = enabled
    }
}

/// One MCP server the owner has configured, as primitives for the act UI.
public struct EpistemosMCPServerInfo: Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let enabled: Bool
    public let connected: Bool
    public let toolCount: Int
    public init(id: UUID, name: String, enabled: Bool, connected: Bool, toolCount: Int) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.connected = connected
        self.toolCount = toolCount
    }
}

/// Read-only surface over Osaurus's tool + MCP controls for the act UI. `@MainActor`
/// because the backing `ToolRegistry` / `MCPProviderManager` are main-actor
/// `ObservableObject`s. Returns primitives only — the boundary stays as clean as
/// `EpistemosModelBridge`.
public enum EpistemosToolBridge {
    /// The Osaurus tools the engine exposes (name + description + enabled state).
    /// Empty if the registry has no tools. Sorted by name for a stable surface.
    @MainActor public static func tools() -> [EpistemosToolInfo] {
        ToolRegistry.shared.listTools()
            .map { EpistemosToolInfo(name: $0.name, description: $0.description, enabled: $0.enabled) }
            .sorted { $0.name < $1.name }
    }

    /// The MCP servers the owner has configured (name + enabled + live connection +
    /// discovered tool count). Empty when none are configured.
    @MainActor public static func mcpServers() -> [EpistemosMCPServerInfo] {
        let mgr = MCPProviderManager.shared
        let states = mgr.providerStates
        return mgr.configuration.providers.map { provider in
            let state = states[provider.id]
            return EpistemosMCPServerInfo(
                id: provider.id,
                name: provider.name,
                enabled: provider.enabled,
                connected: state?.isConnected ?? false,
                toolCount: state?.discoveredToolCount ?? 0
            )
        }
    }
}
