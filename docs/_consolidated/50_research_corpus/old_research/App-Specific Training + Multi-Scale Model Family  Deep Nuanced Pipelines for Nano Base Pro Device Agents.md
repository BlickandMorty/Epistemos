# App-Specific Training + Multi-Scale Model Family: Deep Nuanced Pipelines for Nano/Base/Pro Device Agents
## Executive Overview
Two compounding strategies elevate this project from "capable 1B model" to a legendary three-tier model family: (1) **code-grounded app-specific training** that gives the model hard-wired reflexes for your app's UI rather than runtime inference overhead, and (2) a **Nano/Base/Pro scale ladder** with shared architecture and training infrastructure, where each tier adds more agentic depth. Both are treated as first-class training objectives on equal footing with tool-calling and AX-tree grounding. This report details every niche script, pipeline, and technique to accomplish both.

***
## Part I: App-Specific Training — Reflexive Native Fluency
### The Core Problem with Generic Training
General-purpose macOS models learn your app's UI through in-context reasoning: they see an AX tree, process it, and infer what elements do. Your specialized model should instead **recall** this mapping from weights — the same way a power user knows `Cmd+Shift+E` triggers Export without reading the menu. The difference is latency (10–50ms of inference reasoning vs. sub-1ms weight recall) and reliability (no hallucinated selectors, no confusion between similarly-named buttons across apps).[^1][^2]

The three-layer strategy covers: (1) code anatomy fine-tuning to teach the model what every symbol in your codebase means, (2) AX atlas construction to encode every screen state as a lookup table in weights, and (3) execution trace replay to teach complete workflows. This section adds several niche techniques that dramatically improve upon naive approaches.
### Layer 0 — Code Graph Model (CGM) Architecture
Before any fine-tuning, represent your app's repository as a **code graph** rather than flat text files. This is the most important niche technique for code-grounded training and comes from **CGM** (NeurIPS 2025, CodeFuse-AI). The naive approach of dumping `.swift` files into a context window loses all dependency structure. CGM instead:[^3][^4][^5]

1. **Parses the AST** to build a hierarchical graph: `AppDelegate → ViewController → UIButton → @IBAction handler → downstream state change`[^4]
2. **Encodes each node** (function, class, method, UI component) using a text encoder, then maps node embeddings to the LLM's input space via a lightweight adapter[^4]
3. **Replaces the causal attention mask** between node tokens with the code graph's adjacency matrix, so the model performs direct message-passing along actual code dependency edges rather than positional proximity[^4]
4. **Pre-trains via subgraph reconstruction**: mask out nodes, predict them from their graph neighbors — before any task-specific SFT[^4]

CGM with a 7B backbone surpasses `Agentless + Claude-3.5-Sonnet` by 2.33% on SWE-bench Lite despite using a simpler 4-step pipeline. The architecture generalizes to any backbone size, including your 1B Mamba-2/Attention hybrid.[^4]

**Implementation via `codefuse-ai/CodeFuse-CGM`** (GitHub, supports LoRA, QLoRA, and full-parameter training):[^6]

```python
# build_app_code_graph.py
# Requires: pip install tree-sitter tree-sitter-swift networkx

import tree_sitter_swift, networkx as nx, json, pathlib
from tree_sitter import Language, Parser

SWIFT_LANG = Language(tree_sitter_swift.language())
parser = Parser(SWIFT_LANG)

def parse_swift_to_graph(src_root: str) -> nx.DiGraph:
    G = nx.DiGraph()
    for swift_file in pathlib.Path(src_root).rglob("*.swift"):
        src = swift_file.read_bytes()
        tree = parser.parse(src)
        # Extract nodes: class_declaration, function_declaration, property_declaration
        for node in walk_tree(tree.root_node):
            if node.type in ("class_declaration", "function_declaration", "property_declaration"):
                name = extract_name(node, src)
                code_text = src[node.start_byte:node.end_byte].decode()
                G.add_node(name, code=code_text, type=node.type, file=str(swift_file))
        # Extract edges: @IBAction → outlet, func calls, viewDidLoad → setUp* patterns
        for edge in extract_call_edges(tree, src):
            G.add_edge(edge["caller"], edge["callee"], rel=edge["rel"])
    return G

# Serialize for CGM training format
G = parse_swift_to_graph("~/YourApp/Sources")
graph_data = nx.node_link_data(G)
pathlib.Path("app_code_graph.json").write_text(json.dumps(graph_data))
```

