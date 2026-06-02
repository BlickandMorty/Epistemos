---
state: candidate-intake
created_on: 2026-05-24
purpose: Source intake and fork-mining protocol for the Shadow Projection / Research Construction doctrine. Converts current online research into Epistemos work items without letting external hype bypass local falsifiers.
promotion_rule: No public repo, fork, PR, paper, forum thread, or leaderboard result promotes code into Epistemos by itself. Every intake item must map to a local W/P/T/F row, tier, falsifier, rollback path, and No-Orphan check before implementation.
local_anchors:
  - docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  - docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md
  - docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md
  - docs/HELIOS_V5_DOC_6_THEOREM_CANON.md
  - docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

# Online Research Intake — Shadow Projection / Research Construction — 2026-05-24

## 0. Why this exists

The architecture is now pulling from three kinds of knowledge at once:

1. local canon and worktrees
2. external papers and official research announcements
3. public code ecosystems: GitHub repos, forks, pull requests, issues, discussions, and forum writeups

This doc is the guardrail. It lets agents search widely, but it forces every external idea through the same Epistemos floor:

```text
source → motif → local primitive → W/P/T/F row → tier → falsifier → rollback → implementation
```

If an agent cannot fill that chain, the idea remains research intake.

## 1. Source credibility ladder

Use this order when sources disagree:

| Rank | Source class | Can it define canon? | How agents may use it |
|---|---|---|---|
| 1 | Current Epistemos code + passing local logs | yes | source of implementation truth |
| 2 | Local canon docs in `docs/fusion/` and `docs/HELIOS_*` | yes | source of architectural intent |
| 3 | Official paper / official repo / official challenge rules | no, but strong candidate source | define candidate doctrine or falsifier targets |
| 4 | arXiv / peer-visible companion papers | no, but strong technical evidence | refine proofs, caveats, and benchmark design |
| 5 | Accepted leaderboard records / reproducible record folders | no | mine motifs and benchmark methods |
| 6 | Open GitHub PRs, forks, issues, discussions | no | signal only; never raw-merge |
| 7 | forums, Reddit, blogs, summaries | no | discovery only; must link back to paper/repo/code |

The public web validates and expands the plan. It does not replace the user's local research corpus.

## 2. Current external source floor

| Source | URL | Verified finding | Epistemos intake |
|---|---|---|---|
| OpenAI unit-distance announcement | https://openai.com/index/model-disproves-discrete-geometry-conjecture/ | OpenAI states an internal model found an infinite family beating the long-held grid-style lower-bound intuition for the planar unit-distance problem, with external mathematician checking. | Supports `L8?`, `E8?`, `E9?` as candidate lift/project doctrine, not production proof. |
| Companion remarks | https://arxiv.org/abs/2605.20695 | Human-verified, digested explanation of the OpenAI counterexample; attributes the mechanism to deep number-theoretic ideas such as Ellenberg-Venkatesh, Golod-Shafarevich, and Hajir-Maire-Ramakrishna. | Strengthens the "unexpected coordinate chart" reading; also proves why human verification stays mandatory. |
| Will Sawin explicit bound | https://arxiv.org/abs/2605.20579 | Gives explicit point sets with more than `n^1.014` unit-distance pairs, improving the OpenAI result with an explicit exponent. | Local falsifier should test whether explicit coordinate lift beats surface-native baselines in Epistemos tasks. |
| OpenAI Parameter Golf writeup | https://openai.com/index/what-parameter-golf-taught-us/ | OpenAI reports 1,000+ participants, 2,000+ submissions, heavy coding-agent use, and motifs across optimization, quantization, TTT, tokenization, recurrence, attention, and new modeling ideas. | Supports a local Research Construction Engine with agent-assisted triage and reproducibility gates. |
| OpenAI Parameter Golf repo | https://github.com/openai/parameter-golf | Public MIT repo, 16 MB artifact limit, 10 minute 8xH100 budget, FineWeb bits-per-byte scoring, thousands of forks, large PR ecosystem. | Primary performance-intake repo. Mine records and motifs, not raw code. |
| EML arXiv paper | https://arxiv.org/abs/2603.21852 | Odrzywolek shows `eml(x,y)=exp(x)-ln(y)` plus constant `1` generates the scientific-calculator elementary basis as uniform binary trees. | Validates EML as a formal/math/proof IR, not as the whole substrate ontology. |
| `tomdif/eml-lean` | https://github.com/tomdif/eml-lean | Lean 4 formalization of the EML paper, small repo, recent activity, forks exist. | T5 Lean custody lane: audit license/toolchain, then vendor or submodule only through a setup PR. |
| EML inexpressibility | https://arxiv.org/abs/2605.01636 | Shows an EML-expressible number class has formal limits; Chaitin's Omega is inexpressible. | Adds the caveat agents need: EML is powerful but bounded. |

