# SS-IR — Instant-recall / Halo popup: scope to editors + bubble→native-popover redesign (2026-06-20)

Read-only research (subagent), code-grounded. Feeds the INSTANT-RECALL-POPUP ledger item. Owner: *"the recall
popup → on the EDITORS (Epdoc + TK2), NOT chat; a glowing BUBBLE first, click → a native popover (Apple-like,
less invasive, not the weird pixel box); accuracy-first (slower OK, must be accurate), non-invasive esp. for
models."* Cross-refs SS-UMA (recall accuracy), SS-O/EM (Epdoc). NON-INVASIVE for TK2 (overlay only, no UI in the
NSTextView).

## Headline — there are TWO recall surfaces (the key finding)
1. **Surface A — W8 "Halo"** (`HaloButton` + `ShadowPanel` NSPanel): already editor-scoped (TK2/notes only), a
   corner glyph that opens a real **AppKit NSPanel** (AppKit-positioned, click-gated, light-dismiss). **Already
   near the target design.**
2. **Surface B — "Contextual Shadows" V0** (`ContextualShadowsButton` + `ContextualShadowsPanel`): a **SwiftUI
   overlay box that AUTO-SHOWS while typing** on chat/landing/mini-chat/note-detail. **THIS is the "weird pixel
   box that overlays things."**
**The owner's complaint = Surface B.** The redesign = stop B auto-showing, remove B from chat/landing, converge
onto A's native-panel model (or an NSPopover), add the bubble to Epdoc, accuracy-first via the warm RRF/HNSW.

## Current popup (file:line)
**Surface A (Halo, already good):** trigger = keystroke → `HaloEditorBridge.textDidChange` (`Engine/HaloEditor
Bridge.swift:95`) → `HaloController.editorTextDidChange` (`Engine/HaloController.swift:152`), **200ms debounce** →
`ShadowSearchService.searchReportingErrors` (`:208-242`), min 3 chars + stop-word gate (`:345`); state machine
`dormant→sensing→available(count)→open` (`:317`). Affordance = `HaloButton` (`sparkle.magnifyingglass` SF symbol,
24×24 `.ultraThinMaterial` circle, spring, hidden in dormant/sensing, `Views/Halo/HaloButton.swift:39-65`) — NOT
auto-invasive (must click). The "box" = `ShadowPanel` = a real **NSPanel** (`.nonactivatingPanel/.floating`,
NSVisualEffectView blur, `Views/Halo/ShadowPanel.swift:23-85`) hosting `ShadowPanelContent` (360×480 list + domain
picker + provenance ribbons, `ShadowPanelContent.swift:66-89`); positioned by `panelOrigin(forAnchorRect:)` with
screen-overflow flip+clamp (`ShadowPanel.swift:189-222`) + `didResignKey` light-dismiss (`:243-256`). **Already
the native, anchored, click-gated surface the owner wants.**
**Surface B (Contextual Shadows, the invasive one):** trigger = keystroke → `ContextualShadowsState.requestRecall`
(`State/ContextualShadowsState.swift:211`); backend = warm Shadow RRF/HNSW dual-domain + merge + FTS fallback
(`:241-276`). Affordance = `ContextualShadowsButton` (`sparkles`+count capsule, `Views/Recall/ContextualShadows
Button.swift:24-57`). Box = `ContextualShadowsPanel` (**SwiftUI** VStack + `PixelPanelBackground`, fixed width
520/680, `.move(edge:.bottom)`, `Views/Recall/ContextualShadowsPanel.swift:128-147,504-533`) = **the "weird pixel
box."**

