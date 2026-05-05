# Canon Gaps and Pre-Drafted Addenda — 2026-05-02

> **NEW DOC — created 2026-05-02.** Filename: `CANON_GAPS_AND_ADDENDA_2026_05_02.md`. If your session can't find it, search by name. Sister docs: `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`, `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md`, `CODEX_DELIBERATION_PROMPT_2026_05_02.md`, `WORKTREE_INSIGHT_SALVAGE_2026_05_02.md`, `ALL_DOCS_INDEX_2026_05_02.md`. Mirrored into the active worktree's `docs/fusion/`.

> **STATUS — PARTIALLY MERGED 2026-05-05.** Originally staged pending Codex's deliberation response. After the 2026-05-05 canon-hardening session, Codex's #1 advice item was "merge `CANON_GAPS_AND_ADDENDA` staged blocks". High-severity items C1 (WRV), C2 (no silent fallback), C3 (BYOK off by default), C4 (UX posture §4.0), C5 (canonical state is the only source of truth — §2.2 invariant #5 + §6 forbidden), and medium item C13 (telemetry policy in §6) have been merged into `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`. Each merged block carries an inline `(C#, merged 2026-05-05.)` provenance tag in the destination file. Remaining items (C6 reference link, C7 Resource Runtime anchors, C8 App Store closeout authority, C9 Quick Capture standalone canon, C10 Flight Recorder, C11 pre-release evidence package, C12 local-stream truncation watch, C14 ambient_V1_DECISION naming, C15 housekeeping, B1–B3 bonuses) remain staged.
>
> **This doc remains as the audit trail.** Each `MERGE TARGET:` block below is now annotated with `[MERGED 2026-05-05]` for items that have landed.

---

## 2026-05-03 — Round 103 pbxproj target-sync drift

- **Drift:** `CODEX_TASK_CONTINUITY_HANDOFF_2026_05_03.md` claimed 24 Hermes/Resonance files were not in the Xcode target. Current `project.pbxproj` uses `PBXFileSystemSynchronizedRootGroup`, and focused `xcodebuild` compiled the listed files without manual project edits.
- **Resolution:** No `project.pbxproj` edit was required. The actual blocker was missing `/tokens` dispatch in `HermesCommandDispatcher`, fixed by adding `HermesTokensCommand` to `HermesParsedCommand` and `parseCore`.
- **Evidence:** `/tmp/epistemos-pbxproj-sync-r103-20260503-rerun.log` passed 28 tests across `HermesCommandDispatcherTests` and `ResonanceServiceTests`.

## 2026-05-03 — Round 104 HELIOS verification-floor drift

- **Drift:** `EPISTEMOS_FUSION_HANDOFF_2026_05_03.md` described `agent_core/metal/` as the Metal kernel authority. Current Epistemos has no `agent_core/metal/`; canonical shader authority is `Epistemos/Shaders/`, including the Mamba-2 shader pack.
- **Resolution:** `HELIOS_METAL_KERNELS_2026_05_03.md` and `scripts/verify_hotpath.py` re-derived the kernel index against `Epistemos/Shaders/` instead of copying GPT mockup paths.
- **Drift:** GPT's reference `verify_hotpath.py` used `int.bit_count()`, which failed on the active Python runtime. The canonical verifier uses a portable `bin(mask).count("1")` fallback.
- **Evidence:** `/tmp/epistemos-verify-hotpath-r104-20260503.log` passed 23/23 checks and wrote `docs/fusion/oversight/HELIOS_HOTPATH_VERIFICATION_2026_05_03.json`.

## 2026-05-04 — D2 MCP graph-boundary closure vs deeper backend gap

- **Closed blocker:** The original audit drift "zero seven-verb MCP graph boundary" is closed. `omega-mcp` now advertises `graph.search_semantic`, `graph.search_fulltext`, `graph.get_node`, `graph.traverse`, `graph.create_node`, `graph.create_edge`, and `graph.commit_session` with schemars-derived input schemas. `execute_vault_tool` / `execute_graph_tool` route them through a vault-scoped graph store and append graph events to `.epistemos/mcp_graph_events.jsonl`.
- **Still a gap:** `graph.search_semantic` and `graph.search_fulltext` currently use deterministic in-process lexical matching over the MCP graph store. The doctrine's HNSW vector recall and Tantivy BM25 backends remain substrate-deepening work. The Pro-only `epistemos-hermes-mcp` stdio binary and live Hermes session round-trip are also follow-on work.
- **Evidence:** `cargo test --manifest-path omega-mcp/Cargo.toml d2_graph`, full `cargo test --manifest-path omega-mcp/Cargo.toml` (134 passed), and `cargo test --manifest-path omega-mcp/Cargo.toml --features mas-sandbox` (112 passed).

## 0. Confirmed stances (locked, not addenda)

These are confirmations of what the doctrine already says, with the user's most recent decisions:

- **Three tiers (Core / Pro / Research)**, not two policy profiles. Doctrine §3 is correct as written. The original "one runtime, two policy profiles" framing is **superseded** by the no-compromise three-tier stance the user gave on 2026-05-01.
- **All three tiers ship in parallel** via different distribution channels (App Store / Developer ID + Notarization / Developer ID + private framework loading). Doctrine §3 + §5 are correct.

---

## 1. Reconciliation summary

15 gaps identified between the user's original `Epistemos unified master plan` and the new canon. Plus 3 bonus findings (additional canon docs uncovered during path verification).

| Severity | Count | Action |
|---|---|---|
| **High** (load-bearing; merge once Codex confirms) | 8 | C1–C5, C7, C8, C11 |
| **Medium** (clarification or visibility upgrade) | 4 | C6, C10, C12, C13 |
| **Low** (housekeeping / explicit naming) | 3 | C9, C14, C15 |
| **Bonus** (newly-discovered canonical addenda not in any index) | 3 | B1, B2, B3 |

The gap list below is exhaustive — once these merge plus whatever Codex's deliberation response surfaces, the canon is closed and Codex can build off it.

---

## 2. The 15 gaps with pre-drafted addenda

Each gap below has:
- **What the original plan said** — verbatim summary
- **What the new canon says today** — current state
- **Severity + recommended target file**
- **Pre-drafted text** ready to merge (in fenced blocks marked `MERGE TARGET:`)

### C1 — WRV doctrine (Wired + Reachable + Visible + Verified) **[MERGED 2026-05-05]**

**Original plan:** *"A feature is not real because files exist; it is real only when it is wired, reachable, visible, and verified."*

**Current canon:** Implicit; not named. Doctrine §10 Operating Rule has a "no done claim without path-verified user-visible surface OR passing log path" but does not enumerate WRV.

**Severity: High.** This is the load-bearing process discipline of the original plan.

**MERGE TARGET:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §10 Operating Rule, append after current point #6.

```md
7. **WRV — the only honest "shipped" claim.** Every claim of "done" or "shipped" must satisfy all four:

   - **Wired** — code path exists and compiles in the target tier
   - **Reachable** — at least one user-facing entry point reaches it
   - **Visible** — its state is observable in UI, diagnostics, or audit log
   - **Verified** — at least one test or raw log proves it works

   Files existing is not enough. A subsystem fully implemented but unreached by any UI is not shipped — it is donor code. WRV is enforced at the deliberation-brief layer (`Codex prompt §3.4 report-before-code`); a brief that cannot fill all four for its slice is returned.
```

**Also add to** `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md` §3.4 (report-before-code), append to the report block:

```md
WRV:           wired? reachable? visible? verified? (each yes/no with evidence pointer)
```

---

### C2 — No silent cloud fallback / escalation **[MERGED 2026-05-05]**

**Original plan:** *"No silent backend or cloud switching. Local-first, private by default, optional BYOK cloud, no silent fallback/escalation."*

**Current canon:** Doctrine §6 forbids "hidden cloud calls" — close, but does not forbid silent fallback or automatic escalation when local can't answer.

**Severity: High.** Auditability invariant.

**MERGE TARGET:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §6 Hard Forbidden List, append:

```md
- **Silent cloud fallback or escalation.** If a request is about to leave the device, the user sees an explicit opt-in prompt for that specific request OR has previously enabled the provider in Settings with a clear "use this for X" scope. No automatic "I couldn't answer locally, let me try cloud" behavior in any tier. The transition from local → cloud is always a UI event the user can audit.
```

---

### C3 — BYOK cloud OFF by default **[MERGED 2026-05-05]**

**Original plan:** *"Optional BYOK cloud off by default."*

**Current canon:** Not explicit. Doctrine §3 lists cloud providers as Core-tier capability; nothing says default state.

