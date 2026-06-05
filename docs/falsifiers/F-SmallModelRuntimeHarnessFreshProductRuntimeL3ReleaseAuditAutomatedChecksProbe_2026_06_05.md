# F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditAutomatedChecksProbe

Status: RED, schema-valid primary witness artifact on 2026-06-05.

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
- `model_runtime_bytes_loaded=0`
- `next_cursor=small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe` only if the automated checks pass

## Three-Layer Truth

L1: The automated-checks gate exists, writes a schema-valid artifact, preserves failed-command evidence, and keeps `duplicate_risk_count=0`, but the L1 architecture cursor does not advance because `xcodebuild_test` failed.

L2: Product capability remains `overall_pass=false` with route status `vault_research_route_with_packetized_mitigation`.

L3: User-facing/product capability and release readiness are unchanged. This artifact is not a ship call and does not satisfy runtime-log evidence, manual runtime verification, distribution/compliance review, or three uninterrupted zero-fail passes.

## Hardening Coverage

The primitive and falsifier reject missing upstream proof, missing required checks, duplicate checks, mismatched status/exit-code rows, missing logs, invalid digests, missing or duplicate blocker cards, green blocker cards, hidden authority, route mutation, incomplete automated-check claims, false zero-fail pass counts, false log/manual/distribution evidence claims, ship-call authorization, product-capability promotion, runtime/model byte loads, MAS live-agent overclaims, L2/L3 green claims, autogenous-kernel attempts, live 70B/128K product claims, next-cursor mismatch, and compact metadata-budget overflow.

Failed automated checks remain valid ledger evidence when their status and exit code agree; they drive red axes instead of preventing artifact generation.
