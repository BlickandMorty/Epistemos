# Owner-Steer Closeout Handoff — 2026-07-10

Current canonical execution key:
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.

Status: **INCOMPLETE**. Current source has targeted corrections and the
source-only gate is green, but the newest retained MAS artifact is red and the
owner-visible exact-runtime evidence bar has not run against a current archive.
This handoff is an evidence checkpoint, not authorization to change execution
keys or stop the autonomous MAS work.

## Authority and constraints

- Daily authority is the July 8 master canon under
  `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08`.
- Numeric prompt/plan shorthand is not an execution-state key. Older numbered
  files are provenance/specification appendices only.
- The only product is `Epistemos-AppStore` with `EPISTEMOS_APP_STORE`,
  `MAS_SANDBOX`, MAS/June, in-process `agent_core`, sandbox-safe vault access,
  Keychain secrets, and bundled/native assets.
- Preserve local GGUF models, OpenAI/Anthropic cloud choices, and Kokoro voice
  models under June. Visible settings rows are not proof of a connected runtime.
- Preserve the dirty worktree. Do not reset, revert, discard, stage, commit, or
  broadly reformat owner or prior-agent work.
- The owner reported roughly 25 GB of RAM use. Do not run broad suites,
  parallel builds, multiple archives, concurrent model loads, or repeated
  heavyweight verification.

## Faithful owner-steer inventory and status matrix

The classification column uses exactly one closeout status per steer. A source
patch or older artifact never substitutes for fresh owner-visible proof.

