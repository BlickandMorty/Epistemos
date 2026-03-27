#!/usr/bin/env python3
"""
Epistemos Training Data Generator — The 4 Layers of App Self-Knowledge
=======================================================================

Generates comprehensive training data for the Epistemos device agent model.
This is the sacred 20% that makes it YOUR model, not a generic one.

4 Layers:
  1. Code Graph Model (CGM)     — Understands the codebase structure
  2. Symbol QA                  — Answers questions about any symbol/file/pattern
  3. AX Atlas                   — Deep knowledge of every UI element in every state
  4. Action Trajectories        — Multi-step workflows through the app + macOS

Also generates:
  5. Comprehensive macOS tool-calling examples (50+ tools)
  6. Negative examples (when NOT to call a tool)
  7. Error recovery examples (what to do when actions fail)
  8. Multi-app workflow examples (cross-app automation)

Output: JSONL files in chat format for SFT training.
Run on macOS (needs access to codebase + accessibility APIs).

Usage:
    python generate_epistemos_training_data.py --output ./epistemos_training_data
    python generate_epistemos_training_data.py --output ./epistemos_training_data --layer all
    python generate_epistemos_training_data.py --output ./epistemos_training_data --layer ax_atlas --capture-live
"""

import argparse
import json
import os
import re
import hashlib
import random
import subprocess
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Optional, Tuple

# ─── Configuration ──────────────────────────────────────────────

EPISTEMOS_ROOT = os.environ.get("EPISTEMOS_ROOT", os.path.expanduser("~/Downloads/Epistemos"))
SWIFT_EXTENSIONS = {".swift"}
RUST_EXTENSIONS = {".rs"}
CODE_EXTENSIONS = SWIFT_EXTENSIONS | RUST_EXTENSIONS | {".py", ".h", ".metal"}

SYSTEM_PROMPT_DEVICE_AGENT = """You are Epistemos-Nano, a 1B parameter on-device AI agent for macOS.
You control the Epistemos app and macOS system through accessibility APIs and tool calls.
You understand the app's codebase, UI structure, and every possible user interaction.
You output structured JSON tool calls. You verify actions through perception loops.
You know when NOT to call a tool. You handle errors gracefully."""

SYSTEM_PROMPT_APP_EXPERT = """You are Epistemos-Nano, an AI that deeply understands the Epistemos app.
You know every view, every state class, every service, every model, every modifier.
You can explain any part of the codebase, trace any data flow, and predict any behavior.
You answer questions about the app with precision and cite specific files/lines."""

# ─── Data Structures ────────────────────────────────────────────

@dataclass
class TrainingExample:
    messages: List[Dict[str, str]]
    category: str  # code_graph | symbol_qa | ax_atlas | trajectory | tool_call | negative | error_recovery
    layer: int     # 1-4 for app layers, 5-7 for supplementary
    quality_score: float = 1.0

    def to_jsonl(self) -> str:
        return json.dumps({"messages": self.messages, "category": self.category,
                           "layer": self.layer, "quality": self.quality_score}, ensure_ascii=False)

@dataclass
class CodeFile:
    path: str
    relative_path: str
    content: str
    language: str
    classes: List[str] = field(default_factory=list)
    functions: List[str] = field(default_factory=list)
    protocols: List[str] = field(default_factory=list)
    imports: List[str] = field(default_factory=list)
    subsystem: str = ""

@dataclass
class UIElement:
    role: str
    title: str
    description: str
    position: Tuple[float, float]
    size: Tuple[float, float]
    is_interactive: bool
    children: List["UIElement"] = field(default_factory=list)
    parent_role: str = ""

# ─── TOOL DEFINITIONS — Comprehensive macOS Automation ──────────

