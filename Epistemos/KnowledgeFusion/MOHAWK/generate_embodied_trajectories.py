#!/usr/bin/env python3
"""
Embodied Trajectory Generator for Epistemos-Nano Training

Generates structured embodied agent trajectories in the format:
  [OBSERVE] -> [REASON] -> [ACT] -> [RESULT] -> [DONE]

Each trajectory has the full schema:
  - accessibility_tree (pre-action AX snapshot)
  - screenshot (path placeholder for live capture)
  - instruction (natural language task)
  - reasoning_chain (explicit <think> reasoning)
  - action (structured tool call)
  - result_accessibility_tree (post-action AX snapshot)
  - result_screenshot
  - ax_diff (structural delta)

Outputs:
  - embodied_trajectories.jsonl (100+ trajectories, OBSERVE->REASON->ACT->RESULT->DONE format)
  - embodied_trajectories_sft.jsonl (same data in chat SFT format for training)
  - generation_report.json (stats)

Usage:
  python3 generate_embodied_trajectories.py [--output-dir OUTPUT_DIR] [--count N]
"""

import json
import os
import random
import hashlib
import argparse
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

# ---------------------------------------------------------------------------
# AX Tree Templates — grounded in real Epistemos UI structure from omega-ax
# ---------------------------------------------------------------------------

# These are realistic AX tree snapshots matching the omega-ax AXTreeSnapshot schema.
# In production, EmbodiedCaptureService.swift captures these live.

def _el(role, title=None, value=None, desc=None, x=0.0, y=0.0,
        w=100.0, h=30.0, interactive=False, children=0, parent=-1):
    return {
        "role": role,
        "title": title,
        "value": value,
        "description": desc,
        "position_x": x, "position_y": y,
        "size_width": w, "size_height": h,
        "is_interactive": interactive,
        "children_count": children,
        "parent_index": parent,
    }

def _snapshot(elements: list[dict], app_name: str = "Epistemos") -> dict:
    interactive = sum(1 for e in elements if e.get("is_interactive"))
    return {
        "elements": elements,
        "app_name": app_name,
        "app_pid": 12345,
        "is_sparse": interactive < 5,
    }

# --- Epistemos Landing View ---
LANDING_VIEW = _snapshot([
    _el("AXWindow", "Epistemos", children=6),
    _el("AXToolbar", "Main Toolbar", x=0, y=0, w=1440, h=52, children=4, parent=0),
    _el("AXButton", "New Note", x=20, y=10, w=80, h=32, interactive=True, parent=1),
    _el("AXButton", "Search", x=110, y=10, w=80, h=32, interactive=True, parent=1),
    _el("AXButton", "Graph", x=200, y=10, w=80, h=32, interactive=True, parent=1),
    _el("AXButton", "Settings", x=1360, y=10, w=60, h=32, interactive=True, parent=1),
    _el("AXGroup", "Notes Sidebar", x=0, y=52, w=260, h=848, children=3, parent=0),
    _el("AXTextField", "Search notes...", x=10, y=62, w=240, h=28, interactive=True, parent=6),
    _el("AXList", "Notes List", x=0, y=100, w=260, h=800, children=5, parent=6),
    _el("AXStaticText", "Research Notes", x=10, y=105, w=240, h=24, interactive=True, parent=8),
    _el("AXStaticText", "Meeting Notes", x=10, y=135, w=240, h=24, interactive=True, parent=8),
    _el("AXStaticText", "Project Ideas", x=10, y=165, w=240, h=24, interactive=True, parent=8),
    _el("AXStaticText", "Daily Journal", x=10, y=195, w=240, h=24, interactive=True, parent=8),
    _el("AXStaticText", "Reading List", x=10, y=225, w=240, h=24, interactive=True, parent=8),
    _el("AXGroup", "Content Area", x=260, y=52, w=1180, h=848, parent=0),
    _el("AXStaticText", "Select a note or create a new one", x=660, y=400, w=300, h=30, parent=14),
])

# --- Note Editor View ---
def note_editor_view(title: str = "Research Notes", body: str = "") -> dict:
    elements = [
        _el("AXWindow", "Epistemos", children=5),
        _el("AXToolbar", "Main Toolbar", x=0, y=0, w=1440, h=52, children=5, parent=0),
        _el("AXButton", "New Note", x=20, y=10, w=80, h=32, interactive=True, parent=1),
        _el("AXButton", "Search", x=110, y=10, w=80, h=32, interactive=True, parent=1),
        _el("AXButton", "Graph", x=200, y=10, w=80, h=32, interactive=True, parent=1),
        _el("AXButton", "AI Chat", x=290, y=10, w=80, h=32, interactive=True, parent=1),
        _el("AXButton", "Settings", x=1360, y=10, w=60, h=32, interactive=True, parent=1),
        _el("AXGroup", "Notes Sidebar", x=0, y=52, w=260, h=848, children=1, parent=0),
        _el("AXList", "Notes List", x=0, y=62, w=260, h=838, children=5, parent=7),
        _el("AXStaticText", title, x=10, y=67, w=240, h=24, interactive=True, parent=8,
            desc="Selected"),
        _el("AXGroup", "Editor Area", x=260, y=52, w=920, h=848, children=3, parent=0),
        _el("AXTextField", "Note Title", value=title, x=280, y=62, w=880, h=36,
            interactive=True, parent=10),
        _el("AXTextArea", "Note Body", value=body[:200] if body else "",
            x=280, y=108, w=880, h=780, interactive=True, parent=10),
        _el("AXGroup", "Editor Toolbar", x=280, y=890, w=880, h=32, children=4, parent=10),
        _el("AXButton", "Bold", x=290, y=895, w=28, h=24, interactive=True, parent=13),
        _el("AXButton", "Italic", x=322, y=895, w=28, h=24, interactive=True, parent=13),
        _el("AXButton", "Link", x=354, y=895, w=28, h=24, interactive=True, parent=13),
        _el("AXButton", "AI Assist", x=386, y=895, w=80, h=24, interactive=True, parent=13),
        _el("AXGroup", "Chat Sidebar", x=1180, y=52, w=260, h=848, parent=0),
    ]
    return _snapshot(elements)

# --- Graph View ---
GRAPH_VIEW = _snapshot([
    _el("AXWindow", "Epistemos", children=4),
    _el("AXToolbar", "Main Toolbar", x=0, y=0, w=1440, h=52, children=4, parent=0),
    _el("AXButton", "Notes", x=20, y=10, w=80, h=32, interactive=True, parent=1),
    _el("AXButton", "Search", x=110, y=10, w=80, h=32, interactive=True, parent=1),
    _el("AXButton", "Graph", x=200, y=10, w=80, h=32, interactive=True, parent=1,
        desc="Selected"),
    _el("AXButton", "Settings", x=1360, y=10, w=60, h=32, interactive=True, parent=1),
    _el("AXGroup", "Graph Canvas", x=0, y=52, w=1180, h=848, children=2, parent=0),
    _el("AXGroup", "Metal Render View", x=0, y=52, w=1180, h=848, parent=6,
        desc="Knowledge graph visualization"),
    _el("AXSlider", "Zoom", value="1.0", x=1080, y=860, w=90, h=20, interactive=True, parent=6),
    _el("AXGroup", "Graph Sidebar", x=1180, y=52, w=260, h=848, children=3, parent=0),
    _el("AXTextField", "Search graph...", x=1190, y=62, w=240, h=28, interactive=True, parent=9),
    _el("AXList", "Node List", x=1180, y=100, w=260, h=800, children=3, parent=9),
    _el("AXStaticText", "Research Notes", x=1190, y=105, w=230, h=22, interactive=True, parent=11),
    _el("AXStaticText", "Meeting Notes", x=1190, y=132, w=230, h=22, interactive=True, parent=11),
    _el("AXStaticText", "Project Ideas", x=1190, y=159, w=230, h=22, interactive=True, parent=11),
])

# --- Omega Panel ---
OMEGA_PANEL = _snapshot([
    _el("AXWindow", "Epistemos", children=4),
    _el("AXToolbar", "Main Toolbar", x=0, y=0, w=1440, h=52, children=4, parent=0),
    _el("AXButton", "Notes", x=20, y=10, w=80, h=32, interactive=True, parent=1),
    _el("AXButton", "Graph", x=200, y=10, w=80, h=32, interactive=True, parent=1),
    _el("AXButton", "Omega", x=290, y=10, w=80, h=32, interactive=True, parent=1,
        desc="Selected"),
    _el("AXGroup", "Omega Panel", x=0, y=52, w=1440, h=848, children=4, parent=0),
    _el("AXTextField", "Ask Omega...", x=20, y=800, w=1200, h=36, interactive=True, parent=5),
    _el("AXButton", "Send", x=1230, y=800, w=60, h=36, interactive=True, parent=5),
    _el("AXScrollArea", "Task History", x=20, y=62, w=1400, h=720, parent=5),
    _el("AXButton", "Clear", x=1360, y=800, w=60, h=36, interactive=True, parent=5),
])

# --- Settings View ---
SETTINGS_VIEW = _snapshot([
    _el("AXWindow", "Epistemos Settings", children=3),
    _el("AXTabGroup", "Settings Tabs", x=0, y=0, w=600, h=40, children=4, parent=0),
    _el("AXButton", "General", x=10, y=5, w=80, h=30, interactive=True, parent=1),
    _el("AXButton", "AI Models", x=100, y=5, w=80, h=30, interactive=True, parent=1),
    _el("AXButton", "Sync", x=190, y=5, w=80, h=30, interactive=True, parent=1),
    _el("AXButton", "Advanced", x=280, y=5, w=80, h=30, interactive=True, parent=1),
    _el("AXGroup", "Settings Content", x=0, y=50, w=600, h=400, children=4, parent=0),
    _el("AXCheckBox", "Enable overnight training", x=20, y=60, w=300, h=24,
        interactive=True, parent=6),
    _el("AXPopUpButton", "Default AI Model", value="Qwen 3.5 4B", x=20, y=100, w=300, h=28,
        interactive=True, parent=6),
    _el("AXTextField", "Vault Path", value="~/Documents/Epistemos", x=20, y=140, w=400, h=28,
        interactive=True, parent=6),
    _el("AXCheckBox", "Auto-sync vault", x=20, y=180, w=300, h=24,
        interactive=True, parent=6),
    _el("AXButton", "Save", x=500, y=420, w=80, h=32, interactive=True, parent=0),
])

# --- AI Chat in Editor ---
def ai_chat_view(note_title: str = "Research Notes", query: str = "", response: str = "") -> dict:
    elements = [
        _el("AXWindow", "Epistemos", children=5),
        _el("AXToolbar", "Main Toolbar", x=0, y=0, w=1440, h=52, children=4, parent=0),
        _el("AXButton", "New Note", x=20, y=10, w=80, h=32, interactive=True, parent=1),
        _el("AXButton", "Search", x=110, y=10, w=80, h=32, interactive=True, parent=1),
        _el("AXButton", "Graph", x=200, y=10, w=80, h=32, interactive=True, parent=1),
        _el("AXButton", "AI Chat", x=290, y=10, w=80, h=32, interactive=True, parent=1,
            desc="Selected"),
        _el("AXGroup", "Editor Area", x=0, y=52, w=920, h=848, children=2, parent=0),
        _el("AXTextField", "Note Title", value=note_title, x=20, y=62, w=880, h=36,
            interactive=True, parent=6),
        _el("AXTextArea", "Note Body", x=20, y=108, w=880, h=780, interactive=True, parent=6),
        _el("AXGroup", "AI Chat Panel", x=920, y=52, w=520, h=848, children=4, parent=0),
        _el("AXScrollArea", "Chat History", x=930, y=62, w=500, h=700, parent=9),
        _el("AXStaticText", None, value=query, x=940, y=72, w=480, h=40, parent=10) if query else
        _el("AXStaticText", "No messages yet", x=940, y=350, w=200, h=24, parent=10),
        _el("AXStaticText", None, value=response[:150] if response else None,
            x=940, y=120, w=480, h=100, parent=10) if response else
        _el("AXGroup", "Empty", x=0, y=0, w=0, h=0, parent=10),
        _el("AXTextField", "Ask about this note...", x=930, y=780, w=430, h=36,
            interactive=True, parent=9),
        _el("AXButton", "Send", x=1370, y=780, w=60, h=36, interactive=True, parent=9),
        _el("AXGroup", "AI Response Actions", x=930, y=830, w=500, h=40, children=2, parent=9),
        _el("AXButton", "Accept", x=940, y=835, w=80, h=28, interactive=True, parent=15),
        _el("AXButton", "Discard", x=1030, y=835, w=80, h=28, interactive=True, parent=15),
    ]
    return _snapshot(elements)

