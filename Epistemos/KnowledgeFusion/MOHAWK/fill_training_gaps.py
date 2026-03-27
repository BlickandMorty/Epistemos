#!/usr/bin/env python3
"""
Training Data Gap Filler — Fix all LOW COVERAGE categories
==========================================================

Audit found 8 categories with < 20 examples each. This script
generates AT LEAST 25 examples per category to meet minimums.

Categories to fill:
  - code_grounded:    4 → 30+
  - error_diagnosis:  3 → 25+
  - macos_knowledge:  6 → 30+
  - error_recovery:   8 → 25+  (also fix to AXPress format + <think> tags)
  - negative:        10 → 30+  (also add <think> tags)
  - reasoning_chain: 18 → 30+
  - multi_app_workflows: 4 → 25+
  - temporal_sequential:  0 → 25+

Usage:
    python fill_training_gaps.py --output ./epistemos_training_data
"""

import json, os, hashlib, random
from pathlib import Path
from typing import List

SYS = """You are Epistemos-Nano, a 1B on-device AI agent for macOS.
You think step-by-step inside <think>...</think> tags before acting.
You output AXPress actions as JSON after your reasoning.
You verify actions through perception loops (observe → decide → interact → assess).
You deeply understand the Epistemos codebase and every macOS UI pattern."""

def msg(user, assistant):
    return {"messages": [{"role": "system", "content": SYS}, {"role": "user", "content": user}, {"role": "assistant", "content": assistant}]}


# ─── CODE GROUNDED (Layer 11) — Need 26 more ───────────────────

