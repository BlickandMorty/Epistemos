#!/usr/bin/env python3
"""
Advanced Training Data Generator — Reasoning Chains, Scroll Matrix, Code Grounding
===================================================================================

Supplements generate_epistemos_training_data.py with:
  8.  Reasoning chain examples (ODIA with "I see X, state is Y, I do Z")
  9.  Scroll/gesture matrix (all combinations enumerated)
  10. AXPress action schema examples (constrained decoding training)
  11. Code-grounded trajectories (source code + UI element fusion)
  12. macOS system knowledge (keyboard shortcuts, system preferences, etc.)
  13. Multi-app workflows with reasoning
  14. Temporal and sequential task understanding
  15. Error diagnosis chains (what went wrong and why)

Uses AXPress schema format:
  {"action": "click|type|key|scroll|focus|shortcut", "selector": "...", "value": "...", "modifiers": [...]}

Every example includes a reasoning chain in <think>...</think> tags.

Usage:
    python generate_advanced_training_data.py --output ./epistemos_training_data
"""

import argparse
import json
import os
import re
import hashlib
import random
from pathlib import Path
from typing import List, Dict

SYSTEM_PROMPT = """You are Epistemos-Nano, a 1B on-device AI agent for macOS.
You think step-by-step inside <think>...</think> tags before acting.
You output AXPress actions as JSON after your reasoning.
You verify actions through perception loops (observe → decide → interact → assess).
You know when NOT to act. You recover from errors gracefully.
You deeply understand the Epistemos codebase and every macOS UI pattern."""

# ─── Reasoning Chain Examples ───────────────────────────────────

