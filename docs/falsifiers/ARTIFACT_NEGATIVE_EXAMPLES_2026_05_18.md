---
state: t23b-falsifier-artifact-negative-examples
created_on: 2026-05-18
schema_version: 2026-05-18.2
invalid_example_count: 21
---

# Artifact Negative Examples - 2026-05-18

This catalog preserves invalid witness shapes so future validators reject them deliberately instead of accepting plausible-looking logs.

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
