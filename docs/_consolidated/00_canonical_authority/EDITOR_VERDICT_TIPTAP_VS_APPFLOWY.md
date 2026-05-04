# EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md — Honest assessment

> **Authored**: 2026-04-27 final pass.
> **Question**: Should Epistemos port AppFlowy's editor (Rust+Dart/Flutter), rewrite the rich editor in native Swift, take inspiration, or leave Tiptap-in-WKWebView alone?
> **Verdict**: **Leave Tiptap-in-WKWebView alone for V1.5. Take inspiration from AppFlowy's data model, NOT its UI layer.** Reasoning below.
> **Authority**: composes with `workspace_epistemos_code_verdict.md` (Code editor architectural lock — already settled), `workspace_gpt_workspace_synthesis.md` (Document editor architecture — already settled), `EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN.md` (benchmark first, optimize second).

---

## §1 — What you're comparing

### Your current stack (per `workspace_gpt_workspace_synthesis.md`)

| Surface | Implementation | Why |
|---|---|---|
| **Prose editor** | Native TextKit 2 (Swift) | Native IME, undo/redo, accessibility, scrolling. The ONE thing AppKit gives you that nothing else can match. **Already shipped, working, fast.** |
| **Document editor** | Tiptap (JavaScript) in WKWebView | Block-based WYSIWYG with tables/images/embeds/code blocks. ProseMirror under the hood. **Mature gold-standard for this pattern.** |
| **Code editor** | CodeEditSourceEditor (Swift) + SwiftTreeSitter live syntax | Per `workspace_epistemos_code_verdict.md`: native surface + Rust background brain + LSP. Locked. |

### AppFlowy's stack

| Surface | Implementation |
|---|---|
| **All editors** | Custom Flutter editor (`appflowy_editor` package, written in Dart) |
| **Backend** | Rust (`appflowy-cloud` + Flutter↔Rust bindings) |
| **Rendering** | Flutter framework → Skia → Metal layer on macOS |
| **State management** | Flutter's reactive paradigm (BLoC pattern + Provider) |

### What is Dart?

Dart is Google's language for Flutter. It's:
- Statically typed (like TypeScript or Swift)
- AOT-compiled to native code for release builds (no Dart VM at runtime on mobile/desktop)
- JIT-compiled in development for hot reload
- Single-threaded with isolates for concurrency (similar conceptually to actors)
- Has null safety since 2021

Dart isn't "bad" — it's just **Flutter's language**. You don't choose Dart; you choose Flutter, and Dart comes with it. Outside of Flutter, Dart is rarely used.

---

## §2 — The honest WKWebView overhead question

**Is WKWebView a real performance drop?** Let's separate myth from reality.

### The real overhead (yes, this is real)

1. **Out-of-process model**: WKWebView spawns a separate WebContent process. Inter-process communication (IPC) over Mach ports between your Swift app and the JS world.
2. **Memory baseline**: ~50-200 MB per WKWebView instance for a non-trivial document. Not free.
3. **Startup cost**: First load of Tiptap bundle = HTML parse + CSS apply + JS execute → 50-300ms before editor is interactive.
4. **Bridge serialization**: Every Swift↔JS message gets JSON-encoded. Per-keystroke round-trips would be catastrophic.

### The mitigations (already in your design per `workspace_gpt_workspace_synthesis.md`)

1. **`WKProcessPool` shared and pre-warmed** at app launch → first document opens fast (~50ms instead of 300ms)
2. **Bridge sends transaction summaries** (ProseMirror transactions are small deltas), NOT the full doc on every keystroke → typing latency stays in single-digit ms
3. **Local bundle** of Tiptap (no runtime npm, no remote assets) → no network in the hot path
4. **Custom URL scheme** for package assets (images embedded in `.epdoc`) → no filesystem JS-side
5. **Pre-warmed shared process pool** means switching documents doesn't recreate the editor

### What this means honestly

For a **Document editor** (writing essays, polished output, tables, images), WKWebView with the above mitigations gives you **typing latency under 16ms (60fps)**. You won't perceive jank. Memory cost is real (~150 MB resident per open Document) but bounded.