Use this graph as the structural input to a CGM adapter layer trained on top of your MOHAWK base. The adapter is separate from your AX-action LoRA and can be stacked — the model receives the code graph context at all times when your app is active.[^6][^4]
### Layer 1 — Static Analysis QA Pairs (Cross-File Context)
The single most common failure in app-specific fine-tuning is training on **isolated files** rather than cross-file dependency chains. A button's handler in `ViewController.swift` only makes sense with knowledge of the data model in `DocumentStore.swift` and the navigation logic in `AppCoordinator.swift`. Static analysis tools resolve these links automatically:[^2]

```python
# xcode_symbols_to_qa.py
import subprocess, json, pathlib, re

# Step 1: Generate symbol graph from Xcode
subprocess.run([
    "xcodebuild",
    "-project", "YourApp.xcodeproj",
    "-target", "YourApp",
    "-derivedDataPath", "/tmp/dd",
    "-symbolGraph"
], check=True)

# Step 2: Parse symbol relationships
symbol_graphs = pathlib.Path("/tmp/dd/Build/Products").rglob("*.symbols.json")
qa_pairs = []

for sg_file in symbol_graphs:
    sg = json.loads(sg_file.read_text())
    
    for symbol in sg.get("symbols", []):
        name = symbol["names"]["title"]
        kind = symbol["kind"]["identifier"]
        doc_comment = symbol.get("docComment", {}).get("lines", [])
        
        # Find all relationships (conformsTo, memberOf, overrides, calls)
        related = [
            r for r in sg.get("relationships", [])
            if r["source"] == symbol["identifier"]["precise"]
        ]
        
        if kind == "swift.method" and any(r["kind"] == "memberOf" for r in related):
            parent_class = next(r["target"].split("/")[-1] for r in related 
                              if r["kind"] == "memberOf")
            
            # Generate forward mapping: "user wants X" → action
            qa_pairs.append({
                "instruction": f"In {parent_class}, what method should I call to {name_to_intent(name)}?",
                "response": f"{{'class': '{parent_class}', 'method': '{name}', 'signature': '{symbol.get('type', {}).get('swift.function', '')}'}}",
                "context_files": [str(sg_file)],
                "doc": " ".join(l["text"] for l in doc_comment)
            })
            
            # Generate reverse mapping: given UI action name, describe effect
            qa_pairs.append({
                "instruction": f"What does calling `{parent_class}.{name}()` do in the app?",
                "response": " ".join(l["text"] for l in doc_comment) if doc_comment 
                           else f"Executes {name} in {parent_class}"
            })

pathlib.Path("app_symbol_qa.jsonl").write_text(
    "\n".join(json.dumps(p) for p in qa_pairs)
)
print(f"Generated {len(qa_pairs)} symbol QA pairs")
```

Prioritize high-value tasks over comprehensive coverage: **debugging** ("Why is this button disabled?"), **navigation** ("How do I get from screen A to screen B?"), and **state queries** ("What does the model look like after this action?"). These map directly to your agentic use case.[^2]

Apply **3-phase curriculum** within this layer:[^2]
- Phase 1: Syntax-level (API signatures, return types, parameter names)  
- Phase 2: Architecture-level (which coordinator owns which flow, dependency injection patterns)  
- Phase 3: Runtime-behavioral (what happens when a method fails, error handling paths)
### Layer 2 — AX Atlas with Differential Snapshots
Beyond static snapshots, train on **AX tree diffs** — not just what elements exist, but what changed after each action. This teaches the model to verify action success and diagnose failures:

```python
# ax_differential_atlas.py
from macapptree import get_tree, get_tree_screenshot, get_app_bundle
import json, pathlib, copy, difflib

bundle = get_app_bundle("YourApp")

def ax_tree_diff(before: dict, after: dict) -> dict:
    """Compute structural diff between two AX tree states."""
    before_str = json.dumps(before, sort_keys=True, indent=2)
    after_str = json.dumps(after, sort_keys=True, indent=2)
    diff_lines = list(difflib.unified_diff(
        before_str.splitlines(), after_str.splitlines(), lineterm=""
    ))
    
    added = [l[1:] for l in diff_lines if l.startswith("+") and not l.startswith("+++")]
    removed = [l[1:] for l in diff_lines if l.startswith("-") and not l.startswith("---")]
    
    return {
        "added_elements": added[:20],   # truncate for training
        "removed_elements": removed[:20],
        "diff_size": len(diff_lines)
    }

WORKFLOWS = {
    "create_new_document": [
        ("click", "AXMenuItem[name=New, parent=AXMenu[File]]"),
        ("type", "AXTextField[name=DocumentTitle]", "Untitled"),
        ("click", "AXButton[name=Create]"),
    ],
    "export_to_pdf": [
        ("key", None, "cmd+shift+e"),
        ("click", "AXMenuItem[name=Export as PDF]"),
        ("click", "AXButton[name=Save]"),
    ]
}

atlas_examples = []
for workflow_name, steps in WORKFLOWS.items():
    before_tree = get_tree(bundle)
    
    for step_idx, (action_type, selector, *args) in enumerate(steps):
        # Execute action
        execute_ax_action(action_type, selector, *args)
        after_tree = get_tree(bundle)
        diff = ax_tree_diff(before_tree, after_tree)
        
        atlas_examples.append({
            "workflow": workflow_name,
            "step": step_idx + 1,
            "total_steps": len(steps),
            "pre_tree_hash": hash(json.dumps(before_tree, sort_keys=True)),
            "action": {"type": action_type, "selector": selector, "value": args if args else None},
            "post_diff": diff,
            "instruction": f"Step {step_idx+1}/{len(steps)} of '{workflow_name.replace('_', ' ')}'. What action should I take?",
            "response": json.dumps({"action": action_type, "selector": selector, 
                                    "value": args if args else None})
        })
        before_tree = after_tree

pathlib.Path("app_atlas_differential.jsonl").write_text(
    "\n".join(json.dumps(e) for e in atlas_examples)
)
```
### Layer 3 — SFT → RLAIF Agentic Recipe (SWE-QA-Pro Pattern)
The SWE-QA-Pro benchmark (arXiv, March 2026) proved that **RL after SFT gives larger gains than simply adding more SFT data** for agentic, repository-level tasks. The recipe for your app:[^1][^7]