# --- macOS System Views ---
def safari_view(url: str = "https://arxiv.org", title: str = "arXiv.org") -> dict:
    return _snapshot([
        _el("AXWindow", title, children=3),
        _el("AXToolbar", "Navigation", x=0, y=0, w=1440, h=52, children=5, parent=0),
        _el("AXButton", "Back", x=10, y=10, w=32, h=32, interactive=True, parent=1),
        _el("AXButton", "Forward", x=46, y=10, w=32, h=32, interactive=True, parent=1),
        _el("AXTextField", "Address Bar", value=url, x=200, y=10, w=800, h=32,
            interactive=True, parent=1),
        _el("AXButton", "Reload", x=1010, y=10, w=32, h=32, interactive=True, parent=1),
        _el("AXButton", "New Tab", x=1380, y=10, w=32, h=32, interactive=True, parent=1),
        _el("AXGroup", "Web Content", x=0, y=52, w=1440, h=848, children=2, parent=0),
        _el("AXLink", "Search", x=500, y=200, w=100, h=24, interactive=True, parent=7),
        _el("AXTextField", "Search...", x=400, y=300, w=600, h=36, interactive=True, parent=7),
    ], app_name="Safari")

FINDER_VIEW = _snapshot([
    _el("AXWindow", "Documents", children=3),
    _el("AXToolbar", "Finder Toolbar", x=0, y=0, w=800, h=52, children=3, parent=0),
    _el("AXButton", "Back", x=10, y=10, w=32, h=32, interactive=True, parent=1),
    _el("AXButton", "Forward", x=46, y=10, w=32, h=32, interactive=True, parent=1),
    _el("AXTextField", "Search", x=600, y=10, w=180, h=28, interactive=True, parent=1),
    _el("AXGroup", "File Browser", x=0, y=52, w=800, h=500, children=3, parent=0),
    _el("AXList", "Files", x=200, y=52, w=600, h=500, children=3, parent=5),
    _el("AXStaticText", "Epistemos", x=210, y=60, w=200, h=22, interactive=True, parent=6),
    _el("AXStaticText", "Research", x=210, y=86, w=200, h=22, interactive=True, parent=6),
    _el("AXStaticText", "Notes", x=210, y=112, w=200, h=22, interactive=True, parent=6),
], app_name="Finder")

# ---------------------------------------------------------------------------
# Action Templates — structured tool calls matching omega-mcp registry
# ---------------------------------------------------------------------------

def _action(tool: str, args: dict, agent: str = "automation") -> dict:
    return {
        "toolName": tool,
        "argumentsJson": json.dumps(args),
        "agentName": agent,
    }

# ---------------------------------------------------------------------------
# Trajectory Templates — 20 categories, 5+ variants each = 100+ trajectories
# ---------------------------------------------------------------------------

def _ax_diff(pre: dict, post: dict) -> dict:
    pre_sigs = {f"{e['role']}|{e.get('title','')}|{e.get('description','')}" for e in pre["elements"]}
    post_sigs = {f"{e['role']}|{e.get('title','')}|{e.get('description','')}" for e in post["elements"]}
    added = post_sigs - pre_sigs
    removed = pre_sigs - post_sigs
    return {
        "added_count": len(added),
        "removed_count": len(removed),
        "added": list(added)[:20],
        "removed": list(removed)[:20],
        "pre_total": len(pre["elements"]),
        "post_total": len(post["elements"]),
    }

def _step(instruction: str, reasoning: str, action: dict,
          pre_ax: dict, post_ax: dict, screenshot_pre: str = "", screenshot_post: str = "") -> dict:
    return {
        "instruction": instruction,
        "accessibility_tree": json.dumps(pre_ax),
        "screenshot": screenshot_pre or f"screenshots/pre_{hashlib.md5(instruction.encode()).hexdigest()[:8]}.png",
        "reasoning_chain": reasoning,
        "action": action,
        "result_accessibility_tree": json.dumps(post_ax),
        "result_screenshot": screenshot_post or f"screenshots/post_{hashlib.md5(instruction.encode()).hexdigest()[:8]}.png",
        "ax_diff": json.dumps(_ax_diff(pre_ax, post_ax)),
    }

def _trajectory(task: str, steps: list[dict], task_type: str = "general") -> dict:
    return {
        "task_description": task,
        "steps": steps,
        "step_count": len(steps),
        "task_type": task_type,
        "success": True,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "format": "embodied_v1",
        "schema_version": "1.0.0",
    }


# ===== CATEGORY 1: Create Note =====
def gen_create_note_trajectories() -> list[dict]:
    titles = [
        "Meeting Notes 2026-03-27", "Research: Mamba-2 Architecture",
        "Project Roadmap Q2", "Weekly Review", "Book Notes: Designing Data-Intensive Applications",
        "Ideas for Graph Visualization", "Bug Report: Editor Crash",
    ]
    results = []
    for title in titles:
        editor = note_editor_view(title)
        steps = [
            _step(
                f"Create a new note called '{title}'",
                f"<think>I'm on the landing view. I need to create a new note. I see a 'New Note' button in the toolbar at position (20, 10). I'll click it to open the note creation flow.</think>",
                _action("click_element", {"pid": 12345, "element_name": "New Note"}),
                LANDING_VIEW, editor,
            ),
            _step(
                f"Set the note title to '{title}'",
                f"<think>The note editor is now open with an empty title field. I need to type the title '{title}' into the AXTextField at position (280, 62). The field is already focused after creation.</think>",
                _action("type_text", {"text": title}),
                editor, note_editor_view(title),
            ),
        ]
        results.append(_trajectory(f"Create a new note called '{title}'", steps, "app_specific"))
    return results


# ===== CATEGORY 2: Search Notes =====
def gen_search_note_trajectories() -> list[dict]:
    queries = ["Mamba", "training guide", "graph engine", "SwiftUI", "ODIA traces", "accessibility"]
    results = []
    for q in queries:
        post_search = note_editor_view(f"Results: {q}")
        steps = [
            _step(
                f"Search for notes containing '{q}'",
                f"<think>I need to search for '{q}'. I see the search field in the sidebar at position (10, 62). I'll click it and type my query.</think>",
                _action("click_element", {"pid": 12345, "element_name": "Search notes..."}),
                LANDING_VIEW, LANDING_VIEW,
            ),
            _step(
                f"Type search query '{q}'",
                f"<think>The search field is now focused. I'll type '{q}' to filter the notes list.</think>",
                _action("type_text", {"text": q}),
                LANDING_VIEW, post_search,
            ),
        ]
        results.append(_trajectory(f"Search for notes about '{q}'", steps, "app_specific"))
    return results


# ===== CATEGORY 3: Navigate to Graph View =====
def gen_graph_navigation_trajectories() -> list[dict]:
    results = []
    # From landing
    steps = [
        _step(
            "Navigate to the knowledge graph view",
            "<think>I'm on the landing view. I see a 'Graph' button in the toolbar. I'll click it to switch to the graph visualization.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Graph"}),
            LANDING_VIEW, GRAPH_VIEW,
        ),
    ]
    results.append(_trajectory("Open the knowledge graph", steps, "app_specific"))

    # From editor
    editor = note_editor_view("Research Notes")
    steps = [
        _step(
            "Switch from note editor to graph view",
            "<think>I'm editing a note but need to see the graph. The 'Graph' button is in the toolbar. I'll click it to switch views.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Graph"}),
            editor, GRAPH_VIEW,
        ),
    ]
    results.append(_trajectory("Switch from note editor to knowledge graph", steps, "app_specific"))

    # Search in graph
    steps = [
        _step(
            "Search for a node in the graph",
            "<think>I'm in the graph view. I need to find a specific node. I see the search field in the graph sidebar at position (1190, 62). I'll click and type my search.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Search graph..."}),
            GRAPH_VIEW, GRAPH_VIEW,
        ),
        _step(
            "Type node search query",
            "<think>The graph search field is focused. I'll type 'Research' to find the node.</think>",
            _action("type_text", {"text": "Research"}),
            GRAPH_VIEW, GRAPH_VIEW,
        ),
    ]
    results.append(_trajectory("Search for 'Research' node in the knowledge graph", steps, "app_specific"))

    # Zoom graph
    steps = [
        _step(
            "Zoom into the graph",
            "<think>I need to zoom into the graph to see node details. I see the zoom slider at position (1080, 860). I'll use scroll gesture on the graph canvas.</think>",
            _action("scroll", {"selector": "AXGroup[@AXDescription='Knowledge graph visualization']", "value": "up:3"}),
            GRAPH_VIEW, GRAPH_VIEW,
        ),
    ]
    results.append(_trajectory("Zoom into the knowledge graph for detail", steps, "app_specific"))
    return results


# ===== CATEGORY 4: AI Chat Operations =====
def gen_ai_chat_trajectories() -> list[dict]:
    operations = [
        ("Summarize this note", "summarize"),
        ("Rewrite the introduction paragraph", "rewrite"),
        ("Expand the section on training data", "expand"),
        ("Create an outline from this note", "outline"),
        ("Simplify the technical language", "simplify"),
        ("Continue writing from where I left off", "continue"),
    ]
    results = []
    for query, op in operations:
        pre = note_editor_view("Research Notes", "This note contains research findings about...")
        chat = ai_chat_view("Research Notes", query, f"Here is the {op} result...")
        steps = [
            _step(
                f"Open AI chat for current note",
                f"<think>I need to use AI to {op} the note content. I see the 'AI Chat' button in the toolbar. I'll click it to open the chat panel.</think>",
                _action("click_element", {"pid": 12345, "element_name": "AI Chat"}),
                pre, chat,
            ),
            _step(
                f"Send AI query: {query}",
                f"<think>The AI chat panel is open. I'll type my request '{query}' in the chat input field and send it.</think>",
                _action("type_text", {"text": query}),
                chat, chat,
            ),
            _step(
                f"Send the message",
                f"<think>I've typed my query. Now I'll click the Send button to submit it to the AI.</think>",
                _action("click_element", {"pid": 12345, "element_name": "Send"}),
                chat, ai_chat_view("Research Notes", query, f"Here is the {op} result for your note..."),
            ),
            _step(
                f"Accept the AI response",
                f"<think>The AI has generated a {op} result. It looks good. I'll click Accept to apply it to the note.</think>",
                _action("click_element", {"pid": 12345, "element_name": "Accept"}),
                ai_chat_view("Research Notes", query, f"Here is the {op} result for your note..."),
                note_editor_view("Research Notes", f"[{op} applied] This note contains..."),
            ),
        ]
        results.append(_trajectory(f"{query} using AI assistant", steps, "app_specific"))
    return results


# ===== CATEGORY 5: Omega Task Submission =====
def gen_omega_trajectories() -> list[dict]:
    tasks = [
        ("Search the web for recent Mamba-2 papers", "research"),
        ("Create a summary of all my notes from this week", "general"),
        ("Find and open the TrainingScheduler.swift file", "general"),
        ("Run the Swift test suite", "general"),
        ("Organize my notes by topic", "general"),
    ]
    results = []
    for task_desc, task_type in tasks:
        steps = [
            _step(
                "Open Omega panel",
                "<think>I need to submit a task to Omega. I'll click the Omega button in the toolbar to open the task panel.</think>",
                _action("click_element", {"pid": 12345, "element_name": "Omega"}),
                LANDING_VIEW, OMEGA_PANEL,
            ),
            _step(
                f"Type task: {task_desc}",
                f"<think>The Omega panel is open. I see the task input field at the bottom. I'll type my task description: '{task_desc}'.</think>",
                _action("type_text", {"text": task_desc}),
                OMEGA_PANEL, OMEGA_PANEL,
            ),
            _step(
                "Submit task to Omega",
                "<think>I've entered the task description. I'll click Send to submit it. Omega will plan and execute the task through its agent pipeline.</think>",
                _action("click_element", {"pid": 12345, "element_name": "Send"}),
                OMEGA_PANEL, OMEGA_PANEL,
            ),
        ]
        results.append(_trajectory(f"Ask Omega to: {task_desc}", steps, task_type))
    return results


