---
state: codex-handoff-prompt
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
handoff_for: Codex verifier / reintegration agent
scope: full June 1 research thread, docs, lattice HTML, prompts, build preservation
status: paste-ready
---

# Codex June 1 Full-Thread Canon Reintegration Prompt

This is the one prompt to paste into Codex when the user invokes
`JUNE1-CANON-FUSION-LOCK`.

`JUNE1-PATTERNBOOST-LOCK` is still valid, but it is the narrower residency
subset. The full-thread umbrella is `JUNE1-CANON-FUSION-LOCK`.

## Latest Local Observation

During the full-thread closeout, the earlier PatternBoost closeout build PID
`44554` was no longer present. A separate active build/test process was observed
and intentionally left alone:

```text
PID 73826
elapsed 10:51 at final process check
command xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS,arch=arm64 -skipMacroValidation -skipPackagePluginValidation -derivedDataPath /tmp/epistemos_hotpath_hardening_test_dd COMPILER_INDEX_STORE_ENABLE=NO ONLY_ACTIVE_ARCH=YES ARCHS=arm64 CARGO_TARGET_DIR=/tmp/epistemos_hotpath_hardening_test_cargo_target -only-testing:EpistemosTests/HTMLWorkspacePackageTests -only-testing:EpistemosTests/HTMLWorkspaceSourceGuardTests -only-testing:EpistemosTests/NoteEditorLayoutTests -only-testing:EpistemosTests/ProductionHardeningTests -only-testing:EpistemosTests/CodeFileServiceContainmentTests
```

The next Codex should re-check the live process table before rerunning anything.

## Paste Prompt

