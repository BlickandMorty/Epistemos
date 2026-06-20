# SS-IL — Inline note-AI ("Ask this note"): KEEP inline streaming + send animation + pixel-art scroll-down arrow + AI/user separation (2026-06-20)

Owner: *"Keep the inline streaming of the 'Ask this note' AI feature — when I'm on the Prose editor and ask the AI
something I still want it to reply inline; that inline feature is very good, robust, KEEP it. But add an animation: when
you send a query the bar can do an animation, and there can be a large pixel-art arrow that pops up over the note pointing
down + a pixel-art phrase like 'scroll down to see answer' / 'scroll down for AI'. Then you scroll down and see the answer,
separated — maybe in a 'cold box' or some box obviously written by AI. There should be separation so the user doesn't get
confused about what's theirs vs the AI's. Make that robust WITHOUT losing the inline feature."* Code-grounded, NON-INVASIVE
(additive UI over the existing note-chat; never alters TK2/Prose text internals).

## Current state (file:line)
The inline "Ask this note" feature is `NoteChatState` (`Epistemos/State/NoteChatState.swift`), driven from
`NoteDetailWorkspaceView.swift`: composer + placeholder "Ask this note" (`:2072`), `submitQuery(...)` (`:1778`),
`isStreaming` with persistence on stream-end (`:1074-1076`), toolbar status phase (`:2061`), env-injected into the editor
(`:1015`, `:1374`). It streams a reply tied to the page. So the inline streaming pipeline EXISTS and works — this slice is
purely ADDITIVE chrome + clearer separation; do NOT refactor the streaming path.

## What to build (additive, pixel-art, 120 Hz)
1. **Send animation on the bar [S].** On `submitQuery`, animate the composer/ask-bar (e.g. a pixel-art pulse / scanline /
   "sending" shimmer) keyed off `isStreaming` true→false. Reuse existing animation tokens (cross-ref SS-ALIVE) so it feels
   cohesive; no jank, respects reduce-motion.
