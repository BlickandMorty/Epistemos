---
state: t23b-falsifier-artifact-negative-examples
created_on: 2026-05-18
schema_version: 2026-05-18.2
invalid_example_count: 266
---

# Artifact Negative Examples - 2026-05-18

This catalog preserves invalid witness shapes so future validators reject them deliberately instead of accepting plausible-looking logs.

`invalid_example_count` must equal the number of `## N*` sections in this file. Any new negative example must update that frontmatter value and the handbook validator-readiness count in the same commit batch.

## N1 - Short SHA and Offset Timestamp

Violates: [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule), [Timestamp Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#timestamp-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "f7796dad2",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T09:30:00-05:00",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `commit_sha` is not a full 40-character lowercase hex SHA, and `timestamp_utc` uses a local offset instead of UTC `Z` time.

## N2 - Alias Falsifier ID

Violates: [Falsifier ID Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#falsifier-id-rule), [Cross-Gate Axis Floors](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#cross-gate-axis-floors), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T14:30:00Z",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `F-ULP` is a prose alias, not the exact `F-ULP-Oracle` row identifier, and the artifact omits the full `F-ULP-Oracle` axis floor.

## N3 - Hardware Substitution

Violates: [Hardware Pin Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#hardware-pin-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-PageGather-Baseline",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Max 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "30-core GPU",
    "unified_memory_gb": 32,
    "memory_bandwidth_gb_s": 400
  },
  "command": "tools/falsifiers/f_page_gather_baseline.sh",
  "commit_sha": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "fixture_id": "page-gather-baseline-v1",
  "timestamp_utc": "2026-05-18T15:00:00Z",
  "measurements": {
    "median_bw_256mb": {
      "value": 120,
      "unit": "GB/s",
      "statistic": "median"
    }
  },
  "acceptance_thresholds": {
    "median_bw_256mb": {
      "operator": "present",
      "value": true,
      "unit": "GB/s"
    }
  },
  "pass_per_axis": {
    "median_bw_256mb": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: the artifact substitutes an M2 Max hardware floor for Jojo's pinned M2 Pro 16 GB UMA rig.

## N4 - Fallback Route Claimed as Primary

Violates: [Fallback Tier Semantics](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#fallback-tier-semantics), [Anomaly Kind Requirements](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomaly-kind-requirements), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-KV-Direct-Gate",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_kv_direct_gate.sh",
  "commit_sha": "cccccccccccccccccccccccccccccccccccccccc",
  "fixture_id": "kv-direct-soft-eviction-v1",
  "timestamp_utc": "2026-05-18T15:30:00Z",
  "measurements": {
    "average_d_kl_nats": { "value": 0.03, "unit": "nats", "statistic": "mean" },
    "peak_ram_gb": { "value": 11.8, "unit": "GB", "statistic": "max" },
    "decode_tok_s": { "value": 12.1, "unit": "tok/s", "statistic": "mean" },
    "suite_wall_clock_min": { "value": 24.0, "unit": "min" },
    "spill_labeling": { "value": true, "unit": "boolean" }
  },
  "acceptance_thresholds": {
    "average_d_kl_nats": { "operator": "<=", "value": 0.05, "unit": "nats" },
    "peak_ram_gb": { "operator": "<=", "value": 13, "unit": "GB" },
    "decode_tok_s": { "operator": ">=", "value": 10, "unit": "tok/s" },
    "suite_wall_clock_min": { "operator": "<=", "value": 30, "unit": "min" },
    "spill_labeling": { "operator": "==", "value": true, "unit": "boolean" }
  },
  "pass_per_axis": {
    "average_d_kl_nats": true,
    "peak_ram_gb": true,
    "decode_tok_s": true,
    "suite_wall_clock_min": true,
    "spill_labeling": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [
    {
      "kind": "fallback",
      "description": "soft eviction route used; resulting tier should be Fallback",
      "affects_pass": true
    }
  ],
  "notes": "fallback route passed"
}
```

Rejection reason: a fallback-route witness cannot promote itself as `Primary`.

## N5 - Axis Key Drift

Violates: [Axis Consistency Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#axis-consistency-rule), [Cross-Gate Axis Floors](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#cross-gate-axis-floors), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "dddddddddddddddddddddddddddddddddddddddd",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T16:00:00Z",
  "measurements": {
    "maxULP": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `maxULP` is not a schema-valid axis key and does not match the required `max_ulp` floor.

## N6 - Pre-Adopted Hardware Pin Shape

Violates: [Hardware Pin Typed Sub-Schema Target](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#hardware-pin-typed-sub-schema-target), [Hardware Pin Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#hardware-pin-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-PageGather-Baseline",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "model_identifier": "Mac14,9",
    "chip": "M2 Pro",
    "cpu_cores": 12,
    "gpu_cores": 19,
    "memory_gb": 16,
    "uma": true,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_baseline.sh",
  "commit_sha": "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
  "fixture_id": "page-gather-baseline-v1",
  "timestamp_utc": "2026-05-18T16:30:00Z",
  "measurements": {
    "median_bw_256mb": { "value": 66, "unit": "GB/s", "statistic": "median" }
  },
  "acceptance_thresholds": {
    "median_bw_256mb": { "operator": "present", "value": true, "unit": "GB/s" }
  },
  "pass_per_axis": {
    "median_bw_256mb": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: typed hardware-pin fields are reserved for the next schema revision and are invalid under `2026-05-18.2`.

## N7 - Pass-Affecting Anomaly Hidden in Notes

Violates: [Anomalies Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomalies-rule), [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-PageGather-Baseline",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_baseline.sh",
  "commit_sha": "ffffffffffffffffffffffffffffffffffffffff",
  "fixture_id": "page-gather-baseline-v1",
  "timestamp_utc": "2026-05-18T17:00:00Z",
  "measurements": {
    "median_bw_256mb": { "value": 65, "unit": "GB/s", "statistic": "median" },
    "median_bw_512mb": { "value": 64, "unit": "GB/s", "statistic": "median" },
    "median_bw_1gb": { "value": 63, "unit": "GB/s", "statistic": "median" },
    "window_seconds": { "value": 1.0, "unit": "s" }
  },
  "acceptance_thresholds": {
    "median_bw_256mb": { "operator": "present", "value": true, "unit": "GB/s" },
    "median_bw_512mb": { "operator": "present", "value": true, "unit": "GB/s" },
    "median_bw_1gb": { "operator": "present", "value": true, "unit": "GB/s" },
    "window_seconds": { "operator": ">=", "value": 1.0, "unit": "s" }
  },
  "pass_per_axis": {
    "median_bw_256mb": true,
    "median_bw_512mb": true,
    "median_bw_1gb": true,
    "window_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "Disk filled during raw JSONL write; summary numbers retained."
}
```

Rejection reason: a disk write anomaly that affects raw artifact completeness must appear in `anomalies`, not only in `notes`.

## N8 - Wrapper Command

Violates: [Command Path Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#command-path-rule), [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "bash tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "1111111111111111111111111111111111111111",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T17:30:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: the command is a shell wrapper, not the exact canonical row command path.

## N9 - Unsupported Falsifier ID

Violates: [Falsifier ID Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#falsifier-id-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle-Experimental",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "2222222222222222222222222222222222222222",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T17:35:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: the falsifier ID is not one of the 15 enumerated handbook row identifiers.

## N10 - Extra Top-Level Field

Violates: [Validation Boundary](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#validation-boundary) and the JSON Schema fragment's `additionalProperties: false` rule.

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "3333333333333333333333333333333333333333",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T17:40:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none",
  "validator_hint": "accept because this run looks fine"
}
```

Rejection reason: top-level fields outside the canonical schema are not accepted as witness metadata.

## N11 - Vague Other Anomaly

Violates: [Anomaly Kind Requirements](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomaly-kind-requirements) and [Anomalies Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomalies-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "4444444444444444444444444444444444444444",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T17:45:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [
    {
      "kind": "other",
      "description": "weird run",
      "affects_pass": false
    }
  ],
  "notes": "none"
}
```

Rejection reason: `other` anomalies must name the specific unmapped failure class, not a generic caveat.

## N12 - Missing Required Axis Floor

Violates: [Cross-Gate Axis Floors](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#cross-gate-axis-floors), [Axis Consistency Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#axis-consistency-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "5555555555555555555555555555555555555555",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T17:50:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: F-ULP-Oracle also requires `comparable_points_over_2ulp`, `stress_case_classification`, and `wall_clock_seconds`.

## N13 - Fallback Anomaly Without Tier

Violates: [Anomaly Kind Requirements](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomaly-kind-requirements), [Fallback Tier Semantics](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#fallback-tier-semantics), and the JSON Schema fragment's fallback anomaly conditional.

```json
{
  "falsifier_id": "F-LocalRecallIsland",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_local_recall_island.sh",
  "commit_sha": "6666666666666666666666666666666666666666",
  "fixture_id": "local-recall-island-passkey-v1",
  "timestamp_utc": "2026-05-18T17:55:00Z",
  "measurements": {
    "peak_memory_gb": { "value": 4.2, "unit": "GB" },
    "passkey_recall": { "value": 0.96, "unit": "ratio" },
    "niah_single_1": { "value": 0.95, "unit": "ratio" },
    "depth_failure_labels": { "value": "none", "unit": "labels" }
  },
  "acceptance_thresholds": {
    "peak_memory_gb": { "operator": "<=", "value": 4.5, "unit": "GB" },
    "passkey_recall": { "operator": ">=", "value": 0.95, "unit": "ratio" },
    "niah_single_1": { "operator": ">=", "value": 0.95, "unit": "ratio" },
    "depth_failure_labels": { "operator": "present", "value": true, "unit": "ledger" }
  },
  "pass_per_axis": {
    "peak_memory_gb": true,
    "passkey_recall": true,
    "niah_single_1": true,
    "depth_failure_labels": true
  },
  "overall_pass": true,
  "fallback_tier": "Fallback",
  "anomalies": [
    {
      "kind": "fallback",
      "description": "Granite H-Micro failed; Granite H-Tiny route used.",
      "affects_pass": true
    }
  ],
  "notes": "fallback route used"
}
```

Rejection reason: a `fallback` anomaly must include the anomaly object's resulting `fallback_tier`.

## N14 - Leap-Second Timestamp

Violates: [Timestamp Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#timestamp-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "7777777777777777777777777777777777777777",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T17:59:60Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: second value `60` is outside the bounded RFC 3339 UTC pattern.

## N15 - Cross-Row Command Mismatch

Violates: [Command Path Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#command-path-rule), [Command Path Map](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#command-path-map), and [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_kv_direct_gate.sh",
  "commit_sha": "8888888888888888888888888888888888888888",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T18:00:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: F-ULP-Oracle artifacts must use `tools/falsifiers/f_ulp_oracle.sh`, not another row's script path.

## N16 - Prose Fixture Label

Violates: [Fixture Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#fixture-identity-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "9999999999999999999999999999999999999999",
  "fixture_id": "ULP oracle latest grid",
  "timestamp_utc": "2026-05-18T18:05:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `fixture_id` must be a lowercase replay slug, not a prose label.

## N17 - String Numeric Threshold

Violates: [Threshold Operator Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#threshold-operator-rule) and [Acceptance Thresholds Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#acceptance-thresholds-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T18:10:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": "2", "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `<=` thresholds must carry a numeric value, not a numeric-looking string.

## N18 - Temp Raw Artifact Path

Violates: [Artifact Reference Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#artifact-reference-rule) and [Measurements Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurements-rule).

```json
{
  "falsifier_id": "F-PageGather-Baseline",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_baseline.sh",
  "commit_sha": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "fixture_id": "page-gather-baseline-v1",
  "timestamp_utc": "2026-05-18T18:15:00Z",
  "measurements": {
    "median_bw_256mb": { "value": 67.1, "unit": "GB/s", "raw_artifact": "/tmp/page_gather/raw.jsonl" },
    "median_bw_512mb": { "value": 66.8, "unit": "GB/s" },
    "median_bw_1gb": { "value": 65.9, "unit": "GB/s" },
    "window_seconds": { "value": 1.0, "unit": "s" }
  },
  "acceptance_thresholds": {
    "median_bw_256mb": { "operator": ">=", "value": 60, "unit": "GB/s" },
    "median_bw_512mb": { "operator": ">=", "value": 60, "unit": "GB/s" },
    "median_bw_1gb": { "operator": ">=", "value": 60, "unit": "GB/s" },
    "window_seconds": { "operator": ">=", "value": 1.0, "unit": "s" }
  },
  "pass_per_axis": {
    "median_bw_256mb": true,
    "median_bw_512mb": true,
    "median_bw_1gb": true,
    "window_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `raw_artifact` points to `/tmp` instead of a replayable `artifacts/falsifiers/` path.

## N19 - Shell Metacharacter Command

Violates: [Command Argument Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#command-argument-rule), [Command Path Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#command-path-rule), and [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh --fixture=ulp-oracle-loggrid-v1 && true",
  "commit_sha": "cccccccccccccccccccccccccccccccccccccccc",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T18:20:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: shell metacharacters make the replay command more than the canonical falsifier invocation.

## N20 - String Measurement Under Numeric Threshold

Violates: [Measurement Threshold Compatibility Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurement-threshold-compatibility-rule) and [Measurements Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurements-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "dddddddddddddddddddddddddddddddddddddddd",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T18:25:00Z",
  "measurements": {
    "max_ulp": { "value": "2", "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: numeric threshold operators require numeric measurement values, not string coercion.

## N21 - Silent Old Schema Version

Violates: [Schema Version Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-version-rule), [Schema Migration Table](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-migration-table), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.1",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T18:30:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: old schema artifacts need an explicit migration note and cannot satisfy current pass claims silently.

## N22 - Embedded Artifact Path

Violates: [Expected Artifact Root Map](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#expected-artifact-root-map), [Validation Boundary](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#validation-boundary), and the JSON Schema fragment's `additionalProperties: false` rule.

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "ffffffffffffffffffffffffffffffffffffffff",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T18:35:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none",
  "artifact_path": "artifacts/falsifiers/ulp_oracle/result.json"
}
```

Rejection reason: artifact path is validator input, not a permitted JSON witness field.

## N23 - Wrong Artifact Root

Candidate path: `artifacts/falsifiers/kv_direct_gate/result.json`

Violates: [Expected Artifact Root Map](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#expected-artifact-root-map) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "1234567890abcdef1234567890abcdef12345678",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T18:40:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: F-ULP-Oracle artifacts must live under `artifacts/falsifiers/ulp_oracle/`.

## N24 - Anomaly References Unknown Axis

Violates: [Anomaly Axis Reference Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomaly-axis-reference-rule) and [Anomalies Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomalies-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "abcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T18:45:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [
    {
      "kind": "timing",
      "axis": "wall_clock_seconds",
      "description": "wall-clock timer restarted during run",
      "affects_pass": false
    }
  ],
  "notes": "none"
}
```

Rejection reason: the anomaly references `wall_clock_seconds`, but that axis is absent from the artifact maps.

## N25 - Primary Pass With Pass-Affecting Anomaly

Violates: [Pass-Affecting Anomaly Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#pass-affecting-anomaly-rule), [Overall Pass Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#overall-pass-rule), and [Anomalies Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomalies-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "fedcbafedcbafedcbafedcbafedcbafedcbafedc",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T18:50:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [
    {
      "kind": "disk",
      "description": "raw stress-case output failed to flush to artifacts/falsifiers/ulp_oracle/raw.jsonl",
      "affects_pass": true
    }
  ],
  "notes": "raw stress-case artifact missing"
}
```

Rejection reason: a pass-affecting anomaly cannot coexist with `fallback_tier: Primary` and `overall_pass: true`.

## N26 - Notes Override Failed Axis

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule), [Pass Per Axis Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#pass-per-axis-rule), and [Overall Pass Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#overall-pass-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T18:55:00Z",
  "measurements": {
    "max_ulp": { "value": 4, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": false
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "treat as pass because only two points exceeded the bar"
}
```

Rejection reason: notes cannot override a failed axis or make `overall_pass` true.

## N27 - Incomplete Migration Note

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Schema Version Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-version-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.1",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "76543210fedcba9876543210fedcba9876543210",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T19:00:00Z",
  "measurements": {
    "max_ulp": { "value": 2, "unit": "ulp" }
  },
  "acceptance_thresholds": {
    "max_ulp": { "operator": "<=", "value": 2, "unit": "ulp" }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "from_schema=2026-05-18.1 to_schema=2026-05-18.2 reviewer=jojo"
}
```

Rejection reason: migration notes must include all seven required migration fields, including artifact path, command, field mapping, and reviewed timestamp.

## N28 - Aggregate Without Replay Material

Violates: [Aggregate Statistic Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#aggregate-statistic-rule) and [Measurements Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurements-rule).

```json
{
  "falsifier_id": "F-PageGather-Baseline",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_baseline.sh",
  "commit_sha": "89abcdef0123456789abcdef0123456789abcdef",
  "fixture_id": "page-gather-baseline-v1",
  "timestamp_utc": "2026-05-18T19:05:00Z",
  "measurements": {
    "median_bw_256mb": { "value": 67.1, "unit": "GB/s", "statistic": "median" },
    "median_bw_512mb": { "value": 66.8, "unit": "GB/s", "statistic": "median" },
    "median_bw_1gb": { "value": 65.9, "unit": "GB/s", "statistic": "median" },
    "window_seconds": { "value": 1.0, "unit": "s" }
  },
  "acceptance_thresholds": {
    "median_bw_256mb": { "operator": ">=", "value": 60, "unit": "GB/s" },
    "median_bw_512mb": { "operator": ">=", "value": 60, "unit": "GB/s" },
    "median_bw_1gb": { "operator": ">=", "value": 60, "unit": "GB/s" },
    "window_seconds": { "operator": ">=", "value": 1.0, "unit": "s" }
  },
  "pass_per_axis": {
    "median_bw_256mb": true,
    "median_bw_512mb": true,
    "median_bw_1gb": true,
    "window_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: aggregate `median` measurements need `samples` or a committed `raw_artifact`.

## N29 - Present Threshold Is False

Violates: [Threshold Operator Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#threshold-operator-rule) and [Acceptance Thresholds Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#acceptance-thresholds-rule).

```json
{
  "falsifier_id": "F-ControllerKernelPack",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_controller_kernel_pack.sh",
  "commit_sha": "00112233445566778899aabbccddeeff00112233",
  "fixture_id": "controller-kernel-pack-v1",
  "timestamp_utc": "2026-05-18T19:10:00Z",
  "measurements": {
    "unsupported_case_ledger": { "value": "empty reductions classified", "unit": "ledger" }
  },
  "acceptance_thresholds": {
    "unsupported_case_ledger": { "operator": "present", "value": false, "unit": "ledger" }
  },
  "pass_per_axis": {
    "unsupported_case_ledger": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `present` thresholds require `value: true`, not false.

## N30 - Contains Threshold Uses Boolean

Violates: [Threshold Operator Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#threshold-operator-rule) and [Acceptance Thresholds Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#acceptance-thresholds-rule).

```json
{
  "falsifier_id": "F-Eidos-ClosedCitation",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_eidos_closed_citation.sh",
  "commit_sha": "11223344556677889900aabbccddeeff11223344",
  "fixture_id": "eidos-closed-citation-v1",
  "timestamp_utc": "2026-05-18T19:15:00Z",
  "measurements": {
    "citation_membership": { "value": "all citations inside packet", "unit": "set" }
  },
  "acceptance_thresholds": {
    "citation_membership": { "operator": "contains", "value": true, "unit": "set" }
  },
  "pass_per_axis": {
    "citation_membership": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `contains` thresholds must name a string or array membership target, not a boolean.

## N31 - Measurement Threshold Unit Mismatch

Violates: [Unit Consistency Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#unit-consistency-rule) and [Acceptance Thresholds Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#acceptance-thresholds-rule).

```json
{
  "falsifier_id": "F-KV-Direct-Gate",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_kv_direct_gate.sh",
  "commit_sha": "223344556677889900aabbccddeeff0011223344",
  "fixture_id": "kv-direct-gate-qwen3-8b-v1",
  "timestamp_utc": "2026-05-18T19:20:00Z",
  "measurements": {
    "peak_ram_gb": { "value": 12.5, "unit": "GB" }
  },
  "acceptance_thresholds": {
    "peak_ram_gb": { "operator": "<=", "value": 13, "unit": "GiB" }
  },
  "pass_per_axis": {
    "peak_ram_gb": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: measurement and threshold units must match exactly for the same axis.

## N32 - Freeform Unit String

Violates: [Unit Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#unit-token-rule) and [Measurements Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurements-rule).

```json
{
  "falsifier_id": "F-PageGather-Baseline",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_baseline.sh",
  "commit_sha": "3344556677889900aabbccddeeff001122334455",
  "fixture_id": "page-gather-baseline-v1",
  "timestamp_utc": "2026-05-18T19:25:00Z",
  "measurements": {
    "median_bw_256mb": { "value": 67.1, "unit": "gigabytes per second" }
  },
  "acceptance_thresholds": {
    "median_bw_256mb": { "operator": ">=", "value": 60, "unit": "gigabytes per second" }
  },
  "pass_per_axis": {
    "median_bw_256mb": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: units must be compact ASCII tokens without spaces.

## N33 - Null Measurement Without Classification

Violates: [Classified Unsupported Value Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#classified-unsupported-value-rule) and [Measurements Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurements-rule).

```json
{
  "falsifier_id": "F-ControllerKernelPack",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_controller_kernel_pack.sh",
  "commit_sha": "44556677889900aabbccddeeff00112233445566",
  "fixture_id": "controller-kernel-pack-v1",
  "timestamp_utc": "2026-05-18T19:30:00Z",
  "measurements": {
    "fp32_max_diff": { "value": null, "unit": "abs" }
  },
  "acceptance_thresholds": {
    "fp32_max_diff": { "operator": "<=", "value": 0.001, "unit": "abs" }
  },
  "pass_per_axis": {
    "fp32_max_diff": false
  },
  "overall_pass": false,
  "fallback_tier": "Fail",
  "anomalies": [],
  "notes": "kernel diff was not measured"
}
```

Rejection reason: null measurement values require `statistic: classified` plus an `unsupported_case` anomaly for that axis.

## N34 - Half-Linked Upstream Threshold

Violates: [Upstream Threshold Pair Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#upstream-threshold-pair-rule) and [Acceptance Thresholds Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#acceptance-thresholds-rule).

```json
{
  "falsifier_id": "F-PageGather-Scatter",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_scatter.sh",
  "commit_sha": "556677889900aabbccddeeff0011223344556677",
  "fixture_id": "page-gather-scatter-v1",
  "timestamp_utc": "2026-05-18T19:35:00Z",
  "measurements": {
    "baseline_ratio": { "value": 0.72, "unit": "ratio" }
  },
  "acceptance_thresholds": {
    "baseline_ratio": {
      "operator": ">=",
      "value": 0.70,
      "unit": "ratio",
      "upstream_artifact": "artifacts/falsifiers/page_gather/baseline/falsifier_calibration.toml"
    }
  },
  "pass_per_axis": {
    "baseline_ratio": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: upstream thresholds must name both `upstream_artifact` and `upstream_axis`.

## N35 - CamelCase Axis Key

Violates: [Axis Name Grammar Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#axis-name-grammar-rule) and [Axis Consistency Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#axis-consistency-rule).

```json
{
  "falsifier_id": "F-KV-Direct",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_kv_direct.sh",
  "commit_sha": "6677889900aabbccddeeff001122334455667788",
  "fixture_id": "kv-direct-v1",
  "timestamp_utc": "2026-05-18T19:40:00Z",
  "measurements": {
    "tokensPerSecond": { "value": 44.8, "unit": "tokens/s" }
  },
  "acceptance_thresholds": {
    "tokensPerSecond": { "operator": ">=", "value": 40.0, "unit": "tokens/s" }
  },
  "pass_per_axis": {
    "tokensPerSecond": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "axis name copied from a dashboard label"
}
```

Rejection reason: axis keys must match `^[a-z][a-z0-9_]*$`; CamelCase names are not replay-stable identifiers.

## N36 - Empty Aggregate Samples

Violates: [Aggregate Statistic Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#aggregate-statistic-rule) and [Measurements Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurements-rule).

```json
{
  "falsifier_id": "F-VaultRecall-50",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_vault_recall_50.sh",
  "commit_sha": "77889900aabbccddeeff00112233445566778899",
  "fixture_id": "vault-recall-50-v1",
  "timestamp_utc": "2026-05-18T19:45:00Z",
  "measurements": {
    "recall_at_50": {
      "value": 0.84,
      "unit": "ratio",
      "statistic": "p95",
      "samples": []
    }
  },
  "acceptance_thresholds": {
    "recall_at_50": { "operator": ">=", "value": 0.80, "unit": "ratio" }
  },
  "pass_per_axis": {
    "recall_at_50": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "aggregate kept only the percentile value"
}
```

Rejection reason: aggregate statistics require nonempty `samples` or a `raw_artifact` reference.

## N37 - Bare Digest Measurement

Violates: [Digest Measurement Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#digest-measurement-rule) and [Measurements Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurements-rule).

```json
{
  "falsifier_id": "F-Artifact-Completeness",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_artifact_completeness.sh",
  "commit_sha": "889900aabbccddeeff0011223344556677889900",
  "fixture_id": "artifact-completeness-v1",
  "timestamp_utc": "2026-05-18T19:50:00Z",
  "measurements": {
    "artifact_digest": {
      "value": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
      "unit": "hex",
      "statistic": "digest"
    }
  },
  "acceptance_thresholds": {
    "artifact_digest": { "operator": "present", "value": true, "unit": "sha256" }
  },
  "pass_per_axis": {
    "artifact_digest": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "digest copied without algorithm prefix"
}
```

Rejection reason: digest measurements must use `sha256:` plus lowercase hex and `unit: sha256`.

## N38 - Freeform Anomaly Severity

Violates: [Anomalies Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomalies-rule).

```json
{
  "falsifier_id": "F-PageGather-Baseline",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_baseline.sh",
  "commit_sha": "9900aabbccddeeff0011223344556677889900aa",
  "fixture_id": "page-gather-baseline-v1",
  "timestamp_utc": "2026-05-18T19:55:00Z",
  "measurements": {
    "bandwidth_gb_s": { "value": 205.0, "unit": "GB/s" }
  },
  "acceptance_thresholds": {
    "bandwidth_gb_s": { "operator": ">=", "value": 190.0, "unit": "GB/s" }
  },
  "pass_per_axis": {
    "bandwidth_gb_s": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [
    {
      "kind": "timing",
      "axis": "bandwidth_gb_s",
      "description": "one warmup run jittered before the measured window",
      "affects_pass": false,
      "severity": "critical"
    }
  ],
  "notes": "severity copied from an incident template"
}
```

Rejection reason: anomaly severity must be `info`, `warning`, or `blocking`, not a freeform label.

## N39 - Blocking Anomaly Marked Nonaffecting

Violates: [Anomalies Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomalies-rule) and [Pass-Affecting Anomaly Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#pass-affecting-anomaly-rule).

```json
{
  "falsifier_id": "F-PageGather-Scatter",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_scatter.sh",
  "commit_sha": "aabbccddeeff0011223344556677889900aabbcc",
  "fixture_id": "page-gather-scatter-v1",
  "timestamp_utc": "2026-05-18T20:00:00Z",
  "measurements": {
    "baseline_ratio": { "value": 0.76, "unit": "ratio" }
  },
  "acceptance_thresholds": {
    "baseline_ratio": {
      "operator": ">=",
      "value": 0.70,
      "unit": "ratio",
      "upstream_artifact": "artifacts/falsifiers/page_gather/baseline/falsifier_calibration.toml",
      "upstream_axis": "bandwidth_gb_s"
    }
  },
  "pass_per_axis": {
    "baseline_ratio": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [
    {
      "kind": "memory",
      "axis": "baseline_ratio",
      "description": "allocation pressure invalidated the scatter window",
      "affects_pass": false,
      "severity": "blocking"
    }
  ],
  "notes": "blocking condition was marked informational"
}
```

Rejection reason: `severity: blocking` must set `affects_pass: true` and cannot remain a primary pass.

## N40 - Traversing Raw Artifact Path

Violates: [Artifact Reference Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#artifact-reference-rule) and [Aggregate Statistic Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#aggregate-statistic-rule).

```json
{
  "falsifier_id": "F-VaultRecall-50",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_vault_recall_50.sh",
  "commit_sha": "bbccddeeff0011223344556677889900aabbccdd",
  "fixture_id": "vault-recall-50-v1",
  "timestamp_utc": "2026-05-18T20:05:00Z",
  "measurements": {
    "recall_at_50": {
      "value": 0.86,
      "unit": "ratio",
      "statistic": "mean",
      "raw_artifact": "artifacts/falsifiers/../tmp/vault_recall_samples.json"
    }
  },
  "acceptance_thresholds": {
    "recall_at_50": { "operator": ">=", "value": 0.80, "unit": "ratio" }
  },
  "pass_per_axis": {
    "recall_at_50": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "raw samples live outside the mapped artifact root"
}
```

Rejection reason: artifact references must remain under `artifacts/falsifiers/` without `.` or `..` segments.

## N41 - Notes Carry Hidden JSON

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-KV-Direct",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_kv_direct.sh",
  "commit_sha": "ccddeeff0011223344556677889900aabbccddee",
  "fixture_id": "kv-direct-v1",
  "timestamp_utc": "2026-05-18T20:10:00Z",
  "measurements": {
    "tokens_per_second": { "value": 46.0, "unit": "tokens/s" }
  },
  "acceptance_thresholds": {
    "tokens_per_second": { "operator": ">=", "value": 40.0, "unit": "tokens/s" }
  },
  "pass_per_axis": {
    "tokens_per_second": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "{\"hidden_threshold\":\"tokens_per_second >= 35\"}"
}
```

Rejection reason: notes cannot begin with an object payload or carry hidden structured thresholds.

## N42 - Missing Notes Inspection Token

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-PageGather-Baseline",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_baseline.sh",
  "commit_sha": "ddeeff0011223344556677889900aabbccddeeff",
  "fixture_id": "page-gather-baseline-v1",
  "timestamp_utc": "2026-05-18T20:15:00Z",
  "measurements": {
    "bandwidth_gb_s": { "value": 203.0, "unit": "GB/s" }
  },
  "acceptance_thresholds": {
    "bandwidth_gb_s": { "operator": ">=", "value": 190.0, "unit": "GB/s" }
  },
  "pass_per_axis": {
    "bandwidth_gb_s": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "warmup jitter observed but not pass-affecting"
}
```

Rejection reason: non-`none` notes must include `anomaly_inspection=complete`.

## N43 - Mixed-Type Sample Array

Violates: [Aggregate Statistic Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#aggregate-statistic-rule) and [Measurements Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurements-rule).

```json
{
  "falsifier_id": "F-VaultRecall-50",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_vault_recall_50.sh",
  "commit_sha": "eeff0011223344556677889900aabbccddeeff00",
  "fixture_id": "vault-recall-50-v1",
  "timestamp_utc": "2026-05-18T20:20:00Z",
  "measurements": {
    "recall_at_50": {
      "value": 0.82,
      "unit": "ratio",
      "statistic": "mean",
      "samples": [0.80, "0.84", 0.82]
    }
  },
  "acceptance_thresholds": {
    "recall_at_50": { "operator": ">=", "value": 0.80, "unit": "ratio" }
  },
  "pass_per_axis": {
    "recall_at_50": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete"
}
```

Rejection reason: `samples` must use one scalar JSON type across every entry.

## N44 - Noncanonical Witness Filename

Violates: [Expected Artifact Root Map](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#expected-artifact-root-map).

Validator input path: `artifacts/falsifiers/f_eidos_closed_citation/summary.json`

```json
{
  "falsifier_id": "F-Eidos-ClosedCitation",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_eidos_closed_citation.sh",
  "commit_sha": "ff0011223344556677889900aabbccddeeff0011",
  "fixture_id": "eidos-closed-citation-v1",
  "timestamp_utc": "2026-05-18T20:25:00Z",
  "measurements": {
    "citation_membership": { "value": true, "unit": "bool" }
  },
  "acceptance_thresholds": {
    "citation_membership": { "operator": "==", "value": true, "unit": "bool" }
  },
  "pass_per_axis": {
    "citation_membership": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete"
}
```

Rejection reason: canonical witness files must be named `result.json` or `result.jsonl`.

## N45 - JSONL Witness On Object Gate

Violates: [Expected Artifact Root Map](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#expected-artifact-root-map).

Validator input path: `artifacts/falsifiers/f_eidos_closed_citation/result.jsonl`

```json
{
  "falsifier_id": "F-Eidos-ClosedCitation",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_eidos_closed_citation.sh",
  "commit_sha": "0011223344556677889900aabbccddeeff001122",
  "fixture_id": "eidos-closed-citation-v1",
  "timestamp_utc": "2026-05-18T20:30:00Z",
  "measurements": {
    "citation_membership": { "value": true, "unit": "bool" }
  },
  "acceptance_thresholds": {
    "citation_membership": { "operator": "==", "value": true, "unit": "bool" }
  },
  "pass_per_axis": {
    "citation_membership": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete"
}
```

Rejection reason: `result.jsonl` is reserved for `F-WBO-DriftLedger`; this gate must use `result.json`.

## N46 - Malformed JSONL Witness Rows

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"axis":"pre_softmax_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":2,"axis":"post_softmax_bound","measurement":{"value":0.01,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.025,"unit":"nats"},"pass":true,"anomalies":[]}
```

Rejection reason: JSONL row indices must be zero-based and contiguous; row `1` is missing.

## N47 - JSONL Row Missing Prompt Identity

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"axis":"pre_softmax_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
```

Rejection reason: every JSONL drift row must include `prompt_id`.

## N48 - JSONL Row Missing Token Identity

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","axis":"pre_softmax_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
```

Rejection reason: every JSONL drift row must include `token_index`.

## N49 - JSONL Row Bad Identity Tokens

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"WBO Fixture 0001","token_index":-1,"axis":"pre_softmax_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
```

Rejection reason: `prompt_id` must be schema-safe and `token_index` must be non-negative.

## N50 - JSONL Row Undeclared Axis

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule) and [Cross-Gate Axis Floors](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#cross-gate-axis-floors).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"mystery_drift","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
```

Rejection reason: JSONL row axes must match declared WBO floor axes or explicit manifest-added axes.

## N51 - JSONL Anomaly Axis Mismatch

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule) and [Anomaly Axis Reference Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomaly-axis-reference-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"finite_nonnegative_terms","measurement":{"value":true,"unit":"bool"},"acceptance_threshold":{"operator":"==","value":true,"unit":"bool"},"pass":false,"anomalies":[{"kind":"output","axis":"envelope_bound","description":"finite term ledger row went negative","affects_pass":true,"severity":"blocking"}]}
```

Rejection reason: a JSONL row anomaly axis must match the row `axis`.

## N52 - JSONL Row False Pass

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule) and [Threshold Operator Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#threshold-operator-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"envelope_bound","measurement":{"value":0.08,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
```

Rejection reason: row `pass` must equal replaying `measurement` against `acceptance_threshold`.

## N53 - JSONL Row Stale Schema Version

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule) and [Schema Version Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-version-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.1","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
```

Rejection reason: each JSONL row must repeat the current schema version.

## N54 - JSONL Row Unit Mismatch

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule) and [Unit Consistency Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#unit-consistency-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"bits"},"pass":true,"anomalies":[]}
```

Rejection reason: JSONL row `measurement.unit` must exactly match row `acceptance_threshold.unit`.

## N55 - JSONL Row Extra Property

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule) and the closed-object `additionalProperties: false` rule.

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[],"reviewer_override":"accept"}
```

Rejection reason: JSONL rows cannot add undeclared top-level keys.

## N56 - JSONL Row Falsifier Drift

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-ULP-Oracle","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
```

Rejection reason: row `falsifier_id` must equal the artifact manifest falsifier ID.

## N57 - JSONL Token Index Regression

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":4,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":1,"prompt_id":"wbo-fixture-0001","token_index":3,"axis":"post_softmax_drift","measurement":{"value":0.01,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.025,"unit":"nats"},"pass":true,"anomalies":[]}
```

Rejection reason: `token_index` must not decrease within the same `prompt_id`.

## N58 - Duplicate JSONL Prompt Token Axis

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":4,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":1,"prompt_id":"wbo-fixture-0001","token_index":4,"axis":"envelope_bound","measurement":{"value":0.04,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
```

Rejection reason: `(prompt_id, token_index, axis)` must be unique across `result.jsonl`.

## N59 - JSONL Missing Final Newline

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
```

Fixture byte note: the source file ends immediately after the final `}` byte; the fence newline is not part of the witness.

Rejection reason: `result.jsonl` must end with a final LF.

## N60 - JSONL Blank Line

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}

{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":1,"prompt_id":"wbo-fixture-0001","token_index":1,"axis":"post_softmax_drift","measurement":{"value":0.01,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.025,"unit":"nats"},"pass":true,"anomalies":[]}
```

Rejection reason: `result.jsonl` must not contain blank lines.

## N61 - JSONL UTF-8 BOM Prefix

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
```

Fixture byte note: the source file starts with bytes `EF BB BF` before the first `{`; the code fence omits the invisible prefix.

Rejection reason: `result.jsonl` must be UTF-8 without a BOM.

## N62 - JSONL CRLF Line Endings

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":1,"prompt_id":"wbo-fixture-0001","token_index":1,"axis":"post_softmax_drift","measurement":{"value":0.01,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.025,"unit":"nats"},"pass":true,"anomalies":[]}
```

Fixture byte note: each displayed line ends with bytes `0D 0A`; the code fence normalizes that for readability.

Rejection reason: `result.jsonl` must use LF line endings, not CRLF.

## N63 - JSONL Anomaly Excuses File Defect

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":4,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":1,"prompt_id":"wbo-fixture-0001","token_index":4,"axis":"envelope_bound","measurement":{"value":0.04,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[{"kind":"other","axis":"envelope_bound","description":"duplicate prompt-token-axis row retained as reviewer override","affects_pass":false,"severity":"info"}]}
```

Rejection reason: row anomalies cannot excuse prompt-token-axis duplication or other file-level defects.

## N64 - JSONL Row Artifact Path Smuggling

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule) and [Validation Boundary](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#validation-boundary).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[],"artifact_path":"artifacts/falsifiers/wbo_drift_ledger/alternate.jsonl"}
```

Rejection reason: JSONL rows inherit artifact path from validator input and cannot carry path fields.

## N65 - JSONL Scalar Measurement

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule) and [Measurements Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurements-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"envelope_bound","measurement":0.03,"acceptance_threshold":{"operator":"<=","value":0.05,"unit":"nats"},"pass":true,"anomalies":[]}
```

Rejection reason: JSONL row `measurement` must be an object with `value` and `unit`.

## N66 - JSONL Scalar Threshold

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule) and [Acceptance Thresholds Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#acceptance-thresholds-rule).

Validator input path: `artifacts/falsifiers/wbo_drift_ledger/result.jsonl`

```jsonl
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo-fixture-0001","token_index":0,"axis":"envelope_bound","measurement":{"value":0.03,"unit":"nats"},"acceptance_threshold":0.05,"pass":true,"anomalies":[]}
```

Rejection reason: JSONL row `acceptance_threshold` must be an object with `operator`, `value`, and `unit`.

## N67 - Missing Schema-Required Floor Axes

Violates: [Falsifier Axis Enum Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#falsifier-axis-enum-rule), [Cross-Gate Axis Floors](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#cross-gate-axis-floors), and [Axis Consistency Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#axis-consistency-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T14:30:00Z",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `F-ULP-Oracle` must also include `comparable_points_over_2ulp`, `stress_case_classification`, and `wall_clock_seconds` under all three axis maps.

## N68 - Anomaly Missing Severity

Violates: [Anomalies Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomalies-rule) and [Anomaly Kind Requirements](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomaly-kind-requirements).

```json
{
  "falsifier_id": "F-PageGather-Scatter",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_scatter.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "page-gather-scatter-256m-512m-v1",
  "timestamp_utc": "2026-05-18T14:40:00Z",
  "measurements": {
    "scatter_bw_256mb": {
      "value": 45.0,
      "unit": "GB/s"
    },
    "scatter_bw_512mb": {
      "value": 45.0,
      "unit": "GB/s"
    },
    "baseline_ratio": {
      "value": 0.70,
      "unit": "ratio"
    },
    "correctness_digest": {
      "value": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "unit": "sha256"
    },
    "window_seconds": {
      "value": 1.0,
      "unit": "s"
    }
  },
  "acceptance_thresholds": {
    "scatter_bw_256mb": {
      "operator": ">=",
      "value": 45.0,
      "unit": "GB/s"
    },
    "scatter_bw_512mb": {
      "operator": ">=",
      "value": 45.0,
      "unit": "GB/s"
    },
    "baseline_ratio": {
      "operator": ">=",
      "value": 0.70,
      "unit": "ratio"
    },
    "correctness_digest": {
      "operator": "==",
      "value": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "unit": "sha256"
    },
    "window_seconds": {
      "operator": ">=",
      "value": 1.0,
      "unit": "s"
    }
  },
  "pass_per_axis": {
    "scatter_bw_256mb": true,
    "scatter_bw_512mb": true,
    "baseline_ratio": true,
    "correctness_digest": true,
    "window_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [
    {
      "kind": "timing",
      "axis": "window_seconds",
      "description": "clock jitter observed after run, timing axis manually accepted",
      "affects_pass": false
    }
  ],
  "notes": "anomaly_inspection=complete; timing anomaly retained for validator rejection"
}
```

Rejection reason: every anomaly must include `severity` so validator tooling can sort anomaly urgency without prose inference.

## N69 - Post-Witness Schema Drift Without Digest

Violates: [Schema Migration Table](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-migration-table), [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape), and [Pre-Witness Tightening Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#pre-witness-tightening-rule).

```json
{
  "falsifier_id": "F-ACS-AnchorLookup",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_acs_anchor_lookup.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "acs-anchor-lookup-v1",
  "timestamp_utc": "2026-05-18T14:50:00Z",
  "measurements": {
    "round_trip_field_digest": {
      "value": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "unit": "sha256",
      "statistic": "digest"
    },
    "invalid_theorem_rejection": {
      "value": true,
      "unit": "bool"
    },
    "projection_integrity": {
      "value": true,
      "unit": "bool"
    }
  },
  "acceptance_thresholds": {
    "round_trip_field_digest": {
      "operator": "==",
      "value": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "unit": "sha256"
    },
    "invalid_theorem_rejection": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "projection_integrity": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    }
  },
  "pass_per_axis": {
    "round_trip_field_digest": true,
    "invalid_theorem_rejection": true,
    "projection_integrity": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.2; artifact_path=artifacts/falsifiers/acs_anchor_lookup/result.json; migration_command=manual-schema-tighten; field_mapping=axis_floor_conditionals; reviewer=jojo; reviewed_at_utc=2026-05-18T14:55:00Z"
}
```

Rejection reason: once a real `.2` witness exists, schema-shape changes require a bumped schema version plus before/after schema fragment digests.

## N70 - Pre-Adopted Typed Hardware Pin

Violates: [Hardware Pin Schema Definition Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#hardware-pin-schema-definition-rule), [Hardware Pin Typed Sub-Schema Target](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#hardware-pin-typed-sub-schema-target), and [Hardware Pin Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#hardware-pin-rule).

```json
{
  "falsifier_id": "F-ACS-AnchorLookup",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "model_identifier": "M2 Pro 14-inch 2023",
    "chip": "M2 Pro",
    "cpu_cores": 12,
    "gpu_cores": 19,
    "memory_gb": 16,
    "uma": true,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_acs_anchor_lookup.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "acs-anchor-lookup-v1",
  "timestamp_utc": "2026-05-18T15:00:00Z",
  "measurements": {
    "round_trip_field_digest": {
      "value": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      "unit": "sha256",
      "statistic": "digest"
    },
    "invalid_theorem_rejection": {
      "value": true,
      "unit": "bool"
    },
    "projection_integrity": {
      "value": true,
      "unit": "bool"
    }
  },
  "acceptance_thresholds": {
    "round_trip_field_digest": {
      "operator": "==",
      "value": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      "unit": "sha256"
    },
    "invalid_theorem_rejection": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "projection_integrity": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    }
  },
  "pass_per_axis": {
    "round_trip_field_digest": true,
    "invalid_theorem_rejection": true,
    "projection_integrity": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: schema `2026-05-18.2` still requires the current `$defs.hardware_pin` fields; typed hardware fields are reserved for the next schema bump.

## N71 - Cloud Reference Hidden In Notes

Violates: [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule) and [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-70B-Local-Cocktail-Lite",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_70b_local_cocktail_lite.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "70b-cocktail-lite-50prompt-v1",
  "timestamp_utc": "2026-05-18T15:10:00Z",
  "measurements": {
    "d_kl_nats": {
      "value": 0.08,
      "unit": "nats"
    },
    "decode_tok_s": {
      "value": 5.2,
      "unit": "tok/s"
    },
    "ttft_seconds": {
      "value": 28.0,
      "unit": "s"
    },
    "resident_memory_gb": {
      "value": 13.5,
      "unit": "GB"
    },
    "bottleneck_identified": {
      "value": true,
      "unit": "bool"
    }
  },
  "acceptance_thresholds": {
    "d_kl_nats": {
      "operator": "<=",
      "value": 0.1,
      "unit": "nats"
    },
    "decode_tok_s": {
      "operator": ">=",
      "value": 5.0,
      "unit": "tok/s"
    },
    "ttft_seconds": {
      "operator": "<=",
      "value": 30.0,
      "unit": "s"
    },
    "resident_memory_gb": {
      "operator": "<=",
      "value": 14.0,
      "unit": "GB"
    },
    "bottleneck_identified": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    }
  },
  "pass_per_axis": {
    "d_kl_nats": true,
    "decode_tok_s": true,
    "ttft_seconds": true,
    "resident_memory_gb": true,
    "bottleneck_identified": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; cloud fp16 reference request used for D_KL but receipt withheld by reviewer"
}
```

Rejection reason: cloud or hosted reference evidence requires `provider_receipts`; notes cannot substitute for a replay receipt.

## N72 - Scatter Missing Baseline Artifact

Violates: [Falsifier Dependency Graph](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#falsifier-dependency-graph), [Acceptance Thresholds Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#acceptance-thresholds-rule), and [Artifact Reference Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#artifact-reference-rule).

```json
{
  "falsifier_id": "F-PageGather-Scatter",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_scatter.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "page-gather-scatter-256m-512m-v1",
  "timestamp_utc": "2026-05-18T15:20:00Z",
  "measurements": {
    "scatter_bw_256mb": {
      "value": 45.0,
      "unit": "GB/s"
    },
    "scatter_bw_512mb": {
      "value": 45.0,
      "unit": "GB/s"
    },
    "baseline_ratio": {
      "value": 0.70,
      "unit": "ratio"
    },
    "correctness_digest": {
      "value": "sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
      "unit": "sha256",
      "statistic": "digest"
    },
    "window_seconds": {
      "value": 1.0,
      "unit": "s"
    }
  },
  "acceptance_thresholds": {
    "scatter_bw_256mb": {
      "operator": ">=",
      "value": 45.0,
      "unit": "GB/s"
    },
    "scatter_bw_512mb": {
      "operator": ">=",
      "value": 45.0,
      "unit": "GB/s"
    },
    "baseline_ratio": {
      "operator": ">=",
      "value": 0.70,
      "unit": "ratio"
    },
    "correctness_digest": {
      "operator": "==",
      "value": "sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
      "unit": "sha256"
    },
    "window_seconds": {
      "operator": ">=",
      "value": 1.0,
      "unit": "s"
    }
  },
  "pass_per_axis": {
    "scatter_bw_256mb": true,
    "scatter_bw_512mb": true,
    "baseline_ratio": true,
    "correctness_digest": true,
    "window_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `F-PageGather-Scatter` thresholds must link the baseline calibration artifact and axis instead of embedding a private ratio.

## N73 - Garbage-Collected Upstream Artifact

Violates: [Witness Retention Policy](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#witness-retention-policy), [Falsifier Dependency Graph](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#falsifier-dependency-graph), and [Artifact Reference Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#artifact-reference-rule).

```json
{
  "falsifier_id": "F-PageGather-Scatter",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_scatter.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "page-gather-scatter-256m-512m-v1",
  "timestamp_utc": "2026-05-18T15:30:00Z",
  "measurements": {
    "scatter_bw_256mb": {
      "value": 45.0,
      "unit": "GB/s"
    },
    "scatter_bw_512mb": {
      "value": 45.0,
      "unit": "GB/s"
    },
    "baseline_ratio": {
      "value": 0.70,
      "unit": "ratio"
    },
    "correctness_digest": {
      "value": "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      "unit": "sha256",
      "statistic": "digest"
    },
    "window_seconds": {
      "value": 1.0,
      "unit": "s"
    }
  },
  "acceptance_thresholds": {
    "scatter_bw_256mb": {
      "operator": ">=",
      "value": 45.0,
      "unit": "GB/s",
      "upstream_artifact": "artifacts/falsifiers/page_gather/baseline/result.json",
      "upstream_axis": "median_bw_256mb"
    },
    "scatter_bw_512mb": {
      "operator": ">=",
      "value": 45.0,
      "unit": "GB/s",
      "upstream_artifact": "artifacts/falsifiers/page_gather/baseline/result.json",
      "upstream_axis": "median_bw_512mb"
    },
    "baseline_ratio": {
      "operator": ">=",
      "value": 0.70,
      "unit": "ratio",
      "upstream_artifact": "artifacts/falsifiers/page_gather/baseline/result.json",
      "upstream_axis": "median_bw_512mb"
    },
    "correctness_digest": {
      "operator": "==",
      "value": "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      "unit": "sha256"
    },
    "window_seconds": {
      "operator": ">=",
      "value": 1.0,
      "unit": "s"
    }
  },
  "pass_per_axis": {
    "scatter_bw_256mb": true,
    "scatter_bw_512mb": true,
    "baseline_ratio": true,
    "correctness_digest": true,
    "window_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Fixture filesystem note: `artifacts/falsifiers/page_gather/baseline/result.json` has been deleted after the ratio was copied into this artifact.

Rejection reason: a cited upstream artifact must remain retained while a downstream witness depends on it.

## N74 - 70B Missing Receipt Or Local Marker

Violates: [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule).

```json
{
  "falsifier_id": "F-70B-Local-Cocktail-Lite",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_70b_local_cocktail_lite.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "70b-cocktail-lite-50prompt-v1",
  "timestamp_utc": "2026-05-18T15:40:00Z",
  "measurements": {
    "d_kl_nats": {
      "value": 0.08,
      "unit": "nats"
    },
    "decode_tok_s": {
      "value": 5.2,
      "unit": "tok/s"
    },
    "ttft_seconds": {
      "value": 28.0,
      "unit": "s"
    },
    "resident_memory_gb": {
      "value": 13.5,
      "unit": "GB"
    },
    "bottleneck_identified": {
      "value": true,
      "unit": "bool"
    }
  },
  "acceptance_thresholds": {
    "d_kl_nats": {
      "operator": "<=",
      "value": 0.1,
      "unit": "nats"
    },
    "decode_tok_s": {
      "operator": ">=",
      "value": 5.0,
      "unit": "tok/s"
    },
    "ttft_seconds": {
      "operator": "<=",
      "value": 30.0,
      "unit": "s"
    },
    "resident_memory_gb": {
      "operator": "<=",
      "value": 14.0,
      "unit": "GB"
    },
    "bottleneck_identified": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    }
  },
  "pass_per_axis": {
    "d_kl_nats": true,
    "decode_tok_s": true,
    "ttft_seconds": true,
    "resident_memory_gb": true,
    "bottleneck_identified": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `F-70B-Local-Cocktail-Lite` must include `provider_receipts` or explicitly state `local_reference_only=true`.

## N75 - Malformed Schema Migration Digests

Violates: [Schema Fragment Digest Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-fragment-digest-rule) and [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ACS-AnchorLookup",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_acs_anchor_lookup.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "acs-anchor-lookup-v1",
  "timestamp_utc": "2026-05-18T15:50:00Z",
  "measurements": {
    "round_trip_field_digest": {
      "value": "sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
      "unit": "sha256",
      "statistic": "digest"
    },
    "invalid_theorem_rejection": {
      "value": true,
      "unit": "bool"
    },
    "projection_integrity": {
      "value": true,
      "unit": "bool"
    }
  },
  "acceptance_thresholds": {
    "round_trip_field_digest": {
      "operator": "==",
      "value": "sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
      "unit": "sha256"
    },
    "invalid_theorem_rejection": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "projection_integrity": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    }
  },
  "pass_per_axis": {
    "round_trip_field_digest": true,
    "invalid_theorem_rejection": true,
    "projection_integrity": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/acs_anchor_lookup/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=hardware_pin; reviewer=jojo; reviewed_at_utc=2026-05-18T15:55:00Z; schema_fragment_digest_before=abc123; schema_fragment_digest_after=SHA256:FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
}
```

Rejection reason: schema fragment digests must be lowercase `sha256:` values with 64 lowercase hex characters.

## N76 - Prose-Only Migration Note

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ACS-AnchorLookup",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_acs_anchor_lookup.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "acs-anchor-lookup-v1",
  "timestamp_utc": "2026-05-18T16:00:00Z",
  "measurements": {
    "round_trip_field_digest": {
      "value": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
      "unit": "sha256",
      "statistic": "digest"
    },
    "invalid_theorem_rejection": {
      "value": true,
      "unit": "bool"
    },
    "projection_integrity": {
      "value": true,
      "unit": "bool"
    }
  },
  "acceptance_thresholds": {
    "round_trip_field_digest": {
      "operator": "==",
      "value": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
      "unit": "sha256"
    },
    "invalid_theorem_rejection": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "projection_integrity": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    }
  },
  "pass_per_axis": {
    "round_trip_field_digest": true,
    "invalid_theorem_rejection": true,
    "projection_integrity": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; migrated from the old schema by reviewer Jojo after checking the field mapping spreadsheet"
}
```

Rejection reason: migration notes must use explicit semicolon-delimited `key=value` tokens, not prose.

## N77 - Missing Seeded Fixture Lineage

Violates: [Fixture Lineage Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#fixture-lineage-rule) and [Fixture Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#fixture-identity-rule).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-seed-42",
  "timestamp_utc": "2026-05-18T16:10:00Z",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: a seed-named generated fixture must include `fixture_lineage` with the manifest, seed, generator, and case count needed to recover the input set.

## N78 - Failure Report Claims Primary Pass

Violates: [Artifact Kind Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#artifact-kind-rule), [Overall Pass Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#overall-pass-rule), and [Fallback Tier Semantics](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#fallback-tier-semantics).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "failure_report",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T16:20:00Z",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp"
    },
    "comparable_points_over_2ulp": {
      "value": 0,
      "unit": "count"
    },
    "stress_case_classification": {
      "value": true,
      "unit": "bool"
    },
    "wall_clock_seconds": {
      "value": 80,
      "unit": "s"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp"
    },
    "comparable_points_over_2ulp": {
      "operator": "<=",
      "value": 0,
      "unit": "count"
    },
    "stress_case_classification": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "wall_clock_seconds": {
      "operator": "<=",
      "value": 90,
      "unit": "s"
    }
  },
  "pass_per_axis": {
    "max_ulp": true,
    "comparable_points_over_2ulp": true,
    "stress_case_classification": true,
    "wall_clock_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `failure_report` cannot pair with `overall_pass: true` and `fallback_tier: Primary`.

## N79 - Missing Result Digest

Violates: [Result Digest Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#result-digest-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T16:25:00Z",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp"
    },
    "comparable_points_over_2ulp": {
      "value": 0,
      "unit": "count"
    },
    "stress_case_classification": {
      "value": true,
      "unit": "bool"
    },
    "wall_clock_seconds": {
      "value": 80,
      "unit": "s"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp"
    },
    "comparable_points_over_2ulp": {
      "operator": "<=",
      "value": 0,
      "unit": "count"
    },
    "stress_case_classification": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "wall_clock_seconds": {
      "operator": "<=",
      "value": 90,
      "unit": "s"
    }
  },
  "pass_per_axis": {
    "max_ulp": true,
    "comparable_points_over_2ulp": true,
    "stress_case_classification": true,
    "wall_clock_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: the canonical replay payload has no `result_digest`, so replay cannot bind the reported pass to the bytes being validated.

## N80 - JSONL Row Repeats Result Digest

Violates: [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule), [Result Digest Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#result-digest-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "schema_version": "2026-05-18.2",
  "falsifier_id": "F-WBO-DriftLedger",
  "row_index": 0,
  "prompt_id": "wbo.drift.seeded.001",
  "token_index": 0,
  "axis": "ledger_entries_complete",
  "measurement": {
    "value": true,
    "unit": "bool"
  },
  "acceptance_threshold": {
    "operator": "==",
    "value": true,
    "unit": "bool"
  },
  "pass": true,
  "anomalies": [],
  "result_digest": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
```

Rejection reason: JSONL rows inherit the file-level `result_digest`; embedding a row-level digest creates a competing replay identity.

## N81 - Locale-Formatted Numeric Evidence

Violates: [Result Digest Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#result-digest-rule), [Measurement Threshold Compatibility Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurement-threshold-compatibility-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T16:30:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "max_ulp": {
      "value": "2,0",
      "unit": "ulp"
    },
    "comparable_points_over_2ulp": {
      "value": 0,
      "unit": "count"
    },
    "stress_case_classification": {
      "value": true,
      "unit": "bool"
    },
    "wall_clock_seconds": {
      "value": 80,
      "unit": "s"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp"
    },
    "comparable_points_over_2ulp": {
      "operator": "<=",
      "value": 0,
      "unit": "count"
    },
    "stress_case_classification": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "wall_clock_seconds": {
      "operator": "<=",
      "value": 90,
      "unit": "s"
    }
  },
  "pass_per_axis": {
    "max_ulp": true,
    "comparable_points_over_2ulp": true,
    "stress_case_classification": true,
    "wall_clock_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `max_ulp.value` is a locale-formatted string, so the numeric comparison and canonical result digest cannot represent the same replayable evidence.

## N82 - Raw Artifact Without Digest

Violates: [Sidecar Digest Reference Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#sidecar-digest-reference-rule), [Artifact Reference Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#artifact-reference-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-PageGather-Baseline",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_baseline.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "page-gather-baseline-256m-512m-1g-v1",
  "timestamp_utc": "2026-05-18T16:35:00Z",
  "result_digest": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  "measurements": {
    "baseline_median_gb_s": {
      "value": 67,
      "unit": "GB/s",
      "statistic": "median",
      "raw_artifact": "artifacts/falsifiers/page_gather/baseline/raw_timing.jsonl"
    },
    "min_window_seconds": {
      "value": 1.0,
      "unit": "s"
    },
    "buffer_sizes_covered": {
      "value": true,
      "unit": "bool"
    }
  },
  "acceptance_thresholds": {
    "baseline_median_gb_s": {
      "operator": ">=",
      "value": 60,
      "unit": "GB/s"
    },
    "min_window_seconds": {
      "operator": ">=",
      "value": 1.0,
      "unit": "s"
    },
    "buffer_sizes_covered": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    }
  },
  "pass_per_axis": {
    "baseline_median_gb_s": true,
    "min_window_seconds": true,
    "buffer_sizes_covered": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `raw_artifact` points at replay evidence without the required sibling `raw_artifact_sha256`.

## N83 - Provider Receipt Artifact Ref Without Digest

Violates: [Sidecar Digest Reference Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#sidecar-digest-reference-rule), [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-70B-Local-Cocktail-Lite",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "failure_report",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_70b_local_cocktail_lite.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "70b-cocktail-lite-50prompt-v1",
  "timestamp_utc": "2026-05-18T16:40:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "dkl_nats": {
      "value": 0.12,
      "unit": "nats"
    },
    "decode_tok_s": {
      "value": 4.2,
      "unit": "tok/s"
    },
    "ttft_seconds": {
      "value": 33,
      "unit": "s"
    },
    "resident_memory_gb": {
      "value": 13.8,
      "unit": "GB"
    },
    "bottleneck_identified": {
      "value": true,
      "unit": "bool"
    }
  },
  "acceptance_thresholds": {
    "dkl_nats": {
      "operator": "<=",
      "value": 0.1,
      "unit": "nats"
    },
    "decode_tok_s": {
      "operator": ">=",
      "value": 5,
      "unit": "tok/s"
    },
    "ttft_seconds": {
      "operator": "<=",
      "value": 30,
      "unit": "s"
    },
    "resident_memory_gb": {
      "operator": "<=",
      "value": 14,
      "unit": "GB"
    },
    "bottleneck_identified": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    }
  },
  "pass_per_axis": {
    "dkl_nats": false,
    "decode_tok_s": false,
    "ttft_seconds": false,
    "resident_memory_gb": true,
    "bottleneck_identified": true
  },
  "overall_pass": false,
  "fallback_tier": "Fail",
  "provider_receipts": [
    {
      "provider": "cloud-fp16-reference",
      "model_or_service": "llama-3.3-70b-fp16",
      "purpose": "reference_logits",
      "request_id_hash": "sha256:00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff",
      "timestamp_utc": "2026-05-18T16:39:00Z",
      "data_sent_class": "prompt_hash_only",
      "retention_claim": "zero_retention",
      "redaction_digest": "sha256:ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100",
      "replay_allowed": true,
      "artifact_ref": "artifacts/falsifiers/70b_local_cocktail_lite/provider_reference.json"
    }
  ],
  "anomalies": [
    {
      "kind": "fallback_triggered",
      "severity": "blocking",
      "message": "Cocktail missed the 70B reference thresholds.",
      "axis": "dkl_nats",
      "fallback_tier": "Fail",
      "affects_pass": true
    }
  ],
  "notes": "none; anomaly_inspected=true"
}
```

Rejection reason: provider receipt `artifact_ref` is replay material and must include `artifact_ref_sha256`.

## N84 - JSONL Witness Missing Manifest

Violates: [JSONL Replay Manifest Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-replay-manifest-rule), [JSONL Witness Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-witness-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```text
artifacts/falsifiers/wbo_drift_ledger/
  result.jsonl
```

```json
{"schema_version":"2026-05-18.2","falsifier_id":"F-WBO-DriftLedger","row_index":0,"prompt_id":"wbo.drift.seeded.001","token_index":0,"axis":"ledger_entries_complete","measurement":{"value":true,"unit":"bool"},"acceptance_threshold":{"operator":"==","value":true,"unit":"bool"},"pass":true,"anomalies":[]}
```

Rejection reason: `result.jsonl` has no adjacent `manifest.json`, so file-level fields such as `result_digest`, command, commit, hardware pin, and overall pass cannot be replay-bound.

## N85 - JSONL Manifest Digest Mismatch

Violates: [JSONL Replay Manifest Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#jsonl-replay-manifest-rule), [Result Digest Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#result-digest-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "schema_version": "2026-05-18.2",
  "falsifier_id": "F-WBO-DriftLedger",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_wbo_drift_ledger.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "wbo-drift-ledger-seeded-v1",
  "timestamp_utc": "2026-05-18T16:45:00Z",
  "result_digest": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  "jsonl_file": "result.jsonl",
  "jsonl_file_sha256": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "pass_per_axis": {
    "finite_nonnegative_terms": true,
    "envelope_bound": true,
    "post_softmax_drift": true,
    "missing_term_fail_closed": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `jsonl_file_sha256` must equal `result_digest` so the manifest and row stream name the same canonical payload bytes.

## N86 - Env-Prefixed Command

Violates: [Command Argument Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#command-argument-rule), [Command Normalization Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#command-normalization-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "MLX_FAST=1 tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T16:50:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp"
    },
    "comparable_points_over_2ulp": {
      "value": 0,
      "unit": "count"
    },
    "stress_case_classification": {
      "value": true,
      "unit": "bool"
    },
    "wall_clock_seconds": {
      "value": 80,
      "unit": "s"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp"
    },
    "comparable_points_over_2ulp": {
      "operator": "<=",
      "value": 0,
      "unit": "count"
    },
    "stress_case_classification": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "wall_clock_seconds": {
      "operator": "<=",
      "value": 90,
      "unit": "s"
    }
  },
  "pass_per_axis": {
    "max_ulp": true,
    "comparable_points_over_2ulp": true,
    "stress_case_classification": true,
    "wall_clock_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `command` includes an environment-prefix execution step instead of the canonical row script token string.

## N87 - Missing Runner Environment

Violates: [Command Normalization Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#command-normalization-rule), [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T16:55:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp"
    },
    "comparable_points_over_2ulp": {
      "value": 0,
      "unit": "count"
    },
    "stress_case_classification": {
      "value": true,
      "unit": "bool"
    },
    "wall_clock_seconds": {
      "value": 80,
      "unit": "s"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp"
    },
    "comparable_points_over_2ulp": {
      "operator": "<=",
      "value": 0,
      "unit": "count"
    },
    "stress_case_classification": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "wall_clock_seconds": {
      "operator": "<=",
      "value": 90,
      "unit": "s"
    }
  },
  "pass_per_axis": {
    "max_ulp": true,
    "comparable_points_over_2ulp": true,
    "stress_case_classification": true,
    "wall_clock_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: the artifact omits `runner_environment`, so command replay cannot distinguish script-owned execution from cwd, shell, locale, timezone, or environment drift.

## N88 - Digest Measurement Wrong Evidence Kind

Violates: [Measurement Evidence Kind Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurement-evidence-kind-rule), [Digest Measurement Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#digest-measurement-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ACS-AnchorLookup",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_acs_anchor_lookup.sh",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "acs-anchor-lookup-v1",
  "timestamp_utc": "2026-05-18T17:00:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "round_trip_field_digest": {
      "value": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
      "unit": "sha256",
      "statistic": "digest",
      "evidence_kind": "direct_measurement"
    },
    "invalid_theorem_rejection": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "projection_integrity": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    }
  },
  "acceptance_thresholds": {
    "round_trip_field_digest": {
      "operator": "present",
      "value": true,
      "unit": "sha256"
    },
    "invalid_theorem_rejection": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "projection_integrity": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    }
  },
  "pass_per_axis": {
    "round_trip_field_digest": true,
    "invalid_theorem_rejection": true,
    "projection_integrity": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `statistic: digest` requires `evidence_kind: digest`; `direct_measurement` hides the digest replay path.

## N89 - Aggregate Missing Sample Count

Violates: [Aggregate Statistic Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#aggregate-statistic-rule), [Measurement Evidence Kind Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurement-evidence-kind-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-PageGather-Baseline",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_page_gather_baseline.sh",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "page-gather-baseline-256m-512m-1g-v1",
  "timestamp_utc": "2026-05-18T17:05:00Z",
  "result_digest": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  "measurements": {
    "baseline_median_gb_s": {
      "value": 67,
      "unit": "GB/s",
      "statistic": "median",
      "samples": [65, 67, 68],
      "evidence_kind": "aggregate_statistic"
    },
    "min_window_seconds": {
      "value": 1.0,
      "unit": "s",
      "evidence_kind": "direct_measurement"
    },
    "buffer_sizes_covered": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    }
  },
  "acceptance_thresholds": {
    "baseline_median_gb_s": {
      "operator": ">=",
      "value": 60,
      "unit": "GB/s"
    },
    "min_window_seconds": {
      "operator": ">=",
      "value": 1.0,
      "unit": "s"
    },
    "buffer_sizes_covered": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    }
  },
  "pass_per_axis": {
    "baseline_median_gb_s": true,
    "min_window_seconds": true,
    "buffer_sizes_covered": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: an aggregate `median` measurement must declare `sample_count` so replay can check embedded samples or raw timing sidecars.

## N90 - Runner Environment Missing Thermal State

Violates: [Command Normalization Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#command-normalization-rule), [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T17:10:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    },
    "comparable_points_over_2ulp": {
      "value": 0,
      "unit": "count",
      "evidence_kind": "direct_measurement"
    },
    "stress_case_classification": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "wall_clock_seconds": {
      "value": 80,
      "unit": "s",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp"
    },
    "comparable_points_over_2ulp": {
      "operator": "<=",
      "value": 0,
      "unit": "count"
    },
    "stress_case_classification": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "wall_clock_seconds": {
      "operator": "<=",
      "value": 90,
      "unit": "s"
    }
  },
  "pass_per_axis": {
    "max_ulp": true,
    "comparable_points_over_2ulp": true,
    "stress_case_classification": true,
    "wall_clock_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `runner_environment` omits `thermal_state_start`, `thermal_state_end`, and `power_source`, so timing evidence is not replay-pinned.

## N91 - Timing Pass Under Serious Thermal Pressure

Violates: [Timing Thermal Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#timing-thermal-rule), [Anomalies Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomalies-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "thermal_state_start": "serious",
    "thermal_state_end": "serious",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T17:15:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    },
    "comparable_points_over_2ulp": {
      "value": 0,
      "unit": "count",
      "evidence_kind": "direct_measurement"
    },
    "stress_case_classification": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "wall_clock_seconds": {
      "value": 80,
      "unit": "s",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp"
    },
    "comparable_points_over_2ulp": {
      "operator": "<=",
      "value": 0,
      "unit": "count"
    },
    "stress_case_classification": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "wall_clock_seconds": {
      "operator": "<=",
      "value": 90,
      "unit": "s"
    }
  },
  "pass_per_axis": {
    "max_ulp": true,
    "comparable_points_over_2ulp": true,
    "stress_case_classification": true,
    "wall_clock_seconds": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `wall_clock_seconds` passes while both thermal states are `serious` and no blocking thermal anomaly invalidates the timing axis.

## N92 - Timing Pass On Battery Power

Violates: [Timing Power Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#timing-power-rule), [Anomalies Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomalies-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "battery"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T17:20:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `p99_latency_us` passes while `power_source` is `battery` and no blocking power anomaly invalidates the timing axis.

## N93 - Runner Environment Missing OS Build

Violates: [Command Normalization Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#command-normalization-rule), [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T17:25:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `runner_environment` omits `os_build`, so the timing and command replay context cannot be tied to the producing macOS build.

## N94 - Runner OS Build Contains Newline

Violates: [Command Normalization Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#command-normalization-rule), [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5\n24F74",
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T17:35:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `runner_environment.os_build` contains a newline, so the field is not a single replay-stable macOS build token.

## N95 - Runner Environment Missing Toolchain Identity

Violates: [Runner Toolchain Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#runner-toolchain-identity-rule), [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T17:40:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `runner_environment` omits `toolchain_identity`, so replay cannot separate compiler or interpreter drift from falsifier output drift.

## N96 - Runner Toolchain Uses Vague None Sentinel

Violates: [Runner Toolchain Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#runner-toolchain-identity-rule), [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "none",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T17:45:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `toolchain_identity.xcodebuild` uses `none`; unused toolchains must use the exact `not_used` sentinel.

## N97 - Threshold Missing Source Provenance

Violates: [Acceptance Thresholds Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#acceptance-thresholds-rule), [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist), and [Measurement Threshold Compatibility Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurement-threshold-compatibility-rule).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "Xcode 16.4",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T17:50:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `acceptance_thresholds.p99_latency_us` omits `threshold_source`, so replay cannot tell whether the latency bar came from the handbook row, fragment, upstream artifact, or provider receipt.

## N98 - Provider Threshold Missing Receipt Reference

Violates: [Acceptance Thresholds Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#acceptance-thresholds-rule), [Provider Receipt Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-schema), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "Xcode 16.4",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T17:55:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us",
      "threshold_source": "provider_receipt"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `acceptance_thresholds.p99_latency_us.threshold_source` is `provider_receipt` but the threshold omits `provider_receipt_ref`.

## N99 - Command Digest Missing

Violates: [Command Normalization Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#command-normalization-rule), [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "Xcode 16.4",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T18:00:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: the artifact records `command` but omits `command_digest`, so replay cannot hash-lock the normalized command string.

## N100 - Fixture Lineage Missing Manifest Digest

Violates: [Fixture Lineage Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#fixture-lineage-rule), [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "command_digest": "sha256:6c439cd9c23352e6845c2b819c1eddaeb168acfacf0910e50bab69e9c7135a0f",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "Xcode 16.4",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "fixture_lineage": {
    "fixture_manifest": "docs/falsifiers/fixtures/interrupt-score-cpu-100k.json",
    "seed": "interrupt-score-cpu-100k-v1",
    "generator_command": "tools/falsifiers/generate_interrupt_fixture.sh --cases 100000",
    "dataset_version": "local-v1",
    "config_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
    "case_count": 100000,
    "unicode_cases_present": false
  },
  "timestamp_utc": "2026-05-18T18:05:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `fixture_lineage.fixture_manifest` is present without `fixture_manifest_sha256`, so the generated fixture manifest is not retained by digest.

## N101 - Blocking Anomaly Missing Evidence Reference

Violates: [Anomalies Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomalies-rule), [Pass-Affecting Anomaly Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#pass-affecting-anomaly-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "failure_report",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "command_digest": "sha256:6c439cd9c23352e6845c2b819c1eddaeb168acfacf0910e50bab69e9c7135a0f",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "Xcode 16.4",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "serious",
    "thermal_state_end": "serious",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T18:10:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 180,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": false
  },
  "overall_pass": false,
  "fallback_tier": "Fail",
  "anomalies": [
    {
      "kind": "thermal",
      "axis": "p99_latency_us",
      "description": "Serious thermal pressure invalidated latency evidence.",
      "affects_pass": true,
      "severity": "blocking"
    }
  ],
  "notes": "anomaly_inspection=complete"
}
```

Rejection reason: the blocking thermal anomaly omits `evidence_ref` and `evidence_ref_sha256`, so the disqualifying evidence is not retained.

## N102 - Failure Report Still Passes

Violates: [Artifact Kind Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#artifact-kind-rule), [Overall Pass Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#overall-pass-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "failure_report",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "command_digest": "sha256:6c439cd9c23352e6845c2b819c1eddaeb168acfacf0910e50bab69e9c7135a0f",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "Xcode 16.4",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T18:15:00Z",
  "result_digest": "sha256:abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Fail",
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `artifact_kind` is `failure_report` but `overall_pass` is true; failure reports must fail with `fallback_tier: Fail`.

## N103 - Non-None Notes Missing Reviewer

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "command_digest": "sha256:6c439cd9c23352e6845c2b819c1eddaeb168acfacf0910e50bab69e9c7135a0f",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "Xcode 16.4",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T18:20:00Z",
  "result_digest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete"
}
```

Rejection reason: non-`none` notes include the anomaly-inspection token but omit the required `reviewer=<id>` token.

## N104 - Non-None Notes Missing Review Timestamp

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "command_digest": "sha256:6c439cd9c23352e6845c2b819c1eddaeb168acfacf0910e50bab69e9c7135a0f",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "Xcode 16.4",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T18:25:00Z",
  "result_digest": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete reviewer=codex"
}
```

Rejection reason: non-`none` notes include anomaly-inspection and reviewer tokens but omit the required `reviewed_at_utc=<RFC3339Z>` token.

## N105 - Notes Use Anonymous Reviewer Sentinel

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "command_digest": "sha256:6c439cd9c23352e6845c2b819c1eddaeb168acfacf0910e50bab69e9c7135a0f",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "Xcode 16.4",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T18:30:00Z",
  "result_digest": "sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete reviewer=anonymous reviewed_at_utc=2026-05-18T18:30:00Z"
}
```

Rejection reason: `reviewer=anonymous` is a reserved reviewer sentinel and cannot identify who inspected the notes.

## N106 - Notes Tokens Space-Separated

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule), [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "command_digest": "sha256:6c439cd9c23352e6845c2b819c1eddaeb168acfacf0910e50bab69e9c7135a0f",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "Xcode 16.4",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T18:35:00Z",
  "result_digest": "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete reviewer=codex reviewed_at_utc=2026-05-18T18:35:00Z"
}
```

Rejection reason: required notes tokens are space-separated; validator-readable note tokens must be semicolon-delimited.

## N107 - Notes Exceed Length Cap

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "command_digest": "sha256:6c439cd9c23352e6845c2b819c1eddaeb168acfacf0910e50bab69e9c7135a0f",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "Xcode 16.4",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T18:40:00Z",
  "result_digest": "sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; reviewer=codex; reviewed_at_utc=2026-05-18T18:40:00Z; padding=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}
```

Rejection reason: `notes` exceeds the 1536-character cap even though its required machine tokens are present.

## N108 - Notes Use Unknown Machine Token Key

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-InterruptScore-CPU",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_interrupt_score_cpu.sh",
  "command_digest": "sha256:6c439cd9c23352e6845c2b819c1eddaeb168acfacf0910e50bab69e9c7135a0f",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "Xcode 16.4",
      "swift": "Swift 6.1",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "interrupt-score-cpu-100k-v1",
  "timestamp_utc": "2026-05-18T18:45:00Z",
  "result_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "measurements": {
    "equation_match": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "clamp_bounds": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "bucket_boundaries": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    },
    "p99_latency_us": {
      "value": 80,
      "unit": "us",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "equation_match": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "clamp_bounds": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "bucket_boundaries": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    },
    "p99_latency_us": {
      "operator": "<=",
      "value": 100,
      "unit": "us",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "equation_match": true,
    "clamp_bounds": true,
    "bucket_boundaries": true,
    "p99_latency_us": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; reviewer=codex; reviewed_at_utc=2026-05-18T18:45:00Z; operator_note=acceptable"
}
```

Rejection reason: `operator_note` is not a schema-owned notes token key; prose caveats cannot invent machine-readable keys.

## N109 - Local Reference Notes Missing Digest

Violates: [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule), [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-70B-Local-Cocktail-Lite",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_70b_local_cocktail_lite.sh",
  "command_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "not_used",
      "swift": "not_used",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "70b-cocktail-lite-50prompt-v1",
  "timestamp_utc": "2026-05-18T18:50:00Z",
  "result_digest": "sha256:3333333333333333333333333333333333333333333333333333333333333333",
  "measurements": {
    "d_kl_nats": {
      "value": 0.08,
      "unit": "nats",
      "evidence_kind": "direct_measurement"
    },
    "decode_tok_s": {
      "value": 5.2,
      "unit": "tok/s",
      "evidence_kind": "direct_measurement"
    },
    "ttft_seconds": {
      "value": 28.0,
      "unit": "s",
      "evidence_kind": "direct_measurement"
    },
    "resident_memory_gb": {
      "value": 13.5,
      "unit": "GB",
      "evidence_kind": "direct_measurement"
    },
    "bottleneck_identified": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    }
  },
  "acceptance_thresholds": {
    "d_kl_nats": {
      "operator": "<=",
      "value": 0.1,
      "unit": "nats",
      "threshold_source": "fragment_contract"
    },
    "decode_tok_s": {
      "operator": ">=",
      "value": 5.0,
      "unit": "tok/s",
      "threshold_source": "fragment_contract"
    },
    "ttft_seconds": {
      "operator": "<=",
      "value": 30.0,
      "unit": "s",
      "threshold_source": "fragment_contract"
    },
    "resident_memory_gb": {
      "operator": "<=",
      "value": 14.0,
      "unit": "GB",
      "threshold_source": "fragment_contract"
    },
    "bottleneck_identified": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "d_kl_nats": true,
    "decode_tok_s": true,
    "ttft_seconds": true,
    "resident_memory_gb": true,
    "bottleneck_identified": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; reviewer=codex; reviewed_at_utc=2026-05-18T18:50:00Z; local_reference_only=true; local_reference_artifact=artifacts/falsifiers/70b_local_cocktail_lite/local_reference.json"
}
```

Rejection reason: `local_reference_only=true` names a retained local artifact but omits the required `local_reference_artifact_sha256` digest.

## N110 - Local Reference Artifact Outside Row Root

Violates: [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule), [Artifact Root Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#artifact-root-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-70B-Local-Cocktail-Lite",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_70b_local_cocktail_lite.sh",
  "command_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "not_used",
      "swift": "not_used",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "70b-cocktail-lite-50prompt-v1",
  "timestamp_utc": "2026-05-18T18:55:00Z",
  "result_digest": "sha256:4444444444444444444444444444444444444444444444444444444444444444",
  "measurements": {
    "d_kl_nats": {
      "value": 0.08,
      "unit": "nats",
      "evidence_kind": "direct_measurement"
    },
    "decode_tok_s": {
      "value": 5.2,
      "unit": "tok/s",
      "evidence_kind": "direct_measurement"
    },
    "ttft_seconds": {
      "value": 28.0,
      "unit": "s",
      "evidence_kind": "direct_measurement"
    },
    "resident_memory_gb": {
      "value": 13.5,
      "unit": "GB",
      "evidence_kind": "direct_measurement"
    },
    "bottleneck_identified": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    }
  },
  "acceptance_thresholds": {
    "d_kl_nats": {
      "operator": "<=",
      "value": 0.1,
      "unit": "nats",
      "threshold_source": "fragment_contract"
    },
    "decode_tok_s": {
      "operator": ">=",
      "value": 5.0,
      "unit": "tok/s",
      "threshold_source": "fragment_contract"
    },
    "ttft_seconds": {
      "operator": "<=",
      "value": 30.0,
      "unit": "s",
      "threshold_source": "fragment_contract"
    },
    "resident_memory_gb": {
      "operator": "<=",
      "value": 14.0,
      "unit": "GB",
      "threshold_source": "fragment_contract"
    },
    "bottleneck_identified": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "d_kl_nats": true,
    "decode_tok_s": true,
    "ttft_seconds": true,
    "resident_memory_gb": true,
    "bottleneck_identified": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; reviewer=codex; reviewed_at_utc=2026-05-18T18:55:00Z; local_reference_only=true; local_reference_artifact=artifacts/falsifiers/shared/local_reference.json; local_reference_artifact_sha256=sha256:5555555555555555555555555555555555555555555555555555555555555555"
}
```

Rejection reason: `local_reference_artifact` points outside `artifacts/falsifiers/70b_local_cocktail_lite/`, so the local reference is not retained under the row root.

## N111 - Local Reference Artifact Has Dot Segment

Violates: [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule), [Artifact Root Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#artifact-root-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-70B-Local-Cocktail-Lite",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_70b_local_cocktail_lite.sh",
  "command_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "not_used",
      "swift": "not_used",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "70b-cocktail-lite-50prompt-v1",
  "timestamp_utc": "2026-05-18T19:00:00Z",
  "result_digest": "sha256:6666666666666666666666666666666666666666666666666666666666666666",
  "measurements": {
    "d_kl_nats": {
      "value": 0.08,
      "unit": "nats",
      "evidence_kind": "direct_measurement"
    },
    "decode_tok_s": {
      "value": 5.2,
      "unit": "tok/s",
      "evidence_kind": "direct_measurement"
    },
    "ttft_seconds": {
      "value": 28.0,
      "unit": "s",
      "evidence_kind": "direct_measurement"
    },
    "resident_memory_gb": {
      "value": 13.5,
      "unit": "GB",
      "evidence_kind": "direct_measurement"
    },
    "bottleneck_identified": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    }
  },
  "acceptance_thresholds": {
    "d_kl_nats": {
      "operator": "<=",
      "value": 0.1,
      "unit": "nats",
      "threshold_source": "fragment_contract"
    },
    "decode_tok_s": {
      "operator": ">=",
      "value": 5.0,
      "unit": "tok/s",
      "threshold_source": "fragment_contract"
    },
    "ttft_seconds": {
      "operator": "<=",
      "value": 30.0,
      "unit": "s",
      "threshold_source": "fragment_contract"
    },
    "resident_memory_gb": {
      "operator": "<=",
      "value": 14.0,
      "unit": "GB",
      "threshold_source": "fragment_contract"
    },
    "bottleneck_identified": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "d_kl_nats": true,
    "decode_tok_s": true,
    "ttft_seconds": true,
    "resident_memory_gb": true,
    "bottleneck_identified": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; reviewer=codex; reviewed_at_utc=2026-05-18T19:00:00Z; local_reference_only=true; local_reference_artifact=artifacts/falsifiers/70b_local_cocktail_lite/../shared/local_reference.json; local_reference_artifact_sha256=sha256:7777777777777777777777777777777777777777777777777777777777777777"
}
```

Rejection reason: `local_reference_artifact` uses a `..` segment, so the apparent row-root prefix is not replay-safe.

## N112 - Provider Receipt Artifact Ref Has Dot Segment

Violates: [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule), [Sidecar Digest Reference Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#sidecar-digest-reference-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-70B-Local-Cocktail-Lite",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "failure_report",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_70b_local_cocktail_lite.sh",
  "command_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "not_used",
      "swift": "not_used",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "70b-cocktail-lite-50prompt-v1",
  "timestamp_utc": "2026-05-18T19:05:00Z",
  "result_digest": "sha256:8888888888888888888888888888888888888888888888888888888888888888",
  "measurements": {
    "d_kl_nats": {
      "value": 0.12,
      "unit": "nats",
      "evidence_kind": "direct_measurement"
    },
    "decode_tok_s": {
      "value": 4.2,
      "unit": "tok/s",
      "evidence_kind": "direct_measurement"
    },
    "ttft_seconds": {
      "value": 33,
      "unit": "s",
      "evidence_kind": "direct_measurement"
    },
    "resident_memory_gb": {
      "value": 13.8,
      "unit": "GB",
      "evidence_kind": "direct_measurement"
    },
    "bottleneck_identified": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    }
  },
  "acceptance_thresholds": {
    "d_kl_nats": {
      "operator": "<=",
      "value": 0.1,
      "unit": "nats",
      "threshold_source": "fragment_contract"
    },
    "decode_tok_s": {
      "operator": ">=",
      "value": 5.0,
      "unit": "tok/s",
      "threshold_source": "fragment_contract"
    },
    "ttft_seconds": {
      "operator": "<=",
      "value": 30.0,
      "unit": "s",
      "threshold_source": "fragment_contract"
    },
    "resident_memory_gb": {
      "operator": "<=",
      "value": 14.0,
      "unit": "GB",
      "threshold_source": "fragment_contract"
    },
    "bottleneck_identified": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "d_kl_nats": false,
    "decode_tok_s": false,
    "ttft_seconds": false,
    "resident_memory_gb": true,
    "bottleneck_identified": true
  },
  "overall_pass": false,
  "fallback_tier": "Fail",
  "provider_receipts": [
    {
      "provider": "cloud-fp16-reference",
      "model_or_service": "llama-3.3-70b-fp16",
      "purpose": "reference_logits",
      "request_id_hash": "sha256:00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff",
      "timestamp_utc": "2026-05-18T19:04:00Z",
      "data_sent_class": "prompt_hash_only",
      "retention_claim": "zero_retention",
      "redaction_digest": "sha256:ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100",
      "replay_allowed": true,
      "artifact_ref": "artifacts/falsifiers/70b_local_cocktail_lite/../provider_reference.json",
      "artifact_ref_sha256": "sha256:9999999999999999999999999999999999999999999999999999999999999999"
    }
  ],
  "anomalies": [
    {
      "kind": "fallback_triggered",
      "description": "Cocktail missed the 70B reference thresholds.",
      "severity": "blocking",
      "axis": "d_kl_nats",
      "fallback_tier": "Fail",
      "affects_pass": true,
      "evidence_ref": "artifacts/falsifiers/70b_local_cocktail_lite/anomalies/provider_reference_miss.json",
      "evidence_ref_sha256": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ],
  "notes": "none"
}
```

Rejection reason: provider receipt `artifact_ref` uses a `..` segment, so the retained provider sidecar path is not replay-safe.

## N113 - Provider Receipt Artifact Ref Outside Row Root

Violates: [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule), [Artifact Root Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#artifact-root-rule), and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-70B-Local-Cocktail-Lite",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "failure_report",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_70b_local_cocktail_lite.sh",
  "command_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "not_used",
      "swift": "not_used",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "70b-cocktail-lite-50prompt-v1",
  "timestamp_utc": "2026-05-18T19:06:00Z",
  "result_digest": "sha256:8888888888888888888888888888888888888888888888888888888888888888",
  "measurements": {
    "d_kl_nats": {
      "value": 0.14,
      "unit": "nats",
      "evidence_kind": "direct_measurement"
    },
    "decode_tok_s": {
      "value": 4.5,
      "unit": "tok/s",
      "evidence_kind": "direct_measurement"
    },
    "ttft_seconds": {
      "value": 31.0,
      "unit": "s",
      "evidence_kind": "direct_measurement"
    },
    "resident_memory_gb": {
      "value": 13.8,
      "unit": "GB",
      "evidence_kind": "direct_measurement"
    },
    "bottleneck_identified": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    }
  },
  "acceptance_thresholds": {
    "d_kl_nats": {
      "operator": "<=",
      "value": 0.1,
      "unit": "nats",
      "threshold_source": "fragment_contract"
    },
    "decode_tok_s": {
      "operator": ">=",
      "value": 5.0,
      "unit": "tok/s",
      "threshold_source": "fragment_contract"
    },
    "ttft_seconds": {
      "operator": "<=",
      "value": 30.0,
      "unit": "s",
      "threshold_source": "fragment_contract"
    },
    "resident_memory_gb": {
      "operator": "<=",
      "value": 14.0,
      "unit": "GB",
      "threshold_source": "fragment_contract"
    },
    "bottleneck_identified": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "d_kl_nats": false,
    "decode_tok_s": false,
    "ttft_seconds": false,
    "resident_memory_gb": true,
    "bottleneck_identified": true
  },
  "overall_pass": false,
  "fallback_tier": "Fail",
  "provider_receipts": [
    {
      "provider": "cloud-fp16-reference",
      "model_or_service": "llama-3.3-70b-fp16",
      "purpose": "reference_logits",
      "request_id_hash": "sha256:1010101010101010101010101010101010101010101010101010101010101010",
      "timestamp_utc": "2026-05-18T19:06:00Z",
      "data_sent_class": "prompt_hash_only",
      "retention_claim": "zero_retention",
      "redaction_digest": "sha256:0101010101010101010101010101010101010101010101010101010101010101",
      "replay_allowed": true,
      "artifact_ref": "artifacts/falsifiers/page_gather/baseline/provider_reference.json",
      "artifact_ref_sha256": "sha256:abababababababababababababababababababababababababababababababab"
    }
  ],
  "anomalies": [
    {
      "kind": "fallback_triggered",
      "description": "Cocktail missed the 70B reference thresholds.",
      "severity": "blocking",
      "axis": "d_kl_nats",
      "fallback_tier": "Fail",
      "affects_pass": true,
      "evidence_ref": "artifacts/falsifiers/70b_local_cocktail_lite/anomalies/provider_reference_miss.json",
      "evidence_ref_sha256": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ],
  "notes": "none"
}
```

Rejection reason: provider receipt `artifact_ref` points outside `artifacts/falsifiers/70b_local_cocktail_lite/`, so provider replay material is not retained under the row root.

## N114 - Provider Receipt Claims No Sent Data

Violates: [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-70B-Local-Cocktail-Lite",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "failure_report",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_70b_local_cocktail_lite.sh",
  "command_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "not_used",
      "swift": "not_used",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "70b-cocktail-lite-50prompt-v1",
  "timestamp_utc": "2026-05-18T19:08:00Z",
  "result_digest": "sha256:1212121212121212121212121212121212121212121212121212121212121212",
  "measurements": {
    "d_kl_nats": {
      "value": 0.14,
      "unit": "nats",
      "evidence_kind": "direct_measurement"
    },
    "decode_tok_s": {
      "value": 4.5,
      "unit": "tok/s",
      "evidence_kind": "direct_measurement"
    },
    "ttft_seconds": {
      "value": 31.0,
      "unit": "s",
      "evidence_kind": "direct_measurement"
    },
    "resident_memory_gb": {
      "value": 13.8,
      "unit": "GB",
      "evidence_kind": "direct_measurement"
    },
    "bottleneck_identified": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    }
  },
  "acceptance_thresholds": {
    "d_kl_nats": {
      "operator": "<=",
      "value": 0.1,
      "unit": "nats",
      "threshold_source": "fragment_contract"
    },
    "decode_tok_s": {
      "operator": ">=",
      "value": 5.0,
      "unit": "tok/s",
      "threshold_source": "fragment_contract"
    },
    "ttft_seconds": {
      "operator": "<=",
      "value": 30.0,
      "unit": "s",
      "threshold_source": "fragment_contract"
    },
    "resident_memory_gb": {
      "operator": "<=",
      "value": 14.0,
      "unit": "GB",
      "threshold_source": "fragment_contract"
    },
    "bottleneck_identified": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "d_kl_nats": false,
    "decode_tok_s": false,
    "ttft_seconds": false,
    "resident_memory_gb": true,
    "bottleneck_identified": true
  },
  "overall_pass": false,
  "fallback_tier": "Fail",
  "provider_receipts": [
    {
      "provider": "cloud-fp16-reference",
      "model_or_service": "llama-3.3-70b-fp16",
      "purpose": "reference_logits",
      "request_id_hash": "sha256:2020202020202020202020202020202020202020202020202020202020202020",
      "timestamp_utc": "2026-05-18T19:08:00Z",
      "data_sent_class": "none",
      "retention_claim": "zero_retention",
      "redaction_digest": "sha256:0202020202020202020202020202020202020202020202020202020202020202",
      "replay_allowed": true,
      "artifact_ref": "artifacts/falsifiers/70b_local_cocktail_lite/provider_reference.json",
      "artifact_ref_sha256": "sha256:bcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbcbc"
    }
  ],
  "anomalies": [
    {
      "kind": "fallback_triggered",
      "description": "Cocktail missed the 70B reference thresholds.",
      "severity": "blocking",
      "axis": "d_kl_nats",
      "fallback_tier": "Fail",
      "affects_pass": true,
      "evidence_ref": "artifacts/falsifiers/70b_local_cocktail_lite/anomalies/provider_reference_miss.json",
      "evidence_ref_sha256": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ],
  "notes": "none"
}
```

Rejection reason: a present provider receipt cannot claim `data_sent_class=none`; local-only evidence omits `provider_receipts` or uses the explicit local-reference note path.

## N115 - Provider Receipt Disables Replay

Violates: [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-70B-Local-Cocktail-Lite",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "failure_report",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_70b_local_cocktail_lite.sh",
  "command_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "not_used",
      "swift": "not_used",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "70b-cocktail-lite-50prompt-v1",
  "timestamp_utc": "2026-05-18T19:10:00Z",
  "result_digest": "sha256:3434343434343434343434343434343434343434343434343434343434343434",
  "measurements": {
    "d_kl_nats": {
      "value": 0.14,
      "unit": "nats",
      "evidence_kind": "direct_measurement"
    },
    "decode_tok_s": {
      "value": 4.5,
      "unit": "tok/s",
      "evidence_kind": "direct_measurement"
    },
    "ttft_seconds": {
      "value": 31.0,
      "unit": "s",
      "evidence_kind": "direct_measurement"
    },
    "resident_memory_gb": {
      "value": 13.8,
      "unit": "GB",
      "evidence_kind": "direct_measurement"
    },
    "bottleneck_identified": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    }
  },
  "acceptance_thresholds": {
    "d_kl_nats": {
      "operator": "<=",
      "value": 0.1,
      "unit": "nats",
      "threshold_source": "fragment_contract"
    },
    "decode_tok_s": {
      "operator": ">=",
      "value": 5.0,
      "unit": "tok/s",
      "threshold_source": "fragment_contract"
    },
    "ttft_seconds": {
      "operator": "<=",
      "value": 30.0,
      "unit": "s",
      "threshold_source": "fragment_contract"
    },
    "resident_memory_gb": {
      "operator": "<=",
      "value": 14.0,
      "unit": "GB",
      "threshold_source": "fragment_contract"
    },
    "bottleneck_identified": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "d_kl_nats": false,
    "decode_tok_s": false,
    "ttft_seconds": false,
    "resident_memory_gb": true,
    "bottleneck_identified": true
  },
  "overall_pass": false,
  "fallback_tier": "Fail",
  "provider_receipts": [
    {
      "provider": "cloud-fp16-reference",
      "model_or_service": "llama-3.3-70b-fp16",
      "purpose": "reference_logits",
      "request_id_hash": "sha256:3030303030303030303030303030303030303030303030303030303030303030",
      "timestamp_utc": "2026-05-18T19:10:00Z",
      "data_sent_class": "prompt_hash_only",
      "retention_claim": "zero_retention",
      "redaction_digest": "sha256:0303030303030303030303030303030303030303030303030303030303030303",
      "replay_allowed": false,
      "artifact_ref": "artifacts/falsifiers/70b_local_cocktail_lite/provider_reference.json",
      "artifact_ref_sha256": "sha256:cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd"
    }
  ],
  "anomalies": [
    {
      "kind": "fallback_triggered",
      "description": "Cocktail missed the 70B reference thresholds.",
      "severity": "blocking",
      "axis": "d_kl_nats",
      "fallback_tier": "Fail",
      "affects_pass": true,
      "evidence_ref": "artifacts/falsifiers/70b_local_cocktail_lite/anomalies/provider_reference_miss.json",
      "evidence_ref_sha256": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ],
  "notes": "none"
}
```

Rejection reason: provider receipt `replay_allowed=false` means the referenced provider output cannot be replayed or promoted as witness evidence.

## N116 - Provider Pass Witness Uses Weak Retention

Violates: [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-70B-Local-Cocktail-Lite",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_70b_local_cocktail_lite.sh",
  "command_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "not_used",
      "swift": "not_used",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "70b-cocktail-lite-50prompt-v1",
  "timestamp_utc": "2026-05-18T19:12:00Z",
  "result_digest": "sha256:5656565656565656565656565656565656565656565656565656565656565656",
  "measurements": {
    "d_kl_nats": {
      "value": 0.08,
      "unit": "nats",
      "evidence_kind": "direct_measurement"
    },
    "decode_tok_s": {
      "value": 5.4,
      "unit": "tok/s",
      "evidence_kind": "direct_measurement"
    },
    "ttft_seconds": {
      "value": 26.0,
      "unit": "s",
      "evidence_kind": "direct_measurement"
    },
    "resident_memory_gb": {
      "value": 13.4,
      "unit": "GB",
      "evidence_kind": "direct_measurement"
    },
    "bottleneck_identified": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    }
  },
  "acceptance_thresholds": {
    "d_kl_nats": {
      "operator": "<=",
      "value": 0.1,
      "unit": "nats",
      "threshold_source": "fragment_contract"
    },
    "decode_tok_s": {
      "operator": ">=",
      "value": 5.0,
      "unit": "tok/s",
      "threshold_source": "fragment_contract"
    },
    "ttft_seconds": {
      "operator": "<=",
      "value": 30.0,
      "unit": "s",
      "threshold_source": "fragment_contract"
    },
    "resident_memory_gb": {
      "operator": "<=",
      "value": 14.0,
      "unit": "GB",
      "threshold_source": "fragment_contract"
    },
    "bottleneck_identified": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "d_kl_nats": true,
    "decode_tok_s": true,
    "ttft_seconds": true,
    "resident_memory_gb": true,
    "bottleneck_identified": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "provider_receipts": [
    {
      "provider": "cloud-fp16-reference",
      "model_or_service": "llama-3.3-70b-fp16",
      "purpose": "reference_logits",
      "request_id_hash": "sha256:4040404040404040404040404040404040404040404040404040404040404040",
      "timestamp_utc": "2026-05-18T19:12:00Z",
      "data_sent_class": "prompt_hash_only",
      "retention_claim": "provider_default",
      "redaction_digest": "sha256:0404040404040404040404040404040404040404040404040404040404040404",
      "replay_allowed": true,
      "artifact_ref": "artifacts/falsifiers/70b_local_cocktail_lite/provider_reference.json",
      "artifact_ref_sha256": "sha256:dededededededededededededededededededededededededededededededede"
    }
  ],
  "anomalies": [],
  "notes": "none"
}
```

Rejection reason: `overall_pass=true` with provider receipts requires `retention_claim=zero_retention`; provider-default retention is only historical failure-report evidence.

## N117 - Provider Receipt Sends Prompt Text

Violates: [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-70B-Local-Cocktail-Lite",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "failure_report",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_70b_local_cocktail_lite.sh",
  "command_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5 (24F74)",
    "toolchain_identity": {
      "xcodebuild": "not_used",
      "swift": "not_used",
      "rustc": "not_used",
      "python": "Python 3.12.4"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "0123456789abcdef0123456789abcdef01234567",
  "fixture_id": "70b-cocktail-lite-50prompt-v1",
  "timestamp_utc": "2026-05-18T19:14:00Z",
  "result_digest": "sha256:7878787878787878787878787878787878787878787878787878787878787878",
  "measurements": {
    "d_kl_nats": {
      "value": 0.14,
      "unit": "nats",
      "evidence_kind": "direct_measurement"
    },
    "decode_tok_s": {
      "value": 4.5,
      "unit": "tok/s",
      "evidence_kind": "direct_measurement"
    },
    "ttft_seconds": {
      "value": 31.0,
      "unit": "s",
      "evidence_kind": "direct_measurement"
    },
    "resident_memory_gb": {
      "value": 13.8,
      "unit": "GB",
      "evidence_kind": "direct_measurement"
    },
    "bottleneck_identified": {
      "value": true,
      "unit": "bool",
      "evidence_kind": "classification"
    }
  },
  "acceptance_thresholds": {
    "d_kl_nats": {
      "operator": "<=",
      "value": 0.1,
      "unit": "nats",
      "threshold_source": "fragment_contract"
    },
    "decode_tok_s": {
      "operator": ">=",
      "value": 5.0,
      "unit": "tok/s",
      "threshold_source": "fragment_contract"
    },
    "ttft_seconds": {
      "operator": "<=",
      "value": 30.0,
      "unit": "s",
      "threshold_source": "fragment_contract"
    },
    "resident_memory_gb": {
      "operator": "<=",
      "value": 14.0,
      "unit": "GB",
      "threshold_source": "fragment_contract"
    },
    "bottleneck_identified": {
      "operator": "==",
      "value": true,
      "unit": "bool",
      "threshold_source": "fragment_contract"
    }
  },
  "pass_per_axis": {
    "d_kl_nats": false,
    "decode_tok_s": false,
    "ttft_seconds": false,
    "resident_memory_gb": true,
    "bottleneck_identified": true
  },
  "overall_pass": false,
  "fallback_tier": "Fail",
  "provider_receipts": [
    {
      "provider": "cloud-fp16-reference",
      "model_or_service": "llama-3.3-70b-fp16",
      "purpose": "reference_logits",
      "request_id_hash": "sha256:5050505050505050505050505050505050505050505050505050505050505050",
      "timestamp_utc": "2026-05-18T19:14:00Z",
      "data_sent_class": "prompt_text",
      "retention_claim": "zero_retention",
      "redaction_digest": "sha256:0505050505050505050505050505050505050505050505050505050505050505",
      "replay_allowed": true,
      "artifact_ref": "artifacts/falsifiers/70b_local_cocktail_lite/provider_reference.json",
      "artifact_ref_sha256": "sha256:efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef"
    }
  ],
  "anomalies": [
    {
      "kind": "fallback_triggered",
      "description": "Cocktail missed the 70B reference thresholds.",
      "severity": "blocking",
      "axis": "d_kl_nats",
      "fallback_tier": "Fail",
      "affects_pass": true,
      "evidence_ref": "artifacts/falsifiers/70b_local_cocktail_lite/anomalies/provider_reference_miss.json",
      "evidence_ref_sha256": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ],
  "notes": "none"
}
```

Rejection reason: `data_sent_class=prompt_text` is not allowed; provider receipts must record hash-only, fixture-subset, or metrics-only sent data classes.

## N118 - Migration Note Missing Gap Tokens

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape), [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule), and [Schema Version Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-version-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T19:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=gap_tokens; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; reviewer=jojo; reviewed_at_utc=2026-05-18T19:35:00Z"
}
```

Rejection reason: `from_schema=` migration notes must include every schema-table `*_gap_report` token required by the post-witness migration rule.

## N119 - Malformed Migration Gap Token

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T19:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=gap_tokens; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=needs review; reviewer=jojo; reviewed_at_utc=2026-05-18T19:45:00Z"
}
```

Rejection reason: migration gap token values must match the schema's machine-token grammar; `artifact_kind_gap_report=needs review` contains whitespace.

## N120 - Missing Notes Length Migration Rationale

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Artifact Validator Shape](ARTIFACT_VALIDATOR_SHAPE_2026_05_18.md).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T19:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=gap_tokens; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=none; axis_gap_report=none; anomaly_gap_report=none; anomaly_evidence_gap_report=none; measurement_kind_gap_report=none; threshold_source_gap_report=none; notes_reviewer_gap_report=none; notes_reviewer_sentinel_gap_report=none; notes_review_timestamp_gap_report=none; notes_token_delimiter_gap_report=none; notes_length_gap_report=ulp_oracle; notes_token_key_gap_report=none; local_reference_gap_report=none; local_reference_root_gap_report=none; local_reference_dot_segment_gap_report=none; provider_data_sent_class_gap_report=none; provider_replay_permission_gap_report=none; provider_pass_retention_gap_report=none; provider_artifact_root_gap_report=none; provider_artifact_dot_segment_gap_report=none; command_digest_gap_report=none; fixture_lineage_gap_report=none; aggregate_sample_gap_report=none; sidecar_digest_gap_report=none; runner_environment_gap_report=none; timing_environment_gap_report=none; reviewer=jojo; reviewed_at_utc=2026-05-18T19:55:00Z"
}
```

Rejection reason: a notes length migration must state `notes_length_old_cap`, `notes_length_new_cap`, and `notes_length_reason`; `notes_length_gap_report=ulp_oracle` names an artifact but not the capacity rationale tokens.

## N121 - Zero Notes Length Migration Cap

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T20:00:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=gap_tokens; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=none; axis_gap_report=none; anomaly_gap_report=none; anomaly_evidence_gap_report=none; measurement_kind_gap_report=none; threshold_source_gap_report=none; notes_reviewer_gap_report=none; notes_reviewer_sentinel_gap_report=none; notes_review_timestamp_gap_report=none; notes_token_delimiter_gap_report=none; notes_length_gap_report=ulp_oracle; notes_length_old_cap=0; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=none; local_reference_gap_report=none; local_reference_root_gap_report=none; local_reference_dot_segment_gap_report=none; provider_data_sent_class_gap_report=none; provider_replay_permission_gap_report=none; provider_pass_retention_gap_report=none; provider_artifact_root_gap_report=none; provider_artifact_dot_segment_gap_report=none; command_digest_gap_report=none; fixture_lineage_gap_report=none; aggregate_sample_gap_report=none; sidecar_digest_gap_report=none; runner_environment_gap_report=none; timing_environment_gap_report=none; reviewer=jojo; reviewed_at_utc=2026-05-18T20:05:00Z"
}
```

Rejection reason: `notes_length_old_cap` and `notes_length_new_cap` must be positive integers; zero cannot describe a valid historical or target notes cap.

## N122 - Non-Increasing Notes Length Migration Cap

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T20:10:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=gap_tokens; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=none; axis_gap_report=none; anomaly_gap_report=none; anomaly_evidence_gap_report=none; measurement_kind_gap_report=none; threshold_source_gap_report=none; notes_reviewer_gap_report=none; notes_reviewer_sentinel_gap_report=none; notes_review_timestamp_gap_report=none; notes_token_delimiter_gap_report=none; notes_length_gap_report=ulp_oracle; notes_length_old_cap=1536; notes_length_new_cap=1024; notes_length_reason=full_token_set; notes_token_key_gap_report=none; local_reference_gap_report=none; local_reference_root_gap_report=none; local_reference_dot_segment_gap_report=none; provider_data_sent_class_gap_report=none; provider_replay_permission_gap_report=none; provider_pass_retention_gap_report=none; provider_artifact_root_gap_report=none; provider_artifact_dot_segment_gap_report=none; command_digest_gap_report=none; fixture_lineage_gap_report=none; aggregate_sample_gap_report=none; sidecar_digest_gap_report=none; runner_environment_gap_report=none; timing_environment_gap_report=none; reviewer=jojo; reviewed_at_utc=2026-05-18T20:15:00Z"
}
```

Rejection reason: `notes_length_new_cap` must be greater than `notes_length_old_cap`; a shrink would discard migration-token capacity instead of preserving replayability.

## N123 - Invalid Notes Length Migration Reason

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T20:20:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=gap_tokens; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=none; axis_gap_report=none; anomaly_gap_report=none; anomaly_evidence_gap_report=none; measurement_kind_gap_report=none; threshold_source_gap_report=none; notes_reviewer_gap_report=none; notes_reviewer_sentinel_gap_report=none; notes_review_timestamp_gap_report=none; notes_token_delimiter_gap_report=none; notes_length_gap_report=ulp_oracle; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=needs_more_room; notes_token_key_gap_report=none; local_reference_gap_report=none; local_reference_root_gap_report=none; local_reference_dot_segment_gap_report=none; provider_data_sent_class_gap_report=none; provider_replay_permission_gap_report=none; provider_pass_retention_gap_report=none; provider_artifact_root_gap_report=none; provider_artifact_dot_segment_gap_report=none; command_digest_gap_report=none; fixture_lineage_gap_report=none; aggregate_sample_gap_report=none; sidecar_digest_gap_report=none; runner_environment_gap_report=none; timing_environment_gap_report=none; reviewer=jojo; reviewed_at_utc=2026-05-18T20:25:00Z"
}
```

Rejection reason: `notes_length_reason` must use the closed reason vocabulary: `full_token_set`, `reviewer_token_set`, or `validator_gap_tokens`.

## N124 - Missing Migration Validator Identity

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T20:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=gap_tokens; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=none; axis_gap_report=none; anomaly_gap_report=none; anomaly_evidence_gap_report=none; measurement_kind_gap_report=none; threshold_source_gap_report=none; notes_reviewer_gap_report=none; notes_reviewer_sentinel_gap_report=none; notes_review_timestamp_gap_report=none; notes_token_delimiter_gap_report=none; notes_length_gap_report=ulp_oracle; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=none; local_reference_gap_report=none; local_reference_root_gap_report=none; local_reference_dot_segment_gap_report=none; provider_data_sent_class_gap_report=none; provider_replay_permission_gap_report=none; provider_pass_retention_gap_report=none; provider_artifact_root_gap_report=none; provider_artifact_dot_segment_gap_report=none; command_digest_gap_report=none; fixture_lineage_gap_report=none; aggregate_sample_gap_report=none; sidecar_digest_gap_report=none; runner_environment_gap_report=none; timing_environment_gap_report=none; reviewer=jojo; reviewed_at_utc=2026-05-18T20:35:00Z"
}
```

Rejection reason: `from_schema=` migration notes must include a machine-readable `validator=<id>` token separate from `reviewer=<id>`.

## N125 - Equal Migration Validator And Reviewer

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T20:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=gap_tokens; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=none; axis_gap_report=none; anomaly_gap_report=none; anomaly_evidence_gap_report=none; measurement_kind_gap_report=none; threshold_source_gap_report=none; notes_reviewer_gap_report=none; notes_reviewer_sentinel_gap_report=none; notes_review_timestamp_gap_report=none; notes_token_delimiter_gap_report=none; notes_length_gap_report=ulp_oracle; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=none; local_reference_gap_report=none; local_reference_root_gap_report=none; local_reference_dot_segment_gap_report=none; provider_data_sent_class_gap_report=none; provider_replay_permission_gap_report=none; provider_pass_retention_gap_report=none; provider_artifact_root_gap_report=none; provider_artifact_dot_segment_gap_report=none; command_digest_gap_report=none; fixture_lineage_gap_report=none; aggregate_sample_gap_report=none; sidecar_digest_gap_report=none; runner_environment_gap_report=none; timing_environment_gap_report=none; validator=jojo; reviewer=jojo; reviewed_at_utc=2026-05-18T20:45:00Z"
}
```

Rejection reason: `validator` and `reviewer` must be distinct migration attestations; equal values collapse tool validation and human review.

## N126 - Reserved Migration Validator Identity

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T20:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=gap_tokens; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=none; axis_gap_report=none; anomaly_gap_report=none; anomaly_evidence_gap_report=none; measurement_kind_gap_report=none; threshold_source_gap_report=none; notes_reviewer_gap_report=none; notes_reviewer_sentinel_gap_report=none; notes_review_timestamp_gap_report=none; notes_token_delimiter_gap_report=none; notes_length_gap_report=ulp_oracle; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=none; local_reference_gap_report=none; local_reference_root_gap_report=none; local_reference_dot_segment_gap_report=none; provider_data_sent_class_gap_report=none; provider_replay_permission_gap_report=none; provider_pass_retention_gap_report=none; provider_artifact_root_gap_report=none; provider_artifact_dot_segment_gap_report=none; command_digest_gap_report=none; fixture_lineage_gap_report=none; aggregate_sample_gap_report=none; sidecar_digest_gap_report=none; runner_environment_gap_report=none; timing_environment_gap_report=none; validator=unknown; reviewer=jojo; reviewed_at_utc=2026-05-18T20:55:00Z"
}
```

Rejection reason: reserved validator identities `anonymous`, `unknown`, `tbd`, and `none` are invalid for migration acceptance.

## N127 - Uppercase Migration Validator Identity

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T21:00:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=gap_tokens; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=none; axis_gap_report=none; anomaly_gap_report=none; anomaly_evidence_gap_report=none; measurement_kind_gap_report=none; threshold_source_gap_report=none; notes_reviewer_gap_report=none; notes_reviewer_sentinel_gap_report=none; notes_review_timestamp_gap_report=none; notes_token_delimiter_gap_report=none; notes_length_gap_report=ulp_oracle; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=none; local_reference_gap_report=none; local_reference_root_gap_report=none; local_reference_dot_segment_gap_report=none; provider_data_sent_class_gap_report=none; provider_replay_permission_gap_report=none; provider_pass_retention_gap_report=none; provider_artifact_root_gap_report=none; provider_artifact_dot_segment_gap_report=none; command_digest_gap_report=none; fixture_lineage_gap_report=none; aggregate_sample_gap_report=none; sidecar_digest_gap_report=none; runner_environment_gap_report=none; timing_environment_gap_report=none; validator=SchemaValidator; reviewer=jojo; reviewed_at_utc=2026-05-18T21:05:00Z"
}
```

Rejection reason: `validator` must match the lowercase-slug grammar `^[a-z0-9][a-z0-9._-]*$`; uppercase `SchemaValidator` is invalid for migration acceptance.

## N128 - Uppercase Reviewer Identity

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule), [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape), and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T21:10:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=gap_tokens; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=none; axis_gap_report=none; anomaly_gap_report=none; anomaly_evidence_gap_report=none; measurement_kind_gap_report=none; threshold_source_gap_report=none; notes_reviewer_gap_report=none; notes_reviewer_sentinel_gap_report=none; notes_review_timestamp_gap_report=none; notes_token_delimiter_gap_report=none; notes_length_gap_report=ulp_oracle; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=none; local_reference_gap_report=none; local_reference_root_gap_report=none; local_reference_dot_segment_gap_report=none; provider_data_sent_class_gap_report=none; provider_replay_permission_gap_report=none; provider_pass_retention_gap_report=none; provider_artifact_root_gap_report=none; provider_artifact_dot_segment_gap_report=none; command_digest_gap_report=none; fixture_lineage_gap_report=none; aggregate_sample_gap_report=none; sidecar_digest_gap_report=none; runner_environment_gap_report=none; timing_environment_gap_report=none; validator=schema-validator; reviewer=Jojo; reviewed_at_utc=2026-05-18T21:15:00Z"
}
```

Rejection reason: `reviewer` must match the lowercase-slug grammar `^[a-z0-9][a-z0-9._-]*$`; uppercase `Jojo` is invalid for anomaly and migration review.

## N129 - Reserved Migration Reviewer Identity

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule), [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape), and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T21:20:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=gap_tokens; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=none; axis_gap_report=none; anomaly_gap_report=none; anomaly_evidence_gap_report=none; measurement_kind_gap_report=none; threshold_source_gap_report=none; notes_reviewer_gap_report=none; notes_reviewer_sentinel_gap_report=none; notes_review_timestamp_gap_report=none; notes_token_delimiter_gap_report=none; notes_length_gap_report=ulp_oracle; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=none; local_reference_gap_report=none; local_reference_root_gap_report=none; local_reference_dot_segment_gap_report=none; provider_data_sent_class_gap_report=none; provider_replay_permission_gap_report=none; provider_pass_retention_gap_report=none; provider_artifact_root_gap_report=none; provider_artifact_dot_segment_gap_report=none; command_digest_gap_report=none; fixture_lineage_gap_report=none; aggregate_sample_gap_report=none; sidecar_digest_gap_report=none; runner_environment_gap_report=none; timing_environment_gap_report=none; validator=schema-validator; reviewer=unknown; reviewed_at_utc=2026-05-18T21:25:00Z"
}
```

Rejection reason: reserved reviewer identities `anonymous`, `unknown`, `tbd`, and `none` are invalid for migration acceptance.

## N130 - Embedded Migration Validator Identity

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T21:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=validator=schema-validator; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; reviewer=jojo; reviewed_at_utc=2026-05-18T21:35:00Z"
}
```

Rejection reason: `validator=schema-validator` appears only inside another token value, so no delimiter-bounded migration `validator` token exists.

## N131 - Embedded Migration Reviewer Identity

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule), [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule), and [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T21:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=reviewer=jojo; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewed_at_utc=2026-05-18T21:45:00Z"
}
```

Rejection reason: `reviewer=jojo` appears only inside another token value, so no delimiter-bounded migration `reviewer` token exists.

## N132 - Embedded Review-Time Migration Token

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule), [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule), and [Timestamp Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#timestamp-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T21:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=reviewed_at_utc=2026-05-18T21:55:00Z; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo"
}
```

Rejection reason: `reviewed_at_utc=2026-05-18T21:55:00Z` appears only inside another token value, so no delimiter-bounded migration review-time token exists.

## N133 - Embedded From-Schema Migration Token

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Schema Version Migration Plan](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-version-migration-plan).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T22:00:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=from_schema=2026-05-18.2; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-18T22:05:00Z"
}
```

Rejection reason: `from_schema=2026-05-18.2` appears only inside another token value, so no delimiter-bounded source schema version exists.

## N134 - Embedded To-Schema Migration Token

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Schema Version Migration Plan](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-version-migration-plan).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T22:10:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=to_schema=2026-05-18.3; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-18T22:15:00Z"
}
```

Rejection reason: `to_schema=2026-05-18.3` appears only inside another token value, so no delimiter-bounded destination schema version exists.

## N135 - Embedded Migration Artifact Path

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T22:20:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-18T22:25:00Z"
}
```

Rejection reason: `artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json` appears only inside another token value, so no delimiter-bounded migration artifact path exists.

## N136 - Embedded Migration Command

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T22:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=migration_command=tools/falsifiers/migrate_schema.sh; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-18T22:35:00Z"
}
```

Rejection reason: `migration_command=tools/falsifiers/migrate_schema.sh` appears only inside another token value, so no delimiter-bounded migration command exists.

## N137 - Embedded Field Mapping

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Schema Version Migration Plan](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-version-migration-plan).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T22:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=field_mapping=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-18T22:45:00Z"
}
```

Rejection reason: `field_mapping=x` appears only inside another token value, so no delimiter-bounded field mapping exists for migration review.

## N138 - Embedded Schema Digest Before

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Schema Fragment Digest Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-fragment-digest-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T22:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-18T22:55:00Z"
}
```

Rejection reason: `schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333` appears only inside another token value, so no delimiter-bounded pre-migration schema digest exists.

## N139 - Embedded Schema Digest After

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Schema Fragment Digest Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-fragment-digest-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T23:00:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-18T23:05:00Z"
}
```

Rejection reason: `schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444` appears only inside another token value, so no delimiter-bounded post-migration schema digest exists.

## N140 - Embedded Artifact-Kind Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Schema Version Migration Plan](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#schema-version-migration-plan).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T23:10:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=artifact_kind_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-18T23:15:00Z"
}
```

Rejection reason: `artifact_kind_gap_report=x` appears only inside another token value, so no delimiter-bounded artifact-kind gap report exists.

## N141 - Embedded Axis Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Axis Consistency Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#axis-consistency-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T23:20:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=axis_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-18T23:25:00Z"
}
```

Rejection reason: `axis_gap_report=x` appears only inside another token value, so no delimiter-bounded axis gap report exists.

## N142 - Embedded Anomaly Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Anomaly Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomaly-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T23:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=anomaly_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-18T23:35:00Z"
}
```

Rejection reason: `anomaly_gap_report=x` appears only inside another token value, so no delimiter-bounded anomaly gap report exists.

## N143 - Embedded Anomaly Evidence Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Anomaly Evidence Reference Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#anomaly-evidence-reference-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T23:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=anomaly_evidence_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-18T23:45:00Z"
}
```

Rejection reason: `anomaly_evidence_gap_report=x` appears only inside another token value, so no delimiter-bounded anomaly-evidence gap report exists.

## N144 - Embedded Measurement-Kind Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Measurement Evidence-Kind Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#measurement-evidence-kind-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-18T23:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=measurement_kind_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-18T23:55:00Z"
}
```

Rejection reason: `measurement_kind_gap_report=x` appears only inside another token value, so no delimiter-bounded measurement-kind gap report exists.

## N145 - Embedded Threshold-Source Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Threshold Source Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#threshold-source-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T00:00:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=threshold_source_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T00:05:00Z"
}
```

Rejection reason: `threshold_source_gap_report=x` appears only inside another token value, so no delimiter-bounded threshold-source gap report exists.

## N146 - Embedded Notes Reviewer Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T00:10:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=notes_reviewer_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T00:15:00Z"
}
```

Rejection reason: `notes_reviewer_gap_report=x` appears only inside another token value, so no delimiter-bounded notes-reviewer gap report exists.

## N147 - Embedded Reviewer-Sentinel Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T00:20:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=notes_reviewer_sentinel_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T00:25:00Z"
}
```

Rejection reason: `notes_reviewer_sentinel_gap_report=x` appears only inside another token value, so no delimiter-bounded reviewer-sentinel gap report exists.

## N148 - Embedded Review-Timestamp Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Timestamp Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#timestamp-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T00:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=notes_review_timestamp_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T00:35:00Z"
}
```

Rejection reason: `notes_review_timestamp_gap_report=x` appears only inside another token value, so no delimiter-bounded review-timestamp gap report exists.

## N149 - Embedded Token-Delimiter Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T00:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=notes_token_delimiter_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T00:45:00Z"
}
```

Rejection reason: `notes_token_delimiter_gap_report=x` appears only inside another token value, so no delimiter-bounded token-delimiter gap report exists.

## N150 - Embedded Notes-Length Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T00:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_artifact=notes_length_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T00:55:00Z"
}
```

Rejection reason: `notes_length_gap_report=x` appears only inside another token value, so no delimiter-bounded notes-length gap report exists.

## N151 - Embedded Token-Key Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T01:00:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; local_reference_artifact=notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T01:05:00Z"
}
```

Rejection reason: `notes_token_key_gap_report=x` appears only inside another token value, so no delimiter-bounded token-key gap report exists.

## N152 - Embedded Local-Reference Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Local Reference Artifact Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#local-reference-artifact-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T01:10:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; local_reference_artifact=local_reference_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T01:15:00Z"
}
```

Rejection reason: `local_reference_gap_report=x` appears only inside another token value, so no delimiter-bounded local-reference gap report exists.

## N153 - Embedded Local-Reference-Root Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Local Reference Artifact Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#local-reference-artifact-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T01:20:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_dot_segment_gap_report=x; local_reference_artifact=local_reference_root_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T01:25:00Z"
}
```

Rejection reason: `local_reference_root_gap_report=x` appears only inside another token value, so no delimiter-bounded local-reference-root gap report exists.

## N154 - Embedded Local-Reference Dot-Segment Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Local Reference Artifact Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#local-reference-artifact-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T01:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_artifact=local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T01:35:00Z"
}
```

Rejection reason: `local_reference_dot_segment_gap_report=x` appears only inside another token value, so no delimiter-bounded local-reference dot-segment gap report exists.

## N155 - Embedded Provider Data-Sent Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T01:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; local_reference_artifact=provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T01:45:00Z"
}
```

Rejection reason: `provider_data_sent_class_gap_report=x` appears only inside another token value, so no delimiter-bounded provider data-sent gap report exists.

## N156 - Embedded Provider Replay-Permission Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T01:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; local_reference_artifact=provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T01:55:00Z"
}
```

Rejection reason: `provider_replay_permission_gap_report=x` appears only inside another token value, so no delimiter-bounded provider replay-permission gap report exists.

## N157 - Embedded Provider Pass-Retention Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T02:00:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; local_reference_artifact=provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T02:05:00Z"
}
```

Rejection reason: `provider_pass_retention_gap_report=x` appears only inside another token value, so no delimiter-bounded provider pass-retention gap report exists.

## N158 - Embedded Provider Artifact-Root Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T02:10:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; local_reference_artifact=provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T02:15:00Z"
}
```

Rejection reason: `provider_artifact_root_gap_report=x` appears only inside another token value, so no delimiter-bounded provider artifact-root gap report exists.

## N159 - Embedded Provider Artifact Dot-Segment Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Provider Receipt Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#provider-receipt-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T02:20:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; local_reference_artifact=provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T02:25:00Z"
}
```

Rejection reason: `provider_artifact_dot_segment_gap_report=x` appears only inside another token value, so no delimiter-bounded provider artifact dot-segment gap report exists.

## N160 - Embedded Notes Length Old-Cap Token

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T02:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; local_reference_artifact=notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T02:35:00Z"
}
```

Rejection reason: `notes_length_old_cap=1024` appears only inside another token value, so no delimiter-bounded old-cap migration token exists.

## N161 - Embedded Notes Length New-Cap Token

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T02:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; local_reference_artifact=notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T02:45:00Z"
}
```

Rejection reason: `notes_length_new_cap=1536` appears only inside another token value, so no delimiter-bounded new-cap migration token exists.

## N162 - Embedded Notes Length Reason Token

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T02:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; local_reference_artifact=notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T02:55:00Z"
}
```

Rejection reason: `notes_length_reason=full_token_set` appears only inside another token value, so no delimiter-bounded length-reason migration token exists.

## N163 - Embedded Anomaly Inspection Token

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T03:00:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "local_reference_artifact=anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T03:05:00Z"
}
```

Rejection reason: `anomaly_inspection=complete` appears only inside another token value, so no delimiter-bounded anomaly inspection token exists.

## N164 - Embedded Notes Reviewer Token

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T03:10:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; local_reference_artifact=reviewer=jojo; reviewed_at_utc=2026-05-19T03:15:00Z"
}
```

Rejection reason: `reviewer=jojo` appears only inside another token value, so no delimiter-bounded notes reviewer token exists.

## N165 - Embedded Notes Review-Time Token

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T03:20:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; local_reference_artifact=reviewed_at_utc=2026-05-19T03:25:00Z"
}
```

Rejection reason: `reviewed_at_utc=2026-05-19T03:25:00Z` appears only inside another token value, so no delimiter-bounded notes review-time token exists.

## N166 - Bounded Reserved Reviewer Sentinel

Violates: [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule) and [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T03:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=none; reviewed_at_utc=2026-05-19T03:35:00Z"
}
```

Rejection reason: `reviewer=none` is a delimiter-bounded reserved reviewer sentinel, so it cannot identify the accountable reviewer.

## N167 - Bounded Reserved Validator Sentinel

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T03:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=none; reviewer=jojo; reviewed_at_utc=2026-05-19T03:45:00Z"
}
```

Rejection reason: `validator=none` is a delimiter-bounded reserved validator sentinel, so it cannot identify the conformance checker.

## N168 - Embedded Validator Sentinel

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T03:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; local_reference_artifact=validator=none; reviewer=jojo; reviewed_at_utc=2026-05-19T03:55:00Z"
}
```

Rejection reason: `validator=none` appears only inside another token value, so no delimiter-bounded validator token or validator sentinel evidence exists.

## N169 - Embedded Reviewer Sentinel

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T04:00:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; local_reference_artifact=reviewer=none; reviewed_at_utc=2026-05-19T04:05:00Z"
}
```

Rejection reason: `reviewer=none` appears only inside another token value, so no delimiter-bounded reviewer token or reviewer sentinel evidence exists.

## N170 - Paired Reserved Migration Identities

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T04:10:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=none; reviewer=unknown; reviewed_at_utc=2026-05-19T04:15:00Z"
}
```

Rejection reason: bounded `validator=none` and `reviewer=unknown` both use the shared reserved migration identity sentinel set.

## N171 - Missing Identity Sentinel Gap Report

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T04:20:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T04:25:00Z"
}
```

Rejection reason: the migration note omits `identity_sentinel_gap_report`, so validator and reviewer sentinel impacts are not separately named.

## N172 - Embedded Identity Sentinel Gap Report

Violates: [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule) and [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T04:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; local_reference_artifact=identity_sentinel_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T04:35:00Z"
}
```

Rejection reason: `identity_sentinel_gap_report=x` appears only inside another token value, so the delimiter-bounded sentinel gap report is absent.

## N173 - Unlabeled Identity Sentinel Gap Report

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T04:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=changed; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T04:45:00Z"
}
```

Rejection reason: `identity_sentinel_gap_report=changed` is delimiter-bounded but lacks required `validator:<impact>,reviewer:<impact>` role labels.

## N174 - Reserved Identity Gap Role Value

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T04:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:none,reviewer:changed; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T04:55:00Z"
}
```

Rejection reason: `identity_sentinel_gap_report` uses the reserved role-impact value `validator:none`.

## N175 - Comma Bearing Identity Gap Value

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T05:00:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:changed,extra,reviewer:changed; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T05:05:00Z"
}
```

Rejection reason: `validator:changed,extra` uses a comma inside a role-impact value, colliding with the role separator.

## N176 - Uppercase Identity Gap Atom

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T05:10:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:Changed,reviewer:changed; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T05:15:00Z"
}
```

Rejection reason: `validator:Changed` is not a lowercase slug atom.

## N177 - Identical Identity Gap Impacts

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Notes Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#notes-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T05:20:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:changed,reviewer:changed; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T05:25:00Z"
}
```

Rejection reason: validator and reviewer role-impact values are both `changed`, so the identity gap does not distinguish role-specific impact.

## N178 - Detached Identity Gap Aggregate

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T05:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:validator-impact,reviewer:reviewer-impact; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T05:35:00Z"
}
```

Rejection reason: the identity sentinel gap report is present but no `artifact_path` token binds it to an affected artifact.

## N179 - Identity Gap Missing Old New States

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T05:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:changed,reviewer:updated; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T05:45:00Z"
}
```

Rejection reason: the identity gap role values are distinct slugs, but they do not use the required `old-<state>-new-<state>` transition shape.

## N180 - Half Old New Identity Gap

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T05:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old-anonymous-new-blocked,reviewer:updated; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T05:55:00Z"
}
```

Rejection reason: only the validator role-impact uses `old-<state>-new-<state>`, so the reviewer transition is not migration-auditable.

## N181 - Swapped Half Old New Identity Gap

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T06:00:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:changed,reviewer:old-unknown-new-blocked; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T06:05:00Z"
}
```

Rejection reason: only the reviewer role-impact uses `old-<state>-new-<state>`, so the validator transition is not migration-auditable.

## N182 - Empty Old State Identity Gap

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T06:10:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old--new-blocked,reviewer:old-unknown-new-blocked; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T06:15:00Z"
}
```

