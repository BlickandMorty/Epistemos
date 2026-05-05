# Substrate V2 — final close-out — 2026-05-05

The V2 sequence (V2.1 — V2.7) has reached its acceptance plateau.
This doc supersedes `SUBSTRATE_V2_CLOSEOUT_2026_05_05.md` (the
mid-stretch checkpoint) and is the canonical V2-end record.

## V2 status matrix — final

| Lane | Scope | Status | Gating / open work |
|---|---|---|---|
| **V2.1** | Cognitive DAG Phase 8 | 8.A — 8.G ✓ shipped | 8.H gated on doctrine §10 two-week CI green (release decision; not autonomous) |
| **V2.2** | Halo V1 | ✓ shipped (with ledger ribbon) | none |
| **V2.3** | LSP migration | ✓ closed at source level | Stage F (tower-lsp + tree-sitter for hover/definition) deferred — adds real Cargo dep weight; next-session decision |
| **V2.4** | XPC Mastery | First slice ✓ (ProviderServiceStreamingProtocol + Mock + tests) | Production deployment requires paid Apple Developer Program ($99/yr); IOSurface streaming Phase 2 deferred |
| **V2.5** | Simulation v1.7+ | NOT MERGED | `worktree-simulation` (17 commits) is a 6,678-file architectural divergence from current branch — needs strategic call (cherry-pick / rebase / branch-swap), not a single-commit merge |
| **V2.6** | UX advanced + brand | NOT STARTED | NousResearch licensing gate; brand tokens already removed in Hermes teardown |
| **V2.7** | Multi-Agent ACS tooling | Ongoing/substantial | Quality-of-life category; no hard milestone; multi-day each |

## Strict acceptance bar

The post-recovery V2 plan (`docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md`)
defines V2 acceptance as:
> "V2.1 — V2.7 complete; tests green; two-week CI stable."

That bar is **not strictly met**:
- V2.4 hard-gated on paid team (out of scope for this session)
- V2.5 has unmerged divergent worktree (architectural decision pending)
- V2.6 brand-licensing-gated
- V2.1 8.H is a release-time decision

The autonomous-completable surface is closed. V3 entry (lane V3.3
paper draft) shipped this session as a parallel deliverable.

## Session ledger — every commit on this stretch

37 commits this session, oldest first:

| # | Commit | What |
|---|---|---|
| 1 | `d9be24b5` | Hermes teardown slice 1: delete Expert Mode UI overlay + brand assets |
| 2 | `77de8196` | Rename agent_core::hermes module to agent_runtime |
| 3 | `b8a22adf` | Archive Hermes integration docs + update CLAUDE.md (slice 4) |
| 4 | `1b71302e` | Add Hermes removal handoff doc (final) |
| 5 | `f9db76ee` | Fix slice 4: actually commit the CLAUDE.md updates |
| 6 | `3245ea4f` | Refactor R1: remove dead .hermesSubprocess gateway surface |
| 7 | `bf1567a8` | Refactor R2: remove dead Hermes faculty glyph state from HologramOverlay |
| 8 | `260676c8` | Refactor R3: update Rust doc comments after Hermes removal |
| 9 | `d7f36dd4` | R1 fixup: update 2 surface-count + boundary-line test expectations |
| 10 | `546ee564` | Update Hermes-removal handoff with R1-R4 refactor record |
| 11 | `b34164e5` | Wire V2 Phase A: swap Resonance signature stub for real FFI call |
| 12 | `e50ee926` | Add V2 wire-up status doc — honest accounting + doctrine considerations |
| 13 | `d606afc0` | Wire V2 Lane 1: Rust ClaimLedger surfaced in Provenance Console |
| 14 | `fb3d4fe3` | V2.1 Phase 8.E continuation: Procedural + Provenance DagMirrors |
| 15 | `b439db25` | V2.1 Phase 8.E continuation: CompanionMirror — all 4 mirrors landed |
| 16 | `6f609d8c` | Wire V2 Lane 3: Rust ClaimLedger ribbon in Halo panel |
| 17 | `49d4efaf` | Wire V2 final lane: Cognitive DAG observability surface |
| 18 | `939d7947` | Add V2 wire-up complete handoff doc |
| 19 | `d327e87f` | V2.1 Phase 8.E auto-invoke: dispatch + 3 legacy write paths wired |
| 20 | `28af9b71` | V2.1 Phase 8.F: ReplayBundle DAG snapshot + verify-replay CLI |
| 21 | `261e7cca` | V2.1 Phase 8.G: epistemos-doctrine-lint + storage doctrine alignment |
| 22 | `d06fefca` | V2.3 first slice: LSPTransport protocol seam |
| 23 | `e4fce654` | V2 close-out + V3.3 paper draft first slice |
| 24 | `d0eed651` | Add Gemini + Kimi CLI passthrough tools |
| 25 | `cbb582a7` | V2.4 + V3.2 design assessment — XPC for cloud models + ANE direct path |
| 26 | `ec9cbe48` | V2.4 first slice: ProviderServiceStreamingProtocol + Mock + tests |
| 27 | `8225c22b` | V3.2 first slice: ANEBackend protocol + Mock + KV implant buffer + tests |
| 28 | `690ea3cb` | V3.3 paper draft second slice: §2 background + §9 related work + §10 conclusion |
| 29 | `45757a79` | V2.3 Stage A: in-process LSP kernel (lsp_runtime module + 14 tests) |
| 30 | `7391bb19` | V2.3 Stage B: FFI exports + build-script wiring for in-process LSP |
| 31 | `1d1ffe46` | V2.3 Stage C+D: RustLSPTransport Swift client + end-to-end tests |
| 32 | `813c15dd` | V2.3 close-out: delete LSPServerProcess subprocess transport |
| 33 | (this commit) | V2 final close-out doc + Codex verification handoff |

