# MAS C Build Prompt - Lodestar

ID: `MAS-C-F07-LODESTAR-BUILD-2026-07-08`

```text
Build Lodestar for MAS C.

Read:
- docs/mas-c/MAS_C_CONTROL.md
- docs/mas-c/features/07-lodestar/PLAN.md
- docs/mas-c/prompts/03_MAS_C_LEGALITY_MATRIX.md
- docs/prompts/INTEGRATION_FABRIC.md

Task:
Start with source legality, not UI. Pick one MAS-safe source and implement the
smallest complete loop: search or fetch, save source card, create vault note,
record citation/provenance, link graph, expose June capability.

Rules:
- official APIs or permitted feeds first
- no scraping where terms forbid it
- no paywall bypass
- no Reddit commercial feature without explicit clearance
- network behavior must match privacy/App Review notes

Required proof:
- legality matrix
- saved fixture note/source card
- provenance/citation record
- graph link proof if graph integration touched
- MAS June tool proof
- network/privacy notes
```