Rejection reason: `validator:old--new-blocked` has no old-state atom between `old-` and `-new-`.

## N183 - Empty New State Identity Gap

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T06:20:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old-anonymous-new-,reviewer:old-unknown-new-blocked; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T06:25:00Z"
}
```

Rejection reason: `validator:old-anonymous-new-` has no new-state atom after `-new-`.

## N184 - Reversed Old New Identity Gap

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T06:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:new-blocked-old-anonymous,reviewer:old-unknown-new-blocked; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T06:35:00Z"
}
```

Rejection reason: `validator:new-blocked-old-anonymous` reverses the required `old-<state>-new-<state>` transition order.

## N185 - Nested Old Marker Identity Gap

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T06:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old-old-anonymous-new-blocked,reviewer:old-unknown-new-blocked; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T06:45:00Z"
}
```

Rejection reason: `old-old-anonymous-new-blocked` embeds a second `old-` marker inside the old-state atom.

## N186 - Nested New Marker Identity Gap

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T06:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old-anonymous-new-new-blocked,reviewer:old-unknown-new-blocked; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T06:55:00Z"
}
```

Rejection reason: `old-anonymous-new-new-blocked` embeds a second `-new-` marker inside the new-state atom.

## N187 - Leading Dot Identity Gap State

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T07:00:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old-.anonymous-new-blocked,reviewer:old-unknown-new-blocked; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T07:05:00Z"
}
```

Rejection reason: the old-state atom starts with `.`, but identity gap state atoms must begin with lowercase alphanumeric text.

## N188 - Leading Hyphen Identity Gap State

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T07:10:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old--anonymous-new-blocked,reviewer:old-unknown-new-blocked; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T07:15:00Z"
}
```