def generate_reasoning_chains() -> List[dict]:
    """Every example has: observe → think → decide → act → assess."""
    examples = []

    CHAINS = [
        # ─── Epistemos In-App ───────────────────────────
        {
            "user": "Create a new note about quantum computing",
            "think": "I see the Epistemos landing view. The sidebar shows the notes list with a 'New Note' button at the top. I need to click it to create a new note, then type the title.",
            "actions": [
                {"action": "click", "selector": "AXButton[@AXTitle='New Note']"},
                {"action": "type", "selector": "AXTextField[@AXTitle='Title']", "value": "Quantum Computing Research"},
                {"action": "key", "selector": "", "value": "tab"},
                {"action": "type", "selector": "AXTextArea[@AXRole='AXTextArea']", "value": "# Quantum Computing\n\n## Key Concepts\n- Superposition\n- Entanglement\n- Quantum gates"},
                {"action": "key", "selector": "", "value": "cmd+s"}
            ],
            "assess": "Note created with title 'Quantum Computing Research' and body content. Saved to vault."
        },
        {
            "user": "Ask the AI to simplify this note for a beginner",
            "think": "I see a note open in the editor with technical content. I need to open the AI chat sidebar, then type my request. The AI sidebar toggle is in the toolbar.",
            "actions": [
                {"action": "click", "selector": "AXButton[@AXTitle='AI Chat Sidebar Toggle']"},
                {"action": "type", "selector": "AXTextField[@AXSubrole='AXSearchField']", "value": "Simplify this note for someone who has never studied quantum physics. Use analogies."},
                {"action": "key", "selector": "", "value": "return"}
            ],
            "assess": "AI chat sidebar opened, query submitted. AI is streaming a simplified version below the divider."
        },
        {
            "user": "The AI response looks good, accept it",
            "think": "I see the AI response below the --- divider in the note editor. There are Accept and Discard buttons visible. I'll click Accept to merge the AI text into the note body.",
            "actions": [
                {"action": "click", "selector": "AXButton[@AXTitle='Accept AI Response']"}
            ],
            "assess": "AI response merged into note body. Divider removed. Note now contains the simplified content inline."
        },
        {
            "user": "Navigate to the graph view and find connections to this note",
            "think": "I see the note editor. I need to switch to the graph view. There should be a graph icon in the toolbar or navigation. The graph will show this note as a central node with its connections.",
            "actions": [
                {"action": "click", "selector": "AXButton[@AXTitle='Graph View']"}
            ],
            "assess": "Graph view loaded showing the current note as the central node. I can see connected nodes for related topics, sources, and tags."
        },
        {
            "user": "Search for all notes about machine learning in my vault",
            "think": "I see the notes sidebar with a search field at the top. I'll focus the search field and type my query. The notes list will filter in real-time as I type.",
            "actions": [
                {"action": "focus", "selector": "AXTextField[@AXSubrole='AXSearchField']"},
                {"action": "type", "selector": "AXTextField[@AXSubrole='AXSearchField']", "value": "machine learning"}
            ],
            "assess": "Search results filtering in real-time. I can see notes containing 'machine learning' in their title or body."
        },
        {
            "user": "Right-click on this paragraph and have AI expand it",
            "think": "I see the note editor with a paragraph of text. I need to select the paragraph first, then right-click to get the AI context menu, then choose 'Expand'.",
            "actions": [
                {"action": "click", "selector": "AXTextArea[@AXRole='AXTextArea']"},
                {"action": "key", "selector": "", "value": "cmd+a"},
                {"action": "click", "selector": "AXTextArea[@AXRole='AXTextArea']", "modifiers": ["ctrl"]},
                {"action": "click", "selector": "AXMenuItem[@AXTitle='Expand']"}
            ],
            "assess": "Context menu appeared with AI options. Clicked 'Expand'. AI is now streaming an expanded version below the divider."
        },
        {
            "user": "Change the font size to 16 in settings",
            "think": "I need to navigate to Settings first. I can see the Settings gear icon in the landing view or use the menu bar. Then find the Font Size slider and adjust it to 16.",
            "actions": [
                {"action": "click", "selector": "AXButton[@AXTitle='Settings']"},
                {"action": "focus", "selector": "AXSlider[@AXTitle='Font Size']"},
                {"action": "click", "selector": "AXSlider[@AXTitle='Font Size']", "value": "16"}
            ],
            "assess": "Settings view opened. Font size adjusted to 16pt. The editor text will now render at the new size."
        },
        # ─── Safari ─────────────────────────────────────
        {
            "user": "Open Apple's developer documentation in Safari",
            "think": "I need to activate Safari first, then navigate to the Apple Developer Documentation URL. If Safari isn't running, I'll launch it.",
            "actions": [
                {"action": "shortcut", "selector": "activate_app", "value": "Safari"},
                {"action": "focus", "selector": "AXTextField[@AXSubrole='AXSearchField']"},
                {"action": "type", "selector": "AXTextField[@AXSubrole='AXSearchField']", "value": "https://developer.apple.com/documentation"},
                {"action": "key", "selector": "", "value": "return"}
            ],
            "assess": "Safari activated. URL bar focused. Navigating to Apple Developer Documentation."
        },
        {
            "user": "Go back to the previous page in Safari",
            "think": "I see Safari with a page loaded. The back button is in the toolbar. I can also use the keyboard shortcut Cmd+[.",
            "actions": [
                {"action": "key", "selector": "", "value": "cmd+["}
            ],
            "assess": "Navigated back to the previous page in Safari."
        },
        {
            "user": "Open a new tab and search for SwiftUI tutorials",
            "think": "I see Safari with existing tabs. I'll open a new tab with Cmd+T, which will focus the address bar. Then I'll type my search query.",
            "actions": [
                {"action": "key", "selector": "", "value": "cmd+t"},
                {"action": "type", "selector": "AXTextField[@AXSubrole='AXSearchField']", "value": "SwiftUI tutorials 2026"},
                {"action": "key", "selector": "", "value": "return"}
            ],
            "assess": "New tab opened. Search query typed and submitted. Google results loading."
        },
        # ─── Finder ─────────────────────────────────────
        {
            "user": "Create a new folder called 'Research' on the Desktop",
            "think": "I need to activate Finder, navigate to the Desktop, then create a new folder. I can use Cmd+Shift+N for new folder, then type the name.",
            "actions": [
                {"action": "shortcut", "selector": "activate_app", "value": "Finder"},
                {"action": "click", "selector": "AXOutline[@AXTitle='Sidebar'] > AXRow[@AXTitle='Desktop']"},
                {"action": "key", "selector": "", "value": "cmd+shift+n"},
                {"action": "type", "selector": "AXTextField", "value": "Research"},
                {"action": "key", "selector": "", "value": "return"}
            ],
            "assess": "Finder opened to Desktop. New folder 'Research' created."
        },
        {
            "user": "Move the file 'notes.txt' to the Research folder",
            "think": "I see the Desktop in Finder with notes.txt visible. I need to drag it to the Research folder. Alternatively, I can cut and paste: select the file, Cmd+C, navigate to Research, then Cmd+Option+V to move.",
            "actions": [
                {"action": "click", "selector": "AXCell[@AXTitle='notes.txt']"},
                {"action": "key", "selector": "", "value": "cmd+c"},
                {"action": "double_click", "selector": "AXCell[@AXTitle='Research']"},
                {"action": "key", "selector": "", "value": "cmd+option+v"}
            ],
            "assess": "Selected notes.txt, copied, navigated into Research folder, moved the file. notes.txt is now inside Research/."
        },
        # ─── Mail ───────────────────────────────────────
        {
            "user": "Compose a new email",
            "think": "I need to activate Mail app, then click the compose button or use Cmd+N to create a new email window.",
            "actions": [
                {"action": "shortcut", "selector": "activate_app", "value": "Mail"},
                {"action": "key", "selector": "", "value": "cmd+n"}
            ],
            "assess": "Mail activated. New compose window opened with cursor in the To field."
        },
        # ─── System-Level ───────────────────────────────
        {
            "user": "Check if accessibility is enabled for Epistemos",
            "think": "I need to open System Settings, navigate to Privacy & Security > Accessibility. I can use Spotlight to open it quickly, or use the Apple menu.",
            "actions": [
                {"action": "key", "selector": "", "value": "cmd+space"},
                {"action": "type", "selector": "AXTextField[@AXSubrole='AXSearchField']", "value": "Privacy & Security"},
                {"action": "key", "selector": "", "value": "return"},
                {"action": "click", "selector": "AXStaticText[@AXTitle='Accessibility']"}
            ],
            "assess": "System Settings opened to Privacy & Security > Accessibility. I can see the list of apps with accessibility permissions."
        },
        {
            "user": "Turn on Dark Mode",
            "think": "I can toggle Dark Mode through System Settings > Appearance, or more quickly through Control Center. Let me use the menu bar approach.",
            "actions": [
                {"action": "key", "selector": "", "value": "cmd+space"},
                {"action": "type", "selector": "AXTextField[@AXSubrole='AXSearchField']", "value": "Appearance"},
                {"action": "key", "selector": "", "value": "return"},
                {"action": "click", "selector": "AXRadioButton[@AXTitle='Dark']"}
            ],
            "assess": "System Settings opened to Appearance. Dark mode selected. All apps will now use dark theme."
        },
        {
            "user": "Take a screenshot of just this window",
            "think": "macOS has Cmd+Shift+4 for region screenshot, but Cmd+Shift+4 then Space lets me click a specific window. Even better, Cmd+Shift+5 opens the screenshot toolbar where I can select window capture.",
            "actions": [
                {"action": "key", "selector": "", "value": "cmd+shift+4"},
                {"action": "key", "selector": "", "value": "space"},
                {"action": "click", "selector": ""}
            ],
            "assess": "Screenshot mode activated in window capture mode. Clicked the current window. Screenshot saved to Desktop."
        },
        # ─── Multi-App Workflows ────────────────────────
        {
            "user": "Research quantum computing in Safari and create an Epistemos note with the findings",
            "think": "This is a multi-step cross-app workflow. I need to: 1) Switch to Safari, 2) Search for quantum computing, 3) Read the results, 4) Switch back to Epistemos, 5) Create a new note with the findings. I'll start by activating Safari.",
            "actions": [
                {"action": "shortcut", "selector": "activate_app", "value": "Safari"},
                {"action": "focus", "selector": "AXTextField[@AXSubrole='AXSearchField']"},
                {"action": "type", "selector": "AXTextField[@AXSubrole='AXSearchField']", "value": "quantum computing fundamentals 2026"},
                {"action": "key", "selector": "", "value": "return"},
                {"action": "key", "selector": "", "value": "cmd+a"},
                {"action": "key", "selector": "", "value": "cmd+c"},
                {"action": "shortcut", "selector": "activate_app", "value": "Epistemos"},
                {"action": "click", "selector": "AXButton[@AXTitle='New Note']"},
                {"action": "type", "selector": "AXTextField[@AXTitle='Title']", "value": "Quantum Computing Research"},
                {"action": "key", "selector": "", "value": "tab"},
                {"action": "key", "selector": "", "value": "cmd+v"}
            ],
            "assess": "Searched quantum computing in Safari, copied key content, switched to Epistemos, created note with research findings."
        },
        {
            "user": "Find the last email from Alice and summarize it in a new Epistemos note",
            "think": "Multi-app workflow: 1) Open Mail, 2) Search for Alice's emails, 3) Read the latest one, 4) Copy key content, 5) Switch to Epistemos, 6) Create note with summary. Starting with Mail.",
            "actions": [
                {"action": "shortcut", "selector": "activate_app", "value": "Mail"},
                {"action": "focus", "selector": "AXTextField[@AXSubrole='AXSearchField']"},
                {"action": "type", "selector": "AXTextField[@AXSubrole='AXSearchField']", "value": "from:Alice"},
                {"action": "key", "selector": "", "value": "return"},
                {"action": "click", "selector": "AXRow[0]"},
                {"action": "key", "selector": "", "value": "cmd+a"},
                {"action": "key", "selector": "", "value": "cmd+c"},
                {"action": "shortcut", "selector": "activate_app", "value": "Epistemos"},
                {"action": "click", "selector": "AXButton[@AXTitle='New Note']"},
                {"action": "type", "selector": "AXTextField[@AXTitle='Title']", "value": "Summary: Alice's Latest Email"}
            ],
            "assess": "Found Alice's email, copied content, created Epistemos note with email summary."
        },
    ]

    for chain in CHAINS:
        response = f"<think>\n{chain['think']}\n</think>\n\n"
        for action in chain["actions"]:
            response += json.dumps(action) + "\n"
        response += f"\n**Assessment:** {chain['assess']}"

        examples.append({
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": chain["user"]},
                {"role": "assistant", "content": response}
            ],
            "category": "reasoning_chain",
            "layer": 8
        })

    return examples


