import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Epistemos

@Suite("ThemePair Dock Icon")
struct ThemePairTests {

    @Test("Magnolia resolves to the new ash-rose light and nocturne dark themes")
    func magnoliaPairMapping() {
        #expect(ThemePair.magnolia.lightTheme == .magnolia)
        #expect(ThemePair.magnolia.darkTheme == .nocturne)
        #expect(ThemePair.magnolia.resolved(isDark: false) == .magnolia)
        #expect(ThemePair.magnolia.resolved(isDark: true) == .nocturne)
        #expect(EpistemosTheme.magnolia.usesNativeWindowBlur)
        #expect(EpistemosTheme.nocturne.usesNativeWindowBlur)
        #expect(!EpistemosTheme.light.usesNativeWindowBlur)
    }

    @Test("Classic does not require a runtime dock icon override")
    func classicResourceMapping() {
        #expect(ThemePair.classic.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.classic.dockIconResourceName(isDark: true) == nil)
    }

    @Test("Magnolia, Warmth, and Ember do not require runtime dock icon overrides")
    func alternatePairsUseAdaptiveResources() {
        #expect(ThemePair.magnolia.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.magnolia.dockIconResourceName(isDark: true) == nil)
        #expect(ThemePair.warmth.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.warmth.dockIconResourceName(isDark: true) == nil)
        #expect(ThemePair.ember.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.ember.dockIconResourceName(isDark: true) == nil)
    }

    @MainActor
    @Test("UIState defaults to Platinum when no pair is stored")
    func uiStateDefaultsToPlatinum() {
        let defaults = UserDefaults.standard
        let key = "epistemos.theme.pair"
        let previous = defaults.string(forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.removeObject(forKey: key)

        let uiState = UIState()
        #expect(uiState.activePair == .platinum)
    }

    @Test("Magnolia uses a rose display accent for app titles and headings")
    func magnoliaUsesRoseDisplayAccent() {
        #expect(EpistemosTheme.magnolia.headingAccentHex == 0xB86F8D)
    }

    @Test("Platinum pair resolves to distinct light and dark variants")
    func platinumPairMapping() {
        #expect(ThemePair.platinum.lightTheme == .platinum)
        #expect(ThemePair.platinum.darkTheme == .platinumDark)
        #expect(ThemePair.platinum.resolved(isDark: false) == .platinum)
        #expect(ThemePair.platinum.resolved(isDark: true) == .platinumDark)
        #expect(!EpistemosTheme.platinum.isDark)
        #expect(EpistemosTheme.platinumDark.isDark)
        #expect(EpistemosTheme.platinum.foregroundHex == 0x000000)
        #expect(EpistemosTheme.platinumDark.foregroundHex == 0xFFFFFF)
        #expect(EpistemosTheme.platinum.markdownHeadingAccentHex == 0x111111)
        #expect(EpistemosTheme.platinumDark.markdownHeadingAccentHex == 0xF2F2F2)
        #expect(EpistemosTheme.platinum.preferredMarkdownLinkHex == 0x111111)
        #expect(EpistemosTheme.platinumDark.preferredMarkdownLinkHex == nil)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinum, level: 1) == EpistemosTheme.platinum.headingAccentHex)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinumDark, level: 1) == EpistemosTheme.platinumDark.headingAccentHex)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinum, level: 2) == EpistemosTheme.platinum.markdownHeadingAccentHex)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinumDark, level: 2) == EpistemosTheme.platinumDark.markdownHeadingAccentHex)
        #expect(EpistemosTheme.platinum.assistantBubbleForegroundHex == EpistemosTheme.platinum.mutedForegroundHex)
        #expect(EpistemosTheme.platinumDark.assistantBubbleForegroundHex == EpistemosTheme.platinumDark.foregroundHex)
        #expect(EpistemosTheme.platinum.assistantBubbleBackgroundHex == nil)
        #expect(EpistemosTheme.platinumDark.assistantBubbleBackgroundHex == nil)
        #expect(EpistemosTheme.platinum.userBubbleBackgroundHex == 0x111111)
        #expect(EpistemosTheme.platinum.userBubbleText == Color(hex: 0xF2F2F2).opacity(0.94))
        #expect(EpistemosTheme.platinumDark.userBubbleBackgroundHex == 0x2A2A38)
        #expect(EpistemosTheme.platinumDark.userBubbleText == Color(hex: 0xF2F2F2).opacity(0.94))
    }

    @Test("Platinum Violet pair preserves the accented blue-violet variant")
    func platinumVioletPairMapping() {
        #expect(ThemePair.platinumViolet.lightTheme == .platinumViolet)
        #expect(ThemePair.platinumViolet.darkTheme == .platinumVioletDark)
        #expect(ThemePair.platinumViolet.resolved(isDark: false) == .platinumViolet)
        #expect(ThemePair.platinumViolet.resolved(isDark: true) == .platinumVioletDark)
        #expect(EpistemosTheme.platinumViolet.markdownHeadingAccentHex == 0x00007B)
        #expect(EpistemosTheme.platinumVioletDark.markdownHeadingAccentHex == 0x7B68EE)
        #expect(EpistemosTheme.platinumViolet.preferredMarkdownLinkHex == 0x00007B)
        #expect(EpistemosTheme.platinumVioletDark.preferredMarkdownLinkHex == nil)
        #expect(EpistemosTheme.platinumViolet.accent == Color(hex: 0x000080))
        #expect(EpistemosTheme.platinumVioletDark.accent == Color(hex: 0x7B68EE))
    }

    @Test("System appearance state reads the global Apple interface style")
    func systemAppearanceStateUsesGlobalInterfaceStyle() {
        #expect(SystemAppearanceState.isDark(globalDomain: nil) == false)
        #expect(SystemAppearanceState.isDark(globalDomain: [:]) == false)
        #expect(SystemAppearanceState.isDark(globalDomain: ["AppleInterfaceStyle": "Dark"]))
        #expect(
            SystemAppearanceState.isDark(globalDomain: ["AppleInterfaceStyle": "Light"]) == false
        )
    }

