# Quick Capture salvage triage — 2026-05-04

**Source**: `docs/fusion/salvage/from-vigorous-goldberg/agent_core_src/` —
25 Rust files across 10 modules salvaged from the `vigorous-goldberg`
worktree. Total 5,656 LOC. Master plan at
`docs/fusion/salvage/from-vigorous-goldberg/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md`
(3,715 lines, Waves 0-5).

**This doc is handoff notes, not a port plan.** Per the recovery loop's
wait-for-signal contract, V2.1 (Cognitive DAG) does not auto-start. When
the user types `RESUME SUBSTRATE V2`, the next building agent picks a
Tier A / Tier B slice from this register and lands it independently.

---

## Tier A — Integration-ready today (no DAG dependency)

These modules are self-contained data types or pure deterministic
algorithms. They could land into `agent_core/src/` in their own commits
without waiting for V2.1 Phase 8.

| Module | Files | LOC | What | Depends on |
|---|---|---|---|---|
| `format/` | mod + intent + mem + skill | ~600 | Hybrid JSON+Markdown formats (.mem, .intent, .skill); pure data definitions per Plan §2 + §8 + §24 | serde only |
| `canon/` | mod + alias | ~280 | Deterministic concept canonicalizer (lowercase → unicode-fold → stem → sort → kebab); no LLM per Plan §1.4 No-LLM-First | rust-stemmers crate |
| `grammar/` | mod | 208 | llguidance-based grammar compiler from JSON Schema — single source of truth for tool-call shape per Plan §3.3 + §17 | llguidance 1.x |
| `undo/` | mod | 579 | SQLite-backed undo_events log + 24h ⌘Z reversal per Plan §8.5 | rusqlite |

**Recommended landing order**: `format/` first (everything else
references its types) → `canon/` (zero-deps) → `grammar/` (pre-req for
real route Variant B) → `undo/` (pre-req for skill_discovery's "user
accepted" check).

---

## Tier B — Integration-ready with host wiring (no DAG; needs Swift wiring or trait impl)

These modules are self-contained logic but expect the host (Swift /
AppBootstrap) to provide a probe, callback, or trait implementation.
The Rust side ships clean; the Swift wiring is a separate slice.

| Module | Files | LOC | What | Host wiring required |
|---|---|---|---|---|
| `nightbrain/` | mod | 334 | Idle scheduler; thermal + battery + idle gates per Plan §7.1 | Swift `RuntimeDiagnosticsMonitor` already exposes thermal + memory pressure; needs a battery probe + idle-since-last-input timestamp |
| `heal/` | mod + breaker + log | ~900 | Self-healing Try-Heal-Retry loop + per-tool circuit breaker per Plan §5 | Diagnostician trait impl (LLM-bearing in production; `GiveUpDiagnostician` already present for tests) |
| `route/` | mod + variant_a/b/c | ~1,500 | Four-variant routing pipeline per Plan §4 (place \| merge \| create_folder \| defer) | Variant A: folder-medoid index (Tantivy or HNSW). Variant B: GBNF classifier (uses `grammar/`). Variant C: concept-anchored placement (uses `canon/`). Variant D ships standalone today. |
| `effect/` | mod + 4 appliers + receipt | ~1,200 | Intent-to-Effect state pattern + per-effect inverse for undo per Plan §8 | Receipt module has a Wave 5 stabilize TODO for Ed25519 signing — defer signing to a later slice; receipt-without-signature ships now |

**Recommended landing order**: `effect/` first (everything else emits
Effects) → `heal/` (consumes Effect failures) → `nightbrain/` (uses
heal for retry semantics) → `route/` (uses all of the above).

---

## Tier C — DAG-blocked (needs V2.1 Phase 8 first)

These modules read provenance facts that only become typed and
queryable once the Cognitive DAG lands. Trying to integrate before
Phase 8 means hand-rolling the provenance API twice.

| Module | Files | LOC | What | Why DAG-blocked |
|---|---|---|---|---|
| `skill_discovery/` | mod | 434 | Proposes `.skill.json` / `.skill.md` pairs from successful tool compositions per Plan §11 + Phase 12.5 | Reads (1) tool-sequence-hash (a DAG-provenance edge), (2) "user accepted" = no ⌘Z within 5 min (DAG provenance + undo log), (3) latency budget met (DAG node attribute). All three become first-class once Phase 8 ships; pre-Phase-8 they require a parallel ledger. |

---

## Tier D — Browser engine / Pro-only (Wave 6+; beyond V2 scope)

| Module | Files | LOC | What | Status |
|---|---|---|---|---|
| `browser_engine/` | mod | 470 | BrowserEngine trait + WebKit (MAS-safe) / Obscura (Pro-only) / Mock adapter pattern per FINAL_SYNTHESIS §6 | Wave 6 in the source plan; replaces the legacy `tools/browser.rs` direct-spawn. The trait is small enough to land into agent_core today as a non-default surface, but the actual adapter implementations (esp. ObscuraBrowserEngine) are Pro-only and beyond V2's MAS-first scope. |

---

## Master plan section map

The 3,715-line `QUICK_CAPTURE_IMPLEMENTATION_PLAN.md` covers more than
the 10 salvaged modules. The salvage is the substrate (Waves 0-5);
the plan also covers:

- **§6 Native Skills + Local Inference** (Spotlight, Vision OCR, MLX
  ephemeral pipeline, per-model engineering for 12 models). Some pieces
  exist today (Spotlight indexer, MLXInferenceService); the per-model
  catalog is canon-target.
- **§7 Model Workspace Protocol** (filesystem-as-orchestrator). Adjacent
  to but not blocked by V2.1 DAG.
- **§9 Minimalist Capture Surface** (UI). Belongs in `Epistemos/Views/`,
  not agent_core.
- **§17 Compile-Verify-Mint + Sampler-Bound Tool Dispatch** (the
  breakthrough — grammar-bound dispatch makes local strictly more
  reliable than cloud on tool-call shape). Implements via `grammar/`
  + future runtime wiring.
- **§18 Auto-Generation Pipeline** (skill / tool minting from compose).
  Builds on `skill_discovery/` (Tier C).

---

## Acceptance bar before this triage is "done"

- [ ] Each Tier A module landed as its own commit per the five-question
      PR discipline (Stage / GenUI route / Sovereign / Pro impact /
      TEMP-FREE-TIER).
- [ ] Each Tier B module landed with the named host wiring as a
      separate Swift commit.
- [ ] Tier C deferred until V2.1 Phase 8 lands.
- [ ] Tier D deferred until Pro-build is on the critical path (per the
      MAS-first focus doctrine).

Until then, the salvage tree under
`docs/fusion/salvage/from-vigorous-goldberg/agent_core_src/` stays
read-only. Don't import from the salvage path at compile time —
copy the file into `agent_core/src/` when you're ready to land it.
