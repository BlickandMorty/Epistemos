# Audit: Hermes-prefix bleed in agent_core/src/agent_runtime/ — 2026-05-05

> Loop iteration audit (slice b). Per `feedback_no_hermes_anywhere.md`
> (2026-05-05): "User extends 2026-05-05 subprocess removal to ALL Hermes
> namespace. No new code with Hermes prefix."
> Per `project_hermes_removal_2026_05_05.md`: backend now
> `agent_core::agent_runtime` (in-process Rust); LocalAgent Hermes*.swift
> files INTENTIONALLY KEPT (canonical local agent, Hermes-3 model format).
>
> This audit triages the bleed found in agent_runtime against those rules.

## Inventory

### A. Identifier-level Hermes prefix (Hermes-3 prompt-format types)

| File | Symbols |
|---|---|
| `prompt_format.rs` | `HermesToolDefinition`, `HermesPromptInput`, `HermesMessageRole`, `HermesMessage`, `HermesToolResult`, `formatted_tools_json` (callee) |
| `function_call.rs` | `HermesToolCall`, `parse_tool_calls`, `calls_from_value` |
| `bridge.rs:2242` | `hermes_build_system_prompt` FFI export |
| `Epistemos/Bridge/StreamingDelegate.swift:150` | `hermesBuildSystemPrompt(inputJson:)` Swift shim |
| `Epistemos/LocalAgent/HermesPromptBuilder.swift:183` | `HermesPromptBuilder.systemPrompt()` calls into the Swift shim |
| `Epistemos/LocalAgent/LocalAgentLoop.swift:273,319,1006` | `LocalAgentLoop` calls `HermesPromptBuilder` |

**Classification: INTENTIONAL — sign-off-gated rename.** These are the
Hermes-3 model's native tool-call XML format identifiers (Nous Research
trained the model on `<tool_call>...</tool_call>` + the
function-calling JSON convention). The LocalAgent path runs Hermes-3
in-process via MLX. Per `feedback_no_hermes_anywhere.md`, these are the
"18 existing LocalAgent/Hermes*.swift files flagged for sign-off-gated
rename to LocalAgent*". Same flag applies to the matching Rust types.

**Recommendation:** preserve as-is. If/when sign-off lands for the rename,
the Rust types rename in lockstep with the Swift bridge shims.

### B. Documentation/comment references (intentional historical context)

| File | Notes |
|---|---|
| `mod.rs:4-13` | Explicitly documents the rename (`hermes` → `agent_runtime`, 2026-05-05). Cross-refs `docs/_archive/hermes-removal-2026-05-05/README.md`. |
| `skills.rs:5` | One comment mentions historical `agent_core::hermes::skills` name. |
| `procedural_memory.rs:3` | "Durable skill-outcome memory for Hermes" — refers to the runtime context. |

**Classification: INTENTIONAL — preserve.** Historical context
documenting the rename is exactly the trace future readers will need.

### C. SYSTEM PROMPT TEXT — load-bearing, stale architecture (FINDING)

`prompt_format.rs:73-79` injects the following lines into the **system
prompt sent to the Hermes-3 model on every turn**:

```text
Hermes is the tool-call and external-intelligence membrane, not the graph, Rex, or the deterministic substrate authority.
Use tools only for missing context or explicit external side effects. Do not route already-available local substrate answers through tools.
Hermes is the single fast gateway for cloud models, CLI delegation, MCP/web tools, and explicit external side effects.
Keep deterministic local substrate answers on the direct path; Hermes must not add a gateway hop when no external context is needed.
Return external evidence as structured artifacts and provenance, not graph or Rex authority.
Cloud/provider/CLI/MCP/Hermes subprocess orchestration is Pro/Research only.
Local Hermes-family prompt formatting may stay Core-safe only when it runs in-process over local context.
```

**Classification: STALE DOCTRINE in load-bearing prompt.** These lines
describe an architectural role for "Hermes" — gateway for cloud models,
CLI delegation, MCP/web tools — that no longer exists. The Hermes
subprocess was removed 2026-05-05 (commits dropping `hermes-agent`).
The LLM is being told it is talking to / through an architectural
element that has been deleted.

Two of those lines explicitly name "Hermes subprocess":
- `EXTERNAL_TIER_BOUNDARY_LINE` (line 5)
- `LOCAL_CORE_BOUNDARY_LINE` (line 7)

**Why this is a finding (not a fix):** the prompt is behaviorally
load-bearing — changing what the model "believes about its environment"
is a prompt-engineering judgment call. Specifically:

1. The model may have learned to route differently based on these lines.
   Removing them might shift tool-call frequency, latency, or correctness.
2. The actual current architecture has the in-process `agent_runtime`
   playing the role these lines previously assigned to a subprocess.
   Some replacement language is plausibly correct, but the choice is
   user-facing.
3. Live changes to system prompts are NOT preservation-first deletions;
   they're behavioral redesigns that warrant explicit sign-off.

## Recommendation

**Block A (identifier rename):** held-for-sign-off — same gate as the
18 LocalAgent Hermes\*.swift files.

**Block B (comments/docs):** keep as-is. Historical context is good.

**Block C (system prompt text):** surface to user. Three options:

- **C-1 keep-as-is:** the model's training expects the "Hermes" name as
  its own self-reference (Nous Research's Hermes-3 model card refers to
  itself this way). Lines 73-79 may be re-anchoring the model on its
  own identity, in which case removing them costs more than it gains.
- **C-2 substrate-rename:** swap "Hermes" → "the agent_runtime" or
  "this runtime" in lines 73-77, drop subprocess-tier-boundary lines
  (5, 7, 78). Aligns prompt with current architecture. Behavioral risk:
  unknown until smoke-tested against the existing LocalAgent integration
  test corpus.
- **C-3 minimal trim:** delete only lines 5, 7, 78 (the two
  `EXTERNAL_TIER_BOUNDARY_LINE` / `LOCAL_CORE_BOUNDARY_LINE` constants
  and the line that references them). Keep lines 73-77 because
  Hermes-3 self-identifies as "Hermes" in its training data. Lowest
  behavioral risk that still removes the most stale references.

**No change applied.** Awaiting user decision on C-1 / C-2 / C-3.

## Reproduction

```sh
grep -rn -iE "hermes" agent_core/src/agent_runtime/
```

## Provenance

Audit run during the audit-with-preservation loop, slice (b). Build
verified clean before audit (`cargo test --all-targets`: 26 binaries,
1046 tests, 0 failures; `xcodebuild`: BUILD SUCCEEDED).
