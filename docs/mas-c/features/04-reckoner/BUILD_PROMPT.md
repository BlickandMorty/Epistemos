# MAS C Build Prompt - Reckoner

ID: `MAS-C-F04-RECKONER-BUILD-2026-07-08`

```text
Build Reckoner for MAS C.

Read:
- docs/mas-c/MAS_C_CONTROL.md
- docs/mas-c/features/04-reckoner/PLAN.md
- docs/mas-c/features/12-storage-fusion/PLAN.md
- docs/prompts/INTEGRATION_FABRIC.md

Task:
Implement the next vault-native dataset unit. Begin with source reading:
dataset artifact code, table renderer, calculation engine, Epdoc notebook
integration, provenance, and June capability registry.

Rules:
- vault artifact manifest is truth
- renderer is not calculation authority
- transforms require preview, approval, provenance, and undo
- every imported source needs source/legal status

Required proof:
- fixture dataset
- transform/calc result with provenance
- rollback or undo
- Epdoc tab/embed manual evidence
- relevant source guard/test and MAS checkpoint
```

