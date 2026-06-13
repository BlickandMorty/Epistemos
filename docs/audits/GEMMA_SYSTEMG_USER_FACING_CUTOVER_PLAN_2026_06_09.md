# Gemma / System G User-Facing Cutover Plan - 2026-06-09

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Current Truth

The project should stop treating Gemma as a vague future model-picker wish. The current Gemma ladder is already narrowed:

1. official source card
2. owner-approved local artifact receipt
3. direct local-file first-token receipt
4. same-fixture quality replay
5. RuntimeRouter admission
6. System G dry-run
7. route AnswerPacket visibility
8. settings / diagnostics WRV
9. release-audit zero-fail evidence

The built state is still not user-facing Gemma. As of 2026-06-10, E2B, E4B,
and 12B have owner-approved local GGUF receipts, bounded direct `llama-cli`
first-runtime receipts, seven-task quality replay, RuntimeRouter admission
packets, System G dry-run packets, route AnswerPacket visibility packets, and
Settings/diagnostics WRV packets. None of those artifacts promotes Gemma to a
default route, live picker capability, MAS route, T4 claim, or finished System
G runtime.

## 2026-06-09 Model Selection Lock

Use official Google Gemma 4 QAT Q4_0 GGUF as the first proof root:

1. `google/gemma-4-E2B-it-qat-q4_0-gguf` - fastest first-token proof and harness smoke.
2. `google/gemma-4-E4B-it-qat-q4_0-gguf` - balanced local lane once E2B proves the receipt/runtime path.
3. `google/gemma-4-12B-it-qat-q4_0-gguf` - Pro flagship candidate after E2B/E4B prove receipt, cancellation, memory, quality replay, RuntimeRouter packet, System G dry-run packet, settings WRV, and release audit.

Exact official proof-root files from the Hugging Face model API:

| Lane | Repo revision | Required GGUF | Bytes | LFS SHA256 |
|---|---|---:|---:|---|
| E2B | `1894d1fc0a19d86697abd40483f5983c867df03f` | `gemma-4-E2B_q4_0-it.gguf` | `3349514112` | `3646b4c147cd235a44d91df1546d3b7d8e29b547dbe4e1f80856419aa455e6fd` |
| E4B | `bb3b92e6f031fa438b409f898dd9f14f499a0cb0` | `gemma-4-E4B_q4_0-it.gguf` | `5154939136` | `e8b6a059ba86947a44ace84d6e5679795bc41862c25c30513142588f0e9dba1d` |
| 12B | `f6e7774e6148da3b7f201e42ba37cf084c1db35f` | `gemma-4-12b-it-qat-q4_0.gguf` | `6975877728` | `faff1a63667fac17ac5e777f47114688fcefea96e220e211aaa8d62c2c4561f1` |

The companion `mmproj` files are not part of the first text-only proof. Keep the first probe text-only and reject multimodal sidecars until a separate route exists.

Keep `google/gemma-4-26B-A4B-it-qat-q4_0-gguf` and `google/gemma-4-31B-it-qat-q4_0-gguf` research/vault-only on the current Mac path until measured headroom exists. Google's current Q4_0 memory table lists approximate load memory of E2B 2.9 GB, E4B 4.5 GB, 12B 6.7 GB, 26B-A4B 14.4 GB, and 31B 17.5 GB before Epistemos app state, KV, previews, settings, and graph/editor overhead. Treat those numbers as source evidence, not product admission.

Do not use the current MLX Gemma 4 rows as the first proof root. The app intentionally hides Gemma 4 MLX because the Swift loader path is still not proven for `model_type: gemma4`. Do not use Unsloth, Ollama, LM Studio, `llama-cli -hf`, or LiteRT-LM as the first proof root. LiteRT-LM remains a strong later Pro-native candidate, especially for 12B, but the first Epistemos proof stays direct local GGUF plus `llama-cli --offline -m <approved-local-file>`.

