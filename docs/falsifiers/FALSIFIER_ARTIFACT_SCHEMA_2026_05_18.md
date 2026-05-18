---
state: t23b-falsifier-artifact-schema
created_on: 2026-05-18
schema_version: 2026-05-18.2
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
---

# Falsifier Artifact Schema - 2026-05-18

This schema defines the canonical witness artifact contract for every T23B F-* falsifier. It generalizes the T12 [F-ULP-Oracle](F_ULP_ORACLE_2026_05_18.md) witness pattern into a shared document shape. A row in the M2 Pro Verified Floor Handbook may not claim runtime evidence unless its artifact uses this contract or a documented successor.

## Initial Fields

| Field | Type | Required | Rule |
|---|---|---|---|
| `falsifier_id` | string | yes | Exact F-* identifier from the handbook row, for example `F-ULP-Oracle`. |
| `schema_version` | string | yes | Schema version for this artifact contract. Initial value: `2026-05-18.2`. |
| `hardware_pin` | object | yes | Jojo's M2 Pro hardware floor for the run; substitutes such as M2 Max, M3 Max, or theoretical bandwidth fail the artifact. |
| `command` | string | yes | Exact command line used to produce the artifact. It must match the row command after `NOT IMPLEMENTED:` is removed. |
| `commit_sha` | string | yes | Full 40-character lowercase hex Git commit SHA for the repo state that produced the artifact. Short SHAs fail replay eligibility. |
| `fixture_id` | string | yes | Stable fixture identifier for the input set, including dataset/config version when applicable. |
| `timestamp_utc` | string | yes | UTC timestamp for artifact creation in RFC 3339 date-time form. Local time zones fail the artifact. |
| `measurements` | object | yes | Per-axis measured values from the run. Each axis must be named and must include a value plus unit. |
| `acceptance_thresholds` | object | yes | Per-axis pass criteria. Each threshold must name an operator, value, and unit so the artifact can be replayed against the handbook row. |
| `pass_per_axis` | object | yes | Per-axis boolean validator result. Axis names should match the measurement and threshold axes. |
| `overall_pass` | boolean | yes | Falsifier-level result after all required axes are evaluated. Runtime witness status requires `true`; preserved speculation remains non-witness. |
| `fallback_tier` | string | yes | T12 ladder value: `Primary`, `Fallback`, or `Fail`. `Fail` means no acceptable fallback runtime witness was produced. |
| `anomalies` | array | yes | Structured anomaly ledger. Use an empty array only when no rig, input, output, timing, memory, fallback, or unsupported-case anomaly occurred. |
| `notes` | string | yes | Human-readable caveats or replay notes. Use `none` when there is nothing to add. |

## Hardware Pin Rule

`hardware_pin` must identify Jojo's M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s memory-bandwidth floor. M2 Max, M3 Max, cloud GPU, simulator, and theoretical-bandwidth substitutions fail schema validation.

## Hardware Pin Typed Sub-Schema Target

The next hardware-pin schema revision should replace prose-shaped fields with typed fields: `model_identifier`, `chip`, `cpu_cores`, `gpu_cores`, `memory_gb`, `uma`, and `memory_bandwidth_gb_s`. Until that bump lands, the current JSON fragment remains authoritative; artifacts must not pre-adopt the target shape under schema version `2026-05-18.2`.

## Hardware Pin Migration Mapping

For the next schema bump, `machine` maps to `model_identifier`, `cpu` maps to `cpu_cores`, `gpu` maps to `gpu_cores`, `unified_memory_gb` maps to `memory_gb`, and `memory_bandwidth_gb_s` keeps its name. The new `chip` field must equal `M2 Pro`, and `uma` must be `true`.

## Falsifier ID Rule

`falsifier_id` must be the exact canonical row identifier from the handbook and the matching fragment frontmatter. The JSON Schema fragment enumerates the 15 accepted IDs; aliases such as `F-ULP`, `F-KV-Direct`, or `F-VaultRecall` are allowed in prose only and fail artifact identity.

## Falsifier Map Alignment Rule

