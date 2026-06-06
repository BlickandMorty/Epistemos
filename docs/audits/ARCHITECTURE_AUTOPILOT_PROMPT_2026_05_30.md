Continue the Epistemos architecture salvage and runtime-hardening loop from
`/Users/jojo/Downloads/Epistemos`.

You are running unattended from `Tools/audits/epistemos_architecture_heartbeat_loop.sh`.
Do not wait for user input unless the work is blocked by a genuinely unsafe
choice. Do one small, high-confidence unit of work, verify it, commit it, and
leave a concise report in your final answer.

Start by reading and obeying:

1. `AGENTS.md`
2. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
3. `docs/audits/UNFINISHED_ARCHITECTURE_AND_BEST_COMBO_MANIFEST_2026_05_30.md`
4. `docs/audits/ARCHITECTURE_NO_GAP_BUILD_ORDER_2026_05_28.md`
5. `docs/audits/AGENT_MANAGEABLE_ARCHITECTURE_CANON_2026_05_30.md`
6. `docs/audits/ACS_NAMESPACE_RECONCILIATION_2026_05_30.md`
7. `docs/audits/NEXT_SESSION_WORKTREE_SALVAGE_PROMPT_2026_05_30.md`
8. `docs/audits/NAMESPACE_AND_ARCHITECTURE_CLARITY_AUDIT_2026_05_31.md`
9. `docs/fusion/FRONTIER_LOCAL_REASONING_16GB_ARCHITECTURE_2026_05_31.md`
10. `docs/fusion/NEURAL_IMPORTANCE_ROUTING_ATLAS_2026_05_31.md`
11. `docs/fusion/LOCAL_FRONTIER_PLAYBOOK_16GB_2026_05_31.md`
12. `docs/fusion/EIDOS_NEURAL_IMPORTANCE_BRIDGE_2026_05_31.md`
13. `docs/audits/FULL_ARCHITECTURE_CONTINUATION_PROMPT_2026_05_31.md`
14. `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`
15. `docs/audits/WORKTREE_PRESERVATION_EXTRACTION_PROMPT_2026_05_31.md`
16. `docs/audits/SOVEREIGN_ARCHITECTURE_HARDENING_PROMPT_2026_06_06.md`
17. `docs/fusion/TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE_2026_06_06.md`
18. `docs/fusion/MLX_QAT_TURBOVEC_LOCAL_SUBSTRATE_RESEARCH_2026_06_06.md`

Current naming/build lock:

- Epistemos has two distributable builds: MAS and Pro. Research, Vault, Omega,
  heavy runtime, and future substrate work are Pro status bands, not app
  builds.
- Use ProductBuild plus ProStatus/ResidencyStatus in new architecture claims.
- Use ColdStore for Active Cold Storage. Keep AcsAnchor for anchored
  coordinate/provenance. Use SCOPE-Rex/SovereignGate for admission/verdicts.
- The 16 GB local-reasoning target is: cold trillion, hot five billion,
  active minimum. This is a candidate architecture direction, not a shipped
  local-frontier claim.
- The 2026-06-06 compression/runtime-plural lock is now part of the current
  canon. MLX is first-lane on Apple Silicon, not the whole architecture.
  GGUF/llama.cpp, LiteRT-LM, Transformers, custom Metal, and optional
  user-selected local endpoints are candidate execution organs only under
  System G / RuntimeRouter / SovereignGate / AnswerPacket. Gemma 4 12B QAT
  GGUF/LiteRT is Pro Gated research target; MLX Gemma 4 repos are not Swift
  loader proof. TurboVec is Eidos/AppColdStore compressed retrieval, not
  durable truth or hidden route authority. Public repo logic must pass
  `F-ProprietaryCompression-ProvenanceGate`: quarantine, inspect, benchmark,
  extract behavior/tests/failure cases, then direct import, adapter-wrap, or
  clean-room rewrite safely.
- Ambition lock: do not assume the local frontier direction is impossible just
  because ordinary dense-resident models do not fit. Preserve the hypothesis
  that UAS-addressed SSD/AppColdStore bytes can become a much larger
  addressable cognitive atlas than hot RAM, including per-layer, per-block,
  adapter, KV, and future parameter-component selection. Rigor lock: UAS makes
  those bytes addressable and routable, not RAM-latency; every promotion must
  be earned by layout, prewarm, cache reuse, active-byte accounting, repair
  loops, and falsifiers.
- AppColdStore is the app-owned substrate storage direction: durable model
  atlas, packed weight pages, adapter banks, KV seeds, route cards, and cache
  manifests belong under Epistemos-managed Application Support / App Group
  storage, with purgeable Caches only for regenerable warm packs. SwiftData
  stores manifests/provenance, not giant blobs.
- NeuralImportanceAtlas is the candidate route-selection layer: choose the
  smallest verified support set across evidence, KV pages, adapters, weight
  blocks, kernels, ANE scout heads, and verifiers. Use the
  Counterfactual Utility Law as a planning heuristic, but require falsifiers
  before promotion.
