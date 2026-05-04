# Training a 1B Model on macOS App Data: Full-Spectrum Guide

## Overview

This guide covers everything needed to train a 1-billion-parameter model that truly understands macOS architecture, computer use, and your specific app — from the lowest hardware layers all the way up to gesture-level UI reflexes. The goal is a model that has "muscle memory" for your app: every element, every scroll pattern, every possible interaction sequence is internalized as second nature. The methodology is drawn from state-of-the-art computer-use agent research, Apple's own ML frameworks, and academic work on GUI understanding.

***

## Part 1: Understanding macOS Architecture for Training Data

To train a model with real architectural nuance, you need data covering all layers of the macOS stack. Events and signals in macOS flow through three distinct levels:[^1]

- **IOKit (hardware layer)** — raw input directly from the hardware (HID: Human Interface Device)
- **Quartz / CoreGraphics (CGEvent layer)** — the OS intercepts and routes input through this mid-level; this is where `CGEventTap` lives
- **Cocoa / AppKit (highest level)** — the framework apps typically interface with; `NSEvent` and the Accessibility API live here

### macOS Subsystems to Capture

| Subsystem | What It Governs | Key APIs |
|---|---|---|
| IOKit / HID | Raw keyboard, mouse, trackpad input | `IOHIDManager`, `IOHIDManagerRegisterInputValueCallback`[^2] |
| CoreGraphics (CGEvent) | System-wide event routing and tapping | `CGEvent.tapCreate`, `CGEventTapCallBack`[^3][^1] |
| Accessibility API (AX) | UI element tree, semantic labels, roles, actions | `AXUIElement`, `AXObserver`[^4][^5] |
| AppKit / Cocoa | App-level event handlers, window management | `NSEvent`, `addGlobalMonitorForEvents` |
| Core ML / Neural Engine | On-device inference and ML acceleration | Core ML, Apple Neural Engine (ANE)[^6] |
| Unified Memory Architecture | CPU/GPU shared memory (zero-copy) | Metal, MLX[^6] |
| Foundation Models (macOS 26+) | On-device foundation model API | Foundation Models framework[^7] |

### Key Architectural Nuances to Encode in Training Data

**Unified Memory Architecture (UMA):** Apple Silicon's UMA means the CPU, GPU, and Neural Engine all share the same memory pool with zero PCIe copy overhead. Your training data should reflect that the model understands this: actions like rendering, inference, and process scheduling all compete for the same memory bandwidth.[^6]

**ANE (Apple Neural Engine):** Core ML code runs automatically on the Neural Engine when `computeUnits` is set to `"all"` (the default). Understanding this is critical for generating code or instructions that properly target the hardware.[^6]

**MLX Framework:** Apple's MLX is an array framework optimized for Apple Silicon's unified memory, enabling efficient local fine-tuning without cloud dependency. The model should understand how MLX distributes work across CPU, GPU, and ANE.[^8][^9]

**Pointer Authentication & Kernel Integrity Protection:** Apple Silicon uses hardware-level pointer authentication and immutable kernel code pages. Any computer-use agent data that touches system internals must respect these security invariants.[^6]

***

## Part 2: Data Collection Techniques — macOS Architecture & Computer Use

### 2.1 The Accessibility API: Your Primary Data Source

The macOS Accessibility API (`AXUIElement`) is the cornerstone of UI data collection for computer-use training. Every running application exposes a hierarchical accessibility tree — a structured JSON-like representation of all visible UI elements with their roles, positions, actions, and values.[^5][^10]

**macapptree** is an open-source Python package (by MacPaw) that extracts a running app's full accessibility tree in clean, hierarchical JSON format. It is the engine behind the GUIrilla framework and is designed specifically for this use case.[^11]

```bash
pip install macapptree
# Captures the full AX tree of any running app as structured JSON
```

**AXObserver** lets you register persistent notification callbacks so the tree is captured live, every time any UI element changes state. The pattern is:[^12]
1. Instantiate `AXUIElementCreateApplication(pid)` for your target app
2. Create an `AXObserver` with `AXObserverCreate`
3. Register for all notification types (`kAXWindowResizedNotification`, `kAXFocusedUIElementChangedNotification`, etc.)
4. Every callback fires → serialize the full AX tree + screenshot + timestamp → training record[^13]

