# Wave 9 — Polish, Wire-up, Apple-Native

Synthesis of 5 parallel research streams (project plan audit + Downloads
corpus across optimization, UI wiring, Apple-native, PKM/memory).
Authored 2026-04-26 after W8.7 (Halo vault bootstrap) closure.

## Verdict

V1 is **shippable** conditional on three small ship-gates totaling ~7 hr:
mas-sandbox spot-check, reliability fresh baseline, TestFlight metadata.
The biggest remaining V1-feel gap is not architectural — it is **wiring
existing backend logic to user-facing surfaces** plus a small set of
Apple-native quick wins. Wave 9 closes those gaps without any
architectural rewrites.

## Tier 1 — XS, ship immediately (~6 hr cumulative)

| ID    | Item                                       | Source / status                       |
| ----- | ------------------------------------------ | ------------------------------------- |
| W9.1  | AVSpeechSynthesizer read-aloud             | Apple-native gap; 8 frameworks integrated, this one missing entirely |
| W9.2  | ~~GRDB pragmas + OSSignposter scaffold~~ ✅ already shipped | `Epistemos/Sync/SearchIndexService.swift:204` (canonical W2.3 pragma block) + `Epistemos/Telemetry/Sig.swift` (6-category OSSignposter facade) |
| W9.3  | Reasoning Trajectory Badge                 | `agent_core/src/reasoning_metrics.rs` already classifies Efficient/Hesitating/Stuck — no UI |
| W9.4  | Empty-state messaging                      | HomeView / ChatView / SessionListView blank on cold open |
| W9.5  | Streaming token-count badge                | `Views/Chat` already streams; cost transparency |

## Tier 2 — S, ship in the next 1–2 sessions

| ID    | Item                                       | Source / status                       |
| ----- | ------------------------------------------ | ------------------------------------- |
| W9.6  | Cost dashboard + per-session budget gate   | `agent_core/src/session_insights.rs` tracks `estimated_cost_usd`; never surfaced |
| W9.7  | Vault sidebar selector                     | LIVING_VAULT_ARCHITECTURE Vault-Per-Model registry — no switcher UI |
| W9.8  | Approval modal (PausedForApproval surface) | `SessionState::PausedForApproval { tool_name, args_json, deadline_secs }` exists; no view |
| W9.9  | Vision OCR clipboard pipeline              | `VNRecognizeTextRequest` integrated for screenshots; extend to clipboard |
| W9.10 | TurboQuant KV cache compression            | Google ICLR 2026; 6× memory, +25–32 % throughput, validated on M2 16 GB |

## Tier 3 — M, 2–3 weeks each (V1.5 candidates)

| ID    | Item                                       | Why                                   |
| ----- | ------------------------------------------ | ------------------------------------- |
| W9.11 | Create ML personalized embeddings          | 1 ms paragraph embeds vs 100 ms current; trains nightly via Night Brain |
| W9.12 | Orphan Knowledge Rediscovery               | Night Brain surfaces forgotten-but-relevant notes; uses existing HNSW + GRDB |
| W9.13 | Daily Notes + FSRS spaced repetition       | Logseq/Roam parity + modern FSRS (Ye SIGKDD 2022) replacing Leitner/SM-2 |
| W9.14 | Block References + Transclusion            | Logseq/Roam parity; copy-on-write embeds with edit propagation |
| W9.15 | Static compile-time view routing macro     | EPISTEMOS_DETERMINISTIC_PERF_PLAN Sprint 2 — eliminates AnyView/AttributeGraph diff cost |

## Tier 4 — V1.5+ (deferred)

| ID    | Item                                       |
| ----- | ------------------------------------------ |
| W9.16 | Graph drift / belief evolution timeline    |
| W9.17 | Working-memory window + activity context   |
| W9.18 | Dependency-aware query invalidation        |
| W9.19 | Slotmap + structure-of-arrays entity store |
| W9.20 | phf perfect-hash MCP / tool registries     |

## Tier 5 — Novel coding patterns (deep-research deep dive)

