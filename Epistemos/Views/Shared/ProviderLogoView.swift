import SwiftUI

// P6.1 — renders a provider's brand logo: the staged lobehub SVG from the asset
// catalog when present, else the SF-Symbol fallback so SOMETHING always shows
// (render-safe even before the full SVG set is staged). B&W / template-rendered so
// it tints with the surrounding foreground style.
struct ProviderLogoView: View {
    let brand: ProviderBrand
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let assetName = brand.assetName, NSImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            } else {
                Image(systemName: brand.sfSymbolFallback)
                    .font(.system(size: size * 0.82))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(brand.displayName) logo")
    }
}