Sources checked: Google AI Gemma 4 model overview (`https://ai.google.dev/gemma/docs/core`), Google Gemma 4 QAT Q4_0 Hugging Face collection (`https://huggingface.co/collections/google/gemma-4-qat-q4-0`), Google AI Edge LiteRT-LM Gemma 4 docs (`https://developers.google.com/edge/litert-lm/models/gemma-4`), and `google-ai-edge/LiteRT-LM` README (`https://github.com/google-ai-edge/LiteRT-LM`).

## Build Now

1. Keep the new Settings truth surface visible.
   It should report the Gemma proof lane as contract-ready but owner-receipt blocked. It must not add Gemma to the normal chat picker or mutate RuntimeRouter defaults.

2. Produce the first real owner-approved local artifact receipt.
   Preferred first lane: E2B or E4B QAT GGUF with direct `llama-cli --offline -m <approved-local-file>`. The receipt must bind redacted path digest, sha256, byte count, expected filename, source revision, `llama-cli` version/help digest, offline flag, rollback, RunEventLog, AnswerPacket, abstention, reviewer summary, and non-promotion. Use `Tools/falsifiers/materialize_gemma_owner_approved_local_artifact_receipt.sh`; it requires explicit owner env vars, emits digest-only receipt JSON, and does not execute a model or mutate RuntimeRouter/System G.

3. Implement `F-GemmaDirectHarnessOwnerApprovedFirstRuntimeExecutionProbe`.
   It may run only after a real receipt exists. Use `Tools/falsifiers/run_gemma_first_runtime_execution_probe.sh`; it requires the prior redacted receipt, the same owner approval phrase, the explicit local model path, and direct local `llama-cli`. It emits digest-only stdout/stderr/first-token/timing/exit evidence from a synthetic non-user prompt, with timeout/cancel/teardown proof and zero RuntimeRouter/System G/default mutation.

4. Materialize the first-runtime same-fixture quality packet.
   Use `Tools/falsifiers/materialize_gemma_first_runtime_quality_packet.sh` after a real first-runtime execution receipt exists. It consumes only the redacted runtime receipt and emits a replay-ready packet for the seven quality task families: notes, citation-grounded research, coding patch planning, writing transform, structured tool JSON, refusal/privacy boundary, and latency/abstention. It must not open fixture payloads, run scorers, judge outputs, claim quality, or mutate RuntimeRouter/System G.

5. Run the actual same-fixture replay/scorer pass.
   Use `Tools/falsifiers/execute_gemma_first_runtime_quality_replay.sh` after the quality packet and per-task observation envelope exist. It runs the deterministic shape/safety scorer in memory, emits only output/scorer/verdict digests, records contamination/cache deletion proof, blocks route admission on task failure, and still makes no product/default/System G claim.

6. Materialize the RuntimeRouter admission packet only after receipt plus replay.
   Use `Tools/falsifiers/materialize_gemma_first_runtime_runtime_router_admission_packet.sh` after the quality replay artifact exists. It consumes the digest-only replay artifact, emits a digest-only RuntimeRouter admission packet, keeps route/default/System G mutation at zero, and only marks the packet ready for the next System G dry-run packet when every replay task passed. This is still not live admission, not a default route, and not a user-facing model claim.

7. Materialize the System G dry-run route packet only after admission says ready.
   Use `Tools/falsifiers/materialize_gemma_first_runtime_system_g_dry_run_route_packet.sh` after the digest-only RuntimeRouter admission packet exists and `system_g_dry_run_packet_ready=true`. It emits only a digest-only System G dry-run route packet for later visibility/WRV work, keeps dry-run/admission/RuntimeRouter/System G/default mutation counters at zero, and does not emit a real route, run System G, or claim Gemma capability.

8. Materialize the route AnswerPacket visibility packet only after System G dry-run says ready.
   Use `Tools/falsifiers/materialize_gemma_first_runtime_route_answer_packet_visibility.sh` after the digest-only System G dry-run route packet exists and `route_answer_packet_visibility_ready=true`. It emits only a digest-only visibility packet for later settings/diagnostics/WRV, keeps user-visible AnswerPacket emission and every route/System G/default mutation counter at zero, and uses `settings_diagnostics_wrv_ready` only as permission to build the next WRV slice.