Rejection reason: the old-state atom starts with `-`, but identity gap state atoms must begin with lowercase alphanumeric text.

## N189 - Trailing Dot Identity Gap State

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T07:20:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old-anonymous.-new-blocked,reviewer:old-unknown-new-blocked; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T07:25:00Z"
}
```

Rejection reason: the old-state atom ends with `.`, but identity gap state atoms must end with lowercase alphanumeric text.

## N190 - Trailing Hyphen Identity Gap State

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T07:30:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old-anonymous--new-blocked,reviewer:old-unknown-new-blocked; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T07:35:00Z"
}
```

Rejection reason: the old-state atom ends with `-`, but identity gap state atoms must end with lowercase alphanumeric text.

## N191 - Leading Underscore Identity Gap State

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T07:40:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old-_anonymous-new-blocked,reviewer:old-unknown-new-blocked; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T07:45:00Z"
}
```

Rejection reason: the old-state atom starts with `_`, but identity gap state atoms must begin with lowercase alphanumeric text.

## N192 - Trailing Underscore Identity Gap State

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T07:50:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old-anonymous_-new-blocked,reviewer:old-unknown-new-blocked; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T07:55:00Z"
}
```

Rejection reason: the old-state atom ends with `_`, but identity gap state atoms must end with lowercase alphanumeric text.

