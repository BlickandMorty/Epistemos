# Codex Handoff — Cognitive DAG on the Radar (Phase 8) — 2026-05-03

> **Additive handoff.** This does NOT change the work you are currently doing
> on the kernel doctrine (Phases 1-7 of `COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md`).
> Continue that sprint as-planned. This document adds **Phase 8** to your
> radar — a deeper unification that lands AFTER the kernel sprint completes
> and stabilizes for two consecutive weeks. Read once, register the future
> work, then return to your current commit queue.

---

## 0. Why this exists

After we finalized the kernel doctrine (the seven-subsystem unification —
agent loop, skills, procedural memory, tool registry, vault, provenance,
resonance, capabilities, companions, memory tiers, WASM exec — all collapsed
into one Rust kernel), we identified a deeper unification: **collapse the
seven kernel subsystems themselves into one typed, content-addressed,
Merkle-rooted cognitive DAG**. Every subsystem becomes a traversal pattern
over the DAG, not a separate store with its own state.

This is documented in detail at:

- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` — the full Phase 8 doctrine
- `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` §13 — synthesis section
- `docs/fusion/PROCESSES_AND_RUNTIMES_AUDIT_2026_05_03.md` — current runtime audit

You are not asked to start Phase 8 now. You are asked to:

1. **Read the three docs above** (under 1 hour total)
2. **Verify nothing in your current Phase 1-7 work would actively contradict the future DAG schema** (you'll know — if a new abstraction would be redundant under the DAG, flag it; otherwise proceed)
3. **Continue your current sprint without modification**
4. **When the kernel sprint completes and stabilizes**, follow the Phase 8 order in `COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §8

---

## 1. The two compositions, in sequence

```
TODAY (your current sprint — kernel doctrine Phases 1-7)
   │
   │  Collapse Swift, Python, parallel-Rust into ONE Rust kernel
   │  with seven internal subsystems.
   │
   │  Verification: kernel doctrine §10 gates pass. Two consecutive
   │  weeks of green CI without regression.
   │
   ▼
PHASE 8 (after the above ships and stabilizes — DAG doctrine)
   │
   │  Collapse the seven internal subsystems into ONE typed
   │  cognitive DAG. Subsystems become traversal patterns.
   │
   │  Verification: DAG doctrine §5 gates pass. Replay verification
   │  round-trip green.
   │
   ▼
RESULT
   ├─ One binary
   ├─ One kernel inside the binary
   ├─ One DAG inside the kernel
   ├─ Verifiable replay, cascading truth, KB-not-GB companions,
   │  git-portable skills, time-traveling cognition, audit-as-feature
   └─ A publishable systems substrate (MLSys / NeurIPS systems track)
```

---

## 2. What "do not contradict the DAG" means in practice

While doing Phases 1-7, follow the kernel doctrine as written. The DAG is
forward-compatible with everything in the kernel doctrine. There are only
three small things to watch for:

### 2.1 AgentEvent enum — keep it serializable + content-addressable-friendly

When extending `agent_core::events::AgentEvent` with the 6 v1.6 forward
variants (per H6), make sure the variants follow the existing pattern:
no inline closures, no non-Serde fields, no internal `Rc<RefCell>`
references that won't survive serialization. The DAG schema treats every
`AgentEvent` as a content-addressed `Event` node, which requires
canonical serialization.

**Practical guidance:** existing `AgentEvent` variants already follow this
discipline. New variants just need to do the same. No deviation.

### 2.2 Skills registry — namespace skill names predictably

When implementing `agent_core::hermes::skills` (Phase 2), use
`(namespace, name)` keys for skills, not just `name`. The DAG schema
treats each `Skill` as a content-addressed node, and disambiguating by
namespace prevents collisions when two users / two companions have skills
with the same short name.

**Practical guidance:** `SkillId { namespace: String, name: String }` is
the recommended shape. `String` namespace keys (e.g. `"system"`,
`"user"`, `"companion:sage"`) work fine.

### 2.3 Tool outputs — keep them serializable byte-stable

Tool outputs become `Evidence` or intermediate result nodes in the DAG.
They need stable canonical serialization for content-addressing to work.
Avoid floating-point ambiguity in tool outputs (`f64` JSON serialization
varies across runtimes); prefer `String`-encoded numbers or fixed-point.

**Practical guidance:** tool outputs are already JSON-shaped. Just avoid
new `f64` fields without a serialization strategy. Doctrine note in
existing `tools/` follows this; keep doing it.

**That's it.** Three small disciplines. Everything else in Phases 1-7
proceeds without DAG-awareness.

---

## 3. The signal you need (when to start Phase 8)

Start Phase 8 only when ALL of the following are true:

