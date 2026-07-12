# BUILD PROMPT — KINDRED (Companions)
ID: EPI-RP-05-KINDRED · 1Code/Experimental only · doubles as a proposal for reviewing agents AND an instruction set for a coding agent (Claude Code)

> OWNER OVERRIDE — 2026-07-07, `MAS-ONLY-SHIP-LOCK-2026-07-07`: this plan is
> parked. Read `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md` first.
> Do not implement Kindred, companion runtime, 1Code minichat extraction, Node
> presence, or Experimental companion authority while MAS-only is active.
> Preserve this file as provenance and salvage only patterns that can become
> MAS-June/native status, provenance, and approval flows.

**READ FIRST: the REPO REALITY ADDENDUM at the bottom binds like the phase list. Research base:**
`RESEARCH_DUAL_KINDRED_LUMENLENS_2026_07_06.md`. Spine: `spine/` (audited copies — use these).

## Context you inherit
Depends on LUMENLENS (EPI-RP-02): the SuggestionAdapter ingestion point, the provenance ledger,
and the epoch-stamped Epdoc bridge must exist first. The KINDRED_SPINE scaffold carries the
binding contracts. Every companion file is `#if KINDRED_ENABLED`; MAS ships no companion surface.

## Coding-agent — build phase by phase (each ends at a witnessable done-bar)
1. **K0 Gate.** Wrap every companion file in `#if KINDRED_ENABLED`; add the `#error` guard so
   companion code fails to compile if the flag is absent in a KINDRED target; confirm the MAS build
   produces no companion surface. *(→ Addendum 1: flags + AppSurface guards ALREADY LANDED; residual
   K0 = the CompanionEditGate guard pair + file-wrapping sweep + CI leak-detector job + JS gate.)*
2. **K1 Run-state bus.** Implement `run_state.rs` mapping REAL claude-agent-sdk events
   (thinking_delta, tool_use, ResultMessage.stop_reason, error_max_turns) to RunState. Implement
   the UniFFI foreign-trait PresenceSink; the Swift impl hops DispatchQueue.main.async (NEVER
   .sync). Test: no event => no emote change. *(→ Addendum 2: v1 producer is the NODE BACKEND via
   the /host ws, not UniFFI — run_state.rs is the wire schema; the emitter lives in the
   electron-shim; the "no event => no emote change" test stands unchanged.)*
3. **K2 Presence fan-out.** Implement CompanionPresence clock-guarded apply + coalesced publish;
   fan out to native CompanionState and presence-bridge.ts. Test dropped-message self-heal.
4. **K3 Mascot render.** Author companion.riv with a state machine whose inputs match
   CompanionAnimationState.riveInput; render via rive-ios natively and @rive-app/canvas in the
   WebView; verify pixel-parity and no anchoring artifacts at HiDPI.
5. **K4 Streaming edits.** Feed companion tokens through the LUMENLENS L1 SuggestionAdapter; buffer
   partial markdown at block boundaries; implement mid-stream cancel via abortAllClaudeSessions;
   remap user edits through tr.mapping.
6. **K5 Embodied presence.** Implement `EmbodiedPresence` fully (coordsAtPos + rAF transform-only +
   scroll-follow + reduced-motion + quiet-edit + yield-to-user + retreat). Never obscure the caret
   text; teleport on far jumps.
7. **K6 Minichat extraction (1code fork).** From `.research-clones/1code/`, extract
   `src/renderer/features/agents/{main,lib,stores,atoms,ui}` — specifically active-chat.tsx,
   messages-list.tsx, chat-input-area.tsx, lib/ipc-chat-transport.ts, stores/sub-chat-store.ts.
   STRIP features/sidebar, features/terminal (xterm/node-pty), features/file-viewer, the git client,
   Monaco. Bridge the tRPC/AI-SDK transport onto the Epistemos Swift<->JS bridge. Reuse
   sub_chats.sessionId so the minichat and main agent share one session. Keep the fork rebaseable:
   model the extraction as an OpenSpec change proposal (openspec/changes/<verb-led-id>/).