# ─── Scroll / Gesture Matrix ───────────────────────────────────

def generate_scroll_gesture_matrix() -> List[dict]:
    """Enumerate all scroll/gesture combinations with AXPress format."""
    examples = []

    # Scroll combinations
    directions = ["up", "down", "left", "right"]
    speeds = [("slow", 1), ("medium", 3), ("fast", 10)]
    contexts = [
        ("note editor", "Epistemos", "Scrolling through a long note"),
        ("web page", "Safari", "Scrolling a web page"),
        ("file list", "Finder", "Scrolling through files"),
        ("settings", "System Settings", "Scrolling through settings"),
        ("messages", "Messages", "Scrolling through conversation"),
    ]

    for direction in directions:
        for speed_name, speed_amount in speeds:
            for context_name, app, desc in contexts:
                intent = f"Scroll {direction} {speed_name}ly in the {context_name}"
                think = f"I see a {context_name} in {app} that needs scrolling. I'll scroll {direction} at {speed_name} speed ({speed_amount} ticks)."

                examples.append({
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": intent},
                        {"role": "assistant", "content": f"<think>\n{think}\n</think>\n\n" +
                            json.dumps({"action": "scroll", "selector": f"AXScrollArea[app='{app}']",
                                       "value": f"{direction}:{speed_amount}"})}
                    ],
                    "category": "scroll_gesture",
                    "layer": 9
                })

    # Gesture examples
    GESTURES = [
        ("pinch to zoom in on the graph", "pinch", "in", "Epistemos",
         "I see the knowledge graph view. Pinch-to-zoom-in will enlarge the graph for better detail."),
        ("pinch to zoom out on the graph", "pinch", "out", "Epistemos",
         "The graph is zoomed in too much. I'll pinch to zoom out for a broader view."),
        ("swipe back in Safari", "swipe", "right", "Safari",
         "I want to go back to the previous page. A two-finger swipe right triggers browser back."),
        ("swipe forward in Safari", "swipe", "left", "Safari",
         "I want to go forward to the next page. A two-finger swipe left triggers browser forward."),
        ("force click for Quick Look on a file", "force_click", "", "Finder",
         "I see a file in Finder. Force clicking (pressing harder) will trigger Quick Look preview."),
        ("three-finger drag to move a window", "drag", "", "System",
         "I need to reposition this window. Three-finger drag on the title bar will move it."),
    ]

    for intent, gesture_type, direction, app, think in GESTURES:
        examples.append({
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": intent},
                {"role": "assistant", "content": f"<think>\n{think}\n</think>\n\n" +
                    json.dumps({"action": gesture_type, "selector": f"AXApplication[@AXTitle='{app}']",
                               "value": direction})}
            ],
            "category": "scroll_gesture",
            "layer": 9
        })

    return examples


