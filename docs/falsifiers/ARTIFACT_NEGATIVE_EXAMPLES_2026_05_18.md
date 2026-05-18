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
