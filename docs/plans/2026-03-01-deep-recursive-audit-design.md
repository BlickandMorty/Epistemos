# Deep Recursive Audit — Skill Design

**Date:** 2026-03-01
**Scope:** Epistemos Opulent Edition (macOS) — Swift + Rust graph-engine
**Audit Source:** `docs/future-work-audit.md` (Waves 1-20, 113 items)

## Purpose

An autonomous Claude Code skill that reads the audit document, works through
every item wave-by-wave, writes tests, implements fixes, and verifies each fix
through a quad-gate pipeline before auto-committing. Designed to be started in
a terminal and left running unattended.

## Architecture

### State File: `docs/audit-progress.md`

Persists progress across context compactions and session restarts. Contains:
- Current position (wave, item, gate)
- Completed items with commit hashes
- Failed/deferred items with reason
- Running test count delta

### Quad-Gate Pipeline (per item)

Each audit item passes through four gates before it ships:

1. **DIAGNOSE + FIX** — Read source, write tests first, implement fix, build+test
2. **RESEARCH** — WebSearch for current best practices, compare against fix, refine
3. **VERIFY** — Clean rebuild, run ALL tests (not just new), check regressions
4. **EDGE CASES** — Write edge case/stress tests for the fix, run full suite, final build

If any gate fails: log to state file as "deferred", move to next item.

### Outer Loop

```
while items remain in waves 1-20:
    read audit-progress.md → find next item
    read future-work-audit.md → get item details
    run quad-gate pipeline
    if all gates pass:
        auto-commit with "audit(W{wave}.{item}): {description}"
        update audit-progress.md → mark complete
    else:
        update audit-progress.md → mark deferred with reason
    loop
```

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Work order | Wave sequential (1→20) | Follows audit priority structure |
| Verification | Quad-gate (4 passes) | Maximum rigor per user preference |
| Commits | Auto per item | Easy revert, visible progress |
| Scope | Waves 1-20 (not 21) | macOS only, no Retro Edition |
| Test framework | Swift Testing (`@Suite`/`@Test`) | 100% adopted, no XCTest |
| Failure handling | Defer + continue | Don't block on one item |
| State | `docs/audit-progress.md` | Survives compaction, git-tracked |

### Scope Boundaries

**IN:** Performance (W1), Architecture (W2), Testing (W3), Second Brain (W4),
Data Integrity (W5), Concurrency (W6), Memory (W7), FFI (W8), SwiftData (W9),
Security (W10), Error Handling (W11), UI Edge Cases (W12), Perf Degradation (W13),
AI/Cognitive (W14), Graph/Visual (W15), Academic Writing (W16), UI Polish (W17),
Interactive/Live (W18), Infrastructure (W19), Advanced Arch (W20)

**OUT:** Wave 21 (Retro Edition), new feature development, UI redesign

### Test Strategy

- **Test-first:** Write failing test before implementing fix
- **Edge cases:** Dedicated edge case tests per fix
- **Regression:** Full test suite run at Gate 3 (not just new tests)
- **Count tracking:** State file tracks test count delta per session
