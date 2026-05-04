import Testing

@Suite("Hermes brand source guards")
struct HermesBrandSourceGuardTests {
    @Test("Hermes brand uses bundled fonts and hero mode uses brand display typography")
    func hermesBrandUsesBundledFontsAndHeroDisplayTypography() throws {
        let brand = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Hermes/HermesBrand.swift"
        )
        let liquidGreeting = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/LiquidGreeting.swift"
        )
        let directInfoPlist = try loadMirroredSourceTextFile("Epistemos-Info.plist")
        let appStoreInfoPlist = try loadMirroredSourceTextFile("Epistemos-AppStore-Info.plist")

        // The bundled Inter binary is the variable font; both
        // Inter-Regular.ttf and Inter-SemiBold.ttf carry PSName
        // "InterVariable". HermesBrand must request that PSName + use
        // `.weight()` to pick the axis. See HermesBrandFontResolutionTests
        // for the runtime PSName check that reads each .ttf header.
        #expect(brand.contains("private static let interVariableFontName = \"InterVariable\""),
                "HermesBrand must use the bundled Inter variable font's PSName")
        #expect(brand.contains("private static let monoFontName = \"JetBrainsMono-Regular\""),
                "HermesBrand.mono must request the bundled JetBrains Mono font")
        #expect(brand.contains(".custom(interVariableFontName, size: size).weight(.semibold)"),
                "HermesBrand.display must select semibold via .weight() on the variable font")
        #expect(brand.contains(".custom(interVariableFontName, size: size).weight(.regular)"),
                "HermesBrand.body must select regular via .weight() on the variable font")

        #expect(liquidGreeting.contains("hermesHeroMode ? HermesBrand.display(compact ? 22 : 44) : AppDisplayTypography.font(size: compact ? 22 : 44)"),
                "LiquidGreeting must use HermesBrand.display for the Hermes Agent hero phrase")

        for plist in [directInfoPlist, appStoreInfoPlist] {
            #expect(plist.contains("ATSApplicationFontsPath"))
            #expect(plist.contains("Resources/Fonts"))
        }
    }

    @Test("Hermes sigil is caduceus canvas, not SF Symbol placeholder")
    func hermesSigilIsCaduceusCanvasNotSFSymbolPlaceholder() throws {
        let sigil = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Hermes/HermesShimmeringSigil.swift"
        )

        #expect(sigil.contains("HermesCaduceusCanvas"),
                "Hermes sigil must render the native caduceus Canvas")
        #expect(sigil.contains("Canvas"),
                "Hermes sigil must stay native SwiftUI Canvas until licensed assets land")
        #expect(!sigil.contains("figure.stand.dress"),
                "Hermes sigil must not regress to the old SF Symbol placeholder")
    }
}