- Residency PatternBoost is the candidate offline/idle discovery layer:
  search UAS assembly genomes, repair invalid candidates, sparsely fingerprint
  them, archive held-out winners, and distill route/layout motifs before live
  execution. It may seed a live scout only after held-out wins,
  `ComputeResumeLease`, byte/transport proof, rollback, RunEventLog, and
  AnswerPacket visibility.
- Eidos can feed NeuralImportanceAtlas, but it must not become a hidden model
  self-router. Eidos supplies evidence hits, task meaning, `why_matched`,
  citation need, contradiction hints, and route priors; UAS/AppColdStore binds
  candidate neural units; ActiveAssembly selects the support set; SCOPE-Rex /
  SovereignGate admits the route; RunEventLog and AnswerPacket expose it.
- Dynamic compute ideas are allowed only as explicit checkpoints:
  early-exit, self-speculative, depth-budget, KV-restore, adapter-swap,
  Eidos-interrupt, verifier-repair, or controller-SSM checkpoints. Do not
  silently interrupt a matmul or mutate model state. Every checkpoint that
  affects an output must become a RunEventLog event.
- The 16 GB playbook promotion rule is A/B/C/D: a full Epistemos route must
  beat raw local, conventional RAG, and memory-optimized baselines on quality,
  evidence validity, active bytes, and visible proof before any local-frontier
  claim is allowed.

Concurrency / isolation / unsafe lock:

- Performance is architecture, but concurrency speedups must preserve Swift 6
  actor isolation and Rust/FFI safety. Do not "optimize" by bypassing
  isolation, sprinkling `nonisolated(unsafe)`, sharing non-Sendable model
  state, or moving UI/SwiftData objects across actors.
- Swift UI state remains `@MainActor @Observable`. Heavy work must leave the
  main actor through typed snapshots, Sendable value packets, dedicated actors,
  detached utility tasks, Rust/Tokio workers, or MLX/Metal lanes with explicit
  ownership.
- `nonisolated(unsafe)` is a narrow compatibility escape hatch for known
  AppKit/FFI edges already justified by comments and tests; it is not a
  general architecture primitive. New unsafe escapes require a source path,
  race explanation, fallback, and focused test or source guard.
- MLX/GGUF/model state must use a serialized executor, dedicated thread, or
  route-specific actor when the underlying object is not safely Sendable.
  Never pass live model/KV/buffer handles across random tasks just to improve
  throughput.
- Hot paths must declare their isolation boundary: caller actor, worker actor
  or thread, cancellation behavior, debounce/coalescing policy, backpressure,
  copy-count expectation, and RunEventLog/AnswerPacket visibility when the
  route affects user output.
- Kernel-panic-class unsafe testing is not product canon. Anything that could
  panic macOS, wedge GPU/Metal, overpressure UMA, thrash mmap/SSD, corrupt a
  live model/KV store, or destabilize the machine belongs to a Pro
  Research/Omega crash-safety harness only. The unattended loop may add
  non-executing witnesses, source guards, dry-run manifests, and rollback docs
  for those lanes, but must not run hazardous probes.

Claude-ledger scope lock:

- The long Claude Phase 1 / Phase 2 / T25+ ledger is canon baseline, not final
  source truth. Always verify current code and current docs before declaring a
  row open, closed, wired, or obsolete.
- Treat the pasted ledger as a full-scope map, not a suggestion list. The loop
  may pick only one small work unit per run, but the recursive backlog must
  continue to cover the whole architecture. Do not narrow the mission to the
  most recent hunk, donor, or research phrase.
- Every loop must match or exceed the ledger's architectural intent. It must
  never regress by deleting nuance, flattening UAS/OAS/ColdStore/Eidos/System G
  into a generic chatbot path, replacing user-visible proof with status-only
  docs, or accepting a weaker donor version over stricter current code.
- Nothing from the original Phase 1 / Phase 2 / T25+ ambition is dropped.
  Reconcile every row as one of: current code already wired, port one additive
  donor hunk/test, preserve as Pro Research / Pro Vault-Preserved / Pro Omega,
  or explicitly blocked with the missing falsifier/gate.
- A row counts as "wired" only with source path, caller/reachability proof,
  focused test or runtime guard, and user-visible surface/witness when the row
  is product-facing. Otherwise mark it substrate-only, scaffold-only,
  research-only, or blocked.
- If a row is not completed in the current run, preserve the next cursor and
  explain what remains. Do not close a row because nearby code, names, or docs
  exist.
- Phase 1 leftovers remain in scope: T4 vault retrieval unique-value check,
  T6 UI/UX donor mining, T5 Lean custody, T2 routeProfiles,
  ToolCallingPlan additive variant, T23B dedupe, and T12 eml_ir vs
  fulp_oracle consolidation.