**Stage A — SFT (1,000 tool-invocation trajectories)**

Use Claude Sonnet 4.5 to generate synthetic multi-turn trajectories through your app, given your AX atlas and symbol QA pairs as context. Each trajectory is a 3–8 step conversation:[^1]

```python
# generate_agentic_trajectories.py — SWE-QA-Pro pattern
import anthropic, json, pathlib

client = anthropic.Anthropic()

TRAJECTORY_PROMPT = """You are generating training data for an AI agent that controls the macOS app "{app_name}".

The app has the following key UI elements (AX Atlas excerpt):
{ax_atlas_excerpt}

The app's key methods are:
{symbol_qa_excerpt}

Generate a realistic multi-turn agent trajectory for the task: "{task}"

Format each step as:
[OBSERVE] <describe what the AX tree shows>
[REASON] hain-of-thought about what to do next>  
[ACT] <json: {{"action": "...", "selector": "...", "value": "..."}}>
[RESULT] <what changed in the AX tree>
...
[DONE] >"""

TASKS = [
    "Create a new document titled 'Q4 Report' and add a table",
    "Export the current document as PDF to the Downloads folder",
    "Enable dark mode in preferences",
    "Search for documents containing 'budget' and open the most recent",
    "Duplicate the current selection and paste it 3 times",
]

trajectories = []
for task in TASKS:
    response = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=2000,
        messages=[{"role": "user", "content": TRAJECTORY_PROMPT.format(
            app_name="YourApp",
            ax_atlas_excerpt=load_atlas_excerpt(n=20),
            symbol_qa_excerpt=load_symbol_excerpt(n=10),
            task=task
        )}]
    )
    trajectories.append({
        "task": task,
        "trajectory": response.content.text,
        "source": "claude-sonnet-4-5"
    })

pathlib.Path("app_sft_trajectories.jsonl").write_text(
    "\n".join(json.dumps(t) for t in trajectories)
)
```

**Stage B — RLAIF (464 verification pairs)**

After SFT convergence, apply RLAIF where an LLM judge evaluates each rollout on five dimensions: correctness, completeness, relevance, clarity, and reasoning quality. For your app, "correctness" is whether executing the rollout's actions achieves the stated goal in a sandboxed macOS environment — this is a verifiable ground truth, not model speculation.[^1]

The SWE-QA-Pro recipe trained Qwen3-8B to surpass GPT-4o by 2.3 points on their benchmark. The key lever was filtering out tasks solvable by direct answer (no app exploration needed), forcing the model to internalize genuinely agentic behaviors.[^7][^1]
### The Game-Changer: Doc-to-LoRA for Instant App Updates
**Sakana AI's Doc-to-LoRA** (February 2026) is the most significant recent advance for app-specific model updating. Instead of running a full fine-tuning pipeline every time your app ships a UI update, a **hypernetwork generates a LoRA adapter from your updated source code in a single forward pass** — with no gradient computation at deploy time.[^8][^9]

How it works:[^9][^8]
1. Feed your app's codebase (Swift source + AX atlas JSON) through a frozen base LLM to get per-layer activations
2. A Perceiver-style hypernetwork maps those activations to rank-8 LoRA matrices (A and B for each target layer)
3. The resulting adapter encodes your app's facts and UI structure directly in model weights
4. Total latency: **sub-second, from code → deployed adapter**, vs. 15–30 minutes for standard fine-tuning