COMPREHENSIVE_TOOLS = {
    # ─── Epistemos App Tools ────────────────────────────
    "create_note": {
        "description": "Create a new Epistemos note with title and optional body",
        "arguments": {"title": "string (required)", "body": "string (optional)", "folder": "string (optional)"},
        "agent": "notes", "risk": "low",
        "examples": [
            {"title": "Meeting Notes 2026-03-27", "body": "# Attendees\n- Alice\n- Bob"},
            {"title": "Quick Thought", "body": "What if we used CRDT for real-time sync?"},
        ]
    },
    "edit_note": {
        "description": "Edit an existing Epistemos note by ID",
        "arguments": {"id": "string (required, UUID)", "body": "string (required)"},
        "agent": "notes", "risk": "medium",
        "examples": [{"id": "550e8400-e29b-41d4-a716-446655440000", "body": "Updated content here"}]
    },
    "search_notes": {
        "description": "Full-text search across all Epistemos notes",
        "arguments": {"query": "string (required)"},
        "agent": "notes", "risk": "low",
        "examples": [{"query": "MOHAWK training"}, {"query": "graph engine performance"}]
    },
    "list_notes": {
        "description": "List all notes, optionally filtered by folder",
        "arguments": {"folder": "string (optional)"},
        "agent": "notes", "risk": "low",
        "examples": [{"folder": "Research"}, {}]
    },
    # ─── File System Tools ──────────────────────────────
    "read_file": {
        "description": "Read contents of a file from the vault",
        "arguments": {"path": "string (required, relative to vault)"},
        "agent": "file", "risk": "low",
        "examples": [{"path": "notes/ideas.md"}, {"path": "config.json"}]
    },
    "write_file": {
        "description": "Write content to a file in the vault",
        "arguments": {"path": "string (required)", "content": "string (required)"},
        "agent": "file", "risk": "medium",
        "examples": [{"path": "notes/new.md", "content": "# New Note\nContent here"}]
    },
    "list_files": {
        "description": "List files in a vault directory",
        "arguments": {"path": "string (optional, defaults to root)"},
        "agent": "file", "risk": "low",
        "examples": [{"path": "."}, {"path": "notes/"}]
    },
    "move_file": {
        "description": "Move or rename a file within the vault",
        "arguments": {"path": "string (required)", "destination": "string (required)"},
        "agent": "file", "risk": "medium",
        "examples": [{"path": "draft.md", "destination": "published/final.md"}]
    },
    "delete_file": {
        "description": "Delete a file from the vault (destructive, requires confirmation)",
        "arguments": {"path": "string (required)"},
        "agent": "file", "risk": "critical",
        "examples": [{"path": "temp/scratch.md"}]
    },
    "create_folder": {
        "description": "Create a new folder in the vault",
        "arguments": {"path": "string (required)"},
        "agent": "file", "risk": "low",
        "examples": [{"path": "projects/new-project"}]
    },
    "get_file_info": {
        "description": "Get metadata about a file (size, dates, type)",
        "arguments": {"path": "string (required)"},
        "agent": "file", "risk": "low",
        "examples": [{"path": "notes/important.md"}]
    },
    # ─── Safari / Browser Tools ─────────────────────────
    "open_url": {
        "description": "Open a URL in Safari",
        "arguments": {"url": "string (required)"},
        "agent": "safari", "risk": "low",
        "examples": [{"url": "https://developer.apple.com/documentation"}, {"url": "https://github.com"}]
    },
    "get_page_url": {
        "description": "Get the URL of Safari's current active tab",
        "arguments": {},
        "agent": "safari", "risk": "low", "examples": [{}]
    },
    "get_page_title": {
        "description": "Get the title of Safari's current active tab",
        "arguments": {},
        "agent": "safari", "risk": "low", "examples": [{}]
    },
    "search_web": {
        "description": "Search the web via Google in Safari",
        "arguments": {"query": "string (required)"},
        "agent": "safari", "risk": "low",
        "examples": [{"query": "SwiftUI Observable macro"}, {"query": "Mamba-2 SSM architecture"}]
    },
    "get_page_text": {
        "description": "Extract visible text content from the current Safari page",
        "arguments": {"max_length": "int (optional, default 5000)"},
        "agent": "safari", "risk": "low",
        "examples": [{"max_length": 2000}, {}]
    },
    "click_link": {
        "description": "Click a link on the current page by its text or partial text",
        "arguments": {"text": "string (required)", "index": "int (optional, if multiple matches)"},
        "agent": "safari", "risk": "low",
        "examples": [{"text": "Documentation"}, {"text": "Next", "index": 0}]
    },
    "fill_form_field": {
        "description": "Fill a form field on the current page by label or placeholder",
        "arguments": {"field": "string (required, label or placeholder)", "value": "string (required)"},
        "agent": "safari", "risk": "medium",
        "examples": [{"field": "Search", "value": "SwiftUI tutorials"}, {"field": "Email", "value": "user@example.com"}]
    },
    "switch_tab": {
        "description": "Switch to a Safari tab by index or title",
        "arguments": {"index": "int (optional)", "title": "string (optional)"},
        "agent": "safari", "risk": "low",
        "examples": [{"index": 0}, {"title": "GitHub"}]
    },
    "new_tab": {
        "description": "Open a new Safari tab, optionally with a URL",
        "arguments": {"url": "string (optional)"},
        "agent": "safari", "risk": "low",
        "examples": [{"url": "https://apple.com"}, {}]
    },
    "close_tab": {
        "description": "Close the current Safari tab",
        "arguments": {},
        "agent": "safari", "risk": "medium",
        "examples": [{}]
    },
    "scroll_page": {
        "description": "Scroll the current page up or down",
        "arguments": {"direction": "string (required: up|down)", "amount": "int (optional, pixels, default 500)"},
        "agent": "safari", "risk": "low",
        "examples": [{"direction": "down", "amount": 1000}, {"direction": "up"}]
    },
    # ─── Terminal Tools ─────────────────────────────────
    "run_command": {
        "description": "Execute a shell command (allow-listed commands only)",
        "arguments": {"command": "string (required)"},
        "agent": "terminal", "risk": "medium",
        "examples": [{"command": "ls -la ~/Documents"}, {"command": "grep -r 'TODO' src/"}]
    },
    # ─── UI Automation Tools (AX + CGEvent) ─────────────
    "get_ui_tree": {
        "description": "Get the accessibility tree for a running application",
        "arguments": {"app": "string (required, app name)", "max_depth": "int (optional, default 10)"},
        "agent": "automation", "risk": "low",
        "examples": [{"app": "Epistemos"}, {"app": "Safari", "max_depth": 5}, {"app": "Finder"}]
    },
    "click_element": {
        "description": "Click a UI element by semantic name, AX selector, or coordinates",
        "arguments": {
            "app": "string (optional, app name for semantic click)",
            "element": "string (optional, element title/label)",
            "selector": "string (optional, AX semantic selector like //AXButton[@AXTitle='OK'])",
            "x": "float (optional, screen x coordinate)",
            "y": "float (optional, screen y coordinate)"
        },
        "agent": "automation", "risk": "medium",
        "examples": [
            {"app": "Epistemos", "element": "New Note"},
            {"app": "Safari", "element": "Address and Search"},
            {"selector": "//AXButton[@AXTitle='Save']"},
            {"x": 500, "y": 300},
        ]
    },
    "double_click_element": {
        "description": "Double-click a UI element (e.g., to open files, select words)",
        "arguments": {"app": "string (optional)", "element": "string (optional)", "x": "float (optional)", "y": "float (optional)"},
        "agent": "automation", "risk": "medium",
        "examples": [{"app": "Finder", "element": "Document.pdf"}, {"x": 400, "y": 200}]
    },
    "right_click_element": {
        "description": "Right-click to open context menu on a UI element",
        "arguments": {"app": "string (optional)", "element": "string (optional)", "x": "float (optional)", "y": "float (optional)"},
        "agent": "automation", "risk": "medium",
        "examples": [{"app": "Finder", "element": "myfile.txt"}, {"x": 600, "y": 350}]
    },
    "type_text": {
        "description": "Type text via simulated keyboard input into the focused element",
        "arguments": {"text": "string (required)"},
        "agent": "automation", "risk": "medium",
        "examples": [{"text": "Hello, world!"}, {"text": "# New Heading\n\nParagraph text here."}]
    },
    "press_key": {
        "description": "Press a key combination (human-readable format)",
        "arguments": {"key": "string (required, e.g. 'cmd+s', 'enter', 'cmd+shift+n', 'escape', 'tab')"},
        "agent": "automation", "risk": "medium",
        "examples": [
            {"key": "cmd+s"}, {"key": "cmd+shift+n"}, {"key": "enter"},
            {"key": "escape"}, {"key": "cmd+a"}, {"key": "cmd+c"}, {"key": "cmd+v"},
            {"key": "cmd+z"}, {"key": "cmd+shift+z"}, {"key": "tab"}, {"key": "cmd+w"},
            {"key": "cmd+q"}, {"key": "cmd+space"}, {"key": "cmd+tab"},
        ]
    },
    "drag_element": {
        "description": "Drag a UI element from one position to another",
        "arguments": {
            "from_x": "float (required)", "from_y": "float (required)",
            "to_x": "float (required)", "to_y": "float (required)",
            "duration": "float (optional, seconds, default 0.5)"
        },
        "agent": "automation", "risk": "medium",
        "examples": [{"from_x": 100, "from_y": 200, "to_x": 500, "to_y": 200, "duration": 0.3}]
    },
    "scroll": {
        "description": "Scroll within an app or view at given coordinates",
        "arguments": {
            "direction": "string (required: up|down|left|right)",
            "amount": "int (optional, scroll ticks, default 3)",
            "x": "float (optional, scroll at position)", "y": "float (optional)"
        },
        "agent": "automation", "risk": "low",
        "examples": [{"direction": "down", "amount": 5}, {"direction": "up", "x": 400, "y": 300}]
    },
    "hover_element": {
        "description": "Move mouse over an element without clicking (for tooltips, menus)",
        "arguments": {"app": "string (optional)", "element": "string (optional)", "x": "float (optional)", "y": "float (optional)"},
        "agent": "automation", "risk": "low",
        "examples": [{"app": "Epistemos", "element": "Graph View"}, {"x": 300, "y": 150}]
    },
    "set_value": {
        "description": "Set the value of a UI element (sliders, steppers, text fields, checkboxes)",
        "arguments": {"app": "string (required)", "element": "string (required)", "value": "string (required)"},
        "agent": "automation", "risk": "medium",
        "examples": [{"app": "System Settings", "element": "Volume", "value": "50"}, {"app": "Epistemos", "element": "Font Size", "value": "14"}]
    },
    "select_menu_item": {
        "description": "Select a menu bar item (File > Save, Edit > Copy, etc.)",
        "arguments": {"app": "string (required)", "menu_path": "string (required, e.g. 'File > Save As...')"},
        "agent": "automation", "risk": "medium",
        "examples": [{"app": "Epistemos", "menu_path": "File > New Note"}, {"app": "Safari", "menu_path": "File > Export as PDF..."}]
    },
    "focus_element": {
        "description": "Set keyboard focus to a specific UI element",
        "arguments": {"app": "string (required)", "element": "string (required)"},
        "agent": "automation", "risk": "low",
        "examples": [{"app": "Epistemos", "element": "Search Field"}, {"app": "Safari", "element": "Address and Search"}]
    },
    "toggle_element": {
        "description": "Toggle a checkbox, switch, or disclosure triangle",
        "arguments": {"app": "string (required)", "element": "string (required)"},
        "agent": "automation", "risk": "medium",
        "examples": [{"app": "System Settings", "element": "Dark Mode"}, {"app": "Epistemos", "element": "Show Graph"}]
    },
    "wait_for_element": {
        "description": "Wait for a UI element to appear (with timeout)",
        "arguments": {"app": "string (required)", "element": "string (required)", "timeout": "float (optional, seconds, default 10)"},
        "agent": "automation", "risk": "low",
        "examples": [{"app": "Epistemos", "element": "AI Response", "timeout": 30}]
    },
    "run_shortcut": {
        "description": "Execute a named macOS Shortcut",
        "arguments": {"name": "string (required)"},
        "agent": "automation", "risk": "medium",
        "examples": [{"name": "Screenshot to Clipboard"}, {"name": "Toggle Dark Mode"}]
    },
    # ─── Window Management Tools ────────────────────────
    "activate_app": {
        "description": "Bring an application to the front, launching if needed",
        "arguments": {"app": "string (required)"},
        "agent": "window", "risk": "low",
        "examples": [{"app": "Epistemos"}, {"app": "Safari"}, {"app": "Finder"}, {"app": "Terminal"}]
    },
    "open_app": {
        "description": "Launch an application by name",
        "arguments": {"app": "string (required)"},
        "agent": "window", "risk": "low",
        "examples": [{"app": "Calendar"}, {"app": "Messages"}, {"app": "Mail"}]
    },
    "quit_app": {
        "description": "Quit an application gracefully",
        "arguments": {"app": "string (required)"},
        "agent": "window", "risk": "medium",
        "examples": [{"app": "TextEdit"}, {"app": "Preview"}]
    },
    "minimize_window": {
        "description": "Minimize the frontmost window of an app",
        "arguments": {"app": "string (optional, defaults to frontmost)"},
        "agent": "window", "risk": "low",
        "examples": [{"app": "Safari"}, {}]
    },
    "maximize_window": {
        "description": "Maximize/zoom the frontmost window of an app",
        "arguments": {"app": "string (optional)"},
        "agent": "window", "risk": "low",
        "examples": [{"app": "Epistemos"}, {}]
    },
    "close_window": {
        "description": "Close the frontmost window of an app",
        "arguments": {"app": "string (optional)"},
        "agent": "window", "risk": "medium",
        "examples": [{"app": "Preview"}, {}]
    },
    "resize_window": {
        "description": "Resize and position a window",
        "arguments": {"app": "string (required)", "x": "int", "y": "int", "width": "int", "height": "int"},
        "agent": "window", "risk": "low",
        "examples": [{"app": "Epistemos", "x": 0, "y": 0, "width": 1200, "height": 800}]
    },
    "fullscreen_toggle": {
        "description": "Toggle fullscreen mode for an app",
        "arguments": {"app": "string (optional)"},
        "agent": "window", "risk": "low",
        "examples": [{"app": "Epistemos"}, {}]
    },
    "get_frontmost_app": {
        "description": "Get the name and PID of the frontmost application",
        "arguments": {},
        "agent": "window", "risk": "low", "examples": [{}]
    },
    "list_running_apps": {
        "description": "List all running applications with their PIDs",
        "arguments": {},
        "agent": "window", "risk": "low", "examples": [{}]
    },
    "list_windows": {
        "description": "List all windows for an app with their titles and positions",
        "arguments": {"app": "string (required)"},
        "agent": "window", "risk": "low",
        "examples": [{"app": "Safari"}, {"app": "Epistemos"}]
    },
    # ─── System Tools ───────────────────────────────────
    "clipboard_read": {
        "description": "Read the current clipboard contents",
        "arguments": {},
        "agent": "system", "risk": "low", "examples": [{}]
    },
    "clipboard_write": {
        "description": "Write text to the clipboard",
        "arguments": {"text": "string (required)"},
        "agent": "system", "risk": "low",
        "examples": [{"text": "Copied content here"}]
    },
    "screenshot": {
        "description": "Take a screenshot of the screen or a specific region",
        "arguments": {"region": "string (optional: full|frontmost|x,y,w,h)"},
        "agent": "system", "risk": "low",
        "examples": [{"region": "full"}, {"region": "frontmost"}, {"region": "100,100,800,600"}]
    },
    "spotlight_search": {
        "description": "Open Spotlight and search for something",
        "arguments": {"query": "string (required)"},
        "agent": "system", "risk": "low",
        "examples": [{"query": "System Settings"}, {"query": "terminal"}]
    },
    "notification_read": {
        "description": "Read recent notifications from Notification Center",
        "arguments": {"app": "string (optional, filter by app)", "limit": "int (optional, default 10)"},
        "agent": "system", "risk": "low",
        "examples": [{"app": "Mail", "limit": 5}, {}]
    },
    "open_system_settings": {
        "description": "Open a specific System Settings pane",
        "arguments": {"pane": "string (required, e.g. 'Privacy & Security', 'Displays', 'Sound')"},
        "agent": "system", "risk": "low",
        "examples": [{"pane": "Accessibility"}, {"pane": "Privacy & Security"}, {"pane": "Displays"}]
    },
    # ─── Graph Tools (Epistemos-specific) ───────────────
    "graph_query": {
        "description": "Query the Epistemos knowledge graph",
        "arguments": {"query": "string (required)", "depth": "int (optional, default 2)"},
        "agent": "graph", "risk": "low",
        "examples": [{"query": "connections to MOHAWK", "depth": 3}]
    },
    "graph_add_node": {
        "description": "Add a node to the knowledge graph",
        "arguments": {"title": "string (required)", "type": "string (required: note|idea|source|tag)", "content": "string (optional)"},
        "agent": "graph", "risk": "medium",
        "examples": [{"title": "New Research Paper", "type": "source", "content": "https://arxiv.org/..."}]
    },
    "graph_add_edge": {
        "description": "Create a connection between two graph nodes",
        "arguments": {"from_id": "string (required)", "to_id": "string (required)", "type": "string (required: reference|semantic|questions)"},
        "agent": "graph", "risk": "medium",
        "examples": [{"from_id": "node-1", "to_id": "node-2", "type": "reference"}]
    },
}

