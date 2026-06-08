# F-GemmaQATE2BSettingsDiagnosticsWRVGate - 2026-06-08

North-star: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

- Command: `Tools/falsifiers/f_gemma_qat_e2b_settings_diagnostics_wrv_gate.sh`
- Artifact: `artifacts/falsifiers/gemma_qat_e2b_settings_diagnostics_wrv_gate/result.json`
- Scope: metadata-only T1/L1 research-to-build witness
- Upstream: `F-GemmaQATE2BRouteAnswerPacketVisibilityGate`
- Next Gemma side-ladder cursor: `gemma_qat_e2b_release_audit_surface_gate`

## Result

`F-GemmaQATE2BSettingsDiagnosticsWRVGate` passes as the fail-closed settings
and diagnostics WRV gate between a future Gemma E2B route AnswerPacket
visibility packet and any release-audit/product-surface claim.

The witness binds the selected E2B GGUF/llama.cpp lane:

- model id: `google/gemma-4-E2B-it-qat-q4_0-gguf`
- source revision: `1894d1fc0a19d86697abd40483f5983c867df03f`
- filename: `gemma-4-E2B_q4_0-it.gguf`
- expected file bytes: `3349514112`
- command lane: `/opt/homebrew/bin/llama-cli`
- WRV fields: `34`
- rejection policies: `69`
- rejected red fixtures: `87`

The contract requires the upstream route AnswerPacket visibility digest,
settings source marker, diagnostics source marker, WRV test marker, manual
check plan, release-audit link, AnswerPacket template, settings and diagnostics
surface copy, visible model identity, runtime lane, route status, route caveat,
budget summary, memory headroom, KV budget, latency budget, privacy class,
MAS/Pro boundary, SCOPE-Rex and SovereignGate verdicts, fallback, abstention,
cancellation, rollback, RunEventLog, route explanation, rejected-candidate
summary, user-action requirement, no-toggle-unlock proof, and explicit
no-quality, no-live-default, no-large-model-bypass, and no-L2-L3-T4 claims.

## Non-Claims

This witness does not wire Swift settings, change diagnostics UI, emit an
AnswerPacket to a user, perform route visibility, admit a route, mutate
RuntimeRouter/System G/default-model state, arm or execute commands, run
llama.cpp, inspect a local path, load model/runtime/provider bytes, capture raw
prompt/output bytes, prove quality, prove memory fit, make Gemma default, or
advance MAS/L2/L3/T4.

Correct phrasing: Gemma E2B settings/diagnostics WRV requirements are L1
metadata-proofed; no user-facing Gemma capability was activated.
