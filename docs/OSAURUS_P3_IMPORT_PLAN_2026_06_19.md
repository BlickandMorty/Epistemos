# Osaurus P3.0 — Act = full Osaurus import PLAN (2026-06-19)

**Owner DECISION (ledger P3.0): Act = FULL Osaurus import, ZERO cherry-pick — bring
in ALL of Osaurus, embed the COMPLETE repo as the Act substrate (Epistemos stays
root; tests/IP stay home), preserve its entitlements/Info.plist/build, then reskin
Act's UI to the app. Fold the Lume/Containerization VM sandbox (R-CUA).**

This is the research-first PLAN + the smallest landable first seam. It is a BIG
multi-slice import (Osaurus is 2,837 commits) — this doc scopes it; the first code
seam lands as its own verified slice NEXT.

## What Osaurus is (primary source: github.com/osaurus-ai/osaurus README)
> NOTE: the old `dinoki-ai/osaurus` repo is ARCHIVED → active repo is
> **`osaurus-ai/osaurus`**. Use that.

- **Native macOS Swift app**, **MIT** license. Swift 63.3% + C 35.5% (MLX bindings)
  + minor Python/Shell. 5.9k stars, 2,837 commits, 410 releases (v0.20.4, Jun 2026).
  Requires **macOS 15.5+ + Apple Silicon**.
- **A full app, not a library**: SwiftUI menu-bar/windowed UI + a background **HTTP
  server (localhost:1337)** exposing **OpenAI / Anthropic / Ollama-compatible**
  endpoints (`/v1/chat/completions`, `/anthropic/v1/messages`, `/api/chat`) + an
  `osaurus` **CLI** + a **sandbox VM manager**.