# ─── AXPress Schema Examples ───────────────────────────────────

def generate_axpress_schema_examples() -> List[dict]:
    """Training data in the exact AXPress constrained decoding format."""
    examples = []

    # Every valid action type with every valid modifier combination
    ACTIONS = [
        # Basic clicks
        {"intent": "Click the Save button", "action": "click", "selector": "AXButton[@AXTitle='Save']"},
        {"intent": "Click the Cancel button", "action": "click", "selector": "AXButton[@AXTitle='Cancel']"},
        {"intent": "Click the close button on the window", "action": "click", "selector": "AXButton[@AXSubrole='AXCloseButton']"},
        {"intent": "Click the minimize button", "action": "click", "selector": "AXButton[@AXSubrole='AXMinimizeButton']"},
        {"intent": "Click the zoom button", "action": "click", "selector": "AXButton[@AXSubrole='AXZoomButton']"},

        # Double clicks
        {"intent": "Open the file by double-clicking it", "action": "double_click", "selector": "AXCell[@AXTitle='document.pdf']"},
        {"intent": "Select a word by double-clicking", "action": "double_click", "selector": "AXStaticText[@AXValue contains 'important']"},

        # Type actions
        {"intent": "Type 'Hello World' into the text field", "action": "type", "selector": "AXTextField[@AXTitle='Input']", "value": "Hello World"},
        {"intent": "Type a URL into the address bar", "action": "type", "selector": "AXTextField[@AXSubrole='AXSearchField']", "value": "https://developer.apple.com"},
        {"intent": "Type a search query", "action": "type", "selector": "AXTextField[@AXSubrole='AXSearchField']", "value": "SwiftUI tutorials"},

        # Key presses with modifiers
        {"intent": "Save the file", "action": "key", "selector": "", "value": "s", "modifiers": ["cmd"]},
        {"intent": "Undo the last action", "action": "key", "selector": "", "value": "z", "modifiers": ["cmd"]},
        {"intent": "Redo", "action": "key", "selector": "", "value": "z", "modifiers": ["cmd", "shift"]},
        {"intent": "Select all", "action": "key", "selector": "", "value": "a", "modifiers": ["cmd"]},
        {"intent": "Copy", "action": "key", "selector": "", "value": "c", "modifiers": ["cmd"]},
        {"intent": "Paste", "action": "key", "selector": "", "value": "v", "modifiers": ["cmd"]},
        {"intent": "Cut", "action": "key", "selector": "", "value": "x", "modifiers": ["cmd"]},
        {"intent": "Find text", "action": "key", "selector": "", "value": "f", "modifiers": ["cmd"]},
        {"intent": "Close the window", "action": "key", "selector": "", "value": "w", "modifiers": ["cmd"]},
        {"intent": "Close the tab", "action": "key", "selector": "", "value": "w", "modifiers": ["cmd"]},
        {"intent": "Quit the app", "action": "key", "selector": "", "value": "q", "modifiers": ["cmd"]},
        {"intent": "New document", "action": "key", "selector": "", "value": "n", "modifiers": ["cmd"]},
        {"intent": "New tab", "action": "key", "selector": "", "value": "t", "modifiers": ["cmd"]},
        {"intent": "Open file", "action": "key", "selector": "", "value": "o", "modifiers": ["cmd"]},
        {"intent": "Print", "action": "key", "selector": "", "value": "p", "modifiers": ["cmd"]},
        {"intent": "Bold the selected text", "action": "key", "selector": "", "value": "b", "modifiers": ["cmd"]},
        {"intent": "Italic", "action": "key", "selector": "", "value": "i", "modifiers": ["cmd"]},
        {"intent": "Open Spotlight search", "action": "key", "selector": "", "value": "space", "modifiers": ["cmd"]},
        {"intent": "Switch to next app", "action": "key", "selector": "", "value": "tab", "modifiers": ["cmd"]},
        {"intent": "Force quit dialog", "action": "key", "selector": "", "value": "escape", "modifiers": ["cmd", "alt"]},
        {"intent": "Screenshot entire screen", "action": "key", "selector": "", "value": "3", "modifiers": ["cmd", "shift"]},
        {"intent": "Screenshot selection", "action": "key", "selector": "", "value": "4", "modifiers": ["cmd", "shift"]},
        {"intent": "Screenshot toolbar", "action": "key", "selector": "", "value": "5", "modifiers": ["cmd", "shift"]},
        {"intent": "Lock screen", "action": "key", "selector": "", "value": "q", "modifiers": ["cmd", "ctrl"]},
        {"intent": "Show desktop", "action": "key", "selector": "", "value": "f11"},
        {"intent": "Mission Control", "action": "key", "selector": "", "value": "up", "modifiers": ["ctrl"]},
        {"intent": "Move to next Space", "action": "key", "selector": "", "value": "right", "modifiers": ["ctrl"]},
        {"intent": "Move to previous Space", "action": "key", "selector": "", "value": "left", "modifiers": ["ctrl"]},
        {"intent": "Press Enter to confirm", "action": "key", "selector": "", "value": "return"},
        {"intent": "Press Escape to cancel", "action": "key", "selector": "", "value": "escape"},
        {"intent": "Press Tab to move to next field", "action": "key", "selector": "", "value": "tab"},
        {"intent": "Press Delete to remove", "action": "key", "selector": "", "value": "delete"},
        {"intent": "Move cursor down", "action": "key", "selector": "", "value": "down"},
        {"intent": "Move cursor up", "action": "key", "selector": "", "value": "up"},

        # Scroll
        {"intent": "Scroll down in the document", "action": "scroll", "selector": "AXScrollArea", "value": "down:3"},
        {"intent": "Scroll up to the top", "action": "scroll", "selector": "AXScrollArea", "value": "up:10"},
        {"intent": "Scroll right", "action": "scroll", "selector": "AXScrollArea", "value": "right:3"},

        # Focus
        {"intent": "Focus on the search field", "action": "focus", "selector": "AXTextField[@AXSubrole='AXSearchField']"},
        {"intent": "Focus on the text editor", "action": "focus", "selector": "AXTextArea[@AXRole='AXTextArea']"},

        # Shortcuts
        {"intent": "Run my 'Toggle Dark Mode' shortcut", "action": "shortcut", "selector": "run_shortcut", "value": "Toggle Dark Mode"},
        {"intent": "Run the 'Screenshot to Clipboard' shortcut", "action": "shortcut", "selector": "run_shortcut", "value": "Screenshot to Clipboard"},
    ]

    for a in ACTIONS:
        axpress = {"action": a["action"], "selector": a["selector"]}
        if "value" in a:
            axpress["value"] = a["value"]
        if "modifiers" in a:
            axpress["modifiers"] = a["modifiers"]

        think = f"The user wants to {a['intent'].lower()}. "
        if a["action"] == "key" and "modifiers" in a:
            think += f"I'll use the keyboard shortcut {'+'.join(a['modifiers'])}+{a.get('value','')}."
        elif a["action"] == "click":
            think += f"I'll click the element matching selector: {a['selector']}."
        elif a["action"] == "type":
            think += f"I'll type '{a.get('value','')}' into the focused field."
        else:
            think += f"I'll perform a {a['action']} action."

        examples.append({
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": a["intent"]},
                {"role": "assistant", "content": f"<think>\n{think}\n</think>\n\n{json.dumps(axpress)}"}
            ],
            "category": "axpress_schema",
            "layer": 10
        })

    return examples