## 3. Parameter Golf intake motifs

The Parameter Golf official repo and writeup show these motifs. They are not claims that Epistemos should copy code; they are research prompts to route through W-PERF rows.

| Motif | Public signal | Epistemos home | Candidate win | Gate |
|---|---|---|---|---|
| Score-first TTT / LoRA TTT | official writeup highlights score-first per-document LoRA TTT as valid but review-sensitive | T26 L_SE, Research Construction Engine | bounded adapter updates while using a model | WBO drift + rollback + user-visible adapter ledger |
| Self-generated GPTQ calibration | official writeup highlights self-generated GPTQ Hessian calibration | W-PERF-2 | local calibration for quantized routes | quality rollback + copy-count + reproducible artifact |
| CaseOps tokenizer / byte sidecars | official writeup highlights lossless capitalization operator tokens with BPB accounting | Eidos/VaultRecall/AnswerPacket | preserve exact surface bytes while using compressed symbolic side channels | citation byte-roundtrip falsifier |
| XSA / sparse attention gates | official writeup highlights efficient partial attention variants | Active Assembly selector | wake smaller support sets | `F-ActiveAssembly-Minimal` |
| SmearGate / BigramHash | official writeup highlights learned previous-token blend and pair hash features | PageGather + token route profiles | cheap local features before heavier inference | latency + quality + rollback |
| Mini depth recurrence | official writeup highlights repeated layers that work effectively | Scan-IR / SSM / runtime route | more effective virtual depth per byte | `F-SemiseparableBlockScan-Correctness` |
| Binary / ternary quantization | official repo records include 1-bit and ternary quantization entries | Sherry/Leech VQ + ternary kernel | 16 GB Mac viability for stronger local routes | M2 Pro quality, memory, copy-count |
| Mamba / SSM / H-Net / byte-level studies | non-record track records | Scan-IR shadow lane | alternative sequence state charts, not replacements for transformer path | long-context and resume/staleness falsifiers |
| Adapter on random linear maps | non-record records | L_SE + Active Assembly | small learned adapters over regenerated maps | deterministic seed + provenance + rollback |

## 4. GitHub fork and PR mining rule

Agents may inspect public forks and PRs, but must never raw-merge them. Every candidate must be normalized into one of these intake buckets:

| Bucket | Examples | Required local conversion |
|---|---|---|
| Kernel | fused CE, sparse attention gate, ternary GEMM, XNOR kernels | Metal/Rust microbench + CPU oracle + rollback |
| Quantization | GPTQ, QAT, int6/int5, ternary, 1-bit | local model-quality suite + memory/copy-count artifact |
| Tokenization | CaseOps, byte sidecars, H-Net, BPE variants | byte-roundtrip + citation preservation |
| Adapter | LoRA TTT, random-map adapters, L_SE | adapter ledger + WBO drift + user approval |
| Routing | Active Assembly, routeProfiles, modelPreferenceTable, LocalPolicy | RouteProfile falsifier + WRV HealthRow |
| Retrieval | RRF, PageGather, HNSW/Tantivy variants | `F-VaultRecall-50`, `F-PageGather-M2Pro` |
| Proof / formal | EML Lean, theorem candidates, proof scripts | Lean build + license/toolchain custody |
| UI proof surface | AnswerPacket, provenance console, chip strips | visible WRV screenshot + no false-green |

## 5. EML / Lean custody lane

EML is not "everything is an EML tree." The stricter reading is:

- EML is the elementary-function proof and symbolic-regression chart.
- UAS is the address layer.
- WBO is the error-accounting layer.
- ACS is the admission layer.
- ShadowProjection is the candidate lift/project layer tying charts together.

Before any EML external repo enters Epistemos:

1. identify upstream: `tomdif/eml-lean` is the current lead candidate
2. record license and dependency posture
3. run Lean/lake locally with explicit toolchain path
4. count `sorry`
5. map each imported theorem to a local theorem or falsifier
6. vendor/submodule only through a setup PR

Forks to sample first:

| Repo | URL | Why sample |
|---|---|---|
| `tomdif/eml-lean` | https://github.com/tomdif/eml-lean | upstream candidate for T5 custody |
| `molodiuc/eml-lean` | https://github.com/molodiuc/eml-lean | fork with at least one star; compare deltas |
| `Phelixh/eml-lean` | https://github.com/Phelixh/eml-lean | fork; inspect for portability changes |
| `pannous/eml-lean` | https://github.com/pannous/eml-lean | fork; inspect for experimental changes |

