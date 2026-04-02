# Codex Session Prompt — Epistemos

**Paste this at the start of EVERY NEW Codex session to restore context.**

## STATUS CORRECTION — 2026-04-01

This prompt previously treated Phase 6F and Phase 7 as unfinished. That is stale.

- Phase 6F harness wiring is complete in `AgentViewModel`
- Phase 7A-7G harness lab work is complete per `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md`
- Core Hermes/Omega follow-ons such as tool gates, auto-discovery, skills, cost tracking, NightBrain distillation, and stream composition already landed; check `docs/AGENT_PROGRESS.md` before assuming they are pending
- Current net-new roadmap work is whatever remains in the master plan after those completed items, plus truly new runtime regressions and Cloud Knowledge Distillation

---

You are continuing work on **Epistemos** — a macOS-native cognitive exoskeleton PKM. Swift 6 + Rust (UniFFI) + Metal. 137K Swift, 94K Rust.

## READ THESE FILES FIRST (in order)

### Core Context
1. `CLAUDE.md` — Project rules, constraints, file map
2. `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` — Single source of truth: all phases, what's done, what's next
3. `docs/CODEX_HANDOFF.md` — Full handoff: changes, runtime analysis, audit checklist, research context
4. `docs/AGENT_PROGRESS.md` — Sprint status

### Agent System (historical plan + shipped follow-ons)
5. `docs/BEST_OF_CLAW_AND_OPENCLAW.md` — source pattern doc; many items from this plan are already implemented, so verify against `docs/AGENT_PROGRESS.md`
6. `docs/FUSED_AGENT_ENGINEERING_REPORT.md` — Root cause analysis + upgrade path
7. `docs/HERMES_INTEGRATION_RESEARCH.md` — 40-file hermes-agent study
8. `docs/HERMES_PARITY_REPORT.md` — What hermes can do vs what Epistemos exposes
9. `docs/IMPLEMENTATION_PROMPTS.md` — 8 paste-ready implementation prompts

### Architecture & Specs
10. `docs/EPISTEMOS_FUSED_v3.md` — Complete 8-phase build spec
11. `docs/epistemos-deep-analysis.md` — Deep architectural analysis
12. `docs/CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md` — Per-model vault knowledge compilation
13. `docs/CONTROL_PLANE_RESEARCH.md` — **WHY the app feels disconnected**: become the GUI control plane, MCP as spine, capability→UI surface mapping
14. `docs/MASTER_SESSION_PROMPT_v2.md` — Five Engines, architecture map, remaining work

### Verification
14. `docs/HARDENING_VERIFICATION.md` — 52-item grep checklist
15. `docs/VERIFICATION_PROTOCOL.md` — Phase verification steps

### Research (read if making architectural decisions)
16. `~/arc/arc2.md` — 7-area canonical pattern audit
17. `~/arc/harn2.txt` — Meta-Harness integration blueprint
18. `~/EPISTEMOS-RESEARCH-REFERENCE.md` — 50+ paper synthesis
19. `~/Downloads/files (9)/AGENT_ADVISORY_COUNCIL.md` — 5-expert verdict: orchestration tax, selective adoption
20. `~/Downloads/files (9)/UNIFIED_RESEARCH_SYNTHESIS.md` — 8-project fusion: Fusion Penalty, moat = knowledge layer
21. `docs/AGENT_FUSION_RESEARCH_PROMPT.md` — 8-project analysis with 20 codebase files

## CURRENT STATUS

```
Phases 1-5: Runtime Foundations          ✅ COMPLETE
Phases 6A-6F: Harness Production Runtime ✅ COMPLETE
Phase 7A-7G: Harness Lab                 ✅ COMPLETE
Agent System (Hermes/Omega core sprints) ✅ COMPLETE
Cloud Knowledge Distillation             ✅ WIRED (Codex built + NightBrain integrated)
Phase A: Provider Overhaul               ❌ NEXT
Phase B: Graph-First Experience          ❌ NEXT
Phase C: Agent Parity                    ❌ PLANNED
Phase D: Knowledge Brick                 ❌ PLANNED
Phase E: Code Editor                     ❌ PLANNED
Phase F: Multi-Agent                     ❌ PLANNED
Phase G: Performance Hardening           ❌ PLANNED
Phase I: Rust Agent Migration            ❌ PRE-RELEASE MANDATORY
Phase H: Release                         ❌ AFTER Phase I
```