9. Materialize the settings / diagnostics WRV packet only after route visibility says ready.
   Use `Tools/falsifiers/materialize_gemma_first_runtime_settings_diagnostics_wrv.sh` after the digest-only route visibility packet exists and `settings_diagnostics_wrv_ready=true`. It emits only a digest-only WRV packet for the Settings/diagnostics proof lane, keeps picker toggle/default/RuntimeRouter/System G/user-visible AnswerPacket mutation at zero, and uses `release_audit_automated_checks_ready` only as permission to return to the release-audit automated-check blocker.

## Preserve, Do Not Abandon

System G stays the execution spine: MissionPacket to ExecutorEvent/SystemGAgentEvent to RunEventLog to AnswerPacket.

The 70B / 72B cocktail and code-assembly theme stay Pro Research / Vault until the measured substrate gates pass. Gemma-first is the shorter bridge to user-facing local capability, not a retreat from large-model cold assembly.

The 12B lane stays Pro flagship candidate after E2B/E4B proves the receipt, cancellation, memory, quality, admission, and release-audit machinery. LiteRT-LM and MLX are candidate organs, not hidden defaults.

## Do Not Do

- Do not use `llama-cli -hf`, `llama-server`, local endpoints, HF cache paths, Ollama, LM Studio, or model-card examples as Epistemos proof.
- Do not add Gemma to the default picker as a working model before receipt, runtime proof, quality replay, admission, WRV, and release audit.
- Do not store raw owner paths, raw prompts, raw output, stdout/stderr, or raw tokens in artifacts.
- Do not use another metadata-only gate as a substitute for the first real owner-approved receipt.
- Do not run heavy 12B/31B/70B probes before the E2B/E4B direct local-file lane is boring.

## Terminal Agent Prompt

You are in `/Users/jojo/Downloads/Epistemos`.

Continue the Gemma/System G user-facing cutover without abandoning the large-model architecture.

Read first:
- `AGENTS.md`
- `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/fusion/DEEP_RESEARCH_BREAKTHROUGH_SYNTHESIS_2026_06_06.md` Passes 229-238
- `docs/falsifiers/F-GemmaOwnerApprovedLocalArtifactReceiptProbe_2026_06_09.md`
- `docs/falsifiers/F-GemmaOwnerApprovedLocalArtifactReceiptIntakeGate_2026_06_09.md`
- `docs/falsifiers/F-GemmaOwnerApprovedReceiptMaterializationGate_2026_06_09.md`
- `docs/falsifiers/F-GemmaDirectHarnessFirstRuntimeProofCommandCard_2026_06_09.md`
- `docs/falsifiers/F-GemmaDirectHarnessFirstRuntimeProofReceiptGate_2026_06_09.md`
- `Epistemos/Engine/LocalGGUFClient.swift`
- `Epistemos/LocalAgent/RuntimeRouter.swift`
- `Epistemos/SystemG/RealSystemGRunSeam.swift`
- `Epistemos/Views/Settings/LocalAgentDiagnosticsHealthRow.swift`
- `Tools/falsifiers/materialize_gemma_owner_approved_local_artifact_receipt.sh`
- `Tools/falsifiers/run_gemma_first_runtime_execution_probe.sh`
- `Tools/falsifiers/materialize_gemma_first_runtime_quality_packet.sh`
- `Tools/falsifiers/execute_gemma_first_runtime_quality_replay.sh`
- `Tools/falsifiers/materialize_gemma_first_runtime_runtime_router_admission_packet.sh`
- `Tools/falsifiers/materialize_gemma_first_runtime_system_g_dry_run_route_packet.sh`
- `Tools/falsifiers/materialize_gemma_first_runtime_route_answer_packet_visibility.sh`
- `Tools/falsifiers/materialize_gemma_first_runtime_settings_diagnostics_wrv.sh`