**Severity: High.** Privacy default.

**MERGE TARGET:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §6 Hard Forbidden List, append:

```md
- **BYOK cloud providers enabled by default.** Default state for every cloud provider (Anthropic, OpenAI, Perplexity, etc.) is OFF on a fresh install. The user must explicitly add a key in Settings AND toggle the provider on. No marketing-defaults that pre-enable cloud routing.
```

---

### C4 — UX posture: one composer, two modes, separate effort, tools as capabilities **[MERGED 2026-05-05]**

**Original plan:** *"One composer, two modes (Chat/Agent), separate effort control, tools treated as capabilities rather than as a third mode."*

**Current canon:** UX posture missing entirely. Doctrine talks about features and tiers; not about the input affordance shape.

**Severity: High.** This is the original plan's UX backbone.

**MERGE TARGET:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` — insert new §4.0 BEFORE §4.1 Resonance Gate (renumber section heading "## 4. The Three Killer Features" to "## 4. UX Posture and the Three Killer Features"; the killer features stay numbered §4.1–§4.3).

```md
### 4.0 UX Posture (every tier)

**One composer, two modes.** Chat mode and Agent mode share the same input affordance — same composer view, same shortcut, same surface. Mode is a toggle next to the composer, not a separate entry point in the sidebar. The user sees one place to write; the system routes by mode.

**Effort control is separate from mode.** Effort (fast / thinking / research / agent / liveAgent) lives on its own axis next to the composer. Effort can be changed mid-conversation without leaving the thread. Effort is never bundled into "modes."

**Tools are capabilities, not a third mode.** A tool call is something the agent does inside a turn — not a separate UX surface. There is no "Tools mode." Capability gating happens at the agent layer through the Sovereign Gate (§4.2) and the tool registry (`agent_core/src/tools/registry.rs`), not at the composer.

**Per-tier UX:** All tiers ship the same composer + two-mode layout. Pro / Research add additional effort levels (e.g., long-horizon research, computer-use) but the input shape is identical. This is what makes Pro feel like a continuous evolution of Core, not a different app.
```

---

### C5 — No second source of truth (visuals project from canonical state) **[MERGED 2026-05-05]**

**Original plan:** *"Liquid Wave and Theater cannot become second truth systems. All visuals project from canonical events/state only."*

**Current canon:** Theater is gated to Pro tier; Liquid Wave is the current main branch. The "no second source of truth" principle is not stated as an invariant.

**Severity: High.** Anti-drift rule.

**MERGE TARGET:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §2.2 Architectural Invariants — add as the **5th invariant**:

```md
5. **Canonical state is the only source of truth.** Visual layers — Liquid Wave, Simulation Theater, Halo overlays, Residency Rail, Sovereign Gate dialog, Pulse ghost text — project from canonical events (`AgentEvent`, `GraphEvent`, `MutationEnvelope`) and Rust kernel state. They do not own state. A visual surface that implies state the runtime does not authoritatively own is a §2.2 violation. If a UI shows "thinking" and the agent is not actually thinking, that is P0.
```

Also add to **§6 Hard Forbidden List**:

```md
- **Visual surfaces that imply state the runtime doesn't authoritatively own.** Liquid Wave cannot animate "agent is thinking" if no agent turn is in flight. Simulation Theater cannot show a sub-agent dispatch that didn't emit an `AgentEvent`. Halo cannot show a hit count without a real query result. Visual layers project; they do not invent.
```

---

### C6 — Halo specific stack reference **[MERGED 2026-05-05]**

**Original plan:** *"6-state FSM, trailing-edge debounce, Model2Vec + usearch + Tantivy + weighted RRF, non-activating NSPanel, explicit latency budgets."*

**Current canon:** Doctrine §4.3 Pulse + Rail mentions Halo as a dependency but does not cite the stack. Stack lives in older canon.

**Severity: Medium.** Reference link is enough.

**MERGE TARGET:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.3 — add a "Stack reference" line in the Halo dependency context:

```md
**Halo V1 stack reference (do not re-derive):** 6-state FSM (`dormant → watching → encoding → searching → available → open`) + trailing-edge debounce + Model2Vec + usearch + Tantivy + weighted RRF + non-activating NSPanel + explicit latency budgets per the V1 product canon. Implementation lives across `Epistemos/Engine/HaloController.swift`, `HaloEditorBridge.swift`, `ShadowSearchService.swift`. Stack rationale and budget targets are in `docs/_consolidated/00_canonical_authority/ambient_V1_DECISION.md` and `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md`.
```

---

### C7 — Resource Runtime + grants + verified writes + PromptTree

**Original plan:** *"Phase R: Resource Runtime, grants, verified writes, picker, regression closure. PromptTree from Lane A."*

**Current canon:** Resource Runtime / grants / verified writes live on `codex/runtime-input-audit` (DIVERGED, 324 commits, never merged — salvage §6). `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 H1 corrects the older PromptTree claim: Lane A is **not** mostly merged; it has 601 unmerged N1 Prompt Tree commits plus `PROMPT_AS_DATA_SPEC.md` and full PTF work behind `EPISTEMOS_PROMPT_TREE=1`. 2026-05-04 update: Prompt Tree now has a fusion bridge at `docs/fusion/PROMPT_TREE_LANE_A_BRIDGE_2026_05_04.md`; remaining work is current-main delta reconciliation, not rediscovery.

**Severity: High.** Phase R is the named Core release substrate.

**MERGE TARGET 1:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §9 Canonical Code Anchors — add new rows:

```md
| Resource Runtime + grants + verified writes (Phase R) | unmerged: `codex/runtime-input-audit` branch (324 commits ahead of main, never landed). Files include vault write authorization pipeline, attachment path exposure, sandbox grant seeding | **DIVERGED** — cherry-pick now per Salvage §6 |
| PromptTree / N1 | Lane A donor is **601 unmerged commits** per `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 H1. Canonical donor docs: `/Users/jojo/Downloads/Epistemos-laneA/docs/PROMPT_AS_DATA_SPEC.md` and `/Users/jojo/Downloads/Epistemos-laneA/docs/plan/prompts/N1_prompt_tree.md` | Do not claim mostly merged. Verify main with `rg "prompt.cache.tokens.share|EPISTEMOS_PROMPT_TREE|PromptTree" Epistemos agent_core docs` before assigning or closing |
| Phase R / Phase S release substrate | `docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` + `docs/_consolidated/30_canonical_operational/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` (mirrored copy) | Authority for App Store closeout state |
```

**MERGE TARGET 2:** `WORKTREE_INSIGHT_SALVAGE_2026_05_02.md` §6 codex/* branches — promote `codex/runtime-input-audit` to "**Cherry-pick now (Phase R closure depends on it)**" in bold; already there at high priority but emphasis needed.

---

### C8 — APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24 **[MERGED 2026-05-05 — §1 Authority Order entry; ALL_DOCS_INDEX entry still pending]**

**Original plan:** Listed as part of authority hierarchy.

**Current canon:** File exists at TWO locations (`docs/` and `docs/_consolidated/30_canonical_operational/`). Not referenced in doctrine §1, not in `ALL_DOCS_INDEX_2026_05_02.md`.

**Severity: High.** Was named in original authority hierarchy.

**MERGE TARGET 1:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §1 Authority Order — add to point #2 (Repo authority docs):

```md
   `AGENTS.md`, `CLAUDE.md`, `docs/architecture/PLAN_V2.md`, `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md`, `docs/_consolidated/00_canonical_authority/*`, **`docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md`** (App Store closeout authority).
```

**MERGE TARGET 2:** `ALL_DOCS_INDEX_2026_05_02.md` §6 Consolidated Canonical Authority — add row:

```md
| [APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md](/Users/jojo/Downloads/Epistemos/docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md) | App Store closeout state — Phase R / Phase S progress tracker |
```

---

### C9 — Quick Capture standalone canon **[MERGED 2026-05-05 — §1 Authority Order point #5.5; ALL_DOCS_INDEX entry still pending]**

**Original plan:** *"PLAN.md + FINAL_SYNTHESIS.md as Quick Capture authority; FINAL_SYNTHESIS corrects PLAN.md where they conflict."*

**Current canon:** Only the worktree (`vigorous-goldberg-3a2d35`) is referenced as donor; the standalone canon at `/Users/jojo/Documents/Epistemos-QuickCapture/` is not named. Verified to exist with 11 files including `PLAN.md` (244 KB), `FINAL_SYNTHESIS.md` (53 KB), three `*_ADDENDUM.md` docs, builder/audit/catchup prompts, INDEX.md, README.md.

**Severity: Medium / Low.** Separate-track authority.

**MERGE TARGET 1:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §1 Authority Order — add as new item between #5 and #6 (before "Worktree code"):

```md
5.5. **Quick Capture standalone canon** — `/Users/jojo/Documents/Epistemos-QuickCapture/PLAN.md` + `FINAL_SYNTHESIS.md` (FINAL_SYNTHESIS corrects PLAN.md where they conflict). Authority for the Quick Capture track only. Worktree donor: `vigorous-goldberg-3a2d35`. Treat as authoritative for Quick Capture decisions; subordinate to repo authority docs and this doctrine for everything else.
```

**MERGE TARGET 2:** `ALL_DOCS_INDEX_2026_05_02.md` — add new §3.5 between §3 and §4:

```md
## 3.5. QUICK CAPTURE STANDALONE CANON