Defaults: eco mode ON, graph performance mode ON.

**CRITICAL:** Phase I (Rust Agent Migration) is MANDATORY before Phase H (Release).
The shipped app is pure Swift + Rust + Metal. No Python. See VISION_BACKLOG.md Phase I.

## FOUR WORK TRACKS

**Track A — Vision Backlog phases A→I→H:** `docs/VISION_BACKLOG.md` — the master execution order
**Track B — Verification / Regressions:** confirm runtime against `docs/CODEX_HANDOFF.md`
**Track C — Agent Research:** read `1-RESEARCH` in VISION_BACKLOG.md before any agent work. Advisory council says: minimize orchestration, MCP as spine, knowledge layer is the moat.
**Track D — Rust Migration:** Phase I in VISION_BACKLOG.md — 7 steps from Python to pure Rust agent

## WHAT TO DO

1. Check `docs/VISION_BACKLOG.md` for the current phase (A→H)
2. Check `docs/AGENT_PROGRESS.md` before treating any item as unfinished
3. Read all relevant files before editing
4. Run verification after each task
5. **MANDATORY: After completing each PHASE, run the full 8-step audit** from `docs/CODEX_MASTER_PROMPT.md` §MANDATORY POST-PHASE AUDIT PROTOCOL:
   - Build + Rust tests
   - Hardening grep checklist (all 52 items from HARDENING_VERIFICATION.md)
   - Zero-corruption checks (F_FULLFSYNC, try? audit, catch_unwind coverage)
   - Anti-drift checks (no sidecars, no fake SDKs, Keychain-only keys)
   - Continuation safety (cancellation handlers, timeouts)
   - Performance spot-check (PowerGuard, frame cap, no main-thread blocking)
   - Architectural coherence (re-read CONTROL_PLANE_RESEARCH.md, ZERO_CORRUPTION_SPEC.md, ANTI_DRIFT_SYSTEM.md)
   - Write audit report to `docs/AUDIT_LOG.md`
6. **DO NOT start the next phase until the audit PASSES**
7. Update `docs/AGENT_PROGRESS.md` when done

## ANTI-DRIFT RULES (MANDATORY — Re-read if context compacts)

### Engineering Philosophy
- **Zero-copy by default.** Audit every FFI/IPC boundary. UMA = zero-copy achievable.
- **Typestate over runtime checks.** `~Copyable` in Swift, `PhantomData` in Rust.
- **Atomic writes or no writes.** temp → F_FULLFSYNC → rename → F_FULLFSYNC parent. Never `try?` on user data.
- **Lock-free on hot paths.** popcount breakers, atomic cursors, yield-not-block.
- **Honest capability gating.** Don't fake tool calling on local models.

### Code Rules
- @Observable not ObservableObject
- Swift Testing (@Test, #expect)
- Never block @MainActor with inference
- No try!, no force-unwraps, no print() in production
- DispatchQueue.main.async in UniFFI callbacks, NEVER .sync
- xcodegen generate after adding files (never edit .xcodeproj)
- API keys in Keychain, NEVER UserDefaults
- Stream every token, preserve thinking blocks
- Every Rust FFI export wrapped in catch_unwind
- Every unsafe block gets `// SAFETY:` comment
- F_FULLFSYNC (fcntl 51) for all durable writes — fsync is NOT sufficient on macOS

### Research Grounding (read when making architectural decisions)
- Zero-corruption: `~/Downloads/release/FINAL DOCS/1. CORRUPTION/ZERO_CORRUPTION_SPEC.md`
- Living Vault: `~/Downloads/last feature after new agents/LIVING_VAULT_ARCHITECTURE.md`
- Recursive hardening: `~/Downloads/release/EPISTEMOS_CODEX_RECURSIVE_MASTER_v4.md`
- Anti-drift: `~/Downloads/release/FINAL DOCS/3. MUST READS/ANTI_DRIFT_SYSTEM.md`
- Quantization: `~/stateful-rotor-implementation-reference.md`
- 50+ papers: `~/EPISTEMOS-RESEARCH-REFERENCE.md`

```bash
# Build
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
# Rust
cargo test --manifest-path agent_core/Cargo.toml
# Regen project
xcodegen generate
```

Now read the files and continue building.
