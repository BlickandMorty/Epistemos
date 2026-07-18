import Testing
import Foundation
import AppKit

@testable import Epistemos

// Regression guard (2026-06-21) for the body-vs-display font split that the display-font
// items (L1160 / L1163) deliberately hinge on. AppDisplayTypography.regularUIFont(...) backs the
// note-editor BODY and chat body; the custom/display faces (displayFontName) are pixel-art display
// faces used only for headings + display chrome. The deliberate decision is: picking a custom display
// font must NOT make body text illegible — regularUIFont always stays a readable UI face.
//
// Existing coverage only SOURCE-CHECKS the call site (ChatPresentationTests asserts the string
// "regularUIFont(size: size, weight: weight)" appears) — nothing executes the invariant, so a refactor
// that made regularUIFont return the custom-display font would keep every font test green while the
// editor body broke. These tests RUN the pure nonisolated funcs and pin the behavior.
@Suite("Typography — the body UI font stays readable, never the custom-display face")
struct BodyReadableFontInvariantTests {

    @Test("regularUIFont resolves to a readable UI face at every weight (never a display face)")
    func regularUIFontIsAlwaysReadable() {
        for weight in [NSFont.Weight.regular, .medium, .semibold, .bold] {
            let font = AppDisplayTypography.regularUIFont(size: 14, weight: weight)
            #expect(
                AppDisplayTypography.isRegularUIFont(font),
                "regularUIFont(weight: \(weight)) must be a readable UI face, got \(font.fontName)"
            )
        }
    }

    @Test("isRegularUIFont discriminates — a non-UI face (Courier) is NOT classified readable")
    func predicateRejectsNonUIFace() {
        // Negative control: proves the positive assertions above aren't trivially true.
        if let courier = NSFont(name: "Courier", size: 12) {
            #expect(!AppDisplayTypography.isRegularUIFont(courier))
        }
    }

    @Test("the readable font family constants stay the AvenirNext faces (not swapped to a display face)")
    func readableFontNamesAreStable() {
        #expect(AppDisplayTypography.readableFontRegularName == "AvenirNext-Regular")
        #expect(AppDisplayTypography.readableFontMediumName == "AvenirNext-Medium")
        #expect(AppDisplayTypography.readableFontSemiboldName == "AvenirNext-DemiBold")
        #expect(AppDisplayTypography.readableFontBoldName == "AvenirNext-Bold")
    }
}
