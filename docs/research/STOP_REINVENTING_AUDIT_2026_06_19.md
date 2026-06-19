# STOP REINVENTING — Epistemos vs cloned tools (S1, 2026-06-19)

Read-only research (subagent), all claims code-grounded. Feeds DEEP_PLAN_AUDIT_HUB.

## Keystone insight (converges with S4)
The recurring pattern is NOT "we hand-rolled what a clone does better, rip it out." Epistemos
ALREADY adopted the proven cores (HF `HubClient`, `llguidance`, Hermes-3 grammar in
`function_call.rs`, Goose recipe types). **The disease is SPRAWL + NON-WIRING: Epistemos built
the proper abstraction, then left it disconnected, while a crude older heuristic does the live
work.** So most fixes are **WIRE-what-we-have / DELETE-the-dead-twin**, not "import a clone."
**The owner's four broken areas (model selection, tool dispatch, skills, download) share ONE
root cause: built-then-not-wired.**

## Findings (code-grounded)
- **R1 routing — `RuntimeRouter.swift:580 route(_:)` is DEAD** (zero production callers; only Settings/badges reference it). It already mirrors Hermes `runtime_provider`/Goose lead-worker. **The "everything routes to Qwen-3-4B" bug is BECAUSE this proper router never got wired** — the live path fell to crude heuristics. FIX: **WIRE RuntimeRouter** into dispatch; keep it the intra-local lane chooser (NOT the Act picker — 3rd-route hazard).
- **R2 — `TriageService.InferencePolicyEngine` (`:669 preferredAutomaticLocalModel`) is the LIVE selector** — threshold-soup + hardcoded model-priority list; recently patched off the silent-GPT + auto-substitute-Qwen bugs. KEEP short-term, FOLD into R1 (its model-priority list → R1's preference table). Honest "no local → nil" must survive.
- **R3 — `agent_core routing.rs ConfidenceRouter`** live for cloud tiering but **local arms STUBBED** (`bridge.rs:496` "local providers not wired into agent_core yet" → Local decisions silently fall back to cloud). KEEP for cloud; document dead local arms (doctrine: `agent_loop.rs:147 LocalProviderNotAllowed`).
- **R4 — `LocalAgent/ConfidenceRouter.swift` + `DualBrainRouter.swift` + `HybridRouter.swift` are DEAD** ("never instantiated in production"; zero instantiations). **DELETE** (after rehosting the diagnostic `routeProfiles()` adapter). Sprawl: 4 local/cloud deciders + 3 model-ID tables for 2 live decisions → collapse to R1+R2.
- **T1 tool-call — the Swift constrained decoder is a FAKE STUB.** `MLXConstrainedGenerator.swift JSONSchemaLogitProcessor` does **no masking** (just subtracts 50 logits from 2 hardcoded Qwen EOS ids); `JSONParserState`/`allowedTokenCache` are dead; `ToolSchemaGrammar.swift` emits an EBNF string nobody enforces; `ConstrainedDecodingService.isAvailable` is permanently false. **THE one genuine "adopt the proven engine" win:** bridge the working in-repo Rust `llguidance` grammar (`grammar/mod.rs dispatch_schema_for_tools`) into MLX decoding instead of the fake Swift compiler. (Complements the build loop's GGUF-Gemma `--json-schema` part-2b, which is the GGUF-lane analog.)
- **T2/T3 tool-call** — `IncrementalToolCallDetector` (Swift) ↔ Rust `StreamingToolCallDetector` is a justified maintained twin (in-process streaming can't FFI per-token); `ToolCallParser` already calls Rust FFI first. KEEP; add a parity test.
- **T4 — `ToolRegistry::execute`** is the single robust dispatch owner. Don't touch.
- **S1 skills — progressive-disclosure skills are COMPILED OUT of MAS** (`registry.rs:963 #[cfg(feature="pro-build")]`; `build-agent-core.sh` builds AppStore with `mas-build`) → shipping app exposes only the legacy CRUD `skills` tool. **This is why skills feel broken.** DECIDE the gate honestly (promote to MAS — it's MIT clean-room, no subprocess — OR surface honest "Pro only"); keep `install_from_github/url` Pro/quarantined.
- **S2 skills — `self_evolution.rs propose_repeated_success_skill` + `skill_discovery::observe` are BOTH DEAD** (no production caller; depend on `procedural_memory` records that are NEVER written — `write_procedure`/`record_skill_outcome` FFI have no Swift callers). WIRE one (self_evolution, simpler) into the loop's tool-success path, DELETE the other. Hermes-richer-triggers (overlap #4) is moot until outcomes are recorded.
- **S3 skills — 4 disjoint storage dirs, PATH MISMATCH:** router `vault/skills` · tools `~/.epistemos/skills` · discovery `agent_core/data/proposed_skills` · Swift `SkillManifest`. Skills created by `skill_manage` (→`~/.epistemos/skills`) are NOT read by `skill_router` (→`vault/skills`) → created skills never reach agent context. **UNIFY to one canonical dir** (the load-bearing skills fix; preserve existing on migration). (S4 separately flagged the 7 authored `.agents/skills/*.SKILL.md` in a 5th unread path.)
- **D1 download — NOT reinvented:** `ModelDownloadManager.install` delegates to the official HF `HubClient.downloadSnapshot` (Range-resume, concurrent shards) + verify + atomic finalize. KEEP.
- **D2 download — the likely "download broken/corrupted" ROOT:** `LocalModelInfrastructure.purgeStaleStagingDirectories` (30-min grace) **silently defeats resume on large/slow models** (20GB Qwen MoE) — resume evaporates; plus no auto-retry on transient failure; full SHA-256 re-hash at finalize looks frozen ("Finalizing…"). FIX: condition the purge on active-download / raise the grace; add bounded retry. In-house wrapper bug, not a clone gap.
- **W1 Goose — vendored RetryConfig/SuccessCheck types carried but INERT** (`runWorkSession` throws `engineNotWired`; nothing consumes them). WRAP Goose core behind the seam when armed (`EPISTEMOS_WORK_GOOSE_V0` Pro); `Shell`/`on_failure` exec stays Pro + `harden_cli_subprocess`.

## Cross-cutting takeaways
1. Owner's 4 broken areas = ONE cause: **built-then-not-wired** (RuntimeRouter, progressive skills, self-evolution/procedural memory, constrained decoding, Goose self-correction — all present+tested but compiled-out / never-called / stubbed at the last mile). Almost nothing needs a fresh clone import; it needs CONNECTING.
2. Router sprawl to delete: R1(dead) R2(live) R3(partial) R4(dead) → collapse to R1+R2.
3. The one genuine "adopt the proven engine" win: **T1** — bridge the working `llguidance` grammar into MLX decoding, kill the fake Swift processor.
4. Download is fine (D1, proven HF HubClient); only the 30-min staging purge (D2) needs fixing.

Key files: `Epistemos/LocalAgent/RuntimeRouter.swift:580` · `Epistemos/Engine/TriageService.swift:669` · `agent_core/src/routing.rs` + `bridge.rs:496` · `Epistemos/LocalAgent/ConfidenceRouter.swift` + `Omega/Inference/{DualBrainRouter,HybridRouter,MLXConstrainedGenerator,ToolSchemaGrammar}.swift` · `agent_core/src/grammar/mod.rs` · `agent_core/src/tools/registry.rs:963` · `agent_core/src/agent_runtime/{self_evolution,procedural_memory}.rs` + `skill_discovery/mod.rs` · `agent_core/src/skill_router.rs` · `build-agent-core.sh` · `Epistemos/Engine/{ModelDownloadManager,LocalModelInfrastructure}.swift` · `agent_core/src/work.rs` + `Epistemos/Work/WorkBackend.swift`.
