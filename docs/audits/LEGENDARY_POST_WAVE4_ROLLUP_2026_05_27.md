# LEGENDARY Post-Wave-4 Roll-Up - 2026-05-27

Status: ground-truth checkpoint after Wave 4 and the post-merge audit pass.

Base commit before the F-ULP Metal artifact slice: `c8c4b50f15`
(`test(metal): add witness gate preflight (#133)`).

Latest checkpoint tag before the F-ULP Metal artifact slice:
`checkpoint/post-wave4-metal-witness-preflight-2026-05-27`.

This document is the post-Wave-4 answer to: "What is done, what is preserved
only, what is still partial, and what terminals should run next?"

## Evidence Gates

These passed after PRs `#121` through `#127` landed:

- `cargo test --manifest-path agent_core/Cargo.toml --lib --quiet`
  - 4,042 tests passed.
- `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTriFusionTypedMutationGate build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
  - build passed.
- `rustup run stable-aarch64-apple-darwin cargo test` in `graph-engine`
  - 2,777 lib tests plus integration/doc tests passed.
- `npm run typecheck` in `js-editor`
  - passed.
- Focused graph/editor guard:
  - `GraphPerformanceTests`
  - `GraphPhysicsSettingsAuditTests`
  - `HTMLWorkspaceSourceGuardTests`
  - passed, 65 tests / 3 suites.

Performance guard highlights from the focused run:

- 100 graph nodes loaded in 0.006s.
- 500 graph nodes loaded in 0.028s.
- 1,000 graph nodes loaded in 0.057s.
- 5,000 graph nodes loaded in 0.268s.
- 5,000-node fuzzy graph search completed in 0.352s.
- Gravity Well / snappy defaults and HTML Workspace source guards passed.

No stash was popped, dropped, bulk-applied, or checked out from during this
checkpoint.

Additional 2026-05-27 Metal witness evidence after the preflight slice:

- `Tools/metal-shader-compile/metal-shader-compile.sh`
  - passed; 26 shaders compile, with deferred warnings still emitted for
    PageGather / ControllerKernelPack / PacketRouter1bit.
- `swift Tools/metal-witness-gates/fulp-metal-oracle-artifact.swift --write-artifact`
  - passed; emitted `artifacts/falsifiers/ulp_oracle/result.json` as a full
    Metal `morphOracleFp16` primary witness.
- `cargo run --manifest-path agent_core/Cargo.toml --release --bin falsifier_validator -- artifacts/falsifiers/ulp_oracle/result.json`
  - passed.

## Main / PR State

- `main` equals `origin/main` at the base commit above.
- Open PRs are only preservation references:
  - `#81` - Claude shadow-handle WIP preservation.
  - `#82` - B-prime uncommitted follow-up stash preservation.
- Those PRs are not merge-ready product work. Do not raw-merge them unless a
  separate synthesis pass promotes a focused slice.

## W-Row Recount

The old `~34/53+` count was intentionally conservative before Wave 4 closed.
The honest post-Wave-4 accounting is:

- Strictly wired / product-visible enough to count: about `42/53`.
- Meaningfully advanced but still honest-orange or partial: about `7/53`.
- Still open / research-tier backlog: about `4/53`.

Percentages:

- Strict wired floor: about 79%.
- Strict + meaningful partial: about 92%.
- Substrate floor estimate: about 96%, because the remaining gaps are mostly
  visible truth, provenance-detail, and hardware/research gates
  rather than missing substrate skeleton.

Rows closed or materially advanced by Wave 4:

| Row | Current state | Evidence |
|---|---|---|
| W-01 | wired | Vault retrieval projects typed `UasAddress` values (#121). |
| W-02 | wired | Agent traces expose typed `UasKind::AgentTrace` addresses (#121). |
| W-03 | wired | ClaimLedger claims can carry `UasAddress` and `AcsAnchor` (#121). |
| W-04 | partial/product trace live | PageGather escalation is trace-visible and LIMIT-first-note fallback is removed (#122); full Metal/PageGather gate remains future. |
| W-06 | partial/product path live | One safe model-authored note edit travels as typed reversible `MutationEnvelope` (#124). |
| W-12 | wired/guarded | Per-model agent badges derive `HONEST` / `EXPERIMENTAL` / `OFF` from RuntimeRouter + F-LocalToolUse and surface in Settings, picker rows, ActiveConstellation, and AgentBlueprint. See `docs/audits/POST_WAVE4_AGENT_CAPABILITY_TRUTH_CLOSEOUT_2026_05_27.md`. |
| W-19 | wired | Chat/Vault retrieval uses provenance instead of hidden LIMIT-first-note context. |
| W-20 | wired | Provenance cards and citation surfaces are live after B-prime recovery. |
| W-21 | wired with caveat | VaultRecall metrics have measured artifacts; paraphrase metric remains lexical/informational. |
| W-22 | wired | Retrieval returns typed addresses (#121). |
| W-23 | wired | Vault Context Contract gate exists and passed in Wave 4 validation. |
| W-24 | wired | DAG/claim rows carry UAS/anchor/plane/residency metadata from T14 + #121. |
| W-25 | wired/guarded | ACS anchor data exists and the chat AnswerPacket badge now opens a compact UAS / ACS anchor / plane / residency detail popover. See `docs/audits/POST_WAVE4_PROVENANCE_RESIDENCY_DETAIL_2026_05_27.md`. |
| W-26 | wired | Cognitive DAG visualizer merged (#123). |
| W-27 | wired | AnswerPacket badge/provenance row surface is live from B-prime. |
| W-28 | partial/product visible | Residency types/guards exist and AnswerPacket detail now shows residency tier/signals; broader all-surface residency indicators remain a future polish slice. |
| W-29 | wired | Substrate Health panel is live. |
| W-30 | partial | Cognitive Weight badges exist in Settings; broader weight/residency display can still improve. |
| W-49 | wired/guarded | App Store guard for `IMessageDriverService` is already live; see `docs/audits/POST_WAVE4_W49_W53_HARDENER_CLOSEOUT_2026_05_27.md`. |
| W-53 | wired/guarded | `ModelDownloadManager` SHA256/LFS verification is already live; see `docs/audits/POST_WAVE4_W49_W53_HARDENER_CLOSEOUT_2026_05_27.md`. |

This recount does not delete the older 53-row audit. It gives a current
execution map from actual merged code and tests.

## Falsifier Recount

There are 10 `artifacts/falsifiers/*/result.json` files on main:

| Artifact | Status | Honest interpretation |
|---|---|---|
| `acs_anchor_lookup` | PASS | Product-relevant O(1)-style anchor lookup witness. |
| `uas_copy_count` | PASS | Product-relevant zero-copy/copy-count witness. |
| `vault_recall_50` | measured true | Current run passes exact-title and adversarial reject; paraphrase remains lexical/informational. |
| `eidos_bridge_round_trip` | measured true | Real Eidos bridge round-trip witness; Swift side covered by production bridge tests. |
| `hyperdynamic_loop_bounded` | measured true | Bounded repair loop witness. |
| `acs_anchor_addressing` | full measured true | N=1000 full harness with agent runtime emission, lookup, audit canonicalization, and five-plane projection inversion. See `docs/audits/ACS_ANCHOR_HARNESS_FULL_2026_05_27.md`. |
| `ulp_oracle` | measured true | Full Metal `morphOracleFp16` primary witness over 414,048 points / 1,242,144 evaluations; max ULP axes pass the <=2 budget. |
| `uas_zero_copy_spine` | measured true | Zero tracked copies in scoped spine; broader hot path can still be expanded. |
| `page_gather` | measured true | CPU scatter/PageGather artifact; full Metal STREAM-style gate pending. |
| `controller_kernel_pack` | measured true | CPU/reference kernel-pack witness; full Metal dispatcher pending. |

The `>=7 measured witnesses` objective is satisfied. The verified floor must
still keep hardware-caveat artifacts orange until their full production/hot-path
gate exists.

## Stashes And Preserved Work

The stash/recovery state is demystified as of this checkpoint:

- Product-recovered stash slices are already on main and documented.
- Preservation-only PRs `#81` and `#82` remain open as references, not product
  branches.
- The stash ledger remains the canonical map for old stash material:
  `docs/audits/STASH_RECOVERY_LEDGER_2026_05_26.md`.
- The broad substrate/research stash queue is closed for current product
  recovery by:
  `docs/audits/STASH_SUBSTRATE_RESEARCH_QUEUE_CLOSEOUT_2026_05_26.md`.
- The current rule remains: no stash pop/drop/bulk apply, and no raw restoration
  of legacy shells that current tests intentionally forbid.

## Seven Laws / No-Orphan Check

Wave 4 satisfies the No-Orphan check at the current floor:

- Motion: retrieval/claim work is Project/Recall; PageGather trace is
  Project/Recall; Tri-Fusion edits are Mutate/Promote.
- UAS: typed addresses are now present in retrieval, traces, claims, and ACS
  anchor boundaries.
- Plane: five-plane metadata is carried through T14 and used by DAG/claim
  surfaces.
- Residency: typed residency exists and has anti-drift guard docs/tests.
- WBO/error: approximation-heavy hardware witnesses remain caveated instead of
  green.
- Witness: RunEventLog, AnswerPacket, ClaimLedger, falsifier artifacts, and
  audit docs exist for the live motions.
- Falsifier: 10 artifacts exist; 7+ are measured.
- Tier: current-app vs verified-floor vs research-tier claims are separated.
- Rollback: Tri-Fusion typed mutation path includes deterministic rollback for
  its first product operation.

Remaining No-Orphan risks are not lost work; they are the next focused slices:

1. Broader all-surface residency polish outside the AnswerPacket/detail rows.
2. Full hardware research gates for PageGather / ControllerKernelPack.
   A 2026-05-27 Metal preflight now dispatches the source kernels and keeps
   those primary measurement artifacts pending instead of green. `F-ULP-Oracle`
   has advanced to a full Metal primary witness.

## Next Terminals

The product-floor terminals below are retired or complete. Next work should be
codeword-triggered research/hardware slices, not another broad product merge wave.

### Retired Terminal - Agent Capability Truth

Do not dispatch. Current source already closes W-12. Evidence lives in
`docs/audits/POST_WAVE4_AGENT_CAPABILITY_TRUTH_CLOSEOUT_2026_05_27.md`.

### Retired Terminal - Provenance / Residency Detail

Do not dispatch after this slice merges. The product-floor visibility gap is
closed by `docs/audits/POST_WAVE4_PROVENANCE_RESIDENCY_DETAIL_2026_05_27.md`.

Branch used:

```text
codex/post-wave4-provenance-residency-detail-2026-05-27
```

Historical prompt:

```text
You are Post-Wave-4 Terminal 2: Provenance / Residency Detail.

cd /Users/jojo/Downloads/Epistemos
git fetch origin
git checkout -b codex/post-wave4-provenance-residency-detail-2026-05-27 origin/main

Read first:
1. docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md
2. docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md
3. docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md

Goal:
Close the visible detail gap around ACS anchors, residency, and cognitive
weight without mutating retrieval or graph hot paths.

Scope:
1. Add a clickable ACS anchor/detail path in existing provenance surfaces.
2. Show residency tier and runtime plane consistently where a user inspects a
   claim, AnswerPacket, graph DAG count, or health row.
3. Keep the UI compact and non-blocking.
4. Add tests/source guards proving no green chip appears without a witness.

Rules:
- Do not mutate retrieval ranking, graph physics, or editor hot paths.
- No stash pop/drop/bulk apply.
- No git checkout from stash.
- No git add -A.
- PR must include Motion, UAS, Plane, Residency, WBO/error, Witness,
  Falsifier, Tier, Rollback.

Gates:
git diff --check
cargo test --manifest-path agent_core/Cargo.toml --lib
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

Stop after opening the PR. Do not merge yourself.
```

### Retired Terminal - Ship Hardening W-49/W-53

Do not dispatch. Current source already closes W-49 and W-53. Evidence lives in
`docs/audits/POST_WAVE4_W49_W53_HARDENER_CLOSEOUT_2026_05_27.md`.

## Later Terminals

Run these only after the product-floor closeout PRs are merged and the local
gate is green:

1. `RESUME ACS ANCHOR HARNESS`
   - Completed by `docs/audits/ACS_ANCHOR_HARNESS_FULL_2026_05_27.md`.
2. `RESUME METAL WITNESS GATES`
   - Preflight slice: `docs/audits/METAL_WITNESS_GATES_PREFLIGHT_2026_05_27.md`.
   - `F-ULP-Oracle` full Metal artifact: `artifacts/falsifiers/ulp_oracle/result.json`.
   - Still remaining: full Metal/PageGather and ControllerKernelPack measured
     throughput/latency artifacts. Keep them research-tier until real hardware
     measurements pass.
3. `RESEARCH CONSTRUCTION`
   - Candidate-only research construction engine. Do not affect live product
     behavior.
4. `FORK V3`
   - Second-repo endgame only after post-v2.0 tag.

## Current Best Next Move

Do not dispatch another broad product-floor wave. Main is now at the point where
the remaining work should be summoned by codeword:

1. `RESUME METAL WITNESS GATES`
2. `RESEARCH CONSTRUCTION`
3. `FORK V3` only after the post-v2.0 tag

Then rerun the local ground-truth gate after any future codeword slice:

```text
git diff --check
cargo test --manifest-path agent_core/Cargo.toml --lib --quiet
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosPostWave4NextGate build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```
