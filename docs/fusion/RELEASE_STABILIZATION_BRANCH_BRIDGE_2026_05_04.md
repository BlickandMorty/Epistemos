# Release Stabilization Branch Bridge - 2026-05-04

Track: T12 release / MAS-Pro separation / verification.

This bridge promotes the durable lessons from
`codex/release-stabilization-and-runtime-hardening`. The branch is not a raw
merge target for current recovery; its release-audit workflow and historical
closure docs are already present in main and now have an explicit fusion role.

## Donor / Live Authority

Donor:

- branch `codex/release-stabilization-and-runtime-hardening`
- commit `e5d0114a` (`add release audit workflow and final handoff`)
- commit `d9cf9857` (`release stabilization and runtime hardening`)

Current main evidence:

- `.agents/skills/epistemos_release_audit/SKILL.md` matches the branch skill.
- `docs/plans/2026-03-28-final-claude-release-readiness-prompt.md` exists in
  main and is marked historical/superseded.
- `docs/plans/2026-03-27-*` release, training, Omega, embodied-data, and
  closure reports exist in main.

## Durable Contract

The branch contributes a verification doctrine, not a new Recovery order:

- release claims require log evidence, not just green UI;
- final ship calls require manual/runtime checks;
- unsupported modes should disappear from the user surface instead of failing
  behind disabled or misleading controls;
- App Store and direct-distribution readiness must be evaluated separately;
- final release needs repeated zero-fail validation with no code changes
  between passes.

## Recovery Placement

Stage F should use the repo skill:

- `.agents/skills/epistemos_release_audit/SKILL.md`

The older `Recursive App Audit` wording in March release prompts should be read
as historical. The current fusion authority is the Epistemos Release Audit
skill plus the May 2026 MAS/Pro and XPC doctrine.

Next slices:

1. Keep MAS/Pro surfaces explicit before any final App Store claim.
2. Use official Apple sources for current App Store, privacy, notarization, and
   export-compliance checks when Stage F begins.
3. Reconcile March Omega/research release docs against current Recovery A-F,
   V2, and V3 sequencing instead of reviving the older branch order.
4. Treat the branch's training corpus and MOHAWK assets as historical research
   tier material unless current fusion explicitly reopens that path.

## Non-Negotiables

- No release-ready verdict without real logs.
- No final ship claim without manual/runtime verification.
- No App Store claim based on direct-distribution success.
- No revival of historical branch scope that weakens current MAS-first V1
  recovery or the XPC trust spine.
