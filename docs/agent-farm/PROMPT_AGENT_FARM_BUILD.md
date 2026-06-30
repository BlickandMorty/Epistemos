# PROMPT — AGENT FARM, STAGE 1 BUILD (paste-ready)

> Paste-ready build prompt for a fresh agent (or a `/loop`). Mirrors the Epistemos plan-prompt discipline: read-first,
> staged gates, intermittent research checkpoints, commit-after-each-slice. **This is a NEW, SEPARATE app — it must not
> touch the Epistemos codebase.** The design is SETTLED across 8 research efforts; your job is to BUILD, not re-decide.

---

## WORK ORDER — BUILD THE SHELL + THE SPLIT FIRST. PROVE EACH GATE BEFORE THE NEXT.

You are building **Agent Farm** — a budgeted production society of AI mascot-agents in a native Bevy/Rust 2D world.
It is a fresh app in its own repo. No Epistemos source is imported; you may reuse *patterns* (agent_core ideas,
cli-passthrough, per-agent vault), never a shared binary.

### READ FIRST (in order — do not skip; do not re-litigate the design)
1. `docs/agent-farm/AGENT_FARM_MASTER_BUILD_DOC_2026_06_30.md` — **THE spec, with code.** §0 shell, §2 core code, §4 stages, §5 gates.
2. `docs/agent-farm/AGENT_FARM_SYNTHESIS_2026_06_30.md` — the convergence + every correction/flag.
3. `docs/agent-farm/AGENT_FARM_RESEARCH_REPORT_2026_06_30.md` — the verified constants (0.995, 150) + lift-vs-build table.
4. `docs/agent-farm/AGENT_FARM_CONCEPT_2026_06_30.md` — the vision (read once for intent; the build doc supersedes it on specifics).

### NON-NEGOTIABLE GATES (from §5 — violate one and the slice is rejected)
- **No LLM/PyO3 on the frame thread.** The brain is an out-of-process / off-thread SIDECAR (§2f). The render never blocks.
- **No faucet without a sink.** Every minted budget unit must be burnable. Fuzz the ledger; caps must NEVER be violated.
- **No reward without a verifier pass + novelty check** (§2g). The verifier is the usefulness; do not stub it past Stage 3.
- **No self-minting / no recursive self-purchase of authority.** No endpoint lets an agent grow its own budget.
- **No web/model-rendered UI.** Hand-authored `bevy_ui` + WGSL. `egui` is DEBUG-only. (This is why it is NOT Tauri.)
- **Mine, don't fork.** Lift ideas (memory formula, Voyager skills, PIANO, elizaOS character-JSON); write the Rust runtime fresh.
- **Pin the Bevy version.** Record it in Cargo.toml + README. ProMotion 120fps is a target to PROVE — profile; ship 60 if needed.
- **Honesty.** If a gate isn't met, say so in the commit body. Never mark a stage done without its gate passing.

### BUILD ORDER (one slice per commit; run the gate before moving on)

**STAGE 1 — Prove the split (ZERO LLM).** This is the entry point; do this first, end to end.
1. `cargo new agent-farm`; pin `bevy` + `window-vibrancy` + `crossbeam-channel` + `rusqlite` (exact versions, §0).
2. The shell (§0): transparent borderless window + native vibrancy + `ClearColor::NONE`. A frosted empty window must appear.
3. Spawn 25 agent entities (sprite + `Needs` + `Wallet` + `MemoryStream` + position). They wander.
4. Cheap drives (§2b) + utility-AI action pick (§2b) + ledger (§2e) with a **stubbed** appraiser (no LLM) so trades happen.
5. Dissolve/blur transitions (§3) on object pop-in/out; objects persist in a `rusqlite` data layer (permanence > impermanence).
   - **GATE 1:** stable target fps with **50 agents + 200 objects** on real hardware; **ledger fuzz: caps NEVER violated**;
     a frosted native window renders. Record the measured fps + the pinned Bevy version in the commit body.

**STAGE 2 — Bridge ONE brain.**
6. The sidecar bridge (§2f): off-thread worker, crossbeam channels, `dispatch`/`poll` systems. Frame thread must not stall.
7. Wire Hermes **function-calling** variant (NOT Hermes-chat) as the worker; structured JSON action out.
8. Memory stream (§2c, decay 0.995) + reflection trigger (§2d, threshold 150). One mascot writes ONE real markdown to its vault.
   - **GATE 2:** the artifact is something a human would keep; **zero main-thread stalls** under a profiler while cognition runs.

**STAGE 3 — Economy + society.**
9. AP2 Intent→Cart→settle (§2e) + a shop affordance + per-agent caps + demurrage/upkeep + the **verify loop** (§2g).
10. Gossip + a reputation scalar; the appraiser mints reward ONLY on a verifier pass + novelty check.
11. Tune EVE faucets/sinks so total budget supply stays bounded over a long run.
    - **GATE 3:** budget supply bounded over a long soak; agents specialize **without being scripted to**; no exploit found in a fuzz pass.

**STAGE 4 — Offline super-agent (OPTIONAL — only if Stage 3 is solid).**
12. MoA / Self-MoA for a "serious research" artifact path, OFF the live loop. Keep it offline; measure the quality gain.
    - **GATE 4:** the quality gain pays for the latency/cost, or you CUT it and say so.

### RESEARCH CHECKPOINTS (thermonuclear — pause and verify, don't guess)
- **Before Stage 1 code:** confirm the EXACT current Bevy API for `WindowPlugin`/transparency/`WinitWindows` against the
  pinned version's docs (names drift — `delta_seconds` vs `delta_secs`, etc.). Adjust the §2 snippets to compile.
- **Before Stage 2:** verify the Hermes function-calling prompt format + the chosen serving path (local server vs API)
  against current Hermes docs. Confirm Hermes-chat is NOT what you wired.
- **Before Stage 3:** re-read the §5 anti-exploit list; write the fuzz test FIRST (caps, self-mint, loop-farming, hoarding).
- **Any time a claim matters** (a crate's API, a license, an OS behavior): check the primary source before relying on it.
  Flag anything you couldn't verify in the commit body rather than asserting it.

### COMMIT DISCIPLINE
- One slice per commit. Run the gate, then commit. Never batch.
- Commit body states: what shipped, which gate passed (with the measured number), what's stubbed, what you couldn't verify.
- End every commit message with: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

### DO NOT
- Touch the Epistemos codebase. Import its crates. Share its binary.
- Put an LLM call (or PyO3) on the frame thread.
- Mint budget without a sink, or release reward without a verifier pass.
- Mark a stage done before its gate passes. Over-promise emergence. Ship a web/Tauri UI.
