# MAS C Build Prompt - LumenLens

ID: `MAS-C-F03-LUMENLENS-BUILD-2026-07-08`

```text
Build LumenLens for MAS C.

Read:
- docs/mas-c/MAS_C_CONTROL.md
- docs/mas-c/features/03-lumenlens/PLAN.md
- docs/mas-c/features/05-epdoc-assist/PLAN.md
- docs/prompts/INTEGRATION_FABRIC.md

Task:
Harden Epdoc as the MAS writing/evidence workspace. Start by mapping current
editor files, writeback path, provenance store, undo behavior, and June
assistant seams. Then implement the next smallest feature unit.

Rules:
- vault note files are truth
- every agent edit needs approval, provenance, and undo
- suggestions must be minimal-diff and explainable
- notebook tabs can host datasets and sources, but must not create a silo

Required proof:
- source guard or test for touched editor behavior
- before/after fixture for note writes
- accepted/rejected suggestion provenance
- manual UI evidence when visible editor behavior changes
- MAS build/test checkpoint when phase boundary is reached
```