The `falsifier_id` enum, cross-gate axis floor table, command path map, and expected artifact root map must cover the same 15 canonical IDs. Adding, removing, or renaming a gate is invalid unless all four surfaces change together.

## Schema Version Rule

`schema_version` must equal the version constant in the JSON Schema fragment. Artifacts from older schema versions are preserved historical evidence only until they are replayed or migrated with an explicit migration note; they may not satisfy a current handbook pass claim by silent compatibility.

## Schema Migration Table

| From | To | Trigger | Migration note requirement |
|---|---|---|---|
| `2026-05-18.1` | `2026-05-18.2` | Structured `anomalies` became required and cross-gate axis floors became explicit. | Name the source artifact, state whether anomalies were inspected, and map every legacy axis to the current minimum axis set. |
| `2026-05-18.2` | next | New F-* gate, typed hardware-pin sub-schema, changed command-path map, changed expected-artifact-root map, expanded anomaly requirements, or changed top-level witness field. | Include `from_schema`, `to_schema`, `artifact_path`, `migration_command`, `field_mapping`, and `reviewer` in `notes` or a linked migration artifact. |

## Migration Note Minimum Shape

Migration notes must name `from_schema`, `to_schema`, `artifact_path`, `migration_command`, `field_mapping`, `reviewer`, and `reviewed_at_utc`. A migrated artifact without all seven values remains historical evidence, not a current pass witness.

## Replay Identity Rule

`command` must match the handbook row command after `NOT IMPLEMENTED:` is removed, and `commit_sha` must identify the repo state that produced the artifact with a full 40-character lowercase hex SHA. A witness with a stale command, missing commit, short SHA, or commit from another branch is replay-ineligible.

## Command Path Rule

`command` must begin with the canonical `tools/falsifiers/<script>.sh` path for the matching row. Wrapper commands, shell aliases, copied scripts, or commands run from another directory fail replay eligibility unless the handbook row itself is updated first.

## Command Argument Rule

Command arguments, when present, must be plain space-separated flag/path/value tokens. Shell metacharacters, pipelines, command substitution, environment-prefix execution, or newline-separated command strings fail replay eligibility.

## Command Path Map

| Falsifier | Canonical command path |
|---|---|
| `F-Eidos-ClosedCitation` | `tools/falsifiers/f_eidos_closed_citation.sh` |
| `F-VaultRecall-50` | `tools/falsifiers/f_vault_recall_50.sh` |
| `F-PageGather-Baseline` | `tools/falsifiers/f_page_gather_baseline.sh` |
| `F-PageGather-Scatter` | `tools/falsifiers/f_page_gather_scatter.sh` |
| `F-UAS-CopyCount` | `tools/falsifiers/f_uas_copy_count.sh` |
| `F-ACS-AnchorLookup` | `tools/falsifiers/f_acs_anchor_lookup.sh` |
| `F-InterruptScore-CPU` | `tools/falsifiers/f_interrupt_score_cpu.sh` |
| `F-PacketRouter1bit` | `tools/falsifiers/f_packet_router_1bit.sh` |
| `F-ControllerKernelPack` | `tools/falsifiers/f_controller_kernel_pack.sh` |
| `F-SemiseparableBlockScan` | `tools/falsifiers/f_semiseparable_block_scan.sh` |
| `F-LocalRecallIsland` | `tools/falsifiers/f_local_recall_island.sh` |
| `F-KV-Direct-Gate` | `tools/falsifiers/f_kv_direct_gate.sh` |
| `F-WBO-DriftLedger` | `tools/falsifiers/f_wbo_drift_ledger.sh` |
| `F-ULP-Oracle` | `tools/falsifiers/f_ulp_oracle.sh` |
| `F-70B-Local-Cocktail-Lite` | `tools/falsifiers/f_70b_local_cocktail_lite.sh` |

## Timestamp Rule

`timestamp_utc` must record the artifact creation time in RFC 3339 UTC form ending in `Z`, with bounded month, day, hour, minute, and second fields. Local timezone strings, date-only values, offset timestamps, leap-second spellings, or timestamps captured before the falsifier command completed fail replay eligibility because they cannot anchor the witness to the produced payload.