KV-cache memory drops from over 12GB (keeping the app codebase in context) to under 50MB (adapter only). For documents (or codebases) exceeding the context window, D2L uses a chunking mechanism: split into K chunks, process independently, concatenate adapters along the rank dimension.[^9]

```python
# doc_to_lora_app_adapter.py
# Meta-train once on diverse codebases, then deploy for any app update

from doc_to_lora import DocToLoRA  # Sakana AI implementation

# Load pre-trained hypernetwork (train once, use forever)
hypernetwork = DocToLoRA.from_pretrained("path/to/pretrained_hypernetwork")
base_model = load_mohawk_base()

# When your app ships a new version:
def generate_app_adapter_on_ship(app_version: str, source_root: str):
    # Collect all Swift files + AX atlas
    app_docs = []
    for swift_file in pathlib.Path(source_root).rglob("*.swift"):
        app_docs.append(swift_file.read_text())
    ax_atlas = json.loads(pathlib.Path("app_atlas_differential.jsonl").read_text())
    combined_doc = "\n\n".join(app_docs) + "\n\n" + json.dumps(ax_atlas, indent=2)
    
    # Single forward pass through hypernetwork → LoRA adapter
    adapter = hypernetwork.generate_adapter(
        document=combined_doc,
        target_model=base_model,
        lora_rank=8
    )
    
    # Save alongside app version
    adapter.save(f"adapters/yourapp_{app_version}.lora")
    print(f"Generated adapter for v{app_version} in {adapter.generation_time:.2f}s")
    return adapter

# Called from Xcode post-build script:
# python doc_to_lora_app_adapter.py --version $MARKETING_VERSION --source $SRCROOT
```

The hypernetwork must be meta-trained once on a diverse corpus of codebases paired with fine-tuned LoRA targets. A practical approach: gather 50 open-source macOS apps from GitHub, generate AX atlases and symbol QA pairs for each, fine-tune standard LoRA adapters for each, then train the D2L hypernetwork to predict those adapters from the corresponding source code.[^8]

***
## Part II: Three-Model Family (Nano/Base/Pro)
### Architecture of a Scale Ladder
The NVIDIA Nemotron 3 family (Nano → Super, March 2026) is the most directly relevant reference architecture for your Mamba-2/Attention multi-scale plan. NVIDIA explicitly describes the Nano→Super progression as scaling the same hybrid Mamba-Attention architecture, with **agentic training data and multi-step tool-using behavior** as the primary performance differentiator at each tier — not just parameter count.[^10]

Your three tiers map to distinct capability thresholds and deployment contexts:

| Property | Nano (1B) | Base (3B) | Pro (7B) |
|---|---|---|---|
| **Primary use** | Reflex device actions (<100ms) | Multi-step planning + orchestration | Deep agentic reasoning + new app learning |
| **AX tree depth** | 1–3 levels, simple UI | 1–5 levels, modal dialogs | Full 8+ level hierarchies |
| **Action chain length** | 1–3 steps | 3–8 steps | 8–20+ steps |
| **Context window** | 2,048 tokens | 4,096 tokens | 8,192 tokens |
| **Deployment** | Always-on, ANE/NPU | On-demand, GPU | Cloud-optional |
| **GRPO group size** | 8 completions | 12 completions | 16 completions |
| **LoRA rank** | 8 | 16 | 32 |
| **Shared components** | Tokenizer, AXPress schema, adapter naming, MOHAWK ratios | ← same → | ← same → |
### Shared Infrastructure — Build Once, Scale Thrice
The most powerful aspect of a family approach is **shared training infrastructure**. Everything built for Nano directly benefits Base and Pro:

**1. Shared tokenizer** — train a single vocabulary on the union of macOS AX trees, Swift/ObjC source code, and general conversation data, then use it unchanged across all three sizes. Kimi used a 3B MoE proxy for ablations during K2's 1T-parameter development. Your Nano IS the proxy model for Base; Base IS the proxy for Pro.[^11]

**2. Shared AX atlas** — the app-specific atlas generated in Part I is format-identical for all three sizes. The LoRA rank changes (8/16/32), but the training data and adapter format are the same.

**3. Shared AXPress schema + constrained decoding** — the JSON schema for device actions is universal. All three models validate against the same XGrammar grammar at inference time.

**4. Shared tLoRA training infrastructure** — **tLoRA** (arXiv, February 2026) enables training all three model sizes' LoRA adapters simultaneously on a shared GPU cluster. It uses a Shared Super-Model (SSM) abstraction: the frozen backbone is shared, adapter-specific branches diverge. A fused heterogeneous LoRA kernel with adaptive nano-batching maximizes GPU utilization across heterogeneous adapter ranks:[^12]