# ─── Code-Grounded Trajectories ────────────────────────────────

def generate_code_grounded_examples() -> List[dict]:
    """Fuse source code knowledge with UI interaction understanding."""
    examples = []

    CODE_GROUNDINGS = [
        {
            "user": "What happens when I click 'New Note' in Epistemos?",
            "think": "I know the Epistemos codebase. The 'New Note' button triggers a flow through multiple files. Let me trace the code path.",
            "response": """<think>
Tracing the code path for 'New Note' button:
1. `NotesSidebar.swift` has the New Note button that calls `createNewNote()`
2. This calls `VaultSyncService.createPage()` which creates an `SDPage` model
3. `SDPage.swift` defines the SwiftData model with title, body, timestamps
4. The model context saves, triggering `@Query` to refresh the notes list
5. `NoteTabView` opens with the new page, loading `ProseEditorView`
6. `ProseEditorRepresentable2` creates the NSTextView bridge for editing
7. The title field gets focus automatically via `becomeFirstResponder()`
</think>

When you click 'New Note':
- **UI**: `NotesSidebar.swift` → button action
- **State**: `VaultSyncService.createPage()` → creates `SDPage` in SwiftData
- **Navigation**: Opens `NoteTabView` → `ProseEditorView` → `ProseEditorRepresentable2`
- **Focus**: Title field gets keyboard focus via `ProseTextView2.becomeFirstResponder()`

The note is immediately persisted to SwiftData and marked for vault sync."""
        },
        {
            "user": "How does the AI chat work in the note editor?",
            "think": "I need to trace the AI chat pipeline from user input to response display.",
            "response": """<think>
Tracing the AI chat pipeline:
1. User types in `NoteChatSidebar.swift` input field and presses Enter
2. `NoteChatState.submitQuery()` is called — this is in `State/NoteChatState.swift`
3. Query goes to `TriageService.swift` which routes based on operation complexity
4. For chat queries, it routes to local Qwen model via `LLMService.swift`
5. Tokens stream back via `PipelineService.swift` with 60ms buffering
6. `NoteChatState.appendStreamingText()` buffers tokens
7. `flushTokens()` fires every 60ms, calling `onTokenFlush` callback
8. `Coordinator2.flushNoteChatTokens()` inserts text into NSTextStorage below the --- divider
9. `isFlushingTokens` flag prevents binding cascade during insertion
10. When done, Accept/Discard buttons appear above the divider
</think>

The AI chat pipeline:
- **Input**: `NoteChatSidebar.swift` → `NoteChatState.submitQuery()`
- **Routing**: `TriageService.swift` → complexity-based routing to local Qwen
- **Streaming**: `PipelineService.swift` → 60ms token buffering → `flushTokens()`
- **Display**: `Coordinator2.flushNoteChatTokens()` → NSTextStorage below `---` divider
- **Guard**: `isFlushingTokens` flag prevents binding cascade during insertion
- **Completion**: Accept merges inline, Discard removes from divider onward"""
        },
        {
            "user": "What's the graph engine architecture?",
            "think": "I know the graph engine is in Rust with Swift FFI bridge. Let me explain the full architecture.",
            "response": """<think>
The graph engine architecture:
1. Core: `graph-engine/src/lib.rs` — Rust implementation
2. Storage: `GraphStore.swift` — compact Int-indexed arrays for O(1) adjacency
   - `_nodeIdx: [String: Int]` — node ID → stable index
   - `_neighbors: [[Int]]` — adjacency lists
   - `_trigramIdx: [String: [Int]]` — trigram posting lists for fuzzy search
3. State: `GraphState.swift` — FFI bridge with `engineHandle: OpaquePointer?`
   - `pendingNodes` / `pendingEdges` queued for incremental FFI updates
   - Drained in render loop
4. Rendering: `MetalGraphView.swift` → Metal compute shaders
5. Overlay: `HologramController.swift` → `HologramOverlay.swift`
6. Physics: `graph-engine/src/physics.rs` — force-directed layout
7. Types: `graph-engine/src/types.rs` — FFI-compatible C structs
</think>

The graph engine is a Rust + Metal hybrid:
- **Rust core**: `graph-engine/src/lib.rs` with `physics.rs`, `renderer.rs`, `types.rs`
- **Swift bridge**: `GraphState.swift` — FFI via `OpaquePointer`, queues mutations as `pendingNodes`/`pendingEdges`
- **Storage**: `GraphStore.swift` — Int-indexed arrays, O(1) adjacency, trigram fuzzy search
- **Rendering**: Metal compute shaders via `MetalGraphView.swift`
- **Node types**: Note(0), Chat(1), Idea(2), Source(3), Folder(4), Quote(5), Tag(6), Block(7)
- **Edge types**: 12 types including reference, semantic, questions"""
        },
        {
            "user": "Explain the binding cascade bug and how it's prevented",
            "think": "This is a critical anti-pattern documented in CLAUDE.md. Let me explain the exact code path.",
            "response": """<think>
The Binding Cascade — a critical anti-pattern:
1. Coordinator writes `parent.text = tv.string` after every keystroke
2. SwiftUI `onChange(of: text)` fires
3. Handler sets `page.needsVaultSync = true`
4. `@Query` refetches all pages matching the predicate
5. `NoteTabView` body re-evaluates
6. `loadBody()` is called — this reads from DISK on every re-evaluation
7. `updateNSView` fires — text sync races with the next keystroke callback
8. Infinite loop: keystroke → sync → refetch → re-evaluate → sync → ...
</think>

The Binding Cascade:
- **Trigger**: `Coordinator2` writes `parent.text` on every keystroke
- **Chain**: `onChange` → `needsVaultSync = true` → `@Query` refetch → body re-eval → `loadBody()` (disk read!) → `updateNSView` → race condition
- **Fix**: Debounce binding sync to 300ms in `Coordinator2.textDidChange()`
- **Guard**: `isFlushingTokens` flag suppresses sync during AI streaming
- **Rule**: Never call `loadBody()` in SwiftUI view body — it's a disk read per re-evaluation
- **Rule**: Never set `needsVaultSync` during streaming — causes `@Query` refetch cascade"""
        },
    ]

    for cg in CODE_GROUNDINGS:
        examples.append({
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": cg["user"]},
                {"role": "assistant", "content": cg["response"]}
            ],
            "category": "code_grounded",
            "layer": 11
        })

    return examples


