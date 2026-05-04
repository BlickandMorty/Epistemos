# Canon Gaps and Pre-Drafted Addenda — 2026-05-02

> **NEW DOC — created 2026-05-02.** Filename: `CANON_GAPS_AND_ADDENDA_2026_05_02.md`. If your session can't find it, search by name. Sister docs: `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`, `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md`, `CODEX_DELIBERATION_PROMPT_2026_05_02.md`, `WORKTREE_INSIGHT_SALVAGE_2026_05_02.md`, `ALL_DOCS_INDEX_2026_05_02.md`. Mirrored into the active worktree's `docs/fusion/`.

> **STATUS — STAGED, NOT MERGED.** This doc holds the addenda that the user identified by reconciling their original master plan against the new canon (doctrine + Codex prompt + salvage map + index). The gaps are real but **the merge into the four canon files is held until Codex's deliberation response lands.** This is a deliberate sequencing choice — patching while Codex is mid-deliberation risks breaking section anchors and bypasses the deliberation prompt's "flag gaps" purpose.
>
> **When the user authorizes the merge** (single chat command), every block marked `MERGE TARGET:` below is lifted verbatim into its destination file. This doc remains afterward as the audit trail.

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

### C1 — WRV doctrine (Wired + Reachable + Visible + Verified)

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

### C2 — No silent cloud fallback / escalation

**Original plan:** *"No silent backend or cloud switching. Local-first, private by default, optional BYOK cloud, no silent fallback/escalation."*

**Current canon:** Doctrine §6 forbids "hidden cloud calls" — close, but does not forbid silent fallback or automatic escalation when local can't answer.

**Severity: High.** Auditability invariant.

**MERGE TARGET:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §6 Hard Forbidden List, append:

```md
- **Silent cloud fallback or escalation.** If a request is about to leave the device, the user sees an explicit opt-in prompt for that specific request OR has previously enabled the provider in Settings with a clear "use this for X" scope. No automatic "I couldn't answer locally, let me try cloud" behavior in any tier. The transition from local → cloud is always a UI event the user can audit.
```

---

### C3 — BYOK cloud OFF by default

**Original plan:** *"Optional BYOK cloud off by default."*

**Current canon:** Not explicit. Doctrine §3 lists cloud providers as Core-tier capability; nothing says default state.

**Severity: High.** Privacy default.

**MERGE TARGET:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §6 Hard Forbidden List, append:

```md
- **BYOK cloud providers enabled by default.** Default state for every cloud provider (Anthropic, OpenAI, Perplexity, etc.) is OFF on a fresh install. The user must explicitly add a key in Settings AND toggle the provider on. No marketing-defaults that pre-enable cloud routing.
```

---

### C4 — UX posture: one composer, two modes, separate effort, tools as capabilities

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

### C5 — No second source of truth (visuals project from canonical state)

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

### C6 — Halo specific stack reference

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

**Current canon:** Resource Runtime / grants / verified writes live on `codex/runtime-input-audit` (DIVERGED, 324 commits, never merged — salvage §6). `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 H1 corrects the older PromptTree claim: Lane A is **not** mostly merged; it has 601 unmerged N1 Prompt Tree commits plus `PROMPT_AS_DATA_SPEC.md` and full PTF work behind `EPISTEMOS_PROMPT_TREE=1`. Names don't appear in doctrine.

**Severity: High.** Phase R is the named Core release substrate.

**MERGE TARGET 1:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §9 Canonical Code Anchors — add new rows:

```md
| Resource Runtime + grants + verified writes (Phase R) | unmerged: `codex/runtime-input-audit` branch (324 commits ahead of main, never landed). Files include vault write authorization pipeline, attachment path exposure, sandbox grant seeding | **DIVERGED** — cherry-pick now per Salvage §6 |
| PromptTree / N1 | Lane A donor is **601 unmerged commits** per `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 H1. Canonical donor docs: `/Users/jojo/Downloads/Epistemos-laneA/docs/PROMPT_AS_DATA_SPEC.md` and `/Users/jojo/Downloads/Epistemos-laneA/docs/plan/prompts/N1_prompt_tree.md` | Do not claim mostly merged. Verify main with `rg "prompt.cache.tokens.share|EPISTEMOS_PROMPT_TREE|PromptTree" Epistemos agent_core docs` before assigning or closing |
| Phase R / Phase S release substrate | `docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` + `docs/_consolidated/30_canonical_operational/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` (mirrored copy) | Authority for App Store closeout state |
```

**MERGE TARGET 2:** `WORKTREE_INSIGHT_SALVAGE_2026_05_02.md` §6 codex/* branches — promote `codex/runtime-input-audit` to "**Cherry-pick now (Phase R closure depends on it)**" in bold; already there at high priority but emphasis needed.

---

### C8 — APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24

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

### C9 — Quick Capture standalone canon

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

### C10 — Flight Recorder (named subsystem)

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

### C12 — Local-stream truncation/flush fix preservation

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

### C13 — Telemetry sensitivity / retention / consent

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

### C14 — `ambient_V1_DECISION.md` explicit naming

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