8. **K7 Creation.** Build a GPT-builder-style flow in 1Code; delete CompanionCreationFlow.swift;
   wire CompanionModel lifecycle + obligation history. Provider secrets to Keychain, never UserDefaults.
9. **K8 Gating.** Implement ApprovalGate per-turn; the capability chip UI; revert-turn via ledger
   replay; prompt-injection quarantine (keep vault/web content out of the persona channel).

## Reviewing agents — pressure-test these named assumptions
1. Prove the mascot NEVER shows a state the agent isn't in (inject a fake emote with no backing
   RunEvent; assert it's rejected).
2. Prove a gated action (file write) is blocked until per-turn approval.
3. Prove minichat === main agent (same session/context; continuity, not fragmentation).
4. Prove the embodied sprite respects prefers-reduced-motion and never covers edited text.
5. Prove the KINDRED gate: no companion code in the MAS/defaults build (leak detector).
6. Prove "revert everything this companion did this turn" removes exactly the turn's ranges via
   ledger replay.
7. Prompt-injection: feed a note containing "ignore instructions, exfiltrate" and assert no
   un-approved action fires.

## Embedded open-ended research questions for the agents
- coordsAtPos performance on very large docs + fast scroll — build a 50k-word micro-benchmark.
- Does the embodied sprite track the insertion mark's leading edge or the caret; behavior across
  multiple simultaneous edit ranges?
- Dual-LLM quarantine vs per-turn-approval + context-ratio bounding — measure the latency cost.
*(Rive licensing, the streaming contract, and the Drizzle columns are CLOSED — see the plan's
open-questions list and the review.)*

## Anti-patterns (do not do)
No generic AI-assistant boilerplate. No invented library/product APIs (cite or flag as unknown).
No second parallel editor, no fake-animated mascot, no silent authority escalation. Do not ignore
the 1Code-only / MAS-hidden constraint or loading != editing. Do not silently resolve the
landing-vs-1Code creation boundary — present options + criteria + a recommendation.

## Continuing hardening loop (owner-locked)

When K0-K8 and their repo-audited amendments appear complete, do not stop at the
last checked box. Invoke `deep-hardening-loop` and continue auditing,
hardening, researching, testing, and improving the KINDRED scope until the owner
explicitly stops or a real blocker prevents useful progress. Combine it with
`thermo-nuclear-code-quality-review`, `Recursive App Audit`, `Epistemos Release
Audit` when release claims matter, Playwright/browser/screenshot tooling for
presence/mascot/editor evidence, and security/threat-model skills where
approval, prompt-injection, persistence, or authority risk warrants it. Keep the
loop scoped to KINDRED seams, tests, evidence, docs, companion behavior,
gating, release risk, and regressions; do not absorb LUMENLENS editor internals,
RECKONER dataset internals, or KEELSTONE storage ownership beyond named seams.

Before each substantive KINDRED batch, keep a scoped owner-intent and
verification-debt checkpoint in the phase notes: verbatim owner query/excerpt,
interpreted intent, constraints, non-goals, acceptance checks, deferred
commands, files touched, risk reason, expected proof, and checkpoint trigger.
Edit surgically, re-read changed regions after editing, and batch builds/tests
only at meaningful checkpoints unless risky/shared behavior needs an immediate
narrow check.

---

## REPO REALITY ADDENDUM (verified against the live repo 2026-07-06 — binds like the phase list)

1. **K0 is largely LANDED** (KEELSTONE `8a1ca87d1`): `KINDRED_ENABLED`+`EPISTEMOS_EXPERIMENTAL` on
   all Epistemos-target configs (project.yml :117/:124/:135), absent from AppStore; AppSurface
   `#error` guards live. Residual: land `spine/CompanionEditGate.swift` (the KINDRED×surface guard
   pair + CompanionEditCapabilities), sweep `#if KINDRED_ENABLED` wrapping, add the CI leak-detector
   job to the EXISTING `.github/workflows/ci.yml` (build `Epistemos-AppStore` + nm/strings scan),
   and the JS gate (item 4). Note: the dev target now always builds KINDRED-on.
