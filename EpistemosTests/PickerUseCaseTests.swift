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
        // Refactored (cloud-picker slice) to delegate to the ONE local+cloud
        // resolver instead of inlining profile_for in the bridge.
        #expect(bridge.contains("crate::model_profile::picker_use_case_for(&model_id)"))
        let profile = try loadMirroredSourceTextFile("agent_core/src/model_profile.rs")
        #expect(profile.contains("pub fn picker_use_case_for(model_id: &str) -> &'static str"))
        #expect(profile.contains("pub fn resolve_profile(model_id: &str) -> Option<ModelCapabilityProfile>"))
    }

    @Test("the picker row shows a per-model context-window badge from the FFI")
    func pickerWiresContextBadge() throws {
        let picker = try loadMirroredSourceTextFile(
            "Epistemos/Views/Chat/InlineRuntimePickerPanel.swift"
        )
        #expect(picker.contains("modelContextBadge(for: option.id)"))
        // Resolved from the Rust FFI, not a duplicated Swift table.
        #expect(picker.contains("modelContextWindow(modelId: modelID)"))
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")
        #expect(bridge.contains("pub fn model_context_window(model_id: String) -> u32"))
    }

    @Test("formatContextWindow compacts token counts into compact picker badges")
    func contextWindowBadgeFormatting() {
        #expect(InlineRuntimePickerPanel.formatContextWindow(0) == nil)
        // K uses truncation so a power-of-two window reads colloquially.
        #expect(InlineRuntimePickerPanel.formatContextWindow(32_768) == "32K")
        #expect(InlineRuntimePickerPanel.formatContextWindow(128_000) == "128K")
        #expect(InlineRuntimePickerPanel.formatContextWindow(200_000) == "200K")
        // M snaps to a whole million when within 0.1M (Gemini's 1_048_576), else 1 dp.
        #expect(InlineRuntimePickerPanel.formatContextWindow(1_000_000) == "1M")
        #expect(InlineRuntimePickerPanel.formatContextWindow(1_048_576) == "1M")
        #expect(InlineRuntimePickerPanel.formatContextWindow(1_500_000) == "1.5M")
    }
}