# ===== CATEGORY 6: Settings Configuration =====
def gen_settings_trajectories() -> list[dict]:
    results = []

    # Enable overnight training
    steps = [
        _step(
            "Open Settings",
            "<think>I need to configure settings. I'll click the Settings button in the toolbar.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Settings"}),
            LANDING_VIEW, SETTINGS_VIEW,
        ),
        _step(
            "Enable overnight training",
            "<think>I see the 'Enable overnight training' checkbox. It's currently unchecked. I'll click it to enable nightly LoRA training.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Enable overnight training"}),
            SETTINGS_VIEW, SETTINGS_VIEW,
        ),
        _step(
            "Save settings",
            "<think>I've enabled overnight training. I need to click Save to persist the change.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Save"}),
            SETTINGS_VIEW, SETTINGS_VIEW,
        ),
    ]
    results.append(_trajectory("Enable overnight training in settings", steps, "app_specific"))

    # Change AI model
    steps = [
        _step(
            "Open Settings",
            "<think>I need to change the AI model. Opening Settings first.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Settings"}),
            LANDING_VIEW, SETTINGS_VIEW,
        ),
        _step(
            "Navigate to AI Models tab",
            "<think>I need the AI Models tab to change the model. I see it in the tab group.</think>",
            _action("click_element", {"pid": 12345, "element_name": "AI Models"}),
            SETTINGS_VIEW, SETTINGS_VIEW,
        ),
    ]
    results.append(_trajectory("Change the default AI model in settings", steps, "app_specific"))
    return results


# ===== CATEGORY 7: Multi-App Safari Research =====
def gen_safari_research_trajectories() -> list[dict]:
    searches = [
        ("Mamba-2 state space model paper", "https://arxiv.org/search/?query=mamba+2"),
        ("MOHAWK knowledge distillation", "https://arxiv.org/search/?query=mohawk+distillation"),
        ("MLX fine-tuning tutorial", "https://developer.apple.com/search/?q=mlx+fine+tuning"),
        ("macOS accessibility API guide", "https://developer.apple.com/search/?q=accessibility+api"),
    ]
    results = []
    for query, url in searches:
        safari = safari_view(url, f"Search: {query}")
        steps = [
            _step(
                "Open Safari",
                "<think>I need to research something online. I'll launch Safari first using the launch_app tool.</think>",
                _action("launch_app", {"app_name": "Safari"}),
                LANDING_VIEW, safari_view(),
            ),
            _step(
                f"Navigate to search for '{query}'",
                f"<think>Safari is open. I'll click the address bar and type the search URL for '{query}'.</think>",
                _action("click_element", {"pid": 54321, "element_name": "Address Bar"}),
                safari_view(), safari_view(),
            ),
            _step(
                f"Type search URL",
                f"<think>Address bar is focused. I'll type the search URL.</think>",
                _action("type_text", {"text": url}),
                safari_view(), safari,
            ),
            _step(
                "Press Enter to navigate",
                "<think>URL is entered. I'll press Enter (keycode 36) to navigate.</think>",
                _action("key_press", {"key_code": 36, "modifiers": 0}),
                safari, safari,
            ),
        ]
        results.append(_trajectory(f"Research '{query}' in Safari", steps, "research"))
    return results


# ===== CATEGORY 8: File Operations =====
def gen_file_operation_trajectories() -> list[dict]:
    results = []

    # List vault files
    steps = [
        _step(
            "List files in the vault directory",
            "<think>I need to check what files are in the vault. I'll use the list_files tool to enumerate the vault directory.</think>",
            _action("list_files", {"path": "~/Documents/Epistemos"}, agent="file"),
            LANDING_VIEW, LANDING_VIEW,
        ),
    ]
    results.append(_trajectory("List all files in the Epistemos vault", steps, "general"))

    # Open specific file
    steps = [
        _step(
            "Open TrainingScheduler.swift in the editor",
            "<think>I need to open a specific Swift file. I'll use the open_file tool to open it in the default editor.</think>",
            _action("open_file", {"path": "Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift"}, agent="file"),
            LANDING_VIEW, LANDING_VIEW,
        ),
    ]
    results.append(_trajectory("Open TrainingScheduler.swift for editing", steps, "general"))

    # Run terminal command
    commands = [
        ("Run Swift tests", "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test"),
        ("Check Rust tests", "cd graph-engine && cargo test"),
        ("Build the project", "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos build"),
    ]
    for desc, cmd in commands:
        steps = [
            _step(
                desc,
                f"<think>I need to {desc.lower()}. I'll use the run_command tool to execute the build/test command in the terminal.</think>",
                _action("run_command", {"command": cmd}, agent="terminal"),
                LANDING_VIEW, LANDING_VIEW,
            ),
        ]
        results.append(_trajectory(desc, steps, "general"))
    return results


# ===== CATEGORY 9: Note Editing Workflows =====
def gen_note_editing_trajectories() -> list[dict]:
    results = []

    # Format text bold
    editor = note_editor_view("Research Notes", "Important finding about Mamba architecture")
    steps = [
        _step(
            "Select text to bold",
            "<think>I need to bold 'Important finding'. I'll select the text first by clicking at the start position and dragging.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Note Body"}),
            editor, editor,
        ),
        _step(
            "Apply bold formatting",
            "<think>Text is selected. I'll click the Bold button in the editor toolbar, or use Cmd+B.</think>",
            _action("key_press", {"key_code": 11, "modifiers": 256}),  # Cmd+B
            editor, editor,
        ),
    ]
    results.append(_trajectory("Bold important text in a note", steps, "app_specific"))

    # Add wikilink
    steps = [
        _step(
            "Type a wikilink to connect notes",
            "<think>I want to create a link to another note. In Epistemos, wikilinks use [[double bracket]] syntax. I'll type [[Meeting Notes]] to create the link.</think>",
            _action("type_text", {"text": "[[Meeting Notes]]"}),
            editor, editor,
        ),
    ]
    results.append(_trajectory("Add a wikilink to connect two notes", steps, "app_specific"))

    # Use AI context menu
    ops = [
        ("rewrite", "Rewrite this paragraph more concisely"),
        ("toList", "Convert this paragraph to a bullet list"),
        ("toTable", "Convert this data to a table"),
    ]
    for op, desc in ops:
        steps = [
            _step(
                "Right-click to open context menu",
                f"<think>I need to {desc.lower()}. I'll right-click on the selected text to open the AI context menu.</think>",
                _action("click_element", {"pid": 12345, "element_name": "Note Body"}),
                editor, editor,
            ),
            _step(
                f"Select '{op}' from AI context menu",
                f"<think>The context menu is open. I see the AI operations submenu. I'll select '{op}' to {desc.lower()}.</think>",
                _action("click_element", {"pid": 12345, "element_name": op}),
                editor, ai_chat_view("Research Notes", desc),
            ),
            _step(
                "Accept the AI result",
                "<think>The AI has processed the text. The result looks good. I'll click Accept to apply it.</think>",
                _action("click_element", {"pid": 12345, "element_name": "Accept"}),
                ai_chat_view("Research Notes", desc, "Result..."),
                editor,
            ),
        ]
        results.append(_trajectory(desc, steps, "app_specific"))
    return results


# ===== CATEGORY 10: Error Recovery Trajectories =====
def gen_error_recovery_trajectories() -> list[dict]:
    results = []

    # Accessibility error → retry
    steps = [
        _step(
            "Click a button that fails with AXError",
            "<think>I tried to click 'Save' but got kAXErrorCannotComplete. This usually means the element is disabled or a modal is blocking. Let me check if there's a modal dialog first.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Save"}),
            SETTINGS_VIEW, SETTINGS_VIEW,
        ),
        _step(
            "Check for blocking modal and dismiss it",
            "<think>There might be an unsaved changes dialog blocking. I'll look for and dismiss any modal first, then retry the save.</think>",
            _action("key_press", {"key_code": 36, "modifiers": 0}),  # Enter to dismiss
            SETTINGS_VIEW, SETTINGS_VIEW,
        ),
        _step(
            "Retry the save operation",
            "<think>Modal dismissed. Now I'll retry clicking Save.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Save"}),
            SETTINGS_VIEW, SETTINGS_VIEW,
        ),
    ]
    results.append(_trajectory("Handle AXError during save and recover", steps, "error_recovery"))

    # Element not found → alternative path
    steps = [
        _step(
            "Try to click element that doesn't exist",
            "<think>I tried to click 'Export' but the element wasn't found in the AX tree. The Export function might be in a menu instead. I'll try the File menu.</think>",
            _action("key_press", {"key_code": 3, "modifiers": 256}),  # Cmd+F (File menu)
            LANDING_VIEW, LANDING_VIEW,
        ),
        _step(
            "Find Export in File menu",
            "<think>File menu is open. I'll look for Export or Share option in the menu items.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Export..."}),
            LANDING_VIEW, LANDING_VIEW,
        ),
    ]
    results.append(_trajectory("Recover from element not found by using menu", steps, "error_recovery"))

    # Timeout → keyboard shortcut
    steps = [
        _step(
            "Click timed out on unresponsive button",
            "<think>The click on 'New Note' timed out. The app might be processing. I'll try the keyboard shortcut Cmd+N instead, which is more reliable.</think>",
            _action("key_press", {"key_code": 45, "modifiers": 256}),  # Cmd+N
            LANDING_VIEW, note_editor_view("Untitled"),
        ),
    ]
    results.append(_trajectory("Use keyboard shortcut when click times out", steps, "error_recovery"))

    # Sparse AX tree → fallback
    sparse_tree = _snapshot([
        _el("AXWindow", "Epistemos", children=1),
        _el("AXGroup", "Content", x=0, y=0, w=1440, h=900, parent=0),
    ])
    steps = [
        _step(
            "Detect sparse AX tree and use coordinate-based fallback",
            "<think>The AX tree is sparse (fewer than 5 interactive elements). This might be during a loading state or the app's Metal rendering surface. I'll wait 500ms and retry the AX walk.</think>",
            _action("click_element", {"pid": 12345, "element_name": "retry_ax_walk"}),
            sparse_tree, LANDING_VIEW,
        ),
    ]
    results.append(_trajectory("Handle sparse AX tree during app loading", steps, "error_recovery"))
    return results


# ===== CATEGORY 11: Cross-App Workflows =====
def gen_cross_app_trajectories() -> list[dict]:
    results = []

    # Copy from Safari to Note
    steps = [
        _step(
            "Select text in Safari",
            "<think>I need to copy research content from Safari into an Epistemos note. First, I'll select the relevant text in the web page.</think>",
            _action("key_press", {"key_code": 0, "modifiers": 256}),  # Cmd+A
            safari_view("https://arxiv.org/abs/2401.12345", "Mamba-2 Paper"),
            safari_view("https://arxiv.org/abs/2401.12345", "Mamba-2 Paper"),
        ),
        _step(
            "Copy selected text",
            "<think>Text is selected. I'll copy it with Cmd+C.</think>",
            _action("key_press", {"key_code": 8, "modifiers": 256}),  # Cmd+C
            safari_view("https://arxiv.org/abs/2401.12345", "Mamba-2 Paper"),
            safari_view("https://arxiv.org/abs/2401.12345", "Mamba-2 Paper"),
        ),
        _step(
            "Switch to Epistemos",
            "<think>Content copied. Now I'll switch to Epistemos to paste it into a note.</think>",
            _action("launch_app", {"app_name": "Epistemos"}),
            safari_view("https://arxiv.org/abs/2401.12345", "Mamba-2 Paper"),
            LANDING_VIEW,
        ),
        _step(
            "Open or create a note for the research",
            "<think>I'm back in Epistemos. I'll create a new note for this research content.</think>",
            _action("click_element", {"pid": 12345, "element_name": "New Note"}),
            LANDING_VIEW, note_editor_view("Untitled"),
        ),
        _step(
            "Paste the copied content",
            "<think>New note is open. I'll paste the Safari content with Cmd+V.</think>",
            _action("key_press", {"key_code": 9, "modifiers": 256}),  # Cmd+V
            note_editor_view("Untitled"),
            note_editor_view("Untitled", "Mamba-2 research content pasted..."),
        ),
    ]
    results.append(_trajectory("Copy research content from Safari to a new Epistemos note", steps, "research"))

    # Finder → open vault file
    steps = [
        _step(
            "Open Finder to vault location",
            "<think>I need to find a file in the vault. I'll open Finder to the vault directory.</think>",
            _action("launch_app", {"app_name": "Finder"}),
            LANDING_VIEW, FINDER_VIEW,
        ),
        _step(
            "Navigate to Epistemos folder",
            "<think>Finder is open. I see the Epistemos folder. I'll double-click to open it.</think>",
            _action("click_element", {"pid": 99999, "element_name": "Epistemos"}),
            FINDER_VIEW, FINDER_VIEW,
        ),
    ]
    results.append(_trajectory("Open Epistemos vault in Finder", steps, "general"))
    return results