Lives outside the main repo at `/Users/jojo/Documents/Epistemos-QuickCapture/`. Authority for Quick Capture track decisions; FINAL_SYNTHESIS corrects PLAN where they conflict.

| Doc | Role |
|---|---|
| [PLAN.md (Quick Capture)](/Users/jojo/Documents/Epistemos-QuickCapture/PLAN.md) | Quick Capture phases 0–12.5 implementation plan (244 KB) |
| [FINAL_SYNTHESIS.md (Quick Capture)](/Users/jojo/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md) | Post-critique synthesis; corrects PLAN.md (53 KB) |
| [BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md](/Users/jojo/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md) | Bonus discovery — biometric + Tamagotchi + brain-export integration; aligns with Sovereign Gate + simulation Tamagotchi pattern |
| [LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md](/Users/jojo/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md) | Live Files (deferred per original plan) substrate addendum |
| [OBSCURA_BROWSER_ADDENDUM.md](/Users/jojo/Documents/Epistemos-QuickCapture/OBSCURA_BROWSER_ADDENDUM.md) | Obscura browser (Wave 6) addendum |
| [BUILDER_PROMPT.md (Quick Capture)](/Users/jojo/Documents/Epistemos-QuickCapture/BUILDER_PROMPT.md) | Quick Capture builder prompt |
| [CATCHUP_PROMPT.md (Quick Capture)](/Users/jojo/Documents/Epistemos-QuickCapture/CATCHUP_PROMPT.md) | Quick Capture catchup prompt |
| [AUDIT_PROMPT.md (Quick Capture)](/Users/jojo/Documents/Epistemos-QuickCapture/AUDIT_PROMPT.md) | Quick Capture audit prompt |
| [INDEX.md (Quick Capture)](/Users/jojo/Documents/Epistemos-QuickCapture/INDEX.md) | Quick Capture canon index |
| [README.md (Quick Capture)](/Users/jojo/Documents/Epistemos-QuickCapture/README.md) | Quick Capture canon README |
```

---

### C10 — Flight Recorder (named subsystem) **[MERGED 2026-05-05 — §7 Build-Order + Annex A.15]**

**Original plan:** *"Trust visibility: diagnostics, status surfaces, runtime transparency. Flight Recorder is a real subsystem, not afterthought logging."*

**Current canon:** OpLog projection + AgentEvent live emission cover provenance. "Flight Recorder" as a user-visible exportable diagnostic is not named.

**Severity: Medium.** Visible-trust requirement.

**MERGE TARGET 1:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §7 Build-Order Dependency Graph — add to "Core open" list:

```md
  ├─ Flight Recorder + runtime transparency      open    Core
```

**MERGE TARGET 2:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` Annex A — add new subsection:

```md
### A.15 Flight Recorder + runtime transparency

User-facing trust visibility. Beyond OpLog projection (which is structural) — the Flight Recorder is the user-facing diagnostic surface that lets the user see and export what the system is doing.

**Three components:**

1. **Structured event log** — already exists as OpLog + `agent_events` + `graph_events` tables.
2. **Exportable diagnostic bundle** — Settings → Export Diagnostics. Bundles last N hours of OpLog + AgentEvent + GraphEvent + crash logs + benchmark JSON results. User-controlled scope (anonymize / include vault content / metadata-only).
3. **Live runtime status surface** — visible state of agent loop (idle / thinking / tool-running / waiting-on-approval), MLX inference state (loaded / loading / evicting / refused), FFI call counts and recent failures.

**Tier impact:** All tiers ship #1 and #2. #3 visible in Pro / Research; in Core it's behind a hidden Settings toggle (defaults off; trust-builder for users who want it).
```

---

### C11 — Submission candidate / release evidence package

**Original plan:** *"Workflow matrix, regression suite closure, App Store metadata/compliance, manual dogfood, repeatable release checklist."*

**Current canon:** Not in doctrine §7; not in salvage map. Phase S sequencing is mentioned in the original plan but not landed in the new canon.

**Severity: High.** Phase S is the actual ship gate.

**MERGE TARGET:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` — add new Annex C (after Annex B):

```md
## Annex C — Pre-release Evidence Package (Core / MAS submission)

Required deliverables before Mac App Store submission. None of these counts as "shipped" without WRV (§10):

- **Workflow matrix.** Every user flow tested against a fresh build; raw log path captured per flow. Matrix lives at `docs/_consolidated/30_canonical_operational/WORKFLOW_MATRIX.md` (or equivalent — verify path).
- **Regression suite closure.** Swift Testing + cargo tests green for the Core target; no skips, no flake. Sweep `xcodebuild test` + `cargo test` logs in CI.
- **App Store metadata.** Entitlements plist, scheme audit, bundle ID consistency, privacy manifest (`PrivacyInfo.xcprivacy`), App Store Connect description / screenshots / keywords. Verify against `docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md`.
- **Manual dogfood window.** Minimum N days of founder use against a real vault, on a clean install of the MAS-candidate build. Daily dogfood notes captured.
- **Submission checklist.** Repeatable per-release closure document — every release must pass the same checklist before Apple submission.
- **Phase R closure proof** — Resource Runtime + grants + verified writes pass the `codex/runtime-input-audit` cherry-pick + green test suite.
- **Phase S closure proof** — App Store sequencing: TestFlight beta + reviewer notes + submission packet.

**Process:** Codex runs this Annex as a checklist after the deliberation queue clears. Each line either has a green raw log or it doesn't. No "we'll fix that in the next release" exceptions for any item that touches user data integrity, privacy, or sandbox compliance.

**Tier impact:** Core only. Pro / Research ship via Developer ID + Notarization without App Review, so the metadata/compliance subset is reduced — but the workflow matrix, regression closure, manual dogfood, and Phase R closure still apply.
```

---

### C12 — Local-stream truncation/flush fix preservation **[MERGED 2026-05-05 — added as §8.5 in WORKTREE_INSIGHT_SALVAGE]**

**Original plan:** *"Preserve and reapply local-stream truncation/perf fixes."*

**Current canon:** Not in salvage map; not in doctrine. The fix likely lives in `Epistemos/LocalAgent/IncrementalToolCallDetector.swift` (verified to exist on main + 3 worktrees).

**Severity: Medium.** Known fix that needs explicit preservation through any agent_loop refactor.

**MERGE TARGET:** `WORKTREE_INSIGHT_SALVAGE_2026_05_02.md` — add new section 5.13:

```md
### 5.13 Local-stream truncation / flush fix — preservation watch

**File:** `Epistemos/LocalAgent/IncrementalToolCallDetector.swift` (exists on main + worktrees `quirky-pascal-135a98`, `hermes-parity`, `simulation`)

**Status:** Known fix that prevents premature EOF / token truncation on the local-stream path during tool-call detection. Currently shipping on main.

**Risk:** Any future refactor of `agent_loop.rs`, the Anthropic streaming bridge, or the tool-call detector could regress this. The original master plan flagged "preserve and reapply local-stream truncation/perf fixes" as a P0 stabilization concern.

**Action:** Before any patch that touches the streaming path or `IncrementalToolCallDetector`:
1. Run `EpistemosTests/IncrementalToolCallDetectorTests.swift` and capture green log.
2. Manual test: trigger a long-streaming local-MLX response with embedded tool calls; verify no EOF truncation.
3. After the patch: re-run both. Any regression is P0.

**Tier:** Core (Pro / Research inherit the same path).