- Phase 2 wiring remains in scope: T10 Eidos -> QueryRuntime, T21 VaultRecall
  -> MeaningAnchorService, T17B lattice/WBO oplog accounting, T18B
  SCOPE-Rex/SovereignGate admission, T12 F-ULP witness emission, T11 System G
  -> LocalAgentLoop, T21 capstone unification, T2 RunTimelineView, and W-11
  through W-18 dispatch hooks.
- T25+ / future rows remain in scope as gated work: T14 UAS addressing, T22
  falsifier panel, T22B vault retrieval / Brain Panel closed citations, T27
  visible product behavior, T10B, T13, T15, T16, T19, T20, T24, T25, and T26.
- Auxiliary branches remain preservation/donor references only:
  `release-stabilization/runtime-hardening`, `runtime-input-audit`,
  `runtime-memory-hardening`, `feature/knowledge-fusion-v1`, and run-b/c/d/e/f
  style branches. Audit surgically; never wholesale merge.
- The 70B cocktail remains core canon but unproven. Safe path only:
  WeightBlockManifest -> ResidencyPlan -> non-executing witnesses ->
  crash-safe harness -> measured runtime probe. No heavy runtime probe from
  this loop.

Hard safety rules:

- Do not touch the paused font/typography bundle unless the user explicitly
  resumes font work. In particular, do not edit, stage, commit, or "fix" the
  dirty font files or missing `ka1.ttf`.
- Do not edit, stage, commit, or "fix"
  `artifacts/lattice-coordinate-explainer/index.html` unless the user
  explicitly resumes lattice explainer artifact work.
- Do not run 70B, 128K, full Metal witness, mmap/SSD stress, live MLX/GGUF
  heavy probes, Xcode/full-app tests, or commands likely to pressure memory.
- Do not delete worktrees, sibling Epistemos folders, `~/Epistemos-RETRO/`,
  `src-tauri/`, or `~/meta-analytical-pfc/`.
- Do not wholesale merge donor branches. Use non-mutating checks first and
  port only one additive, focused hunk/file if it is clearly safe.
- Do not treat files, fixtures, docs rows, health rows, or branch-local code as
  product claims. Preserve WRV: Wired, Reachable, Visible, Verified.
- If a donor would remove stricter current truth-floor fields, skip it and
  record why.
- When mining pasted research, donor docs, papers, or generated syntheses,
  extract only the buildable mechanism. Map it to an existing organ
  (Eidos/VaultRecall, System G, RuntimeRouter, ColdStore, Primitive IR,
  SCOPE-Rex/SovereignGate, AnswerPacket, etc.) and do not mint a new top-level
  architecture name from prose.
- EML is an elementary-function/proof chart inside the Primitive IR stack, not
  UAS, ColdStore, Eidos, RuntimeRouter, or a general product/intelligence proof.
- Do not claim SSD equals RAM, comfortable 70B/128K on 16 GB, live 1T local
  model execution, arbitrary ANE kernels, or "better than MoE" unless the named
  falsifier passes. Relevant gates include `F-AppColdStore-Layout`,
  `F-AppleSilicon-RouteSplit`, `F-KV-Direct-Gate`,
  and dense/reference rollback checks.

Preferred unattended work order:

1. If the current repo has new uncommitted changes outside the paused font
   bundle, inspect them before editing and avoid clobbering them.
2. If the user has asked for worktree preservation/extraction, follow
   `docs/audits/WORKTREE_PRESERVATION_EXTRACTION_PROMPT_2026_05_31.md`: audit
   at most one preserved donor for the current cycle, use non-mutating diffs
   first, port at most one useful additive hunk/test/doc row, and never delete
   or wholesale merge any worktree. This is not a new forever lane: donor
   mining is subordinate to the main architecture loop and must return to the
   best-combo/current-head build order after the bounded extraction or skip
   proof.
3. Pick one safe current-head surface from the best-combo manifest:
   - T4 unique-value check;
   - T21/Eidos/VaultRecall/PageGather retrieval unification;
   - RuntimeRouter policy behavior;
   - System G guarded route surfaces that do not launch inference;
   - AcsAnchor/UAS pure Rust read surfaces;
   - ResidencyPlan / WeightBlockManifest dry-run guardrails.
   - AppColdStore / NeuralImportanceAtlas scaffolds only when they are
     non-executing, manifest-only, and falsifier-shaped.
   - Eidos/NeuralImportance bridge work only when it is typed as a route-prior
     or route-card surface and cannot wake model bytes without admission.
   - measurement-floor or playbook harness work that records active bytes,
     copy count, peak UMA, SSD reads, citation validity, and witness completeness.
4. Prefer verified code over docs. If no code is safe, update the salvage docs
   with exact reasons.
5. Run only lightweight verification:
   - `git diff --check`;
   - focused cargo tests for touched Rust modules only;
   - focused Swift source guards only when Xcode is blocked by the paused font
     bundle.
6. Commit the checkpoint before ending. Do not stage paused font files.

End with: what was inspected, what was changed or skipped, what verification
ran, commit hash, and what the next loop should attempt.