    @Test("App heading roles use the shared display scale")
    func appHeadingRolesUseSharedDisplayScale() {
        #expect(AppDisplayTypography.displayFontName == "RetroGaming")
        #expect(AppHeadingRole.pageTitle.fontSize == 28)
        #expect(AppHeadingRole.pageTitle.animatesOnFirstAppearance)
        #expect(AppHeadingRole.h1.fontSize == 26)
        #expect(AppHeadingRole.h2.fontSize == 20)
        #expect(AppHeadingRole.h3.fontSize == 16)
        #expect(AppHeadingRole.section.fontSize == 12)
    }

    @Test("Markdown H1 sizing eases down for longer titles without collapsing into H2")
    func markdownH1AdaptiveSizing() {
        let shortSize = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "All Things Must Go",
            baseSize: AppHeadingRole.h1.fontSize,
            nextLevelSize: AppHeadingRole.h2.fontSize
        )
        let mediumSize = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "A Neuroscientific explanation of determinism in society",
            baseSize: AppHeadingRole.h1.fontSize,
            nextLevelSize: AppHeadingRole.h2.fontSize
        )
        let longSize = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "A Neuroscientific explanation of determinism in society across institutions, incentives, and collective mythmaking",
            baseSize: AppHeadingRole.h1.fontSize,
            nextLevelSize: AppHeadingRole.h2.fontSize
        )

        #expect(shortSize == AppHeadingRole.h1.fontSize)
        #expect(shortSize > mediumSize)
        #expect(mediumSize > longSize)
        #expect(shortSize - mediumSize >= 2)
        #expect(shortSize - longSize >= 3)
        #expect(longSize > AppHeadingRole.h2.fontSize)
    }

    @Test("Markdown heading display uppercases H1 through H3 only")
    func markdownHeadingDisplayUppercasesFirstThreeLevels() {
        #expect(MarkdownHeadingDisplay.displayText("All Things Must Go", level: 1) == "ALL THINGS MUST GO")
        #expect(MarkdownHeadingDisplay.displayText("Sub Heading", level: 2) == "SUB HEADING")
        #expect(MarkdownHeadingDisplay.displayText("Third Level", level: 3) == "THIRD LEVEL")
        #expect(MarkdownHeadingDisplay.displayText("Fourth Level", level: 4) == "Fourth Level")
    }

    @Test("Markdown heading glow tapers from H1 to H3")
    func markdownHeadingGlowTapersByLevel() {
        #expect(MarkdownHeadingDisplay.glowRadius(for: 1) == 14)
        #expect(MarkdownHeadingDisplay.glowRadius(for: 2) == 10)
        #expect(MarkdownHeadingDisplay.glowRadius(for: 3) == 7)
        #expect(MarkdownHeadingDisplay.glowRadius(for: 4) == 0)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumDark, level: 1) == 0.38)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumDark, level: 2) == 0.24)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumDark, level: 3) == 0.18)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumDark, level: 1) == 0.34)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumDark, level: 2) == 0.22)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumDark, level: 3) == 0.16)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinum, level: 1) != nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinum, level: 2) != nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinum, level: 3) != nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinum, level: 4) == nil)
    }

    @Test("Markdown preview heading glow stays softer than the editor heading glow")
    func markdownPreviewHeadingGlowStaysSoft() {
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 1) == 9)
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 2) == 6)
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 3) == 4)
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 4) == 0)
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 1) < MarkdownHeadingDisplay.glowRadius(for: 1))
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 2) < MarkdownHeadingDisplay.glowRadius(for: 2))
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 3) < MarkdownHeadingDisplay.glowRadius(for: 3))
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumDark, level: 1) == 0.2)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumDark, level: 2) == 0.12)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumDark, level: 3) == 0.09)
    }

    @Test("Regular display mode keeps ripple-capable surfaces but drops retro display typography")
    func regularDisplayModePolicy() {
        #expect(AppDisplayMode.opulent.usesDisplayFont)
        #expect(!AppDisplayMode.opulent.reducesASCIIAnimations)
        #expect(!AppDisplayMode.regular.usesDisplayFont)
        #expect(AppDisplayMode.regular.reducesASCIIAnimations)
    }

    @Test("Regular display mode uses the macOS UI font family")
    func regularDisplayModeUsesMacOSUIFont() throws {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: AppDisplayMode.defaultsKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: AppDisplayMode.defaultsKey)
            } else {
                defaults.removeObject(forKey: AppDisplayMode.defaultsKey)
            }
        }

        defaults.set(AppDisplayMode.regular.rawValue, forKey: AppDisplayMode.defaultsKey)

        let preferredBodyFont = NSFont.preferredFont(forTextStyle: .body)
        let preferredBoldDescriptor = preferredBodyFont.fontDescriptor
            .withSize(18)
            .addingAttributes([
                .traits: [NSFontDescriptor.TraitKey.weight: NSFont.Weight.bold.rawValue]
            ])
        let preferredBoldFont = try #require(NSFont(descriptor: preferredBoldDescriptor, size: 18))

        #expect(AppDisplayTypography.fontName == preferredBodyFont.fontName)
        #expect(AppDisplayTypography.nsFont(size: 15).fontName == preferredBodyFont.fontName)
        #expect(AppDisplayTypography.nsFont(size: 18, weight: .bold).fontName == preferredBoldFont.fontName)
    }

    @Test("Assistant chrome tokens keep the floating surface hierarchy intact")
    func assistantSurfaceMetricsStayCalm() {
        let palette = AssistantSurfaceMetrics.commandPalette
        let popout = AssistantSurfaceMetrics.popout

        #expect(palette.outerRadius == 30)
        #expect(palette.innerRadius == 24)
        #expect(palette.controlRadius == 18)
        #expect(palette.borderWidth == 0.72)
        #expect(palette.showsOuterStroke)
        #expect(palette.outerRadius > palette.innerRadius)
        #expect(palette.innerRadius > palette.controlRadius)
        #expect(popout.showsOuterStroke)
        #expect(popout.outerRadius == palette.outerRadius)
        #expect(popout.contentVerticalPadding > palette.contentVerticalPadding)
        #expect(popout.shadowRadius >= palette.shadowRadius)
    }

    @Test("Floating assistant surfaces follow the light and dark shell contrast rules")
    func floatingAssistantSurfacesUseThemeRelativeTints() {
        #expect(EpistemosTheme.light.floatingSurfaceTint == Color(hex: 0xF2F2F2))
        #expect(EpistemosTheme.tan.floatingSurfaceTint == Color(hex: 0xFBF5EB))
        #expect(EpistemosTheme.sunset.floatingSurfaceTint == Color(hex: 0x161018))
        #expect(EpistemosTheme.ember.floatingSurfaceTint == Color(hex: 0x16100C))
        #expect(EpistemosTheme.nocturne.floatingSurfaceTint == Color(hex: 0x141019))
        #expect(EpistemosTheme.oled.floatingSurfaceTint == Color(hex: 0x2A2A2F))
        #expect(EpistemosTheme.ember.floatingSurfaceTint != EpistemosTheme.ember.background)
        #expect(EpistemosTheme.nocturne.floatingSurfaceTint != EpistemosTheme.nocturne.background)
        #expect(EpistemosTheme.tan.floatingSurfaceTint != EpistemosTheme.tan.glassBg)
    }

    @Test("Main chat layout keeps the composer wide before it hits the desktop cap")
    func mainChatLayoutStaysWide() {
        #expect(ChatLayout.mainComposerMaxWidth == 980)
        #expect(ChatLayout.mainComposerHorizontalPadding == 12)
    }

    @Test("Main chat return key submits only when the composer is ready")
    func mainChatReturnSubmitsOnlyWhenReady() {
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [],
                trimmedText: "hello",
                isProcessing: false
            ) == .submit
        )
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [],
                trimmedText: "   ",
                isProcessing: false
            ) == .ignore
        )
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [],
                trimmedText: "hello",
                isProcessing: true
            ) == .ignore
        )
    }

    @Test("Main chat shift return keeps multiline editing and clamps growth")
    func mainChatShiftReturnKeepsMultilineEditing() {
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [.shift],
                trimmedText: "hello",
                isProcessing: false
            ) == .insertNewline
        )
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [.option],
                trimmedText: "hello",
                isProcessing: false
            ) == .systemDefault
        )
        #expect(ChatComposerInputMetrics.maxVisibleLines == 8)
        #expect(ChatComposerInputMetrics.clampedHeight(for: 0) == ChatComposerInputMetrics.minHeight)
        #expect(
            ChatComposerInputMetrics.clampedHeight(
                for: ChatComposerInputMetrics.maxHeight + 40
            ) == ChatComposerInputMetrics.maxHeight
        )
    }

    @Test("Assistant input chrome stays glass-first even without native window blur themes")
    func assistantInputChromePrefersNativeGlass() {
        let input = AssistantGlassInputMetrics.default

        #expect(input.prefersGlassEffect)
        #expect(input.tintOpacity > 0)
        #expect(input.activeBorderOpacity > input.idleBorderOpacity)
    }

    @Test("Markdown preview block chrome keeps the same dormant to hover surface hierarchy")
    func markdownPreviewBlockChromeMatchesHoverGlassSystem() {
        let metrics = MarkdownPreviewSurfaceMetrics.default

        #expect(metrics.cornerRadius == 0)
        #expect(metrics.borderWidth == 0.55)
        #expect(metrics.contentPadding == 12)
        #expect(metrics.verticalSpacing == 2)
        #expect(metrics.topEdgeWidth == 1)
        #expect(metrics.bottomEdgeWidth == 3)
        #expect(metrics.rightEdgeWidth == 1)
        #expect(MarkdownPreviewSurfaceStyle.borderOpacity(isDark: true) > MarkdownPreviewSurfaceStyle.borderOpacity(isDark: false))
    }

    @Test("Editor block chrome frame keeps the trailing edge flush without clipping content")
    func editorBlockChromeFrameUsesMinimalTrailingInset() {
        let origin = NSPoint(x: 8, y: 0)
        let frame = MarkdownTextStorage.blockChromeFrame(
            textContainerOrigin: origin,
            containerWidth: 600,
            boundsWidth: 700
        )

        let leadingInset = max(MarkdownTextStorage.bodyIndent - 8, 14)
        let availableWidth = min(600, max(0, 700 - (origin.x * 2)))
        let expectedWidth = availableWidth - leadingInset - MarkdownPreviewSurfaceMetrics.default.rightEdgeWidth

        #expect(frame.minX == origin.x + leadingInset)
        #expect(frame.width == expectedWidth)
    }

    @Test("Assistant composer metrics keep the main and compact chat bars aligned")
    func assistantComposerMetricsStayConsistent() {
        let main = AssistantComposerMetrics.mainChat
        let compact = AssistantComposerMetrics.compactChat

        #expect(main.cornerRadius == 20)
        #expect(main.sendButtonSize == 36)
        #expect(main.horizontalPadding == 14)
        #expect(main.verticalPadding == 9)
        #expect(main.shadowRadius == 14)
        #expect(main.shadowYOffset == 6)
        #expect(main.sendIconSize == 14)
        #expect(main.sendButtonSize >= compact.sendButtonSize)
        #expect(main.shadowRadius <= compact.shadowRadius)
        #expect(main.borderWidth <= 0.8)
        #expect(compact.cornerRadius >= main.cornerRadius)
        #expect(compact.horizontalPadding <= main.horizontalPadding)
    }

    @Test("Assistant source extraction keeps notes and links in a stable unique order")
    func assistantSourceExtractionDeduplicatesNotesAndLinks() {
        let sources = AssistantSourceReference.extract(
            from: """
            See [Paper](https://example.com/paper) and https://example.com/paper plus
            https://notes.example.org/entry for more context.
            """,
            noteTitles: ["Brown Essays", "Brown Essays", "Field Notes"]
        )

        #expect(sources.count == 4)
        #expect(sources[0].kind == .note)
        #expect(sources[0].title == "Brown Essays")
        #expect(sources[1].title == "Field Notes")
        #expect(sources[2].url?.absoluteString == "https://example.com/paper")
        #expect(sources[2].subtitle == "example.com")
        #expect(sources[3].subtitle == "notes.example.org")
    }

    @MainActor
    @Test("UIState restores saved display mode from defaults")
    func uiStateRestoresDisplayMode() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: AppDisplayMode.defaultsKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: AppDisplayMode.defaultsKey)
            } else {
                defaults.removeObject(forKey: AppDisplayMode.defaultsKey)
            }
        }

        defaults.set(AppDisplayMode.regular.rawValue, forKey: AppDisplayMode.defaultsKey)

        let uiState = UIState()
        #expect(uiState.displayMode == .regular)
    }

    @Test("Icon composer package carries dark and tinted variants")
    func iconComposerSupportsDarkAndTinted() throws {
        let json = try loadIconComposerJSON()
        #expect(json.contains("\"appearance\" : \"dark\""))
        #expect(json.contains("\"appearance\" : \"tinted\""))
        #expect(json.contains("Gemini Generated Image 5 (4).png"))
    }

    @Test("Icon composer package keeps the authored six asset sources")
    func iconComposerKeepsAuthoredAssetSources() throws {
        let assetNames = try FileManager.default.contentsOfDirectory(
            atPath: repoRootURL().appendingPathComponent("Epistemos/AppIcon.icon/Assets").path
        )
        #expect(assetNames.count == 6)
        #expect(assetNames.contains("Gemini Generated Image 5 (4).png"))
    }

    @Test("Bundle plist points at the icon composer asset")
    func bundlePlistUsesIconComposerFile() throws {
        let plist = try loadBundlePlist()
        #expect(plist["CFBundleIdentifier"] as? String == "com.epistemos.app")
        #expect(plist["CFBundleIconName"] as? String == "AppIcon")
        #expect(plist["CFBundleIconFile"] == nil)
    }

    @Test("Project uses AppIcon.icon as the primary app icon source")
    func projectUsesIconComposerFile() throws {
        let pbxproj = try loadProjectFile()
        #expect(pbxproj.contains("AppIcon.icon */ = {isa = PBXFileReference; lastKnownFileType = folder.iconcomposer.icon;"))
        #expect(pbxproj.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;"))
    }

    @Test("Project retains Rust bridge header wiring")
    func projectRetainsRustBridgeWiring() throws {
        let pbxproj = try loadProjectFile()
        #expect(pbxproj.contains("SWIFT_OBJC_BRIDGING_HEADER = \"Epistemos-Bridging-Header.h\";"))
        #expect(pbxproj.contains("\"\\\"$(SRCROOT)/graph-engine-bridge\\\"\","))
        #expect(pbxproj.contains("\"\\\"$(SRCROOT)/build-rust\\\"\","))
    }

    private func loadIconComposerJSON() throws -> String {
        let iconURL = repoRootURL().appendingPathComponent("Epistemos/AppIcon.icon/icon.json")
        return try String(contentsOf: iconURL)
    }

    private func loadBundlePlist() throws -> [String: Any] {
        let plistURL = repoRootURL().appendingPathComponent("Epistemos-Info.plist")
        let data = try Data(contentsOf: plistURL)
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    private func loadProjectFile() throws -> String {
        try String(contentsOf: repoRootURL().appendingPathComponent("Epistemos.xcodeproj/project.pbxproj"))
    }

    private func repoRootURL() -> URL {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        return testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
    }
}

