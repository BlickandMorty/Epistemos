# IMPLEMENTATION SEQUENCE — top ready-to-code wins across all slices (2026-06-19)

Capstone over the completed research backlog (SS-A … SS-Z + SS-AA/AB + the ledger). All slices are researched
with file:line plans; this orders the **highest-leverage, lowest-risk [S] quick-wins** so the build loop codes
the biggest wins first. Authority = `OWNER_REQUESTS_LEDGER_2026_06_18.md`; details = each `SS-*` doc. Governing:
work-in-app (flag-OFF≠done), simplify-not-hide, honest/no-fake, main-only, test-at-end.

## TIER 0 — the #1 owner blocker: models actually install + run (IN PROGRESS by the loop)
1. **GGUF chat-template crash fix** — SS-W/SS-Z/SS-AB. ✅ landed: `9edd41d12` (classify llama-cli SIGABRT),
   `842286538` (per-model `--chat-template` seam). **Remaining [S]:** per-model chatml fallback + always pass
   `--chat-template-file`; per-model `contextWindow` across FFI (replace hardcoded `4096`, `gguf_cli.rs:32`);
   per-model `stop` array. (SS-Z/SS-AA/SS-AB.)
2. **Model install UNMISSABLE** — SS-G. ✅ landed: `a1dd7c6ed` (in-picker "Install local AI" CTA). **Remaining
   [S]:** per-row Install on `ModelStackSettingsView` for the named GGUF models (Gemma/LFM2/VibeThinker) wired to
   `install(modelID:)` + `presentationState` + progress.
3. **Onboarding "it just works"** — SS-C/SS-E. **[S]:** wire `installEpistemosFoundationPackage()` into the
   wizard model step (`SetupAssistantView.swift:191-205`) + default the vault to `FirstRunBootstrap.defaultVaultURL()`
   (`~/Documents/Epistemos`, revive the dead code). Two tiny edits = a cold-start user reaches a working app.
4. **Per-model picker descriptions** — SS-AB. **[S/M]:** every model gets `pickerUseCase` (short use-case copy) +
   `benefitsDescription`; best models advertised; all installable. Honest, no-fake.

## TIER 1 — visible wins + honesty fixes (small, high-owner-visibility)
5. **Chat message-bar de-muddify** — SS-X. **[S]:** drop `preferSplitToolbarControls:true` at `ChatInputBar
   .swift:967` (removes the legacy Think/Code/Tools/Effort/Native row; the flat trigger already covers it) + add
   `.onDisappear { recallDebounceBox.task?.cancel() }` (teardown leak). One line each.
6. **Dark/light crash** — SS-U. **[S]:** drop `workspaceThemeIdentity.hashValue` from `HTMLWorkspaceEditorView
   .swift:617` `.id` + push theme via `updateNSView` (stop destroying+rebuilding the WKWebView on every toggle).
   Removes the verified crash root.
7. **Settings honesty** — SS-F. **[S]:** fix `summaryInterval` default drift (settings 15m vs service 5m,
   `WorkspaceSummaryService.swift:24`); demote the fake `EPISTEMOS_GRAPH_INDEX_CHATS` toggle (zero readers) to a
   disabled "reserved" row; convert the 3 raw-`@State` General settings to `@AppStorage`.
8. **Settings de-dup** — SS-D. **[S]:** remove the duplicate Night Brain toggle (`ModelVaultsSettingsView.swift
   :153-157`; keep Cognitive `:42`); fold General diagnostics into the one `SubstrateHealthPanel`.
9. **Voice premium-default fix** — SS-K. **[S]:** fix `preferredVoice()` (`EpistemosSpeechSynthesizer.swift:227`)
   to scan `speechVoices()` for highest quality instead of the macOS-26-regressing `(language:)` path; pass a
   `voiceIdentifier` from `MessageBubble` so chat read-aloud honors it.

## TIER 2 — the local>cloud + skills-everywhere thesis (medium, flagship)
10. **Wire the vendored masked logit processor** — SS-Y. **[S]:** the project already vendors
    `GrammarMaskedLogitProcessor` (real hard masking) that NO product code imports; wire it into the live MLX
    generator + flip `isFullyConstraining=true` → guaranteed-valid local tool calls (the core of local>cloud).
11. **Skills keystone** — SS-H. **[S]:** inject the ChatLite skills catalog into local chat even when
    `shouldUseToolLoop==false` (`PipelineService.swift:316-388`) so small local models at least SEE skills; then
    route tool-needing queries to a fitting agent-capable model (no tool-less degrade).