# ─── EPISTEMOS UI VIEWS — Every screen the user can see ─────────

EPISTEMOS_VIEWS = {
    "landing": {
        "file": "Views/Landing/LandingView.swift",
        "description": "The main landing screen with app overview and quick actions",
        "elements": ["Search Field", "New Note Button", "Recent Notes List", "Graph Preview", "Settings Gear"],
        "transitions": {"new_note": "note_editor", "click_note": "note_editor", "graph_preview": "graph_view", "settings": "settings_view"},
    },
    "note_editor": {
        "file": "Views/Notes/ProseEditorView.swift",
        "description": "The rich text note editor with markdown support, AI sidebar, and toolbar",
        "elements": ["Title Field", "Body Editor", "Toolbar", "Bold Button", "Italic Button",
                     "Heading Picker", "AI Chat Sidebar Toggle", "Word Count", "Back Button",
                     "Share Button", "Format Menu", "Insert Link", "Insert Image",
                     "Table Button", "Code Block Button", "Divider", "AI Response Zone"],
        "transitions": {"back": "landing", "ai_sidebar": "note_chat", "graph_icon": "graph_view"},
    },
    "note_chat": {
        "file": "Views/Notes/NoteChatSidebar.swift",
        "description": "AI chat sidebar for the current note — ask questions, get rewrites, summaries",
        "elements": ["Chat Input Field", "Send Button", "Chat History", "Clear Chat Button",
                     "Accept AI Response", "Discard AI Response", "Rewrite Button",
                     "Summarize Button", "Expand Button", "Continue Writing Button"],
        "transitions": {"close": "note_editor", "accept": "note_editor", "discard": "note_editor"},
    },
    "graph_view": {
        "file": "Views/Graph/HologramOverlay.swift",
        "description": "3D knowledge graph visualization with Metal rendering",
        "elements": ["Graph Canvas", "Search Field", "Zoom Slider", "Filter Dropdown",
                     "Node Labels", "Edge Lines", "Reset View Button", "Fullscreen Toggle",
                     "Node Context Menu", "Create Connection Button"],
        "transitions": {"click_node": "note_editor", "search": "graph_view", "back": "landing"},
    },
    "settings_view": {
        "file": "Views/Shell/SettingsView.swift",
        "description": "App settings — AI model selection, vault path, theme, keyboard shortcuts",
        "elements": ["Model Picker", "Vault Path", "Theme Toggle", "Font Size Slider",
                     "Keyboard Shortcuts List", "Reset Defaults Button", "About Section",
                     "Enable Reasoning Loop Toggle", "AI Temperature Slider"],
        "transitions": {"back": "landing", "model_picker": "settings_view"},
    },
    "notes_sidebar": {
        "file": "Views/Notes/NotesSidebar.swift",
        "description": "Left sidebar listing all notes with search, sort, and folder navigation",
        "elements": ["Search Field", "Sort Menu", "Folder Tree", "Note List", "New Note Button",
                     "New Folder Button", "Drag Handle", "Note Context Menu"],
        "transitions": {"click_note": "note_editor", "new_note": "note_editor", "new_folder": "notes_sidebar"},
    },
}

# ─── EPISTEMOS STATE CLASSES — Every observable state ───────────

EPISTEMOS_STATE = {
    "NoteChatState": {
        "file": "State/NoteChatState.swift",
        "properties": ["isStreaming", "messages", "currentQuery", "hasDivider", "lastFlushedTurnCount"],
        "methods": ["submitQuery()", "acceptResponse()", "discardResponse()", "appendStreamingText()", "flushTokens()"],
        "description": "Per-note AI chat state. Manages query→response cycle with 60ms token buffering.",
    },
    "GraphState": {
        "file": "Graph/GraphState.swift",
        "properties": ["engineHandle", "pendingNodes", "pendingEdges", "mode", "selectedNodeId"],
        "methods": ["buildPageSubgraph()", "addNode()", "addEdge()", "removeNode()", "searchNodes()"],
        "description": "FFI bridge to Rust graph engine. Manages graph mutations and rendering state.",
    },
    "PhysicsCoordinator": {
        "file": "Theme/PhysicsModifiers.swift",
        "properties": ["graphHoveredNodeId"],
        "methods": [],
        "description": "Cross-view hover signaling between graph and sidebar. Zero cost when idle.",
    },
}

# ─── KEY CODES — Human-readable to CGEvent mapping ──────────────

