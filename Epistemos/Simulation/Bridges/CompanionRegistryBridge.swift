//
//  CompanionRegistryBridge.swift
//  Simulation Mode S5 — Swift wrapper for the canonical
//  CompanionRegistry exposed via UniFFI.
//
//  Per DOCTRINE I-7 Swift never mutates the registry directly —
//  every operation crosses this typed FFI boundary. Per
//  DOCTRINE I-8 this is the **control-plane** surface
//  (low-frequency: list / create / archive); per-frame visual
//  deltas cross via `crate::ffi::delta_ring` instead.
//

import Foundation

// MARK: - Strongly-typed Swift mirrors of the FFI string enums

/// 26-char Crockford-base32 ULID. Wraps `String` for type
/// safety so it can't be confused with `MessageId` etc.
public struct CompanionId: Hashable, Sendable, RawRepresentable {
    public let rawValue: String
    public nonisolated init(rawValue: String) { self.rawValue = rawValue }
}

extension CompanionId: CustomStringConvertible {
    public var description: String { rawValue }
}

/// Body-shape family per DOCTRINE §5.1.
public enum HeadShape: String, Sendable, CaseIterable {
    case block = "Block"
    case sage = "Sage"
    case orb = "Orb"
    case hermesSnake = "HermesSnake"

    public nonisolated init?(ffi: String) {
        self.init(rawValue: ffi)
    }
}

/// Activity state per DOCTRINE §3.2 + §3.5 transitions.
public enum ActivityState: String, Sendable, CaseIterable {
    case active = "Active"
    case recent = "Recent"
    case dormant = "Dormant"
    case parked = "Parked"
    case justAcquired = "JustAcquired"

    public nonisolated init?(ffi: String) {
        self.init(rawValue: ffi)
    }
}

/// Provider role per DOCTRINE §5.5 Category A.
public enum ProviderRole: String, Sendable {
    case orchestrator = "Orchestrator"
    case researcher = "Researcher"
    case worker = "Worker"
    case critic = "Critic"
    case codeWorker = "CodeWorker"
    case faculty = "Faculty"
    case helper = "Helper"
    case custom = "Custom"
    public nonisolated init?(ffi: String) { self.init(rawValue: ffi) }
}

/// Eye style per DOCTRINE §5.2.
public enum EyeStyle: String, Sendable {
    case round = "Round"
    case slit = "Slit"
    case visor = "Visor"
    case closed = "Closed"
    case negativeSpace = "NegativeSpace"
    public nonisolated init?(ffi: String) { self.init(rawValue: ffi) }
}

/// Arm style per DOCTRINE §5.2.
public enum ArmStyle: String, Sendable {
    case none = "None"
    case short = "Short"
    case long = "Long"
    public nonisolated init?(ffi: String) { self.init(rawValue: ffi) }
}

/// Prop / tool affinity per DOCTRINE §5.5 Category A.
public enum PropKind: String, Sendable {
    case wrench = "Wrench"
    case scroll = "Scroll"
    case magnifier = "Magnifier"
    case folder = "Folder"
    case baton = "Baton"
    case lantern = "Lantern"
    public nonisolated init?(ffi: String) { self.init(rawValue: ffi) }
}

// MARK: - CompanionFarmEntry — Swift-typed record

/// One companion as the Landing Farm view-model needs it.
/// All FFI string fields are decoded into typed Swift enums
/// at construction; if any field fails the whole entry is
/// rejected and surfaced as `nil` (the bridge logs and skips
/// — better than rendering with a partial-bad row).
public struct CompanionFarmEntry: Identifiable, Sendable, Hashable {
    public let id: CompanionId
    public let name: String
    public let headShape: HeadShape
    public let paletteRef: String
    public let eyes: EyeStyle
    public let arms: ArmStyle
    public let prop: PropKind?
    public let accessoryRef: String?
    public let role: ProviderRole
    public let baseModel: String
    public let activity: ActivityState
    public let farmPosition: CGPoint
    public let createdAt: String
    public let archivedAt: String?

