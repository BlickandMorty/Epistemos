# KEELSTONE Phase 0 Excision Inventory

Date opened: 2026-07-06
Last audited: 2026-07-07

Scope: retired branded-surface references across production sources, `project.yml`,
scripts, tests, workflow guardrails, and root `build-*.sh` scripts.

## Result

OWNER DIRECTIVE 2026-07-06: **OpenChamber/ProAgent are deletion targets, not
retained surfaces.** The current guarded source surface is now in the
post-excision state: no active production source, tests, scripts, workflow file,
`project.yml`, or root build script may reference the retired names.

Historical docs and archived prompts may still name the deleted surface as
provenance. That does not authorize new source references. The release gate and
source guards are the active enforcement boundary.

## Current Evidence

- `rg -n "OpenChamber|openchamber|ProAgent|PRO_BUILD|pro-agent" Epistemos project.yml scripts .github EpistemosTests build-*.sh` returns no matches.
- `./scripts/keelstone-release-gate.sh` passes the retired-surface drift section.
- `Epistemos/ProAgent/` is absent from the current source tree.
- `project.yml` invokes `build-experimental-web.sh`, not the retired web packaging script.
- `build-experimental-web.sh` stages `Epistemos/Resources/experimental-runtime/...`.
- `AgentSurfaceChildLedger` uses `agent-surface-children.json`.
- `Epistemos/AgentSurface/AgentSurfaceRuntimeSupport.swift` resolves `experimental-runtime/bin/node`.

## Guardrails

- `scripts/keelstone-release-gate.sh` scans `Epistemos`, `EpistemosTests`,
  `project.yml`, `scripts`, `.github`, and root `build-*.sh` scripts for retired
  names.
- `EpistemosTests/AppStoreHardeningTests.swift` asserts the neutral ledger
  filename and keeps the retired-surface scan executable in Swift tests.
- CI runs the release gate before the main Swift test/build lane.

## Remaining Non-Source Residue

- A root `pro-agent-screenshots` directory exists outside the guarded source
  paths. It is not compiled or packaged by the current gate. Do not delete it
  blindly; treat it as archival/user artifact unless the owner asks for artifact
  cleanup.

## Next Checkpoint

Before marking Phase 6 fully complete, run the full test suite or the CI
equivalent release lane. Phase 0 itself is source-clean under the current guard,
but Phase 6's tracker also requires the broader suite evidence.