@Suite("Native Control System")
struct NativeControlSystemTests {
    @Test("toolbar and content variants keep a stable macOS control density")
    func controlDensityMetrics() {
        #expect(NativeControlSystem.toolbar.height == 28)
        #expect(NativeControlSystem.toolbar.cornerRadius == 10)
        #expect(NativeControlSystem.toolbar.iconSize == 13)
        #expect(NativeControlSystem.toolbar.fontSize == 13)
        #expect(NativeControlSystem.toolbar.minHitWidth >= 28)
        #expect(NativeControlSystem.toolbar.maxLabelWidth >= 84)

        #expect(NativeControlSystem.content.height == 32)
        #expect(NativeControlSystem.content.cornerRadius == 12)
        #expect(NativeControlSystem.content.iconSize == 14)
        #expect(NativeControlSystem.content.minHitWidth >= 32)
    }

    @Test("landing search composer keeps the text row above the control row")
    func landingSearchComposerLayout() {
        #expect(LandingSearchLayout.maxWidth == 640)
        #expect(LandingSearchLayout.topRowSpacing == 12)
        #expect(LandingSearchLayout.controlRowSpacing == 8)
        #expect(LandingSearchLayout.controlRowTopPadding == 10)
    }

    @Test("main chat composer keeps a taller stacked input layout")
    func mainChatComposerLayout() {
        #expect(MainChatComposerLayout.horizontalPadding == 14)
        #expect(MainChatComposerLayout.topPadding == 12)
        #expect(MainChatComposerLayout.bottomPadding == 10)
        #expect(MainChatComposerLayout.controlRowSpacing == 6)
        #expect(MainChatComposerLayout.controlRowTopPadding == 8)
        #expect(ChatComposerInputMetrics.maxVisibleLines == 8)
        #expect(ChatComposerInputMetrics.fontSize == 15)
        #expect(ChatComposerInputMetrics.verticalInset == 5)
        #expect(ChatComposerInputMetrics.placeholderTopPadding == 6)
    }