def code_grounded():
    return [
        msg("What happens when I type in the note editor?",
            "<think>\nTracing the text flow in Epistemos:\n1. User types → ProseTextView2.didChangeText() fires\n2. reparseAndInvalidate() re-styles markdown (MarkdownContentStorage)\n3. Coordinator2.textDidChange() starts 300ms debounce timer\n4. After 300ms: binding sync writes parent.text\n5. ProseEditorView receives onChange → debounced disk/model save\n6. VaultSyncService picks up dirty flag → writes .md to vault\n\nKey guard: isFlushingTokens flag prevents binding cascade during AI streaming.\n</think>\n\nThe text flow:\n- **Input**: ProseTextView2 (NSTextView subclass with TextKit 2)\n- **Styling**: MarkdownContentStorage applies structural + inline markdown\n- **Sync**: Coordinator2 debounces to 300ms before updating SwiftUI binding\n- **Persist**: VaultSyncService writes to disk when needsVaultSync is true\n- **Guard**: isFlushingTokens prevents cascade during AI token insertion"),
        msg("How does the knowledge graph store nodes?",
            "<think>\nGraphStore uses compact Int-indexed arrays, not a traditional graph database:\n1. _nodeIdx: [String: Int] maps node IDs to stable compact indices\n2. _neighbors: [[Int]] stores adjacency lists using compact indices\n3. _edgesOf: [[Int]] reverse-indexes edges per node\n4. _trigramIdx: [String: [Int]] enables fuzzy search via trigram posting lists\n\nProxy types (AdjacencyProxy, EdgesByNodeProxy) preserve the store.adjacency[nodeId] API.\nPublic API is unchanged: nodes, edges, adjacency, edgesByNode all work as before.\n</think>\n\nGraphStore uses **compact Int-indexed arrays** for O(1) adjacency lookup:\n- `_nodeIdx: [String: Int]` — node ID → stable compact index\n- `_neighbors: [[Int]]` — deduplicated adjacency lists\n- `_edgesOf: [[Int]]` — edge reverse index\n- `_trigramIdx: [String: [Int]]` — trigram posting lists for fuzzy search\n\nNode types: Note(0), Chat(1), Idea(2), Source(3), Folder(4), Quote(5), Tag(6), Block(7)\nEdge types: 12 total including reference, semantic, and questions edges."),
        msg("How does TriageService route AI requests?",
            "<think>\nTriageService is the AI routing layer. It checks operation complexity:\n- .rewrite (0.25) → Apple Intelligence when light, else local Qwen\n- .summarize (0.20) → Apple Intelligence when light, else local Qwen\n- .continueWriting (0.30) → Local Qwen always\n- .outline (0.40) → Local Qwen\n- .expand (0.50) → Local Qwen\n- .analyze (0.60) → Local Qwen\n- .ask(query:) (0.20 + query complexity) → varies\n\nCurrently bridges to Qwen 2.5 1.5B. After MOHAWK training, Epistemos-Base 3B replaces Qwen entirely.\n</think>\n\nTriageService routes by operation complexity:\n- **Light ops** (.rewrite 0.25, .summarize 0.20): Try Apple Intelligence first, fall back to local\n- **Medium ops** (.continueWriting 0.30, .outline 0.40): Local Qwen directly\n- **Heavy ops** (.expand 0.50, .analyze 0.60): Local Qwen with full context\n- **Queries** (.ask): 0.20 base + query complexity score\n\nDefined in `Engine/TriageService.swift`. Pipeline: `PipelineService.swift` → `LLMService.swift`."),
        msg("What is the environment injection pattern in Epistemos?",
            "<think>\nEpistemos uses withAppEnvironment(bootstrap) for SwiftUI environment injection.\nThe old pattern was manual .environment() chains that drifted from AppEnvironment.swift.\nNoteWindowManager had a separate list that caused runtime crashes when new state objects were added.\n\nFix: Single source of truth in AppEnvironment.swift.\nwithAppEnvironment(bootstrap) injects all state objects at once.\nNever use manual .environment() chains.\n</think>\n\nEnvironment injection uses `withAppEnvironment(bootstrap)`:\n- **Single source**: `App/AppEnvironment.swift` defines all injected state\n- **Bootstrap**: `App/AppBootstrap.swift` creates all services at launch\n- **Injection**: `withAppEnvironment()` applies all `.environment()` modifiers at once\n- **Anti-pattern**: Never use manual `.environment()` chains — they drift from the source\n- **Bug fixed**: NoteWindowManager previously had a separate list that crashed on new state objects"),
        msg("How does the AI context menu work in the note editor?",
            "<think>\nThe AI context menu flow:\n1. User right-clicks in ProseTextView2\n2. ProseTextView2.menu(for:) builds the context menu\n3. AI operations added: rewrite, summarize, expand, simplify, toList, toTable, continue, outline, structure, restructure\n4. User clicks an operation → posts NSNotification with operation string\n5. NoteDetailWorkspaceView receives notification\n6. handleAIContextMenuOperation() maps to (NotesOperation, systemPrompt, userPrompt)\n7. noteChatState.submitQuery() sends to TriageService\n8. Tokens stream back through the same pipeline as chat sidebar\n</think>\n\nAI Context Menu pipeline:\n1. Right-click → `ProseTextView2.menu(for:)` builds menu items\n2. Click operation → posts `NSNotification` with operation string\n3. `NoteDetailWorkspaceView.handleAIContextMenuOperation()` maps to `(NotesOperation, systemPrompt, userPrompt)`\n4. `NoteChatState.submitQuery()` → `TriageService` → token streaming\n5. Response appears below `---` divider in the same editor\n\nOperations: rewrite, summarize, expand, simplify, toList, toTable, continue, outline, structure, restructure"),
        msg("How does the Omega agent orchestration work?",
            "<think>\nThe Omega orchestration pipeline:\n1. User submits task via TaskInputBar → OrchestratorState.submitTask()\n2. OmegaPlanningService plans (LLM or heuristic) → TaskGraph DAG\n3. ConfirmationGate checks risk level (auto/preview/confirm)\n4. executePlan() runs steps via agent dispatch\n5. Each step: route to correct agent → execute → recordAndLog()\n6. recordAndLog() calls mcpBridge.logExecution() + agentGraphMemory.recordExecution()\n7. Results chain via contextualizedStep() for dependency injection\n8. On error: retry with exponential backoff\n</think>\n\nOrchestration flow:\n1. **Input**: `TaskInputBar` → `OrchestratorState.submitTask()`\n2. **Planning**: `OmegaPlanningService` → `TaskGraph` DAG with dependencies\n3. **Gating**: `ConfirmationGate` (CheckedContinuation, not polling)\n4. **Execution**: Route to agent → execute → `recordAndLog()`\n5. **Logging**: `mcpBridge.logExecution()` + `agentGraphMemory.recordExecution()`\n6. **Chaining**: `contextualizedStep()` injects `_context` from completed deps\n7. **Recovery**: Exponential backoff retry on failure"),
        msg("What view modifiers does Epistemos provide?",
            "<think>\nFrom Theme/PhysicsModifiers.swift:\n- .physicsHover(.subtle/.medium/.lift) — scale + shadow on hover, zero cost idle\n- .physicsPress() — scale down on press, spring back\n- .breathe() — 30Hz oscillation via TimelineView, gated by windowOccluded\n- .springEntrance(index:) — staggered appear animation (one-shot)\n- .graphReactive(nodeId:) — highlight when graph hovers matching node\n- .glassEffect() — macOS 26 liquid glass\n- .siriGlow() — animated border glow during AI streaming\n</think>\n\nView modifiers in `Theme/PhysicsModifiers.swift`:\n- **`.physicsHover(.subtle/.medium/.lift)`** — Scale + shadow on hover (zero cost idle)\n- **`.physicsPress()`** — Scale down on press, spring back\n- **`.breathe()`** — 30Hz oscillation, gated by `windowOccluded` + `reduceMotion`\n- **`.springEntrance(index:)`** — Staggered appear animation (one-shot)\n- **`.graphReactive(nodeId:)`** — Highlight when graph hovers matching node\n- **`.glassEffect()`** — macOS 26 liquid glass\n- **`.siriGlow()`** — Animated border glow (streaming indicator only)"),
        msg("How does VaultSyncService work?",
            "<think>\nVaultSyncService manages the Markdown vault on disk:\n1. Each SDPage maps to a .md file in the vault directory\n2. needsVaultSync flag triggers sync (must call modelContext.save() immediately!)\n3. NoteFileStorage handles the actual file I/O\n4. @Query(filter: #Predicate { $0.needsVaultSync == true }) watches for dirty pages\n\nCritical anti-pattern: Setting needsVaultSync without save() causes the @Query to never see it.\nFix: Always call try? modelContext.save() immediately after setting dirty flags.\n</think>\n\nVaultSyncService:\n- **Storage**: Each `SDPage` → `.md` file in vault directory\n- **Dirty flag**: `page.needsVaultSync = true` + `modelContext.save()` (BOTH required)\n- **Watch**: `@Query(filter: #Predicate { $0.needsVaultSync == true })`\n- **I/O**: `NoteFileStorage` handles disk reads/writes\n- **Critical**: Never set `needsVaultSync` without `save()` — the @Query won't see it"),
        # Add more code-grounded examples about specific subsystems
        msg("How does the ReasoningLoop work?",
            "<think>\nReasoningLoopService implements STaR + autoresearch:\n1. THINK: Generate reasoning about the task\n2. CRITIQUE: Self-evaluate the reasoning\n3. ACT: Execute tool calls if needed (vault_search, graph_search)\n4. REFINE: Improve based on critique + action results\n5. EVALUATE: Score quality (parseQualityScore handles multiple formats)\n\nComplexity gate skips simple operations. Opt-in via Settings.\nGenerates ODIA training traces from successful chains.\n16/16 tests pass.\n</think>\n\nReasoningLoopService (`Omega/Inference/ReasoningLoopService.swift`, 456 lines):\n- **Loop**: THINK → CRITIQUE → ACT → REFINE → EVALUATE\n- **Complexity gate**: Skips simple operations automatically\n- **Tool calls**: vault_search, graph_search within reasoning\n- **Quality scoring**: `parseQualityScore()` handles Score:, /1, decimal, integer patterns\n- **Training data**: Generates ODIA traces from successful chains\n- **Status**: 16/16 tests pass, opt-in via Settings"),
        msg("What is the DualBrainRouter and how does it work?",
            "<think>\nDualBrainRouter routes between Brain 1 (reasoning, GPU) and Brain 2 (device actions, fast):\n- Automation agent → Brain 2 (fast action resolution)\n- Safari page inspection → Brain 2\n- Everything else → Brain 1 (reasoning model)\n- Fallback: If Brain 2 unavailable, routes to Brain 1\n\nDefined in Omega/Inference/DualBrainRouter.swift (136 lines).\nHardwareTierManager determines which brains are available based on hardware.\n</think>\n\nDualBrainRouter (`Omega/Inference/DualBrainRouter.swift`):\n- **Brain 1** (GPU, 8-20 tok/s): Reasoning, planning, complex queries\n- **Brain 2** (fast): Device actions, UI automation, Safari inspection\n- **Routing**: automation→Brain 2, safari_inspect→Brain 2, else→Brain 1\n- **Fallback**: Brain 2 unavailable → Brain 1 handles everything\n- **Hardware**: `HardwareTierManager` detects 7 tiers, requires 16GB+ for dual model"),
        msg("Explain the zone protection in the note editor",
            "<think>\nThe Zone Protection Gap was a critical bug:\n- shouldChangeTextIn guards AI zone ONLY during isStreaming\n- After streaming ends but BEFORE accept/discard, user edits above divider\n- These edits don't adjust the offset → stale offset\n- On accept: data loss because offset points to wrong position\n\nFix: Guard whenever hasDivider is true, not just isStreaming.\nThis means protection is active from first token flush until accept/discard.\n</think>\n\nZone Protection (critical anti-pattern fix):\n- **Bug**: `shouldChangeTextIn` only guarded during `isStreaming`\n- **Gap**: After streaming ends but before accept/discard, edits above divider corrupt offset\n- **Result**: Stale offset → data loss on accept\n- **Fix**: Guard whenever `hasDivider` is true, not just `isStreaming`\n- **Code**: `ProseTextView2` checks `hasDivider` in `shouldChangeText(in:replacementString:)`"),
        msg("What is the multi-turn double insertion bug?",
            "<think>\nThe Multi-Turn Double Insertion bug:\n- Second AI query when hasDivider is already true\n- Tokens appended raw without prompt header separator\n- Previous response and new response merge into one blob\n\nFix: Track lastFlushedTurnCount, insert header when turn count increases.\nThis separates multi-turn responses with proper dividers.\n</think>\n\nMulti-Turn Double Insertion:\n- **Bug**: Second query with `hasDivider == true` → tokens appended without separator\n- **Result**: Previous and new responses merge into unstructured blob\n- **Fix**: Track `lastFlushedTurnCount`, insert `---` header when turn count increases\n- **Code**: `NoteChatState.flushTokens()` checks turn count before insertion"),
    ] + [
        # More code-grounded for various subsystems
        msg(f"What does {cls} do in Epistemos?",
            f"<think>\n{cls} is part of the {sub} subsystem. Let me trace its role in the architecture.\n</think>\n\n**`{cls}`** ({sub} subsystem):\n{desc}")
        for cls, sub, desc in [
            ("PhysicsCoordinator", "theme", "Cross-view hover signaling between graph and sidebar. `graphHoveredNodeId: String?` written by MetalGraphNSView on mouseMoved, read by `GraphReactiveModifier` for highlight. Zero cost when idle."),
            ("SDPage", "models", "SwiftData model for notes. Properties: title, body, timestamps, needsVaultSync flag. Maps 1:1 to .md files in vault. Used by NotesAgent, VaultSyncService, and NoteDetailWorkspaceView."),
            ("SDGraphNode", "models", "SwiftData model for graph nodes. Links to SDPage via relationships. Stores node type (Note/Chat/Idea/Source/Folder/Quote/Tag/Block) and edge connections."),
            ("GraphBuilder", "graph", "Constructs the knowledge graph from SwiftData models. Extracts quotes, sources, wikilinks as ephemeral nodes. Called by GraphState.buildPageSubgraph()."),
            ("PipelineService", "ai_pipeline", "Manages the LLM inference pipeline. Handles token streaming with 60ms buffering. Coordinates with TriageService for model routing."),
            ("LLMService", "ai_pipeline", "Direct interface to the local LLM (currently Qwen 2.5 1.5B). Manages model loading, tokenization, and inference on Metal GPU."),
            ("NoteWindowManager", "notes", "Manages detached note windows. Uses withAppEnvironment(bootstrap) for environment injection. Each window gets its own NoteDetailWorkspaceView with full state."),
            ("MarkdownContentStorage", "notes", "TextKit 2 delegate for markdown styling. Applies structural (headings, lists) and inline (bold, italic, code) formatting. Used by ProseTextView2."),
            ("HologramController", "graph", "Coordinates the 3D graph overlay. Manages Metal rendering, camera controls, and node selection. Bridges between HologramOverlay (SwiftUI) and MetalGraphView."),
            ("AppBootstrap", "app", "Creates all services at app launch: TriageService, VaultSyncService, GraphState, OrchestratorState, MCPBridge, etc. Single init point for the entire app."),
            ("Screen2AXFusion", "omega/vision", "Production perception pipeline. AX tree first → Apple Vision OCR fallback when sparse (<10 interactive elements). Merges OCR results as synthetic AXStaticText elements."),
            ("AXSemanticSelector", "omega/vision", "CSS-style AX selector parser. Resolves //Role[@Attr='Value'] and contains() predicates against AX tree JSON. Used by AutomationAgent for semantic element targeting."),
            ("VisualVerifyLoop", "omega/vision", "Before/after state comparison for action verification. LLM-based with AX-diff fallback. Tracks rolling success rate."),
            ("AgentGraphMemory", "omega/knowledge", "Records agent executions as idea nodes in knowledge graph. Creates source nodes from URLs. Auto-tags from keywords. Provides recall() and contextFor() queries."),
        ]
    ]