**Recommendation:** Add explicit preservation note to the deliberation brief for any agent_loop or streaming-path slice.
```

---

### C13 — Telemetry sensitivity / retention / consent **[MERGED 2026-05-05 — §6 forbidden line + Annex A.16 full policy table]**

**Original plan:** *"Telemetry sensitivity. Even metadata-only carries behavioral sensitivity. Minimal capture, explicit retention policy, opt-in/clear copy before rollout."*

**Current canon:** Not in doctrine §6; not in forbidden list. CLAUDE.md mentions "API keys in macOS Keychain, NEVER UserDefaults" but no telemetry policy.

**Severity: Medium.** Privacy invariant + policy gap.

**MERGE TARGET 1:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §6 Hard Forbidden List, append:

```md
- **Telemetry capture beyond metadata.** Input-driven telemetry (keystroke timing, modifier states, app activity) is metadata-only. Never content (typed text, note bodies, code, message contents, query strings). Retention bounded; explicit opt-in for any telemetry channel; default-off for cloud-uploaded telemetry. Consent copy reviewed before any new channel ships.
```

**MERGE TARGET 2:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` Annex A — add new subsection A.16:

```md
### A.16 Telemetry policy

**Captured (allowed):** event timestamps, modifier-key states, anonymized event types (e.g., "agent_turn_completed"), failure categories (e.g., "tool_timeout"), aggregate latency histograms, feature flag enablement, OS version, app version, hardware class.

**Forbidden:** typed text content, note body text, code content, message bodies, file contents, file paths (paths can leak private structure), search query strings, vault content, screenshots, AX tree contents, microphone audio.

**Retention:** local-only by default. Bounded ring buffer (last 7 days for runtime telemetry; last 30 days for crash logs). Cloud upload requires explicit per-channel opt-in.

**Consent:** any new telemetry channel requires (a) Settings toggle defaulting OFF for cloud upload; (b) clear copy describing what is captured and why; (c) one-click "delete all telemetry" affordance.

**Tier impact:** identical across tiers. Pro and Research can layer additional opt-in channels but the metadata-only / no-content rule is invariant.
```

---

### C14 — `ambient_V1_DECISION.md` explicit naming **[MERGED 2026-05-05 — explicitly named in §1 Authority Order point #2]**

**Original plan:** Listed as part of authority hierarchy alongside MASTER_FUSION etc.

**Current canon:** Lives at `docs/_consolidated/00_canonical_authority/ambient_V1_DECISION.md` ✓ verified. Doctrine references `_consolidated/00_canonical_authority/*` as a catch-all but does not name this file.

**Severity: Low.** Covered by the catch-all but worth explicit naming for searchability.

**MERGE TARGET:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §1 Authority Order — expand point #2 to name the load-bearing files explicitly:

```md
2. **Repo authority docs.**
   `AGENTS.md`, `CLAUDE.md`, `docs/architecture/PLAN_V2.md`, `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md`, plus the named files in `docs/_consolidated/00_canonical_authority/`: `MASTER_FUSION.md`, `MASTER_BUILD_PLAN.md`, `RESEARCH_INDEX_BY_FEATURE.md`, `EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md`, `CODEX_VERIFIED_STATE_2026_04_25.md`, **`ambient_V1_DECISION.md`** (Halo / V1 product scope), `MASTER_HARDENING_AND_HARNESS_PLAN.md`, `IMPLEMENTATION_PLAN_FROM_ADVICE.md`, `ANTI_DRIFT_SYSTEM.md`, `00_AUTHORITY_AND_ANTI_DRIFT.md`, `01_DOCTRINE.md`, `02_BUILD_MATRIX.md`, `03_EXECUTION_MAP.md`, `NEXT_SESSION_BOOTSTRAP.md`, `PLAN_V2.md` (consolidated copy).
```

---

### C15 — CRDT collaboration explicitly deferred

**Original plan:** *"CRDT collaboration deferred."*

**Current canon:** "REP mesh + CRDT" appears in Annex A.8 (multi-agent orchestration) as a Research-tier mechanism, not as a deferred-collaboration call-out.

**Severity: Low.** Clarification.

**MERGE TARGET:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §6 Hard Forbidden List, append:

```md
- **Multi-user CRDT collaboration in Core or Pro.** Real-time collaborative editing (shared cursor, shared note editing, shared agent session across users) is **Research only** at the ACS Ecosystem layer (Annex A.4 / A.8). Core and Pro are single-user products. CRDT for single-user multi-device sync (within one iCloud account) is also deferred — explicit slice required if reconsidered.
```

---

## 3. Bonus findings — newly-discovered canonical addenda

While verifying paths, three previously-unindexed canon docs surfaced. None were referenced in any of the four new packet docs.

### B1 — `BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md`

**Path:** `/Users/jojo/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` (44 KB, dated 2026-04-29)

**Why it matters:** The filename alone contains three concepts that map directly to the doctrine's killer features:
- **Biometric** → Sovereign Gate (§4.2)
- **Tamagotchi** → simulation worktree's pixel-art mascot system (Salvage §4.12) and possibly the Pulse + Rail companion concept (§4.3)
- **Brain export** → Flight Recorder / runtime transparency (Annex A.15 above) AND possibly a model-state export feature

**Action:** Read this doc before merging the addenda above; it may already pre-answer C10 (Flight Recorder) and tighten the Sovereign Gate / Tamagotchi link.

**Add to** `ALL_DOCS_INDEX_2026_05_02.md` §3.5 (covered by C9 merge target above).

### B2 — `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md`

**Path:** `/Users/jojo/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` (67 KB, dated 2026-04-29)

**Why it matters:** Live Files is **deferred** per the original master plan. This 67 KB addendum likely contains the design that was being held back — useful to absorb when the deferred track is reactivated, dangerous if it leaks into Core ambition before then.

**Action:** Read before merging; may inform when the Live Files Pro / Research item should land in the build-order graph (doctrine §7).

**Add to** `ALL_DOCS_INDEX_2026_05_02.md` §3.5 (covered by C9 merge target above).

### B3 — `OBSCURA_BROWSER_ADDENDUM.md`

**Path:** `/Users/jojo/Documents/Epistemos-QuickCapture/OBSCURA_BROWSER_ADDENDUM.md` (62 KB, dated 2026-04-29)

**Why it matters:** Obscura is the Pro-tier stealth browser engine called out in `vigorous-goldberg-3a2d35`'s `BrowserEngine` trait (Salvage §5.8). 62 KB of design depth that's not in any of the new packet docs — risks being lost if Pro browser tunnels ship without absorbing it.

**Action:** Read before Pro browser-use slices begin; lift relevant adapter-design rules into doctrine Annex or Salvage §5.8 expanded.

**Add to** `ALL_DOCS_INDEX_2026_05_02.md` §3.5 (covered by C9 merge target above).

---

## 4. Merge execution plan

When the user authorizes the merge:

1. **Read Codex's deliberation response** at `docs/fusion/oversight/CODEX_DELIBERATION_RESPONSE_2026_05_02.md` (if it has landed).
2. **Consolidate** Codex's gap list with the 15 in this doc + 3 bonus findings — dedupe; add any items Codex caught that this doc missed.
3. **Single-pass merge** — every `MERGE TARGET:` block in this doc is lifted verbatim into its target file in one commit-ready edit batch. No file is touched twice.
4. **Mirror updated files** into the active worktree's `docs/fusion/`.
5. **Update** `ALL_DOCS_INDEX_2026_05_02.md` if any new doc is added.
6. **This doc remains** afterward as the audit trail of what changed and why. Mark each gap `MERGED ✓` when done.

**Estimated merge size:** ~150 lines added across doctrine (40 lines), Codex prompt (3 lines), salvage map (15 lines), index (15 lines). Plus B1/B2/B3 read-and-absorb passes (separate slices).

**Safety check before merge:** confirm Codex's deliberation response does not contradict any of the 15 pre-drafted addenda. If conflict, surface to user; do not auto-resolve.

---

## 5. Status checklist

| Gap | Severity | Status |
|---|---|---|
| C1 WRV doctrine | High | Drafted, awaiting Codex deliberation + user authorize |
| C2 No silent cloud escalation | High | Drafted |
| C3 BYOK cloud OFF by default | High | Drafted |
| C4 UX posture (composer / modes / effort / capabilities) | High | Drafted |
| C5 No second source of truth | High | Drafted |
| C6 Halo stack reference | Medium | Drafted |
| C7 Resource Runtime + Phase R | High | Drafted |
| C8 APP_STORE_RELEASE_COMPLETION_STATUS authority | High | Drafted |
| C9 Quick Capture standalone canon | Medium | Drafted |
| C10 Flight Recorder | Medium | Drafted |
| C11 Pre-release evidence package | High | Drafted |
| C12 Local-stream truncation fix watch | Medium | Drafted |
| C13 Telemetry policy | Medium | Drafted |
| C14 ambient_V1_DECISION explicit name | Low | Drafted |
| C15 CRDT collaboration deferred | Low | Drafted |
| B1 BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM | Bonus | Indexed; read before merge |
| B2 LIVE_FILES_AND_SUBSTRATE_ADDENDUM | Bonus | Indexed; read before merge |
| B3 OBSCURA_BROWSER_ADDENDUM | Bonus | Indexed; read before merge |