# ─── macOS System Knowledge ────────────────────────────────────

def generate_macos_system_knowledge() -> List[dict]:
    """Deep macOS system knowledge for the device agent."""
    examples = []

    KNOWLEDGE = [
        ("What are all the modifier keys on macOS?",
         "macOS modifier keys:\n- **⌘ Command (Cmd)**: Primary modifier for shortcuts (Cmd+C, Cmd+V)\n- **⇧ Shift**: Uppercase, extend selection, secondary shortcuts\n- **⌥ Option (Alt)**: Special characters, alternative actions\n- **⌃ Control (Ctrl)**: Terminal shortcuts, right-click (Ctrl+Click)\n- **Fn (Function)**: F-key toggle, special characters, globe key for dictation\n- **⇪ Caps Lock**: Can be remapped to Escape or Ctrl in System Settings"),

        ("How do I manage windows on macOS without a mouse?",
         "Window management keyboard shortcuts:\n- **Cmd+Tab**: Switch apps\n- **Cmd+`**: Switch windows within same app\n- **Cmd+M**: Minimize\n- **Cmd+W**: Close window\n- **Cmd+Q**: Quit app\n- **Ctrl+↑**: Mission Control\n- **Ctrl+←/→**: Switch Spaces\n- **Cmd+F**: Fullscreen toggle (in supported apps)\n- **Fn+F**: Fullscreen (macOS Tahoe)\n- **Cmd+Option+D**: Toggle Dock auto-hide"),

        ("What accessibility APIs does macOS provide?",
         "macOS Accessibility APIs:\n1. **AXUIElement** (C API): Core accessibility interface. `AXUIElementCreateApplication(pid)` creates app reference. `AXUIElementCopyAttributeValue` reads properties. `AXUIElementPerformAction` triggers actions.\n2. **AXObserver**: Event-driven callbacks for UI changes (`kAXFocusedUIElementChangedNotification`, etc.)\n3. **CGEvent**: Low-level input simulation — mouse clicks, key presses, scroll events\n4. **NSAccessibility** (AppKit): Objective-C/Swift wrapper for AX attributes\n5. **VoiceOver API**: Screen reader integration\n6. **Accessibility Inspector**: Debug tool for examining AX trees\n\nPermission required: System Settings → Privacy & Security → Accessibility"),

        ("What are the common AX roles in macOS?",
         "Common AXRole values:\n- **AXApplication**: Top-level app element\n- **AXWindow**: App window\n- **AXButton**: Clickable button\n- **AXTextField**: Single-line text input\n- **AXTextArea**: Multi-line text area\n- **AXStaticText**: Read-only text label\n- **AXCheckBox**: Toggle checkbox\n- **AXRadioButton**: Radio selection\n- **AXSlider**: Value slider\n- **AXMenuItem**: Menu bar item\n- **AXMenuButton**: Dropdown menu trigger\n- **AXPopUpButton**: Popup menu\n- **AXComboBox**: Editable dropdown\n- **AXTable/AXOutline**: Data tables/tree views\n- **AXTabGroup**: Tab container\n- **AXScrollArea**: Scrollable region\n- **AXGroup**: Generic container\n- **AXDisclosureTriangle**: Expand/collapse toggle\n- **AXToolbar**: Toolbar container"),

        ("How does CGEvent input simulation work?",
         "CGEvent input simulation:\n\n**Mouse clicks:**\n```\nCGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x, y), mouseButton: .left)\n```\n\n**Key presses:**\n```\nCGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)\nevent.flags = [.maskCommand]  // for Cmd modifier\n```\n\n**Key codes:** Return=36, Tab=48, Space=49, Delete=51, Escape=53, Up=126, Down=125, Left=123, Right=124\n\n**Modifier flags:** Shift=131072, Cmd=1048576, Alt/Option=524288, Ctrl=262144\n\n**Scroll events:**\n```\nCGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: deltaY)\n```\n\nAll events posted via `event.post(tap: .cghidEventTap)`"),

        ("What is the TCC (Transparency, Consent, and Control) system?",
         "TCC controls app permissions on macOS:\n- **Accessibility**: Required for AXUIElement API and CGEvent simulation\n- **Screen Recording**: Required for ScreenCaptureKit\n- **Full Disk Access**: Required for reading files outside sandbox\n- **Automation**: Required for controlling other apps via AppleScript\n- **Input Monitoring**: Required for CGEvent tap (key logging)\n\nTCC database: `~/Library/Application Support/com.apple.TCC/TCC.db`\nSystem-level: `/Library/Application Support/com.apple.TCC/TCC.db`\n\nApps request via Info.plist keys: `NSAccessibilityUsageDescription`, `NSScreenCaptureUsageDescription`\n\nUser grants via: System Settings → Privacy & Security → [Category]"),
    ]

    for question, answer in KNOWLEDGE:
        examples.append({
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": question},
                {"role": "assistant", "content": f"<think>\nThe user is asking about macOS system knowledge. I'll provide a comprehensive technical answer.\n</think>\n\n{answer}"}
            ],
            "category": "macos_knowledge",
            "layer": 12
        })

    return examples


