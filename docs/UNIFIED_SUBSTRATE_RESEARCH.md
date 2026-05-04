# Unified Substrate Research — Synthesis of 3 Independent Dossiers

> **Index status**: DEFERRED-RESEARCH — Substrate Phase D research with "Five Laws (Add to CLAUDE.md — binding)" language; needs canonical absorption review.
> **Superseded by / Phase**: Phase D.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/60_deferred_research/`.



**Date:** 2026-04-02
**Sources:** unified1.md (Perplexity), unified2.md (Claude), unified3.md (independent)
**Verdict:** All 3 converge on the same architecture. Strong signal.

---

## THE FIVE LAWS (Add to CLAUDE.md — binding)

**Law 1: Measure before you cut.** No architectural refactoring without Instruments profiling data justifying it. Every PR that changes architecture must reference a concrete measurement (allocation count, frame time, call frequency, binary size delta).

**Law 2: The entity store is a new crate, not a refactor.** Don't transform existing Swift models into Rust entities in-place. Build `substrate-core` as a fresh Rust crate with `slotmap` generational keys. Wire alongside existing code. Migrate one entity type at a time. Old and new coexist until old can be deleted.

**Law 3: Identity unification is Sprint 1. Everything else waits.** Define `EntityID` as a `SlotKey` in Rust, expose via C ABI as `u64`, start replacing Swift-side UUIDs one model at a time. Don't touch rendering, action grammar, or Python until identity is unified for notes, links, and tags.

**Law 4: UniFFI stays until profiling proves otherwise.** All 3 dossiers recommend graduated FFI — UniFFI for cold paths, custom C ABI for hot paths. Don't pre-optimize. Keep UniFFI for everything, then replace the top 3 measured hotspots with `#[repr(C)]`.

**Law 5: Python goes out-of-process immediately.** Move all Python to subprocess daemon behind Unix domain socket. Saves 15-25MB bundle, eliminates GIL contention, crash-isolates Python. Fastest no-regret change.

---

## SUBSTRATE SPRINT PLAN

### Sprint 0 (Audit — before any architecture work)

Codex must produce `docs/ARCHITECTURE_AUDIT.md` with:
1. Every distinct identity type in codebase (UUID, String ID, Int ID, file path as ID) with file locations
2. Every `@StateObject`, `@ObservedObject`, `ObservableObject` — flag any holding canonical state
3. Every UniFFI call site, categorized by frequency: high (render loop), medium (user action), low (lifecycle)
4. Every Python invocation — flag any on main thread
5. Binary size by component: `nm` on Rust `.a`, link map on Swift, asset sizes

### Sprint 1 (EntityID + Python Isolation — parallel workstreams)

**Stream A — EntityID:**
- New crate: `substrate-core` with `slotmap::SlotMap<EntityKey, EntityData>`
- `EntityID` exposed as `u64` via C ABI
- Swift typealias bridging
- Migrate `Note` identity first
- Legacy IDs as deprecated aliases that convert to/from `EntityID`

**Stream B — Python Isolation:**
- Extract Python to subprocess daemon
- Unix domain socket, JSON-RPC protocol
- `PythonToolDaemon` class in Swift (spawns on first tool call, keeps warm)
- This is already partially done via HermesSubprocessManager — formalize it

### Sprint 2 (Action Grammar Foundation)

- `AppAction` as Rust enum: `CreateNote`, `UpdateContent`, `RenameNote`, `LinkNotes`, `DeleteNote`
- Event log: `Vec<AppAction>` + SQLite persistence
- Undo/redo via log replay
- This is where "one truth" becomes real

### Sprint 3 (Window Singularity Proof)

- Note editor reads canonical state from Rust entity store via `@Observable` Swift projection
- Open same note in two windows → single-frame propagation
- Validates the entire substrate thesis

### Sprint 4+ (Measure and Iterate)

- Profile again — measurements dictate what to migrate next
- Graph view, sidebar, settings, agent harness — sequenced by profiling data
- The architecture is clear; ordering is dictated by measurements

---

## WHAT NOT TO DO

- **Don't build a custom Metal text renderer.** TextKit 2 / NSTextView is correct for text editing. Metal only for graph/hologram.
- **Don't build a full ECS.** slotmap + typed component access is enough. Not Bevy-style system scheduling.
- **Don't implement rkyv yet.** SQLite + serde is fine until serialization is a measured bottleneck.
- **Don't write the agent harness substrate until Sprint 4+.** It needs entity store + action grammar + event log first.
- **Don't try to execute all of this simultaneously.** Solo developer + 250K LOC + parallel grand rewrites = nothing shippable for months.

---

## THE SEED CRYSTAL

> Build `substrate-core` as a new Rust crate with `slotmap` entity storage and an `AppAction` event log. Expose `EntityID` as `u64` via C ABI. Migrate note identity first. Keep everything else running. Measure everything.

---

## HOW THIS MAPS TO EXISTING PHASES

The substrate work is NOT a separate phase — it weaves into existing phases:

| Phase | Substrate Work That Happens Here |
|-------|--------------------------------|
| A (Provider Overhaul) | Sprint 0 audit runs alongside provider work |
| B (Graph-First) | Graph reads EntityIDs from substrate-core (Sprint 3 proof) |
| C (Agent Parity) | Agent actions route through AppAction event log (Sprint 2) |
| D (Knowledge Brick) | Sidebar reads unified entity store (Sprint 3 window singularity) |
| I (Rust Migration) | Python isolation formalized (Sprint 1 Stream B), agent actions in Rust |
| H (Release) | Full substrate operational, old identity system deleted |

---

## SOURCE RESEARCH (3 dossiers)

All saved at:
- `~/Downloads/unified 1.md` — Perplexity dossier
- `~/Downloads/unified2.md` — Claude dossier
- `~/Downloads/unified 3.md` — Independent dossier

Key convergence points across all 3:
1. slotmap generational keys for entity identity
2. Rust-owned canonical store, Swift @Observable projections
3. AppAction enum event log for mutations
4. Graduated FFI (UniFFI cold, C ABI hot — measured, not assumed)
5. Python out-of-process as immediate no-regret change
6. Window singularity through shared entity subscriptions
7. ECS-inspired but NOT full ECS — productivity app, not game engine