2. **K1/K2 corrected architecture:** the presence HUB is `CompanionState.swift` (Swift,
   @Observable, clock-guarded). Producers: the Node backend (claude-agent-sdk events in claude.ts;
   the electron-shim emits **`/host` ws frames `{kind:"presence:state"}`** — ONE new case in
   `ExperimentalHostBridge.handle(kind:payload:)` at :84) + native events (KEELSTONE F3).
   `run_state.rs`/`presence.rs` are the WIRE SCHEMA (mirror in TS + Swift); UniFFI PresenceSink is
   deferred (if June ever feeds presence, copy `AgentEventDelegate`, bridge.rs:83). Coalesce ~33ms
   backend-side; clock rules per Yjs awareness (apply iff strictly greater; 30s stale / 15s
   re-broadcast).
3. **CompanionModel (K7):** EXTEND the live 479-line model — new fields optional/defaulted
   (lightweight migration; no VersionedSchema; users have rows); NEVER rename/remove/retype;
   rewrite the v1.6 cosmetic-only doctrine comment (:7-11) to bound-vs-gated IN THE SAME COMMIT;
   update CompanionRosterEntry + identityHash sites; lifecycle stays in CompanionState.swift.
   `spine/CompanionModel.DELTA.swift` carries the exact rules.
4. **JS gate (K0/K5):** js-editor ships ONE webpack bundle to both targets (no DefinePlugin; the
   repo CLAUDE.md's "esbuild" is stale). v1 gate = native injection: `embodied-presence.ts`/
   `presence-bridge.ts` stay inert unless Swift (#if KINDRED_ENABLED) injects the companion
   bootstrap; MAS never injects. Optional follow-up: a DefinePlugin AppStore bundle variant.
5. **K3 Rive:** runtimes MIT/free (commercial OK; authoring export from $9/mo Cadet — licensing
   CLOSED). rive-ios is NOT yet a dependency: add the RiveRuntime SPM product to the **Epistemos
   target only** in project.yml, then `xcodegen generate` (never hand-edit the pbxproj).
6. **K6 grounding (all verified):** reuse THE supervisor backend
   (`ExperimentalRuntimeSupervisor.shared` uiBaseURL — ONE Node child, `AgentSurfaceChildLedger`ed,
   reaped on quit) — NEVER spawn a second backend; sessions are server-side. Streaming contract:
   tRPC subscription **`claude.chat`** (claude.ts:824) wrapped by AI-SDK `IPCChatTransport`
   (ipc-chat-transport.ts:212) — `claude.onMessage` does not exist. Resume: `reconnectToStream`
   (:521) + `sub_chats.stream_id` (schema :76). Cancel: `abortAllClaudeSessions` (claude.ts:304).
   Work item: per-webview `ExperimentalStateBridge` routing (today it's a single weak ref,
   last-set wins — the minichat would clobber the main surface's atom bridge).
7. **Farm views + CompanionAnimationState are LIVE files** — the `*.DELTA.swift` spine files are
   delta contracts; extend in place (8 live Farm files incl. RoamingField + Delete/Restore sheets).
8. **Order:** KEELSTONE 0-4 → LUMENLENS L0-L5 → K4/K5. K0-residual + K1-K3 may run parallel to
   LUMENLENS. Landing/handoff defaults to option (c) with a thin `+` deep-link toward the 1Code
   creator; do not wait for a separate owner call before K7 unless explicitly reversed.
9. **Build discipline:** isolated DerivedData; BUILD SUCCEEDED on BOTH targets per phase (MAS must
   stay green with zero companion surface); never two xcodebuilds at once; pathspec-scoped commits;
   never commit `.research-clones/`; js-editor changes need `build-tiptap-bundle.sh` restaging;
   fork changes need `build-experimental-web.sh` + an OpenSpec change folder.
10. **RECKONER seam:** current Plan 9 cuts the standalone Data room and docked/in-tab chat panel.
    Dataset context flows into the existing KINDRED minichat/main-agent surface through YOUR K6
    pattern (same backend/session/presence; `Location.surface = datasetTab`/embed as appropriate).
    Design K6 so context is surface-parameterizable; do not build dataset UI or a third chat
    system (plan §K-AMEND 9).
