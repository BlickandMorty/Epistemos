# Frontend Spec: AI-Powered Research, Writing & Notes App

> An AI-powered research, writing, and note-taking app with a 10-stage analytical pipeline.

This is a local-first productivity app that lets you:
- Take deep, structured notes in a block-based editor with vaults and journals
- Power your own local LLM (via Ollama) **or** connect to cloud APIs (OpenAI/Anthropic/Google) to get deep, deliberate AI-assisted analysis
- Do deep research — manage a library of papers/sources, tag them, annotate, export citations
- Tweak the behavior of the AI in real-time (steering controls, temperature, focus depth, complexity bias) — full control
- Run background agents that auto-learn from your notes

**API mode vs Local mode are fundamentally different experiences:**
- **Local mode:** Full steering lab — sliders for temperature, focus depth, complexity bias. You own the model, you control it.
- **API mode:** Read-only signal dashboard — see confidence/entropy/dissonance charts, but controls are grayed out.
- **Simulation mode:** Offline demo with templated responses, no API keys needed.

---

## Pages & Navigation

**Top navigation** is a floating pill-button bar (glass-morphism bubbles, centered at top of screen). Each bubble is a route:

### 1. Home / Chat (`/`)
The AI conversation interface and landing page.

- IDE-style animated greeting with code-rain canvas background
- Message list with **dual-view per response**:
  - "Research" view — raw, detailed analytical output
  - "Layman" view — simplified plain-language summary
- Streaming text with **reasoning accordion** — collapsible thinking process
- Multimodal text input at bottom
- **Synthesis card** — summarized findings with confidence % badge
- **Code artifact portal** — right-side drawer (Preview / Code / Edit modes)
- Recent chats grid on home page

### 2. Notes (`/notes`)
Block-based knowledge management system.

- **Floating right-panel sidebar** with: page list, favorites, pinned notes, search
- **Two view modes:** Notes Mode (block editor) and Canvas Mode (spatial whiteboard)
- **Block types:** paragraph, heading, code, math, quote, callout, list, numbered-list, todo, divider, image, table, embed, toggle
- **Vault system** — organize notes by workspace/project
- **Journals** — auto-created daily journal entries
- **Concept extraction** — AI pulls key concepts from notes automatically
- **Concept correlation panel** — visualize relationships between concepts
- **Inline AI chat** — per-note AI assistant
- **Zen mode** — distraction-free writing

### 3. Research Library (`/research-library`)
Paper and source management.

- Add papers with: title, authors, year, journal, DOI, URL, tags, abstract
- Semantic Scholar integration for search
- Citation search and tracking
- NeurIPS-style paper review generation
- Research idea generation and novelty checking

### 4. Analytics (`/analytics`)
Dashboard hub with **8 sub-tabs** displayed as pill-bubble sub-navigation:

| Sub-tab | Purpose | Mode |
|---------|---------|------|
| **Research Copilot** | Methodology guidance, technique scaffolding | All modes |
| **Cortex Archive** | Saved brain-state snapshots as card grid | All modes |
| **Steering Lab** | Live parameter sliders (complexity, adversarial, Bayesian, focus, temp) | **Local mode only** — grayed in API |
| **Pipeline** | Real-time 10-stage visualization with status/progress per stage | All modes |
| **Signals** | Confidence, entropy, dissonance line charts over time | All modes (view-only in API) |
| **Visualizer** | Interactive D3: parallel coords, heat maps, smoothing, trendlines | All modes |
| **Evaluate** | Truth assessment / claim validity tool | Full suite only |
| **Concepts** | Concept hierarchy tree, concept weight visualization | All modes |

### 5. Daemon (`/daemon`)
Background agent management.

- Start/stop daemon process
- Enable/disable 5 agent tasks individually
- Configure agent behavior (complexity bias, adversarial intensity, permissions)
- View event log with task results
- Permission tiers: Sandboxed → File Access → Full Access

### 6. Export (`/export`)
- **Formats:** JSON, CSV, Markdown, BibTeX, RIS
- **Data types:** All data, signals, papers, chat history, pipeline runs

### 7. Settings (`/settings`)
- Inference mode selector (Simulation / API / Local)
- API key entry and provider selection
- Ollama connection + hardware monitoring
- Suite tier (Notes / Deep Analysis / Full)
- Analytics Engine toggle
- SOAR meta-reasoning configuration
- Theme selection (8 themes)
- Data export

### 8. Onboarding (`/onboarding`)
First-run setup: boot sequence animation, device detection, tier selection, API key entry.

---

## Design System

### Glass Morphism
```css
backdrop-filter: blur(12px) saturate(1.4);
background: rgba(244, 189, 111, 0.08);
```