    @Test("note and home toolbars step down before they clip")
    func toolbarFallbackMetrics() {
        #expect(NoteToolbarMetrics.chatFieldWidth == 180)
        #expect(NoteToolbarMetrics.compactChatFieldWidth < NoteToolbarMetrics.chatFieldWidth)
        #expect(NoteToolbarMetrics.buttonSide >= NativeControlSystem.toolbar.minHitWidth)
        #expect(HomeToolbarMetrics.modelLabelMaxWidth == 260)
    }

    @Test("control animation timings stay restrained and deterministic")
    func controlAnimationTimings() {
        #expect(NativeControlSystem.animation.hoverDuration == 0.12)
        #expect(NativeControlSystem.animation.pressDuration == 0.08)
        #expect(NativeControlSystem.animation.expansionDuration == 0.18)
        #expect(NativeControlSystem.animation.selectionDuration == 0.18)
        #expect(NativeControlSystem.animation.popoverDuration == 0.16)
    }

    @Test("toolbar and content popovers stay compact")
    func popoverWidthRanges() {
        #expect(NativeControlSystem.toolbarPopoverWidthRange == 220...360)
        #expect(NativeControlSystem.contentPopoverWidthRange == 240...340)
    }

    @Test("ASCII control badges keep deterministic widths across all phases")
    func asciiControlBadgeWidthsAreStable() {
        let badge = ASCIIControlAnimationSet.toolbarStatus

        for phase in ASCIIControlPhase.allCases {
            let frames = badge.frames(for: phase)
            #expect(!frames.isEmpty)
            #expect(frames.allSatisfy { $0.count == badge.width })
        }
    }