# ─── Error Diagnosis Chains ────────────────────────────────────

def generate_error_diagnosis_chains() -> List[dict]:
    """Detailed error diagnosis with reasoning about what went wrong and why."""
    examples = []

    DIAGNOSES = [
        {
            "error": "AXError: kAXErrorCannotComplete when trying to click 'Save' button in TextEdit",
            "diagnosis": """<think>
kAXErrorCannotComplete means the AX API couldn't perform the requested action. Common causes:
1. The element exists but is disabled (grayed out)
2. The element is behind a modal sheet/dialog
3. The app is in a state where the action is invalid
4. The element moved or was removed between tree capture and action

Let me reason about this specific case: clicking Save in TextEdit.
- If the document has no changes, Save might be disabled
- If a print dialog is open, the Save button is behind a modal
- If the app just launched and hasn't finished loading, timing issue

Recovery plan:
1. Check if element is enabled: read AXEnabled attribute
2. If disabled, check if document has unsaved changes
3. If modal is blocking, dismiss it first
4. If timing, wait and retry
</think>

**Diagnosis:** `kAXErrorCannotComplete` — the Save button exists but cannot be activated.

**Most likely causes:**
1. Document has no unsaved changes (Save is disabled)
2. A modal dialog is blocking interaction
3. Stale AX tree reference (element moved)

**Recovery actions:**
""" + json.dumps([
                {"action": "focus", "selector": "AXApplication[@AXTitle='TextEdit']"},
                {"action": "key", "selector": "", "value": "escape"},
                {"action": "key", "selector": "", "value": "s", "modifiers": ["cmd"]}
            ], indent=2)
        },
        {
            "error": "Element 'Submit' not found. Available: ['OK', 'Cancel', 'Don\\'t Save', 'Save']",
            "diagnosis": """<think>
The user asked to click 'Submit' but no element with that title exists. The available buttons suggest this is a save dialog (OK, Cancel, Don't Save, Save). The user likely meant 'Save' or 'OK'.

I should not guess — I should clarify. But if this is an automated workflow, 'Save' is the most likely intended target since it's the positive action in a save dialog.

Recovery: Click 'Save' as the closest match to 'Submit'.
</think>

**Diagnosis:** Element 'Submit' doesn't exist in this dialog. This appears to be a macOS save confirmation sheet.

**Available actions match:** 'Save' is the positive confirmation action, likely what was intended.

**Recovery:**
""" + json.dumps({"action": "click", "selector": "AXButton[@AXTitle='Save']"})
        },
        {
            "error": "Timeout: Element 'AI Response' did not appear within 30 seconds",
            "diagnosis": """<think>
The AI response didn't appear within the timeout. Possible causes:
1. The LLM service crashed or is unresponsive
2. The query was too complex for the local model
3. Network issue if using cloud fallback (but Epistemos is local-first)
4. The note chat state is in an invalid state (e.g., isStreaming stuck true)
5. Memory pressure caused the model to be evicted

Let me check what to do:
- First, check if streaming is still in progress (just slow)
- If not, the service may need to be restarted
- Check macOS Console for Epistemos errors
</think>

**Diagnosis:** AI response timeout. The local LLM may be overloaded, crashed, or the query was too complex.

**Recovery steps:**
1. Check if streaming is still active (might just be slow)
2. If stuck, discard and retry with a simpler query
3. Check memory pressure — the model may have been evicted

""" + json.dumps([
                {"action": "click", "selector": "AXButton[@AXTitle='Discard AI Response']"},
                {"action": "type", "selector": "AXTextField[@AXSubrole='AXSearchField']", "value": "Briefly summarize this note"},
                {"action": "key", "selector": "", "value": "return"}
            ], indent=2)
        },
    ]

    for d in DIAGNOSES:
        examples.append({
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"Error: {d['error']}"},
                {"role": "assistant", "content": d["diagnosis"]}
            ],
            "category": "error_diagnosis",
            "layer": 15
        })

    return examples