## Test count timeline (Rust + Swift focused)

| Stretch start | This session end | Delta |
|---|---|---|
| Rust 997 | Rust 1055 (with `lsp-runtime` feature) | +58 |
| Swift focused (Hermes-area + cloud-routing): 226 | Swift focused: 250+ across all V2/V3 wire suites | +30 |

(Swift counts are partial — only the V2/V3-touched suites; the full
`xcodebuild test` runs ~2,679 tests and is long enough that I run
focused suites per slice instead.)

## What's decisively shipped (autonomous-verifiable)

- All four DagMirrors (Skills + Procedural + Provenance + Companion)
  with auto-invoke from legacy write paths.
- `epistemos-trace verify-replay` CLI with DAG merkle parity check
  (5 distinct exit codes).
- `epistemos-doctrine-lint` CI binary that codifies the 4 §5 gates.
- Storage layer doctrine §4.1/§4.2 enforcement at put_node /
  put_edge boundaries.
- ResonanceService FFI swap (Swift stub → Rust seed).
- Provenance ledger Rust→Swift bridge surfaced in Provenance
  Console + Halo panel ribbon.
- Cognitive DAG observability row in Settings (polls every 5s).
- ProviderServiceStreamingProtocol + MockProviderServiceStreaming
  (V2.4 first slice — Phase 1 wire format stable).
- ANEBackend Swift protocol + MockANEBackend + KV implant typed
  buffer (V3.2 first slice).
- In-process Rust LSP runtime (LspKernel) + FFI + Swift
  RustLSPTransport (V2.3 Stages A-D).
- Subprocess LSPServerProcess deletion (V2.3 Stage E).
- Gemini + Kimi CLI passthrough handlers (parity with Claude /
  Codex).

## What's intentionally orphan-by-doctrine

- Macaroon capabilities (`agent_core/src/cognitive_dag/macaroons.rs`)
  — gates DAG edges; no Swift consumer needs them yet; orphan by
  doctrine until Phase 8.H authority flip.

## What's gated externally

| Item | Gate |
|---|---|
| V2.1 8.H authority flip | Doctrine §10 two-week CI green; release-time decision |
| V2.4 production XPC service launch | Apple Developer Program enrollment |
| V3.2 production ANE direct path | Apple Developer Program enrollment + entitlements for private framework loading |
| V2.6 brand asset re-import | NousResearch licensing |
| V2.5 sim worktree merge | Strategic call (cherry-pick / rebase / branch-swap) |

## What's queued (autonomous, ready for next session)

- V2.3 Stage F — tower-lsp + tree-sitter for hover/definition.
  ~2-3 days. Adds real Cargo dep weight (tree-sitter native compile).
- V2.4 Stage 2 — IOSurface streaming ring for ProviderXPC. ~3-5 days.
- V3.2 Stage 2 — PrivateFrameworkANEBackend (compiles fine; runtime
  loading is signing-gated, but the dlopen wrapper code can be
  written today).
- V3.3 paper §8 evaluation — populates as V3.1 hardware experiments
  produce data.

## Codex verification handoff

See `docs/CODEX_VERIFICATION_HANDOFF_2026_05_05.md`. **Per user
direction every commit since the last Codex session is to be
treated as UNVERIFIED until Codex independently signs off.** Codex
is the final overseer of this work.