KEY_CODES = {
    "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
    "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35,
    "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7,
    "y": 16, "z": 6, "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
    "6": 22, "7": 26, "8": 28, "9": 25, "return": 36, "enter": 36, "tab": 48,
    "space": 49, "delete": 51, "backspace": 51, "escape": 53, "esc": 53,
    "up": 126, "down": 125, "left": 123, "right": 124,
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
    "[": 33, "]": 30, "\\": 42, ";": 41, "'": 39, ",": 43, ".": 47, "/": 44,
    "-": 27, "=": 24, "`": 50,
}

MODIFIER_FLAGS = {
    "shift": 131072, "cmd": 1048576, "command": 1048576, "alt": 524288,
    "option": 524288, "ctrl": 262144, "control": 262144, "fn": 8388608,
}

# ─── LAYER 1: Code Graph Model ─────────────────────────────────

def parse_swift_file(filepath: str) -> CodeFile:
    """Parse a Swift file to extract classes, functions, protocols, imports."""
    with open(filepath, 'r', errors='replace') as f:
        content = f.read()

    rel = os.path.relpath(filepath, EPISTEMOS_ROOT)
    cf = CodeFile(path=filepath, relative_path=rel, content=content, language="swift")

    # Extract classes/structs/enums
    cf.classes = re.findall(r'(?:class|struct|enum|actor)\s+(\w+)', content)
    # Extract functions
    cf.functions = re.findall(r'func\s+(\w+)\s*[\(<]', content)
    # Extract protocols
    cf.protocols = re.findall(r'protocol\s+(\w+)', content)
    # Extract imports
    cf.imports = re.findall(r'import\s+(\w+)', content)

    # Determine subsystem
    if "Views/Notes" in rel: cf.subsystem = "note_editor"
    elif "Views/Graph" in rel: cf.subsystem = "graph"
    elif "Views/Landing" in rel: cf.subsystem = "landing"
    elif "Views/Shell" in rel: cf.subsystem = "shell"
    elif "Views/Chat" in rel: cf.subsystem = "chat"
    elif "State/" in rel: cf.subsystem = "state"
    elif "Engine/" in rel: cf.subsystem = "ai_pipeline"
    elif "Graph/" in rel: cf.subsystem = "graph"
    elif "Models/" in rel: cf.subsystem = "models"
    elif "Sync/" in rel: cf.subsystem = "sync"
    elif "Omega/" in rel: cf.subsystem = "omega"
    elif "Theme/" in rel: cf.subsystem = "theme"
    elif "KnowledgeFusion/" in rel: cf.subsystem = "training"
    elif "App/" in rel: cf.subsystem = "app_bootstrap"
    return cf


def scan_codebase() -> List[CodeFile]:
    """Walk the Epistemos codebase and parse all code files."""
    files = []
    for root, dirs, filenames in os.walk(os.path.join(EPISTEMOS_ROOT, "Epistemos")):
        dirs[:] = [d for d in dirs if d not in {".build", "DerivedData", ".git", "node_modules"}]
        for fn in filenames:
            ext = os.path.splitext(fn)[1]
            if ext in CODE_EXTENSIONS:
                fp = os.path.join(root, fn)
                try:
                    if ext in SWIFT_EXTENSIONS:
                        files.append(parse_swift_file(fp))
                    else:
                        with open(fp, 'r', errors='replace') as f:
                            content = f.read()
                        files.append(CodeFile(path=fp, relative_path=os.path.relpath(fp, EPISTEMOS_ROOT),
                                              content=content, language=ext.strip('.')))
                except Exception as e:
                    print(f"  WARN: {fp}: {e}")
    return files


def generate_code_graph_examples(files: List[CodeFile]) -> List[TrainingExample]:
    """Layer 1: Code Graph Model — teach the model the codebase structure."""
    examples = []

    # File-level understanding
    for f in files:
        if not f.classes and not f.functions:
            continue
        classes_str = ", ".join(f.classes[:5]) if f.classes else "none"
        funcs_str = ", ".join(f.functions[:8]) if f.functions else "none"
        protos_str = ", ".join(f.protocols[:3]) if f.protocols else "none"

        # "What does this file do?"
        examples.append(TrainingExample(
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT_APP_EXPERT},
                {"role": "user", "content": f"What is the purpose of `{f.relative_path}` in the Epistemos codebase?"},
                {"role": "assistant", "content": f"`{f.relative_path}` belongs to the **{f.subsystem}** subsystem. "
                 f"It defines: classes/structs [{classes_str}], key functions [{funcs_str}], "
                 f"protocols [{protos_str}]. Imports: {', '.join(f.imports[:5])}."}
            ],
            category="code_graph", layer=1
        ))

    # Subsystem-level understanding
    subsystems = {}
    for f in files:
        if f.subsystem:
            subsystems.setdefault(f.subsystem, []).append(f)

    for sub, sub_files in subsystems.items():
        all_classes = []
        for sf in sub_files:
            all_classes.extend(sf.classes[:3])
        file_list = ", ".join(f"`{sf.relative_path}`" for sf in sub_files[:6])

        examples.append(TrainingExample(
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT_APP_EXPERT},
                {"role": "user", "content": f"Explain the {sub} subsystem in Epistemos."},
                {"role": "assistant", "content": f"The **{sub}** subsystem contains {len(sub_files)} files: {file_list}. "
                 f"Key types: {', '.join(all_classes[:8])}. "
                 f"This subsystem handles {'AI routing and inference' if sub == 'ai_pipeline' else sub.replace('_', ' ')} functionality."}
            ],
            category="code_graph", layer=1
        ))

    # Cross-file dependency questions
    for f in files:
        if not f.classes:
            continue
        for cls in f.classes[:2]:
            # Find files that reference this class
            refs = [f2 for f2 in files if f2.path != f.path and cls in f2.content]
            if refs:
                ref_paths = ", ".join(f"`{r.relative_path}`" for r in refs[:5])
                examples.append(TrainingExample(
                    messages=[
                        {"role": "system", "content": SYSTEM_PROMPT_APP_EXPERT},
                        {"role": "user", "content": f"Where is `{cls}` used in the Epistemos codebase?"},
                        {"role": "assistant", "content": f"`{cls}` is defined in `{f.relative_path}` and referenced by: {ref_paths}. "
                         f"It's part of the {f.subsystem} subsystem."}
                    ],
                    category="code_graph", layer=1
                ))

    print(f"  Layer 1 (Code Graph): {len(examples)} examples")
    return examples


# ─── LAYER 2: Symbol QA ────────────────────────────────────────

def generate_symbol_qa_examples(files: List[CodeFile]) -> List[TrainingExample]:
    """Layer 2: Symbol QA — answer any question about any symbol."""
    examples = []

    for f in files:
        if f.language != "swift":
            continue

        # Extract function signatures with context
        func_pattern = re.compile(
            r'((?:///[^\n]*\n)*\s*(?:@\w+[^\n]*\n)*\s*(?:public|private|internal|fileprivate)?\s*'
            r'(?:static\s+)?(?:override\s+)?func\s+\w+[^{]*\{)',
            re.MULTILINE
        )
        for match in func_pattern.finditer(f.content):
            sig = match.group(0).strip()
            func_name = re.search(r'func\s+(\w+)', sig)
            if not func_name:
                continue
            name = func_name.group(1)
            if name.startswith("_") or len(name) < 3:
                continue

            # Extract return type if present
            ret = re.search(r'->\s*(\S+)', sig)
            ret_str = f" Returns `{ret.group(1)}`." if ret else ""

            # Extract parameters
            params = re.findall(r'(\w+)\s*:\s*(\w+)', sig)
            params_str = ", ".join(f"`{p}: {t}`" for p, t in params[:5]) if params else "none"

            examples.append(TrainingExample(
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT_APP_EXPERT},
                    {"role": "user", "content": f"What does `{name}()` in `{f.relative_path}` do?"},
                    {"role": "assistant", "content": f"`{name}()` is defined in `{f.relative_path}` ({f.subsystem} subsystem). "
                     f"Parameters: {params_str}.{ret_str} "
                     f"Part of {'`' + f.classes[0] + '`' if f.classes else 'top-level'}."}
                ],
                category="symbol_qa", layer=2
            ))

        # Property questions
        for cls in f.classes[:3]:
            # Find @Observable or @Published properties
            cls_match = re.search(rf'(?:class|struct)\s+{cls}[^{{]*\{{(.*?)(?:func\s|\}})', f.content, re.DOTALL)
            if not cls_match:
                continue
            body = cls_match.group(1)
            props = re.findall(r'(?:var|let)\s+(\w+)\s*[=:]', body)
            if props:
                examples.append(TrainingExample(
                    messages=[
                        {"role": "system", "content": SYSTEM_PROMPT_APP_EXPERT},
                        {"role": "user", "content": f"What state does `{cls}` hold?"},
                        {"role": "assistant", "content": f"`{cls}` in `{f.relative_path}` has properties: {', '.join('`' + p + '`' for p in props[:10])}. "
                         f"It's in the {f.subsystem} subsystem."}
                    ],
                    category="symbol_qa", layer=2
                ))

    print(f"  Layer 2 (Symbol QA): {len(examples)} examples")
    return examples