## Where it's wired (keep/remove/add)
| Surface | File:line | System | Action |
|---|---|---|---|
| **TK2/notes editor** | `Views/Notes/ProseEditorRepresentable2.swift:990-998` (HaloButton as `NSHostingView` pinned to scrollView, non-invasive), feeds `:1006-1029` | Halo (A) + also feeds B `:1111` | **KEEP** (consolidate to bubble→popover) |
| **Chat composer** | `Views/Chat/ChatInputBar.swift:1129` button, `:1192-1201` overlay box, `:1816` requestRecall | B | **REMOVE** |
| **Landing** | `Views/Landing/LandingView.swift:1124/1335/1574` | B | **REMOVE** |
| **Mini-chat** | `Views/MiniChat/MiniChatView.swift:1047/1109/1234` | B | **REMOVE** |
| **Note-detail** | `Views/Notes/NoteDetailWorkspaceView.swift:1094/1100` | B | KEEP/optional (note surface) |
| **Epdoc** | `Views/Epdoc/EpdocEditorChromeView.swift:146` = only a Halo SEARCH closure for Insert-link; **NO recall bubble/panel** | — | **ADD** |
Chat/landing have ZERO Halo refs (pure Surface B); Epdoc has NO instant-recall today.

## Why the box is invasive (= Surface B)
1. **Auto-shows on type, not click:** `requestRecall`→`publishPayload(...isVisible:true)` sets `isPanelVisible
   =true` on any hit (`ContextualShadowsState.swift:303-312,465`). The full box pops by itself mid-typing.
   (Surface A only opens on explicit `openPanel()`.)
2. **SwiftUI overlay inside the host layout:** `.overlay(alignment:.bottomTrailing){ ContextualShadowsPanel(...)
   .padding(...) }` (`ChatInputBar.swift:1192-1201`, same in Landing) → overlaps sibling content (message list,
   composer), clipped/occluded, NO AppKit auto-reposition / screen-edge flip / outside-light-dismiss.
3. **Large + grows:** width 520/680, up to 740/780 workspace mode, height to 610 (`ContextualShadowsPanel.swift
   :17-39`). A big box appearing unbidden = "overlays lots of things."
Surface A's NSPanel has NONE of these (flip/clamp + light-dismiss). → converge B onto A's model.

## The bubble → native-popover redesign
Target: a subtle **glowing pixel-orb bubble** (reuse `HaloButton`'s glyph/spring) that appears only when recall
has results; click → a **native popover** anchored to the bubble (non-modal, AppKit auto-positioned, `.transient`
light-dismiss), clean results `List`. Keep pixel-art on the BUBBLE; make the RESULTS surface native+clean.
- **Bubble:** reuse `HaloButton.swift:39-65` (spring, ultraThinMaterial, ⌘⇧H); add a pulsing glow ring
  (`.overlay(Circle().stroke(.tint))` / `.shadow`) for the "glowing orb." **Do NOT auto-open** — bubble appears
  only on `.available(count:)`.
- **Popover (replaces the box), two native paths:** (preferred) **keep the existing `ShadowPanel` NSPanel** (it's
  already native/anchored/light-dismissing) but **slim `ShadowPanelContent`** (drop the graph-projection +
  provenance ribbons → clean List = "more Apple-like, less invasive"); OR (alt) an **`NSPopover` via
  `NSViewRepresentable`** wrapping `NSHostingController(rootView: resultsList)`, `contentSize ~320×420`,
  `behavior=.transient`, `show(relativeTo:of:preferredEdge:.maxY)` anchored to the bubble. Most "anchored/
  auto-positioned/click-dismiss."
- **Critical fix (both paths):** make the results surface **click-gated only** — stop B's auto-`isVisible:true`
  on type (`ContextualShadowsState.swift:465`); a "has results" flag lights the bubble, popover opens only from
  the bubble's action (exactly Surface A's `HaloController.openPanel() :258`).

## Editor scoping + accuracy
- **(a) TK2 (`ProseEditorRepresentable2.swift`, hardened `ProseTextView2`):** ALREADY non-invasive — bubble is a
  sibling `NSHostingView` pinned to the **scrollView** (NOT in the text view) via Auto Layout (`:990-998`), text
  changes feed `controller.editorTextDidChange` (`:1006-1010`). **Keep overlay-only**; anchor the popover to the
  bubble's host frame (tighter than the whole scrollView bounds).
