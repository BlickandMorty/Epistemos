# F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditAutomatedChecksProbe

Status: RED, schema-valid primary witness artifact on 2026-06-05.

2026-06-06 hardening note: the red artifact now includes a bounded failure-family
ledger parsed from the retained `xcodebuild_test` log. This did not rerun the heavy
release command set and did not change the gate status.

2026-06-08 refresh note: regenerated the artifact builder directly against the
retained `checks.tsv` and command logs at commit
`cdb0ba4ccaf41e67778cf3fe2f768a4c99ac4276`, without running the heavy
`xcodebuild test` release command set. The artifact remains RED and
schema-valid, now carrying current-HEAD commit identity plus the same top
repair family `graph_filter_visibility`.

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

Command:

```bash
Tools/falsifiers/f_small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe.sh
```

Artifact:

```text
artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json
```

## Result

The gate implementation is hardened and validated, but the current product automated-check ledger is red. The artifact records five required checks with bound log byte counts and SHA-256 digests:

- `xcodebuild_build`: pass
- `xcodebuild_test`: fail
- `graph_engine_cargo_test`: pass
- `omega_mcp_cargo_test`: pass
- `omega_ax_cargo_test`: pass

Measured truth:

- `overall_pass=false`
- `check_count=5`
- `failed_check_count=1`
- `xcodebuild_test_passed=false`
- `xcodebuild_test_issue_count=161`
- `xcodebuild_test_unique_failure_count=84`
- `top_xcodebuild_test_failure_family=graph_filter_visibility`
- `model_runtime_bytes_loaded=0`
- `next_cursor=small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe` appears inside the red artifact as the witness' logical next edge, but the guard-owned cursor does not advance while `overall_pass=false`

Failure-family ledger from the retained Swift test log:

- graph/filter visibility: `34`
- agent route policy: `21`
- theme/presentation: `19`
- distribution/project integrity: `18`
- research tool catalog: `16`
- editor/epdoc surface: `14`
- UI shell source guard: `14`
- model vault/catalog: `9`
- visible output sanitization: `5`
- runtime performance policy: `3`
- source-guard drift: `3`
- tool execution surface: `2`
- body-read checksum, search index, and XPC trust: `1` each

## Focused Repair Plan

2026-06-06 follow-up hardening binds the top family to a focused repair plan:

- `focused_repair_family=graph_filter_visibility`
- `focused_repair_plan_bound=true`
- `focused_repair_plan_matches_top_family=true`

Focused commands to run before the full release-audit marathon:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/FilterEngineComprehensiveTests test
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ResourceExhaustionTests test
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ConcurrencyEdgeCaseTests test
```

Source anchors:

- `Epistemos/Graph/FilterEngine.swift`
- `Epistemos/Models/GraphTypes.swift`
- `Epistemos/Graph/GraphState.swift`

This plan is not a pass claim. It only tells the next repair session where to start.

## Three-Layer Truth

L1: The automated-checks gate exists, writes a schema-valid artifact, preserves failed-command evidence, emits the red failure-family ledger, and keeps `duplicate_risk_count=0`, but the L1 architecture cursor does not advance because `xcodebuild_test` failed.

L2: Product capability remains `overall_pass=false` with route status `vault_research_route_with_packetized_mitigation`.

L3: User-facing/product capability and release readiness are unchanged. This artifact is not a ship call and does not satisfy runtime-log evidence, manual runtime verification, distribution/compliance review, or three uninterrupted zero-fail passes.

## Hardening Coverage

The primitive and falsifier reject missing upstream proof, missing required checks, duplicate checks, mismatched status/exit-code rows, missing logs, invalid digests, missing or duplicate blocker cards, green blocker cards, hidden authority, route mutation, incomplete automated-check claims, false zero-fail pass counts, false log/manual/distribution evidence claims, ship-call authorization, product-capability promotion, runtime/model byte loads, MAS live-agent overclaims, L2/L3 green claims, autogenous-kernel attempts, live 70B/128K product claims, next-cursor mismatch, and compact metadata-budget overflow.

Failed automated checks remain valid ledger evidence when their status and exit code agree; they drive red axes instead of preventing artifact generation.
