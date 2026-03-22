# Windows Research Handoff

This folder is a compact source-of-truth handoff for researching a native Windows port of Epistemos.

Use this stack in order:

1. [01_master_google_research_prompt.md](/Users/jojo/Epistemos/docs/windows_research_handoff/01_master_google_research_prompt.md)
2. [02_hardware_target_and_windows_constraints.md](/Users/jojo/Epistemos/docs/windows_research_handoff/02_hardware_target_and_windows_constraints.md)
3. [03_app_architecture_and_bootstrap.md](/Users/jojo/Epistemos/docs/windows_research_handoff/03_app_architecture_and_bootstrap.md)
4. [04_ai_routing_and_local_inference.md](/Users/jojo/Epistemos/docs/windows_research_handoff/04_ai_routing_and_local_inference.md)
5. [05_persistence_models_and_vault.md](/Users/jojo/Epistemos/docs/windows_research_handoff/05_persistence_models_and_vault.md)
6. [06_notes_editor_and_textkit_patterns.md](/Users/jojo/Epistemos/docs/windows_research_handoff/06_notes_editor_and_textkit_patterns.md)
7. [07_chat_surfaces_and_session_patterns.md](/Users/jojo/Epistemos/docs/windows_research_handoff/07_chat_surfaces_and_session_patterns.md)
8. [08_graph_engine_and_rust_ffi.md](/Users/jojo/Epistemos/docs/windows_research_handoff/08_graph_engine_and_rust_ffi.md)
9. [09_performance_rules_and_antipatterns.md](/Users/jojo/Epistemos/docs/windows_research_handoff/09_performance_rules_and_antipatterns.md)
10. [10_windows_port_decision_matrix.md](/Users/jojo/Epistemos/docs/windows_research_handoff/10_windows_port_decision_matrix.md)

What this is:

- A research package for a Windows-native port.
- A compressed description of the app's actual engineering style.
- A map from product goals to concrete source files.

What this is not:

- It is not a rewrite spec.
- It is not permission to add web tech.
- It is not permission to weaken the current performance rules.

Non-negotiables for the Windows port:

- No Tauri, Electron, WebView shell, or browser UI stack.
- Preserve the current split: native frontend + Rust systems core.
- Preserve local-first AI routing and local model orchestration.
- Preserve note-editor responsiveness and graph performance.
- Preserve the app's direct style: minimal layers, low-copy data flow, aggressive caching in hot paths.

If Google Research wants raw source context, start with these real files:

- [AGENTS.md](/Users/jojo/Epistemos/AGENTS.md)
- [AppEnvironment.swift](/Users/jojo/Epistemos/Epistemos/App/AppEnvironment.swift)
- [AppBootstrap.swift](/Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift)
- [ChatCoordinator.swift](/Users/jojo/Epistemos/Epistemos/App/ChatCoordinator.swift)
- [TriageService.swift](/Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift)
- [PipelineService.swift](/Users/jojo/Epistemos/Epistemos/Engine/PipelineService.swift)
- [ProseEditorRepresentable.swift](/Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorRepresentable.swift)
- [MiniChatView.swift](/Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatView.swift)
- [SDPage.swift](/Users/jojo/Epistemos/Epistemos/Models/SDPage.swift)
- [lib.rs](/Users/jojo/Epistemos/graph-engine/src/lib.rs)