Task:
1. Verify the Settings Gemma proof lane reports contract-ready, owner-receipt-missing truth.
2. If no owner-approved local Gemma receipt exists, use the materializer only after the owner supplies the exact approved local artifact path, expected byte count, source revision, source license ref, and approval phrase. Stop before execution if those values are absent.
3. If a real owner-approved local artifact receipt exists, run the smallest `F-GemmaDirectHarnessOwnerApprovedFirstRuntimeExecutionProbe` through `Tools/falsifiers/run_gemma_first_runtime_execution_probe.sh`: one synthetic token through direct local-file `llama-cli --offline -m`, digest-only proof, no runtime route mutation.
4. If a real first-runtime execution receipt exists, materialize the same-fixture quality packet through `Tools/falsifiers/materialize_gemma_first_runtime_quality_packet.sh`; do not run scorers or claim quality in that step.
5. If a real quality packet and same-fixture observation envelope exist, run `Tools/falsifiers/execute_gemma_first_runtime_quality_replay.sh`; keep candidate output only in process memory, persist only digests/verdicts, and do not admit RuntimeRouter/System G in this step.
6. If a real quality replay artifact exists, run `Tools/falsifiers/materialize_gemma_first_runtime_runtime_router_admission_packet.sh`; persist only the digest-only admission packet, keep route/default/System G mutation at zero, and use `system_g_dry_run_packet_ready` only as permission to build the next dry-run packet artifact.
7. If a real RuntimeRouter admission packet exists and `system_g_dry_run_packet_ready=true`, run `Tools/falsifiers/materialize_gemma_first_runtime_system_g_dry_run_route_packet.sh`; persist only the digest-only System G dry-run packet, keep System G dry-run/admission/route/default mutation at zero, and use `route_answer_packet_visibility_ready` only as permission to build later visibility/WRV work.
8. If a real System G dry-run route packet exists and `route_answer_packet_visibility_ready=true`, run `Tools/falsifiers/materialize_gemma_first_runtime_route_answer_packet_visibility.sh`; persist only the digest-only route visibility packet, keep user-visible AnswerPacket/route/default/System G mutation at zero, and use `settings_diagnostics_wrv_ready` only as permission to build later settings/diagnostics WRV.
9. If a real route visibility packet exists and `settings_diagnostics_wrv_ready=true`, run `Tools/falsifiers/materialize_gemma_first_runtime_settings_diagnostics_wrv.sh`; persist only the digest-only WRV packet, keep settings toggle/default/RuntimeRouter/System G/user-visible AnswerPacket mutation at zero, and use `release_audit_automated_checks_ready` only as permission to return to the release-audit automated-check blocker.
10. Add focused tests/source guards for every file touched.
11. Run focused tests first; only run broad release checks after the focused gate is green.

Finish with:
- what is user-facing now
- what is still blocked
- exact artifact or command needed from the owner
- files changed
- tests run
- next safest build slice

## 2026-06-09 Current Validation Addendum

Focused validation now says the runtime spine is healthier than the Gemma
product claim:

- `HELIOSInvariantSourceGuardTests` passed after the SourceMirror proof-root
  included Lean, vault, and falsifier fixture mirrors.
- `OverseerComplexityRouterTests` passed.
- `RuntimeCapabilityAndPerformancePolicyTests` passed.
- `ModelVaultBrowserTests` passed.
- `LocalModelInfrastructureTests` passed. This keeps Gemma out of baseline
  recommendation copy, keeps Gemma 4 hidden on 18 GB until Swift loader/runtime
  proof exists, and keeps GGUF candidates hidden until a GGUF runtime is
  available.
- `LocalModelReleaseSweepTests`, `SystemGRunSeamTests`, `SystemGWiringTests`,
  and `RuntimeRouterTests` passed together: 33 Swift Testing tests green. The
  test run covered the supported-model release sweep, RuntimeRouter lane policy,
  local-before-cloud escalation, privacy rejection when local lanes are
  unavailable, bounded metrics, System G JSON/event log behavior, Rust
  round-trip, local model mission streaming, live bridge artifact writing,
  cooperative cancellation, and System G status wiring.

