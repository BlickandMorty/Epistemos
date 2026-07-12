# MAS C Prompt 05 - Local Build Redirect

ID: `MAS-C-PROMPT-05-LOCAL-BUILD-REDIRECT-2026-07-08`

Use this to redirect an in-flight local agent to MAS C without erasing useful
work.

```text
Pause current assumptions and rebase the task onto MAS C.

Read:
1. docs/mas-c/README.md
2. docs/mas-c/MAS_C_CONTROL.md
3. docs/mas-c/MAS_C_MASTER_PLAN.md
4. docs/mas-c/MAS_C_RELEASE_EVIDENCE_GATE.md
5. the relevant docs/mas-c/features/<feature>/PLAN.md
6. the relevant docs/mas-c/features/<feature>/BUILD_PROMPT.md

Then report:
- current branch and dirty files
- which existing work remains usable under MAS C
- which work must be parked
- exact next small unit
- verification-debt ledger
- tests/builds to run at the next checkpoint

Do not delete broad work. Quarantine, document, and migrate only after reading
the relevant code and plan. Preserve owner intent and do surgical edits.
```

