import Testing
import Foundation

/// Owner 2026-06-18 (reopened picker fix): the model/runtime picker must be a
/// flat inline pixel-art panel that expands IN-FLOW in the composer, NOT a
/// floating .popover. These guard the structural contract:
///   - InlineRuntimePickerPanel exists, is flat/pixel-art, has NO .popover, and
///     drives selection through the same path as the old popover.
///   - the main-chat composer renders it in-flow + hides the redundant floating
///     model button (exactly one model picker).
///   - the hide flag threads cleanly and defaults OFF (every other surface
///     unchanged).
@Suite("Inline runtime picker panel (flat, in-flow)")
struct InlineRuntimePickerPanelTests {

    @Test("the panel is a flat pixel-art picker with NO popover")
    func panelIsFlatAndPopoverFree() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Chat/InlineRuntimePickerPanel.swift"
        )
        // Drives the SAME standalone option model as foundationPickerSection.
        #expect(src.contains("EpistemosRuntimePicker.options(for: tier, environment: environment)"))
        // Flat pixel-art chrome: a hard rectangular border + solid card fill,
        // and a monospaced (pixel) title font — NOT a rounded popover bubble.
        #expect(src.contains("Rectangle()") && src.contains("strokeBorder"))
        #expect(src.contains("design: .monospaced"))
        #expect(src.contains("theme.card"))
        // The owner's hard requirement: no floating popover anywhere in the panel.
        #expect(!src.contains(".popover("))
        // Selection mirrors LocalModelToolbarMenu.selectRuntimePick: set the
        // tier's operating mode + pin the model, blocked picks route to Settings.
        #expect(src.contains("inference.setPreferredChatModelSelection(.localMLX(option.id))"))
        #expect(src.contains("inference.setPreferredChatModelSelection(.appleIntelligence)"))
        #expect(src.contains("onOpenSettings()"))
    }

    @Test("tier→mode mapping matches the popover picker")
    func tierModeMappingMatchesPopover() throws {
        let panel = try loadMirroredSourceTextFile(
            "Epistemos/Views/Chat/InlineRuntimePickerPanel.swift"
        )
        // fast→.fast, think→.thinking, code→.pro — identical to
        // LocalModelToolbarMenu.runtimePickerOperatingMode.
        #expect(panel.contains("case .fast: return .fast"))
        #expect(panel.contains("case .think: return .thinking"))
        #expect(panel.contains("case .code: return .pro"))
    }

    @Test("the composer renders the panel in-flow and hides the floating model button")
    func composerWiresInlinePanel() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        // The panel is rendered inline (gated by the toggle state).
        #expect(src.contains("if showInlineRuntimePicker {"))
        #expect(src.contains("InlineRuntimePickerPanel("))
        // A trigger in the control strip toggles it.
        #expect(src.contains("inlineRuntimePickerTrigger"))
        #expect(src.contains("showInlineRuntimePicker.toggle()"))
        // The redundant split-toolbar model button is hidden → one picker.
        #expect(src.contains("hidesModelButton: true"))
    }

    @Test("hidesModelButton threads through and defaults OFF (other surfaces unchanged)")
    func hideFlagThreadsAndDefaultsOff() throws {
        let picker = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatBrainPickerMenu.swift")
        #expect(picker.contains("var hidesModelButton: Bool = false"))
        #expect(picker.contains("hidesModelButton: hidesModelButton"))

        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        #expect(root.contains("var hidesModelButton: Bool = false"))
        // The model button is conditionally compiled out when the host owns the
        // inline picker.
        #expect(root.contains("if !hidesModelButton {"))
    }

    @Test("single-button surfaces get a Settings footer for the advanced bits")
    func panelHasOptionalSettingsFooter() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Chat/InlineRuntimePickerPanel.swift"
        )
        // Opt-in footer (off for main chat's split toolbar, on for landing etc.).
        #expect(src.contains("var showsSettingsFooter: Bool = false"))
        #expect(src.contains("if showsSettingsFooter {"))
        // The footer routes cloud/routing/model-detail to Settings honestly.
        #expect(src.contains("Settings") && src.contains("onOpenSettings()"))
    }

    @Test("landing migrated off the popover to the inline panel")
    func landingUsesInlinePanel() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        // The landing brain tool is now a flat trigger, NOT the ChatBrainPickerMenu
        // popover, and renders the inline panel in-flow with the Settings footer.
        #expect(src.contains("InlineRuntimePickerPanel("))
        #expect(src.contains("showsSettingsFooter: true"))
        #expect(src.contains("showInlineRuntimePicker"))
        // landingSearchBrainTool must no longer mount the popover picker.
        guard let brainTool = src.range(of: "private var landingSearchBrainTool") else {
            Issue.record("expected landingSearchBrainTool to exist")
            return
        }
        let brainToolBody = String(src[brainTool.lowerBound...].prefix(400))
        #expect(!brainToolBody.contains("ChatBrainPickerMenu"),
                "landingSearchBrainTool must be a trigger, not the popover picker")
    }

    @Test("mini chat migrated off the popover to the inline panel")
    func miniChatUsesInlinePanel() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        // The composer renders the inline panel in-flow + a cpu trigger, and the
        // control strip no longer mounts LocalModelToolbarMenu for the picker.
        #expect(src.contains("InlineRuntimePickerPanel("))
        #expect(src.contains("showsSettingsFooter: true"))
        #expect(src.contains("inlineRuntimePickerTrigger"))
        // The old single-button LocalModelToolbarMenu picker is gone from the
        // composer strip (the trigger replaced it).
        #expect(!src.contains("LocalModelToolbarMenu("),
                "mini chat composer must use the inline panel, not the popover menu")
    }
}
