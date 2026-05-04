# Codex to Claude Continuation Handoff

> **Index status**: CANONICAL-HISTORICAL — Session handoff; kept for state recovery (30-day minimum). No copy to _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



**Date:** 2026-04-17  
**Current source-of-truth commit:** `31214a4d`  
**Current branch:** `codex/runtime-input-audit`  
**Audience:** Claude Code  
**Goal:** Continue the interrupted multi-lane hardening, finish the remaining runtime/setup/product work honestly, and avoid re-discovering the same blockers.

---

## 1. Read This First

Before changing anything, Claude should read these in order:

1. `/Users/jojo/Downloads/Epistemos/AGENTS.md`
2. `/Users/jojo/Downloads/Epistemos/.agents/skills/epistemos_release_audit/SKILL.md`
3. `/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-03-28-final-claude-release-master-handoff.md`
4. `/Users/jojo/Downloads/Epistemos/docs/AGENT_PROGRESS.md`
5. `/tmp/epistemos-mode-audit-refresh-2026-04-17.log`

Important trust boundary:

- `docs/AGENT_PROGRESS.md` is currently overstated and should **not** be treated as proof that the app is release-ready or that all recent agent/runtime work is complete.
- Several earlier green test runs were real, but some "live local model" tests are flag-gated and can appear green while skipping the actual live path.
- The repo is very dirty. Do not revert unrelated work. Work narrowly.

---

## 2. What Codex Actually Finished

### A. Streaming / cloud runtime correctness

These are real code fixes, not just test updates:

- Fixed the OpenAI/Codex SSE transport bug in `Epistemos/Engine/URLSessionTransportSupport.swift`.
- Root issue: `URLSession.AsyncBytes.lines` in this path can omit blank SSE separators, which caused consecutive events to merge into one invalid JSON payload.
- Current fix:
  - flush the previous event when a new `event:` header is encountered
  - stop silently swallowing malformed JSON in the stream path
- Regression coverage added in `EpistemosTests/CloudStreamingParserTests.swift`.