# ─── LAYER 3: AX Atlas ─────────────────────────────────────────

def generate_ax_atlas_examples() -> List[TrainingExample]:
    """Layer 3: AX Atlas — deep knowledge of every UI element in every view state."""
    examples = []

    # Generate from EPISTEMOS_VIEWS definitions
    for view_name, view_info in EPISTEMOS_VIEWS.items():
        elements = view_info["elements"]
        transitions = view_info["transitions"]

        # "What elements are in this view?"
        examples.append(TrainingExample(
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT_DEVICE_AGENT},
                {"role": "user", "content": f"What UI elements are available in the Epistemos {view_name.replace('_', ' ')} view?"},
                {"role": "assistant", "content": f"The **{view_name.replace('_', ' ')}** view ({view_info['file']}) contains: "
                 f"{', '.join(elements)}. {view_info['description']}"}
            ],
            category="ax_atlas", layer=3
        ))

        # "How do I navigate from X to Y?"
        for action, target in transitions.items():
            target_info = EPISTEMOS_VIEWS.get(target, {})
            examples.append(TrainingExample(
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT_DEVICE_AGENT},
                    {"role": "user", "content": f"How do I navigate from {view_name.replace('_', ' ')} to {target.replace('_', ' ')}?"},
                    {"role": "assistant", "content": f"From **{view_name.replace('_', ' ')}**, "
                     f"perform action '{action.replace('_', ' ')}' to reach **{target.replace('_', ' ')}**. "
                     f"{'Target view has: ' + ', '.join(target_info.get('elements', [])[:5]) if target_info else ''}"}
                ],
                category="ax_atlas", layer=3
            ))

        # Per-element interaction examples
        for elem in elements:
            # What can I do with this element?
            if any(kw in elem.lower() for kw in ["button", "toggle", "gear", "icon"]):
                action_type = "click"
            elif any(kw in elem.lower() for kw in ["field", "input", "search"]):
                action_type = "focus and type"
            elif any(kw in elem.lower() for kw in ["list", "tree", "history"]):
                action_type = "scroll and select"
            elif any(kw in elem.lower() for kw in ["slider", "picker"]):
                action_type = "adjust value"
            elif any(kw in elem.lower() for kw in ["canvas", "preview"]):
                action_type = "interact (click, drag, scroll)"
            else:
                action_type = "interact"

            examples.append(TrainingExample(
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT_DEVICE_AGENT},
                    {"role": "user", "content": f"How do I interact with '{elem}' in {view_name.replace('_', ' ')}?"},
                    {"role": "assistant", "content": json.dumps({
                        "tool": "click_element" if action_type == "click" else
                                "focus_element" if "type" in action_type else
                                "scroll" if "scroll" in action_type else
                                "set_value" if "value" in action_type else "click_element",
                        "arguments": {"app": "Epistemos", "element": elem}
                    })}
                ],
                category="ax_atlas", layer=3
            ))

    # Generate synthetic AX tree examples for common macOS apps
    MACOS_APPS_AX_TEMPLATES = {
        "Finder": {
            "elements": ["Sidebar", "File List", "Path Bar", "Search Field", "View Buttons",
                         "Back Button", "Forward Button", "Action Menu", "Share Button", "Tags"],
            "common_actions": ["open file", "create folder", "rename file", "move to trash",
                              "copy file", "get info", "change view", "search files"],
        },
        "Safari": {
            "elements": ["Address and Search", "Back Button", "Forward Button", "Share Button",
                         "Tab Bar", "Bookmarks Button", "Downloads Button", "New Tab Button",
                         "Reader Mode", "Page Content Area"],
            "common_actions": ["navigate to URL", "search web", "switch tab", "bookmark page",
                              "close tab", "go back", "go forward", "download file"],
        },
        "Mail": {
            "elements": ["Mailbox List", "Message List", "Message Content", "Compose Button",
                         "Reply Button", "Forward Button", "Delete Button", "Search Field",
                         "Flag Button", "Archive Button"],
            "common_actions": ["compose email", "reply to email", "search inbox", "delete email",
                              "flag important", "move to folder", "add attachment"],
        },
        "Calendar": {
            "elements": ["Day View", "Week View", "Month View", "Year View", "Event List",
                         "New Event Button", "Search Field", "Calendar List", "Today Button",
                         "Navigation Arrows"],
            "common_actions": ["create event", "view today", "switch to week view", "search events",
                              "edit event", "delete event", "navigate to date"],
        },
        "Messages": {
            "elements": ["Conversation List", "Message Area", "Input Field", "Send Button",
                         "Attachments Button", "Search Field", "New Message Button",
                         "Contact Info", "Tapback Menu"],
            "common_actions": ["send message", "search conversations", "new conversation",
                              "send image", "react to message", "delete conversation"],
        },
        "Notes": {
            "elements": ["Folder List", "Note List", "Note Editor", "Search Field",
                         "New Note Button", "New Folder Button", "Format Bar",
                         "Checklist Button", "Table Button", "Share Button"],
            "common_actions": ["create note", "search notes", "create folder", "add checklist",
                              "insert table", "share note", "pin note", "lock note"],
        },
        "System Settings": {
            "elements": ["Settings Sidebar", "Search Field", "Content Area", "Toggle Switches",
                         "Sliders", "Dropdown Menus", "Back Button"],
            "common_actions": ["search settings", "toggle feature", "adjust slider",
                              "open specific pane", "change default app"],
        },
        "Terminal": {
            "elements": ["Terminal Window", "Tab Bar", "Input Area", "Scrollback",
                         "New Tab Button", "Profile Selector"],
            "common_actions": ["type command", "new tab", "clear terminal", "search output",
                              "split pane", "change profile"],
        },
    }

    for app_name, app_info in MACOS_APPS_AX_TEMPLATES.items():
        # App overview
        examples.append(TrainingExample(
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT_DEVICE_AGENT},
                {"role": "user", "content": f"What UI elements does {app_name} have?"},
                {"role": "assistant", "content": f"{app_name} has these key UI elements: {', '.join(app_info['elements'])}. "
                 f"Common actions: {', '.join(app_info['common_actions'][:5])}."}
            ],
            category="ax_atlas", layer=3
        ))

        # Action-to-tool mapping for each common action
        for action in app_info["common_actions"]:
            tool_call = _action_to_tool_call(app_name, action, app_info["elements"])
            examples.append(TrainingExample(
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT_DEVICE_AGENT},
                    {"role": "user", "content": f"{action} in {app_name}"},
                    {"role": "assistant", "content": json.dumps(tool_call, indent=2)}
                ],
                category="ax_atlas", layer=3
            ))

    print(f"  Layer 3 (AX Atlas): {len(examples)} examples")
    return examples


def _action_to_tool_call(app: str, action: str, elements: list) -> dict:
    """Map a human-readable action to a structured tool call."""
    action_lower = action.lower()

    if "search" in action_lower:
        field = next((e for e in elements if "search" in e.lower()), "Search Field")
        return {"steps": [
            {"tool": "focus_element", "arguments": {"app": app, "element": field}},
            {"tool": "type_text", "arguments": {"text": "<search query>"}},
            {"tool": "press_key", "arguments": {"key": "enter"}}
        ]}
    elif "open" in action_lower or "navigate" in action_lower:
        if "url" in action_lower:
            return {"tool": "open_url", "arguments": {"url": "<target url>"}}
        return {"tool": "activate_app", "arguments": {"app": app}}
    elif "create" in action_lower or "new" in action_lower or "compose" in action_lower:
        btn = next((e for e in elements if any(kw in e.lower() for kw in ["new", "compose", "create"])), elements[0])
        return {"tool": "click_element", "arguments": {"app": app, "element": btn}}
    elif "delete" in action_lower or "trash" in action_lower:
        return {"steps": [
            {"tool": "click_element", "arguments": {"app": app, "element": "<target item>"}},
            {"tool": "press_key", "arguments": {"key": "cmd+delete"}}
        ]}
    elif "reply" in action_lower or "forward" in action_lower:
        btn = next((e for e in elements if action_lower.split()[0] in e.lower()), elements[0])
        return {"tool": "click_element", "arguments": {"app": app, "element": btn}}
    elif "switch" in action_lower or "change" in action_lower:
        return {"tool": "click_element", "arguments": {"app": app, "element": "<target view/tab>"}}
    elif "send" in action_lower:
        return {"steps": [
            {"tool": "type_text", "arguments": {"text": "<message content>"}},
            {"tool": "press_key", "arguments": {"key": "enter"}}
        ]}
    elif "toggle" in action_lower:
        return {"tool": "toggle_element", "arguments": {"app": app, "element": "<toggle name>"}}
    elif "adjust" in action_lower or "slider" in action_lower:
        return {"tool": "set_value", "arguments": {"app": app, "element": "<slider name>", "value": "<new value>"}}
    elif "close" in action_lower:
        return {"tool": "press_key", "arguments": {"key": "cmd+w"}}
    elif "go back" in action_lower:
        return {"tool": "press_key", "arguments": {"key": "cmd+["}}
    elif "go forward" in action_lower:
        return {"tool": "press_key", "arguments": {"key": "cmd+]"}}
    else:
        return {"tool": "click_element", "arguments": {"app": app, "element": action}}


