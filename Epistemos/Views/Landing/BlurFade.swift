import SwiftUI

// SS-AN: a tiny reusable blur+fade modifier for the homepage→graph "Apple blur-replace"
// transition. Used as a `.transition(.modifier(active:identity:))` so the greeting /
// buttons blur away (removal) and the graph blurs in (insertion) via SwiftUI
// `.blur(radius:)` + `.opacity()` — no .scale fold, no spring pop, no flicker. (The
// `.blur` primitive is already used on the greeting overlay.)
struct BlurFade: ViewModifier {
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .opacity(opacity)
    }
}