    @Test("ASCII control badge uses distinct phase language")
    func asciiControlBadgeUsesDistinctPhaseLanguage() {
        let badge = ASCIIControlAnimationSet.toolbarStatus

        #expect(badge.frames(for: .inactive).first == "[     ]")
        #expect(badge.frames(for: .arming).contains("[ ..> ]"))
        #expect(badge.frames(for: .active).contains("[ ON  ]"))
        #expect(badge.frames(for: .cooling).contains("[ <.. ]"))
    }

    @Test("compact toolbar badge stays smaller than the default toolbar badge")
    func compactToolbarBadgeStaysSmall() {
        #expect(ASCIIControlAnimationSet.compactToolbarStatus.width < ASCIIControlAnimationSet.toolbarStatus.width)
        #expect(ASCIIControlAnimationSet.compactToolbarStatus.frames(for: .active).contains("[ON ]"))
    }

    @Test("toolbar chrome policy keeps icon-first controls bare until press or selection")
    func toolbarChromePolicySemantics() {
        #expect(
            NativeControlChromePolicy.bareUntilPressed.showsSurface(
                isHovered: false,
                isPressed: false,
                isActive: false
            ) == false
        )
        #expect(
            NativeControlChromePolicy.bareUntilPressed.showsSurface(
                isHovered: true,
                isPressed: false,
                isActive: false
            ) == false
        )
        #expect(
            NativeControlChromePolicy.bareUntilPressed.showsSurface(
                isHovered: true,
                isPressed: true,
                isActive: false
            )
        )
        #expect(
            NativeControlChromePolicy.bareUntilPressed.showsSurface(
                isHovered: false,
                isPressed: false,
                isActive: true
            )
        )
        #expect(
            NativeControlChromePolicy.alwaysSurface.showsSurface(
                isHovered: false,
                isPressed: false,
                isActive: false
            )
        )
    }

    @Test("toolbar morph styles reserve enough overflow for protrusions")
    func toolbarMorphStyleOverflow() {
        #expect(ToolbarMorphSurfaceStyle.graphBar.overflowPadding >= ToolbarMorphSurfaceStyle.graphBar.maxProtrusionDepth)
        #expect(ToolbarMorphSurfaceStyle.notePreviewStrip.maxProtrusionDepth < ToolbarMorphSurfaceStyle.graphBar.maxProtrusionDepth)
        #expect(ToolbarMorphSurfaceStyle.composerControls.baseCornerRadius == 0)
    }

    @MainActor
    @Test("reduced motion disables continuous morph timeline work")
    func toolbarMorphReducedMotionFallback() {
        let coordinator = ToolbarMorphCoordinator()

        #expect(coordinator.animationMode(reduceMotion: true, windowOccluded: false) == .static)
        #expect(coordinator.animationMode(reduceMotion: false, windowOccluded: true) == .static)

        coordinator.setHovered("graph.semantic", isHovered: true)
        #expect(coordinator.animationMode(reduceMotion: false, windowOccluded: false) == .displayLinked)
    }

    @MainActor
    @Test("toolbar morph progression integrates toward targets instead of snapping")
    func toolbarMorphProgressionUsesContinuousDynamics() {
        let coordinator = ToolbarMorphCoordinator()
        let start = Date(timeIntervalSinceReferenceDate: 10)

        coordinator.setActive("graph.semantic", isActive: true)
        coordinator.setReveal("graph.semantic", progress: 1)

        #expect(coordinator.expansionProgress == 0)
        #expect(coordinator.protrusionDepth == 0)

        coordinator.advanceAnimationFrame(
            to: start,
            reduceMotion: false,
            windowOccluded: false
        )

        #expect(coordinator.expansionProgress > 0)
        #expect(coordinator.expansionProgress < 1)
        #expect(coordinator.protrusionDepth > 0)
        #expect(coordinator.protrusionDepth < 1)

        for step in 1...48 {
            coordinator.advanceAnimationFrame(
                to: start.addingTimeInterval(Double(step) / 120.0),
                reduceMotion: false,
                windowOccluded: false
            )
        }

        #expect(abs(coordinator.expansionProgress - 1) < 0.02)
        #expect(abs(coordinator.protrusionDepth - 1) < 0.02)
    }

    @MainActor
    @Test("toolbar morph keeps animating until collapse fully settles")
    func toolbarMorphCollapseStaysDisplayLinkedUntilSettled() {
        let coordinator = ToolbarMorphCoordinator()
        let start = Date(timeIntervalSinceReferenceDate: 20)

        coordinator.setActive("graph.semantic", isActive: true)
        coordinator.setReveal("graph.semantic", progress: 1)
        coordinator.advanceAnimationFrame(
            to: start,
            reduceMotion: false,
            windowOccluded: false
        )

        coordinator.setActive("graph.semantic", isActive: false)
        coordinator.setReveal("graph.semantic", progress: 0)

        #expect(coordinator.animationMode(reduceMotion: false, windowOccluded: false) == .displayLinked)

        for step in 1...90 {
            coordinator.advanceAnimationFrame(
                to: start.addingTimeInterval(Double(step) / 90.0),
                reduceMotion: false,
                windowOccluded: false
            )
        }

        #expect(abs(coordinator.expansionProgress) < 0.01)
        #expect(abs(coordinator.protrusionDepth) < 0.01)
        #expect(coordinator.animationMode(reduceMotion: false, windowOccluded: false) == .static)
    }

    @MainActor
    @Test("reduced motion snaps toolbar morph to its target state")
    func toolbarMorphReduceMotionSnapsToTarget() {
        let coordinator = ToolbarMorphCoordinator()

        coordinator.setActive("graph.semantic", isActive: true)
        coordinator.setReveal("graph.semantic", progress: 1)
        coordinator.advanceAnimationFrame(
            to: Date(timeIntervalSinceReferenceDate: 30),
            reduceMotion: true,
            windowOccluded: false
        )

        #expect(coordinator.expansionProgress == 1)
        #expect(coordinator.protrusionDepth == 1)
        #expect(coordinator.labelSpread == 1)
    }

    @Test("toolbar morph identifiers stay stable for anchored controls")
    func toolbarMorphIdentifiersStayStable() {
        #expect(GraphToolbarMorphID.semantic.rawValue == "graph.semantic")
        #expect(GraphToolbarMorphID.forceSettings.rawValue == "graph.forceSettings")
        #expect(MainChatToolbarMorphID.incognito.rawValue == "chat.incognito")
        #expect(LandingToolbarMorphID.history.rawValue == "landing.history")
        #expect(NoteToolbarMorphID.preview.rawValue == "note.preview")
    }

    @Test("chat sidebar filter mode is mutually exclusive and semantically explicit")
    func chatSidebarFilterModeSemantics() {
        #expect(ChatSidebarFilterMode.allCases == [.all, .research, .notes])
        #expect(ChatSidebarFilterMode.all.matches(hasResearch: false, hasLinkedNote: false))
        #expect(ChatSidebarFilterMode.research.matches(hasResearch: true, hasLinkedNote: false))
        #expect(!ChatSidebarFilterMode.research.matches(hasResearch: false, hasLinkedNote: true))
        #expect(ChatSidebarFilterMode.notes.matches(hasResearch: false, hasLinkedNote: true))
        #expect(!ChatSidebarFilterMode.notes.matches(hasResearch: true, hasLinkedNote: false))
    }

    @Test("chat query mode bridges the persisted research toggle")
    func chatQueryModeBridge() {
        #expect(ChatQueryMode.direct.isResearch == false)
        #expect(ChatQueryMode.research.isResearch)
        #expect(ChatQueryMode(isResearch: false) == .direct)
        #expect(ChatQueryMode(isResearch: true) == .research)
    }
}
