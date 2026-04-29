//
//  SidebarToggleState.swift
//  Simulation Mode S6 — multi-toggle state for the picker
//
//  Per DOCTRINE §3.4.2 v1.6 the sidebar's display tree is
//  decoupled from the active workspace:
//
//    - active workspace = ONE entity at a time (drives chrome:
//      mascot pin, colour, font, audit attribution).
//    - display-tree toggles = independent set of entity ids that
//      contribute their nested vault trees to the displayed tree.
//
//  This module owns both pieces of state and persists them
//  per-window to UserDefaults under `simulation.sidebarToggles.<windowId>`.
//

import Foundation
import Observation

/// Stable identifier for any toggleable entity in the picker —
/// company / model / agent (and, in a future slice, sub-agent).
public enum SidebarEntity: Hashable, Sendable, Codable {
    case company(slug: String)
    case model(id: String)
    case agent(id: CompanionId)

    /// Stable string used for UserDefaults persistence.
    public var persistenceKey: String {
        switch self {
        case .company(let slug): return "company:\(slug)"
        case .model(let id): return "model:\(id)"
        case .agent(let id): return "agent:\(id.rawValue)"
        }
    }

    public init?(persistenceKey: String) {
        let parts = persistenceKey.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "company":
            self = .company(slug: String(parts[1]))
        case "model":
            self = .model(id: String(parts[1]))
        case "agent":
            self = .agent(id: CompanionId(rawValue: String(parts[1])))
        default:
            return nil
        }
    }
}

@MainActor
@Observable
public final class SidebarToggleState {
    /// Display-tree toggle set. Toggling any entity adds it to
    /// the displayed sidebar; un-toggling removes it. The active
    /// workspace is implicitly toggled.
    public private(set) var toggled: Set<SidebarEntity> = []

    /// Active workspace — drives the sidebar skin (chrome). At
    /// most one. Setting this implicitly adds the corresponding
    /// `.agent(id:)` to `toggled` (active workspace ⊆ toggled
    /// per §3.4.2).
    public private(set) var activeWorkspace: CompanionId?

    /// Per-window persistence key — the UserDefaults entry will
    /// be `simulation.sidebarToggles.<windowId>`.
    private let windowId: String

    public init(windowId: String = "default") {
        self.windowId = windowId
        load()
    }

    public func toggle(_ entity: SidebarEntity) {
        if toggled.contains(entity) {
            toggled.remove(entity)
        } else {
            toggled.insert(entity)
        }
        persist()
    }

    public func isToggled(_ entity: SidebarEntity) -> Bool {
        toggled.contains(entity)
    }

    /// Set the active workspace agent. Adds the corresponding
    /// `.agent(id:)` toggle if not already present.
    public func setActiveWorkspace(_ id: CompanionId?) {
        activeWorkspace = id
        if let id = id {
            toggled.insert(.agent(id: id))
        }
        persist()
    }

    /// Reset to neutral / union view.
    public func clearAll() {
        toggled.removeAll()
        activeWorkspace = nil
        persist()
    }

    // MARK: - Persistence

    private var defaultsKey: String {
        "simulation.sidebarToggles.\(windowId)"
    }

    private var defaultsActiveKey: String {
        "simulation.activeWorkspace.\(windowId)"
    }

    private func persist() {
        let keys = toggled.map(\.persistenceKey).sorted()
        UserDefaults.standard.set(keys, forKey: defaultsKey)
        UserDefaults.standard.set(activeWorkspace?.rawValue, forKey: defaultsActiveKey)
    }

    private func load() {
        if let keys = UserDefaults.standard.stringArray(forKey: defaultsKey) {
            for key in keys {
                if let entity = SidebarEntity(persistenceKey: key) {
                    toggled.insert(entity)
                }
            }
        }
        if let raw = UserDefaults.standard.string(forKey: defaultsActiveKey),
           !raw.isEmpty {
            activeWorkspace = CompanionId(rawValue: raw)
        }
    }
}
