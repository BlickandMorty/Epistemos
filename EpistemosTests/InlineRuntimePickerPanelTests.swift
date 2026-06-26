import Testing
import Foundation

/// Owner 2026-06-18 (reopened picker fix): the model/runtime picker must be a
/// flat inline pixel-art panel that expands IN-FLOW in the composer, NOT a
/// floating .popover. These guard the structural contract:
///   - InlineRuntimePickerPanel exists, is flat/pixel-art, has NO .popover, and
///     drives selection through the same path as the old popover.
///   - single-button non-chat surfaces render it in-flow with the full mode and
///     settings affordances.
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
        // The landing brain tool is now a flat trigger, not the deleted chat
        // picker popover, and renders the inline panel in-flow with the Settings
        // footer.
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

    @Test("the panel renders the Fast/Think/Code tier structure")
    func panelRendersFastThinkCodeTiers() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Chat/InlineRuntimePickerPanel.swift"
        )
        // Owner cross-reference: the Fast/Think/Code structure must render — a
        // section per tier with that tier's picks.
        #expect(src.contains("ForEach(EpistemosModelTier.allCases"))
        #expect(src.contains("tier.shortName.uppercased()"))
        #expect(src.contains("EpistemosRuntimePicker.options(for: tier, environment: environment)"))
        // Selecting a tier pick sets that tier's operating mode (Fast/Think/Code
        // actually switch behavior, not just label).
        #expect(src.contains("case .fast: return .fast"))
        #expect(src.contains("case .think: return .thinking"))
        #expect(src.contains("case .code: return .pro"))
    }

    @Test("the panel exposes the EFFORT control (owner-flagged gap, now present)")
    func panelExposesEffortControl() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Chat/InlineRuntimePickerPanel.swift"
        )
        // The reasoning-effort picker the old picker exposed (Low/Med/High/Heavy).
        #expect(src.contains("Text(\"EFFORT\")"))
        #expect(src.contains("inference.availableReasoningTiers(for: operatingMode.wrappedValue)"))
        #expect(src.contains("inference.setChatReasoningTier(tier, for: mode)"))
        #expect(src.contains("private func effortRow("))
        // Honest gating: only when the mode actually has effort tiers (Fast has
        // none — availableReasoningTiers(.fast) == []), so no empty section.
        #expect(src.contains("if !tiers.isEmpty"))
    }

    @Test("the panel exposes the Chat/Act mode toggle with honest Act gating")
    func panelExposesChatActToggle() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Chat/InlineRuntimePickerPanel.swift"
        )
        // The old depthToggle (Chat/Act) — restores Act reachability on the
        // single-button surfaces (tier picks only reach Fast/Think/Code).
        #expect(src.contains("Text(\"MODE\")"))
        #expect(src.contains("private func coworkRow("))
        #expect(src.contains("CoworkChatMode.actAvailable(in: inference.availableOperatingModes)"))
        // Honest: Act disabled + the real reason when no agent route exists.
        #expect(src.contains("CoworkChatMode.actUnavailableReason"))
        #expect(src.contains("guard available else"))
    }

    @Test("graph node-chat sidebar migrated to the inline panel")
    func graphSidebarUsesInlinePanel() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        #expect(src.contains("InlineRuntimePickerPanel("))
        #expect(src.contains("showsSettingsFooter: true"))
        #expect(src.contains("graphInlineRuntimePickerTrigger"))
        #expect(!src.contains("LocalModelToolbarMenu("),
                "graph sidebar must use the inline panel, not the popover menu")
    }

    @Test("note ask-bar migrated to the inline panel")
    func noteAskBarUsesInlinePanel() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        #expect(src.contains("InlineRuntimePickerPanel("))
        #expect(src.contains("showsSettingsFooter: true"))
        #expect(src.contains("noteInlineRuntimePickerTrigger"))
        #expect(!src.contains("LocalModelToolbarMenu("),
                "note ask bar must use the inline panel, not the popover menu")
    }

    /// Owner 2026-06-18 (non-reductive picker on ALL 5 surfaces): every
    /// single-button surface must mount the SAME full panel — a real
    /// `operatingMode` binding (so the MODE Chat/Act + EFFORT sections render)
    /// AND `showsSettingsFooter: true` (so routing/cloud/native stay reachable
    /// via the Settings footer) — never a reduced subset of main chat. Locks
    /// parity so a future surface edit can't silently drop a control.
    @Test("all single-button surfaces mount the full non-reductive panel")
    func allSingleButtonSurfacesAreNonReductive() throws {
        for path in [
            "Epistemos/Views/Landing/LandingView.swift",
            "Epistemos/Views/Graph/HologramSearchSidebar.swift",
            "Epistemos/Views/Notes/NoteDetailWorkspaceView.swift",
        ] {
            let src = try loadMirroredSourceTextFile(path)
            #expect(src.contains("InlineRuntimePickerPanel("), "\(path) mounts the inline panel")
            #expect(src.contains("showsSettingsFooter: true"), "\(path) keeps the Settings footer")
            #expect(src.contains("operatingMode:"), "\(path) passes a mode binding (MODE + EFFORT render)")
        }
    }

    /// Owner 2026-06-18 (still-open report: the panel "seems like there were only two
    /// available because there's no scroll bar"). The panel must (a) force a VISIBLE
    /// scroll indicator (macOS auto-hides the overlay scroller) and (b) pin an
    /// always-visible "N models" count above the scroll area so the full Fast/Think/
    /// Code lineup is obviously reachable, not just the rows above the fold.
    @Test("the panel forces a visible scrollbar + pins an always-visible model count")
    func panelShowsScrollIndicatorAndModelCount() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Chat/InlineRuntimePickerPanel.swift"
        )
        // (a) the scrollbar is forced visible, not macOS's auto-hidden overlay.
        #expect(src.contains(".scrollIndicators(.visible)"))
        // (b) an always-visible count header pinned above the scroll area.
        #expect(src.contains("pickerCountHeader"))
        #expect(src.contains(".safeAreaInset(edge: .top"))
        // The count is the REAL lineup size (sum of every tier's picks), surfaced as
        // "N models" — never a guess.
        #expect(src.contains("EpistemosModelTier.allCases.reduce(0)"))
        #expect(src.contains("\\(totalModelCount) models"))
        // The scroll cue only appears when the picks actually overflow the viewport.
        #expect(src.contains("if pickerOverflows"))
    }

    @Test("the panel renders Foundation Models runtime readback for Apple Intelligence")
    func panelRendersFoundationModelsRuntimeReadback() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Chat/InlineRuntimePickerPanel.swift"
        )

        #expect(src.contains("appleIntelligenceUnavailableReason: inference.appleIntelligenceUnavailableReason"))
        #expect(src.contains("option.requiresNewSessionOnSelection"))
        #expect(src.contains("option.settingsActionRecommended"))
        #expect(src.contains("option.availabilitySummary"))
        #expect(src.contains("Text(\"NEW CHAT\")"))
        #expect(src.contains("gearshape"))
    }
}
