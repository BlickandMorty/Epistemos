# Backup Cleanup Intent Ledger — 2026-07-11

## Owner wording

> "i dont need build remember i said no build, i also dont need research clone is the june part that is working and wried in my app in the research or is it in like my app folder. also u can delete all my local ai files ther are thigns to get rid of it should not be neay as that much storagfe"

## Interpreted intent

Free the space needed for the selective backup by deleting rebuildable project
outputs, local model/runtime downloads, and the ignored research-clone donor
tree. Keep the active MAS June product source and all user/work data.

## Evidence and scope boundary

- Active June source is under `Epistemos/JuneAgent`, covered by the App Store
  target's `Epistemos` synced source folder.
- `agent_core` is active in-process MAS source. Only its generated `target/`
  directory is disposable.
- `.research-clones` is ignored donor/research material. Its only executable
  references are DEBUG or parked Experimental/Goose fallbacks; the
  Experimental build script exits successfully when the clone is absent.
- The App Store build regenerates `build-rust` and `.june-web-stage` from
  source during its declared pre-build phase.

## Authorized deletion scope

1. Rebuildable project output and dependency caches: `build`, `build-rust`,
   all discovered `target`, `.build`, and `node_modules` directories,
   `.spm-cache`, `.june-web-stage`, Xcode Derived Data, SwiftPM cache, and
   Cargo cache.
2. Ignored `.research-clones` donor tree.
3. Local AI/runtime artifacts: the Qwen GGUF cache, Kokoro Core ML cache,
   Epistemos Python/runtime caches, and the Epistemos container temporary
   model cache.

## Hard constraints and non-goals

- Do not delete `Epistemos/`, `agent_core/` source, `LocalPackages/` source,
  plans, documentation, attached canon material, Codex state, notes,
  databases, user settings, recovery snapshots, secrets, signing material, or
  Git history.
- Do not commit, push, format, or modify the external drive in this cleanup.
- Do not perform a build solely to validate this cleanup; regenerating outputs
  is intentionally deferred until after the backup plan is capacity-valid.

## Acceptance checks

- Re-measure every deletion target immediately before and after removal.
- Confirm protected source and data roots remain present.
- Confirm internal free space increases by the reclaimed amount within normal
  APFS accounting tolerance.
- Recalculate the selective-backup capacity from the remaining retained data.

## Next action

Delete the verified authorized scope, then re-audit capacity before any backup
or Git operation.

## Owner steer — MAS-only excision

### Verbatim wording

> "remmebr i only wanted the MAS version of the app so openchamber experimental all shoudl be gone the nuance is that goose has i process on june so there is two gooses one is for experiemntal and one is for MAs MAs is the canon and the only build im keepiing"

### Interpreted intent

Expand cleanup into an MAS-only excision: remove the executable Experimental,
OpenChamber, 1Code, and non-MAS Goose lanes, while retaining the canonical
App Store target, June, its in-process MAS Goose path, `agent_core`, and their
required native/WKWebView resources.

### Constraints and non-goals

- Do not delete the shared `Epistemos/Goose` directory as a whole until every
  file is classified; it contains both MAS and Experimental-era material.
- Treat source, resource, build-graph, test, and application-support removal
  as separate mapped operations; do not remove a shared MAS dependency.
- Preserve research and historical documentation as backup provenance unless
  the owner explicitly asks for a documentation purge. "All" currently means
  executable code, bundled resources, runtime data, caches, and build hooks.
- Keep the existing no-deletion protections for June, `agent_core`, user data,
  recovery snapshots, Codex state, signing material, and Git history.

### Acceptance checks

- The App Store target resolves June and the in-process MAS Goose path without
  Experimental/OpenChamber runtime inputs.
- No non-MAS runtime, resource, build phase, or application-support cache
  remains in the mapped deletion scope.
- Source-level guards find no active App Store references to deleted lanes.
- Backup capacity is recalculated only after the excision and cache cleanup
  are measured.

### Next action