# ===== CATEGORY 12: Research Workflows (Omega) =====
def gen_research_workflow_trajectories() -> list[dict]:
    results = []

    topics = [
        "State space models for language modeling",
        "On-device knowledge distillation techniques",
        "Accessibility-driven UI automation",
        "Personal LoRA adaptation strategies",
    ]
    for topic in topics:
        steps = [
            _step(
                "Open Omega panel for research task",
                "<think>I need to research a topic. I'll open the Omega panel and submit a research request. Omega will use its research orchestrator with escalation gates.</think>",
                _action("click_element", {"pid": 12345, "element_name": "Omega"}),
                LANDING_VIEW, OMEGA_PANEL,
            ),
            _step(
                f"Submit research task: {topic}",
                f"<think>I'll type the research query and submit it. Omega will plan a multi-step research workflow: search → collect → analyze → synthesize → create note.</think>",
                _action("type_text", {"text": f"research: {topic}"}),
                OMEGA_PANEL, OMEGA_PANEL,
            ),
            _step(
                "Send research request",
                "<think>Research query entered. Sending to Omega for execution.</think>",
                _action("click_element", {"pid": 12345, "element_name": "Send"}),
                OMEGA_PANEL, OMEGA_PANEL,
            ),
        ]
        results.append(_trajectory(f"Research: {topic}", steps, "research"))
    return results


# ===== CATEGORY 13: Keyboard-Driven Navigation =====
def gen_keyboard_navigation_trajectories() -> list[dict]:
    results = []

    shortcuts = [
        ("Cmd+N", 45, 256, "Create new note", LANDING_VIEW, note_editor_view("Untitled")),
        ("Cmd+F", 3, 256, "Open search", LANDING_VIEW, LANDING_VIEW),
        ("Cmd+,", 43, 256, "Open settings", LANDING_VIEW, SETTINGS_VIEW),
        ("Cmd+W", 13, 256, "Close current tab", note_editor_view("Test"), LANDING_VIEW),
        ("Cmd+G", 5, 256, "Switch to graph view", LANDING_VIEW, GRAPH_VIEW),
    ]
    for shortcut_name, key_code, mods, desc, pre, post in shortcuts:
        steps = [
            _step(
                desc,
                f"<think>I'll use the keyboard shortcut {shortcut_name} to {desc.lower()} quickly. Keyboard shortcuts are more reliable than AX element clicks for common operations.</think>",
                _action("key_press", {"key_code": key_code, "modifiers": mods}),
                pre, post,
            ),
        ]
        results.append(_trajectory(f"{desc} via {shortcut_name}", steps, "general"))
    return results


# ===== CATEGORY 14: Scroll & Navigate Lists =====
def gen_scroll_trajectories() -> list[dict]:
    results = []

    targets = [
        ("Notes List", "notes sidebar", LANDING_VIEW),
        ("Node List", "graph sidebar", GRAPH_VIEW),
        ("Task History", "Omega task history", OMEGA_PANEL),
    ]
    for target, desc, view in targets:
        steps = [
            _step(
                f"Scroll down in {desc}",
                f"<think>I need to scroll down in the {desc} to see more items. I'll use the scroll action on the {target} element.</think>",
                _action("scroll", {"selector": f"AXList[@AXTitle='{target}']", "value": "down:3"}),
                view, view,
            ),
        ]
        results.append(_trajectory(f"Scroll through {desc}", steps, "general"))
    return results


# ===== CATEGORY 15: Negative / Refusal Trajectories =====
def gen_negative_trajectories() -> list[dict]:
    results = []

    questions = [
        ("What is the meaning of life?", "This is a philosophical question. I should answer conversationally without using any tools."),
        ("Tell me a joke", "This is a social request. No tool calls needed — I'll respond directly."),
        ("What's 2+2?", "Simple math question. No tools needed."),
        ("How's the weather?", "I don't have access to weather APIs. I should say so directly."),
    ]
    for q, reasoning in questions:
        steps = [
            _step(
                q,
                f"<think>{reasoning}</think>",
                _action("respond_text", {"text": f"[conversational response to: {q}]"}, agent="none"),
                LANDING_VIEW, LANDING_VIEW,
            ),
        ]
        results.append(_trajectory(f"Handle non-tool question: {q}", steps, "negative"))
    return results


# ===== CATEGORY 16: Multi-Tab Note Workflows =====
def gen_multi_tab_trajectories() -> list[dict]:
    results = []

    # Open multiple notes and compare
    steps = [
        _step(
            "Open first note",
            "<think>I need to compare two notes. First, I'll open 'Research Notes' from the sidebar.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Research Notes"}),
            LANDING_VIEW, note_editor_view("Research Notes", "Research content..."),
        ),
        _step(
            "Open second note in new tab",
            "<think>Now I need to open 'Meeting Notes' in a new tab. I'll Cmd+click it in the sidebar to open in a new tab.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Meeting Notes"}),
            note_editor_view("Research Notes"), note_editor_view("Meeting Notes"),
        ),
    ]
    results.append(_trajectory("Compare two notes side by side", steps, "app_specific"))

    # Create note from template
    templates = ["Weekly Review", "Meeting Notes", "Research Log"]
    for template in templates:
        steps = [
            _step(
                f"Create note from '{template}' template",
                f"<think>I'll create a new note and populate it with the '{template}' template structure.</think>",
                _action("click_element", {"pid": 12345, "element_name": "New Note"}),
                LANDING_VIEW, note_editor_view("Untitled"),
            ),
            _step(
                f"Set title to '{template}'",
                f"<think>Note created. I'll set the title to '{template}' and type the template structure.</think>",
                _action("type_text", {"text": template}),
                note_editor_view("Untitled"), note_editor_view(template),
            ),
        ]
        results.append(_trajectory(f"Create a '{template}' note from template", steps, "app_specific"))
    return results


# ===== CATEGORY 17: Vault Sync Operations =====
def gen_vault_sync_trajectories() -> list[dict]:
    results = []

    steps = [
        _step(
            "Open Settings to check sync status",
            "<think>I need to check if vault sync is enabled and working. I'll open Settings and navigate to the Sync tab.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Settings"}),
            LANDING_VIEW, SETTINGS_VIEW,
        ),
        _step(
            "Navigate to Sync tab",
            "<think>Settings is open. I'll click the 'Sync' tab to see vault sync configuration.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Sync"}),
            SETTINGS_VIEW, SETTINGS_VIEW,
        ),
        _step(
            "Enable auto-sync",
            "<think>I see the 'Auto-sync vault' checkbox. I'll enable it to keep the vault synchronized.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Auto-sync vault"}),
            SETTINGS_VIEW, SETTINGS_VIEW,
        ),
    ]
    results.append(_trajectory("Enable vault auto-sync in settings", steps, "app_specific"))
    return results


# ===== CATEGORY 18: Accessibility Verification Loops =====
def gen_verification_trajectories() -> list[dict]:
    """Trajectories that demonstrate the OBSERVE->VERIFY pattern after actions."""
    results = []

    # Verify note was created
    steps = [
        _step(
            "Create a note",
            "<think>Creating a new note. I'll click New Note.</think>",
            _action("click_element", {"pid": 12345, "element_name": "New Note"}),
            LANDING_VIEW, note_editor_view("Untitled"),
        ),
        _step(
            "Verify note editor appeared",
            "<think>I need to verify the note was created. I'll check the AX tree for the note title field and editor area. The post-action AX tree should contain AXTextField with value 'Note Title' and AXTextArea for the body. Both are present — creation succeeded.</think>",
            _action("verify_ax_state", {"expected_role": "AXTextField", "expected_title": "Note Title"}),
            note_editor_view("Untitled"), note_editor_view("Untitled"),
        ),
    ]
    results.append(_trajectory("Create note and verify via AX tree", steps, "app_specific"))

    # Verify navigation
    steps = [
        _step(
            "Navigate to Graph view",
            "<think>Switching to graph view.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Graph"}),
            LANDING_VIEW, GRAPH_VIEW,
        ),
        _step(
            "Verify graph view loaded",
            "<think>I need to verify the graph view loaded. I'll check for the Metal Render View and Graph Canvas elements in the AX tree. Both are present with the expected descriptions. Graph view confirmed.</think>",
            _action("verify_ax_state", {"expected_role": "AXGroup", "expected_description": "Knowledge graph visualization"}),
            GRAPH_VIEW, GRAPH_VIEW,
        ),
    ]
    results.append(_trajectory("Navigate to graph and verify via AX tree", steps, "app_specific"))
    return results


# ===== CATEGORY 19: Complex Multi-Step Workflows =====
def gen_complex_workflow_trajectories() -> list[dict]:
    results = []

    # Research → Note → Graph pipeline
    steps = [
        _step(
            "Start research in Omega",
            "<think>I'll begin a research workflow. First, open Omega and submit the research task.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Omega"}),
            LANDING_VIEW, OMEGA_PANEL,
        ),
        _step(
            "Submit research query",
            "<think>Omega is open. Submitting a research task about knowledge distillation.</think>",
            _action("type_text", {"text": "research: knowledge distillation for small language models"}),
            OMEGA_PANEL, OMEGA_PANEL,
        ),
        _step(
            "Send the research task",
            "<think>Sending the research task. Omega will search, collect evidence, and create a research note.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Send"}),
            OMEGA_PANEL, OMEGA_PANEL,
        ),
        _step(
            "Navigate to the new research note",
            "<think>Omega completed the research and created a note. I'll navigate to Notes view to find it.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Notes"}),
            OMEGA_PANEL, LANDING_VIEW,
        ),
        _step(
            "Open the research note",
            "<think>I see the new note in the sidebar. Opening it to review.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Knowledge Distillation Research"}),
            LANDING_VIEW, note_editor_view("Knowledge Distillation Research", "Research findings..."),
        ),
        _step(
            "View note in knowledge graph",
            "<think>I want to see how this note connects to others in the graph. Switching to graph view.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Graph"}),
            note_editor_view("Knowledge Distillation Research"), GRAPH_VIEW,
        ),
    ]
    results.append(_trajectory(
        "Research knowledge distillation, review note, and check graph connections",
        steps, "research"
    ))

    # Create note → AI expand → accept → add wikilinks
    steps = [
        _step(
            "Create a new note",
            "<think>Starting a new note for project planning.</think>",
            _action("click_element", {"pid": 12345, "element_name": "New Note"}),
            LANDING_VIEW, note_editor_view("Untitled"),
        ),
        _step(
            "Set title",
            "<think>I'll set the title for this planning note.</think>",
            _action("type_text", {"text": "Q2 Training Plan"}),
            note_editor_view("Untitled"), note_editor_view("Q2 Training Plan"),
        ),
        _step(
            "Write initial outline",
            "<think>I'll type a brief outline, then ask AI to expand it.</think>",
            _action("type_text", {"text": "# Goals\n- Embodied data pipeline\n- First adapter\n- Evaluation suite"}),
            note_editor_view("Q2 Training Plan"),
            note_editor_view("Q2 Training Plan", "# Goals\n- Embodied data pipeline..."),
        ),
        _step(
            "Ask AI to expand the outline",
            "<think>I have a brief outline. I'll open AI chat to expand it with more detail.</think>",
            _action("click_element", {"pid": 12345, "element_name": "AI Chat"}),
            note_editor_view("Q2 Training Plan", "# Goals\n- Embodied data pipeline..."),
            ai_chat_view("Q2 Training Plan", "", ""),
        ),
        _step(
            "Request expansion",
            "<think>AI chat is open. I'll ask it to expand each bullet point into a detailed section.</think>",
            _action("type_text", {"text": "Expand each bullet point into a detailed section with timelines"}),
            ai_chat_view("Q2 Training Plan"), ai_chat_view("Q2 Training Plan"),
        ),
        _step(
            "Send the expansion request",
            "<think>Sending the expansion request to AI.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Send"}),
            ai_chat_view("Q2 Training Plan"),
            ai_chat_view("Q2 Training Plan", "Expand each bullet...", "## Detailed Sections..."),
        ),
        _step(
            "Accept the AI expansion",
            "<think>The AI generated detailed sections. I'll accept and merge them into the note.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Accept"}),
            ai_chat_view("Q2 Training Plan", "Expand each bullet...", "## Detailed Sections..."),
            note_editor_view("Q2 Training Plan", "# Goals\n## Detailed sections merged..."),
        ),
    ]
    results.append(_trajectory(
        "Create a planning note, write outline, AI-expand it, and accept",
        steps, "app_specific"
    ))
    return results


