import Testing
import Foundation

@testable import Epistemos

// SS-TC (owner 2026-06-20): granular custom-theme color slots. The owner could change body text
// but the user-bubble text rode along with it (white-on-pale = unreadable). The fix adds
// independent slots — userBubbleText / secondaryText / link / assistantBubbleBg / border — each
// ADDITIVE + DEFAULTED: unset inherits the prior derived value (byte-identical, no regression),
// set overrides it. These tests pin both halves of that contract.
@Suite("SS-TC granular custom-theme color slots (additive + defaulted)")
struct SSTCThemeGranularColorsTests {

    private func freshDefaults(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    // The owner's exact bug: user-bubble text was conflated with body text. Now independent —
    // unset inherits text (no regression), set makes it its own color.
    @Test("userBubbleText inherits .text when unset, uses its own token when set")
    func userBubbleTextSlot() {
        let name = "ss-tc.userBubbleText"
        let d = freshDefaults(name)
        defer { d.removePersistentDomain(forName: name) }

        // Unset → inherits the body-text fallback (byte-identical to the old behavior).
        #expect(AppCustomTheme.inheritedHex(
            for: .userBubbleText, fallback: 0x111111, isDark: true, defaults: d) == 0x111111)
        // Set → the bubble text is now independent of body text.
        AppCustomTheme.setHex(0x00FF00, for: .userBubbleText, isDark: true, defaults: d)
        #expect(AppCustomTheme.inheritedHex(
            for: .userBubbleText, fallback: 0x111111, isDark: true, defaults: d) == 0x00FF00)
    }

    @Test("assistantBubbleBg is nil (no fill) when unset, a hex when set")
    func assistantBubbleBgSlot() {
        let name = "ss-tc.assistantBubbleBg"
        let d = freshDefaults(name)
        defer { d.removePersistentDomain(forName: name) }

        #expect(AppCustomTheme.assistantBubbleBackgroundHex(isDark: false, defaults: d) == nil)
        AppCustomTheme.setHex(0x123456, for: .assistantBubbleBg, isDark: false, defaults: d)
        #expect(AppCustomTheme.assistantBubbleBackgroundHex(isDark: false, defaults: d) == 0x123456)
    }

    // No-regression invariant: EVERY new inheriting slot returns its fallback (the prior derived
    // value) when unset — across both appearances.
    @Test("all new inheriting slots are byte-identical to the prior derivation when unset")
    func unsetSlotsInherit() {
        let name = "ss-tc.inherit"
        let d = freshDefaults(name)
        defer { d.removePersistentDomain(forName: name) }
        let cases: [(AppCustomThemeColorSlot, UInt32)] = [
            (.userBubbleText, 0xAAAAAA),
            (.secondaryText, 0xBBBBBB),
            (.link, 0xCCCCCC),
            (.border, 0xDDDDDD),
        ]
        for (slot, fallback) in cases {
            #expect(AppCustomTheme.inheritedHex(for: slot, fallback: fallback, isDark: true, defaults: d) == fallback)
            #expect(AppCustomTheme.inheritedHex(for: slot, fallback: fallback, isDark: false, defaults: d) == fallback)
        }
    }

    // The 5 new slots are user-editable — they appear in the theme editor's allCases picker grid.
    @Test("the 5 new slots are in allCases (auto-rendered pickers)")
    func newSlotsInAllCases() {
        let all = Set(AppCustomThemeColorSlot.allCases.map(\.rawValue))
        for s in ["userBubbleText", "secondaryText", "link", "assistantBubbleBg", "border"] {
            #expect(all.contains(s))
        }
    }

    // The resolved theme actually routes through the inheritance helpers (not the old hardcoded
    // derivation) — so a set token reaches the rendered bubble/link/border.
    @Test("buildResolved wires the new slots through the inheritance helpers")
    func resolvedWiringUsesHelpers() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Theme/EpistemosTheme.swift")
        #expect(src.contains("inheritedHex(for: .userBubbleText, fallback: text"))
        #expect(src.contains("inheritedHex(for: .secondaryText, fallback: text"))
        #expect(src.contains("inheritedHex(for: .link, fallback: accent"))
        #expect(src.contains("inheritedHex(for: .border, fallback: accent"))
        #expect(src.contains("assistantBubbleBackgroundHex: assistantBubbleBackgroundHex(isDark:"))
    }
}