**18 items total. None merged yet. Held until Codex deliberation + user authorize.**

---

## 2026-05-03 - HELIOS lattice donor Babai drift

**Status:** Recorded during STEP 4b / PR58 implementation.

**Drift:** `/Users/jojo/Downloads/GPT research/crates/helios-core/src/lattice.rs`
describes a lower-triangular `CholeskyBasis`, but its Babai mockup iterates the
lower-triangular basis backward and updates rows `0..=i`. That can mis-round
targets whose lower-triangular dependency is carried by an earlier coefficient.

**Resolution:** Canonical Epistemos implementation in
`agent_core/src/lattice/mod.rs` re-derives Babai for the declared
lower-triangular basis using a forward column update, rejects invalid bases and
dimension mismatches as `Result` errors, and locks the behavior in
`agent_core/tests/lattice_budget.rs`.

**Usefulness:** +1 - prevents donor mockup drift from entering the hot-path
quantization substrate.

---

## 2026-05-03 - App Group entitlement signing-profile drift

**Status:** Recorded during STEP 5d/e / PR63 implementation.

**Drift:** Fusion handoff STEP 5 says to add `group.com.epistemos.shared` to
Epistemos entitlements. Adding the App Group key to the local direct/debug
profiles made the current `xcodebuild` path fail with: `"Epistemos" has
entitlements that require signing with a development certificate.`

**Resolution:** PR63 keeps the canonical App Group key in
`Epistemos/Epistemos-AppStore.entitlements`, leaves direct/debug signing
profiles unchanged for local buildability, and keeps `AppGroupContainer`
fallback-safe when the App Group container is unavailable. Direct/Pro/Research
App Group expansion needs a signing-profile gate that updates certificate/team
configuration alongside entitlements.

**Usefulness:** +1 - prevents a correct architectural entitlement from silently
breaking local debug/direct builds before the signing profile is coordinated.

---

## 2026-05-04 - T6 Companion/Tamagotchi body-grammar correction

**Status:** Captured during canonical recovery after user clarified the original
Simulation Mode intent.

**Drift:** Current `CompanionView` and donor Simulation v1.6 research render
companions as SF Symbols or simple orb/shard/pulse shapes. The intended canon is
styleable Tamagotchi-like companion creatures with a drawn avatar grammar,
landing-page wandering/idle motion, and later graph companion presence.

**Resolution:** Added
`docs/fusion/fleet/t6-tamagotchi-body-grammar/T6_TAMAGOTCHI_BODY_GRAMMAR_RECOVERY_2026_05_04.md`
as the T6 recovery pointer. First safe slice: draw Block/Sage/Orb/Hermes Snake
via SwiftUI Canvas, replace SF Symbols in `CompanionView`, then add deterministic
landing roaming before graph presence.

**Usefulness:** +1 - preserves the user's original Companion Farm vision and
prevents generic SF Symbol/orb placeholders from being mistaken for canon.

---

## 2026-05-04 - XPC no-compromise trust-spine intake

**Status:** Added during XPC canon recovery after the user clarified that the
latest research is canonical and must not be interpreted as a May 4 time-box,
V1 shortcut, or compromise gate.

**Drift:** The XPC canon still contained older near-term co-location wording,
which could be read as lowering the five-service target or weakening
trust-boundary requirements for near-term implementation.

**Resolution:** Added
`docs/fusion/XPC_RESEARCH_INTAKE_2026_05_04.md` as a required sidecar, linked it
from the master index and substrate register, and rewrote the XPC open-question
language so implementation slicing preserves named service contracts, symmetric
code-signing validation, schema/class whitelists, App Group provisioning
discipline, MAS/Pro separation, and Secure Enclave vault-key semantics.

**Usefulness:** +1 - prevents future briefs and delegated agents from treating
XPC hardening as optional, date-gated, or deferrable doctrine.

---

## 2026-05-04 - Simulation v1.6 invariant re-baseline for Companion Farm + GenUI

**Status:** Recorded during unification recovery after
`docs/fusion/simulation/DOCTRINE.md` promoted the full 16-invariant Simulation
Mode v1.6 canon into fusion.

**Audit:** Current Companion Farm is a SwiftUI recovery slice, not the full
Simulation runtime. I-1 through I-4 remain architectural gaps until the Rust
agent registry, reducer, event log, and session/Epistemos thread split own the
creature state machine. I-5, I-13, and I-14 are partially satisfied by
deterministic identity hashes, deterministic roaming, and reduce-motion static
rendering, but still need audit-ledger replay against canonical events. I-6,
I-7, I-8, I-11, I-12, and I-16 remain deferred to the Metal/atlas/texture-array
implementation slices. I-9 is partially visible on Landing Farm only; Graph
Theater and Notes Sidebar Skin placement remain open. I-10 was drifting because
`CompanionBodyKind` was a fixed enum and included Hermes Snake as a Farm choice.
I-15 was drifting because `GenUIDispatcher` stored erased renderer factories.

**Resolution:** This pass corrected the immediate source-level divergences:
`GenUIDispatcher` now uses a typed `@ViewBuilder` schema switch with no erased
factory registry; `CompanionBodyKind` now stores parameterized Block/Sage/Orb
Farm grammar; Hermes Snake moved out of Farm body selection into
`HermesGraphFacultyGlyph` with explicit graph z+1 placement. The remaining
I-1/I-4/I-6/I-8/I-11/I-12/I-16 runtime work stays canonical and open for the
next Simulation/Metal/Rust slices.

**Usefulness:** +1 - keeps the newly promoted 16 invariants live in the code
recovery path and prevents Farm placeholder work from masquerading as the full
Simulation runtime.

**Continuation closure:** `CompanionBodyKind(rawValue:)` now rejects unknown
Block grammar parameter values and over-long persisted tuples instead of
silently defaulting them to compact/stubs/none/filled. This keeps the §5.1
parameterized body grammar auditable at the persistence boundary while
preserving the legacy `block`, `block_compact`, and `block_wide` aliases.
Guarded by `CompanionAvatarGrammarSourceGuardTests`.

---

## 2026-05-04 - Provenance Console doctrine and first read-only GenUI slice

**Status:** Recorded during the next substrate recovery pass after the
unification inventory identified `PROVENANCE_CONSOLE_DOCTRINE` as genuinely
missing from disk.

**Drift:** T2 had durable `MutationEnvelope`, `AgentEvent`, and `GraphEvent`
storage plus separate Settings health rows, but no canonical doctrine or
schema-first console surface tying the four event planes together. Without that
surface, the MAS feature trio remained incomplete and future agents could
mistake diagnostics rows for the Provenance Console.

**Resolution:** Added
`docs/fusion/PROVENANCE_CONSOLE_DOCTRINE_2026_05_04.md`, a bounded
`EventStore.recentAgentEvents(limit:)` projection reader, and the first
read-only Settings-mounted `ProvenanceConsoleView` rendered through
`GenUIDispatcher` using `GenUIPayload.provenanceTrace`.

**Usefulness:** +1 - makes T2 provenance visible through the substrate's
schema-first UI path while preserving the no-repair/no-replay boundary.

---

## 2026-05-04 - B.1 Hermes-in-Rust seed and MAS/Pro cfg repair

**Status:** Recorded during the substrate recovery push that continued from
Stage A.4/E.0 into Stage B.1.

**Drift:** `agent_core::hermes` did not exist, so Swift remained the canonical
Hermes prompt-format and streaming tool-call parser owner. Separately, Rust
feature gates still used the legacy `mas-sandbox` cfg even though the canonical
distribution split is `mas-build` versus `pro-build`; that made the MAS/Pro
boundary depend on an old alias rather than the active build features.

**Resolution:** Added the first `agent_core::hermes` module boundary with tested
`prompt_format` and `function_call` implementations, plus explicit follow-up
module boundaries for skills, procedural memory, and self-evolution. Repaired
the Rust cfg spine so Pro-only modules and registrations use
`feature = "pro-build"` while Core B.1 tools such as `file_ops`, `memory`,
`skills`, and `web_fetch` remain registered under `mas-build`.

**Usefulness:** +1 - moves Hermes from UI shell toward the canonical Rust
runtime without weakening the MAS distribution boundary.