# ─── LAYER 4: Action Trajectories ──────────────────────────────

def generate_trajectory_examples() -> List[TrainingExample]:
    """Layer 4: Multi-step workflows through Epistemos and macOS."""
    examples = []

    TRAJECTORIES = [
        # ─── Epistemos App Workflows ────────────────────
        {
            "intent": "Create a new note, write some content, and add it to the knowledge graph",
            "steps": [
                {"observe": "Landing view with notes list and graph preview", "decide": "Click New Note to create a note", "tool": "click_element", "args": {"app": "Epistemos", "element": "New Note Button"}, "assess": "Note editor opened with empty title and body"},
                {"observe": "Empty note editor with cursor in title", "decide": "Type the note title", "tool": "type_text", "args": {"text": "Research: Mamba-2 Architecture"}, "assess": "Title field populated"},
                {"observe": "Title filled, cursor needs to move to body", "decide": "Tab to body field", "tool": "press_key", "args": {"key": "tab"}, "assess": "Cursor now in body editor"},
                {"observe": "Body editor focused and empty", "decide": "Type research content", "tool": "type_text", "args": {"text": "# Mamba-2 Architecture\n\nMamba-2 introduces selective state spaces with hardware-aware design.\n\n## Key Innovations\n- Selective scan mechanism\n- Hardware-efficient parallel scan\n- State expansion factor of 16"}, "assess": "Body populated with markdown content"},
                {"observe": "Note has content, needs to be saved", "decide": "Save the note", "tool": "press_key", "args": {"key": "cmd+s"}, "assess": "Note saved, auto-added to knowledge graph"},
            ],
        },
        {
            "intent": "Ask AI to summarize the current note and accept the response",
            "steps": [
                {"observe": "Note editor with existing content", "decide": "Open AI chat sidebar", "tool": "click_element", "args": {"app": "Epistemos", "element": "AI Chat Sidebar Toggle"}, "assess": "Chat sidebar appeared on the right"},
                {"observe": "Chat sidebar open with input field", "decide": "Type summarize request", "tool": "type_text", "args": {"text": "Summarize this note in 3 bullet points"}, "assess": "Query typed in chat input"},
                {"observe": "Query ready to send", "decide": "Send the query", "tool": "press_key", "args": {"key": "enter"}, "assess": "AI is streaming response below the divider"},
                {"observe": "AI response complete, divider visible, Accept/Discard buttons shown", "decide": "Accept the AI response to keep it inline", "tool": "click_element", "args": {"app": "Epistemos", "element": "Accept AI Response"}, "assess": "AI text merged into note body, divider removed"},
            ],
        },
        {
            "intent": "Search for a note and open it in the graph view to see connections",
            "steps": [
                {"observe": "Landing view or any view with sidebar", "decide": "Focus the search field", "tool": "focus_element", "args": {"app": "Epistemos", "element": "Search Field"}, "assess": "Search field focused"},
                {"observe": "Search field ready for input", "decide": "Type search query", "tool": "type_text", "args": {"text": "MOHAWK training"}, "assess": "Search results filtering in real-time"},
                {"observe": "Search results showing matching notes", "decide": "Click the first matching note", "tool": "click_element", "args": {"app": "Epistemos", "element": "MOHAWK Training Notes"}, "assess": "Note opened in editor"},
                {"observe": "Note open in editor", "decide": "Switch to graph view to see connections", "tool": "click_element", "args": {"app": "Epistemos", "element": "Graph View"}, "assess": "Graph view showing note as central node with connections"},
            ],
        },
        {
            "intent": "Right-click on text to use AI rewrite, then discard and try again",
            "steps": [
                {"observe": "Note editor with text content", "decide": "Select the paragraph to rewrite", "tool": "click_element", "args": {"app": "Epistemos", "element": "Body Editor"}, "assess": "Cursor in body"},
                {"observe": "Cursor in body text", "decide": "Select all text in paragraph", "tool": "press_key", "args": {"key": "cmd+a"}, "assess": "Text selected"},
                {"observe": "Text selected, ready for context menu", "decide": "Right-click for AI menu", "tool": "right_click_element", "args": {"app": "Epistemos", "element": "Body Editor"}, "assess": "Context menu appeared with AI options"},
                {"observe": "Context menu showing: Rewrite, Summarize, Expand, Simplify...", "decide": "Select Rewrite", "tool": "click_element", "args": {"app": "Epistemos", "element": "Rewrite"}, "assess": "AI streaming rewrite below divider"},
                {"observe": "AI rewrite complete but not satisfactory", "decide": "Discard and try different approach", "tool": "click_element", "args": {"app": "Epistemos", "element": "Discard AI Response"}, "assess": "AI response removed, original text preserved"},
            ],
        },
        # ─── Cross-App Workflows ────────────────────────
        {
            "intent": "Research a topic in Safari and create an Epistemos note with findings",
            "steps": [
                {"observe": "Epistemos is frontmost", "decide": "Switch to Safari for research", "tool": "activate_app", "args": {"app": "Safari"}, "assess": "Safari brought to front"},
                {"observe": "Safari active", "decide": "Search for the topic", "tool": "search_web", "args": {"query": "Mamba-2 selective state spaces paper 2024"}, "assess": "Google results loaded"},
                {"observe": "Search results page", "decide": "Click the most relevant result", "tool": "click_link", "args": {"text": "Transformers are SSMs"}, "assess": "Paper page loaded"},
                {"observe": "Paper page with content", "decide": "Get the page text for reference", "tool": "get_page_text", "args": {"max_length": 3000}, "assess": "Page text extracted"},
                {"observe": "Have research content", "decide": "Switch back to Epistemos", "tool": "activate_app", "args": {"app": "Epistemos"}, "assess": "Epistemos frontmost"},
                {"observe": "Epistemos landing view", "decide": "Create note with research", "tool": "create_note", "args": {"title": "Research: Mamba-2 SSM Paper", "body": "# Mamba-2 Paper Notes\n\nKey findings from research..."}, "assess": "Note created with research content"},
            ],
        },
        {
            "intent": "Copy text from a note and paste it into a new email in Mail",
            "steps": [
                {"observe": "Epistemos note editor with content", "decide": "Select the text to share", "tool": "press_key", "args": {"key": "cmd+a"}, "assess": "All text selected"},
                {"observe": "Text selected", "decide": "Copy to clipboard", "tool": "press_key", "args": {"key": "cmd+c"}, "assess": "Text copied"},
                {"observe": "Text in clipboard", "decide": "Switch to Mail", "tool": "activate_app", "args": {"app": "Mail"}, "assess": "Mail brought to front"},
                {"observe": "Mail inbox view", "decide": "Create new email", "tool": "click_element", "args": {"app": "Mail", "element": "Compose Button"}, "assess": "New email compose window opened"},
                {"observe": "Empty compose window", "decide": "Click body area and paste", "tool": "click_element", "args": {"app": "Mail", "element": "Message Content"}, "assess": "Body area focused"},
                {"observe": "Body area focused", "decide": "Paste the copied text", "tool": "press_key", "args": {"key": "cmd+v"}, "assess": "Note content pasted into email body"},
            ],
        },
        {
            "intent": "Take a screenshot of the graph view and save it to Desktop",
            "steps": [
                {"observe": "Graph view showing knowledge connections", "decide": "Take a screenshot of the graph", "tool": "screenshot", "args": {"region": "frontmost"}, "assess": "Screenshot captured"},
                {"observe": "Screenshot taken", "decide": "Save to desktop with descriptive name", "tool": "run_command", "args": {"command": "mv /tmp/screenshot.png ~/Desktop/epistemos-graph-$(date +%Y%m%d).png"}, "assess": "Screenshot saved to Desktop"},
            ],
        },
        # ─── System-Level Workflows ─────────────────────
        {
            "intent": "Check accessibility permissions are enabled for Epistemos",
            "steps": [
                {"observe": "Need to verify accessibility access", "decide": "Open System Settings to Privacy", "tool": "open_system_settings", "args": {"pane": "Privacy & Security"}, "assess": "System Settings opened to Privacy & Security"},
                {"observe": "Privacy settings pane", "decide": "Click Accessibility in the list", "tool": "click_element", "args": {"app": "System Settings", "element": "Accessibility"}, "assess": "Accessibility permissions list shown"},
                {"observe": "List of apps with accessibility access", "decide": "Check if Epistemos is in the list and enabled", "tool": "get_ui_tree", "args": {"app": "System Settings", "max_depth": 5}, "assess": "Can see Epistemos toggle state in AX tree"},
            ],
        },
    ]

    for traj in TRAJECTORIES:
        # Full trajectory as ODIA format
        odia_steps = []
        for s in traj["steps"]:
            odia_steps.append(f"**Observe:** {s['observe']}\n**Decide:** {s['decide']}\n"
                            f"**Interact:** `{json.dumps({'tool': s['tool'], 'arguments': s['args']})}`\n"
                            f"**Assess:** {s['assess']}")

        examples.append(TrainingExample(
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT_DEVICE_AGENT},
                {"role": "user", "content": traj["intent"]},
                {"role": "assistant", "content": "\n\n".join(odia_steps)}
            ],
            category="trajectory", layer=4
        ))

        # Also generate individual step examples from each trajectory
        for i, step in enumerate(traj["steps"]):
            context = f"Context: {traj['intent']}. Current observation: {step['observe']}"
            if i > 0:
                context += f" Previous action: {traj['steps'][i-1]['decide']}"

            examples.append(TrainingExample(
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT_DEVICE_AGENT},
                    {"role": "user", "content": context},
                    {"role": "assistant", "content": json.dumps({"tool": step["tool"], "arguments": step["args"]})}
                ],
                category="trajectory", layer=4
            ))

    print(f"  Layer 4 (Trajectories): {len(examples)} examples")
    return examples