For a **Prose editor / chat input** (the 80% case where typing-blocking matters most), you're already native TextKit 2 — there is NO WKWebView in that path.

For the **Code editor**, you're already native + Rust background brain. NO WKWebView.

**WKWebView is ONLY in the Document path.** That's the rare path, not the hot path.

---

## §3 — Is AppFlowy a moat to copy?

**No.** AppFlowy is a **Notion alternative** — its moat is Notion-feature-parity (databases, kanban boards, calendars, sub-pages, sharing). That's not Epistemos's moat.

### Epistemos's actual moats (per `MASTER_FUSION.md §17.5`)

```
Ambient memory:    Halo / Contextual Shadows
Deliberate depth:  Concept Door (N2)
Deliberation shape: Exploration Spectrum (N3)
Deterministic verification: Local Analysis Mode (N4)
Provenance plane:  RunEventLog + MutationEnvelope + AgentEvent + GraphEvent
Typed artifacts:   ProseNote / Document / RawThought / Run / Source / Code / Output / Claim / Evidence / Skill / Session
Native moat:       NSPanel non-activating + TextKit 2 + Metal + MLX + AFM in-process
Visible cognition: graph events reflect truth, never theater
Policy profiles:   one runtime, MAS + Pro
```

The **editor surface** is a means to render artifacts. It is NOT the moat. Two notes-app competitors with identical Tiptap editors will differentiate on **everything except the editor**.

### AppFlowy doesn't have

- Halo / Contextual Shadows (ambient recall as you type)
- Concept Door (every concept opens a world)
- Exploration Spectrum meter (deliberation shape control)
- Local Analysis Mode (deterministic math/code verification)
- Provenance plane with retraction propagation
- Typed artifact spine with ULID + content_hash + provenance
- Native macOS NSPanel non-activating UX
- MLX-Swift in-process inference
- Metal graph rendering with cognition-truthful events

**Porting AppFlowy gets you a worse editor surface and zero of the moats.**

---

## §4 — The four real options (with tradeoffs)

### Option A: Port AppFlowy's editor to native Swift

**Cost**: 4-6 months of focused work (re-implementing block-based WYSIWYG editor with tables/images/embeds in SwiftUI from scratch).
**Gain**: Native rendering. ~50 MB memory savings vs WKWebView. ~5ms typing latency improvement.
**Verdict**: ❌ **Catastrophic ROI.** You'd be reinventing Tiptap (mature, well-tested, has 3 years of edge-case fixes) in a less-mature framework, while delaying every actual moat (Halo, N2, N3, N4) by half a year. **Don't do this.**

### Option B: Adopt AppFlowy as the editor (Flutter)

**Cost**: Adding Flutter runtime to a Swift app. ~150 MB Flutter framework + Skia rendering layer + Dart isolate.
**Gain**: AppFlowy's block model + plugin system.
**Verdict**: ❌ **Worst of all worlds.** Flutter on macOS doesn't match Cocoa IME / accessibility / scrolling. You inherit AppFlowy's bugs without any of their team. Your Native moat dies. **Don't do this.**

### Option C: Take inspiration from AppFlowy's data model

**Cost**: ~1-2 days reading AppFlowy source code + porting the patterns that fit.
**Gain**: Insights into block-based architecture, slash commands, plugin patterns, embed handling, sub-page hierarchy. Their Rust backend has interesting CRDT patterns for collaboration (`appflowy-collab` crate).
**Verdict**: ✅ **Recommended for V1.5+.** AppFlowy's data model is good. Their Rust backend (especially `appflowy-collab`, `flowy-document`) is worth studying. Their UI is NOT.

### Option D: Leave Tiptap-in-WKWebView alone for V1.5

**Cost**: Zero.
**Gain**: Ship V1 Halo + V1.5 typed artifact spine + Concept Door + Exploration Spectrum + Local Analysis Mode without distraction.
**Verdict**: ✅ **What you should actually do RIGHT NOW.** Per `EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN.md §1.1`: *"No migration, no editor work, no BoltFFI prototype until instrumentation exists. The benchmark harness is the only slice that cannot cause a regression."*