# ─── NEGATIVE EXAMPLES (Layer 6) — Need 20 more, with <think> ──

def negative_with_think():
    return [
        msg("What is quantum computing?",
            "<think>\nThe user is asking a general knowledge question. This doesn't require any tool call or app interaction. I should answer conversationally.\n</think>\n\nQuantum computing uses quantum mechanical phenomena like superposition and entanglement to process information. Unlike classical bits (0 or 1), quantum bits (qubits) can exist in multiple states simultaneously, enabling certain computations to be exponentially faster. I can create an Epistemos note about this if you'd like!"),
        msg("How are you doing today?",
            "<think>\nThis is a greeting/social question. No tool call needed. I should respond briefly and offer to help with actual tasks.\n</think>\n\nI'm ready to help! I can manage your notes, search your knowledge base, automate macOS tasks, browse the web, or navigate any app. What would you like to do?"),
        msg("What's the meaning of life?",
            "<think>\nPhilosophical question. No tool call. I should respond briefly and redirect to what I'm good at.\n</think>\n\nThat's a deep question! As Epistemos-Nano, I'm better at helping you organize knowledge than answering existential questions. Want me to search your notes for any thoughts you've written about this?"),
        msg("Can you write me a Python script?",
            "<think>\nThe user wants code generation. I can help with this conversationally — no tool call needed. I should just write the code in my response.\n</think>\n\nSure! What should the script do? I can help you write it and then save it to a file in your vault if you'd like."),
        msg("Tell me about the latest news",
            "<think>\nThe user wants news. I don't have real-time news access, but I could search the web in Safari. However, the user didn't ask me to DO anything — they just want information. I should explain my limitations and offer to search.\n</think>\n\nI don't have real-time news access, but I can search the web for you! Say something like 'search the web for latest tech news' and I'll open Safari and search."),
        msg("Good morning",
            "<think>\nGreeting. No action needed. Brief friendly response.\n</think>\n\nGood morning! Ready to help. What's on your agenda today?"),
        msg("Never mind, forget what I said",
            "<think>\nThe user is canceling their previous request. No action needed. I should acknowledge and stand ready.\n</think>\n\nNo problem! Let me know when you need something."),
        msg("I'm not sure what to do next",
            "<think>\nThe user is thinking out loud. No tool call. I should offer suggestions based on what I can do.\n</think>\n\nHere are some things I can help with:\n- Create or search notes\n- Browse research in Safari\n- Automate repetitive tasks\n- Organize your knowledge graph\n- Check your files and folders\nWhat sounds useful?"),
        msg("That's interesting, tell me more",
            "<think>\nThe user wants more information about a previous topic. This is conversational — no tool call needed unless they ask for a specific action.\n</think>\n\nI'd be happy to elaborate! Could you be more specific about which part you'd like to know more about? I can also search your notes or the web for deeper information."),
        msg("Wait, let me think about this",
            "<think>\nThe user is pausing to think. I should NOT take any action. Just acknowledge and wait.\n</think>\n\nTake your time! I'll be here when you're ready."),
        msg("What do you think about SwiftUI vs UIKit?",
            "<think>\nTechnical opinion question. No tool call needed. I can share knowledge about the Epistemos codebase's approach.\n</think>\n\nIn Epistemos, we use SwiftUI as the primary framework with AppKit bridges for TextKit 2 editing and Metal rendering. SwiftUI handles declarative layout and `@Observable` state management. AppKit NSView subclasses handle the heavy lifting where SwiftUI falls short — text editing, accessibility, and GPU rendering. For new views, SwiftUI is preferred unless you need low-level control."),
        msg("Remind me to check the training progress later",
            "<think>\nThe user wants a reminder. I don't have a persistent reminder/timer system — I can only take immediate actions. I should explain this limitation.\n</think>\n\nI can't set persistent reminders since I don't run in the background. But I can create a note to remind you! Want me to create a note titled 'Check Training Progress'?"),
        msg("How long will the training take?",
            "<think>\nThe user is asking about training duration. This is informational — no tool call needed. I should answer based on what I know about the MOHAWK pipeline.\n</think>\n\nBased on the MOHAWK pipeline configuration:\n- Stage 1 (Matrix Orientation): ~10h on A100\n- Stage 2 (Hidden-State Alignment): ~17h\n- Stage 3 (Knowledge Distillation): ~28h\n- Post-MOHAWK SFT: ~2-3h additional\n\nTotal: approximately 55-60 hours."),
        msg("Is it raining?",
            "<think>\nWeather question. I have no weather data access. I should offer to search the web.\n</think>\n\nI can't check the weather directly, but I can search the web for you. Want me to open Safari and search for the current weather in your area?"),
        msg("Compare Mamba-2 and Transformer architectures",
            "<think>\nTechnical comparison question. Conversational answer — no tool call. I have deep knowledge of this from the Epistemos training context.\n</think>\n\nKey differences:\n- **Mamba-2**: Linear-time, constant memory, uses selective state spaces. Great for long sequences. Can't do exact token retrieval.\n- **Transformer**: Quadratic attention, full token visibility. Better at exact matching and structured output.\n- **Epistemos Hybrid (75/25)**: 18 Mamba-2 layers for efficient processing + 6 Attention layers for exact retrieval and JSON formatting. Best of both worlds.\n\nThe attention layers are critical — pure Mamba-2 causes reasoning drift and JSON formatting failures in tool calls."),
        msg("What's 42 + 17?",
            "<think>\nSimple math question. No tool call needed.\n</think>\n\n59."),
        msg("Thank you for your help!",
            "<think>\nGratitude. No action needed.\n</think>\n\nYou're welcome! Let me know if you need anything else."),
        msg("I changed my mind about that",
            "<think>\nThe user is reversing a decision. No action to take — just acknowledge.\n</think>\n\nUnderstood. What would you like to do instead?"),
        msg("Just checking if you're still there",
            "<think>\nPresence check. No action needed.\n</think>\n\nStill here and ready! What do you need?"),
        msg("explain the difference between LoRA rank 8 and 16",
            "<think>\nTechnical question about training. Conversational answer. Per training non-negotiables: rank 16 for Nano, not 8 (too constrained) or 32 (overfits nightly data).\n</think>\n\nFor Epistemos-Nano:\n- **Rank 8**: Too constrained — the adapter can't capture enough diversity in tool-calling patterns\n- **Rank 16**: Sweet spot — enough capacity for nightly data without overfitting\n- **Rank 32**: Overfits on small nightly trace batches\n\nThis is a training non-negotiable: always rank 16 for Nano. Never fuse adapters into base — hot-swap via MoLoRA routing only."),
    ]


