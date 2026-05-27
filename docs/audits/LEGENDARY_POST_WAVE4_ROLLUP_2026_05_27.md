# LEGENDARY Post-Wave-4 Roll-Up - 2026-05-27

Status: ground-truth checkpoint after Wave 4 and the post-merge audit pass.

Base commit: `38bf5e3130657274b9032648d755e84e4551644d`
(`test(audit): remove focused gate warnings (#127)`).

Checkpoint tag: `checkpoint/wave4-trifusion-typed-mutations-2026-05-27`.

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

- Strictly wired / product-visible enough to count: about `38/53`.
- Meaningfully advanced but still honest-orange or partial: about `7/53`.
- Still open / research-tier / ship-hardener backlog: about `8/53`.

Percentages:

- Strict wired floor: about 72%.
- Strict + meaningful partial: about 85%.
- Substrate floor estimate: about 93%, because the remaining gaps are mostly
  visible truth, supply-chain, provenance-detail, and hardware/research gates
  rather than missing substrate skeleton.

Rows closed or materially advanced by Wave 4:

| Row | Current state | Evidence |
|---|---|---|
| W-01 | wired | Vault retrieval projects typed `UasAddress` values (#121). |
| W-02 | wired | Agent traces expose typed `UasKind::AgentTrace` addresses (#121). |
| W-03 | wired | ClaimLedger claims can carry `UasAddress` and `AcsAnchor` (#121). |
| W-04 | partial/product trace live | PageGather escalation is trace-visible and LIMIT-first-note fallback is removed (#122); full Metal/PageGather gate remains future. |
| W-06 | partial/product path live | One safe model-authored note edit travels as typed reversible `MutationEnvelope` (#124). |
| W-19 | wired | Chat/Vault retrieval uses provenance instead of hidden LIMIT-first-note context. |
| W-20 | wired | Provenance cards and citation surfaces are live after B-prime recovery. |
| W-21 | wired with caveat | VaultRecall metrics have measured artifacts; paraphrase metric remains lexical/informational. |
| W-22 | wired | Retrieval returns typed addresses (#121). |
| W-23 | wired | Vault Context Contract gate exists and passed in Wave 4 validation. |
| W-24 | wired | DAG/claim rows carry UAS/anchor/plane/residency metadata from T14 + #121. |
| W-25 | partial | ACS anchor data exists; clickable provenance/detail column still needs a focused UI slice. |
| W-26 | wired | Cognitive DAG visualizer merged (#123). |
| W-27 | wired | AnswerPacket badge/provenance row surface is live from B-prime. |
| W-28 | partial | Residency types/guards exist; broader visible residency indicators remain a next slice. |
| W-29 | wired | Substrate Health panel is live. |
| W-30 | partial | Cognitive Weight badges exist in Settings; broader weight/residency display can still improve. |
| W-49 | open hardener | App Store guard for `IMessageDriverService` still needs a focused PR. |
| W-53 | open hardener | `ModelDownloadManager` SHA256/LFS verification needs a focused PR if not already fully enforced. |

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
| `acs_anchor_addressing` | scoped measured true | N=100 mini-harness; full four-stage projection inversion still future. |
| `ulp_oracle` | measured true | CPU/reference ULP witness; Metal gate remains research/hardware. |
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

1. Visible agent capability truth across all model/agent surfaces.
2. Clickable ACS anchor / residency details in provenance and graph surfaces.
3. App Store and supply-chain hardeners.
4. Full hardware research gates for PageGather / ULP / ControllerKernelPack.

## Next Terminals

Start only three terminals next. They are low-conflict and make main more
truthful instead of opening another broad substrate wave.

### Terminal 1 - Agent Capability Truth

Branch:

```text
codex/post-wave4-agent-capability-truth-2026-05-27
```

Prompt:

```text
You are Post-Wave-4 Terminal 1: Agent Capability Truth.

cd /Users/jojo/Downloads/Epistemos
git fetch origin
git checkout -b codex/post-wave4-agent-capability-truth-2026-05-27 origin/main

Read first:
1. docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md
2. docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md
3. docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md

Goal:
Every model/agent surface shows honest capability state:
HONEST, EXPERIMENTAL, or OFF.

Scope:
1. Audit existing RuntimeRouter, AgentBlueprint, model picker, Settings, and
   chat surfaces for hidden "agent capable" claims.
2. Add/finish per-model badges grounded in lane witness and F-LocalToolUse
   status.
3. Surface the badge in Settings, model picker, and AgentBlueprint selectors.
4. Add tests for disabled, experimental, verified, and power-user modes.

Rules:
- No stash pop/drop/bulk apply.
- No git checkout from stash.
- No git add -A.
- Do not resurrect AgentCommandCenter.
- PR must include Motion, UAS, Plane, Residency, WBO/error, Witness,
  Falsifier, Tier, Rollback.

Gates:
git diff --check
cargo test --manifest-path agent_core/Cargo.toml --lib
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

Stop after opening the PR. Do not merge yourself.
```

### Terminal 2 - Provenance / Residency Detail

Branch:

```text
codex/post-wave4-provenance-residency-detail-2026-05-27
```

Prompt:

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

### Terminal 3 - Ship Hardening

Branch:

```text
codex/post-wave4-ship-hardening-w49-w53-2026-05-27
```

Prompt:

```text
You are Post-Wave-4 Terminal 3: Ship Hardening W-49/W-53.

cd /Users/jojo/Downloads/Epistemos
git fetch origin
git checkout -b codex/post-wave4-ship-hardening-w49-w53-2026-05-27 origin/main

Read first:
1. docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md
2. docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md
3. docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md

Goal:
Close the two low-conflict ship hardeners:
W-49 IMessageDriverService App Store guard and W-53 ModelDownloadManager
SHA256/LFS verification.

Scope:
1. Audit IMessageDriverService for App Store build exposure and add a strict
   compile-time/runtime guard if missing.
2. Audit ModelDownloadManager for SHA256/LFS verification and make the
   verification explicit, testable, and visible in Settings if needed.
3. Add focused Swift tests for guard-on, guard-off, missing checksum, wrong
   checksum, and happy path.

Rules:
- Minimal fixes only.
- No adjacent refactors.
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

## Later Terminals

Run these only after the three terminals above are merged:

1. `RESUME ACS ANCHOR HARNESS`
   - Promote the scoped `F-ACS-Anchor-Addressing` N=100 mini-harness into the
     full four-stage projection-inversion falsifier.
2. `RESUME METAL WITNESS GATES`
   - Full Metal/PageGather, ULP, and ControllerKernelPack gates. Keep them
     research-tier until real hardware measurements pass.
3. `RESEARCH CONSTRUCTION`
   - Candidate-only research construction engine. Do not affect live product
     behavior.
4. `FORK V3`
   - Second-repo endgame only after post-v2.0 tag.

## Current Best Next Move

Dispatch the three terminals above, merge in this order:

1. Ship Hardening W-49/W-53.
2. Agent Capability Truth.
3. Provenance / Residency Detail.

Then rerun the local ground-truth gate:

```text
git diff --check
cargo test --manifest-path agent_core/Cargo.toml --lib --quiet
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosPostWave4NextGate build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```