**Follow-up correction:** The Xcode `build-agent-core.sh` prebuild script still
compiled direct/debug builds with Cargo defaults, which meant the direct Swift
target linked the MAS-flavored Rust dylib and logged `mas_sandbox` as an
unexpected runtime profile. The script now compiles App Store builds with
`--no-default-features --features mas-build` and direct builds with
`--no-default-features --features pro-build`, guarded by
`agent_core/tests/mas_pro_feature_gates.rs`.

---

## 2026-05-04 - Hermes brand E.0 font-token correction

**Status:** Recorded after E.0 inspection while continuing the canonical
Hermes recovery pass.

**Drift:** `HermesBrand` requested `InterVariable`, but the app bundles
`Inter-Regular.ttf`, `Inter-SemiBold.ttf`, and `JetBrainsMono-Regular.ttf`.
`LiquidGreeting` also kept the Hermes Agent hero phrase on generic
`AppDisplayTypography`, so the brand surface could silently fall back and fail
to make E.0.4 visible.

**Resolution:** Added `HermesBrandSourceGuardTests`, switched
`HermesBrand.display` to bundled `Inter-SemiBold`, `HermesBrand.body` to bundled
`Inter-Regular`, `HermesBrand.mono` to bundled `JetBrainsMono-Regular`, and
routed `LiquidGreeting.hermesHeroMode` through `HermesBrand.display`.

**Usefulness:** +1 - prevents invisible font fallback from flattening the
Hermes Agent brand recovery back into generic landing typography.

---

## 2026-05-04 - B.1 Hermes skills ownership facade

**Status:** Recorded during the Hermes-in-Rust Phase 2 recovery pass after
`prompt_format` and `function_call` were already live.

**Drift:** Runtime skill call sites still imported the old parallel surfaces
directly: `skill_router`, `storage::skills_registry`, and `tools::skills`.
That preserved behavior, but it kept the ownership boundary outside
`agent_core::hermes::skills`, contrary to the Cognitive Kernel audit's Rule 4
collapse path.

**Resolution:** Added a behavior-preserving `agent_core::hermes::skills`
facade that owns the public router, registry-store, and tool-facade surface.
Redirected `bridge`, `dispatcher`, `context_loader`, and `tools::registry`
through the Hermes skills module, guarded by `hermes_runtime`.

**Usefulness:** +1 - turns the skills consolidation from a stub into a live
B.1 ownership boundary without bulk-moving the 1,700-line tool facade before
the next procedural-memory slice is ready.

---

## 2026-05-04 - B.1 Hermes procedural-memory SQLite seed

**Status:** Recorded during the Hermes-in-Rust Phase 2 recovery pass after the
skills ownership facade went live.

**Drift:** `agent_core::hermes::procedural_memory` was only a draft type while
the only procedural-memory semantics lived indirectly in the skills tool and
registry counters. That left Phase 2 without the durable outcome store required
by Cognitive Kernel doctrine §4.4.

**Resolution:** Added `ProceduralMemoryStore` with a SQLite
`procedure_outcomes` table, deterministic write/read round-trip, context
similarity, recency decay, and success weighting. Guarded it with
`hermes_runtime` tests for outcome recording and decay-ranked recall.

**Usefulness:** +1 - establishes the durable procedure-outcome boundary that
`hermes::self_evolution` can consume without creating a second memory store.

---

## 2026-05-04 - B.1 Hermes self-evolution proposal seed

**Status:** Recorded during the Hermes-in-Rust Phase 2 recovery pass after
procedural memory gained a durable outcome store.

**Drift:** `agent_core::hermes::self_evolution` was only a draft struct, so the
NousResearch self-evolution pattern described by Cognitive Kernel doctrine
§4.5 had no shipping Rust boundary.

**Resolution:** Added a deterministic proposal seed that consumes successful
`ProcedureOutcomeRecord` sequences, detects repeated tool-call traces, and
synthesizes a reviewable `SkillEvolutionCandidate`. Promotion remains separate
and gated; failed or under-repeated sequences do not propose skills.

**Usefulness:** +1 - gives future AgentEvent-ring integration and Sovereign
Gate confirmation a real Rust proposal object instead of another placeholder.

---

## 2026-05-04 - B.1 Hermes bridge ABI and canonical skill layout repair

**Status:** Recorded during the Hermes-in-Rust Phase 2 recovery pass after
skills, procedural memory, and self-evolution gained live Rust boundaries.

**Drift:** The bridge only exposed prompt formatting and tool-call parsing.
The new skills/procedural-memory modules were not reachable from Swift/XPC
callers, and `SkillRouter` only loaded flat `skills/*.md` files while the
active skill tool facade uses canonical `skills/name/SKILL.md` directories.

**Resolution:** Added UniFFI records and entry points for `list_skills`,
`write_procedure`, `record_skill_outcome`, and `recall_procedure`. Updated
`SkillRouter` to scan canonical nested `SKILL.md` files up to the existing
skill-directory depth.

**Usefulness:** +1 - makes the B.1 Rust work callable across the single kernel
ABI and prevents routing from missing the same skills the tool facade can
manage.

---

## 2026-05-04 - B.1 Hermes invoke_skill ABI seed

**Status:** Recorded during the Hermes-in-Rust Phase 2 recovery pass after the
skills/procedural-memory bridge became callable.

**Drift:** Cognitive Kernel doctrine §3 names `invoke_skill(...)` as part of
the single kernel ABI, but the bridge still stopped at skill listing and
procedure recall. That left skill execution as an implicit future path instead
of an addressable Rust boundary.

**Resolution:** Added `SkillResultFFI` and async `invoke_skill(...)`. The seed
loads canonical `skills/name/SKILL.md` entries from the profile, parses
declared `metadata.epistemos.steps` / top-level `steps`, executes path-bound
`skills_list` and `skill_view` steps against that profile, and falls back to
the tier-gated tool registry for other permitted tool steps. Direct
`skill_manage` remains blocked here because cross-session skill persistence
belongs behind the Sovereign Gate promotion path.

**Usefulness:** +1 - closes the missing B.1 ABI hole with an executable,
test-covered skill path while keeping the larger model-loop skill composer and
promotion workflow explicit future slices.

---

## 2026-05-04 - Worktree prototype canon fusion queue

**Status:** Recorded after the user clarified that the worktrees should be
treated as high-value research/prototype docs, not disposable session
ephemera.

**Drift:** `CANONICAL_UNIFICATION_INVENTORY_2026_05_04.md` correctly pointed at
canonical-named worktree docs, but it still left the promotion strategy too
implicit. That risked future sessions either bulk-copying donor branches or
ignoring durable prototypes such as Tools V2, ExecutionReceipt, capture
routing, heal-loop evals, honest-handle FFI, and PLAN_V2 sections 23-27.

**Resolution:** Added
`docs/fusion/WORKTREE_PROTOTYPE_CANON_FUSION_QUEUE_2026_05_04.md`, linked it
from the master index and unification inventory, and added
`agent_core/docs/TOOL_MIGRATION_STATUS.md` as the first Tools V2 recovery
anchor. The queue keeps the no-bulk-copy rule while treating every worktree as
a prototype-canon input until classified by Track and recovery stage.

**Usefulness:** +1 - preserves the user's prototype work as named substrate
rather than forcing later agents to rediscover or flatten it.

## 2026-05-04 - Quick Capture receipt and routing bridge docs

**Status:** Promoted as bridge doctrine after reading the Quick Capture donor
receipt, route, grammar, and schema files in
`.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/`.

**Drift:** The worktree contained durable T2/T4 contracts that were easy to
flatten into generic labels: `ExecutionReceipt` as signed proof-of-execution,
and `route_capture` as a four-action Resonance Gate direction ladder. Leaving
them only in donor code would make later Sovereign Gate or capture-routing work
re-derive thresholds, schemas, capability semantics, and grammar constraints.

**Resolution:** Added
`agent_core/docs/EXECUTION_RECEIPT_DOCTRINE_MAPPING.md` and
`agent_core/docs/CAPTURE_ROUTING_CLASSIFIER.md`, then linked both from the
worktree prototype queue, master research index, and unification inventory.
These docs preserve the donor contracts while keeping implementation movement
narrow and test-gated.

**Usefulness:** +1 - keeps Quick Capture's signed execution and routing
contracts alive as named substrate without bulk-copying donor runtime modules.

## 2026-05-04 - Heal-loop fixture extraction and exit-gate drift

**Status:** Promoted as fixture doctrine after reading the Quick Capture donor
heal loop, event log, eval harness, and `heal_eval` CLI.

