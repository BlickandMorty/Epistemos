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

extension AnyTransition {
    /// SS-ALIVE: the cohesive blur-fade content swap — the same Apple blur-replace
    /// feel as the SS-AN homepage greeting↔graph transition, reused for the
    /// Landing↔Chat fold (and any sibling content swap) so the whole app breathes
    /// the one way: blur away on removal, blur in on insertion. No `.scale` fold,
    /// no spring pop. Pair with a flat `.easeOut(duration: 0.28)` driver.
    static func blurFade(radius: CGFloat = 12) -> AnyTransition {
        .modifier(
            active: BlurFade(blur: radius, opacity: 0),
            identity: BlurFade(blur: 0, opacity: 1)
        )
    }
}