**Screen2AX** (MacPaw, 2025) is a complementary vision-based framework that infers the accessibility tree from raw screenshots alone, using YOLOv11 for element detection and GPT-4 for classification. This is useful for generating training data from apps that don't fully expose their AX tree.[^14]

### 2.2 CGEventTap: Capturing Every Input Event

`CGEventTap` (CoreGraphics layer) is the gold standard for capturing all system-level input at high fidelity — before apps see it.[^3][^1]

```swift
let eventTap = CGEvent.tapCreate(
    tap: .cghidEventTap,           // Lowest tap point — catches all HID events
    place: .headInsertEventTap,    // Before any app processes it
    options: .listenOnly,          // Observe only, don't block
    eventsOfInterest: CGEventMask([
        .keyDown, .keyUp, .flagsChanged,
        .mouseMoved, .leftMouseDragged, .rightMouseDragged,
        .leftMouseDown, .leftMouseUp,
        .scrollWheel, .tabletPointer, .gesture
    ]),
    callback: myCallback,
    userInfo: nil
)!
```

Each event fires your callback with a `CGEvent` object containing: event type, mouse position, scroll delta, key codes, modifier flags, pressure (for Force Touch), and timing. Logging these alongside synchronized AX tree snapshots and screenshots gives you a ground-truth trace of every user interaction.[^15][^16]

**For the IOKit layer** (raw HID events), `IOHIDManager` lets you register callbacks that fire directly on hardware input, below even CGEvent. This is useful for capturing raw trackpad pressure, multi-touch finger data, and keyboard scan codes that may be normalized away at higher layers.[^2]

### 2.3 GUIrilla Framework — State-of-the-Art macOS Dataset Construction

**GUIrilla** (MacPaw, 2025–2026) is the most advanced open-source framework for automated macOS GUI data collection. It:[^10][^17]

- Crawls macOS applications via the Accessibility API, building hierarchical **MacApp Trees** — full UI state + user action pairs organized as JSON trees[^10]
- Was deployed across **12,298 macOS applications** on a cluster of M1 Mac Minis, yielding **27,171 tasks** across **23 application genres** from ~4,200 unique full-desktop screens[^10]
- Released **561 GB of compressed MacApp Trees** as open-source artifacts[^10]
- Trained **GUIrilla-See models (0.7B, 3B, 7B)** on only 4.2K unique macOS screens and achieved strong transfer to downstream GUI benchmarks[^10]

For your specific app, run GUIrilla's crawler directly against it (it supports single-app targeting) to get a complete tree of every reachable UI state.

### 2.4 OSWorld & OS-ATLAS: Cross-Platform Computer Use Data

**OSWorld** is the primary benchmark for computer-use agents. It contains 369 real-world tasks spanning web apps, desktop apps, OS file I/O, and multi-app workflows on Ubuntu, Windows, and macOS. Critically, it provides reproducible initial states and execution-based evaluation scripts — meaning you can generate unlimited training trajectories by having agents attempt tasks and logging every step.[^18][^19]

**OS-ATLAS** released the largest open-source cross-platform GUI grounding dataset — over **13 million GUI elements** across Windows, Linux, macOS, Android, and web. However, macOS is severely underrepresented: macOS screenshots comprise only **0.06% of OS-Atlas** and roughly **2.45% of automatically collected desktop UIs**. This is why GUIrilla specifically targeted macOS.[^20][^10]

For base knowledge of "all computer use," include OS-ATLAS data in your pretraining or continual pretraining corpus. For macOS-specific nuance, prioritize GUIrilla-Trees and your own collected data.

### 2.5 Gesture & Scroll Pattern Collection

All possible scroll patterns, gesture combinations, and manual movements require a systematic collection strategy:

**Trackpad Multi-Touch Data:** macOS exposes multi-touch data via private APIs (used by apps like BetterTouchTool). For training data purposes, CGEventTap captures `scrollWheel` events including `deltaX`, `deltaY`, `deltaZ`, momentum phase (began/changed/ended/cancelled), and scroll direction. You can enumerate every scroll variant:[^16]
- Single-finger scroll (Magic Mouse)
- Two-finger scroll, pinch-to-zoom, rotate
- Three-finger swipe (Mission Control, Exposé)
- Four-finger swipe (app switching)
- Force Touch click levels (click, force click)

**Full Gesture Enumeration:** Record a session matrix where you manually perform every documented macOS gesture while logging: (1) CGEvent stream, (2) AX tree delta, (3) screenshot before/after, (4) resulting system state change. This generates ground-truth input→effect pairs.[^21]

