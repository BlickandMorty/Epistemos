# Audit supplement: Hermes-prefix bleed — full prompt-builder surface — 2026-05-05

> Loop iteration audit (slice f). Extends
> `docs/AUDIT_HERMES_BLEED_AGENT_RUNTIME_2026_05_05.md` (commit cb39a67f)
> by widening the grep beyond `agent_core/src/agent_runtime/` to the
> Swift mirror builder, the gateway policy constants, and the agent_core
> integration test surface. The original audit identified Block C
> (system-prompt bleed) at one Rust call site; this supplement maps the
> full surface so the C-1/C-2/C-3 sign-off has the complete picture.

## Three additional findings (sharpening Block C)

### Finding F1 — Swift `HermesPromptBuilder` is a live fallback that mirrors the same lines

**File:** `Epistemos/LocalAgent/HermesPromptBuilder.swift:66-72`

Lines 66-70 are byte-identical to the Rust hot path
(`agent_core/src/agent_runtime/prompt_format.rs:73-77`):

```text
Hermes is the tool-call and external-intelligence membrane, not the graph, Rex, or the deterministic substrate authority.
Use tools only for missing context or explicit external side effects. Do not route already-available local substrate answers through tools.
Hermes is the single fast gateway for cloud models, CLI delegation, MCP/web tools, and explicit external side effects.
Keep deterministic local substrate answers on the direct path; Hermes must not add a gateway hop when no external context is needed.
Return external evidence as structured artifacts and provenance, not graph or Rex authority.
```

**Reachability:** the function tries Rust FFI first
(`#if canImport(agent_coreFFI)` + `rustSystemPrompt(...)`), falls back
to Swift if FFI is unavailable OR if the Rust call returns nil. Both
paths are live in production. The Swift fallback ships in the
LocalAgent loop at `LocalAgentLoop.swift:273` (system prompt) +
`:319` (message build) + `:1006` (repair message).

**Implication:** any C-2 / C-3 fix must change BOTH sides in lockstep,
otherwise the prompt the Hermes-3 model sees depends on whether the
Rust FFI happened to work for that specific call.

### Finding F2 — boundary-line constants ALREADY DRIFTED between Rust and Swift

The Swift boundary line at `HermesGatewayPolicy.swift:70-71` reads:

```text
Cloud/provider/CLI/MCP/browser/Docker orchestration is Pro/Research only.
```

The Rust boundary line at `prompt_format.rs:5` reads:

```text
Cloud/provider/CLI/MCP/Hermes subprocess orchestration is Pro/Research only.
```

**Swift was already partially de-Hermes'd** (browser+Docker swapped in
for "Hermes subprocess"); **Rust was not**. The two prompts the model
sees diverge on the boundary line depending on which path serves the
turn. This is pre-existing drift the original audit missed because it
only grepped `agent_core/src/agent_runtime/`.

**Implication:** the C-3 minimal-trim option is the lowest-risk path
*and* would re-converge the two sides. C-2 substrate-rename should
also reconcile both sides at once. C-1 keep-as-is leaves the drift
in place.

### Finding F3 — integration test PINS the Rust boundary line in place

**File:** `agent_core/tests/hermes_runtime.rs:64-66`

```rust
assert!(prompt
    .contains("Cloud/provider/CLI/MCP/Hermes subprocess orchestration is Pro/Research only."));
assert!(prompt.contains("Local Hermes-family prompt formatting may stay Core-safe only when it runs in-process over local context."));
```

Any C-2 or C-3 change to the Rust constants MUST update this test in
lockstep, or `cargo test --all-targets` breaks (the test currently
passes — it was part of the 1046-test green run from slice (a)).

**Implication:** this is a one-test, two-line update — small surface,
no migration concern. But it's a real linked-edit gate that the
sign-off slice owner needs to know about up front.

## Surface map for the C-1/C-2/C-3 decision

If you pick **C-3 minimal trim** (recommended path from original audit):

| File | Change |
|---|---|
| `agent_core/src/agent_runtime/prompt_format.rs` | Delete lines 4-7 (the two boundary-line constants) + line 78 + line 79 (the prompt format-string interpolations of those constants) |
| `Epistemos/LocalAgent/HermesGatewayPolicy.swift` | Delete lines 70-73 (the two static-let boundary-line constants) |
| `Epistemos/LocalAgent/HermesPromptBuilder.swift` | Delete lines 71-72 (the two interpolations into the prompt) |
| `agent_core/tests/hermes_runtime.rs` | Delete lines 64-66 (the two boundary-line assertions) |

That's 4 files, ~10 lines deleted, no behavior change beyond removing
references to the deleted subprocess. Lines 73-77 of the Rust prompt
(the model's self-identity references to "Hermes" — the model name)
stay, because Hermes-3 self-identifies that way per its training.

If you pick **C-2 substrate-rename**:

Same 4 files, but instead of deleting, swap "Hermes" → "the
agent_runtime" or "this runtime" on lines 73-77 of the Rust prompt
(and the matching Swift fallback). Higher behavioral risk because
the model may have learned to attend differently to the "Hermes"
self-reference; needs a smoke pass against the LocalAgent integration
test corpus.

If you pick **C-1 keep-as-is**:

Three files only. Drift the boundary-line constant in
`agent_core/src/agent_runtime/prompt_format.rs:5` to match the
already-de-Hermes'd Swift wording (browser+Docker, no "Hermes
subprocess"), and update the test in lockstep. That at least closes
the drift between the two paths without touching the model-facing
"Hermes is X" lines.

## Provenance

Audit run during the audit-with-preservation loop, slice (f). Read
against `docs/AUDIT_HERMES_BLEED_AGENT_RUNTIME_2026_05_05.md` (commit
cb39a67f), `docs/PRESERVATION_FIRST_AUDIT_POLICY_2026_05_05.md`,
`feedback_no_hermes_anywhere.md`, `project_hermes_removal_2026_05_05.md`.

Reproduction:

```sh
grep -rnE "Hermes is the|hermes subprocess|Hermes subprocess|gateway for cloud|tool-call and external-intelligence membrane" Epistemos/ agent_core/
```

No code change applied — surface map for sign-off only.