12. **De-orphan the HyperdynamicLoop** — SS-Y/SS-F. **[S/M]:** connect `HyperdynamicLoopMetrics.ingest` to a
    `LoopCounters` snapshot (health row stops saying "no read yet"); route the local loop's repairs through the
    bounded `gate_*_through_loop` runner.
13. **ModelCapabilityProfile registry** — SS-AB/SS-AA. **[S/M]:** one bundled JSON (Ollama+LiteLLM+Aider shape);
    seed cloud from LiteLLM data; `llguidance` (dep already added) as the single grammar engine GGUF+MLX.

## TIER 3 — native features (each independently shippable; chat-first per the constraint)
14. **PDF live viewer** — SS-T. **[S]:** `PDFView` `NSViewRepresentable` (thumbnails/outline/find) mounted from
    the file/import rows; reuse `PDFDocument(url:)`. + QuickLook universal preview [S].
15. **Voice bitcrush + Personal Voice** — SS-Q. **[S]:** extract shared `BitcrushKernel` from `Ambient
    FrequencyLivePlayer.swift:687-702` + `VoiceEffect` enum; add `requestPersonalVoiceAuthorization` + picker
    group.
16. **Browser-use MAS-safe** — SS-J/SS-M. **[M]:** implement `WebKitBrowserEngine` (in-process WKWebView DOM
    read + synthetic events) to replace the foreign `agent-browser` CLI; `WKContentRuleList` tracker-block [S].
17. **Sensitive-info redaction** — SS-N. **[S]:** wire the existing NLTagger NER + NSDataDetector into a shared
    `SensitiveInfoRedactor` + a flagged pre-egress hook at `claude.rs:284` (+openai/gemini).
18. **Epdoc rich-UI (Tolaria look, graft-not-clone)** — SS-O/SS-P. **[S prereq]:** land SS-O roots #2/#3 (surface
    JS errors + ready-handshake) FIRST; then Tiptap Notion-template + DragHandle [S]; pixel/macOS-26 skin via the
    existing CSS injector [S].

## TIER 4 — discipline + hardening (standing, each cycle)
19. **Vuln gate before add** — SS-S/SS-V. **[S]:** flip MAS tool gating to fail-closed allowlist (M1,
    `registry.rs:59`); wire clippy `-D unwrap_used -D undocumented_unsafe_blocks` + cargo-audit/cargo-deny +
    semgrep; run the adversarial "thermo-nuclear" review (SS-V) at phase checkpoints.
20. **Tests at end** — every feature gets `cargo test --lib` (real) + reasoned Swift-Testing + a falsifier (e.g.
    no GGUF model reaches `common_chat_templates_apply` with an empty template). No green-without-witness.

## Sequencing logic
- TIER 0 first (the loop is already here) — it's the most-repeated owner concern (models install + run).
- TIER 1 is all 1-line/small honesty+visible-win fixes — knock them out in a batch (logos✅ already shipped).
- TIER 2 is the flagship "local>cloud" thesis — high value, mostly wiring code that already exists (vendored
  masked processor, llguidance dep, HyperdynamicLoop engine).
- TIER 3 features are independent — pick by owner priority; chat-first, Act/Work only non-clashing (constraint).
- TIER 4 runs as a gate around every tier (repair-before-add, test-at-end).
- **Living-Index / Lattice stays sequenced ABSOLUTELY LAST** (owner directive — indefinite research).

Each item links to its `SS-*` doc for the full file:line plan. The research is done + hardened; this is the
order to code it. Cross-ref `SESSION_COVERAGE_MATRIX_2026_06_19.md` (every concern → slice → status).

---

## ▶ READINESS VERIFICATION + TOP-UNCODED (owner 2026-06-20 — "code while I sleep")
**All research is captured + ready to convert to code:** 36 research slices (SS-A…SS-Z + AA/AB/LI/EM/PERF/SH/AL/
UMA/IR/FM) + 2 capstones (this file + EPDOC_MD_V2_BUILD_SEQUENCE) + SESSION_COVERAGE_MATRIX, all committed to main,
cross-linked in the hub + the loop-plan read-first banner. Every owner concern (incl. pre-compaction verbatim
intent) is mapped to a ledger item + slice + file:line plan. Nothing research-only is left dangling.