## Fixture Identity Rule

`fixture_id` must be a replay-safe lowercase slug matching `^[a-z0-9][a-z0-9._-]*$` and stable enough to recover the input corpus, generated-case grid, seed, configuration, and dataset version used by the run. A fixture label that cannot distinguish regenerated inputs from the original witness input set fails replay eligibility.

## Measurements Rule

`measurements` records observed run output only. Each axis must store the raw measured value and unit used by the falsifier, not a prose summary, target, or inferred pass label. Aggregate axes may add `samples`, `statistic`, or raw-artifact references, but the reported `value` must remain replay-computable from the committed artifact payload.

## Classified Unsupported Value Rule

`value: null` is allowed only when `statistic` is `classified` and an `unsupported_case` anomaly names the affected axis. Null cannot stand in for missing numeric, boolean, or digest output.

## Aggregate Statistic Rule

When `statistic` is `min`, `max`, `mean`, `median`, `p50`, `p95`, `p99`, or `count`, the measurement must provide nonempty `samples` or `raw_artifact`. A `samples` array must use one scalar type across all entries. Aggregate values without replay material are summaries, not witness measurements.

## Digest Measurement Rule

When `statistic` is `digest`, `value` must be a lowercase `sha256:` digest and `unit` must be `sha256`. Bare hashes, uppercase hex, alternate algorithms, and prose digests fail validation.

## Acceptance Thresholds Rule

`acceptance_thresholds` records the falsifiable bar copied from the handbook row or fragment. Each axis must name the operator, value, and unit used to judge the matching measurement. Thresholds that depend on another artifact, such as PageGather scatter depending on the baseline calibration, must identify the upstream artifact path or axis; recomputing a private threshold from prose fails validation.

## Artifact Reference Rule

`raw_artifact` and `upstream_artifact` references must point under `artifacts/falsifiers/` without `.` or `..` path segments. A schema witness cannot use ad hoc temp files, user-local absolute paths, cloud URLs, path traversal, or prose-only upstream references as replay material.

## Upstream Threshold Pair Rule

If a threshold includes `upstream_artifact`, it must also include `upstream_axis`; if it includes `upstream_axis`, it must also include `upstream_artifact`. A half-linked upstream threshold is not replayable.

## Expected Artifact Root Map

| Falsifier | Expected artifact root |
|---|---|
| `F-Eidos-ClosedCitation` | `artifacts/falsifiers/f_eidos_closed_citation/` |
| `F-VaultRecall-50` | `artifacts/falsifiers/f_vault_recall_50/` |
| `F-PageGather-Baseline` | `artifacts/falsifiers/page_gather/baseline/` |
| `F-PageGather-Scatter` | `artifacts/falsifiers/page_gather/scatter/` |
| `F-UAS-CopyCount` | `artifacts/falsifiers/uas_copy_count/` |
| `F-ACS-AnchorLookup` | `artifacts/falsifiers/acs_anchor_lookup/` |
| `F-InterruptScore-CPU` | `artifacts/falsifiers/interrupt_score_cpu/` |
| `F-PacketRouter1bit` | `artifacts/falsifiers/packet_router_1bit/` |
| `F-ControllerKernelPack` | `artifacts/falsifiers/controller_kernel_pack/` |
| `F-SemiseparableBlockScan` | `artifacts/falsifiers/semiseparable_block_scan/` |
| `F-LocalRecallIsland` | `artifacts/falsifiers/local_recall_island/` |
| `F-KV-Direct-Gate` | `artifacts/falsifiers/kv_direct_gate/` |
| `F-WBO-DriftLedger` | `artifacts/falsifiers/wbo_drift_ledger/` |
| `F-ULP-Oracle` | `artifacts/falsifiers/ulp_oracle/` |
| `F-70B-Local-Cocktail-Lite` | `artifacts/falsifiers/70b_local_cocktail_lite/` |

