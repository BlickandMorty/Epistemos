# Sprint Agent-2: Local Agent System
## Duration: 1-2 sessions | Priority: HIGH — local agents must be honest, constrained, and reliable

---

## Pre-Read (do this FIRST)

```bash
cat CLAUDE.md
cat docs/agent-system/AGENT_ARCHITECTURE.md
cat docs/agent-system/GAP_ANALYSIS.md
cat docs/PROGRESS.md
sed -n '1310,1695p' /Users/jojo/Downloads/release/new\ agents/EPISTEMOS_REAL_AGENTS.md
sed -n '3728,3798p' /Users/jojo/Downloads/release/new\ agents/EPISTEMOS_REAL_AGENTS.md
sed -n '1,220p' Epistemos/Omega/Inference/ConstrainedDecodingService.swift
sed -n '1,260p' Epistemos/Omega/Inference/ToolSchemaGrammar.swift
sed -n '1,220p' Epistemos/Omega/Inference/ToolCallParser.swift
sed -n '1,260p' Epistemos/Engine/LocalModelInfrastructure.swift
```

After reading, confirm:
"Architecture read. Building the local agent system. First file: `Epistemos/LocalAgent/HermesPromptBuilder.swift`."

---

## Tasks (execute in order)

### Task 1: Create `Epistemos/LocalAgent/HermesPromptBuilder.swift`
From `EPISTEMOS_REAL_AGENTS.md` Section 3.1.

Requirements:
- Build the Hermes-3 `<tools>`, `<tool_call>`, and `<tool_response>` prompt format.
- No `try!`; use `do/catch` or safe fallback strings.
- Define local message/result value types only if existing app types cannot be reused.
- Preserve explicit XML tag formatting exactly enough for Hermes/Qwen tool-tuned models.

### Task 2: Create `Epistemos/LocalAgent/LocalToolGrammar.swift`
From `EPISTEMOS_REAL_AGENTS.md` Section 3.2.

Requirements:
- Build the `mlx-swift-structured` grammar shape using `SequenceFormat`, `TagFormat`,
  `TriggeredTagsFormat`, `JSONSchemaFormat`, and `AlternativesFormat`.
- If the package is not integrated yet, gate the implementation honestly behind availability
  or adapter protocols rather than faking true constrained decoding.
- Reuse or bridge existing `ConstrainedDecodingService` and `ToolSchemaGrammar` where useful.

### Task 3: Create `Epistemos/LocalAgent/LocalAgentLoop.swift`
From `EPISTEMOS_REAL_AGENTS.md` Section 3.3.

Requirements:
- `actor LocalAgentLoop`
- Hermes-format prompt assembly
- grammar-constrained generation path
- regex parsing for `<tool_call>...</tool_call>`
- history trimming for small context windows
- max turn limit
- streaming token callback
- feed tool results back through `<tool_response>`
- local tools only; do not let this silently become a cloud loop

### Task 4: Create `Epistemos/LocalAgent/ConfidenceRouter.swift`
From `EPISTEMOS_REAL_AGENTS.md` Pattern 7 and the Sprint Agent-2 goals in `docs/PROGRESS.md`.

Requirements:
- SLM-default, LLM-fallback routing
- explicit confidence threshold(s)
- verifier hook for structured output validity
- privacy-sensitive requests stay local
- low-confidence or invalid structured output escalates cleanly

### Task 5: Add honest capability gating for local models
Integrate with the existing model/runtime infrastructure.

Read before editing:
- `Epistemos/Engine/LocalModelInfrastructure.swift`
- `Epistemos/State/InferenceState.swift`
- `Epistemos/Engine/TriageService.swift`

Requirements:
- add or reuse a `canActAsAgent`-style capability
- do not claim every local model can run the full tool loop
- keep weak local models limited to classification/ghost-writing/simple transforms
- make the gating visible in code, not just docs

### Task 6: Connect the local loop to existing constrained-decoding infrastructure
Read before editing:
- `Epistemos/Omega/Inference/ConstrainedDecodingService.swift`
- `Epistemos/Omega/Inference/MLXConstrainedGenerator.swift`
- `Epistemos/Omega/Inference/ToolSchemaGrammar.swift`

Requirements:
- either reuse the current constrained-decoding path or add a clearly separated local-agent path
- no architecture theater
- no duplicate grammar compilers if existing code can be adapted
- if true masking is unavailable, preserve the honest fallback boundary

### Task 7: Add tests
Create focused tests for:
- Hermes prompt contains `<tools>` and `<tool_call>` instructions
- tool-call regex parsing
- history trimming under budget pressure
- confidence routing escalation
- capability gating (`canActAsAgent == false` stays enforced)

Suggested file names:
- `EpistemosTests/HermesPromptBuilderTests.swift`
- `EpistemosTests/LocalAgentLoopTests.swift`
- `EpistemosTests/ConfidenceRouterTests.swift`

---

## Verification (run ALL after completing)

```bash
echo "=== Sprint Agent-2 Verification ==="

for f in \
  Epistemos/LocalAgent/HermesPromptBuilder.swift \
  Epistemos/LocalAgent/LocalToolGrammar.swift \
  Epistemos/LocalAgent/LocalAgentLoop.swift \
  Epistemos/LocalAgent/ConfidenceRouter.swift; do
  [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
done

echo "--- Critical Pattern Checks ---"
printf 'Hermes tools tags: '
rg -c '<tools>|<tool_call>|<tool_response>' Epistemos/LocalAgent/HermesPromptBuilder.swift
printf 'mlx structured grammar: '
rg -c 'TriggeredTagsFormat|JSONSchemaFormat|AlternativesFormat|SequenceFormat' Epistemos/LocalAgent/LocalToolGrammar.swift
printf 'Local agent actor: '
rg -c 'actor LocalAgentLoop' Epistemos/LocalAgent/LocalAgentLoop.swift
printf 'History trimming: '
rg -c 'trimHistory|maxTokenBudget' Epistemos/LocalAgent/LocalAgentLoop.swift
printf 'Confidence routing: '
rg -c 'confidence|threshold|fallback|privacy' Epistemos/LocalAgent/ConfidenceRouter.swift
printf 'Capability gate: '
rg -c 'canActAsAgent' Epistemos/LocalAgent Epistemos/Engine Epistemos/State -g '*.swift'

echo "--- Swift typecheck (local files) ---"
xcrun swiftc -typecheck \
  Epistemos/LocalAgent/HermesPromptBuilder.swift \
  Epistemos/LocalAgent/LocalToolGrammar.swift \
  Epistemos/LocalAgent/LocalAgentLoop.swift \
  Epistemos/LocalAgent/ConfidenceRouter.swift
```

## After Completing

Update `docs/PROGRESS.md` and `docs/AGENT_PROGRESS.md`.
Then proceed to Sprint Agent-3 in a fresh session.
