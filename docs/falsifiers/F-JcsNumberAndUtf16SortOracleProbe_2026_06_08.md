# F-JcsNumberAndUtf16SortOracleProbe - 2026-06-08

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only L1/T1 side-ladder witness.

Artifact:
`artifacts/falsifiers/jcs_number_and_utf16_sort_oracle_probe/result.json`

Command:
`Tools/falsifiers/f_jcs_number_and_utf16_sort_oracle_probe.sh`

Witness address:
`sha256:036721ee1d6f3291de7c723759928401681ee7c6a44ccdfc80aa278dfb71412a`

Upstream JCS parity address:
`sha256:2b7f5aa4ec88740c94d97b8d2d87e606e9d7c09391eb57ccb647eca2e230c5eb`

## Claim Boundary

This witness pins the RFC 8785 Appendix B number sample table and the Section
3.2.3 UTF-16 property-sort sample before any synthetic fixture writer can
materialize bytes. It keeps the writer itself blocked: this is oracle evidence,
not a completed Epistemos-owned canonical JSON implementation.

The witness records `node` / ECMAScript `JSON.stringify` observation for the
number rows, but it does not import Node, call Node from the app, write fixture
files, or make `serde_json` / TriFusion fixture authority.

## Required Proofs

- upstream `F-JcsCanonicalJsonWriterParityGate` address binding
- RFC 8785 source-card binding
- 26 Appendix B number rows
- 24 finite number rows and 2 rejected NaN/Infinity rows
- minus-zero normalization to `0`
- ECMAScript expected JSON string binding
- UTF-16 code-unit property-sort binding
- UTF-8 and locale sorting rejected as authorities
- materialization blocked until a later writer dry-run
- zero fixture/schema/model/runtime/provider/cache/index bytes
- zero armed commands
- explicit non-promotion across L1/L2/L3/T4/T5/product/release/70B claims

## Red Fixtures

The falsifier rejects 30 red fixtures including upstream-address drift, wrong
RFC source, disabled number/UTF-16 source binding, local writer authority
claims, number expected-JSON drift, number disposition drift, digest drift,
UTF-16 rank drift, policy bypasses, materialization enablement, metadata
boundary disablement, fixture/schema file writes, runtime/model/provider/cache/
index byte leaks, command arming, L1/L2/product-green claims, and hidden route
authority.

## Three-Layer Truth

- L1 architecture cursor: side-ladder advanced for canonical fixture identity;
  the guard-owned product cursor remains
  `small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
- L2 capability route: unchanged; the capability kernel remains
  `vault_research_route_with_packetized_mitigation`.
- L3 user-facing / north star: unchanged and red for large-local-model product
  capability. This witness creates no fixture files, eval win, runtime route,
  model load, release readiness, live dense 70B, or SSD-as-RAM claim.

## Next

`jcs_fixture_writer_fail_closed_dry_run` is the next side-ladder unit. It must
consume the pinned number and UTF-16 oracles while still failing closed before
owner-approved fixture materialization.
