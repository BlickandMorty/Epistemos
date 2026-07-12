# MAS C Build Prompt - Capabilities

ID: `MAS-C-F09-CAPABILITIES-BUILD-2026-07-08`

```text
Build MAS C Capabilities.

Read:
- docs/mas-c/MAS_C_CONTROL.md
- docs/mas-c/features/09-capabilities/PLAN.md
- docs/mas-c/features/02-mas-june/PLAN.md
- docs/mas-c/prompts/03_MAS_C_LEGALITY_MATRIX.md

Task:
Classify existing and proposed capabilities before implementation. Choose one
MAS-safe capability and wire it through agent_core, MAS June, provenance, and
vault outputs.

Rules:
- no terminal/code-exec tool
- no browser-use Chromium
- no Python helper runtime in MAS
- no unapproved source/data access
- all tools need status, approval where risky, provenance, and rollback

Required proof:
- classification matrix
- one end-to-end capability fixture
- source guard/test
- release scan for forbidden helpers
- manual UI evidence when visible behavior changes
```

