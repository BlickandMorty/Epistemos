# COMPETITOR SUPERSESSION — gaps to beat Obsidian/Claude-desktop/Codex/Tolaria/Notion (S5, 2026-06-19)

Read-only research (subagent), current to mid-2026. Feeds DEEP_PLAN_AUDIT_HUB. "PLANNED/
IN-FLIGHT" = a tracked ledger item, not necessarily shipped+verified.

## Capability matrix — where Epistemos leads / lags
| Capability | Leader 2026 | Epistemos | Verdict |
|---|---|---|---|
| Bidirectional links/graph | Obsidian, Logseq | DAG + Eidos + graph; no outliner/block-ref | parity on graph; behind on outliner/transclusion |
| **Local LLM inference** | LM Studio (MLX), Jan | **in-process MLX-Swift + GGUF, zero-copy, no sidecar** | **LEADS architecture**; behind LM Studio on model-browser polish |
| Agentic tool-use over your notes | Tolaria, Claude Cowork | LocalAgent loop over vault — **REOPENED BROKEN** | architecture leads; **execution failing = top gap** |
| Computer-use/automation | Claude Cowork, Cursor cloud, Codex | AXorcist+ScreenCaptureKit+DeviceAgent+Holo(planned)+R-CUA | strong substrate; Holo/Lume not wired |
| Terminal integration | Claude Code, Codex CLI, Tolaria | terminal.rs exists; Goose=Work planned | behind — no first-class terminal shipped |
| Canvas/whiteboard | Obsidian Canvas, Logseq | P7.2 canvas (**broken**) | behind |
| Web clipping | Obsidian Web Clipper, Reflect | **none** | **GAP** |
| **PDF→Markdown** | (weak spot generally) | **R-LITEPARSE DONE** (in-process PDFium+OCR) | **LEADS** |
| MCP | Claude Desktop (200+), Cherry | bridge+sdk; install UI (P2.7) planned | protocol parity; behind on install UX |
| Multi-agent | Claude Cowork, Cursor, DeerFlow | DeerFlow build started; Hermes fusion planned | substrate strong; UX not shipped |
| Voice | Reflect, Mem | R-VOICE planned | **GAP** |
| Sync | Obsidian Sync, Logseq RTC, Notion | local files; no multi-device sync | **GAP** |
| Extensibility | Obsidian plugins, Cherry (300+) | skills/tools + marketplace planned | different model; marketplace not shipped E2E |
| **Local agent over YOUR vault, honest+provenance** | *nobody fully* (Tolaria closest) | **the whole thesis** | **UNIQUE — the moat** |

## Gaps to supersede each named rival
- **Obsidian:** web clipper (their default), working canvas, Bases-style DB/table views; counter plugin breadth with a skills+pack marketplace that actually ships browse→install→run.
- **Claude Desktop/Cowork:** their cloud-brain-over-folder → counter with **local-brain-over-vault** (but fix the broken agent loop first); add live Artifacts (json-render/htmlstream seed); MCP connectors UI (P2.7); adopt the **SKILL.md open standard**.
- **Codex/Claude Code/terminal agents:** first-class terminal + PR-lifecycle agent (Goose=Work); honest local analog to async cloud agents = Lume VM sandbox.
- **Cursor:** multi-file diff staging w/ per-file accept/reject (needed for Work/Goose); `.cursor/rules`-style version-controlled, file-scoped agent config.
- **Tolaria (closest rival):** its killer move = auto-generates AGENTS.md so Claude Code/Codex/Gemini CLI all drive the same open vault + a native MCP "create note" tool. Epistemos must (a) **expose its vault over MCP** so external agents can drive it, AND (b) keep its in-process agent as the better default — match openness, beat on real local brain + provenance.
- **Notion:** Workers (hosted sandbox) + CLI + External Agents API. Counter = local in-process skills/tools + marketplace; dev-platform/automation story is thin.
- **Reflect/Mem:** voice transcription + clipping + E2E sync. **Logseq:** outliner + block-transclusion + RTC. **Cherry/Jan/LM Studio:** unified multi-provider chat + pre-wired MCP + best-in-class MLX model browser (our picker is reported broken/reductive → must reach LM-Studio clarity).

## The killer differentiators to lean into
1. **A real LOCAL agent over YOUR vault — no cloud required.** Everyone else bolts a cloud brain onto local files, or offers local chat without a true agentic tool-loop over the vault. Unique — **if the tool-loop is fixed (precondition #1).**
2. **Honest capability gating + provenance** (Eidos / Cognitive DAG / ReplayBundle) — no competitor ships verifiable claim-provenance/closed-citation/replay. Non-copyable moat.
3. **Zero-copy in-process inference (no sidecar)** + in-process PDF→md + native computer-use — "fast as a jet, simple as an app."
4. **Three-engine fusion under one vault** (Chat / Act=Osaurus / Work=Goose, shared memory) — Obsidian-fused-with-Codex-and-Claude-and-a-terminal over one local substrate; no single rival spans PKM + computer-use + terminal-coding + deep-research natively.

## Recommendations → ledger mapping
**Fix-first (block the thesis):** (1) repair the agent tool/skill loop (ledger TOOLS/SKILLS, REOPENED) — precondition for differentiator #1; (2) model picker → LM-Studio clarity (picker cluster).
**Close gaps (mostly NEW):** WEB CLIPPER (NEW — biggest unmapped gap; share-ext/browser-capture→vault, tie to Obscura/OpenClaw browser) · VOICE (R-VOICE) · MCP install/connectors UI (P2.7) · **expose vault over MCP + AGENTS.md convention (NEW, anti-Tolaria)** · terminal+Work engine (R-GOOSE) · repair canvas (P7.2) · Artifacts/live dashboards (NEW; json-render+htmlstream seed) · finish computer-use (Holo+Lume, R-CUA).
**Lean-into:** provenance-visible answers everywhere (Eidos/DAG/ReplayBundle) · marketplace breadth (HF/GitHub/arXiv + finetune packs) · adopt SKILL.md standard (portable skills, not a walled garden).

**Net:** Epistemos leads on the hardest architecture (in-process local inference, provenance, native computer-use substrate, in-process PDF); it's BEHIND on shipped-working execution (agent tool-loop broken) and has true GAPS in web-clipping, voice, sync, working canvas, MCP-install UX. Supersession = (a) make the local-agent-over-vault actually work E2E, (b) close clipper/voice/canvas/MCP-UX gaps, (c) loudly own local-first + honest-provenance + three-engine-fusion.

Sources: Obsidian/Copilot/Web-Clipper, Claude Cowork/Code/Skills, Codex/Cursor 2026 guides, Notion Developer Platform, Tolaria (files-first + AGENTS.md), Cherry/LM Studio/Jan, Logseq DB, Reflect/Mem (full URLs in the subagent transcript).