```python
# tlora_multi_scale_training.py — train Nano/Base/Pro adapters simultaneously
from tlora import TLoRATrainer, AdapterJob

jobs = [
    AdapterJob(
        model_path="mohawk_nano_1b",
        adapter_rank=8,
        data_path="axpress_cherry_nano.jsonl",
        batch_size=8,
        name="nano_axpress_v2"
    ),
    AdapterJob(
        model_path="mohawk_base_3b",
        adapter_rank=16,
        data_path="axpress_cherry_base.jsonl",
        batch_size=6,
        name="base_axpress_v2"
    ),
    AdapterJob(
        model_path="mohawk_pro_7b",
        adapter_rank=32,
        data_path="axpress_cherry_pro.jsonl",
        batch_size=4,
        name="pro_axpress_v2"
    ),
]

# tLoRA batches these jobs over a shared backbone where possible,
# amortizing compute across adapters and maximizing GPU utilization
trainer = TLoRATrainer(jobs=jobs, nano_batch_controller="aimd")
trainer.train(total_steps=1000)
```
### Data Differentiation Across Tiers
Each tier should receive the same data format but **different complexity distributions**:

```python
# multi_scale_data_splitter.py
import json

def split_by_tier(examples: list[dict]) -> dict:
    """
    Partition training data by task complexity for 3-tier model family.
    Uses IFD score + chain length + AX tree depth as proxies.
    """
    tiers = {"nano": [], "base": [], "pro": []}
    
    for ex in examples:
        chain_len = len(ex.get("trajectory", []))
        tree_depth = ex.get("ax_tree_depth", 1)
        ifd = ex.get("ifd_score", 0.5)
        
        # Nano: short chains, shallow trees, moderate IFD
        if chain_len <= 3 and tree_depth <= 3 and ifd < 0.7:
            tiers["nano"].append(ex)
        
        # Base: medium chains, moderate trees
        elif chain_len <= 8 and tree_depth <= 5:
            tiers["base"].append(ex)
        
        # Pro: all complexity, especially long chains and deep trees
        else:
            tiers["pro"].append(ex)
        
        # ALL examples go into Base and Pro training — they should learn
        # everything Nano knows, plus harder cases
        if ex not in tiers["base"]:
            tiers["base"].append(ex)  # base trains on Nano's data too
        if ex not in tiers["pro"]:
            tiers["pro"].append(ex)   # pro trains on everything

    return tiers
```

**Critical**: Base and Pro should **always include Nano's training data** plus additional harder examples. This ensures capability inheritance — Pro can do everything Nano does, faster and with more context, plus its own advanced capabilities. Do not train tiers in isolation.
### Progressive Distillation Across the Ladder
Use **Nano as the student and Base as the teacher** within your MOHAWK distillation stages. Then use Base as student and Pro as teacher. This creates a cascade that efficiently transfers capabilities downward:

```
Llama 3.2 1B (Original Teacher)
        ↓ MOHAWK 3-stage distillation
   MOHAWK Pro (7B student of Llama)
        ↓ MOHAWK 3-stage distillation  
   MOHAWK Base (3B student of Pro)
        ↓ MOHAWK 3-stage distillation
   MOHAWK Nano (1B student of Base)
```

Each distillation stage uses **gradient matching + attention transfer**, transferring the specific layers where the teacher learned app-specific patterns. For Pro, the teacher is Llama 3.2 3B (existing, pre-trained). For Base, the teacher is your own Pro checkpoint after app fine-tuning.[^13]
### Agentic Capability Training at Scale
The Nemotron 3 Super paper identified that **agentic training data volume** — specifically multi-step tool-using behavior — was the principal factor separating capability tiers. For your device-control domain, "agentic" means training on tasks that require:[^10]

1. **Sub-goal decomposition**: "export all invoices from 2025 as PDFs" → enumerate invoices → loop through each → export each → verify completion
2. **Error recovery**: agent attempts action → fails (element not found) → re-reads AX tree → identifies correct element → retries
3. **Cross-session context**: maintaining knowledge of past actions across macOS Sleep/Wake cycles

The **Agent-RLVR pattern** directly addresses sparse rewards in multi-step sequences. For Pro-tier training specifically, construct training batches where ≥40% of examples require 5+ steps and have intentionally injected failure modes that the model must recover from.[^14]

