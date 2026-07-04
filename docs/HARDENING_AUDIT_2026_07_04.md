# Pro Agent Surface — Hardening Audit (2026-07-04)

**Scope:** the vendored OpenChamber fork (`~/dev/openchamber-epistemos`) + the native
ProAgent host (`Epistemos/ProAgent/*`). Verified against the four lenses (security /
memory-leak / data-leak / robustness) plus the surface-specific doctrine patterns.

**Disposition:** **0 HIGH / 0 MED / 1 LOW (cosmetic).** Multiple consecutive fully-clean
verify + harden passes. Every §8 row carries a `[VERIFIED-CODE] file:line` or a re-runnable
transport witness. The one item outside this bar — a live UI turn — is environment-blocked
(contended multi-agent desktop; servers down), not a code gap.

## Doctrine patterns — all CLEAN

| Pattern | Evidence (file:line) | Status |
|---|---|---|
| Loopback-origin pinning never weakened | `ProAgentSurfaceView.swift` `ProAgentTrustedLoopbackOrigins.isLoopback` (only 127.0.0.1 / localhost / ::1); decider allows trusted loopback else opens external in browser + `.cancel` | ✓ |
| No secret in webview JS | goosed `X-Secret-Key` read from `process.env.EPISTEMOS_GOOSE_SECRET` and attached server-side in `web/server/lib/goose/proxy.js:205`; SPA-JS scan of `packages/ui/src` empty; client-supplied secret overridden (`proxy.js:57`) | ✓ |
| Validate WKScriptMessageHandler payloads | `EpistemosDesktopBridge` guards body as `[String:Any]`, whitelists command (`desktop_notify`/`speak`/`speak_stop`, else `default: break`), caps text to `maxTextToSpeechInputCharacters`; `@MainActor` (no race) | ✓ |
| CSP no-external-hosts | `security-headers.js`: `default-src 'self'`, `connect-src 'self' data:`, `img-src 'self' data: blob:`; wildcard/external-host scan empty (`unsafe-inline/eval` are same-origin SPA/WASM needs, no external path) | ✓ |
| Service worker off | `web/vite.config.ts:46` excludes `VitePWA` under `epistemosEmbed`; registration stubbed; stale SWs unregistered (`main.tsx:99`) | ✓ |
| Zombie / process-group cleanup on the 3 children | `ProAgentRuntimeSupervisor.swift` `stop()` :153 / `stopChildrenAfterFailedStart` :479 / `stopSurvivingChildrenAfterRequiredExit` :560 → `terminateTrackedProcess` :573 (nils handler, `cleanupProcessTree` kills grandchildren, SIGTERM, untrack); all async tasks cancelled | ✓ |
| Instruction-source boundary | vault content reaches opencode via `omega_mcp_stdio` (downstream of the ProAgent fusion wiring); the fusion adds/removes no boundary — treated by opencode/omega_mcp_stdio (out of the ProAgent lane) | ✓ (neutral) |

## Additional hardening verified

- **MCP fusion shared-config write is atomic** — `WorkOpenCodeRuntime.writeOwnerOnlyConfigData:323-331` uses a unique-UUID temp file + `moveItem`/rename; two concurrent writers (ProAgent + Work) each produce a complete file, last-wins on identical merges. No corruption.
- **Goose adapter robustness** — `gooseClient.ts`: 8 MB SSE reassembly-buffer cap (`:30-32`, anti-OOM) + reader-abort on stream cancel (`:252-254`, anti-leak).
- **Runtime circuit breaker** — `ProAgentSurfaceView.swift:559` `guard retryAttempt < maxRuntimeRetryAttempts` (=8) stops respawning the 3-child runtime; single `retryTask` guard (`:552`) prevents retry storms; resets only on manual restart (`:400`).

## §8 feature-ledger rows — evidenced

- **P1 opencode engine** — OpenChamber's own (donor) opencode SDK seam (`lib/opencode/client.ts`, `sync/event-pipeline.ts`), unmodified + working.
- **P3 goose adapter** — `gooseClient.ts` translates goosed's SSE `/reply` stream → SDK event shape (`:8/:17`), owns its own session index (`:14`), stable id for `id:null` (`:179-195`); transport-witnessed (goose PONG via `/goose/reply`).
- **Native chrome** — pill / all-chats sheet / mascot overlay hook / typewriter headline present in `ProAgentSurfaceView.swift`.
- **Reconnected disconnected parts** — notification bridge (`ff1b286af`), MCP vault fusion (`b9f6bc113`), external-links/OAuth reroute (`8c2226cc`), terminal (CSP `data:`), read-aloud on-device voice provider (`c7853350` + `f8bb263e2`).

## The 1 LOW (cosmetic, logged — not restart-worthy)

Read-aloud: the message TTS button does not auto-reset from "stop" to "read" when native
speech ends (the on-device engine exposes no completion callback). It resets on the next
play or on an explicit stop. No functional or security impact.

## Runtime witness — owner-side

The live end-to-end UI witness (a real turn on both engines with pill + all-chats + mascot,
notification firing, agent citing a vault note, hearing Kokoro/MOSS) requires the app running
on a quiet desktop. It has not been reproduced here because the supervised servers are down
and the multi-agent desktop is contended; adding another instance was deliberately avoided.
See the witness checklist in the session handoff / `plan1-pro-openchamber-loop-state.md`.
