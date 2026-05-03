# Codex Reconceptualization Handoff + Verify Ask — 2026-05-03

> **For Codex.** Final-bow handoff after the substrate reconceptualization landed. **Two asks**: (1) integrate the new vision into the build sequence, (2) verify the plan is still coherent. Sister docs: `JORDANS_RESEARCH_INDEX_2026_05_03.md` (source map for the executive adds), `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` (the substrate vision), `CODEX_TASK_CONTINUITY_HANDOFF_2026_05_03.md` (catch-up on what shipped while the account changed).

---

## TL;DR

1. **Read the four sister docs first** (in the order in `CODEX_TASK_CONTINUITY_HANDOFF_2026_05_03.md` §6).
2. **Verify the plan in `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md`** is still coherent against current code + canon. Flag conflicts in `CANON_GAPS_AND_ADDENDA_2026_05_02.md` if any.
3. **Ship the hackathon block first** — Hermes XPC + Simulation Mode v1.6 with full assets, companion creation UI/UX, adapter UI, delete/restore flows, home window. The user explicitly emphasized these.
4. **Then resume the M1/M2/M3 sequence** from `CODEX_HANDOFF_2026_05_03_PART2.md`.

---

## 1. The user's explicit emphasis (READ THIS BEFORE SLICING)

These are the user's words, paraphrased for clarity but **load-bearing**:

### 1.1 "Hermes agent CLI and multi-CLI" must be implemented as USABLE features, not just architecture

The reconceptualization in §4 of `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` describes Hermes as an XPC service. **That's the architecture.** The user's ask is for the **product surface on top of it**:

| Surface | What "implemented" means |
|---|---|
| **Hermes agent CLI passthrough** | The user can type a Hermes-compatible command and it actually executes through Hermes via ProviderXPC. Round-trips with provenance. |
| **Multi-CLI orchestration** | Multiple delegated CLIs (Claude Code, Codex, Gemini CLI, Kimi) routable through ProviderXPC with the existing `HermesGatewayPolicy` route classification. The user picks the CLI; the substrate routes; the AgentEvent stream is uniform. |
| **First-party tool catalog** | The 26 Hermes parity commands shipped as `HermesCommandDispatcher` are wired through the chat input surface. The user sees `/help` and gets a real listing; types `/calc 2+2` and gets `4`; types `/todo add X` and an item appears in the native task ledger. |
| **Provider switching UX** | One settings panel that boils down to a credentials manager (Anthropic, OpenAI, Google, Perplexity) and a "Pro profile / App Store profile" toggle, per `deterministicapp.md` §1.4 minimal-UX rule. |

**Acceptance bar for the hackathon demo:**

- Open the app cold.
- Type `/help core` in chat → see the Core-tier parity slate.
- Type `/calc 2*pi` → see `6.28...`.
- Type `/ask why is X important` → cloud provider responds via Hermes through ProviderXPC, with provenance row in the Provenance Console.
- Type `/run echo hello` (Pro tier only) → routed through CLI passthrough, returns output, AgentEvent recorded.
- Switch active provider in Settings → next `/ask` uses the new provider.

If any of those steps don't work end-to-end at the hackathon demo, the Hermes integration is not done.

### 1.2 "Simulation gets done" — full assets + companion creation + delete/restore + adapter UI + home window

Per `simulation` worktree `docs/simulation-mode/DOCTRINE.md` v1.6 invariants, Simulation Mode v1.6 is **not** an animated decoration. It's a deterministic visual projection of the real agent runtime. The user's ask: ship it **complete**, not prototype-grade.

**Concrete acceptance bar — what "full assets" means:**

