# MAS C Feature Plan - Epdoc Assist

ID: `MAS-C-F05-EPDOC-ASSIST-2026-07-08`
Codename: `EPDOC-ASSIST`
Status: active after MAS June bridge is stable

## Intent

Replace the 1Code mini-chat idea with a MAS-native Epdoc assist dock. It should
help with the selected note, source, or dataset while using the same MAS June
session, approval path, provenance, and vault tools.

## Scope

- Native dock/panel inside Epdoc.
- Context from the selected note/source/dataset.
- June-backed chat, suggestions, and approved write tools.
- Provenance and undo on every write.
- No independent agent runtime.

## Fabric Mapping

- F1 vault bus: reads selected files and writes only through approved operations.
- F2 agent capability registry: reuses MAS June tools, no duplicate registry.
- F3 MAS status/provenance: renders run state in dock and global status.
- F4 graph: suggests links through public graph API.
- F5 provenance: records chat intent, cited context, and writes.
- F6 event bus: subscribes to current selection and June run events.

## Phases

1. Inventory `JuneEpdocAssist`, `EpdocCopilotDockView`, editor selection, and
   agent session seams.
2. Define context packet and approval contract.
3. Implement one read-only assist flow.
4. Implement one approved write/suggestion flow.
5. Harden undo, citations, and manual UI evidence.

## Parked Or Forbidden

- No 1Code UI stack.
- No second chat backend.
- No direct file writes from the dock.
- No hidden terminal or code-exec capability.

## Acceptance Evidence

- Selected note context proof.
- Read-only assist proof.
- Approved write/suggestion proof with undo.
- Provenance ledger entry.
- Manual UI screenshot or notes for dock behavior.

