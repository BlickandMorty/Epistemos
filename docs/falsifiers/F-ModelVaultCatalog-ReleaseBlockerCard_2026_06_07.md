# F-ModelVaultCatalog-ReleaseBlockerCard - 2026-06-07

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only L1/T1 release-blocker source-card witness.

This witness turns the retained `model_vault_catalog` release-audit failure family into a buildable catalog-trust blocker. It does not edit Swift product code, rerun `xcodebuild`, load model/runtime bytes, prove model availability, promote MAS/Pro runtime capability, or make a user-facing large-model claim.

## Artifact

- Script: `Tools/falsifiers/f_model_vault_catalog_release_blocker_card.sh`
- Primitive: `agent_core/src/uas/model_vault_catalog_release_blocker_card.rs`
- Binary: `agent_core/src/bin/falsify_model_vault_catalog_release_blocker_card.rs`
- Artifact: `artifacts/falsifiers/model_vault_catalog_release_blocker_card/result.json`
- Upstream source-card witness: `artifacts/falsifiers/release_audit_failure_family_source_card/result.json`

## Measurements

- Retained family: `model_vault_catalog`
- Retained issue count: `9`
- Source refs: `8`
- Required invariants: `10`
- Rejected red fixtures: `12`
- Deterministic blocker address: `sha256:776e7a5f6226b4ce1198203548ddaf71223fd1b62b3c5d058bbcd01ecb4e765d`
- Next source-card unit: `agent_route_policy_large_model_no_hidden_authority`

## Bound Source Refs

- `Epistemos/State/InferenceState.swift`
- `Epistemos/Engine/TriageService.swift`
- `Epistemos/Engine/MLXInferenceService.swift`
- `Epistemos/Engine/ModelDownloadManager.swift`
- `Epistemos/Views/Settings/ModelVaultsSettingsView.swift`
- `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift`
- `EpistemosTests/TriageServiceTests.swift`
- `docs/fusion/TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE_2026_06_06.md`

## Bound Invariants

`release_selectable_installed_models_only`, `interactive_chat_validated_models_only`, `gemma4_loader_blocked_from_picker`, `shared_model_vault_targets_builder`, `runtime_directory_must_resolve_before_request`, `model_download_checksum_validation_bound`, `mas_pro_status_visible_before_route`, `no_provider_or_cloud_fallback_from_catalog`, `no_catalog_entry_counts_as_runtime_proof`, and `answer_packet_caveat_required_for_unavailable_models`.

## Truth Layers

- L1 architecture evidence: source-card blocker landed; it makes model-vault/catalog repair addressable.
- L1 guard-owned product cursor: unchanged at `small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
- L2 capability route: unchanged and red, `vault_research_route_with_packetized_mitigation`.
- L3 user-facing/release readiness: unchanged and red until actual Swift repair, logs, manual runtime evidence, distribution review, and three zero-fail passes exist.

## Red Fixtures

The falsifier rejects upstream failure, wrong upstream cursor, wrong family, zero issue count, missing `InferenceState` source ref, missing Gemma 4 loader-blocking invariant, catalog-as-runtime-proof claims, hidden cloud fallback, hidden route authority, live dense-70B claims, L2/L3/product green claims, and model/runtime byte leaks.

## Promotion Caveat

The catalog can describe installability, release validation, loader caveats, and model-vault surfaces. It cannot by itself prove runtime availability, local large-model fit, live dense 70B, MAS/Pro green, or user-facing release readiness.
