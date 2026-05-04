# Notes Editor And Native Text Patterns

> **Index status**: DEFERRED-RESEARCH — Windows porting research; deferred (V1 = macOS-only per ambient_V1_DECISION.md).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/60_deferred_research/windows_research/`.



## Real Source File

- [ProseEditorRepresentable.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorRepresentable.swift)

## What The Current App Actually Does

The note editor is not a generic SwiftUI text box.

It uses a native text-system bridge with:

- one persistent text view for the lifetime of the note editor surface
- storage swapping across pages
- native scroll view ownership
- native undo wiring
- syntax-aware text storage
- debounced sync back to app state
- explicit guards against layout-feedback loops

## Core Patterns

### Persistent Editor Instance

The app does not destroy and recreate the editor on each page switch.

It keeps:

- a persistent native text view
- per-page storage swapped in
- state restoration for selection and scroll

### Native Scroll Ownership

The native text view lives inside a native scroll container.

That is deliberate. It avoids:

- UI framework layout loops
- O(document) height recomputation
- CPU spikes from text-size queries on every change

### Debounced Binding

Text changes do not force an app-wide reactive storm per keystroke.

The editor side debounces sync.

### Streaming AI Insertions

AI text is inserted directly into the editor storage path with safeguards around state sync.

## Windows Research Requirement

Research the best Windows-native text stack that can preserve these exact qualities:

- persistent editor instances
- page-storage swapping
- native undo
- incremental highlighting
- low-copy insertion of streamed AI text
- scroll/selection preservation
- minimal latency under long documents

## The Wrong Answers

Do not propose:

- an HTML editor
- a browser markdown editor
- a control that requires full document re-render on each edit
- state synchronization that rebuilds the editor surface on each keystroke

## Research Output Needed

The research should identify:

- the best native editor control stack
- the best extension point for syntax highlighting
- the best way to host persistent editor instances per note window
- the best way to keep AI text insertion and user edits from fighting each other
