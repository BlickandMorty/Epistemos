# R-FIELDTHEORY verdict — afar1/fieldtheory ("Field Theory") (2026-06-18)

**Verdict: `research_only` / clean-room NATIVE pattern adoption — do NOT port or
bundle the code. TWO dispositive blockers: (1) LICENSE — the main repo is
AGPL-3.0-or-later, viral copyleft that is incompatible with Epistemos's
closed-source MAS + Pro distribution AND with App Store terms (the well-known
GPL-vs-App-Store conflict); porting or even WebKit-bundling AGPL-owned code would
force Epistemos itself to become AGPL. The ProvenanceGate license check (the same
discipline now in `FineTunePackRegistry.add()` — incompatible license → rejected)
quarantines it. (2) ARCHITECTURE — it's an Electron (Node + Chromium) desktop app;
an Electron runtime cannot be a MAS-sandboxed/hardened-runtime sidecar (NO-SIDECAR
NON-NEGOTIABLE). Net: ~80% of its features are ALREADY native in Epistemos; the one
net-new pattern worth building — the "context launcher" global hotkey that injects
current context into the frontmost app — is a clean-room NATIVE feature on the
existing AXorcist/DeviceAgentService/CGEvent substrate, not a port. No code lifted
(research-first).**

## What it is (primary source: the GitHub repo README)
`afar1/fieldtheory` ("Field Theory") — a **local-first macOS app for human +
agentic reading and writing**: context management across modalities (writing,
reading, voice transcription, integrated terminal, X bookmarks, clipboard),
emphasizing local processing and portability between model providers.
- **Stack:** TypeScript **95.1%** + Swift 1.5% + JS 1.3% + C 1.0% + Python 0.4% +
  Shell — built as an **Electron + Vite + React** macOS desktop app. 1,527 commits.
- **License:** **AGPL-3.0-or-later** for Field-Theory-owned code (the repo family
  uses a split-license model; some *sibling* repos are MIT).
- **Type:** native-feeling macOS app, but **Electron-based** (Chromium + Node main
  process). `mac-app/src` = renderer UI (React); `mac-app/electron/main` =
  privileged main-process code (IPC, local data, auth, sync, "River", updater, OS
  integration); `electron/preload.ts` = capability bridges.
- **Deps:** Electron, Vite, React, Node.js, **Supabase** (account-backed sync),
  local **Whisper** (voice), Claude/Codex/Gemma integrations.
- **Features:** native-ish markdown editor; local X-bookmark store + viewer;
  integrated terminal for collaborative writing with AI; multi-window comparative
  reading; **context launcher (⇧⌘K) that deploys content to the frontmost app**;
  local voice transcription with priority audio; full clipboard manager
  (Gmail-style shortcuts); markdown-based local commands; emoji.

## Why NOT a port (the two hard blockers)

### Blocker 1 — LICENSE (dispositive, overrides the earlier "WebKit port" guess)
The owner's guardrail (ledger line 50) pre-listed `fieldtheory` under "full web-app
ports → WebKit OK." That guidance pre-dates the license finding. **AGPL-3.0-or-later
is dispositive and overrides it:**
- AGPL is **strong viral copyleft**: anything that links/derives from AGPL code —
  *including* shipping its TS/React bundle inside a WebView in a larger work — must
  release the COMPLETE corresponding source of the whole work under AGPL, and AGPL
  §13 extends that to anyone interacting over a network.
- Epistemos is a **closed-source commercial** app (MAS + Pro). Taking AGPL code in
  would force the entire app to AGPL. **Not acceptable.**
- AGPL/GPL is also **incompatible with App Store distribution** (Apple's DRM +
  usage terms conflict with the GPL family's freedoms — apps have been pulled for
  exactly this). MAS is the primary target.
- This is precisely the case the **ProvenanceGate** exists for. The license gate I
  just shipped in `FineTunePackRegistry.add()` (unlicensed / incompatible →
  rejected) and `F-ProprietaryCompression-ProvenanceGate` (quarantine → choose
  direct_import / adapter_wrap / quarantine_reference / clean_room_rewrite /
  research_only) → **verdict = `research_only`** for AGPL-owned code.
