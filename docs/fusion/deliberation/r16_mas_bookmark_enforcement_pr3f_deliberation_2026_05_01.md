# R16 MAS Bookmark Enforcement PR3F Deliberation - 2026-05-01

## Decision

Approved for a narrow R16 PR3F slice that makes vault bookmark behavior
deterministic for the Mac App Store / sandbox build before any production ETL
worker is allowed to read vault files.

## Scope

- Keep direct-distribution / Pro behavior unchanged: plain bookmark fallback may
  remain available outside the sandbox.
- In MAS / sandbox policy, reject plain bookmark fallback when security-scoped
  bookmark creation fails.
- In MAS / sandbox policy, block automatic restore when the saved bookmark did
  not resolve through a security scope.
- In MAS / sandbox policy, refuse to start watching a vault when security-scoped
  access was not already acquired and cannot be acquired.
- Add focused Swift tests that prove both the strict MAS policy and the existing
  direct fallback behavior.

## Explicit Non-Scope

- No ETL production worker drain.
- No AFM sidecar worker loop or queue completion semantics.
- No editor badge UI.
- No entitlements, project, scheme, or Info.plist edits.
- No `graph-engine/**`, `epistemos-shadow/**`, protected note editor, or graph
  renderer/controller edits.

## Rationale

Kimi's R16 worker advisory recommended against no-op queue draining and noted
that a real file-reading worker is blocked until MAS bookmark enforcement is
honest. This gate closes that prerequisite without pretending the ETL worker is
complete.

## Acceptance

- A red-first focused test run fails before implementation.
- A green focused test run passes after implementation.
- Existing direct-distribution plain bookmark fallback remains covered.
- Source audit shows no production ETL drain or protected-path edits were added.