- **(b) Epdoc (`EpdocEditorChromeView.swift`, Tiptap WKWebView):** NO recall today → add a **SwiftUI overlay
  bubble** (Epdoc is SwiftUI chrome, `.overlay(alignment:)` orb is natural); feed via `HaloEditorBridge.feed
  (text:)` (the manual non-NSTextView path `HaloEditorBridge.swift:62-66`) off the Tiptap content-change/autosave
  hook (`EpdocEditorChromeView.swift:132,161`). Anchor popover via `.popover` / the NSPopover representable.
  Cross-ref SS-O/EM.
- **(c) Remove from chat/landing/mini-chat** (delete the B button/panel mounts + requestRecall feeds at the sites
  above). `ContextualShadowsState` stays (the recall brain); just stop chat/landing from feeding/showing it.
- **(d) ACCURACY-FIRST (cross-ref SS-UMA):** the accurate path exists — both hit the warm Shadow backend (tantivy
  BM25 + usearch HNSW + **RRF k=60** via `client.search`, `ShadowSearchService.swift:295`; `shadow_warm()`
  preload `RustShadowFFIClient.swift:201`). For accuracy-over-latency: **raise the debounce** (Halo 200ms
  `HaloController.swift:88,118` → 350–500ms), **raise `limit`** (Halo 10 `:223` → use B's 16+top-12), prefer B's
  **dual-domain merge + `rankedUniqueHits` + FTS fallback** (`ContextualShadowsState.swift:241-276`, more accurate
  than Halo's single-domain). "Slower but accurate" = lean on RRF/HNSW warm path + longer debounce + wider limit.

## Ordered plan
1. **[S]** Stop Surface B auto-showing: a successful query lights the BUBBLE but does NOT set `isPanelVisible=true`
   (`ContextualShadowsState.swift:465`). Immediate de-invasive win.
2. **[S]** Remove chat/landing/mini-chat mounts+feeds (`ChatInputBar.swift:1129/1192/1816`, `LandingView.swift
   :1124/1335/1574`, `MiniChatView.swift:1047/1109/1234`).
3. **[S]** Add a glow ring to `HaloButton` (`:45-49`) for the glowing-orb identity.
4. **[M]** Slim `ShadowPanelContent` (drop ribbons → clean List) and/or wrap in an `NSPopover` representable
   anchored to the bubble, `.transient` (`ShadowPanel.swift`/`ShadowPanelContent.swift:66-89`).
5. **[M]** Accuracy tune: longer debounce + wider limit + dual-domain RRF merge as the shared path
   (`HaloController.swift:88,223` + reuse `ContextualShadowsState.swift:241-276`). Cross-ref SS-UMA.
6. **[L]** Mount bubble+popover on **Epdoc** via SwiftUI overlay + `HaloEditorBridge.feed(text:)` off the Tiptap
   content-change/autosave hook (`EpdocEditorChromeView.swift:132/161`; `HaloEditorBridge.swift:62`). Cross-ref
   SS-O/EM.
7. **[L]** Unify the two recall systems (Halo `HaloController` vs `ContextualShadowsState`) so TK2 + Epdoc share
   ONE bubble/popover/backend instead of two divergent stacks.

## Flagged
Did not open MiniChatView/NoteDetailWorkspaceView/ProseTextView2 line-by-line (grep-confirmed mounts; exact
container invasiveness on those 2 note surfaces unverified); the composer-side debounce value for Surface B
(`scheduleContextualShadowsRecall ChatInputBar.swift:1797`) not confirmed. Both surfaces scoped since A is
near-target + B is the invasive one.

Key files: `Views/Halo/HaloButton.swift` (bubble) · `Views/Halo/ShadowPanel.swift` (native NSPanel target) ·
`Views/Halo/ShadowPanelContent.swift:66-89` (slim) · `Engine/HaloController.swift` (state+debounce) ·
`Engine/HaloEditorBridge.swift:62` (feed for Epdoc) · `Engine/ShadowSearchService.swift:295` (warm RRF/HNSW) ·
`State/ContextualShadowsState.swift:241-276,465` (B brain + invasive auto-show) · `Views/Recall/ContextualShadows
{Button,Panel}.swift` (retire/converge) · `Views/Notes/ProseEditorRepresentable2.swift:990-998` (TK2 KEEP) ·
`Views/Chat/ChatInputBar.swift` + `Views/Landing/LandingView.swift` + `Views/MiniChat/MiniChatView.swift` (REMOVE)
· `Views/Epdoc/EpdocEditorChromeView.swift` (ADD). Cross-ref SS-UMA, SS-O/EM.

---

## VERIFICATION (owner 2026-06-20: "I don't see Instant Recall anymore — is it still working? + I haven't seen the new UI")
Investigated on `main` (Explore, file:line). **The feature is NOT removed — it's wired + enabled-by-default, but invisible
for explainable reasons, and the NEW UI in this slice is UNBUILT.**
- **Wired + ON by default.** `ContextualShadowsState.isEnabled` defaults TRUE (`State/ContextualShadowsState.swift:91,121-127`).
  Surface A (Halo NSPanel) mounts in TK2 (`ProseEditorRepresentable2.swift:990-998`, opens `showHaloPanel():1013-1030`);
  Surface B (auto-show box) mounts in NoteDetail (`NoteDetailWorkspaceView.swift:996-1101`), ChatInputBar (`:1129,1193`),
  Landing (`:1139,1350`), MiniChat. No off-flag.
- **No "speed-for-accuracy" commit landed.** The accuracy-first direction lives ONLY in this slice (unbuilt). Reachable
  history shows isolation/scoping commits (`b91487475` harden surface isolation 5-31; `01b1ba4bb` "Focus instant recall on
  active text" 6-01 → per-scope payloads `ContextualShadowsState.swift:380-382,460-487`; `031e5a5cb` 6-01), none disabling.
- **Backend bootstraps at startup** (`AppBootstrap.initializeShadowBackendIfReady() :2409, :3713-3816`) but **requires an
  active vault** (`:3714` early-return "No active vault selected") and a successful Rust FFI open (`:3754`) to install the
  search service via `configureShadowSearch(:3805)`. On failure it degrades to empty silently (`:3710-3712`).
- **WHY THE OWNER DOESN'T SEE IT (most→least likely):** (1) **no recall hits → no chrome** — both buttons render ONLY with
  payload (`ContextualShadowsButton.swift:26` needs `payload.hasPanelPayload`); zero hits = invisible by design. (2) **search
  service never installed** — no active vault or FFI open/warm failed → `haloSearchService` nil → `dismantleHalo()` removes
  the Halo button (`ProseEditorRepresentable2.swift:976-978`). (3) **scoping refactor** narrowed it from global to active
  editor/doc scope (reads as "gone"). (4) **the new popover UI doesn't exist yet** — so there's nothing new to see.
- **ADDED REQUIREMENTS for the build:** (a) make it **DISCOVERABLE even with zero hits** — a persistent, honest entry point
  (the Halo bubble visible in a resting state on the editors with an empty-state "no matches yet", not only when results
  exist) so the owner can always find it; (b) a **runtime health/diagnostic** surfacing whether the shadow search service
  installed (vault present? FFI open? index size?) — wire into the Settings diagnostics rows (`BackgroundIndexingHealthRow`/
  `EditorBundleHealthRow` pattern) so "why is it empty" is answerable; (c) THEN build the bubble→`NSPopover` redesign + add
  the bubble to Epdoc (`EpdocEditorChromeView.swift:146`) per the plan above. Verify on-device the owner can SEE + OPEN it.
