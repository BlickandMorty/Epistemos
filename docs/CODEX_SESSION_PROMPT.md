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
13. `docs/MASTER_SESSION_PROMPT_v2.md` — Five Engines, architecture map, remaining work

### Verification
14. `docs/HARDENING_VERIFICATION.md` — 52-item grep checklist
15. `docs/VERIFICATION_PROTOCOL.md` — Phase verification steps

### Research (read if making architectural decisions)
16. `~/arc/arc2.md` — 7-area canonical pattern audit
17. `~/arc/harn2.txt` — Meta-Harness integration blueprint
18. `~/EPISTEMOS-RESEARCH-REFERENCE.md` — 50+ paper synthesis

## CURRENT STATUS

```
Phases 1-5: Runtime Foundations          ✅ COMPLETE
Phases 6A-6F: Harness Production Runtime ✅ COMPLETE
Phase 7A-7G: Harness Lab                 ✅ COMPLETE
Agent System (Hermes/Omega core sprints) ✅ COMPLETE
Cloud Knowledge Distillation             ❌ SPEC ONLY / NOT STARTED
Phases 8-13: Advanced                    🟡 DEFERRED
```

Defaults: eco mode ON, graph performance mode ON.

## FOUR WORK TRACKS

**Track A — Verification / Regressions:** confirm current runtime behavior against `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` and `docs/CODEX_HANDOFF.md`
**Track B — Agent Follow-Ons:** use `docs/AGENT_PROGRESS.md` + `docs/BEST_OF_CLAW_AND_OPENCLAW.md` only for items not already shipped
**Track C — Cloud Knowledge:** Per-model vaults (per CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md)
**Track D — Vision Backlog:** `docs/VISION_BACKLOG.md` — Hermes v0.6.0 parity, coding features, graph enhancements, sidebar overhaul, multi-agent, comms channels

## WHAT TO DO

1. Check `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` for the true next item
2. Check `docs/AGENT_PROGRESS.md` before treating any BEST_OF_CLAW item as unfinished
3. Read all relevant files before editing
4. Run verification after each task
5. Update `docs/AGENT_PROGRESS.md` when done

## RULES

- @Observable not ObservableObject
- Swift Testing (@Test, #expect)
- Never block @MainActor with inference
- No try!, no force-unwraps, no print() in production
- DispatchQueue.main.async in UniFFI callbacks, NEVER .sync
- xcodegen generate after adding files (never edit .xcodeproj)
- API keys in Keychain, NEVER UserDefaults
- Stream every token, preserve thinking blocks

```bash
# Build
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
# Rust
cargo test --manifest-path agent_core/Cargo.toml
# Regen project
xcodegen generate
```

Now read the files and continue building.
