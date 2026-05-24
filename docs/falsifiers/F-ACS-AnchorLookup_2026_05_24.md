---
falsifier: F-ACS-AnchorLookup
created_on: 2026-05-24
hardware_floor: M2 Pro 16 GB UMA
status: PASS
artifact: artifacts/falsifiers/acs_anchor_lookup/result.json
---

# F-ACS-AnchorLookup

## Result

PASS on one measured run over 10,000 claims.

Command:

```bash
cargo +stable run --manifest-path agent_core/Cargo.toml --bin acs_anchor_lookup
```

Measured artifact:

- `claim_count`: 10000
- `found_count`: 10000
- `avg_lookup_ns`: 516
- threshold: `< 1000 ns`
- invalid theorem id rejection: true

## Scope Note

The harness measures the MAS-safe `agent_core::uas::AcsAnchorRegistry` lookup
path. It validates that ACS (Anchored Cognitive Substrate) anchors retain
theorem, plane, residency, source, packet, compatibility, and salience fields,
and that invalid theorem ids fail closed.

## Acceptance

The falsifier passes iff all 10,000 claim anchors resolve, average lookup
latency is below 1 microsecond, projection fields survive lookup, and an
invalid theorem id is rejected.
