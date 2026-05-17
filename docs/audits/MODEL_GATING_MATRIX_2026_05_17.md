# Model Gating Matrix — 2026-05-17

Scope: §4.E Phase A. Claims are grep-verified against the current branch and pinned to the local-agent acceptance bar.

## Matrix

| Gate | File:line anchor | Current rule | User effect | Doctrine pin | Status |
|---|---:|---|---|---|---|
| Local model agent allow-list | `Epistemos/State/InferenceState.swift:420` | `canActAsAgent` allows Qwen, DeepSeek, LFM, Jamba, Falcon, LocalAgent, and Mistral Small; still denies Gemma and Devstral. | Mistral Small is now available for local agent/routing once installed; unsupported families remain honestly gated. | §4.F per-model native grammars | PARTIAL/IMPROVED |
| Local loop execution | `Epistemos/State/InferenceState.swift:462` | `canRunLocalAgentLoop = canActAsAgent && LocalToolGrammar.supportsLocalAgentLoop`. | Soft-guidance loop can run even without strict masking. | Local-first fallback doctrine | ALIGNED |
| User-visible agent mode | `Epistemos/State/InferenceState.swift:475` | `supportsAgentMode = canActAsAgent && supportsStructuredToolCalling`. | UI hides agent mode when strict imports fail, even though soft-guidance loop can execute. | Honest capability gating | STALE/PARTIAL |
| Runtime local loop availability | `Epistemos/State/InferenceState.swift:4017` | `supportsLocalAgentLoop` checks `effectiveLocalAgentTextModelID != nil`. | Agent-mode availability also depends on selected/effective model. | §4.F local assistant | PARTIAL |
| Cloud models master switch | `Epistemos/State/InferenceState.swift:4479` | `cloudModelsEnabled = activeAIProvider != .localOnly`. | Cloud list suppressed in local-only routing. | Local-first, cloud as escalation | ALIGNED |
| Cloud credential gate | `Epistemos/State/InferenceState.swift:4634` | Provider is configured if API key or OAuth credential exists. | Missing key blocks activation. | Honest cloud-key gating | ALIGNED |
| Cloud pick fallback | `Epistemos/State/InferenceState.swift:5130`, `:5138` | Focus local-only or missing credentials persists local fallback and records pending unavailable cloud selection. | Prevents raw cloud failure, but still collapses selected cloud to local. | No silent fallback | STALE until UI explains each collapse inline |
| Strict local tool grammar | `Epistemos/LocalAgent/LocalToolGrammar.swift:38` | Requires `MLXStructured`, `CMLXStructured`, and `JSONSchema` imports. | One failed import turns strict tool calling off for every local model. | §4.F strict grammar badge | ACTIVE IN PROBE |
| Soft local tool guidance | `Epistemos/LocalAgent/LocalToolGrammar.swift:46` | Always returns true. | Local loop has a fallback path even when strict grammar is off. | Local-first resilience | ALIGNED |
| Project dependency | `project.yml:126`, `:230`, `:536` | Direct product dependency is `MLXStructured`; package graph resolves `JSONSchema`; `CMLXStructured` target compiles as part of package. | App target generated `CMLXStructured-*.pcm` and runtime strict gate is ACTIVE. | §4.E Phase A.2 | VERIFIED |
| Router model capability | `Epistemos/LocalAgent/ConfidenceRouter.swift:219` | Router now has task-class model preference tables and route profiles; local capability still bottoms out at `canRunLocalAgentLoop`. | Mistral Small participates in reasoning/synthesis/local-research routing; strict/soft confidence demotion is still future work. | Multi-model constellation | PARTIAL/IMPROVED |
| Default primary agent hard gate | `Epistemos/Engine/LocalModelInfrastructure.swift:1046` | Canonical 32 GB threshold for 36B default. | 16 GB machines default to Qwen 3 8B. | Dense 4-bit historical bound | ALIGNED for default safety |
| Power-user threshold | `Epistemos/Engine/LocalModelInfrastructure.swift:1062`, `:1066`, `:1073` | UserDefaults-backed power-user key lowers effective threshold to 16 GB. | Settings exposes the toggle and picker rows show explicit OOM-risk badges for large local models. | V6.1 ternary/Sherry/KV-Direct target | UI WIRED, LIVE PROOF PENDING |
| Test seam default resolver | `Epistemos/Engine/LocalModelInfrastructure.swift:1098` | Pure overload accepts power-user mode and opt-in inputs for 36B selection tests. | Tests can exercise the 16 GB power-user behavior. | §4.E power-user override | ALIGNED |
| Default primary accessor | `Epistemos/Engine/LocalModelInfrastructure.swift:1114` | Reads current hardware, opt-in flag, and `effectivePrimaryAgentModelMinHostRAMGB`. | Runtime default can honor power-user mode if the toggle is set. | §4.E quick win | ALIGNED/PARTIAL |
| Startup probe | `Epistemos/App/AppBootstrap.swift:2360` | Logs selected local agent, host GB, effective min, power-user state, strict/soft loop state, cloud status. | Debug launch reports Qwen 3 8B, host 18 GB, 36B min 32 GB, power-user OFF, strict ACTIVE, soft ON, local loop OK. | §4.E Phase A.2 | CAPTURED |
| Settings power-user toggle | `Epistemos/Views/Settings/SettingsView.swift:1436` local section | Toggle is backed by `LocalModelCatalog.powerUserModeDefaultsKey`. | User can explicitly expose 16 GB 36B affordances, with risk copy. | §4.E Phase B.5 | WIRED |
| Active constellation row | `Epistemos/Views/Settings/ActiveConstellationRow.swift` | Row shows hot/warm/cold, strict/soft, native grammar, and agent capability badge. | User can inspect local brain state and model grammar status. | §4.F B2 | WIRED |

## Findings

1. The RAM gate is user-visible now: runtime accessor honors `epistemos.localAgent.powerUserMode`, Settings exposes the toggle, and tests cover the explicit 36B opt-in path. Live 36B stability on constrained hardware is still not proven.
2. Local agent visibility is stricter than local agent execution: `supportsAgentMode` requires strict imports, while `canRunLocalAgentLoop` can use soft guidance. This is now visible through picker/constellation badges, but live grammar confidence demotion is still future work.
3. Cloud fallback is now tracked as `pendingUnavailableCloudSelection`, but the picker still needs explicit "missing key" / "Focus forced local" copy at the point of choice to satisfy the no-silent-fallback bar.
4. `LocalToolGrammar` has model-family profiles and parser fixtures, but strict masking availability is still global and does not yet track per-family runtime success rates.

For the post-merge unbuilt/gated checklist, see `docs/audits/T2_GATED_AFTER_MERGE_TRACKER_2026_05_17.md`.

## Probe Capture

Debug app launch capture via `/usr/bin/log stream --info --style compact`:

```text
2026-05-17 07:10:36.193 I  Epistemos[97644:1484dde] [com.epistemos:app] Local agent model selected: Qwen 3 8B, ~4.000000 GB (host 18 GB, 36B opt-in min 32 GB, power-user mode OFF)
2026-05-17 07:10:36.193 I  Epistemos[97644:1484dde] [com.epistemos:app] Local model gating probe: strict-tool-grammar=ACTIVE, soft-guidance=ON, local-agent-loop=OK, cloud-models=ON, configured-cloud-providers=
```
