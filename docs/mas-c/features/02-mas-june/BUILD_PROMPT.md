# MAS C Build Prompt - MAS June

ID: `MAS-C-F02-MAS-JUNE-BUILD-2026-07-08`

```text
Build MAS June for MAS C.

Read:
- docs/mas-c/MAS_C_CONTROL.md
- docs/mas-c/features/02-mas-june/PLAN.md
- docs/mas-c/MAS_C_RELEASE_EVIDENCE_GATE.md
- docs/prompts/INTEGRATION_FABRIC.md

Task:
Make MAS June the sole active agent surface. Map the current native shell,
WKWebView bundle, June gateway, agent_core runner, bridge handlers, approval
flows, and release archive membership before editing.

If you see Goose or Hermes names, do not assume deletion. Classify each as:
legacy name only, in-process MAS bridge, bundled web compatibility, or forbidden
runtime leakage. Rename only after proving call sites and release impact.

Required proof:
- one active MAS agent registry
- no hidden subprocess or second user-facing agent
- approval/cancel/rollback path
- entitlements justified or reduced
- MAS build/test checkpoint
- UI/manual evidence for the native shell and June surface

After the implementation checklist passes, keep hardening bridge names, source
guards, archive scans, and App Review notes.
```