```text
You are Codex in /Users/jojo/Downloads/Epistemos. Your job is to verify,
preserve, and reintegrate the entire June 1 research/canon thread, not only
Residency PatternBoost.

Codewords:
- JUNE1-CANON-FUSION-LOCK = full thread: formal math companies, meta
  breakthroughs, constructive residency, cache lineage, portable note systems,
  engineering logic, semantic working sets, substrate trace observatory,
  verifier-calibrated sparse routing, ColdStream transport, mmap/hot-path cure,
  Residency PatternBoost, drift sweep, lattice HTML, and build verification.
- JUNE1-PATTERNBOOST-LOCK = residency subset: offline/idle PatternBoost
  discovery and the 345 bridge notes that prevent legacy UAS/ACS/mmap/70B
  claims from steering future agents alone.

Important folder structure:
- The canonical originals remain in their normal repo locations:
  AGENTS.md, docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md,
  docs/fusion/, docs/falsifiers/, docs/audits/, and
  artifacts/lattice-coordinate-explainer/index.html.
- There is also a duplicate navigation bundle at docs/june 1/. It contains
  copied June 1 fusion docs, falsifier bundles, audit/handoff docs, inline
  authority surfaces, the lattice HTML snapshot, a manifest, a bridge-preface
  ledger, and a final nuance check.
- Read both views. The canonical originals show the live source-of-truth
  placement; docs/june 1/ is the easy-to-navigate recovery bundle that helps
  preserve nuance after context compaction. If they differ, treat the canonical
  originals as authoritative and update the duplicate bundle to match.
- Before directing another agent or editing anything, deliberately synthesize
  the full stack in your own words: what changed, which docs are authority,
  which claims remain speculative, which falsifiers promote them, and which
  caveats prevent overclaiming. Do not proceed if the thread has collapsed into
  only PatternBoost or only mmap.

First preserve the running build:
1. Do not kill, reset, or restart any existing build.
2. Inspect any active xcodebuild/cargo/swift/clang/metal processes:
   ps -axo pid,etime,stat,command | rg 'xcodebuild|swift-build|swiftc|clang|metal|cargo'
3. Capture the exact command, elapsed time, status, and final result if
   accessible. Only rerun build after the original build has finished or is
   proven inaccessible.

Read these first, in order:
1. AGENTS.md
2. docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md
3. docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
4. docs/audits/CODEX_JUNE1_FULL_THREAD_CANON_REINTEGRATION_PROMPT_2026_06_01.md
5. docs/june 1/README.md
6. docs/june 1/MANIFEST_2026_06_01.md
7. docs/june 1/INLINE_CANON_SURFACES_2026_06_01.md
8. docs/june 1/FINAL_NUANCE_CHECK_2026_06_01.md
9. docs/audits/JUNE1_PATTERNBOOST_LOCK_CLOSEOUT_2026_06_01.md
10. docs/audits/RESIDENCY_PATTERNBOOST_DRIFT_SWEEP_2026_06_01.md

Then verify the June 1 primary doctrine stack:

Fusion doctrines:
- docs/fusion/FORMAL_MATH_COMPANY_AND_LEAN_INTAKE_2026_06_01.md
- docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md
- docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md
- docs/fusion/CACHE_LINEAGE_AUTORESEARCH_PARADIGM_2026_06_01.md
- docs/fusion/MATH_AND_PORTABLE_NOTE_SYSTEMS_INTAKE_2026_06_01.md
- docs/fusion/ENGINEERING_LOGIC_ARCHITECTURE_INTAKE_2026_06_01.md
- docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md
- docs/fusion/SUBSTRATE_TRACE_OBSERVATORY_2026_06_01.md
- docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md
- docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md
- docs/fusion/MMAP_REPLACEMENT_AND_HOTPATH_CURE_ATLAS_2026_06_01.md
- docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md

Falsifier bundles:
- docs/falsifiers/F-CACHE-LINEAGE-AUTORESEARCH-BUNDLE_2026_06_01.md
- docs/falsifiers/F-COLDSTREAM-RESIDENCY-TRANSPORT-BUNDLE_2026_06_01.md
- docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md
- docs/falsifiers/F-ENGINEERING-LOGIC-ARCHITECTURE-BUNDLE_2026_06_01.md
- docs/falsifiers/F-MATH-NOTE-SYSTEMS-PORTABILITY-BUNDLE_2026_06_01.md
- docs/falsifiers/F-MMAP-REPLACEMENT-HOTPATH-CURE-BUNDLE_2026_06_01.md
- docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md
- docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md
- docs/falsifiers/F-SUBSTRATE-TRACE-OBSERVATORY-BUNDLE_2026_06_01.md
- docs/falsifiers/F-VERIFIER-CALIBRATED-SPARSE-ROUTE-BUNDLE_2026_06_01.md

Thread handoffs / receipts:
- docs/audits/RESIDENCY_PATTERNBOOST_DRIFT_SWEEP_2026_06_01.md
- docs/audits/CODEX_PATTERNBOOST_DOC_SWEEP_VERIFICATION_HANDOFF_2026_06_01.md
- docs/audits/JUNE1_PATTERNBOOST_LOCK_CLOSEOUT_2026_06_01.md
- docs/audits/CODEX_JUNE1_FULL_THREAD_CANON_REINTEGRATION_PROMPT_2026_06_01.md

Also inspect the visible lattice artifact on disk:
- artifacts/lattice-coordinate-explainer/index.html
- docs/june 1/artifacts/lattice-coordinate-explainer/index.html

Also inspect the duplicate June 1 bundle:
- docs/june 1/README.md
- docs/june 1/MANIFEST_2026_06_01.md
- docs/june 1/INLINE_CANON_SURFACES_2026_06_01.md
- docs/june 1/BRIDGE_PREFACE_LEDGER_2026_06_01.md
- docs/june 1/FINAL_NUANCE_CHECK_2026_06_01.md
- docs/june 1/fusion/
- docs/june 1/falsifiers/
- docs/june 1/audits/
- docs/june 1/authority-surfaces/

Do not treat this thread as "just PatternBoost." The canonicized stack is:

L11 Constructive Residency:
- Local capability scales with a selected, proof-carrying resident assembly,
  not with the largest parameter count simultaneously hot.
- UAS/AppColdStore/70B cocktail claims become plausible only through
  coactivation tiles, cold assembly plans, proof-carrying residency leases,
  Lattice Deduction Transformer-style controllers, and explicit local evidence.

L12 Cache Lineage:
- Persistent cache, KV, prefix, trace, and continuity state promotes only when
  saved computation and reasoning continuity exceed staleness, compatibility,
  privacy, storage-wear, rollback, and verification cost.
- Important primitives: KVPrefixUnit, KVLineageGraph, KVCompatibilityFence,
  CacheAdmissionCard, PrefixReuseRouter, ExecutionTraceCapsule.

L13 Delta Projection:
- Note/editor/graph state must move through typed deltas and projection
  digests, not opaque rewrites.
- Important primitives: EditorDeltaMonoid, ReadableProjectionFunctor,
  IncrementalParseForest, DeltaSemilatticeSync, DifferentialKnowledgeView,
  RetentionPotentialField, SemanticEntropyGate, ConstrainedMutationDecode.
- Tolaria is AGPL source-mine-only; Tauri apps are references, not replacements
  for the native macOS Opulent shell.

L14 Engineering Logic:
- A mechanism enters architecture only when invariant, owner, state transition,
  budget, failure mode, witness, and rollback are explicit.
- Preserve ambition, but make every path falsifiable.

L15 Semantic Working-Set:
- UAS/AppColdStore/70B is not SSD-as-RAM. Each mission compiles into a
  predicted, budgeted, prefetchable, observable working set: evidence, KV
  pages, adapters, model byte ranges, kernels, tools, proof routes, and
  rollback-visible traces.
- Important primitives: SourceSignalGraph, SemanticWorkingSetPlan,
  ResidencyPageTable, PrefetchWindow, ColdFaultTrace, MmapResidencyFence,
  KVByteBudgetCard, SourceToResidencyPatch.

L16 Substrate Trace Observatory:
- Routing, retrieval, KV/cache pressure, source steps, tool actions, and agent
  traces must be inspectable, redacted, replayable, comparable, and connected
  to AnswerPacket/witness evidence.
- No hidden chain-of-thought authority. Trace visualizations diagnose and
  calibrate; they do not become proof by themselves.

L17 Verifier-Calibrated Sparse Wake:
- "Choose the right weights/KV/neurons/params" is a software route policy:
  TwoStageRouteScout, BudgetedUncertaintyEscalator, SparseWakeProposal,
  VerifierBudgetAuction, KVPageSketchIndex, QueryAwareKVSelector,
  LayerKVJointLease, RouteDistillationTournament, ProofPressureSignal,
  VerifierRegretFastWeights, FastWeightQuarantine, DepthLease,
  ShadowWakeOracle, SparseWakeCertificate.
- Tiny route scouts/SSMs may propose; verifier evidence and rollback decide.

L18 ColdStream Residency Transport:
- Replace mmap-as-control-plane with explicit, measured, cancelable transport:
  TransportRunManifest, PageRunScheduler, SlabArena, MetalBufferLease,
  CodecStage, TransportTrace, ColdPanicFallback.
- mmap remains useful for addressability, metadata, and baselines; token-hot
  cold routes need byte ranges, leases, cache policy, copy-count proof,
  p95/p99 stall proof, cancellation, rollback, and AnswerPacket caveats.

L19 Copy-Causal Geometry:
- Zero-copy applies to backend/compute/transport/proof hot paths, not all
  product state.
- Preserve intentional copies for multiple graph versions, multiple note
  editor surfaces, undo-safe text, previews, snapshots, visual variants, and
  user artifacts.
- Cure hot paths through HotPathCensus, MmapKeepVsReplace, MmapHazardFence,
  ReadPlanMatrix, GeometryAlignedPageTable, CopyBudgetVector,
  UnsafeBoundaryProofCard, ShmMaterializationWaiver, StreamFrameArena,
  SpatialDirtyWindow, ProtocolEdgeJsonWaiver, GeometricPageRunPlanner,
  GraphNodeStateRingPromotion, HotTraceBinarySummary, EventRingActivationCard,
  CopyCausalGraph, LayoutObjective, ProofHarnessCard.

L20 Pattern-Boosted Residency:
- Residency PatternBoost is offline/idle Pro Research discovery, not hidden
  live route authority.
- It searches UASAssemblyGenomes, repairs invalid candidates, creates sparse
  fingerprints, archives held-out winners, distills route/layout motifs, and
  proposes ColdRoutePolicyPatches.
- Promotion requires repair, sparse fingerprint, held-out replay,
  LatticeAbstentionGate, ComputeResumeLease, rollback, source/license scope,
  ablation, no offline oracle leakage, and AnswerPacket witness evidence.

Formal math / company source distinctions:
- Axiom/Axplorer/PatternBoost, Axiomatic AI/AxProverBase, OProver, UlamAI,
  Harmonic, Math Inc/OpenGauss, Lean, Mathlib, LeanSearch, Pantograph, and
  SageMath motifs are source classes, not a single authority.
- Preserve source cards, license notes, credibility notes, product status, and
  no-overclaim language.

Primary source motifs validated during this thread included:
- Tolaria, Noteriv, ProseMirror, Tiptap, Milkdown, CodeMirror, Lexical,
  Tree-sitter, Automerge, Differential Dataflow, FSRS, PICARD, HNSW, Git vault
  lineage, oMLX, DeepSeek context caching, Karpathy autoresearch, GEPA.
- Denning working sets, vLLM/PagedAttention, LMCache, FlexGen, PowerInfer,
  KTransformers, KIVI, Apple LLM in a Flash, SwiftLM, Letta, MInference,
  Quest, SparQ, RouteLLM, LayerSkip, Mixture-of-Depths, Titans/TTT, Mamba-2.
- Apple mmap/file performance/fcntl/Dispatch I/O/Metal resource loading,
  Rust memmap2/zerocopy/bytemuck/bytes, Lean, Verus, Kani, Aeneas, and
  OpenAI Sparse Transformer.

High-authority surfaces that must remain wired:
- AGENTS.md
- docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md
- docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
- docs/CANONICAL_DOC_INDEX_2026_05_16.md
- docs/_INDEX.md
- docs/MASTER_SESSION_PROMPT_v2.md
- docs/audits/FULL_ARCHITECTURE_CONTINUATION_PROMPT_2026_05_31.md
- docs/LEGENDARY_CODEWORD_2026_05_23.md
- artifacts/lattice-coordinate-explainer/index.html

Verification commands:

1. Broad thread tag coverage:
   rg -l 'JUNE1-CANON-FUSION-LOCK' AGENTS.md docs artifacts/lattice-coordinate-explainer/index.html | wc -l

2. June markdown frontmatter coverage:
   for f in $(rg --files -g '*2026_06_01.md' docs/fusion docs/falsifiers docs/audits); do if ! rg -q '^thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK$' "$f"; then printf '%s\n' "$f"; fi; done

3. PatternBoost bridge coverage:
   rg -l '^> \*\*2026-06-01 current canon bridge \(JUNE1-PATTERNBOOST-LOCK\):' docs artifacts/lattice-coordinate-explainer/index.html | wc -l

4. Live drift check:
   rg --files -g '*.md' -g '*.html' AGENTS.md docs artifacts/lattice-coordinate-explainer/index.html |
     rg -v '(^docs/_archive/|^docs/_consolidated/50_research_corpus/|^docs/fusion/jordan.s research/|^docs/fusion/research/|^docs/fusion/salvage/|^docs/audits/codebase-verbatim-packets-2026-05-09/|^docs/google-research-pack-2026-03-18/)' |
     while IFS= read -r f; do
       if rg -qi '70B|AppColdStore|mmap|KV-Direct|NeuralImportance|ActiveAssembly|local cocktail|addressable neural substrate|Helios|ACS|UAS|unified active substrate|active cold storage|active model-state' "$f" &&
          ! rg -qi 'ResidencyPatternBoost|PatternBoost|RESIDENCY_PATTERNBOOST|2026-06-01|JUNE1-PATTERNBOOST-LOCK|JUNE1-CANON-FUSION-LOCK' "$f"; then
         printf '%s\n' "$f"
       fi
     done

5. Diff hygiene:
   git diff --check -- AGENTS.md docs artifacts/lattice-coordinate-explainer/index.html
   rg -n '^(<<<<<<<( |$)|=======$|>>>>>>>( |$))' AGENTS.md docs artifacts/lattice-coordinate-explainer/index.html

6. Lattice artifact disk check:
   rg -n 'JUNE1-CANON-FUSION-LOCK|JUNE1-PATTERNBOOST-LOCK|epistemos-canon-codeword|Semantic Working|Copy-Causal|ResidencyPatternBoost' artifacts/lattice-coordinate-explainer/index.html

Rules:
- Do not rewrite provenance corpora wholesale. Historical/imported rows are
  allowed to remain historical if live indexes route through the June lock.
- Do not collapse all sources into "Axiom." Keep Axiom/Axplorer, Axiomatic,
  OProver, UlamAI, Harmonic, Math Inc, Lean, and note-system repos distinct.
- Do not claim the app can hot-load a 70B model from SSD. The canonical claim is
  addressable cold material plus working-set compilation, transport, sparse
  routing, verification, leases, and witnesses.
- Do not treat zero-copy as a UI-copy ban. Only backend/compute/transport/proof
  hot paths are targeted.
- Do not promote PatternBoost or fast weights to hidden live authority.
- Do not kill the running build.

Report back:
- Whether the existing build completed, failed, or is still running.
- Exact counts for JUNE1-CANON-FUSION-LOCK, JUNE1-PATTERNBOOST-LOCK bridges,
  June frontmatter misses, and live drift misses.
- Any doc drift found, with exact files.
- Any build/runtime issue, classified as source/build, docs/resource packaging,
  or unrelated pre-existing worktree state.
```

## Human Summary

This prompt is intentionally broader than the earlier PatternBoost handoff. It
preserves the entire thread: note/editor math, formal proof companies, cache
lineage, engineering logic, semantic working sets, trace observability, sparse
route selection, ColdStream transport, mmap/hot-path geometry, PatternBoost
residency, the lattice HTML update, the drift sweep, and the running-build
preservation rule.