- [ ] Kernel doctrine Phase 1 (audit) committed
- [ ] Kernel doctrine Phase 2 (Hermes-in-Rust) committed
- [ ] Kernel doctrine Phase 3 (WASM exec) committed
- [ ] Kernel doctrine Phase 4 (in-process MCP) committed
- [ ] Kernel doctrine Phase 5 (Pro→Core migration matrix) committed
- [ ] Kernel doctrine Phase 6 (capability lattice) committed
- [ ] Kernel doctrine Phase 7 (doctrine doc) committed
- [ ] All §10 verification gates green
- [ ] **Two consecutive weeks of CI green** (no regressions on the kernel doctrine work)
- [ ] User has explicitly approved starting Phase 8

**Do not start Phase 8 early.** The kernel doctrine is a hard prerequisite.
Implementing the DAG before the seven subsystems are unified means refactoring
across Swift, Python, parallel-Rust simultaneously — too many variables
moving. The kernel doctrine collapses to one Rust kernel. THEN the DAG
collapses the seven subsystems inside that kernel. Two compositions, one
direction.

---

## 4. Pre-reading list (when Phase 8 is approved)

Read in this order:

1. `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` — the canonical Phase 8 doctrine (§§1-10)
2. `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` §13 — the synthesis bridge
3. `docs/fusion/PROCESSES_AND_RUNTIMES_AUDIT_2026_05_03.md` — what's where now (so you know what you're collapsing)
4. The capability calculus prior art (DAG doctrine §B.4): Macaroons paper, Tahoe-LAFS design, biscuit-auth Rust crate
5. `redb` crate documentation (the recommended DAG storage backend)
6. MLX-Swift LoRA adapter API — for the Companion `Deforms` engine

---

## 5. Phase 8 sub-phases (overview — full detail in DAG doctrine §8)

```
Phase 8.A — DAG scaffold        (Week 1)  agent_core::cognitive_dag scaffold
Phase 8.B — Resonance propagation (Week 2)  cascading invalidation along edges
Phase 8.C — Macaroon capabilities (Week 3)  compositional grant calculus
Phase 8.D — LoRA-light companions (Week 4)  research spike + Deforms engine
Phase 8.E — Subsystem migration  (Weeks 5-7)  rewire seven subsystems to DAG
Phase 8.F — Replay verification  (Week 8)  epistemos-trace verify-replay
Phase 8.G — Doctrine linter      (Week 9)  compile-time DAG schema enforcement
Phase 8.H — Document + ship      (Week 10) public materials, paper draft
```

---

## 6. Anti-patterns (forward — for when Phase 8 lands)

These don't apply to your current sprint. They apply to Phase 8 work, listed
here so you have them on the radar:

1. **No edges without signatures.** Every DAG edge must carry a Merkle-signed binding `(from, to, kind)` under the issuing capability.
2. **No nodes without content addresses.** Every node id is `BLAKE3(canonical_serialize(kind))`. Rejected at storage layer if mismatched.
3. **No ad-hoc edge types.** `EdgeKind` enum is closed. Adding a variant requires a doctrine PR.
4. **No DAG state outside the kernel.** Swift / XPC services are read-only viewers via UniFFI projections.
5. **No retroactive DAG mutation.** Append-only. To "delete," insert a `Tombstone` node with a `Contradicts` edge. To "edit," insert a new node with a `Revises` edge.

---

## 7. The pure win (forward — what users get when this lands)

Per DAG doctrine §6:

- **Verifiable replay** — export a session, recipient verifies byte-for-byte
- **Cascading truth** — retract evidence, dependent claims auto-invalidate
- **Companions are KB, not GB** — 50 companions on one base model = 6.5GB total
- **Skills are git-portable** — content-addressed verifiable subgraphs
- **Trust is compositional** — Macaroon-style capability calculus
- **Time travel** — git bisect your reasoning
- **Audit-as-feature** — defensible paper trail for regulated environments

---

## 8. Your acknowledgement

When you read this doc (likely as part of your next planning checkpoint),
add one line to `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md`:

```
2026-05-XX — Codex acknowledged Phase 8 (Cognitive DAG) on radar.
Continuing kernel doctrine Phases 1-7 as planned. DAG starts after
kernel sprint completes and stabilizes for two consecutive weeks.
```

That's the signal back to Jordan that you've absorbed the future work
without disrupting the current work.

---

## 9. Closing

You're building the right thing. The kernel doctrine collapses fragmentation
into one Rust binary. The DAG doctrine collapses the kernel's internal
fragmentation into one schema. Both ship. The order matters.

> First one binary. Then one DAG inside that binary. Then publish the paper.

Build it. In order.

---

## Appendix — Cross-references

```
docs/fusion/CODEX_DAG_RADAR_HANDOFF_2026_05_03.md       ← this doc (additive radar item)
docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md     (your current sprint — Phases 1-7)
docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md        (Phase 8 — start after current sprint stabilizes)
docs/fusion/PROCESSES_AND_RUNTIMES_AUDIT_2026_05_03.md  (ground truth audit)
docs/fusion/EPISTEMOS_FUSION_HANDOFF_2026_05_03.md      (Kimi/GPT framing — re-derive canonically)
docs/fusion/EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md (substrate framing)
CLAUDE.md                                               (NON-NEGOTIABLE constraints)
```
