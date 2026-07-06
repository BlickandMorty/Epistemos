---
name: june-skill-learning-loop
description: "Use when adding, auditing, or hardening MAS June user-skill learning: observing successful agent tool compositions, wiring observe_composition, drafting proposed skills through deterministic gates, synthesizing NightBrain review queues, and exposing only gate-passed read-only skills in June without auto-promotion or webview mutation authority."
---

# June Skill Learning Loop

## Purpose

Use this skill when June should learn from repeated successful tool compositions without becoming an autonomous skill mutator. The pattern is: observe bounded evidence, draft locally through deterministic gates, synthesize a review queue, and expose only user-reviewed/gate-passed skills.

Do not use this skill to auto-promote a skill, let the webview edit skill files, expose unproven skills as runnable, add a subprocess/stdio MCP path, claim local model tools, or write raw absolute paths/secrets into JS-visible payloads.

## Required Reads

1. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
2. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
3. `Epistemos/JuneAgent/JuneAgentBridge.swift`
4. `Epistemos/JuneAgent/JuneAgentGateway.swift`
5. `agent_core/src/bridge.rs`
6. `agent_core/src/skill_discovery/mod.rs`
7. `agent_core/src/nightbrain/live.rs`
8. `Epistemos/Vault/SkillEvolutionService.swift`
9. `EpistemosTests/AppStoreJuneHardeningTests.swift`

## Method

1. Observe only real compositions.
   - Capture from the agent turn finalization path, not from guessed UI state.
   - Require a successful turn and at least two tool starts.
   - Filter tool names to the explicit MAS allowlist.
   - Bound tool names, tool count, inferred goal, and total trace JSON before FFI.
   - Run the FFI call off the MainActor; never block the webview or inference loop.

2. Keep SkillDiscovery the authority.
   - Use `observe_composition(trace_json)` as the only FFI ingress for composition observations.
   - Share the proposal data root through `skill_discovery::default_skill_discovery_data_dir()`.
   - Return redacted outcome payloads such as `proposed_skills/<file>`; never return absolute local paths.
   - Preserve frequency, latency, and user-accepted gates. Do not lower thresholds just to show a row.

3. Synthesize review, never promotion.
   - `skill_evolution_analysis` may scan `proposed_skills/*.skill.json` and write a bounded review summary.
   - Cap proposal count and per-proposal bytes.
   - Sort inputs for deterministic reports.
   - Strip controls and omit absolute paths.
   - User approval/promotion remains owned by the app-side skill evolution/review surface.

4. Expose only proven skills in June.
   - `hermes_bridge_skills`, `get_hermes_bridge_skill`, and toggles must pass the native promotion gate.
   - Skill documents are read-only in the webview.
   - Unproven skills are withheld from list/open/toggle paths.
   - Enable/disable state may use non-secret preferences; secrets and vault authority stay native.

5. Verify with sparse OOM-safe checks.
   - Use `git diff --check` first.
   - Use parser-only Swift checks for source guards before any App Store build.
   - Use focused Rust tests with `CARGO_BUILD_JOBS=1 CARGO_INCREMENTAL=0`.
   - Avoid local model runs and broad native builds until a deliberate checkpoint.

## Review Checklist

- Local lanes remain chat-only; no local tool or skill execution claim was added.
- Observation payloads are success-only, multi-tool, MAS-allowlisted, and bounded.
- The FFI result redacts absolute paths.
- NightBrain review writes a bounded summary and does not promote or mutate skills.
- Tests do not write into the user's real proposal queue.
- June UI surfaces only gate-passed read-only skills and withholds unproven ones.
- Runtime proof plan names the MAS task needed to show repeated composition -> proposal -> review -> user-approved skill.
