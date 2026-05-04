# CLAUDE.md ADDENDUM — DETERMINISTIC PERFORMANCE PLAN

> **Where this goes.** Append this block to your existing `CLAUDE.md` at the project root, under a new section heading. Do not paste the full plan into CLAUDE.md — reference it.

---

## Deterministic Performance Plan (active)

A separate, self-contained build spec lives at `docs/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md`. It runs in parallel with the Phase I Rust agent migration and never touches `crates/agent_core/`.

**Five constraints (apply to every change):**
1. NO HOT-PATH SERIALIZATION — events firing >100 Hz cross the FFI as `repr(C)` ring entries, not UniFFI types
2. NO MAIN-THREAD METAL COMPILATION — every PSO sourced from a shipped `MTLBinaryArchive`
3. NO STRING-KEYED DISPATCH IN INNER LOOPS — `phf::Map` or compile-time `enum`
4. NO ALLOCATION IN RENDER FRAMES — `bumpalo::Bump` arenas, reset per frame
5. EVERY OPTIMIZATION SHIPS WITH A SIGNPOST — `os_signpost` interval + CI p99 assertion

**Sprint sequence:**
- Sprint 0 — instrumentation + GRDB pragmas + LTO (week 1)
- Sprint 1 — slotmap + structure-of-arrays migration (weeks 2–3)
- Sprint 2 — `phf` registries + `@ArtifactView` Swift macro (weeks 4–5)
- Sprint 3 — Metal binary archive + Tree-sitter SoA highlight cache (weeks 5–6)
- Sprint 4 — zero-copy FFI carve-out via `substrate-rt` ring buffer (weeks 7–9)
- Sprint 5 — PGO + bumpalo arenas + mmap'd raw-thoughts log (weeks 10–11)

**Stabilization paths** are defined in §7 of the plan. Use them if scope gets messy.

**One sprint per Claude Code session.** Read the sprint header in the plan, execute its tasks, run the verification block, paste output to `docs/PROGRESS.md`, and stop.
