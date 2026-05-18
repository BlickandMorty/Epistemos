---
state: t23b-falsifier-artifact-negative-examples
created_on: 2026-05-18
schema_version: 2026-05-18.2
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
