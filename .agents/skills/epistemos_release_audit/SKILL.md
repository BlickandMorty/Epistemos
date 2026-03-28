---
name: "Epistemos Release Audit"
description: "Use when auditing Epistemos for release readiness, regression safety, or final ship approval. Requires log-first verification, real manual/runtime checks, release-blocker review, distribution/compliance review, and repeated zero-fail validation before calling the app ready."
---

# Epistemos Release Audit

Use this skill for any Epistemos release-readiness pass, strict regression audit, final ship check, or "is this truly ready?" session.

This skill is stricter than a normal test pass. It assumes:
- prior green claims may be stale or overstated
- UI behavior alone is not enough
- logs are first-class evidence
- manual/runtime verification is required for ship-risk surfaces
- release/distribution/compliance status must be checked alongside code/test health

## Required workflow

### 1. Start with repo reality

Before making claims:
- inspect the current branch, commit, and worktree state
- inspect any release plan or closure docs already present under `docs/plans/`
- identify whether the request is about:
  - direct distribution readiness
  - Mac App Store readiness
  - hybrid/direct-plus-MAS-lite strategy
  - general regression safety

If older "release-ready" or "everything is green" reports exist, treat them as inputs, not truth.

### 2. Run automated verification first

Minimum commands:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
cd graph-engine && cargo test
cd omega-mcp && cargo test
cd omega-ax && cargo test
```

If the request is a final release pass, also attempt sanitizer passes when feasible:

```bash
xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -enableAddressSanitizer YES
xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -enableThreadSanitizer YES
xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -enableUndefinedBehaviorSanitizer YES
```

Do not stop when tests pass.

### 3. Treat logs as mandatory evidence

While running tests and manual checks:
- inspect `xcodebuild` output carefully
- inspect runtime logs while the app is open
- correlate logs with visible behavior

Specifically watch for:
- actual model routing
- fallback behavior
- streaming start/stop reasons
- cancellations disguised as success
- permission denials
- Omega task state transitions
- browser / AX / Apple Events failures
- note/vault I/O failures
- silent decode problems

A manual test is not verified until logs agree with what the UI appeared to do.

### 4. Perform real manual/runtime verification

Always prefer a disposable test vault for destructive note/training checks.

For release-risk audits, manually verify:

#### Inference and model/mode wiring
- install/select behavior
- supported local models on the current hardware
- `Fast`, `Thinking`, `Agent` visibility per selection
- unsupported modes hidden rather than merely disabled
- real prompts sent in each supported mode

#### Research and Omega
- visible research entry points
- `/research ...` handoff
- Omega window actually appears
- planning and execution steps render
- results are structured and useful

#### Tools and automation
- browser open/search/title/url
- safe terminal command
- AX tree read
- click/type/key automation
- permission request flow

#### Notes and integrity
- note AI stream / accept / discard
- close/reopen note surfaces after AI use
- no divider orphaning or stale inline AI artifacts
- UTF-16 / Unicode note reads if corruption risk is in scope

#### Settings and messaging
- advanced features are honestly described
- experimental labels are present where needed
- no overclaiming around research, autonomy, or model capabilities

### 5. Audit release/distribution/compliance

For final release work, explicitly review:
- entitlements
- privacy manifest
- App Store helper / gateway helper scaffolding
- notarization readiness
- App Store vs direct-distribution compatibility
- export compliance setup
- app privacy answers
- review notes / demo-mode readiness
- privacy policy / support URL / metadata readiness

If App Store readiness is requested, use official Apple sources only unless clearly marked as inference.

### 6. Compare against older baselines when relevant

If the request mentions regressions, older builds, or "better than before":
- diff against the relevant older commits
- compare current research/Omega behavior against older research-mode baselines
- identify any place where the new branch regressed
- fix only the real regressions or release-critical mismatches

### 7. Recursive zero-fail requirement

For final ship calls:
- achieve 3 uninterrupted passes with no code changes between them
- each pass includes:
  - automated checks
  - code/log audit
  - manual/runtime spot checks on ship-risk surfaces

If any issue is found:
1. fix it
2. explain the root cause
3. reset the pass counter
4. start again

### 8. Reporting standard

When finishing a release audit, always report:
- exact commands run
- exact manual tests run
- exact logs or log-derived findings
- what was fixed during the audit
- what remains blocked, if anything
- final verdict:
  - `READY FOR DIRECT RELEASE`
  - `READY FOR DIRECT RELEASE, MAS LITE ONLY`
  - `NOT READY`

Do not say "ship it" unless the evidence truly supports it.

## Epistemos-specific red flags

Prioritize these if they are still relevant in the branch being audited:
- empty release entitlements
- missing `PrivacyInfo.xcprivacy`
- App Store helper / Gateway helper scaffolding that still throws
- unsupported model modes visible in UI
- thinking-mode blank outputs or crashes
- research handoff that disappears into plain chat
- Omega panel failing to surface visibly
- note-AI divider corruption
- Unicode/UTF-16 note decode issues that make healthy files appear corrupted
- misleading "auto research" or over-autonomous copy

## Success bar

The app is only release-ready when:
- tests are green
- logs support the observed behavior
- manual runtime checks pass on real app surfaces
- no major regression remains versus the intended baseline
- distribution/compliance blockers are either resolved or clearly classified
- the final report is honest
