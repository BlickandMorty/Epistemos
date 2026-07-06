# DEEP-RESEARCH PROMPT — PLAN 6: QUICK CAPTURE (robust unstructured capture + voice)

**ID:** `EPI-RP-06-EMBERCATCH` · **Codename:** EMBERCATCH · Obey `RESEARCH_PROMPT_STANDARD.md` §3 rubric + §4 sources + §5 shape + §7 fabric (deep integration is graded).

> Paste below `─── BEGIN ───` into a deep-research model. Output = build-ready dossier. Owner
> authored 2026-07-06. **Build split: both builds (MAS + 1Code).** MAS is the strict target — no
> subprocess; on-device voice only.

─── BEGIN RESEARCH BRIEF ───

## 0. Who you are / deliverable
Principal capture/ingest researcher. Produce a build-ready dossier for a **frictionless, robust
quick-capture** system for a macOS-native PKM: text + voice + files → the vault, as **unstructured
thoughts**, saved to a dedicated **"Quick Capture" folder**, later refinable into structured notes.
External primary sources (Apple Speech/SpeechAnalyzer, on-device STT, Kokoro TTS, capture-app design,
NSFileCoordinator/security-scoped bookmarks). Cite everything; invent nothing. Design against the
files below.

## 1. Product context (ground truth)
Epistemos = macOS-native PKM; the **vault** (markdown files) is the single source of truth. Capture
must be **instant and forgiving**: the point is to get a thought/voice-memo/dropped-file into the
vault with **zero ceremony**, never blocking on structure. Two builds: **MAS** (sandboxed, hardened,
**no subprocess**, on-device voice only) and **1Code/Experimental** (Developer ID). This plan ships
in **both**.

The owner's asks, verbatim intent:
- Quick capture should be **more robust**.
- Captures save to a folder titled **"Quick Capture"** and are **unstructured files / unstructured
  thoughts** (not forced into a template).
- It should **use the new voice models** (on-device Kokoro + Apple Speech) for voice capture (and
  read-back).
- Captures should be **seed-able into Epdoc** later (turn a raw thought into a real note).

## 2. Thesis
**The fastest path from a fleeting thought — typed, spoken, or dropped — into the vault as a durable
unstructured note in a "Quick Capture" folder, with best-in-class on-device voice, and a clean
promotion path from raw capture → structured Epdoc note.** Frictionless first; structure later.

## 3. Hard constraints
1. **MAS-safe** — sandbox + hardened runtime; **no subprocess**; on-device voice only (no cloud STT
   on the MAS default path); security-scoped bookmarks + `NSFileCoordinator` for vault writes.
2. **Never lose a capture** — durable-write, crash-safe, offline-safe; a capture in flight survives
   app quit. This is the "more robust" mandate — design for zero data loss.
3. **Unstructured by default** — captures land as plain markdown thoughts in the "Quick Capture"
   folder; no forced schema; promotion to structure is opt-in and later.
4. **Instant** — global hotkey / menu-bar / widget entry with sub-100ms surface; capture must feel
   immediate even while the vault indexes in the background.
5. Platform hygiene: `@Observable`; never block `@MainActor`; keys in Keychain; serialize access to
   Apple NL/Speech/LanguageModel APIs (they crash on concurrent access); don't touch the graph.

## 4. What exists today (extend, don't reinvent)
- **Capture UI:** `Epistemos/Views/Capture/QuickCaptureView.swift`, `QuickCaptureReadBack.swift`,
  `TraceInspectorView.swift`.
- **Voice:** on-device TTS `Epistemos/VoicePro/Kokoro*` (CoreML runtime loader, synthesizer, model
  download/install, gate status, settings); STT/analysis `Epistemos/Engine/EpistemosSpeechAnalyzer.swift`,
  `LiveVoiceInputService.swift`, `ComposerVoiceInputService.swift`; `EpistemosSpeechSynthesizer.swift`;
  `VoicePreferences.swift`. (Kokoro-82M is the MAS-safe on-device voice.)
- **Vault write path:** `Epistemos/Sync/VaultSyncService.swift` (`createPage(title:body:...)`),
  and the note surfaces (Epdoc seeding target `MarkdownDocumentSurface.swift`).
- **Entry points:** App Intents / Shortcuts (`Epistemos/Intents/*`), control widget
  (`EpistemosControlWidget.swift`).