## N193 - Duplicate Numeric Identity Gap Role Values

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape) and [Migration Note Token Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-token-rule).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T08:05:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old-1-new-2,reviewer:old-1-new-2; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T08:05:30Z"
}
```

Rejection reason: numeric-only state atoms are allowed, but validator and reviewer role-impact values must remain distinct.

## N194 - Reserved Word Identity Gap State Atom

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T08:15:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old-none-new-blocked,reviewer:old-unknown-new-updated; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T08:15:30Z"
}
```

Rejection reason: `none` is a reserved identity sentinel, so it cannot stand as an old-state atom inside `identity_sentinel_gap_report`.

## N195 - Reserved Word Identity Gap New State Atom

Violates: [Migration Note Minimum Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#migration-note-minimum-shape).

```json
{
  "falsifier_id": "F-ULP-Oracle",
  "schema_version": "2026-05-18.2",
  "artifact_kind": "primary_witness",
  "hardware_pin": {
    "machine": "M2 Pro 14-inch 2023",
    "cpu": "12-core CPU",
    "gpu": "19-core GPU",
    "unified_memory_gb": 16,
    "memory_bandwidth_gb_s": 200
  },
  "command": "tools/falsifiers/f_ulp_oracle.sh",
  "command_digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "runner_environment": {
    "cwd": "repo_root",
    "shell": "zsh",
    "env_policy": "script_owned",
    "locale": "C",
    "timezone": "UTC",
    "os_build": "macOS 15.5",
    "toolchain_identity": {
      "xcodebuild": "16.4",
      "swift": "6.1",
      "rustc": "not_used",
      "python": "3.12"
    },
    "thermal_state_start": "nominal",
    "thermal_state_end": "nominal",
    "power_source": "ac_power"
  },
  "commit_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "fixture_id": "ulp-oracle-loggrid-v1",
  "timestamp_utc": "2026-05-19T08:35:00Z",
  "result_digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "measurements": {
    "max_ulp": {
      "value": 2,
      "unit": "ulp",
      "evidence_kind": "direct_measurement"
    }
  },
  "acceptance_thresholds": {
    "max_ulp": {
      "operator": "<=",
      "value": 2,
      "unit": "ulp",
      "threshold_source": "handbook_row"
    }
  },
  "pass_per_axis": {
    "max_ulp": true
  },
  "overall_pass": true,
  "fallback_tier": "Primary",
  "anomalies": [],
  "notes": "anomaly_inspection=complete; from_schema=2026-05-18.2; to_schema=2026-05-18.3; artifact_path=artifacts/falsifiers/f_ulp_oracle/result.json; migration_command=tools/falsifiers/migrate_schema.sh; field_mapping=x; schema_fragment_digest_before=sha256:3333333333333333333333333333333333333333333333333333333333333333; schema_fragment_digest_after=sha256:4444444444444444444444444444444444444444444444444444444444444444; artifact_kind_gap_report=x; axis_gap_report=x; anomaly_gap_report=x; anomaly_evidence_gap_report=x; measurement_kind_gap_report=x; threshold_source_gap_report=x; notes_reviewer_gap_report=x; notes_reviewer_sentinel_gap_report=x; identity_sentinel_gap_report=validator:old-blocked-new-none,reviewer:old-updated-new-unknown; notes_review_timestamp_gap_report=x; notes_token_delimiter_gap_report=x; notes_length_gap_report=x; notes_length_old_cap=1024; notes_length_new_cap=1536; notes_length_reason=full_token_set; notes_token_key_gap_report=x; local_reference_gap_report=x; local_reference_root_gap_report=x; local_reference_dot_segment_gap_report=x; provider_data_sent_class_gap_report=x; provider_replay_permission_gap_report=x; provider_pass_retention_gap_report=x; provider_artifact_root_gap_report=x; provider_artifact_dot_segment_gap_report=x; command_digest_gap_report=x; fixture_lineage_gap_report=x; aggregate_sample_gap_report=x; sidecar_digest_gap_report=x; runner_environment_gap_report=x; timing_environment_gap_report=x; validator=schema-validator; reviewer=jojo; reviewed_at_utc=2026-05-19T08:35:30Z"
}
```

Rejection reason: `none` and `unknown` are reserved identity sentinels, so they cannot stand as new-state atoms inside `identity_sentinel_gap_report`.

## N196 - Missing Identity Gap Slug Catalog Entry

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog) and [Validator Harness Shape](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#validator-harness-shape).

```json
{
  "catalog_slug": "missing-validator-role-impact",
  "negative_examples": ["N173"],
  "schema_catalog_present": false,
  "validator_shape_row_present": true,
  "handbook_audit_present": true
}
```

Rejection reason: identity-gap validator families must be cataloged in the schema before validator-shape or handbook references can use the slug.

## N197 - Underscore Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved_state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs must use lowercase hyphenated tokens; underscore aliases such as `reserved_state` are invalid.

## N198 - Title Case Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "Reserved-State",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs must use lowercase hyphenated tokens; title-case aliases such as `Reserved-State` are invalid.

## N199 - Leading Hyphen Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "-reserved-state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs must begin with lowercase alphanumeric text; leading-hyphen aliases such as `-reserved-state` are invalid.

## N200 - Trailing Hyphen Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved-state-",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs must end with lowercase alphanumeric text; trailing-hyphen aliases such as `reserved-state-` are invalid.

## N201 - Double Hyphen Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved--state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs must separate nonempty tokens with single hyphens; double-hyphen aliases such as `reserved--state` are invalid.

## N202 - Numeric Leading Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "1-reserved-state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs must begin with a lowercase letter; numeric-leading aliases such as `1-reserved-state` are invalid.

## N203 - Dotted Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved.state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; dotted aliases such as `reserved.state` are invalid.

## N204 - Spaced Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; spaced aliases such as `reserved state` are invalid.

## N205 - Comma Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved,state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; comma aliases such as `reserved,state` are invalid.

## N206 - Slash Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved/state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; slash aliases such as `reserved/state` are invalid.

## N207 - Colon Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved:state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; colon aliases such as `reserved:state` are invalid.

## N208 - Plus Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved+state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; plus aliases such as `reserved+state` are invalid.

## N209 - Ampersand Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved&state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; ampersand aliases such as `reserved&state` are invalid.

## N210 - At-Sign Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved@state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; at-sign aliases such as `reserved@state` are invalid.

## N211 - Leap-Second Timestamp

Violates: [Timestamp Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#timestamp-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "field": "timestamp_utc",
  "timestamp_utc": "2026-05-19T12:34:60Z",
  "schema_pattern": "^\\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\\d|3[01])T(?:[01]\\d|2[0-3]):[0-5]\\d:[0-5]\\d(?:\\.\\d+)?Z$"
}
```

Rejection reason: `timestamp_utc` seconds must be bounded from `00` through `59`; leap-second spellings such as `2026-05-19T12:34:60Z` are replay-ineligible.

## N212 - Uppercase Commit SHA

Violates: [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "field": "commit_sha",
  "commit_sha": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
  "schema_pattern": "^[0-9a-f]{40}$"
}
```

Rejection reason: `commit_sha` must be a full 40-character lowercase hex Git SHA; uppercase hex aliases are replay-ineligible even when the length is correct.

## N213 - Question Mark Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved?state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; question-mark aliases such as `reserved?state` are invalid.

## N214 - Hash Sign Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved#state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; hash-sign aliases such as `reserved#state` are invalid.

## N215 - Dollar Sign Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved$state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; dollar-sign aliases such as `reserved$state` are invalid.

## N216 - Percent Sign Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved%state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; percent-sign aliases such as `reserved%state` are invalid.

## N217 - Caret Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved^state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; caret aliases such as `reserved^state` are invalid.

## N218 - Asterisk Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved*state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; asterisk aliases such as `reserved*state` are invalid.

## N219 - Tilde Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved~state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; tilde aliases such as `reserved~state` are invalid.

## N220 - Backtick Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved`state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; backtick aliases such as `` reserved`state `` are invalid.

## N221 - Pipe Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved|state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; pipe aliases such as `reserved|state` are invalid.

## N222 - Backslash Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\\state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; backslash aliases such as `reserved\state` are invalid.

## N223 - Semicolon Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved;state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; semicolon aliases such as `reserved;state` are invalid.

## N224 - Exclamation Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved!state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; exclamation aliases such as `reserved!state` are invalid.

## N225 - Equals Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved=state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; equals aliases such as `reserved=state` are invalid.

## N226 - Single Quote Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved'state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; single-quote aliases such as `reserved'state` are invalid.

## N227 - Double Quote Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\"state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; double-quote aliases such as `reserved"state` are invalid.

## N228 - Open Paren Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved(state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; open-paren aliases such as `reserved(state` are invalid.

## N229 - Close Paren Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved)state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; close-paren aliases such as `reserved)state` are invalid.

## N230 - Open Bracket Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved[state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; open-bracket aliases such as `reserved[state` are invalid.

## N231 - Close Bracket Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved]state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; close-bracket aliases such as `reserved]state` are invalid.

## N232 - Open Brace Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved{state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; open-brace aliases such as `reserved{state` are invalid.

## N233 - Close Brace Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved}state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; close-brace aliases such as `reserved}state` are invalid.

## N234 - Less Than Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved<state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; less-than aliases such as `reserved<state` are invalid.

## N235 - Greater Than Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved>state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; greater-than aliases such as `reserved>state` are invalid.

## N236 - Tab Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\tstate",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; tab-character aliases that embed `\t` between atoms are invalid.

## N237 - Newline Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\nstate",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; newline-character aliases that embed `\n` between atoms are invalid.

## N238 - Empty String Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs must begin with a lowercase alphabetic character; an empty string fails the leading-`[a-z]` anchor of the slug grammar and is not a registerable catalog entry.

## N239 - Non-ASCII Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "réserved-state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase ASCII alphanumerics and internal hyphens only; non-ASCII characters such as `é` inside `réserved-state` are invalid because they extend the validator vocabulary beyond the schema's `[a-z0-9-]` allowance.

## N240 - Emoji Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved-🚀-state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase ASCII alphanumerics and internal hyphens only; emoji atoms such as `🚀` inside `reserved-🚀-state` introduce multi-byte code points that the slug grammar cannot anchor.

## N241 - Trailing Space Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved-state ",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; trailing whitespace such as the space after `reserved-state` breaks the closing `[a-z0-9]+` anchor and is invalid.

## N242 - Leading Space Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": " reserved-state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; leading whitespace such as the space before `reserved-state` breaks the leading `[a-z]` anchor and is invalid.

## N243 - Only Hyphen Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "----",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs must begin with a lowercase alphabetic character and may not consist exclusively of hyphens; hyphen-only aliases such as `----` carry no semantic atom and fail the leading-`[a-z]` anchor.

## N244 - Only Digit Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "12345",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs must begin with a lowercase alphabetic character; digit-only aliases such as `12345` carry no semantic family name and fail the leading-`[a-z]` anchor.

## N245 - BOM Prefix Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "\ufeffreserved-state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs must begin with a lowercase ASCII alphabetic byte; a `U+FEFF` byte-order-mark prefix before `reserved-state` breaks the leading-`[a-z]` anchor and is invalid for validator parsing.

## N246 - CRLF Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\r\nstate",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; CRLF separators such as `\r\n` between `reserved` and `state` smuggle line endings into a single-line slug and are invalid.

## N247 - NUL Character Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\u0000state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; a `U+0000` NUL byte between `reserved` and `state` smuggles a control character into a single-line slug and is invalid for validator parsing.

## N248 - Path Traversal Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "../reserved-state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; path-traversal aliases such as `../reserved-state` smuggle filesystem semantics into the validator vocabulary and fail both the leading-`[a-z]` anchor and the dot/slash exclusions.

## N249 - URL Encoded Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved%2Dstate",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; URL-encoded aliases such as `reserved%2Dstate` carry a percent character plus uppercase hex digits that the slug grammar does not accept even when the percent sequence decodes to a hyphen.

## N250 - Mixed Case Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "rEsErVeD-state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs must use lowercase ASCII alphanumerics only; mixed-case aliases such as `rEsErVeD-state` break the lowercase requirement even when the family meaning is otherwise preserved.

## N251 - Zero Width Space Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\u200bstate",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase ASCII alphanumerics and internal hyphens only; a `U+200B` zero-width-space between `reserved` and `state` is invisible to readers but extends the validator vocabulary beyond `[a-z0-9-]` and is invalid.

## N252 - Trailing Tab Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved-state\t",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; a trailing `\t` after `reserved-state` breaks the closing `[a-z0-9]+` anchor and is invalid for validator parsing.

## N253 - Carriage Return Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\rstate",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; a `\r` carriage-return between `reserved` and `state` smuggles a control character into a single-line slug and is invalid for validator parsing.

## N254 - Non-Breaking Space Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\u00a0state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase ASCII alphanumerics and internal hyphens only; a `U+00A0` non-breaking space between `reserved` and `state` extends the validator vocabulary beyond `[a-z0-9-]` and is invalid.

## N255 - En Dash Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\u2013state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase ASCII alphanumerics and internal ASCII hyphens only; a `U+2013` en-dash between `reserved` and `state` looks like a hyphen but extends the validator vocabulary beyond `[a-z0-9-]` and is invalid.

## N256 - Em Dash Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\u2014state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase ASCII alphanumerics and internal ASCII hyphens only; a `U+2014` em-dash between `reserved` and `state` looks like a wide hyphen but extends the validator vocabulary beyond `[a-z0-9-]` and is invalid.

## N257 - Soft Hyphen Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\u00adstate",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase ASCII alphanumerics and internal ASCII hyphens only; a `U+00AD` soft-hyphen between `reserved` and `state` is invisible in most renderers but extends the validator vocabulary beyond `[a-z0-9-]` and is invalid.

## N258 - Form Feed Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\fstate",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; a `\f` form-feed between `reserved` and `state` smuggles a control character into a single-line slug and is invalid for validator parsing.

## N259 - Vertical Tab Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\u000bstate",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase alphanumerics and internal hyphens only; a `U+000B` vertical-tab between `reserved` and `state` smuggles a control character into a single-line slug and is invalid for validator parsing.

## N260 - Ideographic Space Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\u3000state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase ASCII alphanumerics and internal hyphens only; a `U+3000` ideographic space between `reserved` and `state` extends the validator vocabulary beyond `[a-z0-9-]` and is invalid.

## N261 - Right-To-Left Override Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\u202estate",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase ASCII alphanumerics and internal hyphens only; a `U+202E` right-to-left override between `reserved` and `state` is a bidi-direction control that extends the validator vocabulary beyond `[a-z0-9-]` and can spoof readers, so it is rejected.

## N262 - Combining Diacritic Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserve\u0301d-state",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase ASCII alphanumerics and internal hyphens only; a `U+0301` combining acute accent after `reserve` extends the validator vocabulary beyond `[a-z0-9-]` even when it renders as `é` on screen, so it is rejected.

## N263 - Zero Width Joiner Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\u200dstate",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase ASCII alphanumerics and internal hyphens only; a `U+200D` zero-width joiner between `reserved` and `state` is an invisible cluster-binding control that extends the validator vocabulary beyond `[a-z0-9-]` and would collapse to a non-canonical glyph cluster, so it is rejected.

## N264 - Zero Width Non Joiner Identity Gap Slug

Violates: [Identity Gap Slug Catalog](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#identity-gap-slug-catalog).

```json
{
  "catalog_slug": "reserved\u200cstate",
  "negative_examples": ["N194", "N195"],
  "schema_catalog_present": true,
  "slug_grammar": "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
}
```

Rejection reason: identity-gap slugs may use lowercase ASCII alphanumerics and internal hyphens only; a `U+200C` zero-width non-joiner between `reserved` and `state` is an invisible cluster-breaking control that extends the validator vocabulary beyond `[a-z0-9-]` and silently changes shaping, so it is rejected.

## N265 - Refspec Commit SHA Alias

Violates: [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "field": "commit_sha",
  "commit_sha": "HEAD~1",
  "schema_pattern": "^[0-9a-f]{40}$"
}
```

Rejection reason: `commit_sha` must store the resolved 40-character lowercase hex commit, not a moving refspec alias such as `HEAD~1`.

## N266 - Branch Name Commit SHA Alias

Violates: [Replay Identity Rule](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-identity-rule) and [Replay-Ineligibility Checklist](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md#replay-ineligibility-checklist).

```json
{
  "field": "commit_sha",
  "commit_sha": "main",
  "schema_pattern": "^[0-9a-f]{40}$"
}
```

Rejection reason: `commit_sha` must store a resolved immutable commit, not a branch name whose target can move between replay attempts.