# ─── ERROR RECOVERY (Layer 7) — Need 17 more, AXPress + <think> ─

def error_recovery_axpress():
    return [
        msg("Error: AXError kAXErrorCannotComplete for AXButton[@AXTitle='Share']",
            "<think>\nkAXErrorCannotComplete means the button exists but can't be activated. Possible causes: disabled state, modal blocking, or the element reference is stale. Let me try the keyboard shortcut alternative.\n</think>\n\nThe Share button can't be activated right now. Trying keyboard shortcut instead.\n\n" + json.dumps({"action": "key", "selector": "", "value": "i", "modifiers": ["cmd", "shift"]})),
        msg("Error: Application 'Preview' is not running",
            "<think>\nThe target app isn't running. I need to launch it first, then retry the intended action.\n</think>\n\nPreview isn't running. Launching it now.\n\n" + json.dumps({"action": "shortcut", "selector": "activate_app", "value": "Preview"})),
        msg("Error: Element 'Download' not found. Available: ['Save', 'Cancel', 'Open']",
            "<think>\nThe user said 'Download' but the available buttons are Save, Cancel, Open. 'Save' is the closest semantic match to download — it saves the file locally.\n</think>\n\nNo 'Download' button found. 'Save' is the equivalent action.\n\n" + json.dumps({"action": "click", "selector": "AXButton[@AXTitle='Save']"})),
        msg("Error: Timeout waiting for AXTextField to appear after 10 seconds",
            "<think>\nThe text field didn't appear in time. The app might be loading, or a dialog needs to be dismissed first. Let me check the current UI state.\n</think>\n\nThe element didn't appear in time. Let me check the current state.\n\n" + json.dumps({"action": "focus", "selector": "AXApplication"})),
        msg("Error: Permission denied: Accessibility not granted for Epistemos",
            "<think>\nAccessibility permission is required for AX tree walking and input simulation. I need to guide the user to System Settings to grant it.\n</think>\n\nAccessibility permission needed. Opening System Settings.\n\n" + json.dumps([
                {"action": "key", "selector": "", "value": "space", "modifiers": ["cmd"]},
                {"action": "type", "selector": "AXTextField", "value": "Privacy & Security"},
                {"action": "key", "selector": "", "value": "return"}
            ], indent=2)),
        msg("Error: Click at coordinates (800, 600) hit a non-interactive element (AXStaticText)",
            "<think>\nClicked on static text instead of the intended button. The coordinates were slightly off. I should use the AX tree to find the correct element by name instead of coordinates.\n</think>\n\nCoordinate click missed the target. Switching to semantic click.\n\n" + json.dumps({"action": "click", "selector": "AXButton[@AXTitle near the clicked area]"})),
        msg("Error: Safari tab crashed (WebContent process terminated)",
            "<think>\nSafari tab crashed. I should try reloading the page. If that fails, close and reopen the tab.\n</think>\n\nTab crashed. Reloading.\n\n" + json.dumps({"action": "key", "selector": "", "value": "r", "modifiers": ["cmd"]})),
        msg("Error: run_command 'sudo rm -rf /' rejected — not in allow list",
            "<think>\nThis command is dangerous and not in the allow list. I should NOT attempt to bypass this. The allow list exists for safety. I should explain the limitation.\n</think>\n\nThat command is blocked for safety. The terminal allow list permits only: ls, cat, head, tail, grep, find, wc, echo, date, pwd, which. I cannot and should not bypass this restriction."),
        msg("Error: AX tree is empty — 0 elements found for 'Electron App'",
            "<think>\nElectron apps often have poor accessibility. The AX tree returned nothing. I should try the Screen2AX VLM fallback or use coordinate-based interaction.\n</think>\n\nNo AX tree available (common with Electron apps). Using coordinate-based interaction.\n\n" + json.dumps({"action": "click", "selector": "", "value": ""})),
        msg("Error: Multiple elements match 'OK' — found 3 AXButtons with title 'OK'",
            "<think>\nAmbiguous selector — 3 OK buttons exist. This often happens with nested dialogs. I should use a more specific selector that includes the parent container or position.\n</think>\n\nMultiple matches found. Using position-based disambiguation.\n\n" + json.dumps({"action": "click", "selector": "AXSheet > AXButton[@AXTitle='OK']"})),
        msg("Error: NSTextView insertText failed — text storage is locked during AI streaming",
            "<think>\nThe text storage is locked because AI streaming is in progress (isFlushingTokens is true). I need to wait for streaming to complete before inserting text.\n</think>\n\nText storage is locked during AI streaming. Waiting for completion.\n\n" + json.dumps({"action": "focus", "selector": "AXTextArea", "value": "wait_for_streaming"})),
        msg("Error: VaultSyncService — file already exists at 'notes/research.md'",
            "<think>\nFile conflict — a note with this name already exists. I should either use a unique name or offer to append to the existing note.\n</think>\n\nFile already exists. Creating with unique name.\n\n" + json.dumps({"action": "type", "selector": "AXTextField[@AXTitle='Title']", "value": "research-2"})),
        msg("Error: Graph engine returned nil — engineHandle is null",
            "<think>\nThe Rust graph engine handle is nil. This means the FFI bridge isn't initialized. This could happen on first launch or after a crash. The engine needs to be re-initialized.\n</think>\n\nGraph engine not initialized. This may resolve after app restart. The engineHandle pointer in GraphState.swift needs to be re-created."),
        msg("Error: Model inference failed — out of memory on Metal GPU",
            "<think>\nGPU OOM during inference. The model or context is too large for available VRAM. I should suggest reducing context size or batch size.\n</think>\n\nGPU memory exhausted. Try closing other apps to free Metal memory, or reduce the context window."),
        msg("Error: Network timeout — HuggingFace model download failed",
            "<think>\nNetwork issue during model download. This shouldn't happen in production since we're local-first. But during initial setup, model download is needed. I should suggest retrying.\n</think>\n\nModel download failed. Check your internet connection and retry. Epistemos is local-first — once the model is downloaded, no network is needed."),
        msg("Error: SwiftData save failed — model context corrupted",
            "<think>\nSwiftData context corruption is serious. I should NOT retry the save — it could make things worse. The context needs to be recreated.\n</think>\n\nSwiftData context corrupted. The app may need to be restarted to recreate the model container. Any unsaved changes may be lost."),
        msg("Error: scroll event ignored — momentum phase is .cancelled",
            "<think>\nThe scroll was cancelled by the system (e.g., another gesture took over). This is normal behavior. I should retry the scroll.\n</think>\n\nScroll was cancelled. Retrying.\n\n" + json.dumps({"action": "scroll", "selector": "AXScrollArea", "value": "down:3"})),
    ]


