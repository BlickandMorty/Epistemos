# V1 Ship Gate Decision

Date: 2026-04-25
Decision authority for V1 (Mac App Store first). Synthesizes all audit findings.

## Ship-gate table

| Feature | Current state | Ship V1? | Hide? | Remove? | Direct build only? | Reason |
|---|---|---|---|---|---|---|
| Prose Editor (TextKit 2) | WIRED stable | YES | — | — | — | Core; protected by canon |
| Code Editor (CodeEditSourceEditor + Binding) | PARTIAL — fluid <100KB, untested at 4k+ lines | YES with caveat | — | — | — | Add 4k-line bench gate before final ship |
| Documents (.epdoc / Tiptap WKWebView) | ABSENT | NO | YES (no UI entry) | — | — | DEFER to V1.5; canon-listed but unbuilt |
| Chat (Fast/Thinking/Pro/Agent) | WIRED, BUT Pro+Cloud has zero tools | YES with FIX | — | — | — | Fix `PipelineService.shouldUseToolLoop` `:313-314` to route Pro+cloud through Rust agent loop |
| Streaming pipeline (`bufferingNewest(256)`) | WIRED stable | YES | — | — | — | Verified across 10 AsyncStream sites |
| Agent runtime (`agent_loop.rs` multi-turn) | WIRED stable | YES | — | — | — | Real loop; thinking blocks preserved |
| Raw Thoughts artifact persistence | SCAFFOLD | YES (V0 behind flag) | — | — | — | Wire under `EPISTEMOS_RAW_THOUGHTS_V0`; default-on if size budget passes |
| Contextual Shadows (Ambient Recall UI) | ABSENT (substrate WIRED) | YES (V0 behind flag) | — | — | — | Wire per AMBIENT_RECALL_WIRING_PLAN; default-on in TestFlight first |
| Instant Recall HNSW substrate | WIRED | YES | — | — | — | Fast path proven; force async rebuild |
| MCP bridge | WIRED | YES (subset) | — | — | — | MAS includes only safe tools (vault_read/write/search) |
| Computer use stack (Omega + omega-ax) | WIRED Pro / Stubbed MAS | YES (Pro), STUB (MAS) | — | — | YES (Pro) | Correctly gated by post-build scrub |
| Vault sync + bookmarks | WIRED | YES | — | — | — | S.4 hardening landed |
| Search index (FTS5) | WIRED | YES | — | — | — | Solid |
| Knowledge Core staged runtime | SCAFFOLD | NO | YES | — | — | Off by default; deterministic perf Sprint 3 territory |
| Graph (Metal renderer) | WIRED | YES | — | — | — | Bounded reopen; pinned panel fix landed |
| Local + Cloud models | WIRED | YES | — | — | — | DD batch coverage in flight |
| Quick Capture | PARTIAL | TBD — verify discoverability | — | — | — | Hide behind flag for V1 if not shippable; otherwise menu bar + global hotkey |
| Voice / dictation | PARTIAL | YES (mic in chat composer) | — | — | — | Already partially wired |
| Privacy transparency pane (S.6) | WIRED | YES | — | — | — | Drift-tested |
| Settings → Saved grants | WIRED | YES | — | — | — | Discoverability link from Privacy pane |
| Effective Model Badge + Why-this-model popover | WIRED | YES | — | — | — | Already landed |
| Reasoning trail rendering (per-provider) | WIRED with verification | YES | — | — | — | Verify Anthropic/OpenAI/Google all routed through ThinkingPopover |
| Agent Command Center (full surface) | SCAFFOLD | NO | YES | — | — | DEFER to V1.5; PLAN_V2 §4.1 territory |
| Embedded terminal | code in `pty.rs` | NO | YES | — | YES (Pro) | Pro V1.5 |
| Bash / shell / Docker tools | gated `#if !EPISTEMOS_APP_STORE` | NO (MAS) | YES (MAS) | — | YES (Pro) | Already gated |
| iMessage outbound | TBD | VERIFY before submit | — | — | — | Confirm MAS-safe entitlements |
| iMessage inbound (Phase K) | not built | NO | YES | — | YES (Pro) | DEFER |
| Hermes subprocess Swift health check | not wired (Phase Omega-2) | NO | — | — | — | Non-blocking; PTY layer is solid |
| BoltFFI typed buffer (graph) | landed behind flag, default off | YES (default off) | — | — | — | Flip flag only after parity proven on real hardware |
| syntax-core viewport path | scaffolded, gated by env var, default off | YES with WIRING | — | — | — | Wire ON for code files in V1 (P1) |
| Memory diff card | not built | NO | YES | — | — | DEFER (Master Plan §GG.3) |
| Bundled `rg` / `fd` | not built | NO | — | — | YES (Pro) | DEFER to Pro |
| Diagnostics panel | not built | NO | YES (under Settings → Advanced) | — | — | Add for V1.5 unless trivial |
| Metal binary archive (deterministic perf Sprint 3) | NOT STARTED | NO | — | — | — | Phase II per dpp |
| Substrate-rt zero-copy ring (deterministic perf Sprint 4) | NOT STARTED | NO | — | — | — | Phase II per dpp |
| PGO + bumpalo arenas (deterministic perf Sprint 5) | NOT STARTED | NO | — | — | — | Phase II per dpp |