Map every Experimental/OpenChamber/Goose file and runtime reference against
the App Store target, then remove only the non-MAS side of each seam.

## Cleanup execution checkpoint

### Completed deletion receipt

- Reclaimed scope measured immediately before deletion: `259,507,484 KiB`
  (`247.49 GiB`).
- Removed rebuildable build products, ignored donor clones, dependency caches,
  Xcode Derived Data, local Qwen/Kokoro assets, parked runtime caches, and
  container temporary model outputs.
- Internal free space increased from `79 GiB` to `296 GiB`.
- The workspace decreased from `233.53 GiB` to `6.00 GiB`.
- Verified retained: `Epistemos/JuneAgent`, `agent_core/src`,
  `LocalPackages`, `docs`, Codex state, and Epistemos recovery snapshots.

### Verification debt for the source excision

- `project.yml`, the generated Xcode project, several direct-lane files, and
  the legacy test suite already contain uncommitted MAS-hardening work. Do not
  overwrite or regenerate them wholesale.
- Remove the LegacyDev/Experimental product target, direct Goose ACP/process
  lane, ExperimentalAgent, OpenChamber/Work/MCP lane, retired resources and
  scripts, then make only the required non-overlapping call-site, release-gate,
  and App Store test updates.
- Regenerate the Xcode project only after the YAML source-of-truth is updated
  and its current uncommitted MAS changes are preserved. Run one Xcode build at
  a time after regeneration; no build is currently owed during storage cleanup.
- Recalculate selective-backup capacity after the source graph is clean.

### Next hardening target

Construct the MAS-only deletion map from current target membership and direct
call sites, then remove one isolated seam at a time with source-level checks.

## MAS-only release-gate replacement plan

- Owner constraint applied: only `Epistemos-AppStore`, June, and in-process
  `agent_core` may remain as buildable product paths; no Developer-ID,
  Experimental, OpenChamber, external Goose, local server, stdio MCP, or
  command-execution release path may remain.
- Current state: `scripts/keelstone-release-gate.sh` is a 1,940-line dual-lane
  guard that requires files and schemes deliberately removed by this cleanup.
  It is invoked by CI and release workflows, so leaving it unchanged would
  preserve and enforce the retired product topology.
- Planned replacement: a compact, same-path MAS-only gate that verifies the
  single App Store target and schemes, the June/in-process Goose execution
  anchors, absence of each removed lane, and App Sandbox entitlements when an
  app bundle is supplied. It retains the existing seeded-HIGH failure contract
  used by CI.
- Blast radius and rollback: only the gate implementation and its MAS test
  assertion are replaced; no app source, vault data, or historical docs are
  rewritten. Git preserves the prior gate for recovery.
- Proof: shell syntax check, normal pass, seeded-HIGH expected failure, and
  source scan. Per owner instruction, do not perform an Xcode build here.

## Remaining local-AI cleanup checkpoint

- The owner’s authorized phrase “delete all my local AI files” applies to the
  remaining large, rebuildable AI application/runtime caches found after the
  MAS excision.
- Mapped deletion set: `~/.cache/epistemos-dd-codex-*` (65.32 GiB of prior
  development cache), `~/.cache/uv`, `~/.cache/huggingface`, the reinstallable
  Codex runtime cache, and the retired/local AI app data for Claude,
  OpenChamber, Goose, and the OpenAI chat application.
- Explicitly retained: `~/.codex` and `~/Library/Application Support/Codex`
  because the standing backup objective requires Codex state, settings, logs,
  skills, and local data; the active Epistemos container, recovery snapshots,
  and active MAS app data are retained as well.
- Pre-deletion measurement: 78.13 GiB across the mapped AI cache/app-data set.
- Process safety check: Claude, OpenChamber, Goose, Ollama, and LM Studio were
  not running. ChatGPT/Codex was active and is deliberately excluded from this
  deletion pass, including its `com.openai.chat` support data and active Codex
  runtime cache. The inactive deletion set reclaims 76.38 GiB.