- ⮕ If the owner specifically wants ONE component that lives in an **MIT sibling**
  repo, name it and I'll assess that repo on its own license — the MIT siblings are
  not blocked by this verdict; only the AGPL `fieldtheory` repo is.

### Blocker 2 — ARCHITECTURE (Electron can't be a MAS sidecar)
Field Theory is an **Electron** app: a bundled Chromium + a Node.js main process
doing privileged OS work. Epistemos is native Swift + Rust, **MAS-sandboxed +
hardened-runtime, with NO Node/Python runtime sidecar** (CLAUDE.md NON-NEGOTIABLE +
the owner's NO-SIDECAR guardrail + memory). You cannot drop an Electron app in as a
sidecar. The WebKit-bundle path (Tiptap/htmlstream precedent) can host *React UI*,
but the VALUABLE part of Field Theory is **not** the renderer — it's the
`electron/main` OS-integration (frontmost-app injection, clipboard, terminal,
Whisper), which Epistemos already does **natively** (AXorcist / AXUIElement,
CGEvent, ScreenCaptureKit, `agent_core` `terminal.rs`).

## Feature map — ~80% is ALREADY native in Epistemos
| Field Theory feature | Epistemos today | Action |
|---|---|---|
| Markdown editor | Tiptap/Epdoc WebKit editor + native ProseEditor (TextKit) | ✅ have |
| Integrated AI terminal | `agent_core/src/.../terminal.rs` (hardened subprocess) | ✅ have |
| Local voice transcription (Whisper) | AudioTranscriber (Python Whisper today; native-Whisper is a tracked kill-order follow-on) | ✅ have / in-flight |
| Multi-window comparative reading | native SwiftUI windows | ✅ have (minor) |
| Clipboard manager | native `NSPasteboard` (small native build if wanted) | ⚪ optional native |
| **Context launcher (⇧⌘K → inject context into frontmost app)** | DeviceAgentService + AXorcist + CGEvent substrate exists; the *global-hotkey → frontmost-app context injection* UX is net-new | ⭐ **clean-room NATIVE pattern** worth adopting |
| X-bookmark store/viewer | none | ⚪ niche, low priority — skip |
| Supabase account sync | Keychain-only creds, local-first | ❌ drop (conflicts with local-first) |

## The actionable native path (delivers the VALUE, none of the AGPL code)
1. **Adopt the context-launcher PATTERN natively** (the one genuinely-new idea): a
   global hotkey (⇧⌘K-style) that takes the user's *current Epistemos context*
   (selection / active note / last answer) and **injects it into the frontmost
   app** via the existing AX/CGEvent substrate (DeviceAgentService / AXorcist).
   Clean-room Swift — observed behavior only, zero AGPL source. Pro-gated (it drives
   other apps → outside the MAS sandbox surface), honest gating, RunEventLog.
2. **Everything else already exists** — no port needed; if a gap is felt (clipboard
   manager), build it natively + small.
3. **ProvenanceGate record:** `fieldtheory` (AGPL-3.0-or-later) → `research_only`,
   quarantined; MIT siblings assessable individually on owner request.

## Net
The owner's "port the WHOLE thing" instinct collides with two NON-NEGOTIABLEs the
owner themselves set: the ProvenanceGate (AGPL viral copyleft → can't enter a
closed-source MAS app) and NO-SIDECAR/MAS (Electron can't sidecar). The honest,
owner-serving outcome is to deliver the *value* natively: Epistemos already covers
~80% of Field Theory's surface, and the one net-new pattern (frontmost-app context
launcher) is a clean-room native feature on substrate that already exists. This is a
case where "research → build" means **build the pattern, not port the code.**
Cross-ref: DeviceAgentService / AXorcist / CGEvent, terminal.rs, AudioTranscriber,
FineTunePackRegistry license gate, F-ProprietaryCompression-ProvenanceGate.