## Ship-blocking items (P0)

1. **G1 — Pro+Cloud tool path** must route through Rust agent loop. Without it, the most common config silently hallucinates "find my note" answers. Fix in `Epistemos/Engine/PipelineService.swift:308-330` + `ChatCoordinator.swift:361`.
2. **A4 (PRIVACY_APP_STORE_AUDIT)** — verify Rust-side `mas-sandbox` feature gates every tool that uses `nix::process::*` / similar. Spot-check `agent_core/src/tools/registry.rs` and submodules.
3. **A1** — App Review JIT entitlement justification document.
4. **G2 — Raw Thoughts V0** under flag (canonical product moat).
5. **Code editor 4k-line benchmark gate** — wire syntax-core viewport path for code files; commit benchmark.

## Ship-strong V1 items (P1)

6. **G3 — Contextual Shadows V0** under flag, default-on in TestFlight.
7. **G14 conditional** — continuous 200ms encoding loop only if benchmarks prove no typing regression.
8. **G15** — verify reasoning summary persistence across all four providers.
9. **G5** — line-count gutter design.
10. **Reliability gate** — re-run baseline; document evidence.

## Hide / disable for V1

- Documents file type until built.
- Agent Command Center entry until built.
- Embedded terminal in MAS.
- Memory diff card.
- Disabled tests (HermesSubprocessTests, InstantRecallTests) — re-enable plan or remove.
- Diagnostics panel.

## Direct-build-only (Pro V1)

- Computer use stack.
- Bash / shell / Docker tools.
- Embedded terminal.
- iMessage inbound.
- Apple Events automation.
- Accessibility bypass.

## Final ship gate criteria

V1 (MAS) ships only when:

1. P0 items 1-5 are closed and verified.
2. Reliability gate green on a fresh run; evidence in `artifacts/reliability/`.
3. Bundle size <600 MB measured in CI.
4. JIT entitlement justification documented for App Review.
5. AppStoreHardeningTests + Phase R regression suites green.
6. Smoke test plan executed manually (BUILD_TEST_VERIFICATION_AUDIT §"Smoke test plan").
7. No `try!`/`as!` regression in Swift (grep clean).
8. No `unbounded` AsyncStream in Swift (grep clean).
9. No `DispatchQueue.main.sync` in Swift (grep clean).
10. PrivacyInfo.xcprivacy drift-test passes.

V1.5 (Pro) ships when:

1. Computer use stack regression-tested on macOS 26.
2. Embedded terminal panel complete.
3. iMessage inbound + outbound fully wired (Phase K).
4. ACC full surface complete.
5. Memory diff card.
6. Documents (.epdoc) editor.

## Confidence

HIGH on P0 items (file-grounded). MEDIUM on bundle-size + reliability-gate freshness (need fresh verification before submission).
