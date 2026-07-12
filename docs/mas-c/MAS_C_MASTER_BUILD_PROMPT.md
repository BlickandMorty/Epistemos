# MAS C Master Build Prompt

ID: `MAS-C-MASTER-BUILD-PROMPT-2026-07-08`

Paste this to a local build agent when redirecting work to MAS C.

```text
You are working on Epistemos MAS C.

Before editing, read:
1. docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md
2. docs/mas-c/README.md
3. docs/mas-c/MAS_C_CONTROL.md
4. docs/mas-c/MAS_C_MASTER_PLAN.md
5. docs/mas-c/MAS_C_RELEASE_EVIDENCE_GATE.md
6. the target feature folder's PLAN.md and BUILD_PROMPT.md
7. docs/prompts/INTEGRATION_FABRIC.md

Interpret "upgrade", "revamp", "new stack", "replace", and "V2" as real
component, behavior, route, and ownership replacement. Do not deliver wrappers,
token-only polish, CSS-only reskins, or package-presence proof.

Active target is Mac App Store only: Epistemos-AppStore, MAS_SANDBOX,
EPISTEMOS_APP_STORE, MAS June, and in-process agent_core. Park Pro,
Developer-ID, Experimental, 1Code, OpenChamber, Kindred runtime, browser-use,
terminal/code-exec, Node backend authority, stdio MCP, and subprocess agents.

Before editing:
- preserve a verbatim owner-intent excerpt
- state interpreted intent, constraints, non-goals, and done bar
- search local code/docs semantically for related seams and contradictions
- read the target files and nearby call sites
- use official/current sources when policy, API, App Store, source legality, or
  package behavior matters

During implementation:
- edit surgically
- keep vault files as truth
- keep indexes and databases derived unless the feature plan explicitly proves a
  better lossless storage authority
- route agent capability through MAS June and agent_core
- use native Swift/AppKit/SwiftUI for shell and review-sensitive surfaces
- use bundled WKWebView assets only when local, static, fast, and reviewable
- maintain a verification-debt ledger if tests/builds are batched

After each batch:
- re-read changed regions
- inspect diff
- run relevant source guards/tests/builds
- collect runtime or screenshot evidence for UI and vault behavior
- scan for parked-lane leakage in MAS target or release archive where relevant
- update the feature evidence notes

Do not claim done. When the implementation checklist appears complete, enter a
hardening loop: contradiction scan, release leak scan, source/legal review,
manual proof, tests, and code-quality audit until the owner stops or a real
blocker is documented.
```