| Surface | What ships in the hackathon block | Doctrine reference |
|---|---|---|
| **Companion creation flow** | User opens Settings → Companions → "Create New Companion". Picks a base ModelProfile (Qwen / Hermes / Apple Intelligence). Customizes appearance (visual). Customizes behavior (every cosmetic choice maps to a real `ModelProfile` config knob OR is explicitly `cosmetic` per Invariant I-10). Names it. Saves. New companion appears in the Landing Farm. | I-10 Customization choices map to real config |
| **Companion delete flow** | User long-presses a companion → "Delete companion?" sheet → Touch ID gate (Sovereign Gate per Sovereign Gate Core PR1+ pattern) → removed from registry → animation plays out (companion fades / leaves the farm). | Doctrine §6 + Sovereign Gate Core |
| **Companion restore flow** | Trash / archive surface where deleted companions can be restored within a time window. Same Touch ID gate. AgentEvent emitted. | Same |
| **Adapter UI** (the LoRA unwrap animation) | When the user applies a SEAL-DoRA adapter (Pro tier) or a LoRA weight set, the **unwrap animation duration ≥ adapter apply duration** (Invariant I-11). Apply fails → unwrap shows failure state. Animation never completes ahead of the work. | I-11 Adapter unwrap animation duration |
| **Home window (Landing Farm placement)** | App opens → Landing Farm visible by default → companions present, idle-breathing animation when no events, react to incoming AgentEvents in real time. Companions selectable; clicking opens companion-specific session view. | I-9 Three placements (Landing Farm) + §3 |
| **Notes Sidebar Skin placement** | Companions also visible in the Notes sidebar surface — slimmer skin, same companion identity, same AgentEvent reactions. | I-9 + §3 |
| **Graph Live Theater placement** | (Defer to post-hackathon if it requires `MetalGraphView` edits — that's a protected path. Ship if it can be done without touching protected paths.) | I-9 + §3 |
| **Determinism + replay** | Given the same event log + same `DeterministicAnimationSeed`, the simulation produces pixel-identical playback. No `Date.now()` / `random()` / system-clock leaks into the reducer. | I-13 |
| **Reduce-motion fallback** | When system reduce-motion is on, all sprite animation collapses to static pose + state badge + audit-readable text. Companions still visibly enter/exit. | I-14 |
| **App Store shippability** | Simulation Mode core is MAS-safe — no shell, no `Process()`, no AX outside entitlements, no arbitrary file import. Pro-only power features (adapter sideload, raw subprocess spawning) live behind compile gates. | I-12 |

**Critical doctrine invariants from the simulation worktree (DO NOT VIOLATE):**

- **I-3 AgentEvent is the runtime bloodstream.** Simulation never reads provider-specific payloads. Only `AgentEvent`. (You already shipped AgentEvent provenance through PR44 — every Bridge file emits `AgentEvent`. Simulation reads from there.)
- **I-4 GraphEvent is the proof of mutation.** Any change to the graph emits a `GraphEvent`. Simulation animates from `GraphEvent` only. No animation may imply a graph mutation that didn't happen.
- **I-5 Every animation maps to a real event.** A "thinking" pose without a backing `thinking_started` event is a defect. Period.
- **I-6 Native rendering only.** Swift 6.2 / SwiftUI / AppKit / Metal. Full Bevy forbidden as the app spine. `bevy_ecs` conditionally allowed post-S12.
- **I-7 Rust owns simulation state. Swift owns rendering and lifecycle.** Reducer + registry + persistence + hysteresis + event log live in Rust. Metal renderer + view-models + MainActor lifecycle live in Swift.
- **I-8 FFI is zero-copy where measured to matter.** Frame deltas via `UnsafeBufferPointer<PerInstanceData>` into `MTLBuffer`. Atlas textures via `IOSurface`. Hot deltas (>100 Hz) via lock-free SPSC ring buffer in shared memory; **UniFFI forbidden for hot deltas.**
- **I-15 No production hot path may use string-keyed dispatch, `AnyView`, allocation in render frames, or main-thread Metal pipeline compilation.** Pre-compile pipelines via `MTLBinaryArchive`. Compile-time enum routing. Pre-allocate buffers.

**The 6 v1.6 AgentEvent forward variants** flagged in `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 honest discovery H6 (`SteerRequested`, `SummaryStarted/Delta/Completed`, `VaultCreated`, `VaultArchived`) **must be added to main's enum** before Simulation v1.6 lands. Currently in worktree only.

### 1.3 The user wants this VERIFIED, not just shipped

You are also being asked to **verify the plan is still coherent**. Specifically:

- Read `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md`. Does the convergence-table (§1) hold against current code? Are the 9 already-shipped pieces actually shipped?
- Does the capability lattice (§3) match the doctrine §3 + §6 hard forbidden list?
- Are the 4 architectural commits (§5) consistent with the existing AppBootstrap + Sovereign Gate + ToolTierBridge architecture?
- Does the hackathon-priority sequencing (§4) actually unblock the M1/M2/M3 follow-ups, or does it create a new blocker?

If any of those checks fail, **flag in `CANON_GAPS_AND_ADDENDA_2026_05_02.md` as a new addendum** and stop until the user resolves.

---

## 2. The integration ask — make these real, not just architectural

The user's no-compromise direction means **all of Helios + MAS Core + Hermes + deterministicapp + SCOPE-Rex Omega** lands eventually. The hackathon block only cherry-picks the two highest-leverage pieces. Everything else follows.

### 2.1 Hackathon-block deliverables (Week 0 through Week 4)

**Week 0 (parallel, half-day):**
- KV-Direct gate experiment per Helios v3 Week 1. Half-day. Binary outcome.

**Week 1 (App Group migration — foundation for both blocks):**
- All shared state moves to `group.com.epistemos.shared` per `mac store edition.md` §"App Group container".
- File-backed `mmap(MAP_SHARED)` arena per `hermes.md` §"Keeping the substrate unified and zero-copy".
- Existing AgentEvent / EventStore / Vault sync rewires here. Non-breaking — same APIs, different storage location.

**Week 2-3 BLOCK A — Hermes XPC + multi-CLI integration:**
- AgentXPC service skeleton + capability grants (HMAC-scoped, time-bounded) per `mac store edition.md` §"Capability grants" and `agent_core/src/effect/receipt.rs` `Capability::BiometricSession` donor pattern.
- ProviderXPC service skeleton — handles all cloud provider HTTP. Existing `HermesGatewayPolicy` route classification stays intact.
- The 26 Hermes parity commands run inside AgentXPC.
- Multi-CLI passthrough (Pro tier) — Claude Code / Codex / Gemini CLI / Kimi routable through ProviderXPC.
- Chat input surface intercepts `/...` commands and routes through `HermesCommandDispatcher.parseCore`.
- Acceptance bar from §1.1 above.

**Week 2-3 BLOCK B — Simulation Mode v1.6 with full assets:**
- Resolve the 6 v1.6 AgentEvent forward variants into main's enum.
- Rust simulation reducer + registry + event log per Invariant I-7.
- Metal renderer + Swift lifecycle per Invariant I-7.
- IOSurface-backed atlas + lock-free SPSC ring for hot deltas per Invariant I-8.
- Companion creation flow (Settings → Companions → Create New) per §6 + Invariant I-10.
- Companion delete flow with Sovereign Gate Touch ID gate.
- Companion restore flow (trash/archive surface).
- Adapter UI — LoRA unwrap animation tied to real apply duration per Invariant I-11.
- Home window (Landing Farm placement) — companions visible by default per Invariant I-9.
- Notes Sidebar Skin placement.
- Graph Live Theater placement IF possible without touching `MetalGraphView` (protected path); otherwise defer.
- Reduce-motion + determinism + replay per Invariants I-13 + I-14.
- App Store shippability per Invariant I-12.
- Acceptance bar from §1.2 above.

**Week 4 — Provenance Console UI:**
- The third MAS-feature trio member (Vault Guard ✅ already, Bounded Agent Service ✅ comes with BLOCK A, Provenance Console ⏸ now).
- Existing AgentEvent rows get a UI surface per `mac store edition.md` §"Audit console" wireframe.
- Filter / search / export.

### 2.2 Post-hackathon — resume the prior sequence

After the hackathon block ships, resume `CODEX_HANDOFF_2026_05_03_PART2.md` recommended next 3-slice batch:

- M1: Mount Resonance chip into one production surface (chat or Halo)
- M2: Wire `HermesCommandDispatcher.parseCore` into the chat input surface (this may already be partially done in BLOCK A — verify)
- M3: Swap `ResonanceService.computeStub` for the FFI call (`agent_core::bridge::compute_resonance_signature_core`)
- S1: Stream-integrate Resonance signatures into chat token stream
- S2: Sherry 1.25-bit ternary on residual (Lane 6 — pure Rust scaffolding can start any time)
- S3: MAS/Core symbol separation closure (gates Lane 4 ship)

### 2.3 The mid-horizon (Q3 2026, post-MAS submission)

Per `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` §3 capability lattice:

- Pro tier ship: Developer ID + Notarization, broader providers, `SMAppService` background, multi-CLI passthrough fully active
- L_SE Self-Evolving (Titans-MAC + SEAL-DoRA) behind Pro feature flag with `‖e‖` telemetry mandatory
- Resonance Gate δ + ρ (Pro tier) — adds direction + resonance components
- Sherry 1.25-bit ternary on weights (measurement-driven)
- Provenance Console wider filter

### 2.4 The long horizon (post-Pro)

- Resonance Gate κ + η (Research tier — η backed by L_SE surprise gradient per Helios v3 §VI.2 #1)
- Direct ANE path via `_ANEClient` (Research)
- KV implantation via `MTLBuffer.contents()` (Research)
- Sherry 1.25-bit ternary scaffolding to maturity (Lane 6)
- WBO-6 budget doc as living artifact tracking each tier's perturbation

---

## 3. The verify ask — Codex, please confirm

After reading the four sister docs, please verify and either confirm or flag:

### 3.1 Convergence verification

For each of the 14 reconceptualization pieces in `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` §1 ("convergence" table), confirm:

- ✅ The named existing surface actually exists (grep / cargo / xcodebuild proves it)
- ⚠️ Or: the named existing surface is partial / drifting / missing

Output format: a new section appended to `CANON_GAPS_AND_ADDENDA_2026_05_02.md` titled "Reconceptualization convergence audit — 2026-05-03" with one row per piece + verdict + evidence path.

### 3.2 Capability lattice verification

For each row in `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` §3 (Helios tier × MAS tier × hackathon priority), confirm:

- The Core / Pro / Research split matches doctrine §3 + §6
- The hackathon-priority flag matches the user's emphasis (Hermes XPC + Simulation v1.6 first)
- No tier-leakage anti-pattern (e.g. a Pro-only feature accidentally listed for Core)

If any row needs revision, propose the change and stop until user approves.

### 3.3 Architectural-commit verification

For each of the 5 commits in `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` §5, confirm:

- The pattern is consistent with existing code (e.g. AppBootstrap @Observable services for state, Sovereign Gate for biometric gating, ToolTierBridge for Core/MAS distribution gating)
- No fork of the architecture (per `mac store edition.md` migration plan)
- The XPC + App Group design works under Epistemos's exact sandbox config (this may need a small POC before week 2 starts)

### 3.4 Hackathon sequencing verification

For the Week 0 → Week 4 sequence in §2.1 above, confirm:

- KV-Direct gate experiment can run on the user's 16GB Mac (per memory `[User Hardware — 16GB Mac]`)
- App Group migration doesn't break any existing test suite
- AgentXPC + ProviderXPC split is feasible without touching protected paths
- Simulation v1.6 land doesn't break the simulation worktree's invariants I-1..I-15

---

## 4. The "all of it, no compromises" boundary

The user's direction was explicit: ship ALL of Helios + MAS + Hermes + SCOPE-Rex + deterministicapp eventually. **Where this handoff says "Pro tier" or "Research tier" — that's not a compromise, it's the capability lattice.** Same substrate. Three envelopes. One binary. Zero forks.

The only items that genuinely DROP from this round:

- **Hope / Continuum Memory System** — defer per Helios v3's own audit; no released code as of May 2026
- **eml-operator (Pillar V)** — beautiful but not load-bearing for the UX; defer to Research
- **Free probability / Koopman / Predictive coding deeper weave** — falsifiable predictions, not theorems; stay as research notes
- **Birkhoff Polytope mHC** — Helios v3 audit calls this "unverified theoretical conjecture"; stay as research

Everything else builds.

---

## 5. The handoff metadata

- **Branch:** `feature/landing-liquid-wave`
- **HEAD before this handoff:** `8f4309a5 Add Claude session-2 handoff to Codex`
- **This handoff lives at:** `docs/fusion/CODEX_RECONCEPTUALIZATION_HANDOFF_AND_VERIFY_2026_05_03.md`
- **Companion docs:**
  - `JORDANS_RESEARCH_INDEX_2026_05_03.md` — index for `docs/fusion/jordan's research/`
  - `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` — the substrate vision
  - `CODEX_TASK_CONTINUITY_HANDOFF_2026_05_03.md` — catch-up + sequence
  - `CODEX_HANDOFF_2026_05_03_PART2.md` — prior session-2 handoff (still authoritative for post-hackathon M1/M2/M3 sequence)
- **Pre-existing uncommitted pile:** 660+ files, untouched
- **Hackathon priority:** Hermes XPC + multi-CLI integration + Simulation Mode v1.6 with full assets, companion creation/delete/restore, adapter UI, home window
- **Codex's first move:** pbxproj sync per `CODEX_TASK_CONTINUITY_HANDOFF_2026_05_03.md` §3, then verify per §3 above, then start Week 0 KV-Direct gate + Week 1 App Group migration in parallel

---

## 6. Star checklist (verify before any slice opens)

- ⭐ Read all 4 sister docs in order
- ⭐ pbxproj sync done; the 2 verification test suites pass
- ⭐ Convergence audit appended to `CANON_GAPS_AND_ADDENDA_2026_05_02.md`
- ⭐ KV-Direct gate result captured (PASS or FAIL)
- ⭐ App Group container migration plan reviewed against existing storage code
- ⭐ Simulation worktree v1.6 invariants (I-1..I-15) confirmed against current `events.rs` enum
- ⭐ The 6 v1.6 forward AgentEvent variants planned for main-enum addition
- ⭐ Hackathon-block acceptance bar from §1.1 + §1.2 above is testable end-to-end
- ⭐ 660-pile untouched
- ⭐ No protected paths edited unless Simulation v1.6 explicitly requires (in which case: coordination-required gate)

---

## 7. Final bow

The user's vision: **one binary, super dynamic schema, dynamic in a way that's super efficient.** This is what `deterministicapp.md` calls the four-leg stool: deterministic tool ladders + GBNF-constrained SLMs + hybrid MD+JSON memory + minimal-UX routing. This is what Helios v3 calls the six-tier substrate with the WBO-6 bound. This is what `mac store edition.md` calls the user-granted cognitive boundary.

**They're all the same vision, named four times.** The reconceptualization makes that explicit so future agents (Codex, Claude, Kimi) all read from the same map.

The hackathon block ships the user-visible proof: Hermes integration that works, Simulation Mode that's beautiful and honest. The post-hackathon block ships the substrate underneath. The Pro and Research tiers ship the same substrate behind wider entitlements. Zero forks.

> One binary. One substrate. Three envelopes. Zero forks.

Build it.
