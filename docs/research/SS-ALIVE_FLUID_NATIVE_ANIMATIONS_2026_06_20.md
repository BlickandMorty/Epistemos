# SS-ALIVE — Make Epistemos feel ALIVE: native fluid animations app-wide (2026-06-20)

Owner (verbatim): *"native animations and even good fluid animations that make the app feel alive, but don't damage
anything… find other places that have ugly or glitchy animations or transitions and polish it up deeply, make it all
feel cohesive."* Extends SS-AN (homepage fold→Apple-blur-replace, now COMPLETE). NON-INVASIVE / additive / every new
animation `reduceMotion`-gated (existing convention, 56 view files); never over the live Metal graph canvas, never
invasive in TK2/Prose NSTextView, never touch vault/graph or dual-brain files.

**Big enabler:** macOS deployment target is **26.0** (`project.yml:4-5,13`) → every 2023–2026 SwiftUI animation API
is unconditionally available, no `@available` gating. Existing infra to REUSE: `Theme/EpistemosTheme.swift:2572-2592`
(`Motion` spring presets; `.repeatForever` intentionally banned = no idle-CPU traps), `Theme/NativeButtonStyles.swift`
(press/hover), `Theme/GlassModifiers.swift` (Liquid Glass `glassEffect(.regular.interactive())`), `Views/Landing/
BlurFade.swift` (the SS-AN blur-replace modifier — now the house style).

## Audit — glitchy/static/janky spots (file:line | issue | fix)
- **`App/RootView.swift:2616-2624` (HomeRouter Landing↔Chat swap)** — REUSES the exact `.scale(scale:0.99)` ZStack-fold
  on BOTH branches that SS-AN removed from home→graph (same double-animated-geometry "pop" class, over heavy ChatView).
  **Fix = the SS-AN BlurFade pattern** (asymmetric `.opacity`/`BlurFade`, `.easeOut(0.28)`, drop `.scale`). Highest
  cohesion payoff — direct cross-ref.
- **`Views/Landing/LandingView.swift:414,441,449,720,726,964,970`** — 7 overlays use `.transition(.opacity.combined(
  with:.scale(0.96–0.98)))` + spring → the same micro-pop on smaller surfaces. Migrate to `BlurFade`.
- **`Views/Landing/Farm/CompanionView.swift:45`** — `.scale(scale:0.5)` = a 50% snap-grow (most aggressive fold in
  app). Reduce to BlurFade or `.scale(0.92)` max, non-bouncy driver.
- **`Theme/PhysicsModifiers.swift:244`** — `.scale(scale:0, anchor:.leading)` scales from ZERO = origin-pop →
  `.scale(0.85)`+opacity or `.blurReplace`.
- **`Views/Chat/ChatSidebarView.swift:144`** — bare `.scale` (defaults to 0) = full origin-pop → `.scale(0.95)`+opacity.
- **`Views/Chat/MessageBubble.swift` + `ThinkingTrailView.swift:45`** — numeric labels (word/token/session counts)
  SNAP; no `.contentTransition(.numericText())`. Add it (numbers roll).
- **46× raw `ProgressView()`** (e.g. `MessageBubble.swift:976`, `LiveActivityStrip.swift:43`) — generic system spinners
  for conceptual states (thinking/indexing/listening), off-brand vs pixel-art-minimal. Replace conceptual ones with
  `.symbolEffect(.pulse/.variableColor.iterative/.bounce)` on an SF Symbol (proven once at `QuickCaptureView.swift:278`);
  keep `ProgressView` only for true determinate/long IO.
- **`Views/Settings/SettingsView.swift:53,186`** — `NavigationSplitView` detail-pane swap is a HARD-CUT → wrap detail
  in `.contentTransition(.opacity)` / keyed `.transition(.opacity)` + `.easeOut`.
- **`Views/Home/HomeGraphEmbeddedView.swift:199-200`** — verify the inner `.transition(.opacity)`+`.animation` doesn't
  double the outer SS-AN blur (one-fade-owner lesson); drop the inner if it races.
- **Zero adoption** (grep) of `matchedGeometryEffect` / `phaseAnimator` / `keyframeAnimator` / `scrollTransition` — the
  biggest "feel alive" gaps on a tile/list UI (tile→detail cross-fades instead of morphing; lists hard-appear).
- **No red flags:** `.repeatForever` banned (`EpistemosTheme.swift:2579`, "70% idle CPU"); ambient uses `TimelineView`/
  `CADisplayLink`. WATCH: never add SwiftUI `.blur`/`matchedGeometryEffect` over the live `MetalGraphRepresentable`
  (SS-AN caveat — route graph-canvas blur through the Metal layer).

## "Feel-alive" toolkit → surface map (cheap→safe→pixel-art-respecting)
| API | cost | surface |
|---|---|---|
| `.contentTransition(.numericText())` | cheapest | word/token/session counts |
| `.symbolEffect(.pulse/.replace/.variableColor)` | cheap | thinking/listening/indexing states (replace conceptual spinners), mic button, toolbar toggles |
| `BlurFade` transition (existing) | cheap, proven | all `.scale`-fold sites above (house style now) |
| `.spring(duration:bounce:0)` smooth presets | cheap | standardize page swaps — bounce:0 = no overshoot = no pop |
| `.scrollTransition` opacity/blur | cheap-mod | chat transcript / SessionList / NotesSidebar LazyVStack rows arrive instead of hard-appear |
| broaden `NativeButtonStyles` + interactive `glassEffect` | cheap-mod | bare buttons / floating chrome lacking press+hover |
| `phaseAnimator(trigger:)` | mod | idle/listening pulse, success checkmarks (trigger-driven, no repeatForever) |
| `matchedGeometryEffect` | high | ONE flagship shared-element: graph node tile → inspector morph |

## Ordered NON-INVASIVE build plan (smallest safe first; each reduceMotion-gated; visual feel = PENDING OWNER)
- **Tier S (trivial, do first):** (1) `.numericText()` on numeric labels; (2) SF-symbol effects replace conceptual
  spinners (start: chat thinking indicator + mic); (3) Settings detail-pane `.contentTransition(.opacity)`.
- **Tier S/M (apply proven SS-AN BlurFade to siblings — top cohesion):** (4) HomeRouter Landing↔Chat (`RootView.swift
  :2616`) → BlurFade, drop `.scale` (test mirrors `SSANHomepageTransitionTests`: assert no `.scale`, reduceMotion→nil);
  (5) the 7 LandingView overlays → BlurFade; (6) fix origin-pops (CompanionView:45, PhysicsModifiers:244, ChatSidebar
  :144).
- **Tier M:** (7) `.scrollTransition` fade-in on chat/sessions/notes lists (test scroll perf on a large vault); (8)
  broaden `NativeButtonStyles` + interactive glass to bare buttons/chrome.
- **Tier L (flagship, last, behind a flag):** (9) `matchedGeometryEffect` graph-node→inspector morph — `.drawingGroup()`
  the tile, NEVER cross the Metal canvas, prove no layout-thrash on-device before unflagging.

**Honesty gate (every step, per SS-AN):** ship code + a structural/reduceMotion test where possible; "feels native /
no flicker" = PENDING OWNER VERIFICATION (headless can't witness visual feel). Cross-ref SS-AN, SS-PERF2 (don't animate
hot/expensive paths). Sources: WWDC23 #10157 / WWDC24 #10145 advanced animations; phaseAnimator/keyframeAnimator/
contentTransition/symbolEffect/scrollTransition/matchedGeometryEffect + macOS-26 Liquid Glass docs.