# ===== CATEGORY 20: Discard / Undo Flows =====
def gen_discard_undo_trajectories() -> list[dict]:
    results = []

    # Discard AI suggestion
    steps = [
        _step(
            "Ask AI to rewrite",
            "<think>I'll ask the AI to rewrite the current paragraph.</think>",
            _action("click_element", {"pid": 12345, "element_name": "AI Assist"}),
            note_editor_view("Research Notes", "Original content..."),
            ai_chat_view("Research Notes", "Rewrite", "Rewritten version..."),
        ),
        _step(
            "Review and discard the AI result",
            "<think>The AI rewrite changed the meaning too much. I'll discard it to keep the original.</think>",
            _action("click_element", {"pid": 12345, "element_name": "Discard"}),
            ai_chat_view("Research Notes", "Rewrite", "Rewritten version..."),
            note_editor_view("Research Notes", "Original content..."),
        ),
    ]
    results.append(_trajectory("Discard an AI rewrite that changed the meaning", steps, "app_specific"))

    # Undo accidental deletion
    steps = [
        _step(
            "Undo accidental text deletion",
            "<think>I accidentally deleted text. I'll use Cmd+Z to undo immediately.</think>",
            _action("key_press", {"key_code": 6, "modifiers": 256}),  # Cmd+Z
            note_editor_view("Research Notes", ""),
            note_editor_view("Research Notes", "Content restored by undo..."),
        ),
    ]
    results.append(_trajectory("Undo accidental text deletion with Cmd+Z", steps, "app_specific"))
    return results


# ===== CATEGORY 21: Additional Tool Call Variations =====
def gen_tool_call_trajectories():
    """Direct tool-call trajectories for tool-calling data balance."""
    results = []

    tool_calls = [
        ("Create a note about Swift concurrency", "create_note",
         {"title": "Swift Concurrency Notes", "body": "# Swift Concurrency\n\n- async/await\n- actors\n- structured concurrency"}, "notes"),
        ("Search for notes about graph engine", "search_notes",
         {"query": "graph engine"}, "notes"),
        ("Edit the Research Notes body", "edit_note",
         {"title": "Research Notes", "body": "Updated research findings..."}, "notes"),
        ("Delete the temporary note", "delete_note",
         {"title": "temp-scratch"}, "notes"),
        ("Get the current Safari page URL", "get_page_url", {}, "safari"),
        ("Get the current Safari page title", "get_page_title", {}, "safari"),
        ("Open arxiv.org in Safari", "open_url",
         {"url": "https://arxiv.org"}, "safari"),
        ("Read the content of the current web page", "get_page_text", {}, "safari"),
        ("List files in the vault", "list_files",
         {"path": "~/Documents/Epistemos"}, "file"),
        ("Read the content of CLAUDE.md", "read_file",
         {"path": "CLAUDE.md"}, "file"),
        ("Run cargo test in graph-engine", "run_command",
         {"command": "cd graph-engine && cargo test"}, "terminal"),
        ("Run swift build", "run_command",
         {"command": "swift build"}, "terminal"),
        ("Launch System Settings app", "launch_app",
         {"app_name": "System Settings"}, "automation"),
        ("Run the Daily Summary shortcut", "run_shortcut",
         {"name": "Daily Summary"}, "automation"),
    ]

    for desc, tool, args, agent in tool_calls:
        steps = [
            _step(
                desc,
                f"<think>User wants to {desc.lower()}. I'll use the {tool} tool via the {agent} agent. Arguments: {json.dumps(args)}</think>",
                _action(tool, args, agent=agent),
                LANDING_VIEW, LANDING_VIEW,
            ),
        ]
        results.append(_trajectory(desc, steps, "tool_call"))
    return results


# ===== CATEGORY 22: Window Management =====
def gen_window_management_trajectories():
    results = []

    actions = [
        ("Minimize the Epistemos window", "key_press", {"key_code": 46, "modifiers": 256}, "Cmd+M"),
        ("Close the current window", "key_press", {"key_code": 13, "modifiers": 256}, "Cmd+W"),
        ("Toggle full screen", "key_press", {"key_code": 3, "modifiers": 256 | 2048}, "Cmd+Ctrl+F"),
        ("Switch to next app", "key_press", {"key_code": 48, "modifiers": 256}, "Cmd+Tab"),
        ("Hide Epistemos", "key_press", {"key_code": 4, "modifiers": 256}, "Cmd+H"),
        ("Show all windows", "key_press", {"key_code": 48, "modifiers": 256 | 512}, "Cmd+Shift+Tab"),
    ]

    for desc, tool, args, shortcut in actions:
        steps = [
            _step(
                desc,
                f"<think>{desc} using {shortcut}. This is a window management operation.</think>",
                _action(tool, args),
                LANDING_VIEW, LANDING_VIEW,
            ),
        ]
        results.append(_trajectory(f"{desc} ({shortcut})", steps, "general"))
    return results


# ===== CATEGORY 23: Additional Note Variants =====
def gen_additional_note_trajectories():
    results = []

    # Create notes with different content types
    note_types = [
        ("Code Snippet: Graph Engine", "```rust\npub fn walk_ax_tree(pid: i64) -> AXTreeSnapshot {\n    // ...\n}\n```"),
        ("Meeting: Q2 Planning", "## Attendees\n- Alice\n- Bob\n\n## Agenda\n1. Review Q1\n2. Plan Q2"),
        ("Reading Note: Attention Is All You Need", "## Key Ideas\n- Self-attention mechanism\n- Multi-head attention\n- Positional encoding"),
        ("Bug Fix Log", "## Issue\nEditor crash on large paste\n\n## Root Cause\nUnbounded NSTextStorage insert\n\n## Fix\nChunk inserts to 64KB"),
        ("Architecture Decision: ODIA Format", "## Context\nNeed structured training traces\n\n## Decision\nODIA (Observe-Decide-Interact-Assess) format"),
    ]

    for title, body in note_types:
        editor = note_editor_view(title, body)
        steps = [
            _step(
                f"Create note: {title}",
                f"<think>Creating a new note for '{title}'. Clicking New Note button.</think>",
                _action("click_element", {"pid": 12345, "element_name": "New Note"}),
                LANDING_VIEW, note_editor_view("Untitled"),
            ),
            _step(
                f"Set title to '{title}'",
                f"<think>Setting the note title.</think>",
                _action("type_text", {"text": title}),
                note_editor_view("Untitled"), note_editor_view(title),
            ),
            _step(
                "Write note content",
                f"<think>Writing the note body content. This is a {'code snippet' if '```' in body else 'structured note'}.</think>",
                _action("type_text", {"text": body}),
                note_editor_view(title), editor,
            ),
        ]
        results.append(_trajectory(f"Create and write '{title}'", steps, "app_specific"))
    return results


# ===== CATEGORY 24: Additional Error Scenarios =====
def gen_additional_error_trajectories():
    results = []

    scenarios = [
        ("Handle permission denied for accessibility",
         "<think>Got permission denied trying to walk the AX tree. The app hasn't been granted accessibility access. I'll guide the user to System Settings > Privacy > Accessibility.</think>",
         _action("launch_app", {"app_name": "System Settings"}),
         "Permission denied: accessibility not granted"),
        ("Handle app not running when trying to automate",
         "<think>Tried to click element in Epistemos but the app isn't running (PID not found). I'll launch it first.</think>",
         _action("launch_app", {"app_name": "Epistemos"}),
         "App not running, launching first"),
        ("Handle network timeout during web search",
         "<think>Web search timed out. This might be a network issue. I'll retry with a simpler query.</think>",
         _action("search_web", {"query": "Mamba-2 paper"}, agent="safari"),
         "Network timeout, retrying with simpler query"),
    ]

    for desc, reasoning, action, error_context in scenarios:
        steps = [
            _step(
                desc,
                reasoning,
                action,
                LANDING_VIEW, LANDING_VIEW,
            ),
        ]
        results.append(_trajectory(desc, steps, "error_recovery"))
    return results


# ---------------------------------------------------------------------------
# SFT Chat Format Converter
# ---------------------------------------------------------------------------

SYSTEM_PROMPT_EMBODIED = """You are Epistemos-Nano, a 1B parameter on-device AI agent for macOS.
You control the Epistemos app and macOS system through accessibility APIs and tool calls.
You observe the accessibility tree before every action. You reason step-by-step inside <think>...</think> tags.
You output structured JSON tool calls after reasoning. You verify results through post-action AX tree diffs.
Your action loop: [OBSERVE] -> [REASON] -> [ACT] -> [RESULT] -> [DONE]."""

def trajectory_to_sft(trajectory: dict) -> dict:
    """Convert an embodied trajectory to chat-SFT format for training."""
    messages = [{"role": "system", "content": SYSTEM_PROMPT_EMBODIED}]

    user_content = f"Task: {trajectory['task_description']}"
    messages.append({"role": "user", "content": user_content})

    assistant_parts = []
    for i, step in enumerate(trajectory["steps"], 1):
        # Parse AX tree for summary
        try:
            ax = json.loads(step["accessibility_tree"])
            interactive = [e for e in ax.get("elements", []) if e.get("is_interactive")]
            ax_summary = f"[{len(interactive)} interactive elements: {', '.join(e.get('title','?') for e in interactive[:5])}]"
        except (json.JSONDecodeError, KeyError):
            ax_summary = "[AX tree available]"

        part = f"**Step {i} — [OBSERVE]:** {ax_summary}\n"
        part += f"**[REASON]:** {step['reasoning_chain']}\n"
        part += f"**[ACT]:** `{json.dumps(step['action'])}`\n"

        # Parse diff
        try:
            diff = json.loads(step.get("ax_diff", "{}"))
            added = diff.get("added_count", 0)
            removed = diff.get("removed_count", 0)
            part += f"**[RESULT]:** AX diff: +{added} -{removed} elements\n"
        except (json.JSONDecodeError, KeyError):
            part += f"**[RESULT]:** Action completed\n"

    assistant_parts.append(part)
    assistant_parts.append("**[DONE]:** Task completed successfully.")

    messages.append({"role": "assistant", "content": "\n".join(assistant_parts)})

    return {
        "messages": messages,
        "category": "embodied_trajectory",
        "layer": 4,
        "quality": 1.0,
        "task_type": trajectory.get("task_type", "general"),
        "step_count": trajectory["step_count"],
        "format": "embodied_v1",
    }


# ---------------------------------------------------------------------------
# Main Generation Pipeline
# ---------------------------------------------------------------------------

def generate_all_trajectories():
    """Generate all trajectory categories."""
    all_trajs = []

    generators = [
        ("create_note", gen_create_note_trajectories),
        ("search_notes", gen_search_note_trajectories),
        ("graph_navigation", gen_graph_navigation_trajectories),
        ("ai_chat", gen_ai_chat_trajectories),
        ("omega_tasks", gen_omega_trajectories),
        ("settings", gen_settings_trajectories),
        ("safari_research", gen_safari_research_trajectories),
        ("file_operations", gen_file_operation_trajectories),
        ("note_editing", gen_note_editing_trajectories),
        ("error_recovery", gen_error_recovery_trajectories),
        ("cross_app", gen_cross_app_trajectories),
        ("research_workflows", gen_research_workflow_trajectories),
        ("keyboard_navigation", gen_keyboard_navigation_trajectories),
        ("scroll_navigate", gen_scroll_trajectories),
        ("negative_refusal", gen_negative_trajectories),
        ("multi_tab", gen_multi_tab_trajectories),
        ("vault_sync", gen_vault_sync_trajectories),
        ("verification", gen_verification_trajectories),
        ("complex_workflows", gen_complex_workflow_trajectories),
        ("discard_undo", gen_discard_undo_trajectories),
        ("tool_calls", gen_tool_call_trajectories),
        ("window_management", gen_window_management_trajectories),
        ("additional_notes", gen_additional_note_trajectories),
        ("additional_errors", gen_additional_error_trajectories),
    ]

    for name, gen_fn in generators:
        trajs = gen_fn()
        for t in trajs:
            t["category"] = name
        all_trajs.extend(trajs)

    # Scale up with parameterized variants
    all_trajs.extend(gen_scaled_variants())

    return all_trajs