| Owner steer | Classification | Current evidence and files |
| --- | --- | --- |
| Embedded-graph and hologram-graph editors load slowly and hang while typing across Epdoc, Source/Code, Prose, and other surfaces. | SOURCE-PATCHED, MANUAL/RUNTIME PROOF PENDING | Embedded routes clear graph/inspector work; hologram editor routes stop the canvas-only 30 Hz pinned-panel timer. Primary current files: `Epistemos/Views/Graph/HologramOverlay.swift`, `Epistemos/Views/Home/HomeGraphEmbeddedView.swift`, `Epistemos/Graph/GraphState.swift`, `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`, `scripts/keelstone-release-gate.sh`. Exact latency remains HIGH OPEN. |
| Editing performance regressed across Epdoc, Prose, Source/Code, Quick Capture, and graph-opened editors. | SOURCE-PATCHED, MANUAL/RUNTIME PROOF PENDING | Current source coalesces/serializes hot-path snapshots, outline work, live preview, Prose parsing/detection/telemetry, Epdoc autosave, graph payload work, and WebKit delivery. Relevant files span `Epistemos/Views/Notes`, `Epistemos/Views/Epdoc`, `Epistemos/Views/Capture`, `Epistemos/Views/Graph`, and `js-editor`. Current large-document typing/allocation measurements are not proven. |
| Epdoc can blank, appear to lose data, or lose rich tables/formatting when switching editor surfaces. | SOURCE-PATCHED, MANUAL/RUNTIME PROOF PENDING | `NoteDetailWorkspaceView` awaits the active editor flush; Document stays mounted while hidden; Source/Prose use the shared Markdown snapshot; hidden Epdoc reloads after sibling-lens changes; clean empty bridge snapshots cannot replace a non-empty host. Primary files: `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`, `Epistemos/Views/Notes/MarkdownDocumentSurface.swift`, `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`, `EpistemosAppStoreKeelstoneTests/MarkdownDocumentLensSwitchTests.swift`. A persisted Epdoc → Source → Prose → Epdoc round trip remains HIGH OPEN. |
| Source/Code appears view-only or cannot acquire the writable editor lease. | SOURCE-PATCHED, MANUAL/RUNTIME PROOF PENDING | Newly mounted Source, Prose, and Epdoc sessions request clean-owner handoff; dirty owners still block transfer. Source teardown publishes and flushes current text before detaching. Primary files: `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`, `Epistemos/Views/Notes/CodeEditorView.swift`, editor-lease registry/tests. Exact edit/save and dirty-owner conflict behavior remain HIGH OPEN. |
| A valid vault fails to restore after quit/relaunch and saves fail with `no vault URL`. | SOURCE-PATCHED, MANUAL/RUNTIME PROOF PENDING | Startup preflight uses one bounded bookmark resolution, reuses a matching successful resolution once, preserves saved bookmark bytes on timeout/failure, and suppresses the false cache-gap warning when a valid bookmark can repair it. Primary files: `Epistemos/App/AppBootstrap.swift`, `Epistemos/Sync/VaultSyncService.swift`, `EpistemosTests/WorkspaceSnapshotTests.swift`, `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`. Exact select/save/quit/relaunch/save evidence remains HIGH OPEN. |
| Kokoro voice does not work or sounds non-English; keep voice models. | SOURCE-PATCHED, MANUAL/RUNTIME PROOF PENDING | The installed package declares English `en-US`; all 75 declared files match declared sizes; saved voice is `af_bella`; the retained binary contains Kokoro runtime symbols. English-only voice normalization, single-flight cancellable rendering, and bounded visible failures are present. Primary files: `Epistemos/VoicePro/KokoroCoreMLSynthesizer.swift`, `Epistemos/Engine/EpistemosSpeechSynthesizer.swift`, `Epistemos/Engine/EpistemosVisibleReadAloud.swift`, voice settings/picker/read-aloud files and tests. Older logs prove render/playback completion, but fresh current-source audible English and surface coverage remain HIGH OPEN. |
| June local models do not produce output; local GGUF must stay enabled and June-owned. | STILL REPRODUCED OR CONTRADICTED | The newest retained MAS archive exposes Qwen rows but has neither embedded `llama.framework` nor an executable load command for it. That artifact physically cannot run the selected GGUF. The sandbox has an exact-size Qwen3 4B file but no current receipt; model bytes were not opened. Current source re-enables in-process `EpistemosLlama`, performs safe existing-file receipt migration, and the release gate now rejects missing embedding/linkage. Primary files: `Epistemos/QuickChat/LocalGGUFQuickChatBackend.swift`, `Epistemos/QuickChat/GGUFModelCatalog.swift`, local installer/router files, `LocalPackages/EpistemosLlama`, `project.yml`, `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift`, and `scripts/keelstone-release-gate.sh`. A fresh archive and real token remain HIGH OPEN. |
| June OpenAI/Anthropic paths may not work. | SOURCE-PATCHED, MANUAL/RUNTIME PROOF PENDING | Saved non-secret selection is `openai:gpt-5.5`; Swift and `agent_core` admit that exact ID. No cloud-consent preference exists, so a visible pre-send consent blocker is expected. Bounded streams now fail visibly on backpressure. No Keychain secret was read and no provider request ran. Primary files: `Epistemos/JuneAgent/JuneAgentGateway.swift`, `Epistemos/JuneAgent/JuneAgentBridge.swift`, `agent_core` provider/session paths and focused tests. Exact consent and provider output remain HIGH OPEN. |
| Normal June send must preserve the literal owner prompt and must not invoke Hermes or Prompt Forge. | SOURCE-PATCHED, MANUAL/RUNTIME PROOF PENDING | MAS `prompt.submit` forwards submitted text directly; per-message forge preview is disabled; missing host mode fails visibly rather than returning a canned echo. Primary files: `Epistemos/JuneAgent/JuneAgentGateway.swift`, `Epistemos/JuneAgent/JuneSystemPromptForge.swift`, `.june-web-stage/tauri-internals-shim.js`, source June shim, tests, and the release gate. Current exact-archive request/log proof remains HIGH OPEN. |
| The normal/base product must be MAS/June, never stale Experimental, 1Code, OpenChamber, Goose, or legacy output. | SOURCE-PATCHED, MANUAL/RUNTIME PROOF PENDING | The normal scheme maps to `Epistemos-AppStore`; legacy/dev is explicitly named; the source gate enforces MAS boundaries. An earlier exact archive launched MAS/June, but current-source product identity and the retained artifact's parked-marker failure still require a new archive/gate/launch proof. Primary files: `project.yml`, Xcode schemes/project, `Epistemos/App`, target entitlements/plists, and release/bundle gates. |
| Keep only the selected local models and cloud models in June settings; model rows must not imply disconnected capability. | SOURCE-PATCHED, MANUAL/RUNTIME PROOF PENDING | Current catalog/policy keeps Qwen3 4B admitted on the 16 GB target and presents Qwen3 8B/Qwen2.5 7B with honest RAM gates; cloud choices remain June-owned. The new artifact check prevents a GGUF row from shipping without its runtime. Exact current settings-to-output behavior remains HIGH OPEN. |
| Stop exhaustive micro-hardening from stalling the master plan and avoid massive tests. | PROVEN BY CURRENT TEST EVIDENCE | `docs/prompts/MAS_EXECUTION_STATUS_2026_07_10.md` establishes the source-freeze/anti-stall rule. This closeout used only parsing, shell/source gates, and artifact inspection; it ran no Xcode build/test/archive, app, provider, Core ML, audio, or GGUF workload. |
| Use only full canonical execution IDs and do not let older numbered indexes control phase order. | PROVEN BY CURRENT TEST EVIDENCE | The dashboard and latest intent-ledger corrections use full IDs; `docs/prompts/MASTER_PLAN_INDEX_2026_07_03.md` is explicitly provenance-only/superseded. |

## Current changed-file ownership

The worktree contains hundreds of unrelated or shared changes. Files directly
changed in the final owner-steer convergence slice include:

- `Epistemos/Views/Graph/HologramOverlay.swift`
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
- `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift`
- `scripts/keelstone-release-gate.sh`
- `docs/prompts/MAS_EXECUTION_STATUS_2026_07_10.md`
- `docs/prompts/MASTER_PLAN_INDEX_2026_07_03.md`
- `docs/plans/keelstone/INTENT_LEDGER.md`
- `docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md`
- `docs/plans/keelstone/PROMPT1_PROMPT2_CHECKPOINT_2026_07_08.md`
- this handoff

