# Hermes Expert View UI Specification

> **Index status**: CANONICAL-RESEARCH — Hermes integration research (Phase D + K reference).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/hermes_research/`.



## Architecture
The UI is centered around `HermesExpertView` serving as a dynamic, three-pane layout adjacent to standard Epistemos Chats and Notes. All interactions run via SwiftData.

## Pane Layout
* **Left Sidebar (HermesTaskListColumn):** List of past running and archived agent tasks mapped mapped identically to `SDHermesTask` records.
* **Center Detail (HermesTaskDetailColumn):**
  * Top sticky composer allowing manual instruction overrides.
  * Scrollable `Think -> Plan -> Act -> Observe` event feed. Uses isolated tool-call cards (e.g. `BrowserActionCard`, `ShellCommandCard`, `WebSearchCard`).
  * Terminal Pane explicitly backed by `SwiftTerm` implementing `NSViewRepresentable` to handle true VT100 sequence buffering at native 60hz, bypassing standard SwiftUI multiline-text performance limitations.
* **Right Inspector (HermesInspectorColumn):** Advanced raw YAML/JSON inspection pane for active tasks.

## OS Triggers
* **Global Shortcut:** `Cmd+Shift+H` pulls up the Expert modal prompt. 
* **macOS Notification Deep-linking:** Native notifications carrying `userInfo["taskID"]` that click-through back directly to the active Hermes context.
