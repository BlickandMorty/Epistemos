---
state: t23b-falsifier-artifact-negative-examples
created_on: 2026-05-18
schema_version: 2026-05-18.2
invalid_example_count: 57
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
