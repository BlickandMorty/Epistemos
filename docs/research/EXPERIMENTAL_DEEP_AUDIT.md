# Experimental Surface — Deep Self-Audit (Cycle 1, Phase A2)

**Date:** 2026-07-05 · **Scope:** the whole Experimental stack — the thin Swift host
(`Epistemos/ExperimentalAgent/**`), the `onecode-shim.js` bridge, the headless backend fork
(`.research-clones/1code/src/main`, `headless/`), the renderer overlays (`.research-clones/1code/src/renderer`),
the provider lane, the MCP path, the theme, and the boot flow.
**Method:** a 4-agent parallel audit (key-paste wiring · feature-fusion gaps · free-Zen/catalog ·
orphaned-code) reading real source with `file:line`, cross-checked against the runtime.

**Verdict key:** CONNECTED (reachable end-to-end) · HALF-WIRED (built, partial reach) ·
DISCONNECTED (one side built, consumer missing) · DEAD (no importer).

---

## Layer-by-layer

### L1 — Swift host (`ExperimentalSurfaceView.swift`, supervisor, `ExperimentalStateBridge`)
**CONNECTED.** Registered script-message channels: `epistemos` (reply-capable desktopApi bucket —
window/clipboard/badge/keychain/save-file/open-external/notification + the new `vault:create-note`);
`epistemosSpeak` (Kokoro read-aloud); the theme user-script + live re-apply; `onecode-shim.js`
@documentStart; `window.__epistemosState` native→SPA Jotai bridge. `/host` ws bridge
(`ExperimentalHostBridge`) for NSOpen/SavePanel. All reached; the state bridge has a 15-assertion
witness. No orphans.

### L2 — Provider lane (six engines)
**CONNECTED**, with one honest gate. Claude ✓ (vault-MCP transcript proven). Codex ✓ — migrated off
the deprecated zed bridge (stale model list, dead on ChatGPT accounts) to `@agentclientprotocol/codex-acp`
driving the user's own CLI; **live round-trip proven** ("CODEX ROUND-TRIP OK"). Kimi/GLM ✓ selectable
via the `ANTHROPIC_BASE_URL` harness (Keychain→env→`harnessTokenFromEnv`, chain fully live). OpenCode ✓
selectable via the shared ACP lane (`acpAgent=opencode`, hard free-Zen gate) — **live round-trip proven**.
Gemini — HALF-WIRED by design: env-injection live, but `selectable:false` "— soon" (no adapter yet,
and the Keychain slot is empty), listed honestly, not faked.

### L3 — MCP path (`epistemos-vault`)
**CONNECTED.** Router-level injection at both in-process points (`claude.ts` `options.mcpServers`,
`codex.ts` `session.mcpServers`) + the `~/.claude.json` file-fallback. Verified live on BOTH engines
(`/mcp` lists `epistemos-vault`; a `list_files` vault-tool call returned real notes). Root-caused +
fixed an arch mismatch (x86_64 `omega_mcp_stdio` staged on an arm64 host → silent MCP death) with a
host-triple selection + arch-refusal gate in the packaging.

### L4 — Renderer overlays + model picker
**CONNECTED.** The six providers live in the donor's OWN picker (owner pivot: extend, don't replace);
an `opencode/…` id in the codex model atom is the single-source engine signal. Model catalog: the
composer picker uses a **curated** list (owner's deliberate choice), while the live `models.dev`-backed
catalog (`epistemosCatalog.list`) feeds the Settings→Providers expander — **this is by design, not a
disconnection** (the audit initially flagged it before learning the owner chose curated).

### L5 — De-brand / boot / theme (foundation)
**CONNECTED.** De-brand grep over `headless/dist` + `out/renderer` = **0** user-facing donor hits,
enforced by a fail-the-build gate; legacy-read compat for renamed roots/theme-ids. Boots straight into
the vault chat (once-per-boot auto-advance past the picker). Epistemos theme worn in light + dark
(HSL-triplet bridge + injected `:root{!important}` style element surviving next-themes' hydration wipe).

### L6 — Overlay module reachability (orphan hunt)
**ZERO dead modules.** Every `epistemos-*` overlay is reached: `harness-env` (claude.ts:1197),
Keychain chain (renderer→shim→Coordinator→supervisor→env), `session-budget` (opt-in, live),
`tool-policy` (Claude enforces; Codex audit-only — see below), `model-catalog` + router (registered +
consumed), `epistemos-mcp`, `session-resume`, `cli-detect`, `zen-notice`, `epistemos-links`,
`state-bridge`, `worktree-roots`, `extra-providers`, `providers-section`. The prior ledger note calling
the Keychain/harness seam "inert" is **STALE** — the chain is fully live.

### L7 — Read-aloud + vault write-back fusion (this cycle)
**CONNECTED.** Transcript speaker button + a new selection-popover "Read aloud" both route to Kokoro
via `epistemosSpeak` (honest-gated, live-refreshed on `.onAppear`). "Save to vault" writes an assistant
reply into `<vault>/notes/*.md` via `vault:create-note` — the first provenance-write-back primitive.

---

## Open items (the Phase-D / hardening backlog)

| Item | Verdict | Risk | Action |
|---|---|---|---|
| Codex tool-policy `deny` is audit-only (logs, cannot block; `codex.ts` onStepFinish) | HALF-WIRED | security (narrow — ACP self-sandboxes) | Phase E: interpose a real pre-tool deny for codex, or document the ACP boundary as the enforcement |
| Gemini engine adapter | DISCONNECTED (by honest gate) | none (listed "soon") | build the §5 direct API-key adapter when a key exists |
| Vault search = substring grep (`omega_mcp_stdio` `vault.rs:854`), NOT the Halo BM25+HNSW RRF index | HALF-WIRED | feature (agent gets the weakest search the app owns) | **Phase C/D crux**: expose RRF-ranked search to the agent — the single highest-leverage embedding upgrade |
| "Open cited note in Epistemos" from the transcript | DISCONNECTED (not built) | none | Phase C: `vault:open-note` deep-link |
| Live catalog → composer picker | intentionally curated | none | owner's choice; leave |

**The crux for the next cycle (from L6/L7 + the field study):** the agent's vault search is naive
substring grep while Epistemos owns a BM25+HNSW RRF index (`epistemos-shadow` / `RRFFusionQuery`) it
can't reach. Closing that — graph/RRF-aware retrieval into the agent's context — is the feature the
entire field study says no standalone app can build. That is the Cycle-2 frontier.

_Cycle-1 Phase-A2 deliverable. Appended to the `EXPERIMENTAL_R.md` cycle log._
