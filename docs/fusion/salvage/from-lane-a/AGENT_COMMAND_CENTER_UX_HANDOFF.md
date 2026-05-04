# AGENT COMMAND CENTER UX: CODEX HANDOFF SYNTHESIS

**To: Codex (Architecture Auditor & Planner)**
**From: UX Analysis Subsystem**
**Date: 2026-04-13**

## 1. Executive Summary: The UX Paradigm Shift
We are formally moving Epistemos from a **"Blank Canvas"** AI UX (click anywhere to chat) to a **"Command Center"** UX for our agent interactions. The new interaction mechanism introduces an explicit "Agent Layer" to the application, providing users with a robust, discoverable, and highly controlled interface for delegating autonomous tasks to the local AI.

**Your Task as Codex:** Integrate this new UI/UX paradigm into the master architectural plan (`docs/future-work-audit.md` and `EPISTEMOS-NORTH-STAR.md`), modify the SwiftUI implementation roadmap for the landing page, and define the necessary state objects and binding pipelines required to build this.

## 2. The Core Rationale
The click-anywhere "magical" canvas suffers from the Blank Page Problem. Power users need explicit affordances. By creating a dedicated Agent Layer, we achieve:

1. **Discoverability and Power:** The user immediately sees what the system is capable of (MCP tools, Agents, specific context selectors) without having to guess the capabilities.
2. **Mental Model Separation:**
   - **Mode A (Authoring):** The user writes notes and navigates the spatial graph.
   - **Mode B (Delegating):** The user enters the Agent Command Center. The AI is now in the driver's seat.

## 3. UI/UX Blueprint & Mechanics (The Cursor & Antigravity Inspiration)

The UX blueprint borrows heavily from the best-in-class developer tools: **Cursor (Cmd+K / Composer)** and **Antigravity**. The interface should be keyboard-first, heavily utilizing slash-commands (`/`) and at-mentions (`@`), packaged in a premium Apple-native aesthetic.

### A. The Entry Point
*   **The Pill Icon:** On the main landing page/toolbar, add a dedicated "Agent" icon to the existing navigation pill.
*   **The Shortcut:** Implement a global, omnipresent shortcut (e.g., `Cmd + J` or `Shift + Cmd + K`) to summon the Agent Layer instantly.

### B. The Command Center Experience (Visuals)
When the user triggers the Agent Layer:
*   **Dimming & Glass:** The main UI (the knowledge canvas/graph) slightly dims and recedes into the background. The background shifts to the "liquid glass" `.glassEffect()` aesthetic defined in the Epistemos Theme.
*   **The Floating Bar:** A central, prominent search/command bar appears in the middle of the screen (similar to macOS Spotlight or Antigravity's central command).

### C. The Input Mechanics (The Cursor/Antigravity Model)
The text input is not just a chat box; it is a context-aware command line.

*   **Slash Commands (`/`) for Modes & Tools:**
    *   Typing `/` opens a rich dropdown (like in Antigravity) allowing the user to select:
        *   **Modes:** `/ask`, `/debug`, `/plan`, `/research`
        *   **Commands/Tools:** `/read-branch`, `/review`, `/summarize`
    *   *Implementation Note for Codex:* This requires a robust `TextKit 2` or SwiftUI `TextField` overlay that parses typed prefixes in real-time to render an autocomplete popover.
*   **Context Selectors (`@`):**
    *   Typing `@` allows the user to explicitly attach context to the prompt.
    *   Examples: `@Safari`, `@CurrentGraph`, `@AllNotes`, `@Folder:Research`
*   **Inline Tool Toggles:**
    *   Below the input field, display SwiftUI "capsule/pill" views. These represent active **MCP Servers** or capabilities (e.g., "🗄️ SQLite", "🌐 GitHub", " Notes AX").
    *   Users can click or keyboard-navigate these pills to toggle capabilities on/off for the current prompt.

### D. Provider Styling & "Native" Feel
Taking inspiration from Antigravity:
*   While the models themselves may run via different providers (Local MLX Qwen, Apple Intelligence, or specific local agents like `safari-agent`), the UI they interact in should feel completely native.
*   Chat boxes and output streams should have dedicated styling based on the agent or provider being used, but they should all feel like terminal execution panels or native assistant panels—not just a generic web-chat UI.
*   There should be a dropdown selector to quickly swap the underlying "Brain" (e.g., Local 3B, Local 8B, Apple Intelligence) inline within the command bar, exactly as seen in the Antigravity UI blueprints.

## 4. Required Updates for Codex's Master Plan

Codex, when updating the repository plans, please map out the following architectural requirements:

1. **State Management:** A new `@Observable` class (e.g., `AgentCommandCenterState`) to handle the presentation of the glass overlay, the state of the input field, and the currently selected `/` mode or `@` contexts.
2. **Keybind Routing:** Ensure the core `AppEnvironment` or `NSEvent` monitor can catch the global hotkey and bring the `AgentCommandCenter` view to the frontmost layer, suspending current text editor focus without losing the selection state.
3. **Menu/Popover Engine:** Design a reusable Swift component for the floating suggestion menus that appear when typing `/` or `@` (ensuring zero-lag performance inside SwiftUI).
4. **Tool Wiring:** Map the UI capsule buttons directly to the Rust `MCPDispatcher` and `ToolRegistry` so that toggling a capsule actually primes the Rust orchestrator for that specific tool restriction.

*End of Synthesis. Over to you, Codex.*
