# MAS C Feature Plan - Embercatch

ID: `MAS-C-F06-EMBERCATCH-2026-07-08`
Codename: `EMBERCATCH`
Status: active after vault write safety

## Intent

Make quick capture fast, reliable, and App Store-safe. Captures should become
real vault notes or Epdoc seeds that MAS June can organize later.

## Scope

- Text quick capture.
- Voice capture where entitlement, privacy, and user consent are clear.
- Capture-to-vault note creation.
- Capture-to-Epdoc and capture-to-June seeding.
- Offline-first behavior.

## Fabric Mapping

- F1 vault bus: writes capture notes/artifacts.
- F2 agent capability registry: June can summarize, file, tag, or expand
  captures after approval.
- F3 MAS status/provenance: shows capture saved, transcribing, queued, failed.
- F4 graph: links captures to notes/entities when processed.
- F5 provenance: records source app/context only when allowed and disclosed.
- F6 event bus: emits capture lifecycle events.

## Phases

1. Inventory existing quick capture and note creation docs/code.
2. Define capture note schema and privacy constraints.
3. Implement text capture to vault.
4. Implement optional voice capture only with entitlement/privacy proof.
5. Wire MAS June organize/expand capability.

## Parked Or Forbidden

- No global keylogger-like behavior.
- No undisclosed audio recording.
- No Pro git or subprocess lane.
- No capture store that bypasses vault truth.

## Acceptance Evidence

- Text capture fixture note.
- Voice privacy/entitlement proof if voice is enabled.
- Failure/retry behavior.
- MAS June post-capture tool proof.
- Manual UI evidence for capture surface.