- **Capabilities:** local MLX inference (`~/MLXModels`, HF lib `OsaurusAI`) · an
  **agent loop** (file/git tools, memory layers) · a **Linux sandbox via Apple
  Containerization** (Alpine VM, VirtioFS `/workspace`, vsock bridge — "shell,
  Python, Node, compilers, zero risk to your Mac") · an on-device **privacy filter**
  (scrub before cloud) · **MCP** server/client · **20+ native plugins** (Mail,
  Calendar, Vision, Browser, Git, Filesystem…) · **identity/relay** (secp256k1
  crypto addresses, secure WebSocket tunnels via `agent.osaurus.ai`).
- **Structure (the key fact for importing):**
  ```
  osaurus/
  ├── App/                       # SwiftUI entry point + assets (the UI to RESKIN)
  ├── Packages/OsaurusCore/      # the SPM core LIBRARY — the substrate to LINK
  │   ├── Models/ Services/ Managers/ Views/ Networking/
  │   ├── Storage/ (SQLite)  Identity/ (crypto)  Tools/ (MCP+plugins)  Folder/
  ├── OsaurusCLI/                # CLI binary
  └── OsaurusRepository/         # plugin registry
  ```
  Targets: `osaurus` (app), `OsaurusCLI`, **`OsaurusCore`** (SPM package library).

## ProvenanceGate verdict — `direct_import` (MIT)
MIT is permissive + App-Store/closed-source-compatible (UNLIKE R-FIELDTHEORY's AGPL
or Khoj's AGPL). The full repo may be vendored. ProvenanceGate posture =
`direct_import` (vendor the source under Epistemos root; keep the LICENSE; tests/IP
stay home). This is the green-light the AGPL repos never got.

## The MAS / Pro boundary — THE critical honesty gate (NON-NEGOTIABLE)
Osaurus's *defining* capabilities are **outside the MAS sandbox**:
- **Apple Containerization Linux VM** (arbitrary code-exec) — Pro/dev only,
  virtualization entitlement, macOS 26+.
- **Background HTTP server on :1337** — a listening socket; MAS-hostile.
- **Identity/relay WebSocket tunnels** (`agent.osaurus.ai`) — outbound P2P; Pro.
- **20+ system plugins** (Mail/Calendar/Browser/Filesystem automation) — each needs
  entitlements/automation perms the MAS sandbox forbids or heavily restricts.

⮕ **Act = Osaurus is a PRO feature.** OsaurusCore links ONLY in the Pro build
(`#if !EPISTEMOS_APP_STORE` / `pro-build`). On the **MAS build, Act stays on the
existing in-process local-agent path** (LocalAgentLoop / agent_core) — never on the
VM/server/relay. This is the deployment-profile doctrine + CLAUDE.md NON-NEGOTIABLE
("no hidden sidecar/subprocess on the MAS path; Pro runtime-plural experiments need
owner approval + MAS/Pro boundary review + no-hidden-fallback proof + RunEventLog +
AnswerPacket + rollback + harness witnesses"). Osaurus's VM/server/relay must clear
exactly that bar before they're live even in Pro.

## Import strategy (honors "zero cherry-pick" + architectural reality)
You cannot run two macOS *app targets* in one app — so:
1. **Vendor the COMPLETE repo** under `LocalPackages/osaurus/` (mirrors how
   `LocalPackages/mlx-swift-lm` is vendored). Zero cherry-pick: ALL code present,
   LICENSE kept, Osaurus's own tests stay in-tree. Epistemos remains root.
2. **Link `OsaurusCore`** (the SPM package library) into the Epistemos app target,
   **Pro-gated**. This is the Act substrate (agent loop + server + tools + sandbox).
3. **Reskin the UI:** Osaurus's `App/` SwiftUI views are the *reference*; Act renders
   Epistemos-styled views driving `OsaurusCore` managers/services (the owner said
   "reskin Act's UI to the app" — pixel-art fonts, app chrome). Don't embed Osaurus's
   `App/` verbatim.
4. **CLI** (`OsaurusCLI`) — Pro/dev tool, optional; not on the MAS path.
5. **CI:** build BOTH profiles; MAS build must NOT link OsaurusCore (a guard test
   asserts the Pro-only boundary). Vendor adds to the lock-hash / xcodegen project.

## Smallest landable FIRST seam (lands NEXT, verified)
NOT the 2,837-commit vendor at once. Two candidate first seams, smallest first:
- **Seam A (recommended, smallest): a Pro-gated `ActOsaurusBridge` protocol seam.**
  Define the protocol Act will drive (start/stop server, run an agent turn, list
  models) + a flag (`EPISTEMOS_ACT_OSAURUS_V0`, OFF) + an INERT stub conformer +
  a gate-status HealthRow (mirrors DeepResearch/NightBrain gate rows). Compile-
  verified, zero repo import yet — establishes the seam + the MAS/Pro guard test
  BEFORE the heavy vendor. This is the honest "smallest landable seam."
- **Seam B (next): align `LocalModelServer.swift`** (already an *osaurus-pattern*
  Network.framework OpenAI-compatible server, :1337) toward Osaurus's exact endpoint
  surface (`/v1/chat/completions` + `/api/chat` + `/anthropic/v1/messages`), Pro-
  gated. This is a real capability step reusing what exists.
- **Then:** vendor `LocalPackages/osaurus`, link OsaurusCore (Pro), wire one
  capability end-to-end (the agent loop → an Act turn), reskin one view, prove the
  MAS guard. Iterate capability-by-capability (server → tools → sandbox → plugins →
  relay), each its own verified, gated, logged slice.

## Sequenced slices (each verified + Pro-gated + harden)
1. **S1 (next):** `ActOsaurusBridge` protocol + flag + INERT stub + gate HealthRow +
   MAS/Pro boundary guard test. *(Seam A — no repo yet.)*
2. **S2:** vendor `LocalPackages/osaurus` (full, MIT LICENSE, zero cherry-pick);
   xcodegen/lock-hash wiring; CI builds both profiles; MAS-excludes-OsaurusCore test.
3. **S3:** link `OsaurusCore` (Pro); a thin real conformer drives one OsaurusCore
   service (e.g. list local MLX models) end-to-end; RunEventLog + AnswerPacket.
4. **S4:** Act agent-turn through OsaurusCore's agent loop (Pro); reskin the Act
   composer/transcript to app chrome.
5. **S5:** the Containerization Linux-VM sandbox (R-CUA Lume fold) — Pro/dev,
   virtualization entitlement, no-hidden-fallback proof, rollback.
6. **S6+:** server endpoints, MCP, plugins, privacy filter, identity/relay — each
   gated/logged/harden, MAS-excluded.

## Guardrails honored
- **NO-SIDECAR/MAS:** OsaurusCore is *in-process Swift* (not a subprocess/sidecar);
  its VM/server/relay are Pro-only and clear the runtime-plural bar before going live.
- **ProvenanceGate:** MIT → `direct_import`; LICENSE preserved; vendored under root.
- **Honest gating:** Act=Osaurus is Pro; MAS Act stays on the in-process local path.
  Never offered where it can't run (owner #1).
- **Don't destabilize Chat/Act:** isolate behind the Act mode + flag; Chat/Work
  unchanged; regression coverage (the GOOSE-into-Work guardrail pattern).

## Net
MIT makes Osaurus the one big port that's license-clean to `direct_import` — but its
power (VM, server, relay, plugins) is squarely Pro/outside-MAS, so Act=Osaurus is a
Pro feature gated behind owner approval + the no-hidden-fallback bar, while MAS Act
stays on the existing in-process path. Import = vendor the full repo + link
OsaurusCore (Pro) + reskin Act UI, sequenced capability-by-capability. First seam =
a Pro-gated `ActOsaurusBridge` protocol + flag + MAS/Pro guard test (no repo yet),
landing next. Cross-ref: LocalModelServer (osaurus-pattern server), LocalPackages/
mlx-swift-lm (vendoring precedent), deployment-profile doctrine, R-CUA (Lume/
Containerization sandbox), GOOSE-into-Work isolation guardrail.

---

## ‼️ OWNER DIRECTIVE + CORRECTION (2026-06-21) — READ FIRST, supersedes any reductive framing
**Owner (verbatim, 2026-06-21):** *"i want the full osaurus clone … trying to do the front end back
end thing from the beginning led to muddiness because the cloned thing would never be fully cloned …
i want the osaurus to be in the app and then cross references the chat to work so it accurately gets
changed. retain my ip. i still want it fully fixed and substrate finished maybe after we are done,
before is just wasting time. i want osaurus settings osaurus everything because i am taking the entire
app."*

**What this locks in (do NOT re-reduce):**
1. **FULL clone — the ENTIRE Osaurus app: settings, everything.** Vendor the complete repo
   (zero cherry-pick, per the strategy above). NOT a "keep our front-end, swap only the backend"
   split — the owner has tried that split before and it caused MUDDINESS because the clone was never
   fully completed. Bring ALL of Osaurus in first.
2. **Then cross-reference the existing chat** to reconcile/adapt it accurately against the full clone
   (not the other way around).
3. **RETAIN the owner's IP** — system prompts + the hidden pieces are preserved/ported, layered on
   the cloned engine. Nothing of the owner's is deleted before the clone proves out.
4. **SEQUENCING:** Osaurus full clone FIRST. The remaining substrate finish + the chat fixes
   (incl. the hidden-Qwen-fallback kill, SS-CHATPICKER) come AFTER — doing them before the clone is
   "wasting time" per the owner. (The fallback kill is still cheap + shared plumbing; sequence it per
   owner, but don't drop it.)
5. **CORRECTION:** OsaurusCore is **in-process Swift**, not a subprocess. An earlier monitor claim
   that "Osaurus is a subprocess that MAS blocks" was a HALLUCINATION — corrected here. The
   in-process loopback server needs only `com.apple.security.network.server` (MAS-allowed). The owner
   wants it minimal/black-boxed; the heavy VM/relay bits may stay Pro/excluded, but the clone itself
   goes IN the app.

**ANTI-HALLUCINATION DISCIPLINE (owner flagged hallucinations 2026-06-21):** every claim about a file/
capability MUST be grounded by reading the actual file in-repo BEFORE stating it. The plan is the sole
authority; never reduce or reinterpret it from memory. No "proven/done" without a real-state test.