The artifact file path is validator input, not a JSON payload field. Adding `artifact_path` inside the witness JSON fails `additionalProperties: false`; placing the file outside its mapped root fails replay eligibility. Canonical witness filenames are `result.json` for object artifacts and `result.jsonl` only for row-stream artifacts such as `F-WBO-DriftLedger`; every other falsifier must use `result.json`. Sidecars may be referenced as raw evidence but cannot replace the canonical witness file.

## JSONL Witness Rule

When the canonical witness file is `result.jsonl`, every line must be a JSON object with `schema_version`, `falsifier_id`, `row_index`, `prompt_id`, `token_index`, `axis`, `measurement`, `acceptance_threshold`, `pass`, and `anomalies`. JSONL rows may not add undeclared top-level keys; row `measurement`, `acceptance_threshold`, and `anomalies` entries inherit the same closed-object rule as object artifacts. Each row `schema_version` must equal the current schema version, and each row `falsifier_id` must equal the artifact manifest falsifier ID. `row_index` values must be zero-based and contiguous so replay can identify missing or reordered ledger rows. `prompt_id` must match `^[a-z0-9][a-z0-9._-]*$`, and `token_index` must be a non-negative integer, binding each drift row back to the producing prompt fixture and token position without aliases. `axis` must match one of the falsifier's declared floor axes or an explicitly declared added axis from the same artifact manifest. Row `measurement.unit` must equal row `acceptance_threshold.unit`. Any row-level anomaly with an `axis` must use that same row `axis`. Row `pass` must equal replaying `measurement` against `acceptance_threshold`.

## Threshold Operator Rule

Numeric comparison operators require numeric threshold values: `<=` and `>=` use one number, while `between` uses exactly two numbers. The `present` operator must use boolean `true` as its value. The `contains` operator must use a string or array value. Other non-numeric operators may carry string, boolean, or array values only when the axis semantics need them.

## Measurement Threshold Compatibility Rule

For numeric threshold operators, the matching measurement `value` must also be numeric. Categorical strings may be used for taxonomy or digest axes, but they cannot satisfy numeric comparisons by string coercion.

## Unit Consistency Rule

For every axis, `measurements[axis].unit` must equal `acceptance_thresholds[axis].unit`. Digest axes therefore require `sha256` on both sides. Unit aliases, implicit conversions, or mixed forms such as `GB/s` versus `MB/s` fail validation unless the schema version explicitly adds a conversion table.

## Unit Token Rule

Units must be compact ASCII tokens matching `^[A-Za-z0-9%./_-]+$`. Freeform units such as `gigabytes per second`, unit strings with spaces, or unicode symbols fail validation because replay code must compare units byte-for-byte.

## Pass Per Axis Rule

`pass_per_axis` records the boolean result of applying each acceptance threshold to its matching measurement. A failed axis must remain present with `false`; omitting a failed axis or renaming it so `overall_pass` can become true invalidates the artifact. Non-numeric axes, such as fake-citation rejection or stress-case classification, still require explicit boolean results tied to named thresholds.

## Overall Pass Rule

`overall_pass` is the conjunction of all required `pass_per_axis` values for the artifact's selected tier. It may be `true` with `fallback_tier: Fallback` only as fallback-route evidence; primary row promotion still requires `overall_pass: true` and `fallback_tier: Primary`. If any required axis is `false`, missing, or replay-ineligible, `overall_pass` must be `false`.

## Pass-Affecting Anomaly Rule

If any anomaly has `affects_pass: true`, the artifact cannot be a primary pass. It may still record fallback evidence only when `fallback_tier` is `Fallback` and the anomaly ledger names the fallback route.

## Anomalies Rule

`anomalies` records structured facts about unexpected rig, input, output, timing, memory, thermal, power, disk, permission, fallback, or unsupported-case behavior. Each anomaly must say whether it affects pass eligibility. An empty array means no anomaly occurred; it does not mean anomalies were uninspected.

If an anomaly includes `severity`, it must be one of `info`, `warning`, or `blocking`. `blocking` anomalies must set `affects_pass: true`; otherwise the artifact hides a disqualifying condition behind a harmless flag. Freeform severity labels fail validation because merge tooling must sort anomaly urgency without synonym tables.

## Anomaly Axis Reference Rule

