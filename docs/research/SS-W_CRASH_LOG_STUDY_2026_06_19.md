# SS-W — Recent crash + log study (2026-06-19)

Read-only study of `~/Library/Logs/DiagnosticReports` + repo grounding. Feeds the CRASH/LOG-STUDY ledger item.
Owner: *"the app crashed recently — research that, study recent logs, root-cause + add fixes to the plan."*
Pairs with SS-U (dark/light crash, a separate vector).

## What crashed (the concrete finding)
**`llama-completion` aborted twice on 2026-06-16 (10:30:15 + 10:31:01), macOS 26.3.1, SIGABRT / "Abort trap:
6".** This is the **local GGUF llama-cli inference subprocess** (binary `/opt/homebrew/*/llama-completion`, a
homebrew llama.cpp build — the Pro GGUF CLI runtime lane, flag-gated `EPISTEMOS_LOCAL_GGUF_CLI_RUNTIME_V0`).
Faulting thread = main; exception type EXC_CRASH / SIGABRT. **Frame chain (root → abort):**
```
llama_completion(int, char**)
  → common_chat_format_example(common_chat_templates const*, bool, map<...> const&)
    → common_chat_templates_apply(common_chat_templates const*, common_chat_templates_inputs const&)  ← throws
      → __cxa_throw → std::__terminate → ggml_uncaught_exception() → abort()
```
**Root cause:** llama.cpp's `common_chat_templates_apply` threw a C++ exception that was **uncaught** →
`ggml_uncaught_exception` → `abort`. This happens during `common_chat_format_example` (llama.cpp formats a
sample conversation to validate/apply the model's **chat template** at startup). So: **the GGUF model's chat
template (Jinja/built-in) could not be applied by this llama.cpp build → uncaught throw → process abort.** A
known llama.cpp failure mode when a model ships a chat template the build's minja/chat-template engine can't
parse, or when `--chat-template`/`--jinja` flags are mismatched for the model.

## Why it matters / connections
- This is the **local GGUF inference lane crashing on model load** — directly relevant to the owner's
  model-install + "can't install/run models" blockers + the per-model engineering framework (SS-Z): each model
  needs a chat template the runtime can actually apply, and the invocation must NOT abort the whole process on
  template failure.
- It's a **subprocess** (`llama-completion`) — per no-hidden-sidecar doctrine the GGUF CLI lane is Pro-only +
  flag-gated; on the MAS path inference is in-process (`LocalGGUFClient`). So this crash is in the Pro CLI lane
  the owner had armed. Even Pro, a foreign subprocess that aborts must be **caught at the Epistemos boundary**,
  never allowed to take down / wedge the app.
- Ties to the Qwen/Gemma routing work: a template that `common_chat_templates_apply` rejects = silent inability
  to run that model (or a crash), which presents to the owner as "the model doesn't work."

## Fixes to add to the plan
1. **[S] Never let the llama-cli subprocess crash propagate.** The Epistemos invoker of `llama-completion`
   (`Engine/LocalGgufCliRuntime` / `PipelineService` / `agent_core/src/bridge.rs run_local_gguf_generation`)
   must treat a non-zero / SIGABRT exit as a typed, surfaced error (honest "this GGUF model's chat template
   couldn't be applied — pick another model / tier") — NOT a hang or a silent fail. Subprocess is already
   hardened (`security.rs`) + `kill_on_drop`; add exit-code/template-error classification.
2. **[S] Pass an explicit chat template / `--jinja` per model** when invoking llama-cli, derived from the
   model's known template (per-model framework, SS-Z), instead of relying on the embedded template that aborts.
   For models whose template is unsupported, fall back to a safe built-in (chatml) + log the substitution
   honestly.
3. **[M] Pre-flight template validation** before a full run: a cheap `common_chat_format_example`-equivalent
   check (or a dry `--n-predict 0`) gated so a template failure is detected + surfaced at install/selection
   time, not at first inference. Feeds the MODEL-INSTALL acceptance (a model that can't apply its template is
   shown as "needs attention," never silently broken).
4. **[M] Upgrade the homebrew llama.cpp build or pin a version** whose chat-template engine handles the owner's
   models (Gemma 4 QAT, etc.); verify against the TurboVec/QAT GGUF canon.
5. **[S] Capture app-side crashes too** — no `Epistemos*.ips` was found (only `llama-completion`), so either the
   app itself isn't crashing (only the subprocess) OR app crashes aren't landing in user DiagnosticReports. Add
   a lightweight crash/health breadcrumb (the diagnostics panel) so the owner's reported app-level crashes
   (dark/light SS-U, transitions) are actually recorded for study.

## Methodology note (study ALL logs going forward)
Only two `.ips` reports exist in user DiagnosticReports, both `llama-completion`. No `Epistemos`/`WebContent`
crash reports were present this pass — so the owner's *app-level* crashes (dark/light toggle SS-U; "transitions"
in this session) are NOT being captured as crash reports (likely caught-then-wedged, or a SwiftUI fault that
doesn't generate an `.ips`). Recommend: (a) wire an in-app crash recorder / signal handler that writes a
breadcrumb on fault, (b) periodically study `/tmp/*build*.log`, the app's own logs, and DiagnosticReports each
hardening cycle. SS-U (HTMLWorkspace `.id` WKWebView teardown) remains the most likely app-level crash root
even without an `.ips`.

Key files: `Engine/LocalGgufCliRuntime` + `Engine/PipelineService.swift` (llama-cli invoker) · `agent_core/src/
bridge.rs run_local_gguf_generation` (FFI seam) · `agent_core/src/security.rs harden_cli_subprocess` (already
hardens the spawn) · `Engine/LocalModelInfrastructure.swift GemmaQATRuntimeLadder` (per-model GGUF descriptors —
where chat-template-per-model belongs, SS-Z). Crash artifacts: `~/Library/Logs/DiagnosticReports/llama-
completion-2026-06-16-1030*.ips`. Cross-ref: SS-U (dark/light app crash), SS-Z (per-model framework), the
MODEL-INSTALL + Qwen-routing ledger items.
