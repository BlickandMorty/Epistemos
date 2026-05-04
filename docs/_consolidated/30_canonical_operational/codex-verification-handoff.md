# Codex Verification Handoff — Phase 4.5 Stabilization

> **Index status**: CANONICAL-OPERATIONAL — Codex verification handoff (2026-04-19+).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



**Context for Codex**: The previous agent was tasked with closing out "Phase 4.5" of the Epistemos local AI stack, ensuring strict architectural rules were followed before Phase 5 could begin. 

Your objective is to independently verify that the codebase accurately reflects the **Option B (Deferred Graph)** completion state, and that the regression fixes and performance improvements were implemented truthfully without weakening tests or faking capabilities.

## 1. Architectural Mandate to Verify
Ensure the following are structurally true in the live codebase `HEAD` (currently `main`):
- **No Sidecar / No Reasoner**: DeepSeek, the sidecar, OpenClaw, and localhost/Node orchestrations must be entirely removed from the live boot and routing path.
- **One Local Text Lane**: Qwen must be the only in-process local model running. 
- **Apple Intelligence Integration**: Used strictly for the lightest native tasks. Graph summaries must prefer Apple Intelligence first, falling back to Qwen.
- **Explicit Deferral of Rust-Native AI**: The FFI/Rust layer (`graph-engine`) was audited and found lacking the ML tensors/dependencies (`candle-core`, `ort`, etc.) necessary to run cross-encoders or BGE natively. You must verify that Swift continues to own the embedding generation and that Rust explicitly handles the semantic routing via SIMD scalar Cosine Similarity in `embedding.rs`, preventing massive architectural drift away from Apple Silicon MLX unified memory. 
- **Graph Semantic Clustering**: Must remain disabled as the embedding space is not yet unified.

## 2. The Regression Fix to Verify
**Background**: Commit `085da92` introduced a regression by shifting `TrigramSearchIndex` rebuilds onto background tasks (`Task.detached`), violating the immediate availability contract assumed by targeted tests.
**Action Taken**: The rebuild logic in `Epistemos/Views/Landing/CommandPaletteOverlay.swift` and `Epistemos/Views/Notes/NotesSidebar.swift` was reverted to be strictly synchronous on the `MainActor` to securely resolve the regression.
**Your Verification Task**: Ensure `RuntimeValidationTests` and `PipelineServiceTests` pass flawlessly without any modification to the test logic themselves.

## 3. Documentation Accuracy to Verify
Check `docs/ai_stack_implementation_plan.md` and `docs/ai_stack_phase_audit_log.md`. 
**Your Verification Task**: Ensure Phase 4.5 is strictly marked completed under **Option B constraints**. Specifically, verify that "Rust-native BGE query execution" and "Real cross-encoder reranker runtime" are explicitly tagged as deferred to Phase 5 or later, and not falsely claimed as implemented.

## 4. Required Execution Validation
To confirm the integrity of the build, you must run the following from the root `/Users/jojo/Epistemos`:

```bash
# 1. Reject Legacy Code (Sidecar / OpenClaw / Deepseek bindings)
./scripts/audit/native_cleanup_scan.sh

# 2. Assert all FTS / Core Swift Logic
./scripts/audit/verify.sh --fix-format

# 3. Assert Graph Engine Integrity
cargo test --manifest-path graph-engine/Cargo.toml
cargo test retrieval_index --manifest-path graph-engine/Cargo.toml

# 4. Assert Triage, Pipeline, and Validation specifically
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/TriageServiceTests -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/SearchIndexServiceIntegrationTests -only-testing:EpistemosTests/PipelineServiceTests
```

## 5. Performance Delta against 0981039
**Your Verification Task**: Compare `HEAD` against checkpoint `0981039`. Prove that the codebase sheds heavy sidecar UI, redundant local transport networking, and redundant background worker processes. Verify that no feature regressions were introduced to mask "faster" behavior. 

```bash
git diff --stat 0981039..HEAD
```

## Sign-Off
Once validated, confirm that Phase 5 is legally unblocked under these newly solidified boundary constraints.