- Salvage context: memory `project_quick_capture_salvage_triage` (prior capture Rust tiers).

## 5. Research dimensions
### D1 — Capture surfaces & instant entry (both builds)
- The fastest entry patterns on macOS: global hotkey, menu-bar popover, a floating capture window,
  Shortcuts/App Intents, Control Center/widget, share-extension, drag-drop. Cite Apple APIs +
  best-in-class capture apps (Drafts, Bear, Obsidian capture, Reflect, mymind, MacWhisper). What's
  the sub-100ms "always ready" architecture? Warm surface, off-main persistence.

### D2 — The "Quick Capture" folder & unstructured model
- The vault layout for captures: a dedicated **Quick Capture** folder, naming/timestamping,
  frontmatter (minimal), how a capture is a first-class vault note yet clearly "unstructured/inbox."
  How dropped **files** (images/pdf/audio/arbitrary) are stored + referenced. GTD-"inbox" patterns.
- **Promotion path** raw capture → structured Epdoc note (seed the markdown into Epdoc; keep
  provenance to the original capture). Cite the note-creation seam.

### D3 — Voice capture (on-device, the "new voice models") ★
- **Speech-to-text on-device**: Apple `Speech` / the newer `SpeechAnalyzer`/`SpeechTranscriber`
  (macOS 26) vs Whisper-class local models. Latency, accuracy, streaming/partial results, language
  support, MAS-sandbox + privacy. Verdict for the MAS default + any 1Code-only upgrade. Cite the
  real APIs and their constraints (incl. the concurrency-crash caveat).
- **Voice memo capture**: record → store audio in the Quick Capture folder → transcribe → keep both
  audio + transcript linked. Robustness: long recordings, interruptions, background.
- **Read-back (TTS)** with Kokoro (existing `QuickCaptureReadBack` + `Kokoro*`): confirm what a
  capture says back; voice selection; MAS-safe on-device.
- Serialization discipline around Apple NL/Speech APIs (they crash concurrently) — design the actor.

### D4 — Robustness & durability (the core "more robust" mandate)
- Zero-loss write pipeline: journaled/staged writes, crash recovery, offline queue, `NSFileCoordinator`
  + security-scoped bookmarks, conflict with external edits/sync. A capture must survive quit/crash.
- Failure table: mic denied, disk full, vault not mounted, STT fails, huge dropped file, app killed
  mid-capture. Define graceful behavior for each.

### D5 — Intelligence (light, optional, honest)
- Optional low-friction enrichment that never blocks capture: auto-title, tag suggestion, link
  candidates, "route to note X" — all **after** the capture is safely saved, opt-in, honestly gated
  (on-device where possible; cloud only on 1Code with consent). Don't over-engineer; capture-first.

### D6 — Competitive synthesis
- Cited table: Drafts, Bear, Obsidian, Reflect, mymind, MacWhisper, Apple Notes quick-note,
  Superwhisper. Columns: entry speed, voice, unstructured inbox, promotion, robustness, on-device.
  What to copy, avoid, and the novel edge.

## 6. Primary-source discipline
Cite Apple Speech/SpeechAnalyzer, AVFoundation, NSFileCoordinator, App Intents, Kokoro. Flag
macOS-version-gated speech APIs + fallbacks. Distinguish observed vs inferred.

## 7. Deliverable
1. Executive thesis. 2. Capture surfaces + instant architecture (D1). 3. Quick Capture folder +
unstructured model + promotion (D2). 4. **On-device voice capture/read-back** (D3 — headline).
5. **Durability/robustness pipeline + failure table** (D4 — the "more robust" core). 6. Optional
enrichment, honestly gated (D5). 7. Competitive table + novel edge (D6). 8. Phased build order
(durable write core → instant entry → Quick Capture folder → voice STT → voice memo+read-back →
promotion → optional enrich), each with a witnessable proven-done bar; flag Plan 2 (Epdoc seeding)
+ Plan 7 (Sync) dependencies. 9. Open questions.

## 8. Anti-patterns
No capture flow that can lose data, blocks on structure, or blocks on a network/model. No cloud STT
on the MAS default path. No concurrent Apple-Speech access. No forced templates. Capture-first,
always.

─── END RESEARCH BRIEF ───
