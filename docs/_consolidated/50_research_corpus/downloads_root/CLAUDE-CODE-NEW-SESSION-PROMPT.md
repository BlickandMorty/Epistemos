# EPISTEMOS — NEW SESSION PROMPT

**Paste this at the start of EVERY new Claude Code session to restore context.**

---

## CONTEXT RESTORATION

You are continuing work on **Epistemos** — a macOS-native cognitive exoskeleton PKM. Swift 6 UI + Rust core via FFI. Sub-5ms semantic memory retrieval. Local + cloud LLM. Agentic AI.

**Before writing any code, read these files:**
1. `harness-engineering-thesis.md` — Architecture vision, Harness Engineering thesis, Meta-Memory Retrieval
2. `stateful-rotor-implementation-reference.md` — Code templates, performance targets, concurrency patterns, crate stack
3. `EPISTEMOS-RESEARCH-REFERENCE.md` — Product strategy, search pipeline, inference, UX

Then run `cargo check` to see current state. Then ask me what we're working on.

## ANTI-DRIFT CHECKLIST (Re-read every session)

Before writing code, confirm:
- [ ] Am I using `objc2-metal`, NOT `metal-rs`? (metal-rs is deprecated)
- [ ] Am I using UniFFI proc-macros for non-perf FFI, C FFI for Metal buffers?
- [ ] Does my search pipeline have ALL FIVE stages? (tantivy + vectors + graph + RRF + reranking)
- [ ] Is my concurrency model using crossbeam-epoch + segment MVCC + read-temperature? (not just RwLock)
- [ ] Does the router output intent + reasoning_depth, NOT target_model?
- [ ] Am I implementing real code, not stubs/TODOs?
- [ ] Am I yielding in background tasks after each chunk?

## ARCHITECTURE QUICK-REF

```
Swift 6 UI → UniFFI/C-FFI → Rust Core Engine
                              ├── Stateful Rotor (ButterflyQuant + Kitty + MVCC)
                              ├── Meta-Memory Retrieval (TurboQuant-compressed patterns)
                              ├── Search Pipeline (tantivy + vectors + graph + RRF + reranker)
                              ├── Concurrency Lattice (epoch + MVCC + temperature)
                              └── Metal Compute (objc2-metal, zero-copy UMA)
```

## KEY MATH

- ButterflyQuant: O(d log d) rotation, Givens angles, (d log d)/2 params
- PM-KVQ Right Shift: `floor((2^{2b} - 2^b + 1)(X_{2b} + 2^{b-1})) >> 3b`
- RRF: `score(d) = Σ 1/(60 + rank_r(d))`
- MMR Estimator: `<y, x̃> = <y, Q⁻¹(Q(x))> + ||r||₂ · <y, QJL(r)>` (unbiased)

## PERFORMANCE TARGETS

| Op | Target |
|----|--------|
| Vector search (1M) | <5ms |
| Ingest | <1ms |
| Full hybrid pipeline | <50ms |
| Rotation swap | <1μs |
| MLX inference | 45-58 tok/s |

## CRATE STACK

`uniffi 0.29` · `objc2-metal 0.3` · `rusqlite 0.31` · `tantivy 0.25.0` · `tokio 1.x` · `crossbeam-epoch 0.9` · `parking_lot 0.12` · `mimalloc` · `half 2.3` · `bitvec 1` · `rayon 1.8` · `memmap2 0.9` · `serde + bincode` · `tracing`

Compile: `target-cpu=apple-m1`, `opt-level=3`, `lto="fat"`, `codegen-units=1`

## NOW

Read the reference docs. Run `cargo check`. Ask me what we're building today.