**Drift:** The donor `heal_eval` CLI comment says exit code 0 means
`passes_phase_11_exit()` succeeds, but the donor synthetic 30-case seed is
documented in tests as intentionally failing the stricter production exit gate:
20/30 recover within 1 backtrack (66.7%, below 85%) and 29/30 recover within
3 backtracks (96.7%, just below 97%). Treating that corpus as a ship gate would
silently weaken the intended Try-Heal-Retry standard.

**Resolution:** Added `agent_core/tests/heal_loop_fixtures.md` as a fixture
bridge. It preserves `ApplyError`, `Diagnostician`, `HealLoop`,
`HealEventLog`, the synthetic distribution, and the exit-gate contradiction.
Future ports must distinguish fixture-regression pass from production
diagnostician pass.

**Usefulness:** +1 - keeps the heal-loop prototype available for recovery while
making the donor mismatch explicit before implementation.

## 2026-05-04 - Honest-handle FFI doctrine promotion

**Status:** Promoted after comparing the D-series donor worktree's
`honest_handle.rs` files with current main.

**Drift:** Honest-handle FFI was easy to treat as a local implementation patch,
but it is actually substrate doctrine: Swift/Rust handles must expose real
ownership semantics. Shared Rust state cannot be represented as `Box::into_raw`
plus a prose "do not free while in use" convention.

**Resolution:** Added
`docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md`. The doc records the
Arc-backed opaque handle lifecycle, Swift `final class` ownership rule, panic
boundary, string-freeing convention, live main evidence for `epistemos-shadow`,
`substrate-core`, `syntax-core`, and donor evidence for `substrate-rt`.

**Usefulness:** +1 - preserves the FFI ownership rule as named canon and makes
future zero-copy work distinguish ownership handles from payload transport.

## 2026-05-04 - PLAN_V2 sections 23-27 recovery

**Status:** Promoted after reading sections 23-27 of the
`inspiring-heisenberg-ea9dc3` PLAN_V2 worktree.

**Drift:** The sections carry durable substrate rules for editor truth, syntax
data plane, agent streaming coalescing, graph zero-copy gating, implementation
order, and anti-patterns. Without a fusion bridge, future sessions could either
ignore them or bulk-copy a broader PLAN_V2 file with stale details.

**Resolution:** Added
`docs/fusion/PLAN_V2_SECTIONS_23_27_RECOVERY_2026_05_04.md`. The bridge keeps
the benchmark gates and anti-patterns while explicitly superseding PLAN_V2
§23.5's old `Box::into_raw` syntax handle note with the honest-handle Arc
retain/release doctrine now present in `syntax-core/src/honest_handle.rs`.

**Usefulness:** +1 - preserves the actionable architecture laws while
preventing an outdated handle-lifecycle detail from re-entering implementation.

## 2026-05-04 - AgentEvent v1.6 forward variant bridge

**Status:** Promoted after reading Simulation DOCTRINE §3.4.5 / §11 and
checking current Swift provenance code.

**Drift:** Simulation v1.6 adds six event variants for farm steering,
helper-model summaries, and multi-vault operations. Swift provenance already
contains those forward variants and tests, but the full Rust `agent_core::events`
spine remains absent. Future sessions could falsely count the Swift vocabulary
as the completed event system.

**Resolution:** Added `docs/fusion/AGENT_EVENT_VARIANTS_V16_2026_05_04.md`.
The bridge records the six variants, live Swift evidence, tests, honesty
semantics, and remaining Rust normalizer / append-only event-log / replay gap.

**Usefulness:** +1 - preserves the v1.6 event vocabulary while keeping the
Rust-owned event bloodstream as an explicit recovery target.

## 2026-05-04 - Five Laws and Phase I branch bridge

**Status:** Promoted after inspecting branch `codex/runtime-memory-hardening`
non-destructively with `git show` / `git grep`.

**Drift:** The branch contains durable substrate synthesis: Five Laws, four
substrate sprints, a `substrate-core` seed crystal, and a Rust-agent migration
Phase I. It also predates the current fusion recovery order and contains older
wording around Python subprocess isolation.

**Resolution:** Added `docs/fusion/FIVE_LAWS_AND_PHASE_I_2026_05_04.md`. The
bridge preserves the measurement-first, new-crate, identity-first, graduated
FFI, and pure-shipping-runtime principles while subordinating the old phase
order to current Recovery A-F / V1 / V2 / V3 canon. The old "Python
out-of-process" law is reinterpreted under current doctrine as no hidden Python
runtime in MAS/Core, with any subprocess path explicit and gated.

**Usefulness:** +1 - keeps the branch's substrate wisdom without letting stale
release sequencing or runtime assumptions override fusion canon.

## 2026-05-04 - Runtime-input-audit bridges

**Status:** Promoted after inspecting branch `codex/runtime-input-audit` and
comparing key files with current main.

**Drift:** The branch contained two active recovery truths: the code editor
feature audit and Phase R resource runtime / verified-write work. Both were
easy to miss because some artifacts already exist in main while their canonical
meaning was not fused into `docs/fusion/`.

**Resolution:** Added `docs/fusion/CODE_EDITOR_FEATURE_TRUTH_2026_05_04.md`
and `docs/fusion/RESOURCE_RUNTIME_PHASE_R_BRIDGE_2026_05_04.md`. The first
keeps editor feature claims tied to live `CodeEditorView` evidence. The second
names the permission-store bridge, fail-closed grants, readback verified writes,
and resource audit log as T2/Sovereign Gate substrate.

**Usefulness:** +1 - makes "visible editor truth" and "verified writes with
grants" first-class recovery inputs instead of scattered branch history.

**Continuation closure:** A full `agent_core` audit run exposed a parallel-test
race, not a product policy regression: R.5 registry tests and resource-bridge
tests used separate module-local locks while mutating the same OnceLock-backed
permission store. The store/env test gates now live in shared
`agent_core::test_support`, and the full default `agent_core` test floor passes
again with R.5 enabled.

### Gap Addendum - recipe cache and release-stabilization bridges

**Observed:** The `codex/post-audit-feature-work` branch was still described as
needing a cherry-pick even though `agent_core/src/storage/recipe_cache.rs` is
already present and exported in current main. The
`codex/release-stabilization-and-runtime-hardening` branch was still described
as "verify superseded" even though its Epistemos Release Audit skill and March
release prompt are already present in main.

**Drift:** The docs confused "artifact missing" with "artifact unwired." Recipe
cache is a wiring/provenance problem, not a recovery-copy problem. Release
stabilization is a Stage F verification source, not a branch-order source.

**Resolution:** Added
`docs/fusion/RECIPE_CACHE_RECOVERY_BRIDGE_2026_05_04.md`,
`docs/fusion/RELEASE_STABILIZATION_BRANCH_BRIDGE_2026_05_04.md`, and
`docs/fusion/WORKTREE_FUSION_BRAINSTORM_2026_05_04.md`. Updated the prototype
queue, master index, and unification inventory to point at them.

**Usefulness:** +1 - keeps the branch work alive without misleading future
agents into raw cherry-picking stale branch state.

### Gap Addendum - Lane A prompt-as-data worktree is active

**Observed:** `git worktree list` includes
`/Users/jojo/Downloads/Epistemos-laneA` on branch `lane-A`, 601 commits ahead of
`main`. Current main already contains the Prompt Tree foundation files and
`agent_core/src/session_insights.rs`, but `git diff lane-A -- ...` still shows
meaningful deltas in `ChatCoordinator`, `agent_core/src/bridge.rs`,
`agent_core/src/providers/claude.rs`, `session_insights.rs`, and
`docs/PROMPT_AS_DATA_SPEC.md`.

**Drift:** Earlier canon correctly warned that Lane A was not "mostly merged,"
but the prototype queue only listed `.claude/worktrees/*` and the `codex/*`
branches. That made the live `/Users/jojo/Downloads/Epistemos-laneA` worktree
easy to omit during whole-worktree fusion.

**Resolution:** Added
`docs/fusion/PROMPT_TREE_LANE_A_BRIDGE_2026_05_04.md` and linked it from the
prototype queue, master index, unification inventory, and brainstorm. The bridge
names Lane A as a reconciliation target, not a raw merge target.

**Usefulness:** +1 - preserves N1 Prompt Tree / prompt-as-data work as active
substrate canon and prevents future agents from closing prompt-cache telemetry
without comparing the Lane A deltas.

## 2026-05-04 - D3 closed A2UI catalog Phase-1 seed

**Status:** Recorded during the canonical audit reconciliation continuation.

**Drift:** The 2026-04-26 canonical audit correctly flagged D3 because no
closed A2UI catalog existed. Cognitive UI doctrine requires a closed catalog
with no fallback inspector, and the local A2UI brief names `NoteCard` as the
Phase-1 seed surface. Leaving the project at "no catalog" kept the app
doctrinally safe only by omission.