def gen_scaled_variants():
    """Generate 400+ additional trajectories by parameterizing templates."""
    results = []

    # --- Variant pool: diverse note titles ---
    note_titles = [
        "Swift Concurrency Deep Dive", "Mamba-2 vs Transformer Comparison",
        "Graph Engine Optimization Notes", "MLX Metal Performance Tips",
        "CoreML Deployment Checklist", "ODIA Trace Format Spec",
        "LoRA Rank Selection Guide", "AX Accessibility Patterns",
        "macOS Automation Cookbook", "Knowledge Distillation Survey",
        "Epistemos Architecture Overview", "MOHAWK Training Log",
        "WSD Scheduler Experiments", "Nightly Flywheel Debug Notes",
        "Research: Speculative Decoding", "Research: RLHF vs KTO",
        "Research: State Space Models", "Research: On-Device Inference",
        "Meeting: Training Pipeline Review", "Meeting: Q2 Roadmap",
        "Meeting: Model Evaluation Strategy", "Meeting: Data Collection Sprint",
        "Bug: Editor Crash on Large Paste", "Bug: Graph Render Flicker",
        "Bug: Vault Sync Race Condition", "Bug: AI Chat Token Overflow",
        "Todo: Implement IFD Filtering", "Todo: Build Eval Runner",
        "Todo: Wire Live AX Capture", "Todo: Collect KTO Feedback",
        "Reading: Attention Is All You Need", "Reading: Scaling Laws",
        "Reading: Constitutional AI", "Reading: Direct Preference Optimization",
        "Idea: Neural Cloud Shader", "Idea: Voice-to-Note Pipeline",
        "Idea: Auto-Wikilink Suggestions", "Idea: Graph Clustering",
        "Log: Training Run 001", "Log: Adapter Evaluation Results",
        "Comparison: MLX vs PyTorch Performance",
        "Comparison: Mamba vs RWKV vs Transformer",
        "Reference: macOS Keyboard Shortcuts",
        "Reference: AX Role Complete List",
        "Reference: Omega Tool Registry",
        "Checklist: Pre-Training Data Audit",
        "Checklist: Adapter Deployment Steps",
        "Checklist: App Store Submission",
        "Template: Research Paper Summary",
        "Template: Sprint Retrospective",
        "Template: Bug Triage Form",
        "Template: Architecture Decision Record",
        "Brainstorm: Next Feature Priorities",
        "Brainstorm: User Onboarding Flow",
        "Brainstorm: Knowledge Graph Visualizations",
        "Draft: Blog Post on Epistemos Architecture",
        "Draft: Technical Documentation for omega-ax",
        "Draft: API Reference for MCP Tools",
        "Glossary: Epistemos Domain Terms",
    ]

    # --- Variant pool: search queries ---
    search_queries = [
        "Mamba architecture", "training scheduler", "graph engine",
        "SwiftUI views", "ODIA traces", "accessibility API",
        "LoRA adapter", "Metal GPU", "knowledge fusion",
        "vault sync", "note editor", "AI chat",
        "research orchestrator", "confirmation gate", "task graph",
        "MLX inference", "constrained decoding", "recipe graph",
        "ghost brain", "agent memory", "tool registry",
        "heuristic planner", "risk evaluation", "confidence scoring",
        "error recovery", "wikilink", "markdown rendering",
        "TextKit 2", "NSTextStorage", "ProseEditorView",
        "AppBootstrap", "EpistemosApp", "StatusBar",
        "NoteWindowManager", "NoteTabView", "NoteChatState",
        "GraphBuilder", "GraphStore", "PhysicsCoordinator",
        "MetalGraphView", "HologramController", "HologramOverlay",
        "DeviceAgentService", "DualBrainRouter", "HardwareTierManager",
        "AdapterRegistry", "QLoRATrainer", "PythonEnvironmentManager",
        "FeedbackLogger", "CSISafeguard", "ExperimentTracker",
    ]

    # --- Variant pool: research topics ---
    research_topics = [
        "Mamba-3 improvements over Mamba-2",
        "Low-rank adaptation for small language models",
        "Accessibility-driven UI testing automation",
        "On-device knowledge distillation with MOHAWK",
        "Speculative decoding for faster inference",
        "KTO vs DPO for preference alignment",
        "Curriculum learning for agent training",
        "Multi-modal grounding with AX trees",
        "Personal LoRA adaptation strategies",
        "GRPO reinforcement learning for tool use",
        "Data quality filtering with IFD scoring",
        "Nightly training flywheel architecture",
        "State space models for sequence modeling",
        "Screen2AX dataset for UI understanding",
        "AgentTrek: mining macOS automation traces",
        "MoLoRA routing for adapter hot-swap",
        "WSD vs cosine learning rate schedules",
        "Embedding-based retrieval for notes",
        "CRDT-based collaborative editing",
        "Zero-trust MCP gateway design",
    ]

    # --- Variant pool: terminal commands ---
    terminal_commands = [
        ("Check git status", "git status"),
        ("Show git log", "git log --oneline -10"),
        ("List Swift files", "find . -name '*.swift' | head -20"),
        ("Count lines of code", "find . -name '*.swift' -exec cat {} + | wc -l"),
        ("Check disk space", "df -h /"),
        ("Show running processes", "ps aux | head -20"),
        ("Check Rust version", "rustc --version"),
        ("Run clippy", "cd graph-engine && cargo clippy"),
        ("Show memory usage", "vm_stat"),
        ("Check network", "ping -c 1 google.com"),
    ]

    # --- Variant pool: macOS apps ---
    mac_apps = [
        "Safari", "Finder", "Terminal", "Notes", "Calendar",
        "Mail", "Messages", "Preview", "TextEdit", "Activity Monitor",
        "System Settings", "Xcode", "Music", "Photos", "Maps",
    ]

    # --- Variant pool: AI operations ---
    ai_operations = [
        ("Summarize this note", "summarize"),
        ("Rewrite the introduction", "rewrite"),
        ("Expand the key points", "expand"),
        ("Create an outline", "outline"),
        ("Simplify the language", "simplify"),
        ("Continue from where I left off", "continue"),
        ("Convert to bullet points", "toList"),
        ("Structure this into sections", "structure"),
        ("Restructure for clarity", "restructure"),
    ]

    # --- 1. Create note variants (40 trajectories) ---
    for title in note_titles:
        editor = note_editor_view(title)
        steps = [
            _step(
                "Create a new note",
                "<think>I need to create a note titled '{}'. Clicking the New Note button in the toolbar.</think>".format(title),
                _action("click_element", {"pid": 12345, "element_name": "New Note"}),
                LANDING_VIEW, note_editor_view("Untitled"),
            ),
            _step(
                "Set note title",
                "<think>Note editor is open. Setting the title to '{}'.</think>".format(title),
                _action("type_text", {"text": title}),
                note_editor_view("Untitled"), editor,
            ),
        ]
        results.append(_trajectory("Create note: {}".format(title), steps, "app_specific"))
        results[-1]["category"] = "create_note_variant"

    # --- 2. Search variants (30 trajectories) ---
    for q in search_queries:
        steps = [
            _step(
                "Search for '{}'".format(q),
                "<think>I need to find notes about '{}'. Clicking the search field in the sidebar.</think>".format(q),
                _action("click_element", {"pid": 12345, "element_name": "Search notes..."}),
                LANDING_VIEW, LANDING_VIEW,
            ),
            _step(
                "Type search query",
                "<think>Search field focused. Typing '{}'.</think>".format(q),
                _action("type_text", {"text": q}),
                LANDING_VIEW, note_editor_view("Results: {}".format(q)),
            ),
        ]
        results.append(_trajectory("Search notes for '{}'".format(q), steps, "app_specific"))
        results[-1]["category"] = "search_variant"

    # --- 3. Research workflow variants (20 trajectories) ---
    for topic in research_topics:
        steps = [
            _step(
                "Open Omega for research",
                "<think>Starting a research task about '{}'. Opening Omega panel.</think>".format(topic),
                _action("click_element", {"pid": 12345, "element_name": "Omega"}),
                LANDING_VIEW, OMEGA_PANEL,
            ),
            _step(
                "Submit research task",
                "<think>Typing the research query. Omega will plan search → collect → analyze → synthesize.</think>",
                _action("type_text", {"text": "research: {}".format(topic)}),
                OMEGA_PANEL, OMEGA_PANEL,
            ),
            _step(
                "Send research request",
                "<think>Submitting to Omega for execution.</think>",
                _action("click_element", {"pid": 12345, "element_name": "Send"}),
                OMEGA_PANEL, OMEGA_PANEL,
            ),
        ]
        results.append(_trajectory("Research: {}".format(topic), steps, "research"))
        results[-1]["category"] = "research_variant"

    # --- 4. AI chat operation variants (54 trajectories = 6 notes x 9 ops) ---
    sample_notes = ["Research Notes", "Meeting Notes", "Project Ideas",
                     "Training Guide", "Architecture Doc", "Bug Report",
                     "Daily Journal", "Reading List", "Sprint Retro",
                     "Code Review", "Design Document", "Release Notes"]
    for note_title in sample_notes:
        for query, op in ai_operations:
            pre = note_editor_view(note_title, "Content of {} ...".format(note_title))
            chat = ai_chat_view(note_title, query, "AI {} result...".format(op))
            steps = [
                _step(
                    "Open AI chat",
                    "<think>I need to {} the note '{}'. Opening AI chat panel.</think>".format(op, note_title),
                    _action("click_element", {"pid": 12345, "element_name": "AI Chat"}),
                    pre, chat,
                ),
                _step(
                    "Send query: {}".format(query),
                    "<think>Chat panel open. Typing '{}' and sending.</think>".format(query),
                    _action("type_text", {"text": query}),
                    chat, chat,
                ),
                _step(
                    "Send message",
                    "<think>Sending the AI request.</think>",
                    _action("click_element", {"pid": 12345, "element_name": "Send"}),
                    chat, ai_chat_view(note_title, query, "Completed {} of the note content.".format(op)),
                ),
                _step(
                    "Accept result",
                    "<think>AI generated a good {} result. Accepting.</think>".format(op),
                    _action("click_element", {"pid": 12345, "element_name": "Accept"}),
                    ai_chat_view(note_title, query, "Result..."),
                    note_editor_view(note_title, "[{} applied]".format(op)),
                ),
            ]
            results.append(_trajectory("{} on '{}'".format(query, note_title), steps, "app_specific"))
            results[-1]["category"] = "ai_chat_variant"

    # --- 5. Terminal command variants (10 trajectories) ---
    for desc, cmd in terminal_commands:
        steps = [
            _step(
                desc,
                "<think>Running terminal command: {}. Using run_command tool.</think>".format(cmd),
                _action("run_command", {"command": cmd}, agent="terminal"),
                LANDING_VIEW, LANDING_VIEW,
            ),
        ]
        results.append(_trajectory(desc, steps, "general"))
        results[-1]["category"] = "terminal_variant"

    # --- 6. App launch variants (15 trajectories) ---
    for app in mac_apps:
        steps = [
            _step(
                "Launch {}".format(app),
                "<think>User wants to open {}. Using launch_app tool.</think>".format(app),
                _action("launch_app", {"app_name": app}),
                LANDING_VIEW, LANDING_VIEW,
            ),
        ]
        results.append(_trajectory("Open {}".format(app), steps, "general"))
        results[-1]["category"] = "app_launch_variant"

    # --- 7. Safari research with diverse URLs (20 trajectories) ---
    safari_searches = [
        ("Mamba-2 architecture paper", "https://arxiv.org/search/?query=mamba+2"),
        ("MOHAWK distillation technique", "https://arxiv.org/search/?query=mohawk"),
        ("MLX framework documentation", "https://ml-explore.github.io/mlx/"),
        ("SwiftUI accessibility guide", "https://developer.apple.com/documentation/swiftui/accessibility"),
        ("CoreML model conversion", "https://developer.apple.com/documentation/coreml"),
        ("macOS automation with AppleScript", "https://developer.apple.com/library/archive/documentation/AppleScript/"),
        ("LoRA fine-tuning best practices", "https://arxiv.org/search/?query=lora+fine+tuning"),
        ("State space model survey", "https://arxiv.org/search/?query=state+space+model"),
        ("Knowledge distillation methods", "https://arxiv.org/search/?query=knowledge+distillation"),
        ("On-device AI inference optimization", "https://arxiv.org/search/?query=on+device+inference"),
        ("Reinforcement learning from human feedback", "https://arxiv.org/search/?query=rlhf"),
        ("Direct preference optimization paper", "https://arxiv.org/search/?query=DPO"),
        ("Constitutional AI approach", "https://arxiv.org/search/?query=constitutional+AI"),
        ("Speculative decoding techniques", "https://arxiv.org/search/?query=speculative+decoding"),
        ("CRDT collaborative editing", "https://arxiv.org/search/?query=crdt+collaborative"),
        ("Metal GPU compute shaders", "https://developer.apple.com/documentation/metal"),
        ("Rust FFI with Swift", "https://github.com/nicklockwood/SwiftFormat"),
        ("Graph neural networks", "https://arxiv.org/search/?query=graph+neural+network"),
        ("Attention mechanism variants", "https://arxiv.org/search/?query=attention+mechanism"),
        ("Data augmentation for NLP", "https://arxiv.org/search/?query=data+augmentation+nlp"),
        ("Mixture of experts architecture", "https://arxiv.org/search/?query=mixture+of+experts"),
        ("Retrieval augmented generation", "https://arxiv.org/search/?query=retrieval+augmented+generation"),
        ("Flash attention optimization", "https://arxiv.org/search/?query=flash+attention"),
        ("Parameter efficient fine-tuning survey", "https://arxiv.org/search/?query=peft+survey"),
        ("Vision language models", "https://arxiv.org/search/?query=vision+language+model"),
        ("Reward modeling for RLHF", "https://arxiv.org/search/?query=reward+model+rlhf"),
        ("Quantization aware training", "https://arxiv.org/search/?query=quantization+aware+training"),
        ("Instruction tuning datasets", "https://arxiv.org/search/?query=instruction+tuning"),
        ("Chain of thought prompting", "https://arxiv.org/search/?query=chain+of+thought"),
        ("Tool use in language models", "https://arxiv.org/search/?query=tool+use+language+model"),
        ("Apple Neural Engine optimization", "https://developer.apple.com/documentation/coreml"),
        ("SwiftUI performance profiling", "https://developer.apple.com/documentation/swiftui"),
        ("macOS security sandboxing", "https://developer.apple.com/documentation/security"),
        ("Combine framework patterns", "https://developer.apple.com/documentation/combine"),
        ("Structured concurrency Swift", "https://developer.apple.com/documentation/swift/concurrency"),
        ("Metal shader best practices", "https://developer.apple.com/documentation/metal"),
        ("App Intents framework", "https://developer.apple.com/documentation/appintents"),
        ("SwiftData migration guide", "https://developer.apple.com/documentation/swiftdata"),
        ("ScreenCaptureKit API", "https://developer.apple.com/documentation/screencapturekit"),
    ]
    for query, url in safari_searches:
        safari = safari_view(url, "Search: {}".format(query))
        steps = [
            _step(
                "Open Safari",
                "<think>Need to research '{}'. Launching Safari.</think>".format(query),
                _action("launch_app", {"app_name": "Safari"}),
                LANDING_VIEW, safari_view(),
            ),
            _step(
                "Navigate to search",
                "<think>Clicking address bar to type the URL.</think>",
                _action("click_element", {"pid": 54321, "element_name": "Address Bar"}),
                safari_view(), safari_view(),
            ),
            _step(
                "Type URL",
                "<think>Typing the search URL.</think>",
                _action("type_text", {"text": url}),
                safari_view(), safari,
            ),
            _step(
                "Navigate",
                "<think>Pressing Enter to load the page.</think>",
                _action("key_press", {"key_code": 36, "modifiers": 0}),
                safari, safari,
            ),
        ]
        results.append(_trajectory("Research '{}' in Safari".format(query), steps, "research"))
        results[-1]["category"] = "safari_variant"

    # --- 8. Cross-app copy-paste variants (10 trajectories) ---
    copy_sources = [
        ("Safari", "research paper abstract"),
        ("Notes", "meeting action items"),
        ("Mail", "project requirements"),
        ("Messages", "quick idea"),
        ("Preview", "PDF excerpt"),
        ("TextEdit", "draft text"),
        ("Terminal", "command output"),
        ("Finder", "file path"),
        ("Calendar", "event details"),
        ("Maps", "location info"),
    ]
    for source_app, content_type in copy_sources:
        steps = [
            _step(
                "Select text in {}".format(source_app),
                "<think>I need to copy {} from {}. Selecting text first.</think>".format(content_type, source_app),
                _action("key_press", {"key_code": 0, "modifiers": 256}),
                safari_view() if source_app == "Safari" else LANDING_VIEW,
                safari_view() if source_app == "Safari" else LANDING_VIEW,
            ),
            _step(
                "Copy to clipboard",
                "<think>Copying with Cmd+C.</think>",
                _action("key_press", {"key_code": 8, "modifiers": 256}),
                LANDING_VIEW, LANDING_VIEW,
            ),
            _step(
                "Switch to Epistemos",
                "<think>Switching to Epistemos to paste the {}.</think>".format(content_type),
                _action("launch_app", {"app_name": "Epistemos"}),
                LANDING_VIEW, LANDING_VIEW,
            ),
            _step(
                "Create a new note and paste",
                "<think>Creating a note for the pasted content.</think>",
                _action("click_element", {"pid": 12345, "element_name": "New Note"}),
                LANDING_VIEW, note_editor_view("Untitled"),
            ),
            _step(
                "Paste content",
                "<think>Pasting the copied {} with Cmd+V.</think>".format(content_type),
                _action("key_press", {"key_code": 9, "modifiers": 256}),
                note_editor_view("Untitled"),
                note_editor_view("Untitled", "{} pasted...".format(content_type)),
            ),
        ]
        results.append(_trajectory("Copy {} from {} to Epistemos note".format(content_type, source_app), steps, "general"))
        results[-1]["category"] = "cross_app_variant"

    # --- 9. Graph exploration variants (15 trajectories) ---
    graph_nodes = [
        "Research Notes", "Meeting Notes", "Project Ideas", "Training Guide",
        "Architecture Doc", "Bug Report", "Graph Engine", "TriageService",
        "ProseEditorView", "VaultSyncService", "AgentGraphMemory",
        "RecipeGraphSkills", "OrchestratorState", "MCPBridge", "LLMService",
    ]
    for node in graph_nodes:
        steps = [
            _step(
                "Open graph view",
                "<think>Navigating to graph to find '{}'.</think>".format(node),
                _action("click_element", {"pid": 12345, "element_name": "Graph"}),
                LANDING_VIEW, GRAPH_VIEW,
            ),
            _step(
                "Search for node",
                "<think>Searching for '{}' in the graph sidebar.</think>".format(node),
                _action("click_element", {"pid": 12345, "element_name": "Search graph..."}),
                GRAPH_VIEW, GRAPH_VIEW,
            ),
            _step(
                "Type node name",
                "<think>Typing '{}' to find the node.</think>".format(node),
                _action("type_text", {"text": node}),
                GRAPH_VIEW, GRAPH_VIEW,
            ),
            _step(
                "Click on the node",
                "<think>Found '{}'. Clicking to focus it in the graph.</think>".format(node),
                _action("click_element", {"pid": 12345, "element_name": node}),
                GRAPH_VIEW, GRAPH_VIEW,
            ),
        ]
        results.append(_trajectory("Find and focus '{}' in knowledge graph".format(node), steps, "app_specific"))
        results[-1]["category"] = "graph_variant"

    # --- 10. Multi-step complex workflows (30 trajectories) ---
    complex_tasks = [
        ("Create a note, add content, and view it in the graph",
         ["create_note", "type_text", "navigate_graph"], "app_specific"),
        ("Search for a note, open it, and ask AI to summarize",
         ["search", "open_note", "ai_summarize"], "app_specific"),
        ("Research a topic and create a note from findings",
         ["omega_research", "create_note", "type_text"], "research"),
        ("Open settings, enable training, and verify with Omega",
         ["settings", "enable_training", "omega_verify"], "app_specific"),
        ("Open Safari, search, copy text, paste into note",
         ["launch_safari", "search", "copy", "paste_note"], "research"),
    ]
    for i in range(30):
        task_desc, step_names, task_type = complex_tasks[i % len(complex_tasks)]
        variant = "variant_{}".format(i)
        all_steps = []
        for j, sn in enumerate(step_names):
            pre = LANDING_VIEW if j == 0 else note_editor_view("Note {}".format(i))
            post = note_editor_view("Note {}".format(i)) if j < len(step_names) - 1 else GRAPH_VIEW
            all_steps.append(_step(
                "{} (step {})".format(sn, j + 1),
                "<think>Executing step {} of {}: {}. This is part of a multi-step workflow.</think>".format(
                    j + 1, len(step_names), sn),
                _action("click_element", {"pid": 12345, "element_name": sn}),
                pre, post,
            ))
        results.append(_trajectory("{} ({})".format(task_desc, variant), all_steps, task_type))
        results[-1]["category"] = "complex_variant"

    # --- 11. Direct tool call variants (40 trajectories) ---
    direct_tools = [
        ("create_note", {"title": "Quick Note", "body": "Draft..."}, "notes"),
        ("search_notes", {"query": "architecture"}, "notes"),
        ("edit_note", {"title": "Draft", "body": "Updated"}, "notes"),
        ("delete_note", {"title": "temp"}, "notes"),
        ("open_url", {"url": "https://arxiv.org"}, "safari"),
        ("get_page_url", {}, "safari"),
        ("get_page_title", {}, "safari"),
        ("get_page_text", {}, "safari"),
        ("search_web", {"query": "Mamba SSM"}, "safari"),
        ("list_files", {"path": "~/Documents"}, "file"),
        ("read_file", {"path": "CLAUDE.md"}, "file"),
        ("run_command", {"command": "ls -la"}, "terminal"),
        ("run_command", {"command": "git diff --stat"}, "terminal"),
        ("launch_app", {"app_name": "Safari"}, "automation"),
        ("run_shortcut", {"name": "Daily Summary"}, "automation"),
        ("click_element", {"pid": 12345, "element_name": "Save"}, "automation"),
        ("type_text", {"text": "Hello"}, "automation"),
        ("key_press", {"key_code": 36, "modifiers": 0}, "automation"),
        ("scroll", {"selector": "AXScrollArea", "value": "down:3"}, "automation"),
        ("walk_ax_tree", {"pid": 12345}, "automation"),
    ]
    for i, (tool, args, agent) in enumerate(direct_tools):
        for variant_idx in range(2):
            desc = "Tool call: {} ({})".format(tool, variant_idx)
            steps = [
                _step(
                    desc,
                    "<think>Executing {} tool via {} agent. Args: {}</think>".format(tool, agent, json.dumps(args)),
                    _action(tool, args, agent=agent),
                    LANDING_VIEW, LANDING_VIEW,
                ),
            ]
            results.append(_trajectory(desc, steps, "tool_call"))
            results[-1]["category"] = "direct_tool_variant"

    # --- 12. Error recovery variants (20 trajectories) ---
    error_scenarios = [
        "AXError: kAXErrorCannotComplete on button click",
        "Element not found: 'Export' button missing from AX tree",
        "Timeout: click_element took >5s, app may be frozen",
        "Sparse AX tree: only 2 interactive elements found",
        "Permission denied: accessibility not granted",
        "App not running: Epistemos process not found",
        "Network timeout during web search",
        "Modal dialog blocking: unsaved changes prompt",
        "Text field not editable: read-only mode active",
        "Invalid PID: process terminated during operation",
    ]
    for i, scenario in enumerate(error_scenarios):
        for recovery in ["keyboard_shortcut", "retry_after_wait"]:
            steps = [
                _step(
                    "Encounter error: {}".format(scenario),
                    "<think>Got error: {}. Recovery strategy: {}. Attempting alternative approach.</think>".format(
                        scenario, recovery),
                    _action("key_press" if recovery == "keyboard_shortcut" else "click_element",
                            {"key_code": 36, "modifiers": 0} if recovery == "keyboard_shortcut"
                            else {"pid": 12345, "element_name": "retry"}),
                    LANDING_VIEW, LANDING_VIEW,
                ),
            ]
            results.append(_trajectory("Error recovery: {} via {}".format(scenario, recovery), steps, "error_recovery"))
            results[-1]["category"] = "error_variant"

    # --- 13. Wikilink insertion variants (35 trajectories) ---
    wikilink_pairs = [
        ("Research Notes", "Training Guide"),
        ("Meeting Notes", "Project Ideas"),
        ("Architecture Doc", "Graph Engine"),
        ("Bug Report", "Editor Crash"),
        ("Training Guide", "MOHAWK Training Log"),
        ("Mamba-2 vs Transformer Comparison", "State Space Models"),
        ("LoRA Rank Selection Guide", "Adapter Evaluation Results"),
        ("Knowledge Distillation Survey", "MOHAWK Training Log"),
        ("Swift Concurrency Deep Dive", "Architecture Doc"),
        ("Graph Engine Optimization Notes", "Graph Engine"),
        ("AX Accessibility Patterns", "Omega Tool Registry"),
        ("macOS Automation Cookbook", "AX Accessibility Patterns"),
        ("Epistemos Architecture Overview", "Architecture Doc"),
        ("Research: Speculative Decoding", "Research: On-Device Inference"),
        ("Research: RLHF vs KTO", "Research: State Space Models"),
        ("Meeting: Training Pipeline Review", "Training Guide"),
        ("Meeting: Q2 Roadmap", "Project Ideas"),
        ("Bug: Editor Crash on Large Paste", "Bug Report"),
        ("Bug: Graph Render Flicker", "Graph Engine"),
        ("Todo: Implement IFD Filtering", "Training Guide"),
        ("Todo: Build Eval Runner", "Adapter Evaluation Results"),
        ("Reading: Attention Is All You Need", "Research Notes"),
        ("Reading: Scaling Laws", "Knowledge Distillation Survey"),
        ("Idea: Neural Cloud Shader", "Graph Engine"),
        ("Idea: Voice-to-Note Pipeline", "Architecture Doc"),
        ("Log: Training Run 001", "MOHAWK Training Log"),
        ("Checklist: Pre-Training Data Audit", "Training Guide"),
        ("Reference: macOS Keyboard Shortcuts", "macOS Automation Cookbook"),
        ("Template: Research Paper Summary", "Research Notes"),
        ("Draft: Blog Post on Epistemos Architecture", "Architecture Doc"),
        ("Glossary: Epistemos Domain Terms", "Epistemos Architecture Overview"),
        ("Comparison: MLX vs PyTorch Performance", "Training Guide"),
        ("Brainstorm: Next Feature Priorities", "Project Ideas"),
        ("Brainstorm: Knowledge Graph Visualizations", "Graph Engine"),
        ("Draft: Technical Documentation for omega-ax", "AX Accessibility Patterns"),
    ]
    for source, target in wikilink_pairs:
        editor = note_editor_view(source, "Existing content of {} ...".format(source))
        steps = [
            _step(
                "Open note '{}'".format(source),
                "<think>I need to add a wikilink from '{}' to '{}'. First, opening the source note.</think>".format(source, target),
                _action("click_element", {"pid": 12345, "element_name": source}),
                LANDING_VIEW, editor,
            ),
            _step(
                "Navigate to end of note",
                "<think>Moving cursor to the end of the note body to add the link.</think>",
                _action("key_press", {"key_code": 119, "modifiers": 256}),
                editor, editor,
            ),
            _step(
                "Insert wikilink to '{}'".format(target),
                "<think>Inserting wikilink [[{}]] at cursor position. This creates a bidirectional connection in the knowledge graph.</think>".format(target),
                _action("type_text", {"text": "\n\nSee also: [[{}]]".format(target)}),
                editor, note_editor_view(source, "Content... See also: [[{}]]".format(target)),
            ),
        ]
        results.append(_trajectory("Add wikilink from '{}' to '{}'".format(source, target), steps, "app_specific"))
        results[-1]["category"] = "wikilink_variant"

    # --- 14. Negative/refusal variants (20 trajectories) ---
    refusal_questions = [
        "What is the meaning of life?",
        "Write me a poem about the ocean",
        "Tell me a joke",
        "What's the weather like today?",
        "How do I cook pasta?",
        "What is quantum computing?",
        "Explain blockchain to me",
        "Who won the World Cup in 2022?",
        "What's 2 + 2?",
        "Translate 'hello' to French",
        "Can you sing a song?",
        "What color is the sky?",
        "Who is the president?",
        "How many planets are there?",
        "What's the speed of light?",
        "Define 'epistemology'",
        "What's the capital of France?",
        "How far is the moon?",
        "What is machine learning?",
        "Explain gravity to a child",
    ]
    for q in refusal_questions:
        steps = [
            _step(
                q,
                "<think>This is a general knowledge question, not a tool-use task. I should respond conversationally without calling any tools.</think>",
                _action("respond_text", {"text": "[conversational response]"}, agent="none"),
                LANDING_VIEW, LANDING_VIEW,
            ),
        ]
        results.append(_trajectory("No-tool question: {}".format(q), steps, "negative"))
        results[-1]["category"] = "negative_variant"

    # --- 11. Omega task variants (20 trajectories) ---
    omega_tasks = [
        ("Summarize all my notes from this week", "general"),
        ("Find files modified in the last 24 hours", "general"),
        ("Run the full test suite and report failures", "general"),
        ("Search for papers about attention mechanisms", "research"),
        ("Organize my notes by topic", "general"),
        ("Create a bibliography from my research notes", "research"),
        ("Check for broken wikilinks in my vault", "general"),
        ("Export my notes as markdown files", "general"),
        ("Find duplicate notes in the vault", "general"),
        ("Search for 'TODO' items across all notes", "general"),
        ("Research: efficient inference on Apple Silicon", "research"),
        ("Research: CRDT algorithms for collaborative editing", "research"),
        ("Research: zero-shot tool use in language models", "research"),
        ("Research: privacy-preserving machine learning", "research"),
        ("Build a knowledge graph from my reading notes", "general"),
        ("Analyze the complexity of my note interconnections", "general"),
        ("Search the web for macOS 26 API changes", "research"),
        ("Research: LoRA merge strategies", "research"),
        ("Count words across all my notes", "general"),
        ("Find notes that reference 'Mamba' but not 'Transformer'", "general"),
    ]
    for task_desc, task_type in omega_tasks:
        steps = [
            _step(
                "Open Omega",
                "<think>Submitting task to Omega: '{}'.</think>".format(task_desc),
                _action("click_element", {"pid": 12345, "element_name": "Omega"}),
                LANDING_VIEW, OMEGA_PANEL,
            ),
            _step(
                "Type task",
                "<think>Entering the task description.</think>",
                _action("type_text", {"text": task_desc}),
                OMEGA_PANEL, OMEGA_PANEL,
            ),
            _step(
                "Submit",
                "<think>Sending the task for execution.</think>",
                _action("click_element", {"pid": 12345, "element_name": "Send"}),
                OMEGA_PANEL, OMEGA_PANEL,
            ),
        ]
        results.append(_trajectory("Omega: {}".format(task_desc), steps, task_type))
        results[-1]["category"] = "omega_variant"

    # --- 16. Combinatorial create->edit->AI->graph workflows (500 trajectories) ---
    # Cross-product of note titles × action sequences for maximum diversity
    action_sequences = [
        ("create_and_ai_summarize", [
            ("Create note", "click_element", {"element_name": "New Note"}, LANDING_VIEW, None),
            ("Set title", "type_text", {}, None, None),
            ("Ask AI to summarize", "click_element", {"element_name": "AI Chat"}, None, None),
            ("Send summary request", "type_text", {"text": "Summarize this note"}, None, None),
            ("Accept result", "click_element", {"element_name": "Accept"}, None, None),
        ]),
        ("create_and_view_graph", [
            ("Create note", "click_element", {"element_name": "New Note"}, LANDING_VIEW, None),
            ("Set title", "type_text", {}, None, None),
            ("View in graph", "click_element", {"element_name": "Graph"}, None, GRAPH_VIEW),
        ]),
        ("search_and_edit", [
            ("Search", "click_element", {"element_name": "Search notes..."}, LANDING_VIEW, None),
            ("Type query", "type_text", {}, None, None),
            ("Open result", "click_element", {"element_name": "first_result"}, None, None),
            ("Edit content", "type_text", {"text": "Updated content"}, None, None),
        ]),
        ("search_and_ai_expand", [
            ("Search", "click_element", {"element_name": "Search notes..."}, LANDING_VIEW, None),
            ("Type query", "type_text", {}, None, None),
            ("Open AI chat", "click_element", {"element_name": "AI Chat"}, None, None),
            ("Ask to expand", "type_text", {"text": "Expand the key points"}, None, None),
            ("Send", "click_element", {"element_name": "Send"}, None, None),
            ("Accept", "click_element", {"element_name": "Accept"}, None, None),
        ]),
        ("create_with_wikilinks", [
            ("Create note", "click_element", {"element_name": "New Note"}, LANDING_VIEW, None),
            ("Set title", "type_text", {}, None, None),
            ("Add wikilink", "type_text", {"text": "See also: [[Related Note]]"}, None, None),
        ]),
    ]

    combo_count = 0
    for title in note_titles:
        for seq_name, steps_template in action_sequences:
            all_steps = []
            for j, (desc, tool, args, pre_override, post_override) in enumerate(steps_template):
                actual_args = dict(args)
                if tool == "type_text" and "text" not in actual_args:
                    actual_args["text"] = title
                if "element_name" not in actual_args and tool == "click_element":
                    actual_args = {"pid": 12345, "element_name": desc.split()[-1]}

                pre = pre_override if pre_override else note_editor_view(title)
                post = post_override if post_override else note_editor_view(title, "Content...")

                all_steps.append(_step(
                    "{}: {}".format(desc, title[:30]),
                    "<think>Step {} of workflow '{}' for '{}'. Executing {} with {}.</think>".format(
                        j + 1, seq_name, title[:30], tool, json.dumps(actual_args)[:80]),
                    _action(tool, actual_args),
                    pre, post,
                ))
            results.append(_trajectory("{}: {}".format(seq_name, title), all_steps, "app_specific"))
            results[-1]["category"] = "combo_workflow"
            combo_count += 1

    return results