Relevant files:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/URLSessionTransportSupport.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/CloudStreamingParserTests.swift`

### B. Web tool availability contract

- Fixed the `web_search` tool advertising bug in `agent_core/src/tools/web.rs`.
- Current behavior:
  - if no backend is configured, `WebSearchHandler::new()` fails immediately
  - `web_search` should disappear instead of surfacing as a broken callable tool

Relevant file:

- `/Users/jojo/Downloads/Epistemos/agent_core/src/tools/web.rs`

### C. Hidden local agent tier contract

- Fixed one stale mode-contract test in `EpistemosTests/ConfidenceRouterTests.swift`.
- Product behavior is intentional:
  - some local tiers stay hidden from the interactive chat picker
  - a stronger hidden tier can still back the local agent loop
- The old test treated that as a failure. The updated test now matches the intended routing policy.

Relevant file:

- `/Users/jojo/Downloads/Epistemos/EpistemosTests/ConfidenceRouterTests.swift`

### D. Earlier session work that was already implemented before the final interruption

These were completed earlier in the session and should be preserved, but several still need broader manual/runtime verification:

- Agent plan/todo side panel became directly editable through the note-style prose editor.
- `H1` retro font stayed in chat; `H2` retro font was added; body text shifted toward the Claude desktop typography direction.
- Artifact / side-panel doc surfaces gained a `Doc` / `MD` toggle.
- Landing popover was restored from newer in-session memory rather than old git state.
- Graph labels were fixed so they no longer disappear on the default graph path, and atlas load failures now log useful diagnostics.
- The code editor ask bar was hidden for code files only.
- Project auto-add behavior was fixed via filesystem-synced groups in `project.yml`.
- Voice capture / Quick Capture / Siri discoverability was restored in landing and settings surfaces.
- iMessage settings were turned into a setup doctor instead of a raw failing settings form.
- The app-freeze-at-launch bug caused by over-eager vault recovery gating was fixed so bad vault state should no longer block input globally.

Do not assume all of those are fully polished. Some are implemented but not fully re-audited end-to-end in the current runtime build.

---

## 3. What Is Verified Right Now

### A. Broad mode matrix

After the `ConfidenceRouter` test fix, this targeted mode matrix passed:

- `TriageServiceTests`
- `LocalAgentLoopTests`
- `DeviceAgentServiceTests`
- `ResearchModeTests`
- `ConfidenceRouterTests`
- `LocalModelInfrastructureTests`
- `RuntimeCapabilityAndPerformancePolicyTests`

Result:

- `116 tests in 7 suites passed`

Evidence:

- log: `/tmp/epistemos-mode-matrix-rerun-2026-04-17.log`
- xcresult: `/tmp/epistemos-mode-dd/Logs/Test/Test-Epistemos-2026.04.17_11-44-59--0500.xcresult`

### B. Live cloud/backend audit

This is real live backend evidence, not just unit tests:

- `lite_fast` passed
- `pro_deep` passed
- `gpt52_with_instructions` passed
- multi-step `agent` tool loop passed

Evidence:

- `/tmp/epistemos-codex-mode-audit-2026-04-17.log`

Important content in that log:

- `lite_fast` produced a valid concise answer
- `pro_deep` produced a structured deeper answer
- `gpt-5.2` only behaved correctly when top-level `instructions` was present
- the `agent` path executed function calls across multiple turns and returned a coherent blocker summary

### C. Tool bridge audit

This was executed through the real Rust bridge:

- `chat_lite` tool count: `24`
- `chat_pro` tool count: `33`
- `agent` tool count: `60`
- `read_file`: passed
- `search_files`: passed
- `workspace_search`: passed
- `bash_execute`: passed
- `web_search`: hidden as expected without backend

Evidence:

- `/tmp/agent-tool-probe-2026-04-17.log`

### D. Fresh Rust-side contract checks

These all passed and are useful because they protect the agent specialty bridge and the Codex tool-shape assumptions:

- `/tmp/agent-core-perceive-test-2026-04-17.log`
- `/tmp/agent-core-interact-test-2026-04-17.log`
- `/tmp/agent-core-screen-watch-test-2026-04-17.log`
- `/tmp/agent-core-web-search-backend-test-2026-04-17.log`
- `/tmp/agent-core-codex-tool-schema-test-2026-04-17.log`
- `/tmp/agent-core-codex-input-roundtrip-test-2026-04-17.log`

### E. Earlier focused Swift verification

Also keep this earlier passing slice in mind:

- `CloudProviderAuthServiceTests`
- `CloudStreamingParserTests`

Evidence:

- log: `/tmp/epistemos-codex-test-rerun.log`
- xcresult: `/tmp/epistemos-codex-dd/Logs/Test/Test-Epistemos-2026.04.17_11-32-55--0500.xcresult`

---

## 4. What Is Still Not Finished

This is the main section Claude should use as the active work queue.

### A. Real local-model install / local runtime is still not proven

This is the single biggest unfinished runtime slice.

Facts established:

- `curl -I https://huggingface.co` still fails on this machine with DNS resolution failure.
- `~/Library/Application Support/Epistemos/Models/manifests/install-state.json` is absent.
- `config/model_manifest.json` still marks prepared assets as `missing`.
- The app-owned local models root is mostly empty.
- There are some separate `model_vaults` and a staged 35B directory, but Codex did **not** prove the active runtime is consuming them.

Very important nuance:

- `LocalModelInfrastructureTests` contains "live install smoke" tests.
- Those tests only execute the real install path if the `/tmp/epi-live-*` gate files exist.
- A normal green run does **not** prove local install/runtime is working.

Codex tried to force a real local release sweep:

- created `/tmp/epi-live-local-model-release-sweep`
- created `/tmp/epi-local-model-sweep-models.txt`
- ran `xcodebuild ... -only-testing:EpistemosTests/LocalModelReleaseSweepTests`

What happened:

- the run spent the entire attempt recompiling the huge MLX + Swift + Epistemos test stack
- it never reached the meaningful install/runtime assertion before it was stopped

Evidence:

- partial log: `/tmp/epistemos-live-local-release-sweep-2026-04-17.log`

Claude should treat local runtime status as:

- **not verified**
- **environment-blocked**
- **not yet a demonstrated app regression**, but also **not ready to claim working**

### B. Release-readiness is still unfinished

Do not ship based on the current state.

Still missing or not freshly re-certified:

- Developer ID signing on the real distributable app
- notarization
- DMG packaging
- final direct-distribution validation
- repeated no-edit verification passes
- fresh manual runtime pass on the exact candidate bundle

Important earlier truth from this session:

- direct distribution is the target, not Mac App Store
- entitlements/runtime posture remain outside MAS constraints
- older docs that read as green are not reliable proof anymore

### C. iMessage is better instrumented but not proven working in the user’s actual active app copy

What Codex finished:

- turned the iMessage settings into a setup doctor
- made it detect the exact running app path
- added guidance around Full Disk Access, Messages automation, relaunch, and duplicate app copies

What remained unresolved:

- the user likely had two Epistemos app copies running at once
- Full Disk Access must apply to the exact app copy doing the polling
- Codex did not complete a final runtime proof that the user’s live chosen build can now open `chat.db` and poll successfully

Claude should manually verify:

1. which app copy is running
2. whether that exact copy has Full Disk Access
3. whether Messages automation consent is granted
4. whether the running build stops logging `unable to open database file`

### D. Agent surface still needs more convergence with main chat

Codex moved the agent experience closer to a main-chat-like route and reduced crowding, but the user was still unhappy with the agent page direction and density.

User’s intent that remains only partially satisfied:

- agent should feel like a real first-class page, not a command-center dashboard
- it should visually converge much more strongly with main chat
- it should keep agent-specific controls, but in a cleaner, more native arrangement
- more buttons likely still need manual validation because the user explicitly said many were broken or regressed

Claude should assume:

- implementation direction is partially there
- design polish is not done
- manual interaction testing is required

### E. Setup/settings surfaces still need a broader user-friendly sweep

Codex improved:

- voice capture discoverability
- Siri/Shortcuts discoverability
- iMessage setup guidance

But the user explicitly said:

- “lots of these setup settings don’t work”
- they want setup flows to feel more automated and native

So Claude should continue the same pattern across the remaining settings/categories:

- find any page that only dumps an error
- replace it with guided status + direct action buttons + exact permission/state diagnosis
- manually exercise the buttons where possible

### F. The app still needs a real full-button / full-surface runtime walk

This did not happen comprehensively.

What Codex did do:

- verified many source contracts and targeted test slices
- fixed several real routing/runtime issues

What Codex did **not** finish:

- open the running app and comprehensively click through all chat lanes, agent actions, setup pages, landing routes, popovers, and side panels
- recursively fix every dead button or broken control

The user explicitly asked for this broader behavior-driven audit. Claude should still do it.

---

## 5. Repo State and Working Tree Reality

Current branch:

- `codex/runtime-input-audit`

Current short commit:

- `31214a4d`

Repo state:

- extremely dirty
- many unrelated modifications existed before or alongside this interrupted pass
- do not attempt cleanup by resetting broadly

Files Codex definitely modified in this most recent mode-audit lane:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/URLSessionTransportSupport.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/CloudStreamingParserTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/ConfidenceRouterTests.swift`
- `/Users/jojo/Downloads/Epistemos/agent_core/src/tools/web.rs`

There are many other modified files in the worktree from prior lanes or concurrent work. Claude must inspect carefully before touching anything adjacent.

---

## 6. Recommended Execution Order for Claude

This order is deliberate. It avoids wasting time on polish before the important runtime truth is known.

### Phase 1: Preserve and verify the current mode/runtime fixes

1. Read the four most recent modified files listed above.
2. Re-run the broad mode matrix first.
3. Re-open the live cloud and tool audit logs.
4. Re-run the targeted Rust specialty/tool contract tests if needed.
5. Confirm no regression was introduced by any additional local edits before expanding scope.

Suggested commands:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-mode-dd test \
  -only-testing:EpistemosTests/TriageServiceTests \
  -only-testing:EpistemosTests/LocalAgentLoopTests \
  -only-testing:EpistemosTests/DeviceAgentServiceTests \
  -only-testing:EpistemosTests/ResearchModeTests \
  -only-testing:EpistemosTests/ConfidenceRouterTests \
  -only-testing:EpistemosTests/LocalModelInfrastructureTests \
  -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests
```

```bash
cd agent_core
cargo test perceive_forwards_app_and_depth_and_wraps_response
cargo test interact_forwards_action_payload
cargo test screen_watch_forwards_mode_and_condition
cargo test web_search_fails_without_backend
cargo test codex_tool_schema_is_flat_function_shape
cargo test builds_codex_input_with_function_call_round_trip
```

### Phase 2: Settle the local-model truth

Claude should not keep speaking vaguely about local models. Settle it decisively.

1. Recheck whether network access to Hugging Face is now working.
2. Inspect the real active install root.
3. Inspect whether there is any offline-prepared snapshot path that can be adopted without network.
4. If network is still dead, say so plainly and stop pretending local install is nearly done.
5. If network is fixed, rerun a **real** flagged local install smoke and capture the result.

Suggested checks:

```bash
curl -I --max-time 10 https://huggingface.co
find "$HOME/Library/Application Support/Epistemos/Models" -maxdepth 5 -print
sed -n '1,220p' config/model_manifest.json
```

If network is restored, use the flag-gated live path and wait for the actual test body:

```bash
touch /tmp/epi-live-local-model-release-sweep
printf 'qwen35_4B4Bit\n' > /tmp/epi-local-model-sweep-models.txt
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' \
  -derivedDataPath /tmp/epistemos-live-local-dd test \
  -only-testing:EpistemosTests/LocalModelReleaseSweepTests
```

If that still recompiles forever, Claude may need to:

- build once first
- then use `test-without-building`
- or isolate a narrower live harness if a smaller executable path is possible

### Phase 3: Finish the setup/usability audit

Priority order:

1. iMessage Driver
2. voice capture / Quick Capture / Siri
3. other settings pages with setup flows or error surfaces
4. anything user-facing that still dumps raw technical errors without guided recovery

For iMessage specifically:

1. determine the exact running app path
2. verify Full Disk Access for that exact copy
3. relaunch that exact copy
4. run the in-app refresh
5. watch logs for `chat.db` open behavior
6. confirm whether polling now works or still fails

### Phase 4: Finish the agent/main-chat convergence

This is largely product/UI work, but the user cares about it.

Goals Claude should actively target:

- agent route should feel like a sibling of main chat, not a center-column dashboard
- top utility row should be calmer and more native
- command-center phrasing and framing should disappear where it no longer fits the product direction
- quick actions and agent controls should feel integrated rather than bolted on
- verify actual button behavior manually

### Phase 5: Finish the full runtime button audit

Do a real manual pass. Not just tests.

Claude should launch the app and work through:

- landing page
- landing popover
- chat mode submit path
- agent mode submit path
- chat composer controls
- artifact toggle paths
- plan/doc side panel
- settings categories
- iMessage Driver
- Quick Capture
- any visible toolbar/utility buttons on the new agent page

If a control is dead, log it, inspect the action path, patch minimally, and retest immediately.

### Phase 6: Only after that, resume release closure

Once the runtime truth is known, continue the release lane:

1. clean release evidence
2. release build
3. preflight
4. manual runtime checklist
5. Developer ID / notarization / DMG

Do not call the app ready before that.

---

## 7. Specific Open Questions Claude Should Answer

Claude should come back with explicit answers to these, not vague summaries:

1. Does the user’s currently running Epistemos build now have working iMessage polling?
2. Are local model installs actually possible on this machine today?
3. If not, is the blocker DNS/network only, or is there also an app/runtime bug?
4. Which visible agent-page buttons or controls are still broken in the live app?
5. Which settings/setup surfaces still present raw errors or dead flows?
6. Is the current candidate build safe to describe as stable for cloud chat modes?
7. What exact work remains before direct release readiness can honestly be claimed?

---

## 8. Logs and Artifacts Worth Preserving

Claude should not overwrite these casually. Read them first.

- `/tmp/epistemos-mode-audit-refresh-2026-04-17.log`
- `/tmp/epistemos-mode-matrix-2026-04-17.log`
- `/tmp/epistemos-mode-matrix-rerun-2026-04-17.log`
- `/tmp/epistemos-mode-dd/Logs/Test/Test-Epistemos-2026.04.17_11-40-37--0500.xcresult`
- `/tmp/epistemos-mode-dd/Logs/Test/Test-Epistemos-2026.04.17_11-44-59--0500.xcresult`
- `/tmp/epistemos-codex-mode-audit-2026-04-17.log`
- `/tmp/agent-tool-probe-2026-04-17.log`
- `/tmp/epistemos-codex-test-rerun.log`
- `/tmp/epistemos-codex-dd/Logs/Test/Test-Epistemos-2026.04.17_11-32-55--0500.xcresult`
- `/tmp/epistemos-live-local-release-sweep-2026-04-17.log`
- `/tmp/agent-core-perceive-test-2026-04-17.log`
- `/tmp/agent-core-interact-test-2026-04-17.log`
- `/tmp/agent-core-screen-watch-test-2026-04-17.log`
- `/tmp/agent-core-web-search-backend-test-2026-04-17.log`
- `/tmp/agent-core-codex-tool-schema-test-2026-04-17.log`
- `/tmp/agent-core-codex-input-roundtrip-test-2026-04-17.log`

---

## 9. Final Honest Summary

What is genuinely in good shape:

- cloud lite/pro/agent paths
- SSE streaming parser correctness
- tool catalog visibility for missing web-search backend
- local agent loop policy contract
- Rust-side specialty bridge contracts

What is **not** finished:

- real local-model install/runtime proof
- full manual runtime button/surface audit
- final iMessage end-to-end success on the user’s actual active app copy
- setup polish across the remaining settings surfaces
- agent/main-chat convergence and final visual/runtime cleanup
- release closure

Claude should continue from that truth, not from the older all-green progress docs.