When an anomaly has an `axis`, that axis must appear in the artifact's `measurements`, `acceptance_thresholds`, and `pass_per_axis` maps. An anomaly cannot introduce a side-channel axis that bypasses the per-axis pass ledger.

## Anomaly Kind Requirements

| Kind | Required detail in `description` |
|---|---|
| `rig` | Actual machine identifier and the expected M2 Pro pin it diverged from. |
| `input` | Fixture case, seed, or source input that diverged from the declared `fixture_id`. |
| `output` | Output artifact path, digest, or missing-output condition affected by the anomaly. |
| `timing` | Affected axis plus observed wall-clock or latency value. |
| `memory` | Affected axis plus observed RAM, RSS, UMA, or allocation value. |
| `thermal` | Thermal state or throttling signal and whether timing axes are invalidated. |
| `power` | Power source or low-power state and whether timing axes are invalidated. |
| `disk` | Disk-full, write-failure, or filesystem path detail. |
| `permission` | Denied entitlement, sandbox, file, or device permission. |
| `fallback` | Referenced fallback route in `description` plus the anomaly object's `fallback_tier`. |
| `unsupported_case` | Fixture case that was classified instead of silently counted. |
| `other` | Specific reason the anomaly does not fit the enumerated kinds; generic `other` is invalid. |

## Notes Rule

`notes` is for replay caveats, rig observations, and summaries that do not fit a numeric or boolean axis. Use `none` only when the run has no caveat. Any non-`none` note must include `anomaly_inspection=complete` so reviewers can distinguish observed caveats from an uninspected anomaly surface. Notes cannot add hidden thresholds, override failed axes, replace raw measurements, replace the structured anomaly ledger, embed fenced JSON, begin with an object payload, or turn fallback evidence into a primary pass claim.

## Axis Consistency Rule

The keys under `measurements`, `acceptance_thresholds`, and `pass_per_axis` must describe the same axis set. Missing or extra axes fail artifact validation because they make the per-axis result non-replayable.

## Axis Name Grammar Rule

Every axis key must match `^[a-z][a-z0-9_]*$`. CamelCase, hyphenated, dotted, spaced, or prose-shaped axis labels fail validation even when they are obvious to a human reviewer, because replay tooling must join the axis across measurements, thresholds, pass booleans, anomaly references, and the cross-gate floor table without aliases.

## Validation Boundary

The JSON Schema fragment is authoritative for top-level field presence, field types, enum values, and M2 Pro hardware constants. The axis consistency rule is enforced by replay validation because it compares key sets across fields.

## JSON Fragment Authority Rule

The first fenced `json` block in this document is the only machine-readable schema fragment. Additional prose tables and migration notes may tighten validator behavior, but they must not introduce a second competing JSON Schema block.

## Replay-Ineligibility Checklist

An artifact is replay-ineligible if any predicate below is true:

1. `falsifier_id` does not exactly match a handbook row and fragment frontmatter.
2. `schema_version` differs from the current schema and lacks an explicit migration note.
3. `hardware_pin` differs from Jojo's M2 Pro 16 GB UMA floor.
4. `command` differs from the row command after removing `NOT IMPLEMENTED:`.
5. `commit_sha` is missing, short, non-hex, or not the producing repo state.
6. `fixture_id` cannot recover the exact input set, seed, or dataset/config version.
7. `timestamp_utc` is not UTC `Z` time or predates command completion.
8. Measurement, threshold, and pass-axis key sets differ.
9. Any required cross-gate axis floor is absent.
10. `overall_pass` is true while any required axis is false, missing, or replay-ineligible.
11. `fallback_tier` claims `Primary` for a fallback route artifact.
12. A pass-affecting anomaly is omitted or only described in freeform notes.

## Negative Examples Catalog

Invalid witness shapes are cataloged in [Artifact Negative Examples](ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md). Validator work must keep these examples failing unless a future schema migration explicitly rewrites the violated rule.

## Validator Harness Shape

The future validator contract is sketched in [Artifact Validator Shape](ARTIFACT_VALIDATOR_SHAPE_2026_05_18.md). That document is non-executable until a merge-phase or validator-implementation terminal owns the harness.

