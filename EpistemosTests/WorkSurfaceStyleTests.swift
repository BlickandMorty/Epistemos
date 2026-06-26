import AppKit
import Testing
@testable import Epistemos

@Suite("Work surface style")
struct WorkSurfaceStyleTests {
    @Test("surface backgrounds are derived from theme tokens, not fixed warm RGB")
    func backgroundsFollowTheme() {
        let oled = WorkSurfaceStyle.backgroundNSColor(for: .oledSoft, role: .canvas)
        let ember = WorkSurfaceStyle.backgroundNSColor(for: .ember, role: .canvas)
        let oldWarmDark = NSColor(red: 0.09, green: 0.075, blue: 0.06, alpha: 1)

        #expect(!sameRGB(oled, ember))
        #expect(!sameRGB(oled, oldWarmDark))
    }

    @Test("roles produce distinct layers inside one theme")
    func rolesProduceLayering() {
        let canvas = WorkSurfaceStyle.backgroundNSColor(for: .oledSoft, role: .canvas)
        let rail = WorkSurfaceStyle.backgroundNSColor(for: .oledSoft, role: .rail)
        let popover = WorkSurfaceStyle.backgroundNSColor(for: .oledSoft, role: .popover)
        let toolCard = WorkSurfaceStyle.backgroundNSColor(for: .oledSoft, role: .toolCard)

        #expect(!sameRGB(canvas, rail))
        #expect(!sameRGB(rail, popover))
        #expect(!sameRGB(canvas, toolCard))
    }

    @Test("permission and question cards use Work surface tokens for their background")
    func cardsUseWorkSurfaceBackground() throws {
        let permission = try loadMirroredSourceTextFile("Epistemos/Work/WorkPermissionCardView.swift")
        let question = try loadMirroredSourceTextFile("Epistemos/Work/WorkQuestionCardView.swift")

        for source in [permission, question] {
            #expect(source.contains("WorkSurfaceStyle.background(for: theme, role: .toolCard)"))
            #expect(!source.contains("Color.white.opacity(0.03)"))
            #expect(!source.contains("Color.black.opacity(0.02)"))
        }
    }

    @Test("native Work error and stop colors use theme tokens")
    func nativeWorkErrorsUseThemeTokens() throws {
        let surface = try loadMirroredSourceTextFile("Epistemos/Work/WorkEngineSurfaceView.swift")

        #expect(surface.contains(".foregroundStyle(theme.coral)"))
        #expect(!surface.contains(".foregroundStyle(.red)"))
    }

    private func sameRGB(_ lhs: NSColor, _ rhs: NSColor, tolerance: CGFloat = 0.0001) -> Bool {
        let l = lhs.usingColorSpace(.sRGB) ?? lhs
        let r = rhs.usingColorSpace(.sRGB) ?? rhs
        return abs(l.redComponent - r.redComponent) < tolerance
            && abs(l.greenComponent - r.greenComponent) < tolerance
            && abs(l.blueComponent - r.blueComponent) < tolerance
    }
}