---

## §5 — The benchmark-first rule (binding)

Before you change anything about the editor based on perceived performance issues, **measure**:

```
1. Add os_signpost intervals to:
   - WKWebView document load (com.epistemos.editor.doc-load)
   - Bridge transaction round-trip (com.epistemos.editor.bridge-tx)
   - Per-keystroke MainActor work (com.epistemos.editor.keystroke)

2. Run Instruments → Time Profiler over a 5-minute editing session.

3. Capture:
   - p50/p95/p99 latency per keystroke
   - Memory peak vs baseline
   - WKWebView IPC count per second under typing
   - JS heap growth over session

4. Commit results to docs/architecture/EDITOR_BENCHMARK_BASELINES.csv
```

**Decision rule**:
- If p99 typing latency > 16ms (60fps display target) AND p99 > 8ms (120fps ProMotion target): the bridge is the problem; optimize bridge first (batched transactions, throttled echo)
- If memory grows unbounded over 30-min session: there's a leak; fix the leak
- If neither: **WKWebView is not the bottleneck**. Don't rewrite. Build the moats.

Per `MASTER_FUSION.md §17.3`: **"If a feature cannot be measured, it cannot be claimed."** Your perception that there's overhead is a hypothesis, not a measurement.

---

## §6 — When to revisit this decision

Re-run this verdict when **any** of the following becomes true:

1. Benchmark harness shows Document editor typing latency consistently > 16ms p99 AND user-perceived jank confirmed by 3+ test sessions
2. Tiptap project goes inactive (no commits for 12+ months) — currently very active
3. ProseMirror replaces its core for performance reasons (would re-enable native ports)
4. macOS deprecates WKWebView (zero indication this will happen)
5. WebKit removes a critical capability you depend on

Until then: **ship the moats**.

---

## §7 — What to take from AppFlowy (the inspiration list)

If/when V1.5 typed artifact spine work resumes, study these AppFlowy patterns:

| AppFlowy concept | Where to look | What to take |
|---|---|---|
| **Block-based document model** | `frontend/rust-lib/flowy-document/` + `appflowy_editor` package | Document = ordered tree of typed blocks (paragraph / heading / list / table / code / embed). Each block has stable ID. Composes well with `.epdoc` ProseMirror JSON. |
| **CRDT collaboration** | `frontend/rust-lib/collab/` | Yrs (Rust port of Yjs) for collaborative editing. Pro feature; not V1. |
| **Slash commands** | `appflowy_editor/lib/src/render/toolbar/` | UX pattern for inserting block types via `/`. Composes with N2 Concept Door. |
| **Embed system** | `flowy-document/src/document/embeds/` | URL → typed embed dispatcher. Composes with `.epdoc` assets/. |
| **Plugin architecture** | `appflowy_plugin/` | Document handler registry. Composes with N2 typed-artifact plugin model. |

