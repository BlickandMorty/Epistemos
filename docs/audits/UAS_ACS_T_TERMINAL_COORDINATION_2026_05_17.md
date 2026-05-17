---
state: audit
created_on: 2026-05-17
terminal: T3 — UAS-ACS Canonical Architecture
branch: codex/t3-uasacs-2026-05-16
scope: Phase A iter 17 — enumerate every cross-terminal boundary T3's Phase B/C implementation work touches. One row per boundary: artifact + owner + producer/consumer direction + handshake protocol + current status + iter-when-needed.
authority: driver scope locks (T3 owns + T3 doesn't touch); audit §F open questions 2-4; canonical doctrine §8 open question 3 (T1 UasKind coordination).
---

# UAS-ACS T-Terminal Coordination Handles — 2026-05-17

> Phase A iter 17 deliverable. Every artifact that crosses the T3 scope boundary is enumerated here with the
> direction (T3 produces / T3 consumes), the owning terminal, the handshake protocol, and the iter where T3
> needs the handshake closed. This prevents Phase B blockers from being discovered mid-iter; instead they
> surface upfront with named coordination requirements.

## §1. T3 scope boundaries — recap

Per driver prompt scope lock:

**T3 owns** (free to edit, extend, create):
- `agent_core/src/uas/` (NEW module — Phase B.G.B1)
- `agent_core/src/research/acs/` (extend; never break)
- `agent_core/src/research/active_assembly/` (NEW)
- `agent_core/src/research/page_gather/` (NEW — Metal kernel)
- `agent_core/src/research/local_recall_island/` (NEW)
- `agent_core/src/research/scan_ir/` (coordinate with T5)
- `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md`
- `docs/falsifiers/F-*.md`
- `docs/audits/UAS_ACS_*.md`
- `tests/uas_*.rs · acs_*.rs · page_gather_*.rs`

**T3 DOES NOT TOUCH** (other terminals' scope):
- `tri_fusion` (T1)
- `agent_runtime` (T2)
- `vault.rs` (T4)
- `research/eml` (T7)
- UI (T6)
- biometric (T8)

## §2. T1 coordination — UasKind types (tri_fusion ↔ UAS)

**Handle**: `UasKind` enum in `agent_core/src/uas/kind.rs` (T3 owns the file; T1 contributes variants).

**Direction**: T3 produces the enum surface (the `enum UasKind { ... }` plus serialization + tests). T1
consumes it from `tri_fusion` lane and may propose new variants as their MD ⇄ JSON ⇄ HTML schema work
evolves.

**Why**: per driver "COORDINATION: T1 UasKind types". UasKind tags the substrate kind of a UAS-addressed
artifact (vault note · graph node · KV page · model component · agent trace · tool result · tri-fusion
content block · ...). T1 owns `tri_fusion` (hyperdynamic-schema content fabric) and needs UasKind
variants for tri-fusion artifacts.

**Initial variant set proposed by T3** (Phase B.G.B1 target):

```rust
pub enum UasKind {
    VaultNote,           // Markdown vault notes
    GraphNode,           // Cognitive DAG nodes
    KvPage,              // KV cache pages (hot / warm / cold tiers)
    ModelComponent,      // VPD-extracted component (T7 lane)
    AgentTrace,          // agent_runtime trace events (T2 lane)
    ToolResult,          // tool execution results
    AnswerPacket,        // SCOPE-Rex AnswerPacket emission
    TriFusionBlock,      // T1 content-fabric block (T1 to refine)
    Other(SmolStr),      // forward-compat escape hatch
}
```

**Handshake protocol**:

1. T3 lands `UasKind` with the proposed variants above (Phase B.G.B1, iter 21).
2. T3 commits with `BLOCKER: T1 UasKind variants — review needed before iter 30` in the message.
3. T1 reviews; either accepts the variants or proposes additions/renames.
4. T3 incorporates T1 feedback before iter 30 (Phase B.G.B2 onward depends on stable UasKind shape).

**Status as of 2026-05-17**: Phase B.G.B1 NOT YET STARTED. Handshake pending.

**Risk if not closed by iter 30**: F-UAS-ZeroCopy-Spine harness (iter 25 target) consumes UasKind; if the
enum shape changes later, the harness needs re-running. Mitigate by writing the harness to be variant-set
agnostic (deserialization round-trip through `Other(SmolStr)` fallback).

## §3. T4 coordination — vault retrieval as Shadow-paging consumer

**Handle**: `agent_core/src/storage/vault.rs` (T4 owns) consumes the Shadow-first paging substrate that T3
produces (Phase B.G.B4 + F-ShadowFirst-PageEscalation).

**Direction**: T3 produces (Shadow paging escalation policy, HeliosPage three-stage pipeline,
`agent_core/src/research/page_gather/` Metal driver). T4 consumes via vault retrieval.

**Why**: per driver "COORDINATION: T4 retrieval consumes Shadow paging". The T4-owned `F-VaultRecall-50`
gate (§4.H, gate #1 in §4.G ladder) needs Shadow paging to honestly find the right notes; the V1
differentiator at `epistemos-shadow/src/` is the current-app analog, but F-VaultRecall-50 requires the
Shadow-first paging escalation (sketch → residual → exact) to be wired in.

**Handshake protocol**:

1. T3 lands HeliosPage three-stage pipeline (Phase B.G.B4, iter ~35).
2. T3 commits with cross-link to `agent_core/src/storage/vault.rs` documenting the consumer API.
3. T4 wires vault retrieval to consume the pipeline.
4. F-VaultRecall-50 + F-ShadowFirst-PageEscalation pass together (composite acceptance).

**Status as of 2026-05-17**: T3 Phase B.G.B4 NOT YET STARTED. T4 has the F-VaultRecall-50 dataset spec
(see audit reference: `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md`).

**T3 does NOT edit `vault.rs`.** Per scope lock; T3 only provides the upstream substrate.

## §4. T5 coordination — Scan-IR primitive (SSM kernel doctrine)

**Handle**: `agent_core/src/research/scan_ir/` — T5 owns; T3 coordinates as a downstream consumer.

**Direction**: T5 produces (Scan-IR primitive types, kernel-doctrine substrate for SSMs). T3 consumes via
F-SemiseparableBlockScan-Correctness harness (gate #8 in §4.G ladder).

**Why**: per driver "COORDINATION: T5 Scan-IR API". Scan-IR is the kernel-grade IR family for SSMs
(Mamba-2, RWKV-7, Jamba) per driver §4.I "EML-IR Primitive Stack". F-SemiseparableBlockScan needs the
Scan-IR primitive types to express the SSD scan kernel uniformly across SSM model families.

**Handshake protocol**:

1. T5 lands `agent_core/src/research/scan_ir/` with `ScanIR::SemiseparableBlock { ... }` variant.
2. T3 consumes the variant in the F-SemiseparableBlockScan harness (Phase C, iter ~60).
3. Two-track gate (F-SemiseparableBlockScan Track A correctness) refers to Scan-IR types for the kernel
   under test.

**Status as of 2026-05-17 (iter 57 update)**: `agent_core/src/research/scan_ir/` does NOT exist on this
T3 worktree. **T5 EML-IR full-execution override active** per memory `project_terminal_t5_override_2026_05_17`
on branch `codex/t5-emlir-2026-05-16` at worktree `/Users/jojo/Downloads/Epistemos-t5-emlir` ("six IR
scope lock"). T5 is actively producing the six-IR layer; Scan-IR will land in that worktree's
research/scan_ir/ path. T3 reads-only when T5 publishes; cross-terminal merge will bring it to main.
Phase C dependency, not blocking Phase B.

**Mitigation if T5 lags**: T3 can use the existing `agent_core/src/helios/ssd_block_scan.rs` (Rust CPU
scalar reference, 385 LOC) as the de-facto Scan-IR primitive until T5 lands the formal types. The Metal
kernel under test would compare to this Rust reference directly.

## §5. T7 coordination — EML integration + F-ULP-Oracle oracle reference

**Handle**: `agent_core/src/research/eml/ulp_oracle.rs` — T7 owns runtime-layer EML integration; T3
consumes for F-ULP-Oracle gate.

**T5/T7 boundary clarification (iter 57 update)**: The EML work is split across two terminals:
- **T5 (EML-IR layer)**: six-IR scope lock per `project_terminal_t5_override_2026_05_17`. Owns the
  IR type surface (Scan-IR + 5 sibling IRs); `oxieml::EmlTree` type definition may live here.
- **T7 (EML integration runtime)**: per `project_terminal_t7_override_2026_05_17`, §4.B runtime-layer
  on `/Users/jojo/Downloads/Epistemos-t7-eml`. Owns `oxieml::EmlTree::eval_real` runtime evaluator
  + `agent_core/src/research/eml/ulp_oracle.rs`.
- T3 stays read-only on both; F-ULP-Oracle harness consumes whichever terminal lands the oracle
  reference first.

**Direction**: T7 (runtime) produces the oracle reference (`oxieml::EmlTree::eval_real`); T5 (IR layer)
may produce the `EmlTree` type definition itself. T3 consumes the runtime evaluator in the F-ULP-Oracle
harness (W1 in V6.1 foundation sequence, gate doc landed iter 15).

**Why**: per driver "COORDINATION: T7 active-assembly primitives" + driver §4.I EML-IR ownership. The Morph
DSL evaluator kernel (T3-owned: `Epistemos/Shaders/morph_eval_reduced.metal v0.1`) must match the T7-owned
`oxieml::EmlTree::eval_real` reference within ≤ 2 ULP fp16 over 412k log-sampled + 2k stress points within
90 s on M2 Pro 16 GB (per V6.1 foundation intake §"W1 F-ULP Oracle", captured verbatim in
`docs/falsifiers/F-ULP-Oracle_2026_05_17.md` §4).

**Handshake protocol**:

1. T7 lands `oxieml` vendored read-only (V6.1 stage 1 — already live as of 2026-05-17 per V6.1 intake).
2. T7 stabilizes `oxieml::EmlTree::eval_real` API surface and publishes the function signature.
3. T3 wires F-ULP-Oracle harness to call into `oxieml::EmlTree::eval_real` for the reference value.
4. T3 lands `morph_eval_reduced.metal v0.1` (Phase B, iter ~40).
5. T3 runs the F-ULP-Oracle gate; on pass, AnswerPacket schema freeze unlocks (V6.1 stage 5).

**Status as of 2026-05-17**:

- T7 `oxieml` vendored: ASSUMED live (per V6.1 intake §"Stage Mapping" step 1). T3 should verify with T7
  before consuming.
- T3 `morph_eval_reduced.metal v0.1`: NOT YET STARTED. Phase B target.
- F-ULP-Oracle harness: spec landed iter 15; implementation Phase B.

**Risk if T7 oracle reference API changes**: T3's F-ULP-Oracle harness becomes incompatible. Mitigate by
adding a doctrine-cross-reference comment on the eventual harness file pointing to the T7 oracle.

## §6. T2 + T6 + T8 boundaries (no active handshake; documented for completeness)

**T2 (agent_runtime)**: T3 produces `UasAddress` + `AcsAnchor`; T2 consumes them in agent_runtime trace
emission. **T3 does NOT edit `agent_runtime`.** No active handshake required; T2 reads our produced types.

**T6 (UI)**: T3 produces substrate; T6 surfaces it (e.g. SCOPE-Rex AnswerPacket UI badges, Halo/Shadow
panel from #36 epistemos-shadow). **T3 does NOT edit UI.** No active handshake required.

**T8 (biometric)**: No direct UAS-ACS substrate touch. The biometric lock is at the §4.D layer (§4.G ADMISSION
FIELD ACS/CMS-X #21); orthogonal to T3's substrate work.

## §7. Handshake-status matrix (one-line summary)

| Boundary | Owner | Direction | T3 iter when needed | Status 2026-05-17 |
|---|---|---|---|---|
| §2 UasKind (T1) | T3 owns surface · T1 owns variants | bidirectional | iter 21 (B.G.B1) | NOT YET STARTED |
| §3 Shadow paging → vault.rs (T4) | T3 produces · T4 consumes | T3 → T4 | iter ~35 (B.G.B4) | T4 has F-VaultRecall-50 spec; T3 has not yet produced HeliosPage |
| §4 Scan-IR primitive (T5) | T5 produces · T3 consumes | T5 → T3 | iter ~60 (Phase C, F-SemiseparableBlockScan) | **T5 full-execution override active 2026-05-17** on codex/t5-emlir-2026-05-16; six-IR scope lock; module pending; T3 mitigation = use helios/ssd_block_scan.rs as de facto primitive |
| §5 oxieml::EmlTree::eval_real (T7) | T7 produces · T3 consumes | T7 → T3 | iter ~40 (B Morph kernel + F-ULP-Oracle harness) | **T7 full-execution override active 2026-05-17** on codex/t7-eml-2026-05-16; §4.B runtime-layer; T5/T7 boundary clarified §5 above |
| §6 UasAddress / AcsAnchor → agent_runtime (T2) | T3 produces · T2 consumes | T3 → T2 (passive) | iter 21+ (whenever T3 lands the types) | no active handshake; T2 reads our types |
| §6 substrate → UI (T6) | T3 produces · T6 surfaces | T3 → T6 (passive) | as T3 lands substrate | no active handshake |
| §6 biometric (T8) | no T3 touch | — | — | no boundary |

## §8. Surfacing in commit messages

When T3 commits work that crosses a boundary, the commit message must include a `COORDINATION:` line
naming the boundary + iter status. Examples:

- `COORDINATION: T1 UasKind variants — review needed before iter 30` (when landing initial UasKind enum).
- `COORDINATION: T4 vault retrieval — Shadow-paging consumer API landed at agent_core/src/research/page_gather/api.rs` (when landing the consumer-facing API).
- `COORDINATION: T7 oxieml::EmlTree::eval_real — API surface verified live` (when wiring F-ULP-Oracle).

This makes the handshake state visible in `git log` so the next iter can see what's outstanding.

## §9. Cross-references

- Driver authority: scope-lock sections in the iter-1 starting prompt + driver §4.G COORDINATION line.
- Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §8 open question 3
  (UasKind coordination) — now CLOSED here.
- Substrate-floor audit: `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` §F questions 2-4 — now
  CLOSED here.
- Morph deep-dive (T7 handshake context): `docs/audits/UAS_ACS_MORPH_DEEP_DIVE_2026_05_17.md` §5.
- F-ULP-Oracle gate (T7 handshake spec): `docs/falsifiers/F-ULP-Oracle_2026_05_17.md` §3 (oracle reference)
  + §9 (dependencies).
- V6.1 foundation stage mapping: `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` §"Stage
  Mapping".
