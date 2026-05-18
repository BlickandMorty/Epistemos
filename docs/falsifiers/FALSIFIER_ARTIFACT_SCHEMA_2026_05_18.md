---
state: t23b-falsifier-artifact-schema
created_on: 2026-05-18
schema_version: 2026-05-18.1
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
---

# Falsifier Artifact Schema - 2026-05-18

This schema defines the canonical witness artifact contract for every T23B F-* falsifier. It generalizes the T12 F-ULP witness pattern into a shared document shape. A row in the M2 Pro Verified Floor Handbook may not claim runtime evidence unless its artifact uses this contract or a documented successor.

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

## JSON Schema Fragment

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.json",
  "title": "T23B Falsifier Artifact",
  "type": "object",
  "required": ["falsifier_id", "schema_version", "hardware_pin", "command", "commit_sha", "fixture_id", "timestamp_utc", "measurements"],
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
    }
  },
  "additionalProperties": true
}
```
