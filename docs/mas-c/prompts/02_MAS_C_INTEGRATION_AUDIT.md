# MAS C Prompt 02 - Cross-Plan Integration Audit

ID: `MAS-C-PROMPT-02-INTEGRATION-AUDIT-2026-07-08`

Use this before integrating multiple features or before accepting a returned
plan from a research agent.

```text
Audit the attached MAS C feature plan against:
- docs/mas-c/MAS_C_CONTROL.md
- docs/mas-c/MAS_C_MASTER_PLAN.md
- docs/prompts/INTEGRATION_FABRIC.md

Return:
1. feature ID and scope
2. F1-F6 mapping status
3. active dependencies and blocked dependencies
4. contradictions with MAS-only target
5. old-lane leakage risks
6. storage truth risks
7. source/legal risks
8. UI/native-shell risks
9. release evidence required before next phase

Reject the plan if it treats the feature as a silo, assumes a second agent,
uses database truth without vault reconstruction, or requires forbidden MAS
runtimes.
```