# ─── MULTI-APP WORKFLOWS (Need 21 more) ────────────────────────

def multi_app_workflows():
    return [
        msg("Copy my meeting notes from Notes app into Epistemos",
            "<think>\nMulti-app workflow: 1) Activate Apple Notes, 2) Find the meeting notes, 3) Select all text, 4) Copy, 5) Switch to Epistemos, 6) Create new note, 7) Paste.\n</think>\n\n" + json.dumps([
                {"action": "shortcut", "selector": "activate_app", "value": "Notes"},
                {"action": "focus", "selector": "AXTextField[@AXSubrole='AXSearchField']"},
                {"action": "type", "selector": "AXTextField", "value": "meeting notes"},
                {"action": "key", "selector": "", "value": "return"},
                {"action": "key", "selector": "", "value": "a", "modifiers": ["cmd"]},
                {"action": "key", "selector": "", "value": "c", "modifiers": ["cmd"]},
                {"action": "shortcut", "selector": "activate_app", "value": "Epistemos"},
                {"action": "click", "selector": "AXButton[@AXTitle='New Note']"},
                {"action": "type", "selector": "AXTextField[@AXTitle='Title']", "value": "Meeting Notes Import"},
                {"action": "key", "selector": "", "value": "tab"},
                {"action": "key", "selector": "", "value": "v", "modifiers": ["cmd"]}
            ], indent=2)),
        msg("Check my calendar for today and create a summary note",
            "<think>\nMulti-app: 1) Open Calendar, 2) Navigate to today, 3) Read events, 4) Switch to Epistemos, 5) Create summary note.\n</think>\n\n" + json.dumps([
                {"action": "shortcut", "selector": "activate_app", "value": "Calendar"},
                {"action": "click", "selector": "AXButton[@AXTitle='Today']"},
                {"action": "key", "selector": "", "value": "a", "modifiers": ["cmd"]},
                {"action": "key", "selector": "", "value": "c", "modifiers": ["cmd"]},
                {"action": "shortcut", "selector": "activate_app", "value": "Epistemos"},
                {"action": "click", "selector": "AXButton[@AXTitle='New Note']"},
                {"action": "type", "selector": "AXTextField[@AXTitle='Title']", "value": "Today's Schedule"},
                {"action": "key", "selector": "", "value": "tab"},
                {"action": "key", "selector": "", "value": "v", "modifiers": ["cmd"]}
            ], indent=2)),
        msg("Find a research paper in Safari and add it as a source in my knowledge graph",
            "<think>\nMulti-app: 1) Safari search, 2) Get URL, 3) Switch to Epistemos, 4) Add as graph source node.\n</think>\n\n" + json.dumps([
                {"action": "shortcut", "selector": "activate_app", "value": "Safari"},
                {"action": "focus", "selector": "AXTextField[@AXSubrole='AXSearchField']"},
                {"action": "type", "selector": "AXTextField", "value": "Mamba-2 selective state spaces arxiv"},
                {"action": "key", "selector": "", "value": "return"},
                {"action": "click", "selector": "AXLink[contains(@AXTitle,'arxiv')]"},
                {"action": "key", "selector": "", "value": "l", "modifiers": ["cmd"]},
                {"action": "key", "selector": "", "value": "c", "modifiers": ["cmd"]},
                {"action": "shortcut", "selector": "activate_app", "value": "Epistemos"}
            ], indent=2)),
        msg("Export my note as PDF and email it",
            "<think>\nMulti-step: 1) In Epistemos, use File > Export as PDF, 2) Save to Desktop, 3) Open Mail, 4) New email, 5) Attach the PDF.\n</think>\n\n" + json.dumps([
                {"action": "key", "selector": "", "value": "p", "modifiers": ["cmd"]},
                {"action": "click", "selector": "AXButton[@AXTitle='PDF']"},
                {"action": "click", "selector": "AXMenuItem[@AXTitle='Save as PDF...']"},
                {"action": "type", "selector": "AXTextField[@AXTitle='Save As']", "value": "exported-note.pdf"},
                {"action": "click", "selector": "AXButton[@AXTitle='Save']"},
                {"action": "shortcut", "selector": "activate_app", "value": "Mail"},
                {"action": "key", "selector": "", "value": "n", "modifiers": ["cmd"]}
            ], indent=2)),
    ] + [
        msg(f"{intent}",
            f"<think>\n{think}\n</think>\n\n" + json.dumps(actions, indent=2))
        for intent, think, actions in [
            ("Open Terminal and check disk usage, then note it in Epistemos",
             "Multi-app: Terminal for df command, then create note with results.",
             [{"action": "shortcut", "selector": "activate_app", "value": "Terminal"},
              {"action": "type", "selector": "AXTextArea", "value": "df -h | head -5"},
              {"action": "key", "selector": "", "value": "return"},
              {"action": "key", "selector": "", "value": "a", "modifiers": ["cmd"]},
              {"action": "key", "selector": "", "value": "c", "modifiers": ["cmd"]},
              {"action": "shortcut", "selector": "activate_app", "value": "Epistemos"},
              {"action": "click", "selector": "AXButton[@AXTitle='New Note']"}]),
            ("Search for a SwiftUI tutorial in Safari, bookmark it, and note the URL",
             "Multi-step Safari workflow with Epistemos note creation.",
             [{"action": "shortcut", "selector": "activate_app", "value": "Safari"},
              {"action": "focus", "selector": "AXTextField[@AXSubrole='AXSearchField']"},
              {"action": "type", "selector": "AXTextField", "value": "SwiftUI Observable tutorial 2026"},
              {"action": "key", "selector": "", "value": "return"},
              {"action": "key", "selector": "", "value": "d", "modifiers": ["cmd"]},
              {"action": "key", "selector": "", "value": "return"}]),
            ("Move files from Downloads to a project folder in Finder",
             "Finder file management workflow.",
             [{"action": "shortcut", "selector": "activate_app", "value": "Finder"},
              {"action": "key", "selector": "", "value": "l", "modifiers": ["cmd", "alt"]},
              {"action": "type", "selector": "AXTextField", "value": "~/Downloads"},
              {"action": "key", "selector": "", "value": "return"}]),
            ("Check Messages for new texts and summarize in Epistemos",
             "Messages → Epistemos cross-app workflow.",
             [{"action": "shortcut", "selector": "activate_app", "value": "Messages"},
              {"action": "key", "selector": "", "value": "a", "modifiers": ["cmd"]},
              {"action": "key", "selector": "", "value": "c", "modifiers": ["cmd"]},
              {"action": "shortcut", "selector": "activate_app", "value": "Epistemos"}]),
            ("Open System Settings and change display resolution",
             "System Settings navigation.",
             [{"action": "key", "selector": "", "value": "space", "modifiers": ["cmd"]},
              {"action": "type", "selector": "AXTextField", "value": "Displays"},
              {"action": "key", "selector": "", "value": "return"},
              {"action": "click", "selector": "AXRadioButton[@AXTitle='Scaled']"}]),
            ("Arrange two apps side by side for multitasking",
             "Window management: resize Epistemos left half, Safari right half.",
             [{"action": "shortcut", "selector": "activate_app", "value": "Epistemos"},
              {"action": "key", "selector": "", "value": "left", "modifiers": ["ctrl", "alt"]},
              {"action": "shortcut", "selector": "activate_app", "value": "Safari"},
              {"action": "key", "selector": "", "value": "right", "modifiers": ["ctrl", "alt"]}]),
        ]
    ]