This means `RuntimeRouter -> System G -> RunEventLog -> AnswerPacket` is a
valid spine to build against. It does not mean Gemma, 12B, 70B, 72B, or the
code-assembly cocktail is live.

## What Is User-Facing Now

User-facing today should remain the stable local app floor plus visible
diagnostics:

- normal local routing through the existing proven local model path;
- RuntimeRouter/System G health rows and diagnostics;
- Gemma E2B/E4B/12B proof-lane status as local-receipt/runtime/replay/WRV
  proven but release-audit/product-route blocked;
- no Gemma picker/default route that implies working capability;
- no hidden cloud, hidden server, `-hf`, cache, MTP, LiteRT, MLX, or 70B
  substitution as proof.

## 2026-06-09 E2B Runtime Proof Update

The first practical Gemma proof ladder is no longer blocked by missing local
E2B bytes:

1. `Tools/falsifiers/acquire_gemma_official_qat_gguf.sh --lane e2b --materialize-receipt`
   downloaded the official `google/gemma-4-E2B-it-qat-q4_0-gguf` artifact into
   explicit Application Support quarantine and verified bytes plus SHA256.
2. `artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_materializer/receipt.redacted.json`
   records the digest-only local artifact receipt for
   `gemma-4-E2B_q4_0-it.gguf`, `3349514112` bytes, SHA256
   `3646b4c147cd235a44d91df1546d3b7d8e29b547dbe4e1f80856419aa455e6fd`.
3. `artifacts/falsifiers/gemma_direct_harness_first_runtime_execution_probe/receipt.redacted.json`
   records a bounded direct local-file `llama-cli --offline -m` execution
   receipt with exit `0`, one-token digest, and zero RuntimeRouter/System G/
   settings-default mutation.
4. `artifacts/falsifiers/gemma_direct_harness_first_runtime_quality_packet/packet.redacted.json`
   packaged the same-fixture quality replay surface for seven task families.
5. `Tools/falsifiers/run_gemma_first_runtime_quality_observation_replay.sh`
   generated seven tiny local observations through direct local Gemma, kept raw
   outputs only in a temporary file, deleted that file, and emitted
   `artifacts/falsifiers/gemma_direct_harness_first_runtime_quality_replay/result.redacted.json`.
   The replay scored `7/7` and set `route_admission_packet_ready=true` while
   keeping quality/product claim flags false.
6. RuntimeRouter admission, System G dry-run route, route AnswerPacket
   visibility, and Settings/diagnostics WRV packets were materialized as
   digest-only artifacts:
   - `artifacts/falsifiers/gemma_direct_harness_first_runtime_runtime_router_admission/admission.redacted.json`
   - `artifacts/falsifiers/gemma_direct_harness_first_runtime_system_g_dry_run_route/system_g_dry_run.redacted.json`
   - `artifacts/falsifiers/gemma_direct_harness_first_runtime_route_answer_packet_visibility/visibility.redacted.json`
   - `artifacts/falsifiers/gemma_direct_harness_first_runtime_settings_diagnostics_wrv/wrv.redacted.json`

This is still not a live picker/default route and still not T4/user-facing
Gemma. It proves the first E2B local QAT/llama.cpp ladder through WRV evidence.
The current next cursor is
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.

## 2026-06-10 E4B / 12B Runtime Proof Update

The same direct local-file proof ladder now exists for the larger Gemma QAT
lanes:

| Lane | Model | Local receipt | First-runtime duration | Replay | WRV |
|---|---|---:|---:|---:|---:|
| E2B | `google/gemma-4-E2B-it-qat-q4_0-gguf` | `3349514112` bytes | `2154` ms | `7/7` | true |
| E4B | `google/gemma-4-E4B-it-qat-q4_0-gguf` | `5154939136` bytes | `8181` ms | `7/7` | true |
| 12B | `google/gemma-4-12B-it-qat-q4_0-gguf` | `6975877728` bytes | `10213` ms | `7/7` | true |

Lane-specific artifacts live under the same falsifier roots, with `e4b/` and
`12b/` subdirectories for the larger lanes:

- `artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_materializer/{e4b,12b}/receipt.redacted.json`
- `artifacts/falsifiers/gemma_direct_harness_first_runtime_execution_probe/{e4b,12b}/receipt.redacted.json`
- `artifacts/falsifiers/gemma_direct_harness_first_runtime_quality_replay/{e4b,12b}/result.redacted.json`
- `artifacts/falsifiers/gemma_direct_harness_first_runtime_runtime_router_admission/{e4b,12b}/admission.redacted.json`
- `artifacts/falsifiers/gemma_direct_harness_first_runtime_system_g_dry_run_route/{e4b,12b}/system_g_dry_run.redacted.json`
- `artifacts/falsifiers/gemma_direct_harness_first_runtime_route_answer_packet_visibility/{e4b,12b}/visibility.redacted.json`
- `artifacts/falsifiers/gemma_direct_harness_first_runtime_settings_diagnostics_wrv/{e4b,12b}/wrv.redacted.json`

Release-audit focused distribution evidence is also refreshed:

- `artifacts/falsifiers/release_audit_distribution_focused_evidence/result.json`
  passes from a fresh `Epistemos-AppStore` build log and the focused
  distribution test slice.
- `artifacts/falsifiers/release_audit_zero_fail_pass_ledger/result.json`
  passes with cumulative `zero_fail_pass_count=3` for the current source-state
  signature.
- `artifacts/falsifiers/release_audit_distribution_compliance_review/result.json`
  passes distribution/compliance review while still refusing notarization, App
  Review, ship-call, or Gemma route-promotion claims.
- `artifacts/falsifiers/gemma_qat_e2b_product_capability_recheck_gate/result.json`
  passes the post-release-audit product-capability recheck as a blocked truth:
  E2B/E4B/12B proof lanes are ready, but live RuntimeRouter/System G/default
  route integration remains pending.

This is a major movement from "why is Gemma not running?" to "Gemma runs
through the guarded local-file proof ladder." It is still not a product-route
green light. The current blocking cursor is now
`gemma_product_route_integration_gate`.

## What Is Truly Left

The next real Gemma step is live route integration. Distribution/compliance and
the uninterrupted zero-fail ledger now have passing artifacts for the current
source-state signature; they do not authorize a ship-call, default route, or
T4 claim by themselves. After that:

1. Only after the release gate is green, expose Gemma as truthful gated
   diagnostics/picker candidates, not defaults.
2. Promote E2B first as the small proof lane, E4B as the scale lane, and 12B as
   the Pro flagship candidate only if the same release discipline stays green.
3. Wire any live RuntimeRouter/System G route behind explicit user selection,
   SCOPE-Rex/SovereignGate policy, cancellation, rollback, RunEventLog,
   AnswerPacket witness, and visible caveats.
4. Keep LiteRT-LM, MLX, MTP, multimodal sidecars, 26B/31B, and 70B/72B work
   blocked until their own byte, route, memory, quality, and release evidence
   exists.

## Preserve The Big Runtime

The 12B lane is now locally receipt/runtime/replay/WRV proven as a direct GGUF
Pro flagship candidate, but it still waits on live route admission. LiteRT-LM and MLX are separate candidate organs that must prove
package/API/cancellation/sandbox and Swift loader behavior before they can
outrank the direct GGUF lane.

The 70B/72B cocktail and code-assembly runtime remain Pro Research / Vault.
They are not abandoned. Their current blockers are still real: prompt-level
KV-Direct proof is red, the 70B cocktail preflight is red, dense live residency
is not proven, provider/reference equivalence is not proven, and cold assembly
must stay behind PatternBoost/UAS/AppColdStore/AnswerPacket witnesses.

## Next Safest Build Slice

Return to `gemma_product_route_integration_gate`.
Gemma E2B/E4B/12B now have local proof artifacts and release-audit completion
evidence; product truth is blocked by live route integration, not by QAT source
availability, basic local execution, distribution/compliance review, or the
zero-fail ledger.