    /// Construct from the raw FFI record. Returns `nil` if any
    /// required field has an unknown discriminator (forward-
    /// compat: a future Rust enum variant gracefully drops out
    /// of the Swift view-model rather than crashing).
    public nonisolated init?(ffi: CompanionFarmEntryFfi) {
        guard let head = HeadShape(ffi: ffi.headShape),
              let eyes = EyeStyle(ffi: ffi.eyes),
              let arms = ArmStyle(ffi: ffi.arms),
              let role = ProviderRole(ffi: ffi.role),
              let activity = ActivityState(ffi: ffi.activity)
        else {
            return nil
        }
        self.id = CompanionId(rawValue: ffi.id)
        self.name = ffi.name
        self.headShape = head
        self.paletteRef = ffi.paletteRef
        self.eyes = eyes
        self.arms = arms
        self.prop = ffi.propRef.flatMap(PropKind.init(ffi:))
        self.accessoryRef = ffi.accessoryRef
        self.role = role
        self.baseModel = ffi.baseModel
        self.activity = activity
        self.farmPosition = CGPoint(
            x: CGFloat(ffi.farmPositionX),
            y: CGFloat(ffi.farmPositionY)
        )
        self.createdAt = ffi.createdAt
        self.archivedAt = ffi.archivedAt
    }
}

// MARK: - CompanionRegistryBridge actor

/// Wraps the Rust-owned CompanionRegistry handle. All UniFFI
/// calls cross this boundary. Per DOCTRINE I-8 this is the
/// control-plane surface; per-frame visual deltas use the
/// SPSC ring instead.
public actor CompanionRegistryBridge {
    private let handle: UInt64
    public let vaultRoot: URL

    /// Open or create the registry at `<vaultRoot>/.epistemos/companions.db`.
    /// Returns `nil` on disk failure (the FFI surfaces it as a
    /// 0 handle).
    public init?(vaultRoot: URL) {
        let h = epistemosCompanionsOpen(vaultRoot: vaultRoot.path)
        guard h != 0 else { return nil }
        self.handle = h
        self.vaultRoot = vaultRoot
    }

    deinit {
        epistemosCompanionsDestroy(handle: handle)
    }

    /// All non-archived companions. The Landing Farm calls this
    /// on appear and on observed registry changes.
    public func listActive() -> [CompanionFarmEntry] {
        let raw = epistemosCompanionsListActive(handle: handle)
        return raw.compactMap(CompanionFarmEntry.init(ffi:))
    }

    /// Every companion including archived. For the Audit View.
    public func listAll() -> [CompanionFarmEntry] {
        let raw = epistemosCompanionsListAll(handle: handle)
        return raw.compactMap(CompanionFarmEntry.init(ffi:))
    }

    /// Create a default Local Helper preset companion (DOCTRINE
    /// §5.4). Triggers the `JustAcquired` rainbow-flash entrance
    /// per §3.2.
    public func createLocalHelper(name: String) throws -> CompanionFarmEntry {
        let entry = try epistemosCompanionsCreateLocalHelper(
            handle: handle, name: name
        )
        guard let typed = CompanionFarmEntry(ffi: entry) else {
            throw CompanionRegistryBridgeError.malformedEntry
        }
        return typed
    }

    /// Soft-archive (DOCTRINE §3.5). Vault on disk preserved.
    public func archive(_ id: CompanionId, reason: String? = nil) throws {
        try epistemosCompanionsArchive(
            handle: handle, id: id.rawValue, reason: reason
        )
    }
}

public enum CompanionRegistryBridgeError: Error {
    /// FFI returned a record with an unknown enum discriminator.
    /// Forward-compat: a future Rust variant we don't yet know
    /// about — the bridge skips it rather than crashing.
    case malformedEntry
}
