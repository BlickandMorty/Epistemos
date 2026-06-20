# SS-E — Defaults & automation audit ("derive-don't-ask") (2026-06-19)

Read-only research (subagent), code-grounded. Feeds the DEFAULTS/AUTOMATION items. Owner: *"if my app can
automate or simplify, make it happen; reduce complexity for equivalent with more simplicity; automate the
defaults."* Balance: automate defaults, NEVER delete/hide — the manual override stays, just not required.
Cross-refs SS-C (onboarding), SS-AB (model profiles), SS-F (default-drift), SS-A (clone plumbing).

## Headline
Epistemos's **runtime engine is ALREADY strongly derive-first** — idle-unload, model-fit, complexity routing,
per-model context windows + sampling are all auto-computed from hardware/model specs (the owner never sets
them). The gap is at the **edges**: (1) **onboarding still ASKS** for the two things it could most easily default
(vault path + first model) despite having the exact auto-derivation code (`defaultVaultURL`,
`installEpistemosFoundationPackage`) sitting UNUSED; (2) a handful of feature toggles default OFF that arguably
should be AC-gated ON. ~80% of *inference* config is DERIVE; the *first-run "just works"* promise is broken by 2
manual asks that block a cold-start user. **Highest-value automations are all in onboarding** (converges with
SS-C).

## Model / runtime defaults (auto, not asked)
- Default chat model = smallest Fast Gemma (`EpistemosFoundationLineup.defaultChatModelID:151`, consumed as
  `preferredLocalTextModelID` default `InferenceState.swift:3308`); lineup recommends by RAM (`candidates(for:)`
  sorts by `minimumRecommendedMemoryGB` `:120-124`).
- **Complexity auto-sizing (Fast→E2B/E4B/12B) ON by default, pure-derived** — `EpistemosFastEffortSizing
  .candidateIndex(forComplexity:candidateCount:)` (`:207`) maps QueryAnalyzer complexity→size, no user flag;
  clamps to fit; driven by `OverseerComplexityRouter.ExecutionPlan` (`ChatCoordinator.swift:1062-1119`).
- Local routing defaults `.auto` (`InferenceState.swift:3294`); cloud auto-route defaults OFF (`:3299` — correct,
  needs keys).
- **Context window: DERIVED from model-arch spec, hardcoded `switch` (`InferenceState.swift:708-719`), NOT
  GGUF-read** — GGUF lane falls back to `8_192` for unknown ids (`LocalGGUFClient.swift:537`); *unverified whether
  GGUF `n_ctx` metadata is ever read — appears not.* (SS-AB's `ModelCapabilityProfile` is doc-only, NOT in Swift
  — this switch is what SS-AB proposes to formalize.)
- Sampling per-model, auto (`optimalTemperature` switch `InferenceState.swift:829`); advanced UI opt-in
  (`inferenceAdvancedSettingsEnabled=false`).

## Memory / perf auto-tuning (strong — mostly done)
- Idle-unload auto-sized by RAM band (`MLXInferenceService.swift:343-377`: 16/24/36GB→4/6/10s + thermal). No knob.
- Model fit auto-gated `LocalChatModelMemoryGate.fits` (6GB headroom `EpistemosFoundationLineup.swift:229-242`) +
  `hardwareCapabilitySnapshot.supports`. Only manual lever = the explicit "Run anyway" override
  (`memoryGateForcedModelIDs` `InferenceState.swift:5685`) — exactly right (derive default + keep override).
- Hardware tier auto-detected (`HardwareTierManager.swift:58-101`: sysctl→tier→budget `mem*0.60`); KV drop on
  pressure automatic (`MLXInferenceService.swift:1163`). **No manual memory/ctx knobs that should be derived.**

## Paths / dirs / ports
- **Vault path: ASKED (highest-value gap)** — `defaultVaultURL` (`FirstRunBootstrap.swift:60`) computes
  `~/Documents/Epistemos` but **zero non-test callers** (dead, SS-C); onboarding forces `NSOpenPanel`
  (`SetupAssistantView.swift:149,318`) + Next `.disabled(vaultURL==nil)` (`:155`).
- **Ports/dirs/caches: auto-defaulted (good)** — LocalModelServer `127.0.0.1:1337` (`AppBootstrap.swift:1997`),
  hub/cache `paths.hubDirectory(for:)` (`LocalModelInfrastructure.swift:2739`), shadow `<vault>/.epcache/shadow`,
  MCP config in-memory (`AgentBackend.swift:15`), clone backends Pro-gated stubs (no user port). Matches SS-A
  "auto-default all plumbing" — no action.

## Feature-enablement defaults (`EpistemosConfig.swift`)
- **ON (good):** ecoMode `:14`, friction `:23`, nightBrain `:27` (AC + 300s idle), ocrFallback `:18`,
  ssmAutoSaveOnTurnEnd `:34`.
