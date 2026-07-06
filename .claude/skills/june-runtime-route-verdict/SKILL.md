---
name: june-runtime-route-verdict
description: Use when materializing, auditing, or extending MAS June deterministic route witnesses, RuntimeRouter policy tables, RouteVerdict diagnostics, cloud-first/local-second model routing, lane toggles, or local chat-only capability gates without executing models or faking local tools.
---

# June Runtime Route Verdict

## Purpose

Use this skill when June needs a deterministic, auditable routing decision before model execution. The pattern turns cloud/local preference, privacy constraints, context limits, lane toggles, and tool/grammar demands into a visible `RouteVerdict` while keeping execution authority elsewhere.

Do not use this skill to launch a local model, add a sidecar, make a local lane tool-capable without an admitted deterministic grammar lane, hide a cloud fallback, or mutate runtime defaults outside the reviewed policy table.

## Required Reads

1. `docs/research/DETERMINISTIC_SUBSTRATE_INFUSION.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
4. `Epistemos/Engine/RuntimeExecutor.swift`
5. `Epistemos/LocalAgent/RuntimeRouter.swift`
6. `agent_core/tests/runtime_router_policy_source_guard.rs`
7. `agent_core/tests/runtime_router_policy_order_source_guard.rs`

## Method

1. Preserve capability truth first.
   - Cloud lanes may be agentic only when the provider/runtime can honor native tools.
   - Local lanes remain chat-tier unless a deterministic grammar/tool lane is actually admitted.
   - Route tables should be cloud-first for June's primary agentic path and local-second for privacy/offline fallback.

2. Keep the router pure.
   - Routing may read policy tables, lane toggles, and request metadata.
   - Routing must not load model bytes, execute inference, spawn processes, call network APIs, or mutate vault data.
   - A witness executor may answer `canHandle`; it must fail if asked to execute.

3. Make every refusal observable.
   - Emit `RouteVerdict.accept`, `.escalate`, or `.reject`.
   - Reject malformed policy hints before lane walking.
   - Preserve explicit reasons for disabled lanes, context overflow, privacy mismatch, residency ceiling, and unsupported tools/grammar.
   - Record bounded diagnostics; never create an unbounded route log.

4. Honor privacy and memory.
   - Privacy-sensitive packets must not route to cloud.
   - If no enabled local lane can satisfy a privacy-sensitive packet, reject honestly.
   - Local context windows are smaller; route or escalate based on the lane's real context budget.

5. Keep UI/settings as mirrors.
   - Settings can expose lane toggles keyed by stable lane ids.
   - The internal `.stub` reject bucket stays hidden from users.
   - Diagnostics and route profiles delegate to the router table instead of duplicating policy.

6. Validate with cheap guards first.
   - Run parser-only Swift checks for the router/mirrors before any App Store build.
   - Run focused Rust source guards for RuntimeRouter policy/order/toggles.
   - Save full App Store build and running MAS proof for sparse checkpoints on 16 GB machines.

## Review Checklist

- Route tables are cloud-first for June and local-second, not local-first by accident.
- Local rows/tool modes do not claim native tools or grammar support without an admitted deterministic lane.
- Preferred-lane hints reorder the governed chain but do not bypass policy validation.
- Disabled, malformed, privacy-sensitive, context-overflow, and tool/grammar failures are visible `RouteVerdict` outcomes.
- Settings hide `.stub` and persist only non-secret lane toggles.
- Diagnostics route profiles delegate to `RuntimeRouter.defaultRouteProfiles()`.
- No model load, local inference, subprocess, network call, vault mutation, or hidden fallback occurs inside the router.