**SHIPPED this session (verified real + test-backed, each cites its slice):** logos (×2); gguf crash fix SS-W (×2:
9edd41d12, 842286538); ModelCapabilityProfile + GGUF wiring SS-AB/Z (40b32bb22, 03bd5c4a7); SS-X chat-bar
(1d596891a); SS-U dark/light crash (749d2c889); SS-F settings honesty (3b214c1dd). The model-run crash (the #1
blocker root) is fixed end-to-end.

**SHIPPED in the 2026-06-20 overnight /loop (8 slices, each cargo/xcodebuild-gated + committed + pushed to
main):** substrate-health panel FFI freeze fix completed across ALL health rows (off-MainActor polling; SS-SH —
`f983a1d92`/`3dba72114`/`a7d89767e`); cloud-profiles-in-picker FFI + the `ModelCapabilityProfile` CLOUD_CANON
half + a single `resolve_profile` local+cloud resolver (SS-AB — `e279bfad2`); local repair-token streaming, killing
the masked `{ _ in }` decode (SS-AL #1 — `f26924ccf`); the Gemma-4-12B-general vs 12B-Coder profile split, fixing a
real mislabel (SS-AB — `2b2f8321b`); per-model context-window resolver + FFI + picker badge (SS-AB —
`251f371d8`/`6f1b78aad`); cloud-provider use-case line surfaced in Settings, wiring the previously-dead cloud
resolver branch (SS-AB — `7b5dd8eb4`); SS-W GGUF-template + family-dialect invariant guards (`9485ad7a8`). The
picker/profile/cloud arc is now COMPLETE + hardened with one Rust source of truth. DEFERRED to owner-awake (need a
Pro build / are too large to verify unattended): #6 SS-Y masked logit (real grammar masking), #7c LoRA-apply
keystone (Pro-gated `#if !EPISTEMOS_APP_STORE` — MAS build can't verify), claude.rs mid-stream retry + cancellation
(needs trait-wide token threading).

**TOP UNCODED — do these next (highest owner value, all researched with file:line):**
1. **Model-install PER-ROW Install button** (SS-G) — `ModelStackSettingsView` per-row Install wired to
   `install(modelID:)` + `presentationState` + progress, so the named GGUF models (Gemma/LFM2/VibeThinker) install
   individually. **The #1 owner blocker remnant** (the in-picker CTA landed `a1dd7c6ed`; the stack rows still
   can't install). [S]
2. **Substrate-health glitch fix** (SS-SH/PERF #1) — collapse the ~15 per-row 1Hz synchronous-FFI-on-MainActor
   timers into ONE shared `TimelineView` clock fetching OFF the MainActor. Fixes the owner's "glitched/not working"
   panel AND the biggest perf win, one change. [M]
3. **Onboarding "it just works"** (SS-C/E) — wire `installEpistemosFoundationPackage()` into the wizard model step
   + default the vault to `FirstRunBootstrap.defaultVaultURL()` (revive the dead code). [S]
4. **Skills keystone** (SS-H) — inject the ChatLite skills catalog into local chat even when
   `shouldUseToolLoop==false` (`PipelineService.swift:316`) + route tool-needing queries to a fitting agent-capable
   model. The #2 owner priority. [S]
5. **Per-model picker descriptions** (SS-AB) — `pickerUseCase` + `benefitsDescription` per model on the picker. [S]
6. **Wire the vendored masked logit processor** (SS-Y) — `GrammarMaskedLogitProcessor` into the live MLX generator
   (guaranteed-valid local tool calls = local>cloud). [S]
7. **Stream local repair tokens** (SS-AL #1) — pass real `onToken` into the repair generators (kill the masked
   `{ _ in }` decode). [S]
7b. **ALL-MODELS profile update + harden** (SS-AB/SS-Z/SS-R/SS-AA; owner 2026-06-20) — extend the shipped
   `ModelCapabilityProfile` so EVERY local AND cloud model has a CURRENT + HARDENED profile (correct ctx/template/
   dialect/sampling/stop/tier/skills + benefitsDescription + pickerUseCase); cloud half seeded from LiteLLM's
   capability table (bundled offline, MAS-safe); validated, honest/no-fake, with tests. The profile is shipped +
   wired into GGUF (40b32bb22/03bd5c4a7); COMPLETE the all-model coverage. [M]
7c. **MLX-LoRA-Studio embed + fuse** (SS-LS; owner 2026-06-20) — graft the MIT Swift fine-tuning STUDIO onto
    Epistemos's EXISTING native `NativeLoRATrainer`/`LoRATrain` engine (NO Python sidecar — MAS/NO-HIDDEN-SIDECAR);
    fuse the existing `KnowledgeFusion` pipeline in (delete nothing). **Keystone first = close the apply gap:**
    `NativeAdapterApply.apply` is an ORPHAN — wire it into `MLXInferenceService.loadContainerIfNeeded:1942-2003` so
    a trained+active adapter actually changes live tokens (the owner's literal "use the models right after they're
    done"). Then fuse-to-ModelVault (`LoRAContainer.fuse`→`Models/text/active`→`AdvertisedModelStore`) + rescan;
    repair the `adapters.safetensors`↔`adapter_weights.safetensors` filename mismatch + migrate `KTOTrainer` off
    `/usr/bin/python3`; then graft the studio UI (live metrics dashboard / runs archive / algorithm guide /
    ResourceGuard) + port net-new algos (DPO/ORPO/GRPO/full-FT/QLoRA/QAT) natively. Order [S→M] in SS-LS. [S→L]
7d. **Homepage transition animation repair** (SS-AN; owner 2026-06-20, HIGH-PRIORITY REPAIR — slot EARLY) — the
    home/landing->graph/"learning" transition SQUISHES/FOLDS/flickers. Root = `.scale(0.94)` transition on both
    branches (`LandingView.swift:367-375`) + double-fire spring (`EpistemosApp.swift:1137` vs `LandingView.swift:459`)
    + racing AppKit alpha fade + 420ms pop-in gate (`HomeGraphEmbeddedView.swift:350-358,404-420`). Fix = delete the
    `.scale`, kill the double-fire, Apple blur-replace (buttons blur away, graph blur-reappears) on one fast
    `.easeOut(0.28)`, drop pop-in/AppKit race. Visual witness PENDING OWNER. [S] each step.
7e. **Adapter UX + agent revamp** (SS-AD; builds on SS-LS apply-gap) — Settings: select adapter -> apply to chat
    (safer; already wired) or to a model (new `modelID->adapterID` map); per-AGENT adapter (Companions already carry
    `CompanionModel.loraAdapterPath` but it's DEAD — wire it into `applyActiveAdapterIfPresent`); adapter explanations
    (`AdapterRecord.description` + parse `adapter_config.json`); test-adapter A/B split-compare. Default adapter type
    = DoRA-on-quantized kept-separate (SS-XR). [S->M]
7f. **Cohesive fluid "feel-alive" animations** (SS-ALIVE; owner 2026-06-20) — apply the SS-AN BlurFade house style to
    the REPEATED `.scale`-fold sites (HomeRouter Landing↔Chat `RootView.swift:2616`, 7 LandingView overlays,
    CompanionView/PhysicsModifiers/ChatSidebar origin-pops) + add `.contentTransition(.numericText())`, `.symbolEffect`
    for conceptual spinners, Settings detail cross-fade, `.scrollTransition` list fade-in, broaden NativeButtonStyles/
    Liquid Glass; flagship `matchedGeometryEffect` (graph node→inspector) LAST + flagged. All reduceMotion-gated,
    additive, never over Metal canvas; visual feel PENDING OWNER. Tier S→L in SS-ALIVE. [S→L]
7g. **Remaining perf wins** (SS-PERF2; standing each cycle) — top: compact tool-schema JSON in the LLM prompt
    (`ChatCoordinator.swift:3499`, fewer input tokens/turn), shared JSON coders on `SDMessage`, memoize RawThoughts
    grouping, off-main settings reads, timer focus-gating. All non-invasive; #6 (MessageBubble Equatable) last + behind
    a focused test. [S]
8. Then the editor cluster per `EPDOC_MD_V2_BUILD_SEQUENCE` + the remaining native features (PDF/voice/browser/
   redaction) + the instant-recall popup redesign (SS-IR) + the perf/vuln gates each cycle.

**HARDENING DISCIPLINE each cycle (owner standing):** perf research before + after each feature; the thermo-nuclear
(SS-V) + vuln-gate (SS-S) at checkpoints; tests at the end (the loop is already writing a test per fix — keep it);
honest/no-fake/no-green-without-witness; main-only commit+push; never touch vault/graph; TK2/Prose non-invasive
only. The only thing left is build time.
