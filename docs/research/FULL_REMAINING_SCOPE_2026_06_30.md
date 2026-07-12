# FULL REMAINING SCOPE — Plans 1 / 2 / 3 (2026-06-30)

> 🟡 **PARTIAL-SUPERSEDE 2026-07-02 (OpenChamber pivot).** The Plan-2/3 scope items (editor, capabilities) are largely still valid; the Plan-1 scope (reskin Goose / Goose-as-surface / Option 1 / MAS-as-reskinned-goose-webview) is DEAD. Current: Current surfaces = Experimental/1Code + MAS/June; OpenChamber/ProAgent are deletion targets; MAS = June + goose IN-PROCESS backend; goose = one engine. Editors = simplify not Tolaria-rival; arXiv/Obscura kept dedicated. Canon: memory `project_ui_base_pivot_openchamber_2026_07_02` + `project_product_shape_agent_center_2026_07_02`.

> No-compromise inventory of EVERYTHING left across the three build plans — **including the MAS in-process backend +
> frontend and all deferred/gated items.** Compiled by reading the actual plan docs + canonical codepacks (not memory).
> Status tags: ✅ done · 🔨 in-progress · ⬜ not-started · ⏸ deferred (in-scope, sequenced later) · 🔒 Pro-gated · ⛔ cut/forbidden.

## At-a-glance — how "done" each really is
- **Plan 1 (Goose):** EARLIEST — Phase 1 of 5. Committing real reskin polish daily, but the native frame, the full reskin
  system, the MAS backend, and Phase 0 closeout are mostly ⬜. ~90 items.
- **Plan 2 (Editor / HTML-Workspace):** MIDDLE — a big chunk is *built-but-unproven* (the 5 HTML caps) and the **MarkEdit
  full-clone is largely ⬜**. The lens model + L1 markdown-truth flip are ⬜. ~80 items.
- **Plan 3 (Capabilities):** MOST COMPLETE — the entire 6-item build order is ✅. What's left = edge-hardening + a short
  ⏸ deferred list. This is the plan closest to truly done.

---

## PLAN 1 — GOOSE SURFACE

### ✅ Done / committing now
- Phase 0 ~96% (ACP transport, web-UI staging, boot-shim core affordances, read-only ACP minimum, golden fixtures F1–F5).
- §7 green-lit; Option 1 locked (native FRAME only; chat stays reskinned WebView; route-migration stops after Models).
- Daily reskin/native-frame polish commits (token retheme, settings/recipe/form surfaces).

### ⬜ Phase 0 closeout (not signed off)
- Real-`goose serve` integration test (not just the in-memory transport); kill stale :3284 orphans + document lifecycle.
- **Live catalog-parity test** (GOLDEN RULE): provider/model/skill inventory enumerated ONLY via ACP, digest-compared to real Goose; CI grep gate = no hardcoded rosters in `Epistemos/Goose/**`.
- Prove the **production web-UI chat path** end-to-end (not only the Swift test client); live tests must fail loud when the binary is absent.
- Long-tail boot-shim affordances (21 deferred keys) implemented natively OR shown as honest blocked UI.
- OAuth `authenticate` success path; Phase-0 sign-off doc.

### ⬜ Phase 1–3 — the native FRAME (Option 1; NO native chat)
- ACP codegen (`GooseACPExt*.swift` from acp-meta) + `GooseACPExtClient` actor + unstable notification/recipe handling.
- `AgentSurfaceWindowController` + `AgentSurfaceRootView` + hybrid content router (native for hub/session/settings, embedded reskinned WebView for the long tail).
- Phase 2: landing tile + ⌘⇧A (draft-only) + native cwd picker + diagnostics row; `AgentNavigationRailView` (8 destinations + recent sessions, rename/archive/streaming badges); `AgentSettingsView` (Models/Chat/Auth/App) + provider config via ACP + Keychain secrets.
- Phase 3: per-route native gates (flip `useWebViewFor*`→false only when ACP+fixtures+WRV pass); **`epistemos.context.snapshot` bridge** (attach vault notes / graph selection to the composer).
- ⛔ Phase 4 "native chat default" = DELETED (Option 1 — chat stays WebView permanently).