```python
# agentic_scale_curriculum.py
# Generates Pro-tier training data with explicit multi-step agentic requirements

AGENTIC_TASK_TEMPLATES = [
    # Level 1: Sequential (Nano-tier)
    "Click the {button_name} button in {app_name}",
    
    # Level 2: Conditional (Base-tier) 
    "If the document is unsaved, save it; then export as PDF",
    
    # Level 3: Looping with state tracking (Pro-tier)
    "For each document in the Recent Documents list, check if it has been modified today. "
    "If yes, create a backup copy in ~/Backups/",
    
    # Level 4: Error recovery + replanning (Pro-tier+)
    "Open {app_name} and navigate to {screen}. "
    "If the app is not running, launch it first. "
    "If the screen requires authentication, handle the auth dialog. "
    "Then perform: {terminal_action}",
    
    # Level 5: Cross-app orchestration (Pro-tier+)
    "Read the email from {sender} in Mail, extract the deadline date, "
    "create a Calendar event for that date, and mark the email as flagged",
]

def generate_agentic_batch(tier: str, n_examples: int) -> list[dict]:
    """Generate training examples at appropriate agentic complexity for each tier."""
    if tier == "nano":
        templates = AGENTIC_TASK_TEMPLATES[:1]
    elif tier == "base":
        templates = AGENTIC_TASK_TEMPLATES[:2]
    else:  # pro
        templates = AGENTIC_TASK_TEMPLATES  # all levels including cross-app
    
    examples = []
    for _ in range(n_examples):
        template = random.choice(templates)
        filled = fill_template(template)  # inject real app/screen/button names from atlas
        trajectory = generate_trajectory_with_teacher(filled)  # use Claude as teacher
        examples.append({"task": filled, "trajectory": trajectory, "tier": tier})
    return examples
```
### LoRA Hot-Swap Router for the 3-Model System
At inference time, all three models are managed by a **central router** that selects both the model tier and the active adapter based on task complexity estimation:

```python
# model_router.py — runtime tier + adapter selection
import subprocess, time
from enum import Enum

class Tier(Enum):
    NANO = "nano"    # 1B, ANE, <100ms
    BASE = "base"    # 3B, GPU, <500ms
    PRO  = "pro"     # 7B, GPU, <2s

class DeviceAgentRouter:
    
    COMPLEXITY_SIGNALS = {
        "chain_length_estimate": lambda intent: len(intent.split("then")) + len(intent.split("and then")),
        "cross_app_signal": lambda intent: any(app in intent.lower() for app in ["mail", "calendar", "finder", "safari", "terminal"]),
        "error_recovery_signal": lambda intent: any(kw in intent.lower() for kw in ["if", "unless", "when", "retry", "until"]),
        "loop_signal": lambda intent: any(kw in intent.lower() for kw in ["each", "all", "every", "loop", "repeat"]),
    }
    
    def select_tier(self, intent: str, ax_tree_depth: int) -> Tier:
        chain_est = self.COMPLEXITY_SIGNALS["chain_length_estimate"](intent)
        cross_app = self.COMPLEXITY_SIGNALS["cross_app_signal"](intent)
        error_rec = self.COMPLEXITY_SIGNALS["error_recovery_signal"](intent)
        loop = self.COMPLEXITY_SIGNALS["loop_signal"](intent)
        
        if cross_app or loop or (chain_est > 5 and error_rec):
            return Tier.PRO
        elif chain_est > 3 or error_rec or ax_tree_depth > 4:
            return Tier.BASE
        else:
            return Tier.NANO
    
    def select_adapter(self, bundle_id: str, tier: Tier) -> str:
        """Return the appropriate LoRA adapter path for the active app + tier."""
        app_specific = f"adapters/{bundle_id}_{tier.value}.lora"
        generic_macos = f"adapters/macos_general_{tier.value}.lora"
        
        import os
        if os.path.exists(app_specific):
            return app_specific
        return generic_macos
    
    def route(self, intent: str, ax_tree_depth: int, bundle_id: str) -> dict:
        tier = self.select_tier(intent, ax_tree_depth)
        adapter = self.select_adapter(bundle_id, tier)
        return {"tier": tier.value, "adapter": adapter, 
                "estimated_latency_ms": {"nano": 80, "base": 400, "pro": 1800}[tier.value]}
```

***
## Part III: Niche Pipeline Integration
### App-Code Training in the Nightly Flywheel
The nightly flywheel (from the previous report) extends naturally to include app-specific training. The key addition is a **version-triggered adapter regeneration step**:

```python
# app_version_trigger.py — runs in Xcode post-build phase
import subprocess, pathlib, json
from datetime import datetime

APP_VERSION = "$(MARKETING_VERSION)"  # injected by Xcode
ADAPTER_DIR = pathlib.Path("~/mohawk_adapters").expanduser()

def check_and_retrain_if_needed(version: str):
    version_marker = ADAPTER_DIR / f"yourapp_{version}.lora"
    
    if not version_marker.exists():
        print(f"[ADAPTER] New version {version} — generating app adapter")
        
        # Option A: Doc-to-LoRA instant generation (if hypernetwork trained)
        if (ADAPTER_DIR / "d2l_hypernetwork.pt").exists():
            generate_d2l_adapter(version)  # < 1 second
        
        # Option B: Standard 200-iteration fine-tune (15 min on Apple Silicon)
        else:
            subprocess.run([
                "python", "-m", "mlx_lm.lora",
                "--model", str(ADAPTER_DIR / "mohawk_nano_base"),
                "--data", "app_atlas_differential.jsonl",
                "--lora-rank", "8",
                "--iters", "200",
                "--save-path", str(version_marker),
                "--adapter-path", str(ADAPTER_DIR / "yourapp_latest.lora"),
            ])
        
        # Update symlink
        (ADAPTER_DIR / "yourapp_latest.lora").unlink(missing_ok=True)
        (ADAPTER_DIR / "yourapp_latest.lora").symlink_to(version_marker)
        print(f"[ADAPTER] Deployed adapter for v{version}")

check_and_retrain_if_needed(APP_VERSION)
```
### LLamaFactory as the Unified SFT Orchestrator
**LLamaFactory** (100+ models, 170% speed with Unsloth patch) provides the cleanest CLI for orchestrating all three model tiers from a single config. You run one training job per tier, using the same dataset format:[^15]

```bash
# nano_train.yaml
model_name_or_path: mohawk_nano_1b
finetuning_type: lora
lora_rank: 8
lora_target: all
dataset: axpress_cherry_nano,app_atlas_nano,app_symbol_qa
template: llama3  # or your custom AXPress template
cutoff_len: 2048
learning_rate: 3e-4
num_train_epochs: 3
per_device_train_batch_size: 8
gradient_accumulation_steps: 4
use_unsloth: true  # 170% speed
output_dir: adapters/nano_axpress_v2

# Run: llamafactory-cli train nano_train.yaml
# Then for base: swap model_name_or_path, lora_rank: 16, dataset: *_base, cutoff_len: 4096
# Then for pro:  swap model_name_or_path, lora_rank: 32, dataset: *_pro, cutoff_len: 8192
```

The `dataset` field accepts comma-separated names pointing to files in `data/dataset_info.json`. Registering all three tier-specific datasets once enables one-command training for any tier at any time.

***
## Critical Failure Modes and Mitigations
1. **Cross-file blindness in app-specific training**: Training on individual Swift files without dependency context produces a model that can name elements but cannot predict downstream effects of actions. Always include the CGM code graph or at least the Xcode symbol graph relationships alongside individual file contents.[^2]

2. **AX tree stale reads**: `macapptree` occasionally returns cached element states for partially rendered windows. Add a 150ms sleep after triggering any navigation action before calling `get_tree()` again — Apple's accessibility subsystem needs time to propagate state changes.[^16]

3. **Catastrophic forgetting of general macOS knowledge**: App-specific LoRA fine-tuning can overfocus the model on your app's selectors, degrading performance on other apps. Mitigate by always including 20% general macOS examples in every app-specific SFT batch — not just your app's traces.

4. **Version drift without adapter updates**: If your app ships a UI change (button renamed, modal restructured) and the adapter hasn't been regenerated, the model will confidently emit stale selectors that fail silently. The Xcode post-build script above prevents this — make adapter generation a mandatory build step before QA.

5. **tLoRA rank heterogeneity causing gradient contamination**: When training Nano (rank 8) and Pro (rank 32) simultaneously via tLoRA, the rank mismatch means gradient scales differ by 4×. Apply per-adapter gradient clipping independently, not globally, to prevent Pro's larger gradients from dominating the shared backbone update.[^12]

6. **Doc-to-LoRA hypernetwork overfitting to training app styles**: If you meta-train D2L only on iOS/macOS apps similar to yours, it will fail on apps with unusual patterns. Include 20% web apps, CLI tools, and games in the meta-training corpus to maintain generalization.[^8]

***
## Master Training Schedule
| Week | Activity | Output |
|------|----------|--------|
| 1 | Build app code graph (CGM). Generate AX atlas + differential snapshots. Run Xcode symbol graph extraction | `app_code_graph.json`, `app_atlas_differential.jsonl`, `app_symbol_qa.jsonl` |
| 2 | Generate 1,000 SFT trajectories via Claude Sonnet. IFD-score all data. Split into tier buckets | `app_sft_trajectories.jsonl`, tier-split JSONL files |
| 3 | MOHAWK Stage 1–3 distillation for all three tiers (can parallelize with tLoRA) | `mohawk_nano_base`, `mohawk_base_base`, `mohawk_pro_base` |
| 4 | App-specific SFT for all three tiers (LLamaFactory). CAMPUS curriculum ordering | `nano_axpress_v1.lora`, `base_axpress_v1.lora`, `pro_axpress_v1.lora` |
| 5 | RLAIF stage: 464 app-verification pairs + GRPO with rubric-decomposed reward | Policy-improved adapters for all 3 tiers |
| 6 | Meta-train Doc-to-LoRA hypernetwork on 50 open-source macOS app codebases | `d2l_hypernetwork.pt` — enables instant future adapters |
| 7+ | Nightly flywheel live: collect traces → IFD filter → CAMPUS sort → LoRA fine-tune → BFCL eval → deploy | Continuously improving production adapters |