Other editor, vault, June, voice, graph, WebKit, project, test, and generated
files were already dirty from owner/prior-agent work. Do not infer sole
ownership from `git status`, and do not stage the broad state.

## Verification run in this closeout

Commands and results:

```bash
git diff --check
```

PASS with no whitespace errors.

```bash
bash -n scripts/keelstone-release-gate.sh
```

PASS; approximately 2.1 MB maximum RSS, zero swap.

```bash
xcrun swiftc -parse \
  Epistemos/Views/Graph/HologramOverlay.swift \
  EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift \
  EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift \
  Epistemos/Views/Notes/NoteDetailWorkspaceView.swift \
  Epistemos/Views/Notes/MarkdownDocumentSurface.swift \
  EpistemosAppStoreKeelstoneTests/MarkdownDocumentLensSwitchTests.swift
```

PASS; 44,957,696 bytes maximum RSS, 10,355,240 bytes peak footprint, zero
swap.

```bash
bash scripts/keelstone-release-gate.sh \
  > /tmp/keelstone-source-gate-20260710-owner-steers-closeout.log
```

PASS; 10,321,920 bytes maximum RSS, 2,720,056 bytes peak footprint, zero
swap. The retained log contains 827 PASS lines and no gate error.

The newest retained MAS archive was also checked with the built-app gate. It is
RED with 12 findings:

- two missing GGUF framework/linkage findings;
- one parked account/backend marker finding;
- seven stale JuneWeb identity/configuration findings;
- two privacy-manifest collected-data findings.

Full log: `/tmp/keelstone-retained-app-gate-20260710.log`. That scan built
nothing, loaded no model, used 59,719,680 bytes maximum RSS / 6,209,872 bytes
peak footprint, and recorded zero swap.

Two initial lightweight check invocations used a stale test path and a
nonexistent `--source-only` gate option. They failed before testing behavior;
the corrected commands above are the authoritative results.

## Verification deliberately not run

- No `xcodebuild`, archive, broad Swift/Cargo suite, app launch, UI automation,
  provider request, Keychain secret read, GGUF hash/load/token, Core ML model
  load, or audio playback ran in this closeout.
- Reason: the owner explicitly asked to avoid the prior roughly 25 GB RAM
  event, and the source-freeze rule says the next useful evidence is one serial
  current-source archive plus a finite runtime matrix, not repeated broad
  testing or more optional source churn.

## Exact manual/runtime evidence still required

Use one fresh current-source `Epistemos-AppStore` Release archive and stop the
chain immediately if its resource cap is crossed.

1. Gate, sign, entitlement/privacy scan, quarantine scan, parked-lane scan, and
   verify JuneWeb plus embedded/linked `llama.framework` on that exact app.
2. Launch only that exact app path and confirm the normal product is MAS/June.
3. Select the owner vault, edit/save, quit, relaunch, confirm the same scoped
   vault restores, edit/save again, and prove there is no `no vault URL`,
   truncation, or silent loss.
4. On a rich fixture containing tables, blockquotes, lists, links, and an
   intentionally empty case, perform Epdoc → Source → Prose → Epdoc and confirm
   persisted Markdown/fidelity.
5. Type and save in Epdoc, Prose, Source/Code, Quick Capture, embedded graph,
   and hologram graph; record load/input/save latency and confirm graph nodes
   route to the writable canonical editor.
6. Submit one local Qwen3 4B turn and prove receipt migration, selected-model
   routing, streamed output, cancellation/teardown, and visible bounded errors.
7. Exercise cloud consent and one configured OpenAI or Anthropic turn only if
   the owner has already configured that provider; otherwise prove the precise
   visible configuration blocker without reading or changing secrets.
8. Prove normal June send preserves the literal submitted text and produces no
   Prompt Forge/Hermes rewrite event.
9. Run one English Kokoro Settings preview and owned-surface read-aloud matrix;
   obtain owner-audible confirmation or capture the exact visible blocker.

## Current HIGH release blockers

- The retained app is red and physically lacks the local GGUF runtime.
- Current-source exact archive packaging, linkage, JuneWeb, privacy, parked
  residue, signature, entitlements, and quarantine evidence is absent.
- Vault restore/save after quit/relaunch is not owner-visible proven.
- Epdoc multi-lens data/format fidelity is not runtime proven.
- Editor/graph input responsiveness and Source/Code writability are not runtime
  proven.
- Local GGUF and cloud June output are not runtime proven.
- Literal normal-send behavior is not exact-request/log proven.
- Fresh current-source audible English Kokoro is not proven.

## Recommended next action

Remain in `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. Hold the source
freeze unless a current exit check fails. When system memory is safe, perform
one serial, resource-capped current-source MAS archive and then the finite
runtime matrix above. Fix only the failed leg and rerun only that leg.

Only after the exact KEELSTONE bar passes, the canonical recommended next key
is `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08`.