## 6. Erdos / unit-distance code lane

The authoritative sources are the OpenAI proof, companion remarks, and Sawin arXiv paper. Quick GitHub search found only low-authority demonstrations or early formalization attempts:

| Repo | URL | Intake posture |
|---|---|---|
| `eitanporat/unit-distance` | https://github.com/eitanporat/unit-distance | illustrated walkthrough; use only for intuition |
| `quanglehuy2911/Erdos-Unit-Distance-Simulation` | https://github.com/quanglehuy2911/Erdos-Unit-Distance-Simulation | simulation/demo; do not treat as proof |
| `fbundle/erdos90` | https://github.com/fbundle/erdos90 | WIP Lean formalization attempt; possible formal-lane watch item |

Terminal R should revisit this lane when `RESUME ERDOS BREAKTHROUGH` is invoked. Until then, local doctrine should cite OpenAI/arXiv, not demo repos.

## 7. Terminal R — Online Research Intake + Fork Mining

Use this terminal only when the user wants more public research intake while A-G/H are building.

```text
# Epistemos — Terminal R: Online Research Intake + Fork Mining

## Mission
Continuously scan public research sources, repos, forks, PRs, arXiv, and forum-linked code for ideas that can strengthen Epistemos without bypassing local canon. This is a docs/scoping terminal. Do not implement product code.

## Mandatory reads
- docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
- docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md
- docs/fusion/ONLINE_RESEARCH_INTAKE_SHADOW_PROJECTION_2026_05_24.md
- docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md

## Scope
Write only docs/research-intake/*, docs/fusion/* intake updates, and docs/audits/* research-scoping reports.
No Epistemos/** changes.
No agent_core/** changes.
No raw merge from any public fork.

## Loop
1. Pick one source family: Parameter Golf, EML/Lean, Erdos/unit-distance, local-model compression, retrieval/page-gather, or proof assistants.
2. Gather official source + arXiv/paper + repo + fork/PR/discussion signals.
3. Classify every signal by source credibility rank.
4. Map each useful motif to a local W-PERF/T/W/F row.
5. Assign tier: Production-equivalent, Flagged performance, Research construction, or Vault.
6. Define falsifier, artifact schema, rollback, and owner terminal.
7. Write a short intake report and a ready-to-paste implementation prompt if the item is mature.

## Acceptance
- Every candidate has: URL, local anchor, motif, target primitive, tier, falsifier, rollback, owner terminal.
- Every public-code idea says "mine motif, not raw code" unless user explicitly approves a vendor/setup PR.
- Every forum/blog signal links back to a primary paper or repo, or it is marked low-authority.
- No candidate promotes to canon without a local falsifier.
```

## 8. Resume patch for stopped terminals

Paste this into any stopped A-H terminal before asking it to continue:

```text
Resume patch — 2026-05-24

1. Pull latest main.
2. Read:
   - docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md
   - docs/fusion/ONLINE_RESEARCH_INTAKE_SHADOW_PROJECTION_2026_05_24.md
   - docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md
3. Classify your current work under the Substrate Motion Invariant:
   Lift/Ingest, Project/Compress/Recall, or Mutate/Promote.
4. Add/update the PR No-Orphan check:
   Motion, UAS address, plane, residency, WBO/error policy, witness, falsifier, tier, rollback.
5. Continue the loop:
   Audit -> Build -> Verify -> Harden -> Report.
6. If your work depends on public research, cite the source credibility rank from the Online Research Intake doc.
7. Do not promote ShadowProjection, L8/E8/E9, T28, W-Lift-N, Research Construction Engine, or W-PERF rows into product behavior unless the falsifier and WRV caller chain are already real.
```

## 9. No-compromise compression of the architecture

The simplified language is not "retrieval and compression only." It is:

```text
one substrate object
  + three motions
  + five authority fields
  + one promotion loop
```

The three motions cover the user's intuition:

- "going in" = Lift / Ingest
- "being retrieved or compressed" = Project / Compress / Recall
- "state being manipulated and updated" = Mutate / Promote

The five authority fields stop it from becoming vague:

- UAS address
- RuntimePlane
- ResidencyTier
- WBO / error policy
- Witness / falsifier / rollback

This keeps the architecture legible while preserving its original scope: pixels, notes, vectors, graph nodes, KV pages, model components, proofs, EML terms, AnswerPackets, and research candidates are one ontology only when they are addressable, placed, budgeted, witnessed, and falsifiable.