**Scroll Pattern Taxonomy:** Programmatically generate synthetic scroll sequences (slow, fast, inertial, bounce, overscroll, rubberbanding) using `CGEventPost` and log the resulting UI state transitions. This covers patterns a user might never perform organically.

***

## Part 3: Building the App-Specific Training Dataset

### 3.1 Full App State Mapping

The goal is a complete **state graph** of your app — every screen, every element, every reachable UI state. Think of it as a finite state machine where each node is a UI state and each edge is an action (tap, scroll, keyboard shortcut, drag).

**Step 1 — Static Snapshot:** Run macapptree against every screen of your app while manually navigating through all flows. Capture: AX tree JSON, screenshot, screen dimensions, dark/light mode variants.

**Step 2 — Dynamic Crawl:** Use GUIrilla's crawler to automatically explore the app. Configure it with:
- `Maximum parsing tree depth: 25` (default, captures deep modal flows)
- `Maximum parsing duration: 2+ hours` per major app section[^10]
- Enable LLM-assisted element ordering for smarter navigation

**Step 3 — Edge Case Enumeration:** Manually cover all states the crawler misses: error states, empty states, loading states, confirmation dialogs, context menus, tooltips, keyboard shortcut panels, settings/preferences screens.

**Step 4 — Interaction Recording:** For every state, record all valid actions. Use a tool like [SeeAction](https://arxiv.org/html/2503.12873v1) which reverse-engineers user actions from screencasts — giving you action annotations from existing recordings without manual labeling.[^22]

### 3.2 Dataset Schema: Training Record Format

Each training example should be a structured tuple following the format used by state-of-the-art agents like UI-TARS:[^23]

```json
{
  "screenshot": "<base64 or path>",
  "accessibility_tree": { /* macapptree JSON output */ },
  "action_history": ["click button X", "scroll down 3 units", "..."],
  "instruction": "Change the font size to 14pt",
  "action": {
    "type": "click",
    "element_id": "AXButton:Font Size Stepper Up",
    "coordinates": [412, 234],
    "gesture": "left_click"
  },
  "result_screenshot": "<base64 or path>",
  "result_accessibility_tree": { /* post-action AX tree */ }
}
```

Include all modalities your model will consume: screenshot, AX tree, instruction text, action taken, before/after state.

### 3.3 Synthetic Data Augmentation

For a 1B model, you need at minimum 1,000 examples per task type to avoid overfitting — and ideally 10,000+ for core workflows. Synthetic generation bridges the gap:[^24]

**LLM-Generated Instructions:** Take each recorded action trace and generate 10–50 paraphrased natural language instructions for the same action ("increase font size", "make text bigger", "bump up the font", "go to 14pt", etc.). This is the exact methodology used by UI-TARS-2.[^23]

**Action Augmentation:** For scroll events, programmatically generate variants: different scroll speeds, different starting positions, partial scrolls, scroll-then-pause patterns. Use `CGEventPost` to replay synthetic events and capture the resulting screenshots.

**Reasoning Chain Annotation:** UI-TARS-2 found that training on actions *without reasoning traces* produces models that mimic surface behavior without internalizing logic. For each action, annotate a chain-of-thought: "I see a Font Size stepper. The current value is 12. I need to increase it. I will click the up arrow twice." Use an LLM (GPT-4o, Claude, Gemini) to auto-generate these reasoning chains aligned with your recorded actions.[^23]

***

## Part 4: Training the 1B Model

### 4.1 Local Training with MLX on Apple Silicon

Apple's **MLX framework** is the recommended training stack for local 1B model fine-tuning on Mac. It runs entirely on-device, leverages the unified memory architecture, and requires no cloud dependency.[^9][^8]

```bash
# Fine-tune with LoRA on your dataset
mlx_lm.lora \
  --model "mlx-community/Llama-3.2-1B-Instruct-4bit" \
  --train \
  --data ./app_training_data \
  --iters 1000 \
  --batch-size 4 \
  --lora-layers 16

# Fuse adapter into base model
mlx_lm.fuse \
  --model "./llama-3.2-1b-instruct" \
  --adapter-path "adapters" \
  --save-path "fused-app-model"
```

MLX supports both **full fine-tuning** and **LoRA (Low-Rank Adaptation)**. For a 1B model on app-specific data, LoRA is the correct choice: it adds small trainable matrices to existing layers, reduces trainable parameters to 0.1–1% of the original model, and dramatically reduces overfitting risk on smaller datasets.[^25][^24][^8]

### 4.2 Three-Stage Training Pipeline (UI-TARS-2 Methodology)

The most effective approach, validated by UI-TARS-2 and PC Agent-E, is a **three-stage pipeline**:[^26][^23]

**Stage 1 — Continual Pretraining (CT):** Expose the base model to broad macOS and computer-use knowledge. Use OS-ATLAS GUI elements data, GUIrilla-Trees, Apple developer documentation, macOS HIG (Human Interface Guidelines), WWDC session transcripts, Stack Overflow macOS/Swift threads, and general computer-use corpora. This builds the "architectural vocabulary."

**Stage 2 — Supervised Fine-Tuning (SFT):** Train on your high-quality app-specific dataset: screenshot + AX tree + instruction → action pairs with reasoning traces. This is where your app becomes "second nature." Use LoRA at this stage with:
- Learning rate: 5e-5 to 1e-4
- Batch size: 4–8
- Epochs: 3–5 with early stopping
- Regularization: dropout 0.1

**Stage 3 — Reinforcement Learning (RL/RLVR):** Use **Reinforcement Learning with Verifiable Rewards** — the model attempts tasks in a live macOS environment (your app running in a VM or sandbox), and receives binary rewards based on whether the task was actually completed (verified by checking final AX tree state). This is what produces true "reflex" behavior rather than pattern matching.[^23]

### 4.3 Dataset Size Thresholds

| Dataset Size | Recommended Approach | Expected Outcome |
|---|---|---|
| Under 1,000 examples | LoRA or Prefix Tuning only | Specific task adaptation |
| 1,000–10,000 examples | LoRA with adapter layers | Solid task coverage, some generalization |
| 10,000–100,000 examples | LoRA + Partial Fine-Tuning | Broad app coverage, strong reflexes |
| 100,000+ examples | Full Fine-Tuning viable | Complete model specialization[^24] |

### 4.4 Preventing Catastrophic Forgetting

Fine-tuning a 1B model on app-specific data risks overwriting general computer knowledge. Mitigations:

- **LoRA** keeps original weights frozen; only the adapters change[^8]
- **Data mixing:** Include ~20% general computer-use data alongside your app data in every training batch
- **Low learning rates:** 5e-6 to 5e-5 for SFT stage[^24]
- **Perplexity monitoring:** Track base model perplexity on a held-out general corpus throughout training; if it spikes, reduce learning rate or increase general data ratio

***

## Part 5: The "Reflex Brain" — Making All Actions Second Nature

### 5.1 Complete Action Space Definition

Before training, exhaustively enumerate the complete action space of your app. Every possible thing a user or agent can do must be in the dataset:

**Atomic Actions:**
- `click(element_id, coordinates)`
- `double_click(element_id, coordinates)`
- `right_click(element_id, coordinates)`
- `type(text)`
- `key_press(key_combination)` — including all shortcuts (⌘Z, ⌃⇥, ⌥⌘T, etc.)
- `scroll(direction, amount, velocity)` — all variants
- `drag(start_coords, end_coords, duration)`
- `pinch(scale_factor)`
- `force_click(pressure_level)`

**Composite Patterns (sequences):**
- Scroll-to-element + click
- Select-all + type (replace content)
- Multi-select (⌘+click patterns)
- Drag-and-drop between UI zones
- Keyboard shortcut chains

**State-Conditional Actions:** For every UI state in the app, define which actions are valid. An action attempted on a disabled button or hidden element must also be represented (as an "impossible" or "no-op" example with appropriate reasoning: "This button is greyed out, I cannot click it here").

### 5.2 Pattern Completeness for Scrolling

To cover all possible scroll patterns, generate a **scroll matrix**:

| Direction | Speed | Phase | Momentum | Overscroll | Bounce |
|---|---|---|---|---|---|
| Vertical ↓ | Slow | began | no | no | no |
| Vertical ↑ | Fast | changed | yes | yes | yes |
| Horizontal → | Medium | ended | no | no | yes |
| Diagonal | Variable | cancelled | yes | no | no |

For each combination, record: the CGEvent parameters, the resulting content offset change, the AX tree delta, and the visual state. A model trained on this matrix will handle any scroll pattern it encounters.

### 5.3 Reward Shaping for Reflex Quality

In the RL stage, standard binary task completion rewards are insufficient for building reflex-level speed and accuracy. Augment with:

- **Efficiency reward:** Bonus for completing tasks in fewer steps than the human-annotated reference trajectory (OSWorld-Human found the best current agents take 1.4–2.7× more steps than necessary)[^27]
- **Precision reward:** Bonus for clicking within N pixels of the correct target (tight tolerance = higher reward)
- **Speed reward:** Bonus for completing within a time budget
- **Smoothness penalty:** Penalty for erratic cursor paths (high jitter = lower reward)

### 5.4 Video-Based Reward Modeling

A cutting-edge technique from a March 2026 paper: train a **reward model from execution video** — sequences of keyframes from agent trajectories. This reward model evaluates the *quality* of an agent's execution independent of whether the final task was completed. It catches subtle issues: clicking the right button in the wrong way, scrolling past the target, hovering without clicking. Use datasets like AgentNet, ScaleCUA, and OSWorld converted to step-level video representations to train this reward model, then apply it alongside verifiable task rewards during RL.[^28]

***

## Part 6: Tooling & Infrastructure

### 6.1 Recommended Stack

| Component | Tool | Purpose |
|---|---|---|
| AX Tree Extraction | macapptree (Python)[^11] | Serialize live app UI to JSON |
| App Crawling | GUIrilla[^10][^17] | Automated app state exploration |
| Input Capture | CGEventTap (Swift/Python)[^3] | All keyboard/mouse/scroll events |
| UI Element Detection | YOLOv11 + Screen2AX[^14] | Vision-based UI parsing from screenshots |
| Session Recording | Custom pipeline (screenshot + AX + events) | Aligned multimodal training records |
| Local Training | Apple MLX + mlx_lm[^8][^9][^29] | LoRA fine-tuning on Apple Silicon |
| Base Model | Llama 3.2 1B Instruct (MLX-Community) | Strong base for SFT |
| RL Environment | macOS VM / sandboxed app instance | Live interaction for reward-based training |
| Data Annotation | LLM-assisted reasoning chain generation | Chain-of-thought for every action |

### 6.2 MacosUseSDK

The **MacosUseSDK** library (mediar-ai) was noted by the macOS developer community as an "insanely fast library to traverse and control macOS" — purpose-built for exactly this use case. It wraps the Accessibility API with performance optimizations for programmatic control of any macOS application, making it ideal for both data collection and RL environment interaction.[^30]

### 6.3 Data Pipeline Architecture

```
[Live App Session]
        │
        ├─ CGEventTap → Raw input log (JSON)
        ├─ AXObserver → AX tree deltas (JSON)
        └─ Screenshot → PNG frames (synchronized)
        
[Alignment Layer]
        └─ Timestamp-join all three streams → unified training record

[Annotation Layer]
        ├─ LLM-generated instruction (50 paraphrases per action)
        ├─ LLM-generated reasoning chain
        └─ Manual annotation for complex flows

[Quality Filter]
        ├─ Deduplication (exact + near-duplicate AX tree removal)
        ├─ Executability verification (replay action, confirm state change)
        └─ Dual-annotator review for high-stakes flows

[Training Dataset] → JSONL format → MLX fine-tuning
```

***

## Part 7: Advanced Techniques

### 7.1 Never-Ending UI Learning

The **Never-ending UI Learner** pattern applies here: deploy your model, monitor cases where it fails or produces low-confidence predictions, use those cases as new training examples, fine-tune incrementally, repeat. This creates a self-improving data flywheel identical to what UI-TARS-2 uses at scale. Even with a 1B model, this loop compound-improves performance over weeks of deployment.[^31][^23]

### 7.2 Novice + Expert Annotation Tracks

UI-TARS-2 found significant value in collecting data from two annotator types:[^23]
- **Experts** who demonstrate optimal task completion paths
- **Novices** who explore unfamiliar tasks via trial-and-error, web search, and improvisation

Novice tracks capture valuable recovery behavior — what to do when something goes wrong, how to find a feature you've never used, how to interpret unexpected UI states. For a reflex brain, knowing the optimal path is table stakes; knowing how to *recover* from errors is what separates brittle agents from robust ones.

### 7.3 Hierarchical Task Graphs

For your app's training data, construct a **hierarchical task graph**: decompose every major app feature into a tree of sub-tasks, sub-sub-tasks, and atomic actions. Score each task by: frequency of use, difficulty (step count), cross-screen dependencies, and error rate. Prioritize data collection for high-frequency, high-difficulty tasks first. This ensures training effort is proportional to real-world impact.[^23]

### 7.4 Dark Mode / Light Mode & Accessibility Variants

macOS apps render differently across appearance modes, font size settings, reduce-motion settings, and display resolutions. Collect training data in all variants your app supports. Screen2AX's dataset was deliberately balanced: 52% light theme, 48% dark theme screenshots. A model trained only on light mode will hallucinate element positions in dark mode.[^14]

***

## Summary of Key Priorities

1. **macOS architecture knowledge** comes from broad CT on Apple developer docs, WWDC sessions, AX API specs, CGEvent documentation, and OS-ATLAS data
2. **App-specific reflexes** come from GUIrilla-style exhaustive crawling of your app combined with CGEventTap-logged real sessions
3. **Gesture/scroll completeness** requires systematic matrix-based synthetic generation covering all CGEvent scroll phases, directions, speeds, and multi-touch variants
4. **Reflex quality** emerges from Stage 3 RL with verifiable rewards, efficiency bonuses, and video-based reward modeling
5. **Robustness** requires both expert and novice annotation tracks, dark/light mode variants, and a never-ending learning loop on deployment failures

---

## References

1. [macOS keyboard event intercepted three ways - R0uter's Blog](https://www.logcg.com/en/archives/2902.html) - This article has detailed instructions,Pass it over here,How do we have focused on addressing key us...

2. [macOS - keylogging through HID device interface - The Evil Bit Blog](http://theevilbit.blogspot.com/2019/02/macos-keylogging-through-hid-device.html) - The built in keyboard on a MacBook Pro is also connecting through the USB / IOHID interface. That ma...

3. [CGEventTapCallBack | Apple Developer Documentation](https://developer.apple.com/documentation/coregraphics/cgeventtapcallback) - A client-supplied callback function that's invoked whenever an associated event tap receives a Quart...

4. [AXUIElement.h | Apple Developer Documentation](https://developer.apple.com/documentation/applicationservices/axuielement_h) - Assistive applications use the functions defined in this header file to communicate with and control...

5. [AXUIElement | Apple Developer Documentation](https://developer.apple.com/documentation/applicationservices/axuielement) - An accessibility object provides information about the user interface object it represents. This inf...

6. [Explore the new system architecture of Apple silicon Macs - WWDC20](https://developer.apple.com/videos/play/wwdc2020/10686/) - Leveraging a unified memory architecture for CPU and GPU tasks, Mac apps will see amazing performanc...

7. [Machine Learning & AI - Apple Developer](https://developer.apple.com/machine-learning/) - Learn how to build, use, train, and deploy machine learning and AI models for iPhone, iPad, Apple Vi...

8. [Explore large language models on Apple silicon with MLX - WWDC25](https://developer.apple.com/videos/play/wwdc2025/298/) - Discover MLX LM – designed specifically to make working with large language models simple and effici...

9. [WWDC 2025 - Explore LLM on Apple silicon with MLX](https://dev.to/arshtechpro/wwdc-2025-explore-llm-on-apple-silicon-with-mlx-1if7) - MLX is Apple's open-source machine learning framework specifically designed for Apple Silicon, enabl...

10. [GUIrilla: A Scalable Framework for Automated Desktop UI Exploration](https://arxiv.org/html/2510.16051v2) - Complete end-to-end implementation including data generation pipeline, model training code, evaluati...

11. [MacPaw/macapptree: Repository for macos accessibility parser](https://github.com/MacPaw/macapptree) - macapptree is a Python package that extracts the accessibility tree of a macOS applications screen i...

12. [I hit a dead end with accessibility APIs : r/swift - Reddit](https://www.reddit.com/r/swift/comments/18k909w/i_hit_a_dead_end_with_accessibility_apis/) - I tried to create a basic mac app that keeps track of which window you currently have focused. I tri...

13. [DevilFinger/DFAXUIElement: A fastway to use Accessibility ... - GitHub](https://github.com/DevilFinger/DFAXUIElement) - This is a Swift version to let you use Accessibility API with AXUIElement、AXObserver. It's a fastway...

14. [Vision-Based Approach for Automatic macOS Accessibility Generation](https://arxiv.org/html/2507.16704v1) - Desktop accessibility metadata enables AI agents to interpret screens and supports users who depend ...

15. [A Click Ahead: Real-Time Forecasting of Keyboard and Mouse Actions using
  RNNs and Computer Vision](http://arxiv.org/pdf/2309.12170.pdf) - Computer input is more complex than a sequence of single mouse clicks and
keyboard presses. We intro...

16. [CGEventType | Apple Developer Documentation](https://developer.apple.com/documentation/coregraphics/cgeventtype) - Specifies an event indicating the event tap is disabled because of timeout. ... Specifies an event i...

17. [MacPaw/GUIrilla: Repository for the implementation of ... - GitHub](https://github.com/MacPaw/GUIrilla) - We release GUIrilla-Trees, a large-scale dataset of accessibility trees for macOS applications, enab...

18. [OSWorld: Benchmarking Multimodal Agents for Open-Ended Tasks ...](https://proceedings.neurips.cc/paper_files/paper/2024/hash/5d413e48f84dc61244b6be550f1cd8f5-Abstract-Datasets_and_Benchmarks_Track.html) - OSWorld can serve as a unified, integrated computer environment for assessing open-ended computer ta...

19. [OSWorld: Benchmarking Multimodal Agents for Open-Ended Tasks ...](https://os-world.github.io) - Building upon OSWorld, we create a benchmark of 369 computer tasks involving real web and desktop ap...

20. [OS-ATLAS: A Foundation Action Model for Generalist GUI Agents](http://arxiv.org/pdf/2410.23218v1.pdf) - ...We have invested
significant engineering effort in developing an open-source toolkit for
synthesi...

21. [A Beginner's Guide to Navigating macOS With Ease - YouTube](https://www.youtube.com/watch?v=E52pkPORQpU) - ... macOS gestures can transform the way you use your Mac. In this comprehensive guide, I'll show yo...

22. [SeeAction: Towards Reverse Engineering How-What-Where of HCI Actions
  from Screencasts for UI Automation](https://arxiv.org/html/2503.12873v1) - UI automation is a useful technique for UI testing, bug reproduction, and
robotic process automation...

23. [UI-TARS-2 Technical Report: Advancing GUI Agent with Multi-Turn ...](https://arxiv.org/html/2509.02544v2) - Our continual pre-training framework spans multiple agent domains. Here we illustrate the methodolog...

24. [What Issues Might Arise from Using Small Dataset with Vanilla Fine ...](https://dialzara.com/blog/fine-tuning-llms-with-small-data-guide) - Learn how fine-tuning large language models with small datasets can enhance industry-specific AI too...

25. [Scaling Down to Scale Up: A Guide to Parameter-Efficient Fine-Tuning](https://arxiv.org/pdf/2303.15647.pdf) - This paper presents a systematic overview of parameter-efficient fine-tuning
methods, covering over ...

26. [Efficient Agent Training for Computer Use - arXiv](https://arxiv.org/html/2505.13909v1) - We introduce PC Agent-E, an efficient agent training framework that significantly reduces reliance o...

27. [OSWorld-Human: Benchmarking the Efficiency of Computer-Use ...](https://arxiv.org/abs/2506.16042) - We then construct OSWorld-Human, a manually annotated version of the original OSWorld dataset that c...

28. [Video-Based Reward Modeling for Computer-Use Agents - arXiv](https://arxiv.org/html/2603.10178) - In this work, we study reward modeling from execution video: a sequence of keyframes from an agent t...

29. [GitHub - ARahim3/mlx-tune: Fine-tune LLMs on your Mac with Apple ...](https://github.com/ARahim3/mlx-tune) - Requirements · Hardware: Apple Silicon Mac (M1/M2/M3/M4/M5) · OS: macOS 13.0+ · Memory: 8GB+ unified...

30. [Insanely Fast Library to traverse and control MacOS, perfect if u are ...](https://www.reddit.com/r/macapps/comments/1jsjs8w/insanely_fast_library_to_traverse_and_control/) - 101 votes, 22 comments. https://github.com/mediar-ai/MacosUseSDK.

31. [Never-ending Learning of User Interfaces](https://arxiv.org/pdf/2308.08726.pdf) - Machine learning models have been trained to predict semantic information
about user interfaces (UIs...