Surfaced by the deep-nest research pass on the Downloads corpus
(`arc8.txt`, `sw.txt`, `Metal Mamba 2 Research Prompt.txt`,
`MLX Constrained Decoding Research.md`, `EPISTEMOS_HERMES_MANIFESTO.md`,
`Epistemos Graph Engine Optimal Performance Roadmap.md`,
`vector quant.md`). These are 2026 production techniques distilled
from the user's own corpus, not generic best practices — each is a
genuinely rare pattern.

| ID    | Pattern                                                          | Source quote location                                                  | Effort | Wins                                                                    |
| ----- | ---------------------------------------------------------------- | ---------------------------------------------------------------------- | ------ | ------------------------------------------------------------------------ |
| W9.21 | **Honest FFI** — `Arc::into_raw` + `~Copyable` wrappers          | `arc8.txt`                                                             | M      | Eliminates UniFFI HandleMap mutex; zero-cost identity mapping            |
| W9.22 | **Typestate Islands** — `~Copyable` for MLX/subprocess lifecycles | `arc8.txt`                                                             | M      | Compile-time prevention of use-after-free on MLX sessions + Hermes proc |
| W9.23 | **Bit-packed circuit breaker** — AtomicU64 + popcnt              | `arc8.txt`                                                             | S      | Lock-free, zero-alloc resilience; 8 bytes per breaker; cache-line padded |
| W9.24 | **Metal zero-copy graph buffers** — `makeBuffer(bytesNoCopy:)`   | `sw.txt`                                                               | M      | Page-aligned Rust alloc → Metal binding; 120 Hz on 10 K-node graph       |
| W9.25 | **Grammar-constrained logit masking** — MLXLMCommon LogitProcessor | `MLX Constrained Decoding Research.md`                                 | L      | 100 % JSON / tool-call validity from local Qwen 7-8 B; no retry loops    |
| W9.26 | **B-tree text rope** — `crop` crate + UTF-16 metrics             | `sw.txt`                                                               | L      | O(log n) edits in code editor; no lag at 100 KB+ files                   |
| W9.27 | **Append-only OpLog + replay** — event-sourced graph             | `Epistemos_ Audit, Research, Design.md`                                | M      | Time-machine debugging; perfect undo; multi-user audit trail             |
| W9.28 | **Blelloch scan in Metal** — Mamba-2 prefill parallelism         | `Metal Mamba 2 Research Prompt.txt`                                    | L      | 5 s prefill on 100 K tokens; unlocks "vault as memory" vision            |
| W9.29 | **Thermal-aware breaker throttling** — global supervisor         | `arc8.txt`                                                             | S      | Pre-empt thermal hardware throttle by tightening breaker thresholds     |
| W9.30 | **KIVI per-channel/per-token KV quantisation**                   | `vector quant.md`                                                      | M      | 60 % KV memory cut; 2-bit Key + per-token Value asymmetric quant         |

### Top 3 from Tier 5 to ship first
- **W9.21 Honest FFI** — biggest concurrency bottleneck removed; foundation for everything else
- **W9.25 Grammar-constrained logits** — makes local-model tool-calling reliable enough to ship
- **W9.28 Blelloch scan** — required to actually cash in the Mamba-2 vault vision

## Pre-TestFlight ship gates (orthogonal to Wave 9)

These three close out V1 release-readiness; track in `KNOWN_ISSUES_REGISTER.md`:

- **P0-2** Reliability fresh baseline (re-run 5-gate suite post-Phase-R closure) — ~2 hr
- **P0-4** mas-sandbox feature-gating spot-check (`agent_core/src/tools/registry.rs` + `omega-mcp/src/pty.rs`) — ~30 min
- **P0-3** TestFlight submission metadata (screenshots, App Review notes draft already in `MAS_APP_REVIEW_NOTES.md`) — ~4 hr

## Sources

- `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md`, `docs/AGENT_PROGRESS.md`, `docs/KNOWN_ISSUES_REGISTER.md`
- `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md`, `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md`
- `~/Downloads/opt/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` + `Epistemos Performance Optimization Roadmap.txt`
- `~/Downloads/new features/Cognitive Computing Capabilities for a Native macOS Personal Knowledge System.md`
- `~/Downloads/last feature after new agents/LIVING_VAULT_ARCHITECTURE.md`
- `~/Downloads/cap5_night_brain.md` (orphan + FSRS sources)
- Cross-corpus grep against `Epistemos/` source for "exists in code, no UI" gaps
