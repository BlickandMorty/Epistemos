# R-KUKU — Kuku (local-first AI note-taking) verdict (2026-06-18)

`kuku.mom` / `github.com/kukume`. The closest sibling to Epistemos yet: a
**local-first PKM with AI** — bidirectional wikilinks, graph view, local Whisper
STT, an AI agent, plain `.md` files, "your files are yours." So this is a
take-the-best-IDEAS verdict, not a port.

## TL;DR — SKIP the code, ADOPT two patterns natively

| Aspect | Kuku | Epistemos (already) | Verdict |
|---|---|---|---|
| Stack | Tauri (Rust core + **WebKit/SolidJS** frontend), ProseMirror editor | native **SwiftUI** + Tiptap (WKWebView) editor | SKIP the stack — Epistemos is already the native equivalent |
| License | Client **MIT**, server **AGPL** | — | MIT client is studyable; AGPL server = do NOT touch/port |
| Files | local-first `.md` | local-first `.md` vault | parity |
| Graph / wikilinks | yes | yes (graph + wikilinks) | parity |
| Local STT | local **Whisper** | ties to R-VOICE (Kokoro/MOSS + STT) | adopt pattern |
| AI agent | Gemini (cloud) | local MLX/GGUF + cloud | Epistemos is more local |

**Don't port** (Tauri/SolidJS/TS, AGPL server — NO-SIDECAR + not Swift/Rust-native).
**Adopt two patterns** that are genuinely additive and fit the native stack:

### 1. AI MEMORY SHARING — "your notes as long-term memory for ANY AI tool" (TAKE)
Kuku's headline idea: a **secure LOCAL API** that lets other AI assistants read
your knowledge base. This is exactly Epistemos's edge made outward-facing. We
already have the pieces — the vault, **Knowledge Core**, **Eidos** retrieval,
memory — and the **local OpenAI/Ollama-compatible server** (the osaurus-adopted
`ResponseWriters`/server, MAS-safe) + **MCP**. The pattern: expose the vault/KC as
a **read-only memory endpoint** (local HTTP /  an MCP "epistemos-memory" server)
so Claude Desktop / Cursor / any MCP client can query the user's notes as
long-term memory. Honest gating: read-only by default, Keychain-token auth,
user-toggled, localhost-only. Pairs with P-BESTOF (connectors) + P2.7 (MCP
management). High-value, low-risk, native.

### 2. MEETING / LECTURE NOTE with local transcription (TAKE pattern)
Kuku's MeetingNote = record a lecture/meeting → local Whisper transcript → a note.
Maps directly onto R-VOICE (the STT half) + the vault. Native path: AVFoundation
capture → on-device STT (Apple Speech / a local Whisper GGUF via the audio lane) →
an Epdoc note with the transcript + AI summary (TriageService already summarizes).
Honest: on-device only, no cloud upload by default. Slots into the voice workstream.

## What NOT to take
- The Tauri/SolidJS/ProseMirror frontend (Epistemos has SwiftUI + Tiptap).
- The AGPL server infra / sync backend (license-incompatible with a shipped app;
  Epistemos uses its own vault + optional git sync).
- Gemini-as-the-agent (Epistemos is local-first MLX/GGUF + honest cloud).

## Founding-thesis fit
Kuku validates the local-first PKM-AI thesis from a TS/Tauri angle; Epistemos does
it native + with determinism/verifiability. The one idea worth stealing — **expose
your vault as memory to other AI tools** — turns Epistemos's knowledge substrate
into a product moat, and it's a small native slice on infra we already shipped.

## Sources
- [kuku roadmap (open-sourcing client MIT / server AGPL)](https://www.kuku.mom/blog/kuku-roadmap-2026/)
- [github.com/kukume](https://github.com/kukume)
