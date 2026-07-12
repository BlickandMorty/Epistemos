# MAS C Build Prompt - Keelstone

ID: `MAS-C-F01-KEELSTONE-BUILD-2026-07-08`

```text
Build Keelstone for MAS C.

Read:
- docs/mas-c/MAS_C_CONTROL.md
- docs/mas-c/MAS_C_RELEASE_EVIDENCE_GATE.md
- docs/mas-c/features/01-keelstone/PLAN.md
- docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md

Task:
Inventory and harden the MAS vault/release path. Start with read-only mapping:
vault writers, bookmark access, provenance stores, App Store target membership,
entitlements, privacy manifest, and archive scripts. Only edit after the map
identifies the smallest safe unit.

Do not delete or rename broad code because of a legacy name. First prove whether
it is in-process MAS bridge behavior or forbidden runtime leakage.

Required outputs:
- intent checkpoint
- touched file list
- verification-debt ledger if batching tests
- MAS build/test or documented blocker
- archive scan command and result
- next Keelstone hardening item

Continue into hardening after the first pass; do not call Keelstone done until
the MAS release gate catches parked lanes, storage divergence, and entitlement
drift.
```

