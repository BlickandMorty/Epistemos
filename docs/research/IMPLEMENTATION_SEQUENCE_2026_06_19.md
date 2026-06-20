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