**Resolution:** Added `Epistemos/A2UI/` with closed
`A2UICatalog.allComponents == [.noteCard]`, typed `A2UINoteCard`,
`A2UIValidator`, and `A2UIValidationFailure(code: "VALIDATION_FAILED")`
emitting a typed `GenUIPayload.errorReport` audit payload. Added Rust schema
authority at `agent_core/src/a2ui/schemas.rs` using `schemars`, with
`closed_catalog_component_names()` and a `NoteCard` JSON Schema. Guarded the
slice with `EpistemosTests/A2UICatalogTests.swift` and
`agent_core/tests/a2ui_schemas.rs`.

**Usefulness:** +1 - closes the original "A2UI absent" blocker without
pretending the full ~25-component catalog is done. Future work is catalog
expansion and cross-runtime payload unification, not reopening fallback UI.

## 2026-05-04 - Quick Capture Tier B `effect/` selective port

**Status:** Recorded while continuing the post-recovery substrate queue after
Tier A salvage verification.

**Drift:** `format/`, `canon`, `grammar`, and `undo` had already landed as
selective Tier A ports, but the next canonical Quick Capture stage still had no
live `agent_core::effect` module. That left `undo` storing JSON-shaped effects
instead of a typed Intent→Effect boundary and kept future `heal` / `route`
integration without a shared failure and inverse surface.

**Resolution:** Added `agent_core/src/effect/` with typed `Effect`, `Inverse`,
`ApplyError`, `PriorState`, `IntentApplier`, `IntentDispatcher`,
vault/concept/memory appliers, and `ExecutionReceipt` hash/MAC verification.
The port adapts the salvaged source instead of raw-copying it: missing
`util::atomic_write_bytes` became local atomic-write helpers, and memory ULID
validation reuses the landed `format` canonical alphabet rather than adding a
new crate. Guarded by `agent_core/tests/effect_salvage.rs`.

**Usefulness:** +1 - establishes the typed Intent→Effect spine needed by
`heal`, `nightbrain`, and `route`. Ed25519 / Keychain / Secure Enclave receipt
signing remains a named trust follow-up; this slice does not collapse that
future requirement into the HMAC placeholder.

## 2026-05-04 - Quick Capture Tier B `heal/` selective port

**Status:** Recorded after `effect/` landed and before continuing to the next
Tier B substrate slice.

**Drift:** The salvaged Try-Heal-Retry loop carried its own `ApplyError`
taxonomy and referenced an older breaker path. Current main already had the
bit-packed `CircuitBreaker` and now has `effect::ApplyError`, so raw-copying
would have split the failure surface in two.

**Resolution:** Added `agent_core/src/heal/` with `HealLoop`,
`Diagnostician`, `GiveUpDiagnostician`, a canonical breaker re-export, and
`HealEventLog` SQLite persistence for `heal_events`. The port consumes
`effect::ApplyError` directly, records recovered/abandoned outcomes, and keeps
recurring-pattern detection (`same tool + same error kind >= 10 events in 7
days`). Guarded by `agent_core/tests/heal_salvage.rs`.

**Usefulness:** +1 - makes failed Intent→Effect application a bounded,
observable recovery step instead of an untyped retry. LLM-bearing
diagnostician wiring and Swift trace UI surfacing remain host follow-ups.

## 2026-05-04 - Quick Capture Tier B `nightbrain/` scheduler core selective port

**Status:** Recorded after the `heal/` port while continuing the Tier B
substrate queue.

**Drift:** The salvaged NightBrain scheduler depended on a Rust
`lifecycle::idle_monitor::IdleMonitor` module that does not exist in current
main. Current Epistemos already has Swift-side NightBrain and macOS probes, so
raw-copying the salvage would have invented a second host-activity authority.

**Resolution:** Added `agent_core/src/nightbrain/` with
`NightBrainScheduler`, `HostActivitySnapshot`, shared `CancellationToken`,
`NightBrainTask`, `TaskCtx`, `TaskOutcome`, the 60-second default idle
threshold, and the canonical Plan §7.1 worker-pool cap. The Rust core accepts a
host snapshot rather than owning AppKit / IOKit probes. Guarded by
`agent_core/tests/nightbrain_salvage.rs`.

**Usefulness:** +1 - preserves the single-process NightBrain scheduler and
preemption contract without splitting macOS probe ownership. Swift
battery-percent snapshot wiring landed immediately after this Rust core slice;
Swift/UniFFI exposure remains the named host follow-up before this becomes the
full runtime scheduler.

**Continuation closure:** The stale-run foreground fallback now calls
`NightBrainService.runInlineFallback()` and records
`NightBrainScheduler.recordSuccessfulRun()` only when the pipeline returns
`.finished`. This closes the prior false-positive success path where fallback
called `start()` (scheduler registration) and marked the run successful without
executing the pipeline.

**Continuation closure:** The Rust scheduler now owns live in-process task
registration: `NightBrainScheduler.register_task(_)`, duplicate task-name
rejection, stable `registered_task_names()`, and ordered
`run_registered_tasks()` execution that stops on preemption. Guarded by
`agent_core/tests/nightbrain_salvage.rs`. The remaining host seam is exposing
that Rust scheduler registry through Swift/UniFFI without duplicating the
macOS probe authority already owned by `NightBrainService` / `PowerGate`.

**Continuation closure:** Swift/UniFFI now exposes the non-probe NightBrain
contract without moving macOS authority into Rust: `nightbrain_canonical_task_names`
returns the canonical host task registry and `nightbrain_preview_admission`
returns the Rust admission decision, reason, idle threshold, and worker-pool cap
from a Swift-supplied snapshot. Guarded by
`agent_core/tests/nightbrain_salvage.rs` and
`EpistemosTests/CognitiveSubstrateTests.swift`, which compares the Rust task
names to `NightBrainService.Job.allCases`. The remaining host seam is narrower:
wire a Swift-owned execution handle / object lifecycle into the Rust scheduler
for real registered task execution, while keeping AppKit / IOKit probes on the
existing Swift side.

## 2026-05-04 - Quick Capture Tier B `route/` ladder core selective port

**Status:** Recorded after the NightBrain scheduler core while closing the
remaining Tier B Rust salvage modules.

**Drift:** The salvaged `route/` module encoded the right four-variant
`structure.route_capture` ladder, but it referenced a divergent
`cache::EmbeddingProvider` and raw schema files that were not present in current
main. Leaving it as salvage-only kept Quick Capture without the canonical
`place | merge_into_existing_note | create_folder | defer` routing spine.

**Resolution:** Added `agent_core/src/route/` with typed `RouteInput`,
`RouteDecision`, `Action`, `EmbeddingProvider`, `RouteCtx`, Variant A centroid
routing, Variant B classifier grammar/sentinel contract, Variant C
concept-anchored merge/create-folder logic, and Variant D review-inbox fallback.
The port keeps the canonical floors (0.85 / 0.75 / 0.70), merge gates
(0.90 + >24h), create-folder gates, and 280-character reasoning-trace cap.
Guarded by `agent_core/tests/route_salvage.rs`.

**Usefulness:** +1 - closes the Rust-core Tier B route recovery without
pretending the live host implementations are done. Folder-medoid persistence,
MLX/GBNF classifier wiring, and concept/neighbour providers remain named
follow-up slices.

**Continuation closure:** Variant A now has durable folder-medoid persistence
via `FolderMedoidStore`: SQLite WAL / `synchronous=NORMAL`, deterministic
path-ordered loading, finite-vector validation, and reload-to-route tests.
Variant B now also uses a single deterministic closed-vocabulary helper for
schema construction and runtime acceptance: non-inbox paths are sorted,
deduplicated, and classifier outputs outside that closed set fail closed even
when their confidence clears 0.75. Remaining Route host follow-ups are
MLX/GBNF classifier wiring and concept/neighbour provider implementations.

**Continuation closure:** Swift/UniFFI now exposes the safe Route host contract:
`route_capture_contract` publishes the schema IDs, canonical action wire names,
floors, merge/create-folder gates, reasoning-trace cap, and review-inbox
fallback, while `route_variant_b_schema_json` lets Swift build the deterministic
Variant B closed-vocabulary schema from current vault paths. Guarded by
`agent_core/tests/route_salvage.rs` and
`EpistemosTests/CognitiveSubstrateTests.swift`. Remaining Route host follow-ups
are now narrower: wire the MLX/GBNF classifier and real concept/neighbour
providers into the live Quick Capture path.