### ⬜ Full reskin + TOTAL theme-awareness (R7–R11 — ongoing alongside phases)
- R7 token retheme of Goose's `theme-tokens.ts` + `main.css` (SF Pro, #0066cc, radius scale) to the Apple tokens.
- R8 per-component macOS CSS (switch, segmented control, select/dropdown) tuned to the verified springs.
- R9 **A/B pixel-diff harness** (WKWebView snapshot vs SwiftUI ImageRenderer, ≤~2% gate) — every component flips to VERIFIED only when it passes.
- R10 cross-surface token unification (EpistemosTheme.swift → editor web bodies too — shared with Plan 2).
- R11 global macOS details (native overlay scrollbars, accent focus ring).
- Transparent-over-real-glass everywhere; SF Symbols native-chrome-only; total theme-awareness incl. the **custom palette** (currently doesn't propagate everywhere = a bug to fix).

### ⏸ MAS IN-PROCESS BACKEND + FRONTEND (in scope; sequenced AFTER the visible Phase-1 work — the thing you asked about)
- **Keep the reskinned Goose WebUI frontend**; swap its backend transport: `goose serve` subprocess → **in-process ACP over `agent_core` (Rust, via FFI)**, behind `EPISTEMOS_APP_STORE`.
- **Bounded MAS toolset** (sandbox-legal): vault read/write (security-scoped bookmarks), network/HTTP MCP, cloud APIs, in-app capabilities (PDF/search/etc).
- **Honest Pro-gate** (never silent-drop) for the sandbox-illegal bits: the `developer`/shell builtin, install-deps, local stdio (process-spawning) MCP, the goose-serve subprocess.
- Result: ONE WebUI, TWO backends behind the flag — Pro = subprocess (full shell/autonomy), MAS = in-process agent_core (bounded). The agentic loop already exists in agent_core; this is the **ACP-over-FFI adapter + the tool-boundary split**, not a native-Swift reimplementation. **This is the only way Goose ships on the App Store.**

### ⏸ White-screen robustness (FINAL hardening pass — it renders now)
- Atomic, hash-gated UI staging (copy index.html + assets as one unit; flip served-root only after verify).
- `GooseWebUIResolver` verifies every referenced `<script src>`/`<link href>` resolves (reject + fall through if missing).
- Re-derive staging from the current bundle on launch; clear stale staged dirs.
- ACP handshake: token↔`GOOSE_SERVER__SECRET_KEY` parity + decouple SPA-load from `acpBridge==.connected`.

### ⏸ Phase 5 — Paseo strategic fusion (later)
- Engine picker (ACP family), multi-tab/split workspace, inline diff + gh PR/merge, worktree-isolated parallel runs.

---

## PLAN 2 — EDITOR / HTML-WORKSPACE

### 🔨 / ✅ Built (partially)
- Three-lens model locked in canon (Note=Epdoc / Source=MarkEdit / Prose=TK2).
- Note-width binary toggle (720/none) built; Epdoc Tolaria-style chrome in progress.
- Old code editor kept as v1-legacy artifact; caret-anchored panels (slash/bubble/KaTeX) native-positioned.

### ⚠️ BUILT-BUT-UNPROVEN — must prove in a cold-launched app before claiming done (do NOT trust the isLive:true flags)
- Full-surface **REGENERATE** (chat rewrites the whole HTML surface, atomic/versioned/reversible + streaming).
- App **message-bridge** (the empty `didReceive` handler).
- JS **console/error capture** bridge.
- **DOM picker / style inspector** (live evaluateJavaScript, not static outline).
- **Python (Pyodide/WASM)** in-WKWebView runtime.
- → All 12 HTML-Workspace caps are flagged `isLive:true` but were uncommitted/unverified; each needs in-app proof.

### ⬜ Priority-0 fixes
- Dark/light toggle crash (guard `evaluateJavaScript` mid-load; don't recreate WebView on colorScheme change) + in-app crash recorder → `<vault>/.epcache/diagnostics/`.
- Blank code editor: root-cause the CoreEditor bundle RUNTIME load (chunk-loader scheme handler + message bridge); prove a .swift file renders highlighted.
- Wire/verify the MarkEdit **Source lens route** (`.markdownChrome`) so `.md` can open in Source without regressing default Note/Prose.
- Visual fidelity: inherit MarkEdit's FontPicker default size + lineHeight verbatim; match insets/window size; side-by-side vs MarkEdit.app.

### ⬜ MarkEdit FULL CLONE ("settings and all", 100% capability) — largely not started, blocks all code-editor work
- Deterministic clone script → `LocalPackages/MarkEdit/`; delete only the 4 un-coexistable shell items (@main/AppDelegate, AppDocumentController, .xcodeproj, 2 .appex) — every dropped item maps to an Epistemos equivalent or is a stated loss.
- Harvest into Epistemos: launch setup → AppBootstrap; doc-types/UTIs → EpistemosDocumentController; build settings/Info.plist/**MAS-safe entitlements** → project.yml (reject MarkEdit's MAS-hostile keys).
- Vendor all 11 modules + add the 3 missing (FileDrop, Previewer, TextBundle); decide Scripting/Shortcuts (vendor or explicitly drop).
- `MarkEditCodeEditorRepresentable` mount seam + `build-coreeditor-bundle.sh` (lock-hash gated) + chunk-loader scheme handler + strip the SwiftLint plugin from vendored Package.swift.
- **Full MarkEdit Settings UI user-reachable** (not embedded-but-inert) — prove all controls functional.
- Completeness gate test: HTMLWorkspace source panes use `MarkEditCodeEditorRepresentable`, never `HTMLWorkspaceCodeEditor(`/`TextEditor(`.

### ⬜ L3-CHROME (code chrome reimplemented on the MarkEdit engine)
- MD lens → MarkEdit chrome verbatim; CODE lens → v1 minimal look reimplemented (nested-box, title, **real per-language file-type logos** not `</>`, Epistemos theme-aware).
- Graft the v1 critical buttons into code chrome: Live-Preview (HTMLWorkspacePreviewView), LSP-hover (CodeEditorSemanticLSP), Outline navigator.

### ⬜ Lens model wiring + L1 markdown-as-truth + data-loss guardrails
- Note↔Source↔Prose toggle routes + Source→Prose affordance; code = Source only.
- **L1 staged flip** (jsonOnly→dualWrite→markdownCanonical, falsifier-gated); JS `getMarkdown()` full-fidelity bridge = the canonical writer; Goose `edit_note` points at the L1 writer.
- 4 guardrails: getMarkdown-only writer · preserve-unknown passthrough · write-only-on-real-edit · round-trip-fails-loud test.

### ⬜ Build-sequence stages (S/M sizes)
- Ontology core (NoteOntologyParser, ViewDefinition/Compiler/Evaluator, TypeRegistry, incremental crawl); Cmd+K command palette + caretChanged.marks read-back; Note AI-diff (prosemirror-changeset + suggest-changes); Views + type registry; Goose note-context plumbing (ActiveEpdocTracker + NoteContextProvider → context snapshot; **no separate native chat** — Plan 1 owns Goose).
- Recovered surfaces: graph inline-edit, home-graph tunnel, Prose image render+persist (2 data-loss fixes), instant-recall/Halo popup, web clipper (unspecced), **PDF viewer (PDFKit)** — Plan 2 owns the viewer, Plan 3 owns parse+storage.
- Grammar: Obsidian/GFM callouts/fences/wikilinks; pin `@tiptap/markdown@3.24.0` (P0: verify it resolves on npm).

### ⏸ Deferred / ⛔ forbidden
- ⏸ brotli-unify scheme (later opt), 2 .appex Finder bits (MAS v1 loss), web clipper design, Prose image work.
- ⛔ Delete the old code editor (KEEP as v1-legacy); Tolaria/BlockNote-xl/Vrite code (AGPL/GPL — clean-room only).

---

## PLAN 3 — CAPABILITIES  (the most complete plan)

### ✅ Done — the entire 6-item build order
1. **PDF→md**: EdgeParse (Apache-2.0) + unpdf (MIT) vendored, MAS-default Cargo features, FFI envelope preserved, source_pdf coexistence, hardened inputs, tests. (liteparse stays 🔒 Pro.)
2. **Provenance moat**: honest `VRMLabel.honestLabel` gate (no "Verified" without a real anchored claim), hover-lineage card, edit-supersession trace (EventStore-derived), copy-lineage JSON, hardened AnswerPacketStore. Rust ClaimLedger read-only.
3. **Extensibility**: skill/MCP install UI (registry browse + URL-MCP install, no token values written), best-of preset (idempotent+reversible, honest Pro-gating), **vault-as-MCP-server** (read-only enforced at core, Keychain token, OFF by default).
4. **Apple-native**: QuickLook preview + VisionKit Live Text + QuickLook thumbnails (hardened file policies); **landing feature buttons** (one per capability, honest Pro pills); **arXiv pull** (search + ingest + frontmatter, hardened temp-file + magic-byte, tests). arXiv PRIORITY-0 temp-file bug ✅ fixed.
5. **Browser**: lite native WKWebView tab (MAS-safe, human-driven, ⌘⇧B) ✅; **browser-use Pro** 🔒 (vendored core 0.13.2 + Gradio web-ui in WKWebView + Chromium payload + signed-bundle gate + the subordinate browser-scoped sub-agent + hardened Rust browser tools) — extensively built + tested.
6. **Meeting/STT note** ✅ (on-device Apple SpeechAnalyzer, macOS 26), **Voice** 🔨 (Apple-native STT live; TTS is Kokoro-only and honestly unavailable until native synthesis is wired; no AVSpeech fallback), **whole-app brand logos** ✅ (registry + honest fallbacks, no fakes, model logos untouched).

### ⬜ Left — edge-hardening (the plan's "work mode" = deep review, few tests)
- PDF→md edge cases: encrypted / 0-byte / scanned / multi-column through EdgeParse + unpdf.
- Re-verify: provenance honest-gate (no fake Verified), vault-MCP read-only enforcement, browser-use Pro honest-gating + signed-bundle verification (no MAS leakage), full-clone completeness (EdgeParse/unpdf feature sets + browser-use settings-and-all).

### ⏸ Deferred (owner-blocked or phase-gated)
- ClaimLedger **full BFS retraction cascade** — needs owner sign-off + new Rust write FFI (`record_claim_json`/`retract_claim_json`).
- **Kokoro TTS** — native no-Python synthesis engine + model packaging/download (status-gated `isReady=false` until wired).
- Scanned/**OCR lane** for PDF→md (future Apple Vision/PDFKit).
- browser-use **release notarization** (distribution ops, not a runtime gate).
- Later logo slices (utility-panel metadata + optional licensed assets).

### ⛔ Cut (no build)
- Obscura native automation engine (→ browser-use Chromium; WebKitBrowserEngine stays NotConfigured), ColBERT, local model-management (BYOM/stack/vision), three-engine Chat/Act/Work + Osaurus (Goose-only; browser-use is the only subordinate exception), DeerFlow.

---

## The honest bottom line
- **Plan 3** is essentially feature-complete; it just needs edge-hardening + the short deferred list. Closest to done.
- **Plan 2** has built a lot but much is *unproven*, and the **MarkEdit full-clone** (the spine of the code/source editor) is largely unstarted — that's the biggest real chunk.
- **Plan 1** is the furthest from done — it's at Phase 1 of 5, and the **MAS in-process backend + frontend** (your App-Store path) is a large deferred workstream on top of the native frame + full reskin.
- **MAS:** the in-process backend is Plan 1's, in-scope, deliberately sequenced *after* the visible Goose surface is finished (not abandoned).
