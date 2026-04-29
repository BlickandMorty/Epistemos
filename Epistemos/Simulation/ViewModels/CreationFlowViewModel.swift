//
//  CreationFlowViewModel.swift
//  Simulation Mode S8 — observable state for the §6.1 8-step
//  creation wizard.
//
//  Owns the in-flight `CompanionSpecFFI` draft, the navigation
//  stack of `CreationStepRoute`s, and the pre-commit validation
//  state. Submit calls `epistemos_companions_create_from_spec`
//  via `CompanionRegistryBridge`. Cancel discards transient
//  state — no rollback needed because no transaction was started
//  (per DOCTRINE §6.5 "User cancels mid-flow" recovery row).
//

import Foundation
import Observation

@MainActor
@Observable
public final class CreationFlowViewModel {
    /// Navigation stack — `presetPick` is the root and is NOT
    /// pushed; subsequent routes get pushed onto the path.
    public var route: [CreationStepRoute] = []

    /// Currently selected preset. Picking re-fills downstream
    /// step defaults; users can override any axis.
    public var selectedPreset: CompanionPresetId = .claudeCodeWorker

    // MARK: - Live spec axes (mutable per step)

    public var name: String = ""
    public var headShape: String = "Block"
    public var paletteRef: String = "claude_warm_v1"
    public var customPaletteHex: String = ""
    public var eyes: String = "Round"
    public var arms: String = "None"
    public var prop: String? = "Wrench"
    public var role: String = "CodeWorker"
    public var baseModel: String = "claude-sonnet-4-6"
    public var systemPromptPreset: String = "careful_reviewer_v1"
    /// Path component(s) under the registry's vault_root. Empty
    /// means "use Companions/<name>/" — the workspace step
    /// computes the default in the previewed text.
    public var vaultSubpath: String = ""

    // MARK: - Result + error surfacing

    public private(set) var lastError: String?
    public private(set) var lastCreatedId: String?

    /// `true` while a `submit()` call is in flight. The Review
    /// step disables its "Create" button while submitting so the
    /// user can't double-fire the §6.3 transaction.
    public private(set) var isSubmitting: Bool = false

    private let bridge: CompanionRegistryBridge

    public init(bridge: CompanionRegistryBridge, initialPreset: CompanionPresetId = .claudeCodeWorker) {
        self.bridge = bridge
        applyPreset(initialPreset)
    }

    // MARK: - Preset application

    public func applyPreset(_ id: CompanionPresetId) {
        selectedPreset = id
        let p = PresetCatalog.preset(id)
        headShape = p.headShape
        paletteRef = p.paletteRef
        customPaletteHex = ""
        eyes = p.eyes
        arms = p.arms
        prop = p.prop
        role = p.role
        baseModel = p.baseModel
        systemPromptPreset = p.systemPromptPreset
    }

    // MARK: - Navigation

    /// Advance to the next canonical step.
    public func advance() {
        let current = route.last ?? .presetPick
        guard let next = current.next else { return }
        // `presetPick` is the root and is never pushed onto
        // the path — `route == []` represents being on it.
        if next == .presetPick { return }
        route.append(next)
    }

    public func pop() {
        if !route.isEmpty {
            route.removeLast()
        }
    }

    public func goTo(_ step: CreationStepRoute) {
        if step == .presetPick {
            route.removeAll()
            return
        }
        // Trim or extend the path so the last entry == step.
        if let idx = route.firstIndex(of: step) {
            route = Array(route.prefix(idx + 1))
        } else {
            route.append(step)
        }
    }

    // MARK: - Per-step validation (§6.2)

    /// Whether the current step's input is valid; the wizard
    /// gates the "Next" button on this. Checks mirror the
    /// Rust-side validation so the user catches errors before
    /// the FFI round-trip.
    public func isStepValid(_ step: CreationStepRoute) -> Bool {
        switch step {
        case .presetPick:
            return true
        case .headShape:
            return ["Block", "Sage", "Orb"].contains(headShape)
        case .palette:
            if paletteRef.isEmpty {
                // Custom palette path — must have a valid hex.
                return Self.isValidHex(customPaletteHex)
            }
            return true
        case .eyes:
            return ["Round", "Slit", "Visor", "Closed", "NegativeSpace"]
                .contains(eyes)
        case .arms:
            return ["None", "Short", "Long"].contains(arms)
        case .prop:
            return prop == nil
                || ["Wrench", "Scroll", "Magnifier", "Folder", "Baton", "Lantern"]
                    .contains(prop!)
        case .workspace:
            // Empty subpath means "default Companions/<name>" —
            // valid as long as `name` will be valid by the time
            // `submit()` runs.
            return !vaultSubpath.contains("..")
        case .name:
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return false }
            if trimmed.count > 64 { return false }
            return !trimmed.contains("/")
                && !trimmed.contains("\\")
                && !trimmed.contains("\0")
        case .review:
            return CreationStepRoute.sequence
                .filter { $0 != .review && $0 != .presetPick }
                .allSatisfy(isStepValid)
        }
    }

    /// Hex `#RRGGBB` parser used by the palette step pre-flight.
    public static func isValidHex(_ s: String) -> Bool {
        guard s.count == 7, s.first == "#" else { return false }
        let hex = s.dropFirst()
        return hex.allSatisfy { $0.isHexDigit }
    }

    // MARK: - Submit (§6.3 transaction)

    /// Build the FFI spec from the live axes + fire the
    /// canonical 7-step transaction. Sets `lastCreatedId` on
    /// success and `lastError` on failure. The wizard's
    /// `dismiss` action consumes the success.
    public func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        lastError = nil

        let chosenPalette = paletteRef.isEmpty ? customPaletteHex : paletteRef
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subpath = vaultSubpath.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Companions/\(trimmedName)"
            : vaultSubpath
        let spec = CompanionSpecFfi(
            name: trimmedName,
            headShape: headShape,
            paletteRef: chosenPalette,
            eyes: eyes,
            arms: arms,
            prop: prop,
            accessoryRef: nil,
            role: role,
            baseModel: baseModel,
            systemPromptPreset: systemPromptPreset,
            vaultSubpath: subpath,
            farmPositionX: 0,
            farmPositionY: 0
        )
        do {
            let entry = try await bridge.createFromSpec(spec)
            lastCreatedId = entry.id.rawValue
        } catch {
            lastError = "\(error)"
        }
    }

    // MARK: - Reset

    /// Reset the wizard back to the picker step with the given
    /// preset's defaults. Used when the sheet is re-presented
    /// after a successful creation.
    public func reset(to preset: CompanionPresetId = .claudeCodeWorker) {
        route.removeAll()
        name = ""
        vaultSubpath = ""
        customPaletteHex = ""
        lastError = nil
        lastCreatedId = nil
        applyPreset(preset)
    }
}