def main():
    parser = argparse.ArgumentParser(description="Generate embodied trajectories for Epistemos-Nano training")
    parser.add_argument("--output-dir", default=None,
                        help="Output directory (default: MOHAWK/embodied_data/)")
    parser.add_argument("--count", type=int, default=0,
                        help="Limit number of trajectories (0 = all)")
    args = parser.parse_args()

    output_dir = args.output_dir or os.path.join(os.path.dirname(__file__), "embodied_data")
    os.makedirs(output_dir, exist_ok=True)

    print("Generating embodied trajectories...")
    trajectories = generate_all_trajectories()

    if args.count > 0:
        trajectories = trajectories[:args.count]

    # Shuffle for training diversity
    random.seed(42)
    random.shuffle(trajectories)

    # Write raw embodied trajectories
    raw_path = os.path.join(output_dir, "embodied_trajectories.jsonl")
    with open(raw_path, "w") as f:
        for t in trajectories:
            f.write(json.dumps(t) + "\n")
    print(f"  Written {len(trajectories)} raw trajectories -> {raw_path}")

    # Write SFT chat format
    sft_path = os.path.join(output_dir, "embodied_trajectories_sft.jsonl")
    with open(sft_path, "w") as f:
        for t in trajectories:
            sft = trajectory_to_sft(t)
            f.write(json.dumps(sft) + "\n")
    print(f"  Written {len(trajectories)} SFT trajectories -> {sft_path}")

    # Category stats
    categories = {}
    task_types = {}
    total_steps = 0
    for t in trajectories:
        cat = t.get("category", "unknown")
        categories[cat] = categories.get(cat, 0) + 1
        tt = t.get("task_type", "general")
        task_types[tt] = task_types.get(tt, 0) + 1
        total_steps += t.get("step_count", len(t.get("steps", [])))

    # Write generation report
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_trajectories": len(trajectories),
        "total_steps": total_steps,
        "avg_steps_per_trajectory": round(total_steps / max(len(trajectories), 1), 1),
        "categories": dict(sorted(categories.items(), key=lambda x: -x[1])),
        "task_types": dict(sorted(task_types.items(), key=lambda x: -x[1])),
        "schema_version": "1.0.0",
        "format": "embodied_v1",
        "schema_fields": [
            "task_description", "steps[].instruction", "steps[].accessibility_tree",
            "steps[].screenshot", "steps[].reasoning_chain", "steps[].action",
            "steps[].result_accessibility_tree", "steps[].result_screenshot", "steps[].ax_diff",
        ],
        "output_files": {
            "raw_trajectories": raw_path,
            "sft_trajectories": sft_path,
        },
    }

    report_path = os.path.join(output_dir, "generation_report.json")
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)
    print(f"  Generation report -> {report_path}")

    print(f"\nDone! {len(trajectories)} trajectories, {total_steps} total steps across {len(categories)} categories.")
    print(f"Category breakdown:")
    for cat, count in sorted(categories.items(), key=lambda x: -x[1]):
        print(f"  {cat}: {count}")
    print(f"Task type breakdown:")
    for tt, count in sorted(task_types.items(), key=lambda x: -x[1]):
        print(f"  {tt}: {count}")


if __name__ == "__main__":
    main()