### Brand Color Palette
| Token | Hex | Usage |
|-------|-----|-------|
| `pfc-violet` | `#C4956A` | Primary brand accent |
| `pfc-ember` | `#E07850` | Alert, active states |
| `pfc-green` | `#34D399` | Success |
| `pfc-cyan` | `#22D3EE` | Info |
| `pfc-red` | `#F87171` | Error |
| `pfc-yellow` | `#FBBF24` | Warning |

### Animation
- **Primary easing:** `cubic-bezier(0.32, 0.72, 0, 1)` (Cupertino)
- **Spring presets:** snappy (500/35), gentle (300/25), standard (400/30)
- AnimatePresence for mount/unmount transitions

### Core UI Components
| Component | Description |
|-----------|-------------|
| **GlassBubbleButton** | Reusable pill-shaped button with glass effect |
| **PageShell** | Page wrapper with icon + title header |
| **GlassSection** | Content grouping container |
| **AppShell** | Root wrapper with localStorage hydration |
| **TopNav** | Fixed floating pill-button navbar |

---

## State Management

**Zustand** store with 12 slices, persisted to `localStorage` with `pfc-*` prefix:

| Slice | What it controls |
|-------|-----------------|
| `message` | Chat messages, submit query, streaming state |
| `pipeline` | 10-stage results, signal history, active stage |
| `inference` | API key, provider, model selection, inference mode |
| `controls` | Pipeline parameter overrides: focus depth, temperature, complexity bias |
| `cortex` | Brain state snapshots |
| `concepts` | Concept extraction, weights, adjustments |
| `tier` | Suite tier, measurement toggle |
| `research` | Papers, citations, tags |
| `portal` | Code artifact portal state |
| `ui` | UI flags (thinking visible, synthesis view) |
| `notes` | Pages, blocks, vaults, journals |
| `learning` | AI learning summaries |

---

## Streaming & Real-Time

**SSE (Server-Sent Events):**
- Endpoint: `POST /api/chat`
- Event types: `content`, `reasoning`, `pipeline_stage`, `signal_update`, `complete`
- Custom `useChatStream` hook handles streaming

---

## Dual-Message System

Every AI response generates TWO outputs:
1. **rawAnalysis** — detailed, research-grade analysis (Research view)
2. **laymanSummary** — simplified, accessible summary (Layman view)

---

## 10-Stage Pipeline

1. Triage → 2. Memory → 3. Routing → 4. Statistical → 5. Causal → 6. Meta-Analysis → 7. Bayesian → 8. Synthesis → 9. Adversarial → 10. Calibration

Stages 4-7 use structured prompt templates (`lib/engine/prompts/`) encoding formal analytical frameworks. Each stage shows status and progress in the Pipeline analytics tab.

---

## API Routes

| Route | Method | Purpose |
|-------|--------|---------|
| `/api/chat` | POST | Main pipeline — stream 10-stage analysis |
| `/api/assistant` | POST | Floating widget LLM |
| `/api/notes-ai` | POST | AI-assisted note writing |
| `/api/evaluate` | POST | Truth assessment |
| `/api/test-connection` | GET | Test LLM provider connectivity |
| `/api/ollama-check` | GET | Check Ollama availability |
| `/api/ollama-status` | GET | Get Ollama hardware stats |
| `/api/daemon` | POST | Daemon start/stop/config/proxy |
| `/api/research/*` | POST | Semantic Scholar, paper review, citations |

---

## Database

**SQLite** via Drizzle ORM (file: `pfc.db`):
- `user`, `chat`, `message` (with rawAnalysis + laymanSummary)
- `chatSignals` (confidence, entropy, dissonance, healthScore)
- `noteVault`, `notePage`, `noteBlock`, `noteBook`
- `noteConcept`, `noteConceptCorrelation`, `notePageLink`
- `daemonEventLog`, `daemonStatus`, `daemonConfig`

---

## Suite Tiers

| Tier | What's available |
|------|-----------------|
| **Notes** | Chat, Notes, basic AI — no analytics |
| **Deep Analysis** | + Steering, code tools, analytics |
| **Full** | Everything — all 8 analytics tabs, evaluate, steering lab, deep analysis |

---

## Tech Stack

- **Framework:** Next.js 16 (App Router), React 19, TypeScript
- **State:** Zustand with subscribeWithSelector
- **Styling:** Tailwind CSS 4, Radix UI, Framer Motion
- **Charts:** D3.js
- **DB:** Drizzle ORM + better-sqlite3
- **AI SDK:** Vercel AI SDK (@ai-sdk/anthropic, @ai-sdk/openai, @ai-sdk/google, @ai-sdk/openai-compatible)
- **Icons:** Lucide React
- **Markdown:** react-markdown + remark-gfm