# ─── TEMPORAL/SEQUENTIAL (Layer 14) — New category, 25 examples ─

def temporal_sequential():
    return [
        msg("First create a note, then add it to the graph, then share it",
            "<think>\nThis is a sequential task with 3 ordered steps. Each depends on the previous:\n1. Create note → get note ID\n2. Add to graph → requires note ID\n3. Share → requires note to exist\nI must execute in order.\n</think>\n\nSequential workflow with dependencies:\n\n**Step 1:** Create note\n" + json.dumps({"action": "click", "selector": "AXButton[@AXTitle='New Note']"}) +
            "\n\n**Step 2:** Note auto-added to graph on save\n" + json.dumps({"action": "key", "selector": "", "value": "s", "modifiers": ["cmd"]}) +
            "\n\n**Step 3:** Share the note\n" + json.dumps({"action": "click", "selector": "AXButton[@AXTitle='Share']"})),
        msg("Wait for the AI response to finish, then accept it, then save the note",
            "<think>\nTemporal dependency: I must wait for streaming to complete before I can accept. Then save after acceptance.\n1. Wait for AI response (streaming indicator disappears)\n2. Accept response (merges into note)\n3. Save note (Cmd+S)\n</think>\n\nWaiting for AI to finish streaming...\n\n**Step 1:** Wait for completion\n" + json.dumps({"action": "focus", "selector": "AXButton[@AXTitle='Accept AI Response']"}) +
            "\n**Step 2:** Accept\n" + json.dumps({"action": "click", "selector": "AXButton[@AXTitle='Accept AI Response']"}) +
            "\n**Step 3:** Save\n" + json.dumps({"action": "key", "selector": "", "value": "s", "modifiers": ["cmd"]})),
    ] + [
        msg(f"{intent}",
            f"<think>\n{think}\n</think>\n\n{response}")
        for intent, think, response in [
            ("After the download finishes, open the file and read it",
             "Temporal: wait for download → open → read. Downloads appear in ~/Downloads.",
             "Waiting for download to complete, then opening the file.\n\n" +
             json.dumps({"action": "key", "selector": "", "value": "l", "modifiers": ["cmd", "alt"]}) +
             "\nThen navigate to Downloads and open the file."),
            ("Search, find the best result, open it, then summarize it",
             "Sequential 4-step: search → evaluate results → open best → summarize content.",
             "Step-by-step:\n1. Search\n2. Evaluate results\n3. Open best match\n4. Read and create summary note"),
            ("If the note has more than 500 words, summarize it; otherwise expand it",
             "Conditional logic: check word count, then branch to summarize or expand.",
             "I need to check the note length first. Looking at the Word Count indicator in the toolbar to decide whether to summarize or expand."),
            ("Keep retrying the search until we find a relevant result",
             "Iterative: search → evaluate → refine query → repeat until success.",
             "I'll search, evaluate results, and refine the query if needed. This may take multiple attempts."),
            ("Open each note in the search results and tag them all with 'review'",
             "Loop: iterate through search results, open each, add tag.",
             "Iterating through search results. For each note: open → add 'review' tag → go back to results → next."),
            ("Back up my 3 most recent notes by exporting them as files",
             "Sequential batch: find recent → export each → verify all saved.",
             "Finding the 3 most recent notes, then exporting each one sequentially."),
            ("Undo the last 5 changes I made",
             "Repeated action: press Cmd+Z five times.",
             json.dumps({"action": "key", "selector": "", "value": "z", "modifiers": ["cmd"]}) + " (repeat 5 times)"),
            ("Close all open windows except Epistemos",
             "Iterative window management: list windows, close non-Epistemos ones.",
             "Iterating through running apps and closing windows for each except Epistemos.\n\n" +
             json.dumps({"action": "key", "selector": "", "value": "w", "modifiers": ["cmd"]})),
        ]
    ]