# ─── LAYER 5: Comprehensive Tool-Calling Examples ──────────────

def generate_tool_call_examples() -> List[TrainingExample]:
    """Generate diverse tool-calling examples for every tool."""
    examples = []

    for tool_name, tool_info in COMPREHENSIVE_TOOLS.items():
        for ex_args in tool_info.get("examples", []):
            # Direct tool call
            examples.append(TrainingExample(
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT_DEVICE_AGENT},
                    {"role": "user", "content": _natural_language_for_tool(tool_name, ex_args)},
                    {"role": "assistant", "content": json.dumps({"tool": tool_name, "arguments": ex_args})}
                ],
                category="tool_call", layer=5
            ))

    # Key code mapping examples
    KEY_COMBOS = [
        ("save the file", "cmd+s"), ("undo", "cmd+z"), ("redo", "cmd+shift+z"),
        ("copy", "cmd+c"), ("paste", "cmd+v"), ("cut", "cmd+x"), ("select all", "cmd+a"),
        ("close window", "cmd+w"), ("quit app", "cmd+q"), ("new tab", "cmd+t"),
        ("new window", "cmd+n"), ("find", "cmd+f"), ("print", "cmd+p"),
        ("open preferences", "cmd+,"), ("minimize", "cmd+m"), ("hide app", "cmd+h"),
        ("switch app", "cmd+tab"), ("spotlight", "cmd+space"), ("force quit", "cmd+option+escape"),
        ("screenshot full", "cmd+shift+3"), ("screenshot region", "cmd+shift+4"),
        ("lock screen", "cmd+ctrl+q"), ("mission control", "ctrl+up"),
        ("show desktop", "f11"), ("bold text", "cmd+b"), ("italic text", "cmd+i"),
        ("underline text", "cmd+u"),
    ]

    for intent, key in KEY_COMBOS:
        examples.append(TrainingExample(
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT_DEVICE_AGENT},
                {"role": "user", "content": intent},
                {"role": "assistant", "content": json.dumps({"tool": "press_key", "arguments": {"key": key}})}
            ],
            category="tool_call", layer=5
        ))

    print(f"  Layer 5 (Tool Calls): {len(examples)} examples")
    return examples


def _natural_language_for_tool(tool_name: str, args: dict) -> str:
    """Generate natural language request from tool name and args."""
    templates = {
        "create_note": lambda a: f"Create a new note called '{a.get('title', 'Untitled')}'",
        "edit_note": lambda a: f"Update the note with new content",
        "search_notes": lambda a: f"Search my notes for '{a.get('query', '')}'",
        "list_notes": lambda a: f"Show me all my notes{' in ' + a['folder'] if a.get('folder') else ''}",
        "read_file": lambda a: f"Read the file at {a.get('path', '')}",
        "write_file": lambda a: f"Write to {a.get('path', '')}",
        "list_files": lambda a: f"List files in {a.get('path', 'the vault')}",
        "open_url": lambda a: f"Open {a.get('url', '')} in Safari",
        "search_web": lambda a: f"Search the web for '{a.get('query', '')}'",
        "get_page_url": lambda _: "What URL is open in Safari?",
        "get_page_title": lambda _: "What page is open in Safari?",
        "get_page_text": lambda _: "Read the text on the current page",
        "click_element": lambda a: f"Click '{a.get('element', '')}' in {a.get('app', 'the app')}",
        "type_text": lambda a: f"Type '{a.get('text', '')[:50]}'",
        "press_key": lambda a: f"Press {a.get('key', '')}",
        "run_command": lambda a: f"Run: {a.get('command', '')}",
        "get_ui_tree": lambda a: f"Show me the UI elements of {a.get('app', 'the app')}",
        "activate_app": lambda a: f"Switch to {a.get('app', '')}",
        "open_app": lambda a: f"Open {a.get('app', '')}",
        "quit_app": lambda a: f"Quit {a.get('app', '')}",
        "screenshot": lambda a: f"Take a screenshot",
        "clipboard_read": lambda _: "What's on my clipboard?",
        "clipboard_write": lambda a: f"Copy this to clipboard: {a.get('text', '')[:30]}",
    }
    fn = templates.get(tool_name)
    if fn:
        try:
            return fn(args)
        except Exception:
            pass
    return f"Use {tool_name} with {json.dumps(args)}"


# ─── LAYER 6: Negative Examples ────────────────────────────────

def generate_negative_examples() -> List[TrainingExample]:
    """When NOT to call a tool — casual questions, clarifications, thinking."""
    examples = []

    NEGATIVE_CASES = [
        ("What is Mamba-2?", "Mamba-2 is a selective state space model architecture that combines the efficiency of linear recurrence with selective attention mechanisms. It was designed for hardware-efficient sequence modeling, using a parallel scan algorithm that leverages GPU tensor cores. In Epistemos, we use a hybrid Mamba-2 + Attention model with 75% Mamba layers and 25% Attention layers."),
        ("How does the graph engine work?", "The Epistemos graph engine is implemented in Rust (`graph-engine/src/lib.rs`). It uses compact Int-indexed arrays for O(1) adjacency lookup, with trigram indexing for fuzzy search. The Swift side communicates via FFI through `GraphState.swift`, which queues mutations as `pendingNodes`/`pendingEdges` and drains them in the render loop. All mutations are `@MainActor` serialized."),
        ("What's the weather like?", "I'm Epistemos-Nano, focused on app and macOS automation. I don't have access to weather data. You could search the web: I can open Safari and search for the current weather if you'd like."),
        ("Tell me a joke", "I'm optimized for app automation and knowledge management, not jokes! But I can help you create a note, search your knowledge graph, or automate a workflow. What would you like to do?"),
        ("What time is it?", "I don't have direct access to the system clock, but I can check for you."),
        ("Should I use SwiftUI or AppKit for this view?", "For Epistemos, we use SwiftUI as the primary framework with AppKit bridges where needed (like `ProseTextView2` for the text editor). SwiftUI handles layout and state (`@Observable`), while AppKit NSView subclasses handle TextKit 2 editing, Metal rendering, and accessibility. The bridge pattern is in `ProseEditorRepresentable2`."),
        ("Explain the binding cascade bug", "The binding cascade is a critical anti-pattern in Epistemos: Coordinator writes `parent.text` → SwiftUI `onChange` fires → sets `page.needsVaultSync = true` → `@Query` refetches → NoteDetailWorkspaceView re-evaluates → `loadBody()` disk read → `updateNSView` → races with next callback. The fix is debouncing binding sync to 300ms and never syncing during AI streaming."),
        ("Thanks!", "You're welcome! Let me know if you need anything else — I can help with notes, search, automation, or any app workflow."),
        ("What can you do?", "I can: create and edit notes, search your knowledge base, navigate the knowledge graph, automate macOS UI interactions (clicking, typing, scrolling in any app), manage files in your vault, browse the web in Safari, run terminal commands, take screenshots, and execute multi-step workflows across apps. Just tell me what you need!"),
        ("Hmm, let me think about that", "Take your time! I'm here when you're ready. I won't take any action until you give me a specific task."),
    ]

    for user_msg, assistant_msg in NEGATIVE_CASES:
        examples.append(TrainingExample(
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT_DEVICE_AGENT},
                {"role": "user", "content": user_msg},
                {"role": "assistant", "content": assistant_msg}
            ],
            category="negative", layer=6
        ))

    print(f"  Layer 6 (Negative): {len(examples)} examples")
    return examples


