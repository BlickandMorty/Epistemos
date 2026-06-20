import Testing
import Foundation
@testable import Epistemos

/// SS-AB (owner 2026-06-19: "on the model picker there should be a brief
/// description of its use case"): the picker renders a per-model use-case line
/// resolved from the SINGLE Rust ModelCapabilityProfile source via the agent_core
/// FFI (`model_picker_use_case`) — NOT a duplicated Swift copy table (one source
/// of truth).
@Suite("Picker use-case copy (SS-AB)")
struct PickerUseCaseTests {

    @Test("the picker row shows the per-model use-case line from the FFI, falling back to the tagline")
    func pickerWiresUseCaseLine() throws {
        let picker = try loadMirroredSourceTextFile(
            "Epistemos/Views/Chat/InlineRuntimePickerPanel.swift"
        )
        #expect(picker.contains("modelUseCaseLine(for: option.id) ?? tier.tagline"))
        // Resolved from the Rust FFI, not a duplicated Swift copy table.
        #expect(picker.contains("modelPickerUseCase(modelId: modelID)"))
        #expect(picker.contains("import agent_coreFFI"))
    }

    @Test("the FFI resolves the copy from the single ModelCapabilityProfile (Rust)")
    func ffiResolvesFromProfile() throws {
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")
        #expect(bridge.contains("pub fn model_picker_use_case(model_id: String) -> String"))
        #expect(bridge.contains("crate::model_profile::profile_for(&model_id)"))
        #expect(bridge.contains("profile.picker_use_case"))
    }
}