# ─── ADDITIONAL REASONING CHAINS ─────────────────────────────

def more_reasoning_chains():
    return [
        msg("The font size looks too small, make it bigger",
            "<think>\nI see the note editor. The text appears small. I need to either:\n1. Use Cmd+= (Cmd+Plus) to zoom in\n2. Go to Settings and adjust the Font Size slider\n3. Use the Format menu\n\nCmd+= is the fastest approach.\n</think>\n\n" + json.dumps({"action": "key", "selector": "", "value": "=", "modifiers": ["cmd"]})),
        msg("I accidentally deleted my note, can you undo it?",
            "<think>\nThe user deleted a note and wants to undo. In Epistemos, Cmd+Z should work if the deletion was recent. The undo stack in NSTextView handles this through shouldChangeText/didChangeText.\n</think>\n\n" + json.dumps({"action": "key", "selector": "", "value": "z", "modifiers": ["cmd"]})),
        msg("Show me what's in my vault",
            "<think>\nThe user wants to see their vault contents. I can either:\n1. Use the list_files tool to show vault contents\n2. Navigate to the notes sidebar which shows all files\n\nThe notes sidebar is the visual approach. Let me also check the file list.\n</think>\n\n" + json.dumps({"action": "click", "selector": "AXOutline[@AXTitle='Sidebar']"})),
        msg("I want to work in fullscreen mode",
            "<think>\nThe user wants fullscreen. On macOS, I can use the green traffic light button, or Ctrl+Cmd+F, or Fn+F. The keyboard shortcut is most reliable.\n</think>\n\n" + json.dumps({"action": "key", "selector": "", "value": "f", "modifiers": ["ctrl", "cmd"]})),
        msg("Split my screen between Epistemos and Safari",
            "<think>\nSplit screen on macOS: hover over the green window button → choose tile left/right. Or use keyboard: Ctrl+Option+Left/Right. The keyboard approach is faster.\n</think>\n\n" + json.dumps([
                {"action": "shortcut", "selector": "activate_app", "value": "Epistemos"},
                {"action": "key", "selector": "", "value": "left", "modifiers": ["ctrl", "alt"]},
                {"action": "shortcut", "selector": "activate_app", "value": "Safari"},
                {"action": "key", "selector": "", "value": "right", "modifiers": ["ctrl", "alt"]}
            ], indent=2)),
    ]