# ─── Main ───────────────────────────────────────────────────────

def write_jsonl(examples, output_dir, filename):
    os.makedirs(output_dir, exist_ok=True)
    seen = set()
    written = 0
    path = os.path.join(output_dir, filename)
    with open(path, 'w', encoding='utf-8') as f:
        for ex in examples:
            h = hashlib.sha256(json.dumps(ex["messages"], sort_keys=True).encode()).hexdigest()
            if h in seen:
                continue
            seen.add(h)
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")
            written += 1
    print(f"  Written: {path} ({written} examples, {os.path.getsize(path)/1024:.1f} KB)")
    return written


def main():
    parser = argparse.ArgumentParser(description="Advanced Training Data Generator")
    parser.add_argument("--output", default="./epistemos_training_data")
    args = parser.parse_args()

    print(f"\n{'='*60}")
    print(f"  Advanced Training Data Generator")
    print(f"  Output: {args.output}")
    print(f"{'='*60}\n")

    total = 0
    all_examples = []

    print("Layer 8: Reasoning Chains...")
    ex = generate_reasoning_chains()
    total += write_jsonl(ex, args.output, "08_reasoning_chains.jsonl")
    all_examples.extend(ex)

    print("Layer 9: Scroll/Gesture Matrix...")
    ex = generate_scroll_gesture_matrix()
    total += write_jsonl(ex, args.output, "09_scroll_gesture.jsonl")
    all_examples.extend(ex)

    print("Layer 10: AXPress Schema Examples...")
    ex = generate_axpress_schema_examples()
    total += write_jsonl(ex, args.output, "10_axpress_schema.jsonl")
    all_examples.extend(ex)

    print("Layer 11: Code-Grounded Trajectories...")
    ex = generate_code_grounded_examples()
    total += write_jsonl(ex, args.output, "11_code_grounded.jsonl")
    all_examples.extend(ex)

    print("Layer 12: macOS System Knowledge...")
    ex = generate_macos_system_knowledge()
    total += write_jsonl(ex, args.output, "12_macos_knowledge.jsonl")
    all_examples.extend(ex)

    print("Layer 15: Error Diagnosis Chains...")
    ex = generate_error_diagnosis_chains()
    total += write_jsonl(ex, args.output, "15_error_diagnosis.jsonl")
    all_examples.extend(ex)

    # Append to existing train/eval if present
    train_path = os.path.join(args.output, "train.jsonl")
    eval_path = os.path.join(args.output, "eval.jsonl")

    random.seed(42)
    random.shuffle(all_examples)
    split = int(len(all_examples) * 0.9)

    with open(train_path, 'a', encoding='utf-8') as f:
        for ex in all_examples[:split]:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")

    with open(eval_path, 'a', encoding='utf-8') as f:
        for ex in all_examples[split:]:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")

    print(f"\n  TOTAL NEW: {total} examples")
    print(f"  Appended {split} to train.jsonl, {len(all_examples)-split} to eval.jsonl")

    # Count totals
    train_count = sum(1 for _ in open(train_path))
    eval_count = sum(1 for _ in open(eval_path))
    print(f"  Combined train: {train_count} | eval: {eval_count}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
