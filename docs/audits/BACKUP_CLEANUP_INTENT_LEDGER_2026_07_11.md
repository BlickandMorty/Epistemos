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

## Completion evidence and backup-capacity checkpoint

- The MAS source-of-truth and generated Xcode metadata now expose only
  `Epistemos-AppStore`, its widget, and the App Store KEELSTONE tests. June and
  `GooseMASAgentCoreRunner` remain the active in-process agent route.
- The release gate was replaced with an MAS-only gate. Shell syntax checks,
  `cargo fmt --check`, `git diff --check`, the normal gate, and its seeded
  HIGH/CRITICAL failure witness all pass. No Xcode build was run, per owner
  instruction; generated Rust bindings were not retained.
- The browser-use vendor was also removed as a retired non-MAS automation
  dependency. The workspace is now 5.12 GiB; local storage free space is
  366 GiB.
- The full selected raw backup set—including Codex companion data, the active
  Epistemos data/recovery roots, Xcode user data, and the three attached canon
  packets—is 53.09 GiB after the browser-use removal. Two uncompressed copies
  need about 106.18 GiB.
- The external volume was initially 114.07 GiB free, whose 20%-headroom
  payload ceiling is 91.67 GiB. It later disconnected and is currently absent
  from `/Volumes`. Even if remounted at the prior capacity, two raw complete
  copies are about 14.51 GiB over the permitted ceiling. Do not begin an
  external backup until the owner chooses compression/deduplication, a larger
  destination, or an explicitly approved source reduction.

## Final inactive model-artifact cleanup

- A final tracked-file scan found two 71.87 MiB Qwen/MLX prompt-cache files
  beneath `artifacts/falsifiers/kv_direct_gate/`. They are historical
  research-run output, not a dependency of the retained App Store June route.
- Both files were removed under the owner's authorization to delete local AI
  files. Historical documentation may retain their evidence references; no
  active MAS product source points to either cache file.

## Single restore-backup override — 2026-07-12

- Owner wording: “ok just do 1 copy please” and “i dont need encryption”.
- Interpreted intent: create one unencrypted, selective external restore
  archive that can rebuild the active MAS/Codex working environment on a new
  Mac, including the project source, scripts, Git state, Codex sessions and
  configuration, active Epistemos state, Xcode user settings, and the attached
  canon packets.
- Hard constraints: preserve the MAS/June-only topology; retain no retired
  Experimental/OpenChamber payload; do not back up deleted build products;
  include a manifest and SHA-256 checksum; do not claim live database
  consistency without a safe snapshot or the owner's process-close action.
- Capacity: `/Volumes/treasure` is mounted with 114.03 GiB free. One measured
  restore set fits within the required 20% headroom; two copies do not.
- Next action: create the single archive and its verification manifest on the
  mounted external volume, after the selected source inventory is finalized.

### Retired local-state exclusion before archive

- Measured retired payloads not needed to resume the MAS app: the
  `app.epistemos.llama-spike` container (3.12 GiB), the `epistemos-dd-agentB`,
  `epistemos-dd-holofix`, and `epistemos-dd-mas` developer caches (about
  5.08 GiB combined), and the small Experimental/direct-Goose application
  support directories.
- These paths are excluded from the restore set and removed under the prior
  MAS-only and local-AI cleanup authorization. The MAS App Store container,
  current Epistemos support data, and all recovery snapshots remain retained.

### Owner-directed script handoff

- Owner clarification: “i asked for a script to do it isnt that better so i
  can close the app”. The attempted live archive was cancelled and its partial
  output deleted.
- `scripts/create-epistemos-codex-restore-backup.zsh` now creates the single
  unencrypted restore archive after ChatGPT/Codex, Xcode, and Simulator are
  closed. It refuses a live run, snapshots SQLite databases, checks capacity,
  writes a manifest and SHA-256 receipt, validates archive readability, and
  extracts the full project into a temporary staging area to verify Git state.
- First interactive launch receipt: no archive directory or partial archive was
  created and external free space remained 113 GiB, proving the safety guard
  stopped the run before data copy while ChatGPT/Codex was active. A visible
  wrapper is added so Finder launches keep their Terminal window open with the
  exact stop/completion result.
- Restart-run diagnosis: the first script incorrectly made browser-cache
  SQLite databases a hard prerequisite and removed its own temporary failure
  report. The corrected script archives raw Codex databases and their WAL/SHM
  files only after the app-close guard passes; it attempts snapshots of the
  actual `~/.codex` state databases as additional recovery material and keeps
  their status report in the finished backup instead of blocking the archive.
- Archive-run diagnosis: the second run copied 54 GiB, then correctly reported
  failure because two transient Git filesystem-monitor sockets and unsupported
  macOS extended metadata made the PAX archive invalid. The incomplete archive
  is not a backup and is removed before retry. The next script revision excludes
  only those socket paths, omits nonportable extended metadata, and removes the
  entire output folder unless checksum plus staging Git restore both pass.

### Full new-Mac restore requirement

- Owner wording: “when i have a new mac i run a script and it compelely
  repalces the program data and everythgin as if the app is fully restored”.
- A paired restore script will verify the archive checksum, require active apps
  to be closed, stage-extract the archive, and replace each backed-up Codex,
  Epistemos, Xcode-user-data, and workspace path only after explicit typed
  confirmation. It preserves the old current state in a timestamped rollback
  folder before replacement.
- Non-portable macOS Keychain items, signing identities, and account-login
  tokens are not silently claimed as restored; the new Mac may require normal
  Apple/OpenAI sign-in and certificate provisioning afterward.