---

## References

1. [SWE-QA-Pro: A Representative Benchmark and Scalable Training ...](https://arxiv.org/html/2603.16124v1) - (2025) Swift: a scalable lightweight infrastructure for fine-tuning. ... source code, configuration,...

2. [Fine-Tuning LLMs on Large Proprietary Codebases - Models](https://discuss.huggingface.co/t/fine-tuning-llms-on-large-proprietary-codebases/155828) - I'm currently fine-tuning a large language model (LLM) on a proprietary codebase. The fine-tuning pr...

3. [NeurIPS Poster Code Graph Model (CGM)](https://neurips.cc/virtual/2025/poster/117200) - To this end, we introduce Code Graph Models (CGMs), which integrate repository code graph structures...

4. [A Graph-Integrated Large Language Model for Repository-Level ...](https://arxiv.org/html/2505.16901v4) - Noisy Fine-tuning: This phase fine-tunes CGM on real-world issue-patch pairs (Jimenez et al., 2024) ...

5. [Paper page - Code Graph Model (CGM) - Hugging Face](https://huggingface.co/papers/2505.16901) - Code Graph Model (CGM): A Graph-Integrated Large Language Model for Repository-Level Software Engine...

6. [CGM: Code Graph LLM - GitHub](https://github.com/codefuse-ai/CodeFuse-CGM) - We propose a graph-based framework CGM for real-world SE tasks. Before CGM starts its work, we const...

7. [SWE-QA-Pro: A Representative Benchmark and Scalable Training ...](https://arxiv.org/abs/2603.16124) - Empirically, a Qwen3-8B model trained with our recipe surpasses GPT-4o by 2.3 points on SWE-QA-Pro a...

8. [Instant LLM Updates with Doc-to-LoRA and Text-to-LoRA - Sakana AI](https://pub.sakana.ai/doc-to-lora/) - Doc-to-LoRA enables knowledge updates by turning documents into LoRA adapters, allowing a model to i...

9. [Sakana AI Introduces Doc-to-LoRA and Text-to-LoRA - MarkTechPost](https://www.marktechpost.com/2026/02/27/sakana-ai-introduces-doc-to-lora-and-text-to-lora-hypernetworks-that-instantly-internalize-long-contexts-and-adapt-llms-via-zero-shot-natural-language/) - Doc-to-LoRA and Text-to-LoRA: Hypernetworks that Instantly Internalize Long Contexts and Adapt LLMs ...

10. [[PDF] Nemotron 3 Super: Open, Efficient Mixture-of-Experts Hybrid Mamba ...](https://research.nvidia.com/labs/nemotron/files/NVIDIA-Nemotron-3-Super-Technical-Report.pdf) - Abstract. We describe the pre-training, post-training, and quantization of Nemotron 3 Super, a 120 b...

11. [huggingface-smol-training-playbook-made-by-crawl4ai.md · GitHub](https://gist.github.com/unclecode/e5da5fb6a1d37022b089e243e0d9e00e) - Below is a non-exhaustive list of strong 2025 baseline options for various architectures and model s...

12. [tLoRA: Efficient Multi-LoRA Training with Elastic Shared Super-Models](https://arxiv.org/html/2602.07263v2) - Supporting large numbers of LoRA adapters at scale introduces significant efficiency challenges. Tre...

13. [Training an Expert Coding Agent with Reinforcement Fine-Tuning](https://www.rubrik.com/blog/ai/25/training-ai-coding-agents-with-reinforcement-fine-tuning-llms) - To solve this, we used Reinforcement Fine-Tuning (RFT) to turn a general-purpose code LLM into a dom...

14. [[2506.11425] Agent-RLVR: Training Software Engineering ... - arXiv](https://arxiv.org/abs/2506.11425) - In this work, we introduce Agent-RLVR, a framework that makes RLVR effective in challenging agentic ...

15. [GitHub - hiyouga/LlamaFactory: Unified Efficient Fine-Tuning of 100 ...](https://github.com/hiyouga/LlamaFactory) - LazyLLM: An easy and lazy way for building multi-agent LLMs applications and supports model fine-tun...

16. [MacPaw/macapptree: Repository for macos accessibility parser](https://github.com/MacPaw/macapptree) - macapptree is a Python package that extracts the accessibility tree of a macOS application's screen ...