- **OFF — review:** `captureEnabled=false :17` (correct — needs Screen Recording), `heartbeatEnabled=false :43`,
  `claudeManagedSessionsEnabled=false :38` (correct — needs key), `ssmStatePersistenceEnabled=false :33`,
  `nightBrainMenuBarAgent=false :30`, `graphIndexChatsEnabled=false` (`SettingsView.swift:1386`, the SS-F fake).
- **Flag-ON ≠ wired (SS-F):** Act/Work clones gate on `EPISTEMOS_ACT_OSAURUS_V0`/Work flags but runtimes are inert
  Pro stubs (`ActOsaurusGateStatus.swift:33-40`) — flag-ON = honest "armed but inert," NOT a working feature. Do
  NOT treat these as "automate-to-ON" candidates.

## ASK-vs-DERIVE scorecard
| Surface | Now | Derive? | Source | Priority |
|---|---|---|---|---|
| **Vault path** | **ASK** (blocks Next) | YES | `defaultVaultURL`→`~/Documents/Epistemos` (dead, ready) | ★ HIGH |
| **First model install** | **ASK** (punts to Settings) | YES | `installEpistemosFoundationPackage()` (RAM-filtered, ready) | ★ HIGH |
| Model/tier (use-time) | DERIVE | done | Fast rep + RAM lineup | — |
| Runtime routing | DERIVE (.auto) | done | OverseerComplexityRouter | — |
| Complexity sizing | DERIVE (on) | done | EpistemosFastEffortSizing | — |
| Context window | DERIVE (hardcoded) | partial | model spec; could read GGUF n_ctx | LOW |
| Sampling | DERIVE (per-model) | done | optimalTemperature | — |
| KV/idle-unload | DERIVE | done | RAM band + thermal | — |
| Model fit | DERIVE+override | done | LocalChatModelMemoryGate | — |
| Ports/dirs/caches | DERIVE | done | :1337 / hubDirectory / .epcache | — |
| Cloud keys | ASK (correct) | NO | Keychain secret | — |
| Permissions | ASK (correct) | NO | macOS TCC | — |
| Engines (clones) | OFF (Pro stub) | NO (inert) | flag = honest status | — |
| Heartbeat | OFF | maybe | AC-gated default-ON like NightBrain | MED |

## Ordered plan (automate, keep override)
1. **[S] Wire `installEpistemosFoundationPackage()` into onboarding model step** — replace the "install later in
   Settings" punt (`SetupAssistantView.swift:191-205`) with one-tap "Install recommended" (RAM-filtered, already
   at `SettingsView.swift:3248`); keep Skip + Settings as override. **Biggest "just works" win** (SS-C).
2. **[S] Default the vault to `defaultVaultURL()`** — pre-fill `vaultSync.vaultURL` with `~/Documents/Epistemos`
   (`FirstRunBootstrap.bootstrap` scaffolds), turning the vault step into "Confirm / Change folder" not a hard
   gate; unblocks the `.disabled` Next; revives `FirstRunBootstrap.swift:60` (SS-C).
3. **[M] Read GGUF `n_ctx` to derive context** instead of the `8_192` fallback (`LocalGGUFClient.swift:537`); fold
   into SS-AB `ModelCapabilityProfile` so the per-model `switch` (`InferenceState.swift:708`) becomes data-driven;
   keep arch-spec values as default.
4. **[M] Reconsider `heartbeatEnabled`/`ssmStatePersistenceEnabled` defaults** — both OFF but safe AC-gated like
   NightBrain; an AC-gated default-ON would make the app feel alive out of the box. Override stays a toggle.
5. **[L] Audit-only:** confirm no GGUF lane silently ignores `optimalTemperature`/`maxContextTokens` (per-model
   values in `InferenceState`; propagation to the GGUF executor not traced).

## Unverified
GGUF executor's actual use of `optimalTemperature`/`maxContextTokens` (propagation to `LocalGGUFClient` not
traced); whether GGUF `n_ctx` is ever read (appears not — `8_192` literal); `ModelCapabilityProfile` doc-only
(SS-AB), absent from `*.swift`.

Key files: `Views/Onboarding/SetupAssistantView.swift:147-214` (the 2 asks) · `Vault/FirstRunBootstrap.swift:60`
(dead default) · `Engine/LocalModelInfrastructure.swift:2701` (RAM-filtered installer) · `Engine/Epistemos
FoundationLineup.swift:120,151,207,229` · `State/InferenceState.swift:3294,3299,708,829,5685` ·
`State/EpistemosConfig.swift` (flag defaults) · `Engine/MLXInferenceService.swift:343` · `Omega/Inference/
HardwareTierManager.swift:58`. Cross-refs SS-C/AB/F/A.