## Fallback Tier Semantics

`Primary` means the exact row command and threshold passed on Jojo's M2 Pro hardware floor. `Fallback` means the documented fallback route produced an acceptable artifact, but the primary row remains not fully passed unless its row threshold explicitly accepts that route. `Fail` means neither primary nor fallback evidence satisfies the contract.

## Cross-Gate Axis Floors

These are the minimum axis keys each F-* artifact must cover in `measurements`, `acceptance_thresholds`, and `pass_per_axis`. Artifacts may add more axes when the row needs them, but added axes must obey the same consistency rule.

| Falsifier | Minimum axis keys |
|---|---|
| `F-Eidos-ClosedCitation` | `citation_membership`, `fake_citation_rejection`, `empty_vault_deferral`, `source_trace_visible` |
| `F-VaultRecall-50` | `target_recall`, `distractor_suppression`, `candidate_count`, `trace_components`, `weak_evidence_behavior` |
| `F-PageGather-Baseline` | `median_bw_256mb`, `median_bw_512mb`, `median_bw_1gb`, `window_seconds` |
| `F-PageGather-Scatter` | `scatter_bw_256mb`, `scatter_bw_512mb`, `baseline_ratio`, `correctness_digest`, `window_seconds` |
| `F-UAS-CopyCount` | `tensor_copy_count`, `data_copy_bytes`, `metadata_copy_ledger`, `stack_label_coverage` |
| `F-ACS-AnchorLookup` | `round_trip_field_digest`, `invalid_theorem_rejection`, `projection_integrity` |
| `F-InterruptScore-CPU` | `equation_match`, `clamp_bounds`, `bucket_boundaries`, `p99_latency_us` |
| `F-PacketRouter1bit` | `p99_latency_us`, `reconstruction_digest`, `mask_class_breakdown`, `lane_balance_report` |
| `F-ControllerKernelPack` | `per_kernel_equivalence`, `fp32_max_diff`, `threadgroup_budget`, `unsupported_case_ledger` |
| `F-SemiseparableBlockScan` | `core_max_abs_diff`, `final_state_diff`, `chunk_size`, `ngroups`, `stretch_labeling` |
| `F-LocalRecallIsland` | `peak_memory_gb`, `passkey_recall`, `niah_single_1`, `depth_failure_labels` |
| `F-KV-Direct-Gate` | `average_d_kl_nats`, `peak_ram_gb`, `decode_tok_s`, `suite_wall_clock_min`, `spill_labeling` |
| `F-WBO-DriftLedger` | `finite_nonnegative_terms`, `envelope_bound`, `post_softmax_drift`, `missing_term_fail_closed` |
| `F-ULP-Oracle` | `max_ulp`, `comparable_points_over_2ulp`, `stress_case_classification`, `wall_clock_seconds` |
| `F-70B-Local-Cocktail-Lite` | `d_kl_nats`, `decode_tok_s`, `ttft_seconds`, `resident_memory_gb`, `bottleneck_identified` |

## T12 F-ULP Witness Correspondence

T12's F-ULP witness shape is the first specific instance of this general artifact schema. On this branch, the Rust substrate report is `UlpOracleReport` in `agent_core/src/research/eml/ulp_oracle.rs`; a future T12 `FulpWitness` artifact must map `max_ulp_error` to `measurements.max_ulp`, `samples_within_bar` plus total comparable samples to `measurements.comparable_points_over_2ulp`, stress taxonomy output to `measurements.stress_case_classification`, and run timing to `measurements.wall_clock_seconds`.

