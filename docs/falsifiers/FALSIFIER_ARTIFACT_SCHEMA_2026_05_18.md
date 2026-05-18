---
state: t23b-falsifier-artifact-schema
created_on: 2026-05-18
schema_version: 2026-05-18.1
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
---

# Falsifier Artifact Schema - 2026-05-18

This schema defines the canonical witness artifact contract for every T23B F-* falsifier. It generalizes the T12 [F-ULP-Oracle](F_ULP_ORACLE_2026_05_18.md) witness pattern into a shared document shape. A row in the M2 Pro Verified Floor Handbook may not claim runtime evidence unless its artifact uses this contract or a documented successor.

## Initial Fields

| Field | Type | Required | Rule |
|---|---|---|---|
| `falsifier_id` | string | yes | Exact F-* identifier from the handbook row, for example `F-ULP-Oracle`. |
| `schema_version` | string | yes | Schema version for this artifact contract. Initial value: `2026-05-18.1`. |
| `hardware_pin` | object | yes | Jojo's M2 Pro hardware floor for the run; substitutes such as M2 Max, M3 Max, or theoretical bandwidth fail the artifact. |
| `command` | string | yes | Exact command line used to produce the artifact. It must match the row command after `NOT IMPLEMENTED:` is removed. |
| `commit_sha` | string | yes | Git commit SHA for the repo state that produced the artifact. Short SHAs are allowed only if unambiguous in the repo. |
| `fixture_id` | string | yes | Stable fixture identifier for the input set, including dataset/config version when applicable. |
| `timestamp_utc` | string | yes | UTC timestamp for artifact creation in RFC 3339 date-time form. Local time zones fail the artifact. |
| `measurements` | object | yes | Per-axis measured values from the run. Each axis must be named and must include a value plus unit. |
| `acceptance_thresholds` | object | yes | Per-axis pass criteria. Each threshold must name an operator, value, and unit so the artifact can be replayed against the handbook row. |
| `pass_per_axis` | object | yes | Per-axis boolean validator result. Axis names should match the measurement and threshold axes. |
| `overall_pass` | boolean | yes | Falsifier-level result after all required axes are evaluated. Runtime witness status requires `true`; preserved speculation remains non-witness. |
| `fallback_tier` | string | yes | T12 ladder value: `Primary`, `Fallback`, or `Fail`. `Fail` means no acceptable fallback runtime witness was produced. |
| `notes` | string | yes | Human-readable caveats or replay notes. Use `none` when there is nothing to add. |

## Hardware Pin Rule

`hardware_pin` must identify Jojo's M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s memory-bandwidth floor. M2 Max, M3 Max, cloud GPU, simulator, and theoretical-bandwidth substitutions fail schema validation.

## Replay Identity Rule

`command` must match the handbook row command after `NOT IMPLEMENTED:` is removed, and `commit_sha` must identify the repo state that produced the artifact. A witness with a stale command, missing commit, or commit from another branch is replay-ineligible.

## Fixture Identity Rule

`fixture_id` must be stable enough to recover the input corpus, generated-case grid, seed, configuration, and dataset version used by the run. A fixture label that cannot distinguish regenerated inputs from the original witness input set fails replay eligibility.

## Measurements Rule

`measurements` records observed run output only. Each axis must store the raw measured value and unit used by the falsifier, not a prose summary, target, or inferred pass label. Aggregate axes may add `samples`, `statistic`, or raw-artifact references, but the reported `value` must remain replay-computable from the committed artifact payload.

## Axis Consistency Rule

The keys under `measurements`, `acceptance_thresholds`, and `pass_per_axis` must describe the same axis set. Missing or extra axes fail artifact validation because they make the per-axis result non-replayable.

## Validation Boundary

The JSON Schema fragment is authoritative for top-level field presence, field types, enum values, and M2 Pro hardware constants. The axis consistency rule is enforced by replay validation because it compares key sets across fields.

## Fallback Tier Semantics

`Primary` means the exact row command and threshold passed on Jojo's M2 Pro hardware floor. `Fallback` means the documented fallback route produced an acceptable artifact, but the primary row remains not fully passed unless its row threshold explicitly accepts that route. `Fail` means neither primary nor fallback evidence satisfies the contract.

## JSON Schema Fragment

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.json",
  "title": "T23B Falsifier Artifact",
  "type": "object",
  "required": ["falsifier_id", "schema_version", "hardware_pin", "command", "commit_sha", "fixture_id", "timestamp_utc", "measurements", "acceptance_thresholds", "pass_per_axis", "overall_pass", "fallback_tier", "notes"],
  "properties": {
    "falsifier_id": {
      "type": "string",
      "pattern": "^F-[A-Za-z0-9][A-Za-z0-9-]*$"
    },
    "schema_version": {
      "type": "string",
      "const": "2026-05-18.1"
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
      "minLength": 1
    },
    "commit_sha": {
      "type": "string",
      "pattern": "^[0-9a-f]{7,40}$"
    },
    "fixture_id": {
      "type": "string",
      "minLength": 1
    },
    "timestamp_utc": {
      "type": "string",
      "format": "date-time"
    },
    "measurements": {
      "type": "object",
      "minProperties": 1,
      "patternProperties": {
        "^[a-z][a-z0-9_]*$": {
          "type": "object",
          "required": ["value", "unit"],
          "properties": {
            "value": {
              "type": ["number", "string", "boolean"]
            },
            "unit": {
              "type": "string",
              "minLength": 1
            },
            "samples": {
              "type": "array",
              "items": {
                "type": ["number", "string", "boolean"]
              }
            }
          },
          "additionalProperties": true
        }
      },
      "additionalProperties": false
    },
    "acceptance_thresholds": {
      "type": "object",
      "minProperties": 1,
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
              "minLength": 1
            }
          },
          "additionalProperties": true
        }
      },
      "additionalProperties": false
    },
    "pass_per_axis": {
      "type": "object",
      "minProperties": 1,
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
    "notes": {
      "type": "string",
      "minLength": 1
    }
  },
  "additionalProperties": false
}
```