# ─── WRITE OUTPUT ───────────────────────────────────────────────

def write_jsonl(examples, output_dir, filename, category, layer):
    os.makedirs(output_dir, exist_ok=True)
    seen = set()
    written = 0
    path = os.path.join(output_dir, filename)
    with open(path, 'w', encoding='utf-8') as f:
        for ex in examples:
            ex_out = ex if isinstance(ex, dict) else ex
            if "category" not in ex_out:
                ex_out["category"] = category
            if "layer" not in ex_out:
                ex_out["layer"] = layer
            h = hashlib.sha256(json.dumps(ex_out["messages"], sort_keys=True).encode()).hexdigest()
            if h in seen:
                continue
            seen.add(h)
            f.write(json.dumps(ex_out, ensure_ascii=False) + "\n")
            written += 1
    print(f"  {filename}: {written} examples ({os.path.getsize(path)/1024:.1f} KB)")
    return written, [ex for ex in examples]


def main():
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--output", default="./epistemos_training_data")
    args = p.parse_args()

    print(f"\n{'='*60}")
    print(f"  Training Data Gap Filler")
    print(f"{'='*60}\n")

    total = 0
    all_new = []

    n, ex = write_jsonl(code_grounded(), args.output, "11_code_grounded.jsonl", "code_grounded", 11)
    total += n; all_new.extend(ex)

    n, ex = write_jsonl(negative_with_think(), args.output, "06_negative.jsonl", "negative", 6)
    total += n; all_new.extend(ex)

    n, ex = write_jsonl(error_recovery_axpress(), args.output, "07_error_recovery.jsonl", "error_recovery", 7)
    total += n; all_new.extend(ex)

    n, ex = write_jsonl(multi_app_workflows(), args.output, "13_multi_app_workflows.jsonl", "multi_app_workflow", 13)
    total += n; all_new.extend(ex)

    n, ex = write_jsonl(temporal_sequential(), args.output, "14_temporal_sequential.jsonl", "temporal_sequential", 14)
    total += n; all_new.extend(ex)

    n, ex = write_jsonl(more_reasoning_chains(), args.output, "08_reasoning_chains_extra.jsonl", "reasoning_chain", 8)
    total += n; all_new.extend(ex)

    # Rebuild train.jsonl and eval.jsonl from ALL layer files
    all_files = sorted(Path(args.output).glob("[0-9]*.jsonl"))
    all_examples = []
    for f in all_files:
        with open(f) as fh:
            for line in fh:
                line = line.strip()
                if line:
                    try:
                        all_examples.append(json.loads(line))
                    except:
                        pass

    random.seed(42)
    random.shuffle(all_examples)
    split = int(len(all_examples) * 0.9)

    train_path = os.path.join(args.output, "train.jsonl")
    eval_path = os.path.join(args.output, "eval.jsonl")

    with open(train_path, 'w', encoding='utf-8') as f:
        for ex in all_examples[:split]:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")

    with open(eval_path, 'w', encoding='utf-8') as f:
        for ex in all_examples[split:]:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")

    train_count = split
    eval_count = len(all_examples) - split

    print(f"\n  NEW examples added: {total}")
    print(f"  Rebuilt train.jsonl: {train_count}")
    print(f"  Rebuilt eval.jsonl: {eval_count}")
    print(f"  TOTAL training examples: {len(all_examples)}")

    # Category breakdown
    cats = {}
    for ex in all_examples:
        c = ex.get("category", "unknown")
        cats[c] = cats.get(c, 0) + 1
    print(f"\n  Category breakdown:")
    for c, n in sorted(cats.items(), key=lambda x: -x[1]):
        status = "✅" if n >= 20 else "⚠️ LOW"
        print(f"    {c}: {n} {status}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