## JSON Schema Fragment

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.json",
  "title": "T23B Falsifier Artifact",
  "type": "object",
  "required": ["falsifier_id", "schema_version", "hardware_pin", "command", "commit_sha", "fixture_id", "timestamp_utc", "measurements", "acceptance_thresholds", "pass_per_axis", "overall_pass", "fallback_tier", "anomalies", "notes"],
  "properties": {
    "falsifier_id": {
      "type": "string",
      "pattern": "^F-[A-Za-z0-9][A-Za-z0-9-]*$",
      "enum": [
        "F-Eidos-ClosedCitation",
        "F-VaultRecall-50",
        "F-PageGather-Baseline",
        "F-PageGather-Scatter",
        "F-UAS-CopyCount",
        "F-ACS-AnchorLookup",
        "F-InterruptScore-CPU",
        "F-PacketRouter1bit",
        "F-ControllerKernelPack",
        "F-SemiseparableBlockScan",
        "F-LocalRecallIsland",
        "F-KV-Direct-Gate",
        "F-WBO-DriftLedger",
        "F-ULP-Oracle",
        "F-70B-Local-Cocktail-Lite"
      ]
    },
    "schema_version": {
      "type": "string",
      "const": "2026-05-18.2"
    },
    "hardware_pin": {
      "type": "object",
      "required": ["machine", "cpu", "gpu", "unified_memory_gb", "memory_bandwidth_gb_s"],
      "properties": {
        "machine": {
          "type": "string",
          "const": "M2 Pro 14-inch 2023"
        },
        "cpu": {
          "type": "string",
          "const": "12-core CPU"
        },
        "gpu": {
          "type": "string",
          "const": "19-core GPU"
        },
        "unified_memory_gb": {
          "type": "integer",
          "const": 16
        },
        "memory_bandwidth_gb_s": {
          "type": "integer",
          "const": 200
        }
      },
      "additionalProperties": false
    },
    "command": {
      "type": "string",
      "minLength": 1,
      "pattern": "^tools/falsifiers/[a-z0-9_]+\\.sh(?: [A-Za-z0-9._=:/,-]+)*$"
    },
    "commit_sha": {
      "type": "string",
      "pattern": "^[0-9a-f]{40}$"
    },
    "fixture_id": {
      "type": "string",
      "minLength": 1,
      "pattern": "^[a-z0-9][a-z0-9._-]*$"
    },
    "timestamp_utc": {
      "type": "string",
      "format": "date-time",
      "pattern": "^\\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\\d|3[01])T(?:[01]\\d|2[0-3]):[0-5]\\d:[0-5]\\d(?:\\.\\d+)?Z$"
    },
    "measurements": {
      "type": "object",
      "minProperties": 1,
      "propertyNames": {
        "pattern": "^[a-z][a-z0-9_]*$"
      },
      "patternProperties": {
        "^[a-z][a-z0-9_]*$": {
          "type": "object",
          "required": ["value", "unit"],
          "properties": {
            "value": {
              "type": ["number", "string", "boolean", "null"]
            },
            "unit": {
              "type": "string",
              "minLength": 1,
              "pattern": "^[A-Za-z0-9%./_-]+$"
            },
            "samples": {
              "type": "array",
              "minItems": 1,
              "oneOf": [
                { "items": { "type": "number" } },
                { "items": { "type": "string" } },
                { "items": { "type": "boolean" } }
              ]
            },
            "statistic": {
              "type": "string",
              "enum": ["raw", "min", "max", "mean", "median", "p50", "p95", "p99", "count", "digest", "classified"]
            },
            "raw_artifact": {
              "type": "string",
              "minLength": 1,
              "pattern": "^artifacts/falsifiers/(?!\\.\\.?/)(?!.*?/\\.\\.?(?:/|$))[A-Za-z0-9._/-]+$"
            }
          },
          "allOf": [
            {
              "if": {
                "properties": {
                  "statistic": { "const": "digest" }
                },
                "required": ["statistic"]
              },
              "then": {
                "properties": {
                  "value": {
                    "type": "string",
                    "pattern": "^sha256:[a-f0-9]{64}$"
                  },
                  "unit": { "const": "sha256" }
                }
              }
            }
          ],
          "additionalProperties": false
        }
      },
      "additionalProperties": false
    },
    "acceptance_thresholds": {
      "type": "object",
      "minProperties": 1,
      "propertyNames": {
        "pattern": "^[a-z][a-z0-9_]*$"
      },
      "patternProperties": {
        "^[a-z][a-z0-9_]*$": {
          "type": "object",
          "required": ["operator", "value", "unit"],
          "properties": {
            "operator": {
              "type": "string",
              "enum": ["<=", ">=", "==", "!=", "between", "contains", "present"]
            },
            "value": {
              "oneOf": [
                { "type": "number" },
                { "type": "string" },
                { "type": "boolean" },
                {
                  "type": "array",
                  "items": {
                    "type": ["number", "string", "boolean"]
                  }
                }
              ]
            },
            "unit": {
              "type": "string",
              "minLength": 1,
              "pattern": "^[A-Za-z0-9%./_-]+$"
            },
            "upstream_artifact": {
              "type": "string",
              "minLength": 1,
              "pattern": "^artifacts/falsifiers/(?!\\.\\.?/)(?!.*?/\\.\\.?(?:/|$))[A-Za-z0-9._/-]+$"
            },
            "upstream_axis": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_]*$"
            }
          },
          "allOf": [
            {
              "if": {
                "properties": {
                  "operator": { "enum": ["<=", ">="] }
                },
                "required": ["operator"]
              },
              "then": {
                "properties": {
                  "value": { "type": "number" }
                }
              }
            },
            {
              "if": {
                "properties": {
                  "operator": { "const": "between" }
                },
                "required": ["operator"]
              },
              "then": {
                "properties": {
                  "value": {
                    "type": "array",
                    "minItems": 2,
                    "maxItems": 2,
                    "items": { "type": "number" }
                  }
                }
              }
            },
            {
              "if": {
                "properties": {
                  "operator": { "const": "present" }
                },
                "required": ["operator"]
              },
              "then": {
                "properties": {
                  "value": { "const": true }
                }
              }
            },
            {
              "if": {
                "properties": {
                  "operator": { "const": "contains" }
                },
                "required": ["operator"]
              },
              "then": {
                "properties": {
                  "value": {
                    "type": ["string", "array"]
                  }
                }
              }
            },
            {
              "if": {
                "required": ["upstream_artifact"]
              },
              "then": {
                "required": ["upstream_axis"]
              }
            },
            {
              "if": {
                "required": ["upstream_axis"]
              },
              "then": {
                "required": ["upstream_artifact"]
              }
            }
          ],
          "additionalProperties": false
        }
      },
      "additionalProperties": false
    },
    "pass_per_axis": {
      "type": "object",
      "minProperties": 1,
      "propertyNames": {
        "pattern": "^[a-z][a-z0-9_]*$"
      },
      "patternProperties": {
        "^[a-z][a-z0-9_]*$": {
          "type": "boolean"
        }
      },
      "additionalProperties": false
    },
    "overall_pass": {
      "type": "boolean"
    },
    "fallback_tier": {
      "type": "string",
      "enum": ["Primary", "Fallback", "Fail"]
    },
    "anomalies": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["kind", "description", "affects_pass"],
        "properties": {
          "kind": {
            "type": "string",
            "enum": ["rig", "input", "output", "timing", "memory", "thermal", "power", "disk", "permission", "fallback", "unsupported_case", "other"]
          },
          "axis": {
            "type": "string",
            "pattern": "^[a-z][a-z0-9_]*$"
          },
          "description": {
            "type": "string",
            "minLength": 1
          },
          "affects_pass": {
            "type": "boolean"
          },
          "severity": {
            "type": "string",
            "enum": ["info", "warning", "blocking"]
          },
          "fallback_tier": {
            "type": "string",
            "enum": ["Fallback", "Fail"]
          }
        },
        "allOf": [
          {
            "if": {
              "properties": {
                "kind": { "const": "fallback" }
              },
              "required": ["kind"]
            },
            "then": {
              "required": ["fallback_tier"]
            }
          },
          {
            "if": {
              "properties": {
                "severity": { "const": "blocking" }
              },
              "required": ["severity"]
            },
            "then": {
              "properties": {
                "affects_pass": { "const": true }
              }
            }
          }
        ],
        "additionalProperties": false
      }
    },
    "notes": {
      "type": "string",
      "minLength": 1,
      "not": {
        "pattern": "```|^\\s*\\{"
      }
    }
  },
  "additionalProperties": false
}
```