# ─── LAYER 7: Error Recovery Examples ──────────────────────────

def generate_error_recovery_examples() -> List[TrainingExample]:
    """What to do when actions fail — element not found, permission denied, stale AX tree."""
    examples = []

    ERROR_SCENARIOS = [
        {
            "error": "Element 'Save Button' not found in Epistemos. Available interactive elements: ['New Note', 'Search Field', 'Settings', 'Graph View', 'Recent Notes']",
            "recovery": "The Save button isn't visible in the current view. Let me try the keyboard shortcut instead.",
            "tool_call": {"tool": "press_key", "arguments": {"key": "cmd+s"}}
        },
        {
            "error": "Application 'Epistemos' is not running",
            "recovery": "Epistemos isn't running. Let me launch it first.",
            "tool_call": {"tool": "open_app", "arguments": {"app": "Epistemos"}}
        },
        {
            "error": "Accessibility permission denied for pid 1234",
            "recovery": "I don't have accessibility permission for this app. Let me open System Settings so you can grant access.",
            "tool_call": {"tool": "open_system_settings", "arguments": {"pane": "Privacy & Security"}}
        },
        {
            "error": "AX tree is sparse (only 2 interactive elements found). The app may not have fully loaded.",
            "recovery": "The app hasn't fully loaded yet. Let me wait and try again.",
            "tool_call": {"tool": "wait_for_element", "arguments": {"app": "Epistemos", "element": "New Note", "timeout": 10}}
        },
        {
            "error": "Click at (500, 300) hit no interactive element",
            "recovery": "The coordinate click missed the target. Let me get the UI tree to find the exact element position.",
            "tool_call": {"tool": "get_ui_tree", "arguments": {"app": "Epistemos"}}
        },
        {
            "error": "Command 'rm -rf /' is not in the allow list",
            "recovery": "That command is not allowed for safety reasons. I can only run commands from the allow list: ls, cat, head, tail, grep, find, wc, echo, date, pwd, which.",
            "tool_call": None  # No recovery action — explain the limitation
        },
        {
            "error": "File 'notes/deleted.md' not found in vault",
            "recovery": "That file doesn't exist. Let me list the available files to find what you're looking for.",
            "tool_call": {"tool": "list_files", "arguments": {"path": "notes/"}}
        },
        {
            "error": "Safari is not responding",
            "recovery": "Safari appears frozen. Let me try force-quitting and reopening it.",
            "tool_call": {"steps": [
                {"tool": "press_key", "arguments": {"key": "cmd+option+escape"}},
                {"tool": "click_element", "arguments": {"app": "Force Quit Applications", "element": "Safari"}},
                {"tool": "click_element", "arguments": {"app": "Force Quit Applications", "element": "Force Quit"}},
            ]}
        },
    ]

    for scenario in ERROR_SCENARIOS:
        assistant_content = scenario["recovery"]
        if scenario["tool_call"]:
            assistant_content += f"\n\n{json.dumps(scenario['tool_call'], indent=2)}"

        examples.append(TrainingExample(
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT_DEVICE_AGENT},
                {"role": "user", "content": f"The previous action failed with error: {scenario['error']}"},
                {"role": "assistant", "content": assistant_content}
            ],
            category="error_recovery", layer=7
        ))

    print(f"  Layer 7 (Error Recovery): {len(examples)} examples")
    return examples


# ─── OUTPUT ─────────────────────────────────────────────────────

def write_jsonl(examples: List[TrainingExample], output_dir: str, filename: str):
    """Write examples to JSONL file, deduplicated."""
    os.makedirs(output_dir, exist_ok=True)
    seen = set()
    written = 0
    path = os.path.join(output_dir, filename)

    with open(path, 'w', encoding='utf-8') as f:
        for ex in examples:
            h = hashlib.sha256(json.dumps(ex.messages, sort_keys=True).encode()).hexdigest()
            if h in seen:
                continue
            seen.add(h)
            f.write(ex.to_jsonl() + "\n")
            written += 1

    print(f"  Written: {path} ({written} examples, {os.path.getsize(path) / 1024:.1f} KB)")
    return written


def main():
    parser = argparse.ArgumentParser(description="Epistemos Training Data Generator")
    parser.add_argument("--output", default="./epistemos_training_data", help="Output directory")
    parser.add_argument("--layer", default="all", help="Which layer(s): all, code_graph, symbol_qa, ax_atlas, trajectories, tools, negative, error_recovery")
    parser.add_argument("--capture-live", action="store_true", help="Capture live AX trees from running apps (macOS only)")
    args = parser.parse_args()

    print(f"\n{'='*60}")
    print(f"  Epistemos Training Data Generator")
    print(f"  Output: {args.output}")
    print(f"  Codebase: {EPISTEMOS_ROOT}")
    print(f"{'='*60}\n")

    all_examples = []
    total = 0

    # Layer 1: Code Graph
    if args.layer in ("all", "code_graph"):
        print("Layer 1: Code Graph Model...")
        files = scan_codebase()
        print(f"  Scanned {len(files)} code files")
        examples = generate_code_graph_examples(files)
        total += write_jsonl(examples, args.output, "01_code_graph.jsonl")
        all_examples.extend(examples)

    # Layer 2: Symbol QA
    if args.layer in ("all", "symbol_qa"):
        print("Layer 2: Symbol QA...")
        if not all_examples:
            files = scan_codebase()
        examples = generate_symbol_qa_examples(files)
        total += write_jsonl(examples, args.output, "02_symbol_qa.jsonl")
        all_examples.extend(examples)

    # Layer 3: AX Atlas
    if args.layer in ("all", "ax_atlas"):
        print("Layer 3: AX Atlas...")
        examples = generate_ax_atlas_examples()
        total += write_jsonl(examples, args.output, "03_ax_atlas.jsonl")
        all_examples.extend(examples)

    # Layer 4: Trajectories
    if args.layer in ("all", "trajectories"):
        print("Layer 4: Action Trajectories...")
        examples = generate_trajectory_examples()
        total += write_jsonl(examples, args.output, "04_trajectories.jsonl")
        all_examples.extend(examples)

    # Layer 5: Tool Calls
    if args.layer in ("all", "tools"):
        print("Layer 5: Comprehensive Tool Calls...")
        examples = generate_tool_call_examples()
        total += write_jsonl(examples, args.output, "05_tool_calls.jsonl")
        all_examples.extend(examples)

    # Layer 6: Negative Examples
    if args.layer in ("all", "negative"):
        print("Layer 6: Negative Examples...")
        examples = generate_negative_examples()
        total += write_jsonl(examples, args.output, "06_negative.jsonl")
        all_examples.extend(examples)

    # Layer 7: Error Recovery
    if args.layer in ("all", "error_recovery"):
        print("Layer 7: Error Recovery...")
        examples = generate_error_recovery_examples()
        total += write_jsonl(examples, args.output, "07_error_recovery.jsonl")
        all_examples.extend(examples)

    # Combined file (all layers mixed and shuffled)
    if args.layer == "all":
        random.seed(42)
        random.shuffle(all_examples)

        # 90/10 train/eval split
        split = int(len(all_examples) * 0.9)
        train = all_examples[:split]
        eval_set = all_examples[split:]

        write_jsonl(train, args.output, "train.jsonl")
        write_jsonl(eval_set, args.output, "eval.jsonl")

        # Stats
        cats = {}
        for ex in all_examples:
            cats[ex.category] = cats.get(ex.category, 0) + 1

        print(f"\n{'='*60}")
        print(f"  TOTAL: {total} unique examples")
        print(f"  Train: {len(train)} | Eval: {len(eval_set)}")
        print(f"  Categories:")
        for cat, count in sorted(cats.items()):
            print(f"    {cat}: {count} ({count/total*100:.1f}%)")
        print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