**Do NOT take**: their Flutter widget tree, their Skia rendering pipeline, their Dart code (you'd have to port to Swift). The patterns translate; the implementation does not.

---

## §8 — Sequencing impact

Updating MASTER_FUSION sequencing reflects this verdict:

```
V1 (now):       Halo + Contextual Shadows. Editor: ALREADY DONE (TextKit2 prose + Tiptap doc + native code).
                NO editor changes. ANY editor work now is a distraction.

V1.5:           N2 Concept Door + N3 Exploration Spectrum + N4 LAM + Raw Thoughts + typed artifact spine.
                Editor: study AppFlowy data model patterns; apply to .epdoc block schema if they fit.
                NO UI rewrite.

Pro:            Hermes Expert Mode + CLI providers + Docker + computer use + NightBrain + Co-op Mode.
                Editor: at this point, IF benchmarks prove a real bottleneck AND moats are stable,
                consider native Swift Document editor. Until then: leave alone.

Far-future:     If AppFlowy ever ships native macOS Cocoa version (they won't; Flutter is their bet),
                study it. Otherwise this verdict stands.
```

---

## §9 — Final recommendation

```
1. KEEP Tiptap-in-WKWebView for Documents.
2. KEEP TextKit 2 for Prose.
3. KEEP CodeEditSourceEditor for Code.
4. ADD benchmark harness BEFORE making any editor decisions.
5. STUDY AppFlowy data model patterns when V1.5 typed artifact spine work begins.
6. DO NOT port AppFlowy UI. DO NOT rewrite Document editor in native Swift. DO NOT add Flutter.
7. SHIP THE MOATS — Halo, N2, N3, N4 — BEFORE optimizing surfaces that already work.
```

The editor is not your moat. Your typed-artifact spine + provenance + Halo + four pillars + Mac-native UX is your moat. Tiptap in a properly-configured WKWebView is **good enough that touching it before V2 is bad strategy**.

---

## §9.5 — FAQ: "But Flutter renders via Skia → Metal, isn't that just as native?"

This is the most common confusion when comparing editor frameworks. The honest answer:

### "Native on macOS" does NOT mean "uses Metal under the hood"

All three options end up at Metal:

```
Tiptap-in-WKWebView  →  WebKit  →  Core Animation  →  Metal
AppFlowy (Flutter)   →  Skia    →  IOSurface     →  Metal
Native Swift (AppKit)→  AppKit  →  Core Animation  →  Metal
```

**Reaching Metal is not the bar.** "Native on macOS" specifically means **AppKit + Cocoa frameworks**. The difference between options is what's *between you and Metal*, and that's what determines how Mac-native the experience feels.

### The Mac-native ranking (counterintuitive)

```
1. AppKit (NSTextView)              100% native — it IS the platform
2. WebKit (WKWebView)                90% native — WebKit IS made by Apple, ships in every macOS, 25 years of Mac integration
3. Flutter (Dart + Skia)             60% native — Google framework, macOS is third-tier port
4. Electron (Chromium)               40% native — Chromium is foreign to Apple
```

**Tiptap-in-WKWebView is actually MORE Mac-native than AppFlowy-in-Flutter would be**, because WebKit ships in every macOS install as a first-party Apple framework with deep platform integration. Flutter is foreign on macOS — it has its own scrolling physics, its own IME handling, its own accessibility tree, its own font system, its own menu rendering.

### What "native feel" means concretely

| Concrete experience | Tiptap (WKWebView) | AppFlowy (Flutter) | Native Swift (NSTextView) |
|---|---|---|---|
| **IME** (Chinese/Japanese/Korean input) | ✅ Excellent (WebKit has 25y of this) | ⚠️ Spotty (open Flutter macOS issues) | ✅ Excellent (AppKit native) |
| **System undo** (⌘Z works across app + OS) | ❌ Own stack | ❌ Own stack | ✅ NSUndoManager |
| **VoiceOver** | ✅ Web standards mature | ⚠️ Flutter macOS accessibility gap | ✅ Auto from AppKit |
| **Trackpad scrolling feel** (rubber-band, momentum) | ✅ WebKit-tuned for Mac | ⚠️ Foreign feel | ✅ NSScrollView native |
| **Right-click menus** | ✅ NSMenu via WebKit | ⚠️ Custom-built | ✅ NSMenu native |
| **Drag-and-drop with other apps** | ✅ Via WebKit pasteboard | ⚠️ Limited | ✅ Native pasteboard |
| **System fonts + dynamic type** | ✅ Auto | ⚠️ Manual | ✅ Auto |
| **Light/Dark mode auto-adapt** | ✅ Via `prefers-color-scheme` | ⚠️ Manual | ✅ Auto |
| **Memory baseline** | ~150 MB | ~200 MB (Flutter framework + editor) | ~5-15 MB |
| **Typing latency p99** | 8-16 ms | 8-16 ms | 1-3 ms |

**Going from Tiptap-in-WKWebView to Flutter is moving DOWN the native scale, not up.** You'd lose IME quality, VoiceOver completeness, scrolling feel, system undo integration — to gain Skia rendering, which already happens at the Metal layer either way.

### Is Tiptap functionally better than AppFlowy's editor?

For pure rich-text editing: **yes, Tiptap wins**. Built on ProseMirror — 3+ years of battle-tested edge-case fixes, massive plugin ecosystem (tables / images / code blocks / math via KaTeX / embeds / mentions / slash commands / collaborative cursors / footnotes / callouts / drag-handles).

AppFlowy's editor is decent but only ~2 years old. **Their actual edge is database views** — Notion-style tables that act like databases (filter, sort, group, kanban, calendar). Tiptap doesn't have those out of the box.

**But database views aren't an editor problem — they're a typed-artifact problem.** In Epistemos's framing, a database view is a different `ArtifactKind` (or a different rendering of `Document` with `view_mode: database`). You build that on top of Tiptap as custom blocks, or as a totally separate surface that doesn't share the editor at all (which is what Notion does — their database is NOT their editor).

**For the editor**: Tiptap wins. **For database views**: separate feature, build later as part of typed-artifact spine.

### "But I want native Metal rendering for performance"

If the appeal is **performance** (smoother scrolling, faster paint):
- WKWebView already paints via Metal under the hood
- The bottleneck is almost never paint — it's bridge IPC and JS execution
- **Optimize the bridge before the paint pipeline**

If the appeal is **direct GPU control** (custom shaders, MSDF font atlases, particle effects):
- Skia/Flutter gives you more control than WKWebView's content
- **But so does AppKit** — embed `MTKView` / `CAMetalLayer` exactly where you want
- You don't need Flutter for Metal access; you need an `MTKView` placed in your AppKit hierarchy

If the appeal is **smaller memory footprint**:
- Native Swift (NSTextView, no WKWebView, no Flutter framework) wins: ~5-15 MB vs ~150 MB
- **But only worth pursuing AFTER benchmarks prove memory is a real bottleneck on real vaults**
- A 16 GB Mac doesn't notice 150 MB. Your moats need that 6-month dev budget more than your editor needs that 135 MB.

### The sharpened recommendation

```
Prose editor:    KEEP NSTextView (TextKit 2).
                 Native AppKit. Best possible. Already shipped.

Document editor: KEEP Tiptap-in-WKWebView.
                 WebKit IS Apple. More Mac-native than Flutter.
                 Tiptap > AppFlowy editor for rich text.
                 Pre-warmed shared WKProcessPool + transaction-summary bridge per workspace_gpt_workspace_synthesis.md.

Code editor:     KEEP CodeEditSourceEditor + SwiftTreeSitter.
                 Already settled per workspace_epistemos_code_verdict.

If you want database views (AppFlowy's actual edge):
                 → Build as separate ArtifactKind / surface, NOT by replacing editor.
                 → Take inspiration from AppFlowy's data model (block IDs, embed dispatch, slash commands).

Going to Flutter:
                 → Loses IME quality + VoiceOver + scrolling feel + system undo + trackpad gestures.
                 → Gains nothing your moats need.
                 → DON'T.
```

---

## §10 — Provenance log

| Date | Author | Action |
|---|---|---|
| 2026-04-27 | consolidation pass (Cowork) | User asked: should Epistemos port/inspire-from/rewrite/leave-alone the rich editor vs AppFlowy? Authored honest assessment. Verdict: leave Tiptap-in-WKWebView alone for V1.5; benchmark before any editor work; study AppFlowy data model patterns when typed artifact spine resumes; do NOT port their UI (Flutter). Cross-referenced from MASTER_FUSION §6.4 + workspace_epistemos_code_verdict + workspace_gpt_workspace_synthesis. |

---

**END OF EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md**

> **TL;DR**: WKWebView overhead is real but bounded. Tiptap is the gold standard for block WYSIWYG. AppFlowy's editor is good but Flutter-based — porting it gets you nothing your moats need. **Leave Tiptap alone. Ship the moats. Benchmark before optimizing. Take AppFlowy's data model patterns, not their UI layer.**
