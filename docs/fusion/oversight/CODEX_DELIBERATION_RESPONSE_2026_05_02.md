# Codex Deliberation Response — 2026-05-02

## Verdict

The five-doc fusion packet is valid to continue from. It is the strongest current architectural basis for the unified substrate: direct, tier-aware, performance-constrained, and compatible with the current branch's actual closed work.

No P0 forbidden-action violation surfaced during this pass. I did find several drift points caused by the packet being written before the latest build slices closed; after user permission, I corrected the concrete stale references instead of leaving them as unresolved drift.

Current best continuation is still implementation, not more doctrine expansion: build the remaining provenance/projection slices and only open killer-feature implementation when its deliberation gate is satisfied.

## Doctrine alignment

The doctrine aligns with the branch's core direction:

- The substrate spine is still the right center of gravity: TypedArtifact -> MutationEnvelope -> OpLog/EventStore -> AgentEvent/GraphEvent -> read-only diagnostics/projections.
- The architectural invariants remain compatible with current code: zero-copy as a hot-path goal, single-binary in-process Core, Rust ownership as the Markov blanket, and tiered determinism by Core/Pro/Research.
- The Hermes Cloud Gateway idea fits the doctrine cleanly as Pro-tier orchestration and cloud abstraction, not as a replacement for Core local determinism.
- The current PR8/PR9 CloudLLM AgentEvent work did not violate the single-binary/Core rule because it only records sanitized provenance around existing URLSession cloud paths and tags the route as Hermes Gateway class; it did not add subprocess inference or new cloud execution policy.
- Sovereign Gate status was stale in the doctrine. It is now corrected: Core seed work exists through `Epistemos/Sovereign/SovereignGate.swift`, `AppBootstrap`, and `ApprovalModalView`, while Rust action-class emission, broader popup migration, transport outcome wiring, and Secure Enclave Pro/Research work remain open.

## Annex coverage check

The Annex coverage is broad enough to guide builders without losing the research nuance:

- SCOPE-Rex naming, T0-T4 verification, L0-L7 residency, ACS five-layer recursion, QOFT/QDoRA/QPiSSA, Sovereign auth routes, KV/ANE research, Hermes ChatML, Knowledge Sieve, and VRM are all represented.
- The "honest scheduling stack" is especially important and should stay: work-stealing and priority queues are the runtime truth; biological metaphors are design inspiration, not scheduler implementation.
- The 5-tier verification ladder correctly keeps Z3 off the hot path.
- The Residency hierarchy is useful but needs one future builder card that turns L0-L7 into a code-facing enum/decision table before Rail implementation starts.
- The continual-learning section correctly keeps OSFT/PSOFT/coSO out of QLoRA production claims and treats QOFT/QDoRA/QPiSSA as the realistic production lane.

## Salvage map confirmation

The salvage map is directionally correct and should stay in the packet. I checked the highest-risk donors and confirmed the core anchors exist:

- `vigorous-goldberg-3a2d35` still contains the Tool trait / `execute_v2` pattern, `ExecutionReceipt`, heal eval, skill discovery, and the actual Quick Capture routing implementation.
- `codex/runtime-input-audit` still contains `CODE_EDITOR_FEATURE_AUDIT.md`.
- Commit `6820f163` still exists and is reachable from the expected branches.
- `simulation` still contains the Simulation Theater doctrine.
- `agent-a0550f9c` still contains `epistemos-shadow/src/honest_handle.rs` and the Rust shadow FFI client.
- The one broken donor pointer was corrected: Quick Capture routing is not at `agent_core/src/capture/routing/`; it is at `agent_core/src/route/`, with grammar/compiler support in `agent_core/src/grammar/mod.rs` and `agent_core/schemas/route_capture.*.json`.

## Things the new canon does NOT yet mention but should

- Add path: salvage map. The new packet itself was partly untracked/dirty during this pass (`CODEX_DELIBERATION_PROMPT_2026_05_02.md`, `WORKTREE_INSIGHT_SALVAGE_2026_05_02.md`, and oversight rounds). To avoid losing canon, stage and commit the five-doc packet plus this response intentionally, separate from unrelated dirty work.
- Add path: Codex prompt. Existing Swift subprocess/training surfaces still need sharper tier classification: `PythonEnvironmentManager`, `QLoRATrainer`, `MoLoRAInferenceService`, audio transcription helpers, and data-ingestion scripts should be explicitly Core-disabled or Pro/Research-only unless proven App Store-safe.
- Add path: doctrine. PLAN_V2 permits transitional typed-buffer sync/copy in graph migration while the doctrine forbids hot-path tensor copies. The doctrine should clarify that the no-copy invariant is absolute for live inference/render hot paths, while measured transitional graph migration copies are allowed only behind explicit profiling/debt labels.
- Add path: Codex prompt. The "unsafe requires SAFETY" rule is good, but existing Rust FFI code has many historical unsafe blocks. Future Rust slices should enforce the rule for touched/new unsafe blocks first, then schedule a separate audit card for historical unsafe documentation rather than blocking unrelated work.
- Add path: salvage map. `Capability::BiometricSession { ttl_secs }` in the donor receipt should become a concrete Sovereign Gate bridge card before the Rust action-class matrix is invented independently.
- Add path: doctrine. Hermes should be named as the preferred Cloud Gateway and Pro-tier orchestration firewall: Core stays local/deterministic; Hermes handles cloud provider churn, MCP/tool dirtiness, and structured handoff back into Epistemos.

## Re-read suggestions

Before the next large feature slice, re-read these in order:

- `docs/fusion/ALL_DOCS_INDEX_2026_05_02.md` for packet and absolute path orientation.
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` for the live closed/open state, especially PR8/PR9 and the next best build cards.
- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` sections 2, 4, 6, 7, Annex A.2, Annex A.3, Annex A.4, and Annex A.12.
- `docs/fusion/WORKTREE_INSIGHT_SALVAGE_2026_05_02.md` sections 1 and 5 before touching Resonance Gate delta, Sovereign Gate capability shape, tool routing, heal loops, or skill discovery.
- `docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md` sections 3.6, 3.7, 3.8, and the severity model before touching tier boundaries or biometric/auth surfaces.

## Forbidden-action drift

No current-slice forbidden drift found.

Specific checks:

- LocalAuthentication is centralized in `Epistemos/Sovereign/SovereignGate.swift`; `ApprovalModalView` routes through that gate rather than creating a second LAContext path.
- PR8/PR9 CloudLLM provenance did not record prompts, system prompts, API keys, URLs, generated text, or streamed content; it records provider/model/mode/route and length/count metadata only.
- No killer-feature implementation was started without a deliberation gate.
- No protected editor/graph renderer files were touched in the latest provenance slices.
- Existing subprocess surfaces are present, but they are pre-existing Pro/Research/training/orchestration concerns, not new drift from the current slice.

## Continuation

Continue building from the current state doc. The safest next build lanes are:

- Remaining broader runtime AgentEvent coverage beyond PR1-PR9.
- Remaining live GraphEvent consumer projection beyond durable mapping/visibility/audit projection.
- A narrow Sovereign Gate follow-through card that imports the donor `BiometricSession` capability shape before inventing a separate Rust action matrix.
- A Hermes Cloud Gateway doctrine/code bridge card that makes cloud routing feel unified while keeping Core deterministic and clean.

Do not start Resonance Gate, Pulse/Rail, private ANE, KV implantation, activation steering, or Research-tier neural-control surfaces until their deliberation gates are explicitly approved.
