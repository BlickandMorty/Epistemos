---
state: per-terminal-punch-list (archeology — prior cycle)
created_on: 2026-05-17
cycle: RUN-B-C-D-E-F + maintenance loop A (2026-05-06 → 2026-05-16)
template: docs/audits/UAS_ACS_PER_TERMINAL_PUNCH_LIST_2026_05_17.md
authority:
  - docs/TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md (Terminal C's final closeout iter 222)
  - docs/TERMINAL_FINAL_TASKS_AND_STOP_2026_05_16.md (per-terminal final-task spec)
  - docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_{A,B,C,D,E,F}_2026_05_16.md (the 6 driver prompts; each carries STOP-ALL §0 + original §0 victory criteria)
  - docs/CODEX_HANDOFF_2026_05_16.md (post-merge consolidation)
purpose: Archeology punch list for the 6-Terminal RUN round (A/B/C/D/E/F) that completed 2026-05-16. Each section enumerates what each terminal DEFERRED at wind-down; use this post-merge as the single per-terminal pickup point.
---

# Post-RUN-BCDEF Per-Terminal Punch List — Archeology 2026-05-17

> The RUN-B-C-D-E-F + maintenance loop A cycle closed 2026-05-16 via the STOP-ALL-TERMINALS directive
> (`a18e72d65` + 4 duplicates). All 5 product branches merged to `main`:
>   - `merge(B): run-b-post-v1-research → main` (`988de854f`)
>   - `merge(D): run-d-providers → main` (`c56eeb049`)
>   - `merge(F): run-f-integrations → main` (`0461b4f3b`)
>   - `merge(C): run-c-audit → main` (`3f6b6fd4e`)
>   - `merge(E): run-e-decisions → main` (`a21d6cdef`)
>   - `merge(THIS): codex/research-snapshot-2026-05-08 → main` (`102a927f9` for maintenance loop A)
>
> Cargo lib floor at merge: **1671 tests** (up from 1194 baseline). All branches were doc-rich; per
> `TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md` §"What needs USER ATTENTION" + each driver's §0 victory
> criteria, this doc reorganizes the deferral list **by terminal** rather than by gate.
>
> This is archeology — the round terminated WITHOUT a per-terminal punch list at the time. The T3
> UAS-ACS session of 2026-05-17 noticed the gap and authored the template + the multi-terminal
> archeology prompt that this doc fulfills.

## §1. How to read this doc

Each section is one terminal (TA … TF). For each row:
- **Item** — what's missing or deferred
- **Where** — file path / branch / commit / doc anchor
- **Why** — what downstream feature or terminal depends on it
- **Acceptance** — measurable criterion (no "looks good" — must be quantifiable)

The cross-terminal interconnection map is at §10. Pre-merge sanity check is at §11.

## §2. TA — V1 Ship (MAS + Pro distribution)

Branch: `codex/research-snapshot-2026-05-08` (also drove `lane-A`). Maintenance loop A.
Mission: Close every V1 ship blocker. MAS App Store submission AND Pro Developer ID distribution.
Victory criteria: 15 listed in `CLAUDE_AUTONOMOUS_LOOP_PROMPT_V2_2026_05_16.md §0`.
Status at handoff: 5/15 reached per directive's status note (see TERMINAL_HANDOFF_SNAPSHOT §"Audit-of-audit register summary" — "Terminal A §0 victory criteria: 5/15 reached").

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **ApprovalModalView.swift in-flight edit** | `Epistemos/Views/Approval/ApprovalModalView.swift` (uncommitted on `lane-A` at handoff per snapshot §"Status per terminal") | Pending USER decision: commit (if complete) or stash (if mid-thought). Blocks A's wind-down marker. | Edit either landed as a commit or stashed; lane-A working tree clean; final wind-down marker pushed |
| **MAS xcodebuild Release green** | `xcodebuild -scheme Epistemos-AppStore -configuration Release` per `MAS_FINAL_STRETCH §4.1` (criterion #5) | App Store submission gate; without this MAS V1 is non-shippable | xcodebuild Release exits 0; no warnings about missing entitlements / PrivacyInfo |
| **MAS_FINAL_STRETCH §4.1 command sweep green** | `docs/MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §4.1 (criterion #6) | Aggregated post-build verification commands (binary audit + entitlement check + PrivacyInfo bundle check) | every §4.1 command exits clean; no leaked symbols / no missing keys |
| **Binary audit — no ScreenCaptureKit/AXorcist/omega_ax in MAS** | per criterion #7 | MAS sandbox forbids these; presence = MAS rejection. Source guards exist but `otool` binary scan is the truth. | `otool -L Epistemos.app/Contents/MacOS/Epistemos \| grep -E "ScreenCapture\|AX(orcist)?\|omega_ax"` returns nothing |
| **PrivacyInfo.xcprivacy bundled** | `Epistemos.app/Contents/Resources/PrivacyInfo.xcprivacy` (criterion #8) | MAS-required privacy manifest declaring API access reasons | File exists in MAS bundle; passes `plutil -lint`; includes every API actually called |
| **6-key MAS entitlements verified** | `Epistemos-AppStore.entitlements` (criterion #9) | Each entitlement must be claimed AND used; unused entitlements = MAS rejection | All 6 keys present + each has a runtime caller; no extras |
| **Pro xcodebuild Release green** | `xcodebuild -scheme Epistemos-Pro -configuration Release` (criterion #10) | Developer ID distribution gate | Release configuration builds without errors |
| **codesign verify** | `codesign --verify --verbose=4 Epistemos.app` (criterion #11) | Code-signing integrity check before notarization | exit 0; "satisfies its Designated Requirement" |
| **notarytool Accepted** | `xcrun notarytool submit ... --wait` (criterion #12) | Apple notarization for Developer ID distribution | status: Accepted; ticket retrievable |
| **stapler validate** | `xcrun stapler staple Epistemos.app && xcrun stapler validate Epistemos.app` (criterion #13) | Notarization ticket stapled into bundle | "The validate action worked!" |
| **Phase F′ XPC end-to-end** | VaultXPC → AgentXPC → ProviderXPC → WASMExecXPC coordination chain (criterion #14) | XPC Mastery Doctrine 5-service decomposition; without end-to-end the service split is theatre | Round-trip integration test: chat query touches all 4 XPC services, all return success, capability tokens flow |
| **Per-XPC entitlement audit** | one entitlements file per XPC service (criterion #15) | Each XPC service must have minimal entitlement set; any over-privileged service = security regression | per-service entitlements diffed against actual capability surface; no excess |

### TA cross-cutting blockers

- **D.5 ↔ A WASMExecXPC dependency surface** — TERMINAL_HANDOFF_SNAPSHOT §"What needs USER ATTENTION" #5: escalation flagged from C iter 174; awaiting USER decision: (a) authorize A to exit wind-down, (b) authorize D to skip D.5, (c) redirect WASMExecXPC, or (d) continue blocked. Surfaced in C's PASS-2 §9 register cycles iter 174-217.

## §3. TB — Post-V1 + Research Tier (Wave G/H/I/J)

Branch: `run-b-post-v1-research` @ `28385bdea`.
Mission: Land EVERY remaining Wave G/H/I/J item, EVERY 136 NOT-STARTED MASTER_FUSION row, Helios V5/V6.1/V6.2 hardware-validated kernels, Brain export + Biometric Tamagotchi, Live File Compiler full state machine.
Final commit: `docs(B-final-proof): V6.1 acceptance proofs — wave-by-wave evidence`.
Snapshot summary: "435 commits ahead · 1643 tests (+449 vs main 1194) · Wave I A2UI 24/24 closed · B.1, B.2, B.6, G, J shipped per ACCEPTANCE_PROOFS_V6_1_2026_05_16.md."

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **Wave G — Simulation v1.7+ full 13-state animation machine** | `docs/fusion/simulation/DOCTRINE.md` (1982L · 16 invariants) | TB §0 criterion #1 (Wave G). Doctrine landed; animation state machine implementation deferred. | 13 states + 16 invariants implemented in Swift simulation runtime; per-invariant unit test |
| **Wave H — Halo/Shadow remaining items** | `docs/fusion/HALO_SHADOW_*` + `Epistemos/Engine/Halo*` | Halo/Shadow shipped at V1 but remaining queue items per TB §0 (Wave H criteria) deferred | each Wave H §0 line item has a code anchor + test |
| **Wave I A2UI catalog — final hardening** | `agent_core/src/research/a2ui/` (5,452 LOC · 24/24 components per TB final proof) | TB shipped Wave I 24/24 but per drift catches, surface integration into product UI not all done | every A2UI component has a Swift rendering surface OR an explicit GenUI-DEFER row |
| **Wave J research-tier validation against acceptance bars** | `docs/audits/` — J1-J9 entries | TERMINAL_HANDOFF_SNAPSHOT §"What needs USER ATTENTION" #6: "Wave J research-tier entries J1-J9 — research-only; not validated against acceptance bars. USER must decide whether to promote any to V1 ship scope or keep deferred for V2." | each J1-J9 either: (a) gets a §4.G-style falsifier doc + harness, OR (b) is explicitly marked V2-deferred in MASTER_FUSION |
| **Helios V5/V6.1/V6.2 kernels — `canonical_target_not_implemented_here`** | `agent_core/src/research/helios/` + V6.1 doctrine `KERNEL_IMPLEMENTATION_POSTURE` declaration | TERMINAL_HANDOFF_SNAPSHOT #7: "PageGather / SemiseparableBlockScan / LocalRecallIsland / ControllerKernelPack / PacketRouter1bit — declared `canonical_target_not_implemented_here`." T3 picked up substrate-floor PASS for 8/11 in §4.G ladder; **Metal kernels remain TB-or-T3 deferral.** | Each kernel has a Metal kernel + Swift driver + falsifier PASS on M2 Pro 16 GB |
| **Brain export + Biometric Tamagotchi** | `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` (44 KB seed doctrine) | TB §0 criteria. Brain export surfaces Cognitive DAG / mechanism state to user-readable form. Biometric Tamagotchi is the lockable-content companion. | Brain export emits at least one .epbundle with provenance ledger + DAG snapshot embedded; Tamagotchi UI surfaces lock state per T8 doctrine |
| **Live File Compiler full state machine** | `docs/fusion/LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` (Wave 7 substrate) | TB §0 criterion (Wave 7 — Live File Compiler). State machine deferred at handoff. | manual-trigger first per LiveNoteScanner; state transitions log to RunEventLog |
| **B.1 invariant-testing discipline — 30 categories** | per TERMINAL_HANDOFF_SNAPSHOT §"Audit-of-audit register summary" — TB §7 audit checkpoints ~20 cleared at milestone iter 200 | category count locked at 30; remaining 10 not yet wired into Wave I A2UI cluster | every category has a `tests/<category>_*.rs` exhaustive coverage check |
| **B.6 — see TB final commit for full closure** | `docs/ACCEPTANCE_PROOFS_V6_1_2026_05_16.md` | TB final proof doc enumerates which waves PASSED ACCEPTANCE vs deferred to a wave-level row | each acceptance-failed wave gets a §10-style deferred row pointing to which post-merge slice picks it up |

## §4. TC — Continuous Audit Conscience

Branch: `run-c-audit` @ `8085deafd`.
Mission: Audit-of-audit conscience of the parallel run. Verify §5.0 claims. Maintain doctrine cross-links. Catch drift before it accumulates.
Final task: write `docs/TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md` (DONE — that's the source for this punch list).
Snapshot: ~54 audit-of-audit cycles + ~10 status pulses + 6 §7 meta-cycles at iters 79/100/130/160/190/220. 52+ consecutive ON-TRACK since drift catch iter 74.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **(no production-code deferrals)** | — | TC is pure audit role; never touches production code per scope lock | TC deferrals are governance-not-code: see below |
| **PASS-2 §9 register continuation** | `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` §9 (55 audit-of-audit cycles + 7 trust-but-verify lessons at handoff) | T9 in the 9-terminal cycle continued this pattern but it's an unbounded audit-of-audit doctrine — never "done" | every new cycle of multi-terminal work appends ≥ 1 AoA cycle + ≥ 1 trust-but-verify lesson |
| **MAS §8 implementation-log row chronology** | `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §8 (per snapshot §"File-conflict predictions" — grew ~200 rows during cycle) | TC discipline: append-only, never overwrite. Post-merge readers need this to reconstruct sequence. | every merge into main keeps row chronological order; no row deletion |
| **FEATURE_CHANGE_TRACKER continuation** | `docs/FEATURE_CHANGE_TRACKER_2026_05_16.md` | TC-owned per §5.7. Tracks every feature mutation in product code. | each merge brings new feature mutations into the tracker |
| **CANONICAL_DOC_INDEX maintenance** | `docs/CANONICAL_DOC_INDEX_2026_05_16.md` (TC-owned per §5.7) | post-merge readers need a single doc-index to navigate the corpus | every new doc added during a cycle gets indexed |

### TC trust-but-verify lessons cumulative — also deferred forward

Per TERMINAL_HANDOFF_SNAPSHOT §"Trust-but-verify lessons articulated this session":
- **Lesson #6** — substrate-claim verification requires independent re-grep (operationalized as `.github/workflows/drift-detection.yml`)
- **Lesson #11** — RE-READ SIBLING DRIVER §5 BEFORE flagging any pattern as drift
- **Lesson #12** — LOC-claim precision is verifiable
- **Lesson #13** — authorship via `git log -1 --format='%an %ae'`
- **Lesson #14** — maintenance-loop identity distinct from product terminals
- **Lesson #17** — `git show <sha> --stat` to verify diff CONTENT matches commit-message claim

These are governance heuristics. Future audit terminals (T9, etc.) must inherit them.

## §5. TD — Providers + MCP + CLI passthrough + Code execution

Branch: `run-d-providers` @ `9c83757d8`.
Mission: Expand the agent's reach — new cloud providers, new MCP servers, new CLI passthrough tools, new code execution tools, tool registry expansion.
Final task: commit/stash in-flight `agent_loop.rs` + `providers/claude.rs` + add D.1.1/D.1.2 MCP-hardening closure tests.
Snapshot: 297 commits · 1220 tests · 8 autonomous-lockstep iterations · D.1.1 + D.1.2 hardening sub-clusters 3 commits deep each.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **In-flight agent_loop.rs + providers/claude.rs edits** | `agent_core/src/agent_loop.rs` + `agent_core/src/providers/claude.rs` (uncommitted at handoff per snapshot §"Status per terminal") | TD's final task was to land these as D.1.1/D.1.2 closure tests | Edits landed; cargo lib floor ≥ 1220 (TD's run-level baseline) holds or grows |
| **Cloud providers not all wired** | `agent_core/src/providers/` | TD §0 criterion #1 listed 7 cloud providers: Gemini · Kimi · xAI Grok · Codex CLI wrap · Codestral · OpenRouter · Together. Verify each shipped vs deferred. | each provider has: (1) `agent_core/src/providers/<name>.rs`, (2) at least one round-trip test, (3) row in `MODEL_GRAMMAR_MATRIX` |
| **MCP servers integration** | `omega-mcp/` | TD §0 criterion #2 listed: filesystem · git · web-search-mcp · etc. | each MCP server has: stdio transport, URL transport (where applicable), authentication path, smoke test |
| **Pro tier CLI passthrough** | `agent_core/src/cli_passthrough/` (Pro-only) | TD §0 criterion #3: codex · gemini · kimi · claude CLI wrap | each CLI: `#[cfg(feature = "pro-build")]` gated, security-scoped bookmark, subprocess hardening per `agent_core::security::harden_cli_subprocess()`, round-trip test |
| **Code execution tools** | `agent_core/src/code_execution/` (per `WASMExecXPC` plan) | TD §0 criterion #4: Wasmtime · Python (sandbox) · Node (sandbox) · Ruby · Perl · shell (Pro). Wasmtime gates the rest. | Wasmtime executor lands first; per-language test runs `1+1=2` round-trip; each Pro-tier language behind feature flag |
| **Tool registry stable schema** | `agent_core/src/tools/registry.rs` | TD §0 criterion #5: each tool has declaration · grammar · executor · safety gate · test | every tool in registry has all 5 attached; CI test asserts completeness |
| **D.1.1 hardening sub-cluster closure** | per snapshot §"Audit-of-audit register summary" — D.1.1 3-commits deep at iter 208/214/221 | hardening tests for D.1 MCP integration | every D.1 surface has a hardening test; iter-221 6-doc + 3-code lockstep pattern documented |
| **D.1.2 hardening sub-cluster closure** | iter 180/202/218 — also 3-commits deep | hardening tests for D.1.2 MCP-transport-correctness contracts | every transport contract has a hardening test |
| **D.5 WASMExecXPC dependency on A** | per TERMINAL_HANDOFF_SNAPSHOT §"What needs USER ATTENTION" #5 — D.5 ↔ A escalation | Pro tier code execution depends on WASMExecXPC service (TA scope). Cross-terminal blocker. | USER answers (a/b/c/d) per snapshot; D.5 either proceeds or gets explicit V2-deferral |
| **HERMES_AGENT_CORE_2_0_DESIGN doc — D's rows** | `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` | per snapshot §"File-conflict predictions" — D's 8 autonomous-lockstep rows land alongside F's integration rows | both terminals' rows present chronologically post-merge |
| **TOOL_INVENTORY_TRUTH_TABLE — D's rows** | `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` | same as above | combined truth table reflects D + F additions |

## §6. TE — User-Decision Research (13 items)

Branch: `run-e-decisions` @ `6bbb475c4`.
Mission: research each of the ~13 user-decision-gated items in depth; prepare full-context options + tradeoffs + recommendations + decision-ready surface so the user can decide quickly.
Final task: just a wind-down marker (all 13 research docs complete at iter 253).
Snapshot: 253 commits · 13/13 user-decision research docs surfaced · awaiting USER signoff.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **13 user-decision research docs await USER signoff** | `docs/audits/user-decisions/*.md` | Per snapshot §"What needs USER ATTENTION" #4: "USER must read + answer. These decisions cannot auto-implement." | USER answers each item; answered items get handed off to owning terminal (A/B/D/F) as implement-ready slice |
| **RCA13-P0-001 vault smoke decision** | `docs/audits/user-decisions/RCA13-P0-001-*.md` (final commit `d71772762` per snapshot) | The "highest-leverage" decision per E's prioritization | USER answers; T4 vault terminal (current cycle) consumes the answer |
| **Per-answered-item handoff to owning terminal** | per E §0 criterion #5: "Any answered items have been handed off to the owning terminal (A/B/D/F) as ready-to-implement slices" | Without handoff, answered decisions stay dormant | each answered item has a corresponding row in the owning terminal's queue + slice ID |
| **MAS_COMPLETE_FUSION §10 Compromises Recorded — E's research-doc cross-refs** | `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §10 | E §0 criterion #3: every item's §10 row references its research doc | every research doc has a §10 row pointing back; cross-link traversable both directions |

### TE — what's NOT a deferral
TE shipped 100% of its assigned scope (13/13 research docs). The "deferral" is USER cognition — without the user answering, downstream work can't start. This is `docs/audits/user-decisions/` waiting for inboxes to be processed.

## §7. TF — External Integrations

Branch: `run-f-integrations` @ `4726720fd`.
Mission: Land all external-integration surfaces — Channel Relay (Pro tier 7 channels) + iMessage Pro drivers + Apple Events / Computer Use polish + OpenClaw multi-claw MAS (J4 from Wave J) + Calendar/Mail/Reminders/Spotlight integration.
Final task: commit/discard in-flight prompt edit + add tests for F.1.3 Pro-gated channel worker CLIs.
Snapshot: 241 commits · F.1.3 Pro-gated channel worker CLIs shipped · closure tests pending.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **In-flight prompt edit on F driver** | `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_F_2026_05_16.md` (per snapshot §"Status per terminal") | F's wind-down requires commit-or-discard of the in-flight edit | edit committed (if meaningful clarification) or discarded; final task can proceed |
| **F.1.3 Pro-gated channel worker closure tests** | `tests/channel_workers_*.rs` (final commit message: `feat(F-final): F.1.3 Pro-gated channel worker closure tests`) | F's final task; without these the Pro-tier channel workers ship without acceptance coverage | each worker has a `#[cfg(feature = "pro-build")]` test that exercises the CLI subprocess + verifies output |
| **Channel Relay 7 channels** | per TF §0 criterion #1: Telegram · Slack · Discord · WhatsApp · Signal · Email · iMessage | each requires Pro entitlement gate + subprocess hardening + per-channel grammar | each channel: `#[cfg(feature = "pro-build")]` module + per-channel adapter + delivery test |
| **iMessage Pro drivers full inbound** | per TF §0 criterion #2: full inbound (currently only outbound stub) + native-bridge carve-out per `docs/channels/relay-ops.md` | iMessage is product-promoted; inbound is the missing half (outbound shipped pre-cycle per FILE MAP `Epistemos/Omega/iMessageDriver/IMessageDriverService.swift`) | inbound message → AgentRuntime dispatch profile per K-channel doctrine; per-sender override surface |
| **Apple Events / Computer Use polish** | per TF §0 criterion #3: AXorcist queries · CGEvent dispatch · ScreenCaptureKit — all Pro-only behind `#if !EPISTEMOS_APP_STORE` | binary audit (TA criterion #7) rejects these from MAS; Pro polish is the surface | per-surface integration test in Pro target; binary audit confirms 0 occurrences in MAS target |
| **OpenClaw multi-claw MAS framework** | per TF §0 criterion #4: `mas_architecture_research.md` · multi-claw orchestrator · capability-scoped dispatch profiles · per-claw audit trail | OpenClaw was Wave J4 (research-tier) — TF carved it out from TB to integrate as a multi-claw orchestrator | multi-claw orchestrator lands; capability-scoped profile per claw; audit trail flows to ClaimLedger |
| **Calendar / Mail / Reminders / Spotlight integration** | per TF §0 criterion #5: EventKit + MailKit + UnifiedNotifications + CoreSpotlight | broad macOS integration surface | each framework: bootstrap call + at least one round-trip + UI surface |
| **HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md — F's integration rows** | `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` | per snapshot §"File-conflict predictions" — F's integration rows land alongside D's autonomous-lockstep rows | both terminals' rows present chronologically post-merge |

## §8. Maintenance loop A — `codex/research-snapshot-2026-05-08`

Branch: `codex/research-snapshot-2026-05-08` @ `dcf8825a1` (per final state).
Mission: Audit-row PASS-1 LOW slice maintenance work — supporting V1 ship by closing audit-row backlog.
Status at handoff: 8 audit-of-audit cycles before iter-83 wind-down. Idle since `7eb513bea`.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **(no specific deferrals — maintenance role)** | — | Per snapshot §"Audit-of-audit register summary" — "IDLE since iter 83 wind-down" | Maintenance loop is by design intermittent; no continuous deferral list |
| **Re-publishing A's T-A self-audit docs for parallel-terminal visibility** | per snapshot §"Audit-of-audit register summary" — "Currently re-publishing A's T-A self-audit docs for parallel-terminal visibility" | TA's self-audits become readable to sibling terminals via this branch | each T-A self-audit doc reachable from `codex/research-snapshot-2026-05-08` |

## §9. Swift / Metal lane (cross-terminal — affects TA + TB + TF)

The Swift-side Metal kernel work blocks several Helios kernels from production-PASS. TB's deferral in §3
points here; T3's UAS-ACS work (current cycle) confirmed this lane via §4.G ladder gates.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **`Epistemos/Shaders/PageGather.metal`** | currently a stub per TB Wave H queue | TB §0 Wave H criterion; T3 §4.G ladder gate #5 picked up substrate-floor PASS at iter 54 (CPU twin); Metal kernel remains deferred | F-PageGather-M2Pro falsifier PASS: ≥ 70% of MEASURED M2 Pro STREAM at 256/512/1024 MB buffers |
| **`Epistemos/Shaders/PacketRouter1bit.metal`** | not yet | TB Wave H criterion; T3 §4.G ladder gate #10 picked up substrate-floor PASS (CPU ref) at iter 48 | Metal p99 < 100 µs + bit-for-bit match vs CPU ref |
| **`Epistemos/Shaders/ControllerKernelPack.metal`** | not yet | TB Wave H criterion; T3 §4.G ladder gate #11 picked up substrate-floor PASS at iter 49 (6 kernels × 7-size sweep + 100-iter sequence) | per-kernel Metal correctness vs CPU ref + sequence wall-clock |
| **`Epistemos/Shaders/SemiseparableBlockScan.metal`** | not yet | TB Wave H criterion; T3 §4.G ladder gate #8 picked up substrate-floor PASS at iter 53 (Track A: 100 seeds × 4 block sizes; CPU scalar reference verified) | Metal kernel matches `helios::ssd_block_scan_scalar` + `ssd_minimal.py` reference within 1e-3 fp16 over 100 seeds |
| **`Epistemos/Shaders/LocalRecallIsland.metal`** | not yet | TB Wave H criterion; T3 §4.G ladder gate #9 picked up substrate-floor PASS at iter 52 (5 depths × 50 trials at 32k context) | Metal kernel + live model integration |
| **Apple Events / Computer Use polish (CGEvent + ScreenCaptureKit + AXorcist)** | per §7 TF criterion #3 | TF deferred; binary audit (TA criterion #7) gates MAS shippability | Pro-only behind `#if !EPISTEMOS_APP_STORE`; binary audit on MAS confirms 0 symbols |
| **EventKit + MailKit + UnifiedNotifications + CoreSpotlight integration** | per §7 TF criterion #5 | TF deferred | each framework: bootstrap call + UI surface |

## §10. Cross-cutting / multi-terminal items

Items where the deferral spans multiple terminals — they can only be closed when both halves land.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **MAS_COMPLETE_FUSION §8 row chronology after merge** | `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §8 | per snapshot §"File-conflict predictions" — TC ~200 rows + TB rows + TD rows + TF rows; post-merge must keep chronological. Append-only contract. | merged §8 has no row deletion; every row's timestamp matches its commit date |
| **`agent_core/Cargo.toml` + `Cargo.lock` union of dep additions** | per snapshot §"File-conflict predictions" — TB added a2ui/wave-I deps; TD added MCP/Anthropic-spec deps | both dep sets need to merge | union both; re-run `cargo update -p <added crate>`; cargo lib floor ≥ 1671 |
| **`HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` row chronology** | per snapshot §"File-conflict predictions" — TD's 8 autonomous-lockstep + TF's integration rows | both rows present post-merge | append-only chronology |
| **`TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` row chronology** | same as above | both rows present | append-only chronology |
| **`agent_core/src/providers/claude.rs` MCP-transport vs integration tier** | per snapshot §"File-conflict predictions" — TF may have modified same `mcp_servers` / `mcp_toolset` blocks as TD | merge needs ordering | TD's MCP-transport-correctness contracts preferred; TF's integration-tier wiring verified to still compile + tests pass |
| **STOP-ALL-TERMINALS directive `a18e72d65`** + 4 dupes `4726720fd / 6bbb475c4 / 51e193bf6 / a5c1dab65` | per snapshot §"What's still LOOPING" | already propagated to all 6 driver files; each terminal reads its §0 on next iter and stops | All 6 drivers carry §0 hard-stop; no terminal re-fires `/loop` until USER manually does so |

## §11. Cross-terminal interconnection map

| Feature area | Primary terminal | Touches |
|---|---|---|
| **MAS shippability** | TA | TB (binary surface — must not leak ScreenCaptureKit) · TD (MCP / providers surface — must not embed Python in MAS) · TF (Apple Events polish — Pro-only) |
| **Pro distribution (Developer ID + notarization)** | TA | TD (CLI passthrough Pro tier) · TF (Channel Relay Pro tier) |
| **XPC service decomposition (Phase F′)** | TA | TD (ProviderXPC service) · TF (AgentXPC bridge to channels) |
| **WASMExecXPC** | TA | TD (D.5 code execution tools depend on this) |
| **MCP integration** | TD | TF (Channel Relay MCP servers) · TB (research-tier MCP servers for Wave J integration) |
| **Cloud provider expansion** | TD | TA (capability gate per ConfidenceRouter routing decision) |
| **Helios kernels (PageGather / Scan / Recall / Router / Controller)** | TB | TA (MAS shippability — Metal lane vs binary audit) · current-cycle T3 (substrate-floor PASS at §4.G ladder; production Metal kernel still deferred) |
| **A2UI Wave I components** | TB | TF (channel-relay UI components) · current-cycle T6 (UI/UX integration of A2UI components into product surfaces) |
| **iMessage** | TF | TD (provider routing for iMessage-as-tool) · current-cycle T2 (agent_runtime tool surface for iMessage inbound) |
| **Channel Relay 7 channels** | TF | TD (per-channel auth via provider auth surface) · TA (Pro entitlement gate) |
| **Brain export + Biometric Tamagotchi** | TB | current-cycle T8 (biometric lock doctrine consumes the Tamagotchi shape) · current-cycle T2 (export surfaces via AnswerPacket pipeline) |
| **OpenClaw multi-claw MAS framework** | TF | TB (Wave J4 research-tier source) · TD (per-claw provider routing) · TA (MAS / Pro tier gating) |
| **User-decision answers → owning-terminal handoff** | TE | TA · TB · TD · TF (each answered decision routes to owning terminal) |
| **Audit-of-audit cumulative discipline** | TC | every other terminal (audit-of-audit is universal) · current-cycle T9 (inherits TC's PASS-2 §9 register pattern) |
| **MAS §8 implementation-log row chronology** | TC | TB · TD · TF (each terminal appends; TC enforces append-only) |
| **FEATURE_CHANGE_TRACKER** | TC | every other terminal (feature mutations) |
| **CANONICAL_DOC_INDEX maintenance** | TC | every other terminal (doc additions) |

## §12. Pre-merge sanity check (post-merge today; preserved here for archeology completeness)

This cycle's merges already landed on `main` by 2026-05-17. Preserved here for the historical record:

1. **Cargo baseline expected on merged main**:
   ```bash
   git checkout main
   cargo test --manifest-path agent_core/Cargo.toml --lib  # expect ≥ 1671
   ```
   Last verified on T8 worktree 2026-05-17: 1671 passed.

2. **xcodebuild on merged main**:
   ```bash
   xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
   ```
   Last verified 2026-05-16 post-merge: BUILD SUCCEEDED.

3. **Verify driver §0 hard-stop directives propagated**:
   ```bash
   grep -l "STOP-ALL-TERMINALS" docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_*.md
   # expect: 6 file matches (A B C D E F)
   ```

4. **Confirm append-only doctrine docs**:
   - `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §8 — no row deletion
   - `RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` §9 — append-only
   - `FEATURE_CHANGE_TRACKER_2026_05_16.md` — append-only

## §13. Cross-references

- **Final closeout** (TC's hand): `docs/TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md`
- **Per-terminal final tasks**: `docs/TERMINAL_FINAL_TASKS_AND_STOP_2026_05_16.md`
- **Each driver's full §0 victory criteria**: `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_{A,B,C,D,E,F}_2026_05_16.md`
- **Post-merge consolidation handoff**: `docs/CODEX_HANDOFF_2026_05_16.md`
- **Acceptance proofs (TB's final task)**: `docs/ACCEPTANCE_PROOFS_V6_1_2026_05_16.md`
- **Template (current-cycle T3's)**: `docs/audits/UAS_ACS_PER_TERMINAL_PUNCH_LIST_2026_05_17.md`
- **Archeology meta-prompt**: `docs/audits/MULTI_TERMINAL_ARCHEOLOGY_PROMPT_2026_05_17.md`
- **MASTER_FUSION 43-row atlas**: `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md`

## §14. §5.0 Validation pass

Each claim in §2-§10 above traces to one of:
- A specific file path that exists on the merged `main` (verified via merge commits in §11)
- A V3 driver prompt's §0 victory criterion (numbered #1-#15 or #1-#N per terminal)
- A row in `TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md` (specifically §"What needs USER ATTENTION" or §"Audit-of-audit register summary")
- A merge commit message on `main` (the 5 `merge(X):` commits enumerated at the top of this doc)

**No invented deferrals.** Where a deferral could not be traced to a specific source, the row says "verify each shipped vs deferred" rather than asserting non-shipment. The TB row on cloud providers (§5) is one such example.

**Anti-template-copying**: zero rows in this doc are copied from the T3 punch list template content. The format follows the template but every Item / Where / Why / Acceptance is sourced from this cycle's own evidence.

## §15. Open Questions (unresolved during archeology)

1. **TA's exact 5/15 victory split** — per TERMINAL_HANDOFF_SNAPSHOT §"Audit-of-audit register summary" Terminal A "5/15 reached," but the directive doesn't enumerate WHICH 5 vs WHICH 10. Resolution: open A's last self-audit doc (re-published via maintenance loop A per §8) to find the exact split.
2. **Wave H criteria details for TB** — TB §0 listed Wave H as part of the criteria set but the driver's full Wave H list wasn't captured in this archeology. Resolution: read TB §0 in full from `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`.
3. **F.1.1 + F.1.2 vs F.1.3 status** — F.1.3 channel worker CLIs shipped; F.1.1 and F.1.2 status unclear from the snapshot. Resolution: read F's commit messages around the F.1.x rollout.
4. **D.1.3+ hardening status** — D.1.1 and D.1.2 each 3-commits deep at snapshot time; D.1.3+ not surfaced. Resolution: walk D's commit log post-D.1.2 cluster.

These can be resolved by future audit-of-audit cycles (T9 or successor) without re-running archeology.

---

*Archeology punch list for the RUN-B-C-D-E-F-A cycle, in the same shape as `UAS_ACS_PER_TERMINAL_PUNCH_LIST_2026_05_17.md`. Authored 2026-05-17 per the multi-terminal archeology mission. Validates against TC's final closeout snapshot + each driver's §0 victory criteria.*