2. **Pixel-art "scroll down for the answer" affordance [S→M].** When an answer arrives BELOW the current viewport (i.e. the
   freshly-streamed AI block is off-screen), show a large animated pixel-art DOWN arrow overlaid on the note + a pixel-art
   phrase ("scroll down to see answer" / "scroll for AI"). It bobs/pulses, is dismissible, and auto-hides once the answer
   block scrolls into view (observe scroll offset vs the answer block's frame). Non-blocking overlay (`.overlay`), never
   covers the caret/active edit region. Only shows when the answer is actually below the fold — if the answer is already
   visible, skip the arrow.
3. **Separated AI answer box ("obviously AI") [M].** Render the AI answer in a visually distinct, clearly-AI container —
   a "cold box": different surface tint (use the theme's AI/assistant token, NOT the note body color), a pixel-art AI
   glyph/label ("AI"), a subtle border/wash, and clear top/bottom delimiters so it reads as separate from the user's prose.
   This kills the "is this mine or the AI's?" confusion. The box is non-editable-as-prose (it's a response artifact), with
   actions (copy / insert-into-note / dismiss) so the user EXPLICITLY chooses to merge AI text into their content — nothing
   silently becomes part of the note body. Cross-ref SS-2S (AI/user separation is the same anti-confusion principle as the
   cross-surface caveat) + SS-TC (the AI box gets its own color slot; coordinate with the granular-color work).
4. **Robustness / keep-inline contract.** The inline streaming stays exactly as-is functionally; this is overlay + container
   styling only. Persisted note-chat messages (`NoteChatState.persistMessages`) unchanged. No regression to streaming
   latency. Reduce-motion + accessibility labels on the arrow/box.

## Notes
- The "cold box" separation also future-proofs the two-surface story (SS-2S): an AI answer is a distinct, attributable
  block, so if a note later opens in Epdoc it can become a typed/attributed block rather than ambiguous inline text.
- Tests: behavior/render — (a) arrow shows only when the answer block is below the viewport and hides when scrolled to;
  (b) AI answer renders in the distinct container with the AI label; (c) inline streaming still completes + persists
  unchanged (no-regression guard).
Order [S→M], NON-INVASIVE; single targeted swift build. Cross-ref SS-ALIVE, SS-TC, SS-2S, SS-CLEAN (one answer-container
component, not cloned per surface).

---

## METAL STREAMING OVERLAY (owner 2026-06-20): make the inline streaming itself interesting/dynamic
Owner: *"For the 'Ask this note' streaming, make it more interesting + dynamic. Maybe use Metal to have an overlay going
on — it's hard to engineer UI surfaces on TextKit, so be creative. Find interesting ways to communicate the
interestingness of inline streaming happening on an ACTUAL editing surface and being able to immediately edit right after
it's done streaming — that's so interesting."* Research-validated, NON-INVASIVE (overlay above the editor; the TextKit2
text layer is untouched).

### Why a Metal OVERLAY (not editing the TextKit render path)
Engineering live effects INTO `NSTextView`/TextKit2 glyph rendering is brittle (the owner's point). The clean path on
macOS 26: a **non-interactive SwiftUI overlay layer above the editor**, GPU-driven by **SwiftUI Metal shaders**
(`.layerEffect` / `.colorEffect` / `.distortionEffect`) self-animated by `TimelineView(.animation)` — no CADisplayLink to
babysit, `allowsHitTesting(false)` so typing/selection pass straight through to TextKit underneath. The text stays 100%
native + editable; the "magic" is a shader skin on top that fades out to hand the text back to the user.
- **Reuse existing infra:** the app already ships `Epistemos/Shaders/ThinkingGlow.metal` (+ a Shaders/ dir) — extend/port
  that into a `[[stitchable]]` SwiftUI shader rather than authoring a raw `CAMetalLayer`/`MTKView`. (Today no View uses
  `.layerEffect`/`.colorEffect` yet — this is the first; establish a tiny `ShaderLibrary` seam others can reuse → SS-ALIVE.)
- **Precedent libs (study, don't vendor blindly):** twostraws/Inferno + SwiftUIShaders (shimmer/glitch/neon/holographic).

### The effect — "materialize then hand off" (communicates the inline-streaming story)
1. **On send:** the ask-bar emits a pixel-art pulse; a faint Metal scanline/shimmer sweeps the region where the answer
   will land (anchored to the caret/insertion line) — signals "the surface itself is thinking here."
2. **While streaming:** newly-arrived tokens "materialize" — a shader shimmer/glow (port of ThinkingGlow) rides the
   streaming frontier (the growing answer's trailing edge), drawn as an overlay clipped to the answer block's rect, driven
   by `TimelineView(.animation)` + a `startDate`/progress uniform. Pixel-art palette, theme-tinted (AI token, SS-TC).
3. **On stream end (the key beat):** the shimmer DISSOLVES (a quick dissolve/settle shader pass) to reveal clean, fully
   native, immediately-editable text — visually communicating "the AI wrote this; now it's yours." The caret can auto-land
   at the answer end so the user types instantly. This "dissolve→editable" hand-off IS the interestingness the owner wants.
4. **Cohesion with the rest of SS-IL:** the dissolved text settles INTO the "cold box" AI container (separation) with the
   scroll-down arrow if it's below the fold. One coherent moment: pulse → materialize → dissolve → separated + editable.

### Constraints / robustness
- Overlay only; `allowsHitTesting(false)`; the streaming pipeline + persistence unchanged (no regression — same contract as
  above). 120 Hz; respect `reduce-motion` (shader degrades to a simple fade or no-op). GPU cost bounded: shader runs ONLY
  during streaming + the short dissolve, clipped to the answer rect, then removed — never a persistent always-on layer
  (SS-PERF2/SS-CLEAN: no layering mud, no idle GPU). Works on the TK2/Prose surface now; the SAME overlay component is
  reusable on Epdoc later (one component, not cloned — SS-CLEAN).
- Tests: render/behavior — overlay mounts only while `isStreaming` (+ dissolve window) then unmounts; `hitTesting` false
  (typing reaches TextKit during + after); reduce-motion path; no-regression on streaming completion/persistence.
Sources: SwiftUI `.layerEffect`/`.colorEffect`/`.distortionEffect` + `TimelineView(.animation)` (Hacking with Swift, WWDC23
Metal-for-SwiftUI); twostraws/Inferno; SwiftUIShaders. Cross-ref existing `Shaders/ThinkingGlow.metal`, SS-ALIVE, SS-TC, SS-PERF2.

---

## SAFE-ADDITIVE IMPLEMENTATION (owner 2026-06-20: NO-DEFERRAL — research it to safety, then CODE it)
The loop deferred SS-IL fearing it would touch the owner-protected inline-streaming path. Deep map (Explore, file:line)
proves the enhancements can be **pure overlays that NEVER mutate text storage** → the regression risk is removable → no
deferral needed. Implement via this seam.

### The streaming path = text-storage + offset math (DO NOT TOUCH)
The streamed answer flows through a divider-protected append pipeline, entirely in two files:
- `NoteChatState.swift`: divider contract (`NoteChatInlineResponse.divider` :7, `dividerRange` :9, `editTouchesDivider` :13);
  the 6 mutation callbacks (`onStreamStart/onTokenFlush/onStreamFinish/onAccept/onDiscard/onReplaceInlineResponse` :72-96);
  the `useResponsePanel` gate (:65, set in `beginSubmission` :283); `finalizeResponseText`→`onReplaceInlineResponse` (:305-321).
- `ProseEditorRepresentable2.swift`: `startNoteChatStream` :635, `appendNoteChatTokens` :655 (always appends at `ts.length`),
  `replaceNoteChatResponse` :725, accept :686 / discard :705, all under the `isFlushingTokens` reentrancy flag.
- `ProseTextView2.swift`: `hasProtectedInlineResponseDivider` :123 + `shouldChangeText` rejection :418-442.
FRAGILE: anything that writes `NSTextStorage`, sets a text-storage/layout delegate, adds a glyph attribute, or inserts a
`replaceCharacters` mid-stream regresses it (races `isFlushingTokens`, shifts `responseRange` offsets, pollutes the undo
group). So the enhancements MUST be SwiftUI/AppKit overlays that READ state and never mutate storage.

### Read-only signals an overlay consumes (zero modification)
`NoteChatState` is `@MainActor @Observable`: `isStreaming` :58, `responseText` :60, `hasResponse` :62, `useResponsePanel`
:65, `toolbarStatusPhase` :66, `error` :64. Missing: a published answer RECT — add it ADDITIVELY (below).

### The safe seam — one overlay + one additive read-only getter
1. **Overlay mount:** add ONE `.overlay { InlineAnswerDecorationOverlay(...) }` on the `noteCanvas` ZStack
   (`NoteDetailWorkspaceView.swift` after :1012; the ZStack already has `.environment(noteChatState)` :1015 + sibling
   overlays at :992/996/1001), guarded `if noteChatState.hasResponse && !noteChatState.useResponsePanel`. `.allowsHitTesting(false)`
   except the arrow button.
2. **Answer rect (additive, read-only):** add `var inlineResponseRectProvider: (() -> CGRect?)?` to `NoteChatState` (next to
   the existing provider closures, after :96 — matches the documented provider pattern). Populate it in
   `ProseEditorRepresentable2.wireNoteChatCallbacks` (:594) with a READ-ONLY helper that computes `dividerRange`→`responseRange`
   (reuse the math at :730-734) and calls the EXISTING `ProseTextView2.firstRect(forCharacterRange:actualRange:)` (:215-242,
   already returns screen-space NSRect). This adds a GETTER only — touches none of the 6 callbacks, no `replaceCharacters`.
3. **Cold box:** rounded container + border drawn in the overlay clipped to the answer rect — paints OVER the inline text
   without changing how it's stored. Reads `useResponsePanel == false` to decide to draw; never sets it. (Verdict: the
   inline-vs-panel risk is avoided entirely — overlay-only.)
4. **Scroll-down arrow:** positioned at the rect's bottom edge, shows only when the rect is below the viewport; the one
   hit-testing element.
5. **Metal glow:** `Shaders/ThinkingGlow.metal` EXISTS + has ZERO consumers (orphan scaffold → wiring is purely additive,
   nothing to regress). Two additive routes: (a) add a `[[stitchable]]` variant + SwiftUI `.colorEffect` on the overlay
   (the current entry points are classic vertex/fragment, so the stitchable fn is new), or (b) an `NSViewRepresentable`+`MTKView`
   modeled on the existing `MetalGraphView.swift`. Either: `allowsHitTesting(false)`, reads only `isStreaming` + rect, gated
   to the stream+dissolve window then removed (no idle GPU).

### Regression-guard tests (PROVE inline streaming unchanged) — required before "done"
(1) divider constant byte-equality + `editTouchesDivider` still rejects in-marker edits; (2) inline lifecycle order
(`["replace","accept"]` suffix + visible-delta join) byte-identical WITH the overlay present; (3) `onReplaceInlineResponse`
fires once inline / zero in panel mode; (4) invoking `inlineResponseRectProvider` changes nothing + fires zero of the 6
callbacks; (5) append-after-divider invariant + `hasProtectedInlineResponseDivider` toggle unchanged; (6) overlay file
imports no `NSTextStorage`/`ProseTextView2` symbols (compile-time proof it can't touch storage).

### Files: NEW `Views/Notes/InlineAnswerDecorationOverlay.swift` (+ optional `ThinkingGlowMetalView.swift` / stitchable shader);
EDIT `NoteDetailWorkspaceView.swift` (1 overlay line), `NoteChatState.swift` (1 read-only closure), `ProseEditorRepresentable2.swift`
(populate the getter). DO-NOT-TOUCH list above. **CODE IT — do not defer; the safe seam is proven.**
