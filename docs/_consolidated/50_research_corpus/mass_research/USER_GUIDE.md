# Meta-Analytical PFC — User Guide

Practical guide for running and using the app.

## Quick Start

```bash
cd pfc-app
npm install
npm run dev
```

Open `http://localhost:3000` in your browser.

## First Run

On first launch, you'll see the onboarding flow:
1. Boot sequence animation
2. Device capability detection
3. Suite tier selection (Notes / Deep Analysis / Full AI & Measurement)
4. API key entry (optional — skip for Simulation mode)

## Inference Modes

Configure in **Settings → Inference Mode**:

| Mode | What It Does | Needs |
|------|-------------|-------|
| **Simulation** | Template-generated responses for offline demo | Nothing |
| **API** | Cloud LLM calls with structured analytical prompts | API key (Anthropic, OpenAI, or Google) |
| **Local** | Ollama-compatible models with full steering control | Ollama running locally |

### Setting Up Ollama (Local Mode)

1. Install Ollama: https://ollama.ai
2. Pull a model: `ollama pull qwen2.5:14b`
3. In Settings → Local Mode, enter `http://localhost:11434`
4. Click "Test Connection"
5. Select your model from the dropdown

## Core Features

### Chat (`/`)
- Type research questions in the input bar
- Toggle between **Research view** (detailed) and **Layman view** (simplified) per message
- Expand the reasoning accordion to see the AI's thinking process
- View confidence and evidence grades per response

### Notes (`/notes`)
- Create pages organized in vaults
- Block-based editing: paragraphs, headings, code, math, quotes, callouts, lists, todos
- Use `[[page name]]` for bi-directional links
- AI-assisted writing: select blocks → ask AI to continue, summarize, expand, or rewrite
- Daily journal entries auto-created

### Research Library (`/research-library`)
- Add papers with title, authors, DOI, tags, abstract
- Search by keyword or tag
- Inline notes on each paper

### Analytics (`/analytics`)
- **Pipeline** tab shows real-time 10-stage progress
- **Signals** tab charts confidence, entropy, dissonance over time
- **Steering Lab** lets you adjust complexity bias, adversarial intensity, Bayesian prior strength, focus depth, temperature

## Background Agents (Daemon)

Go to `/daemon` to manage background agents:

1. Click **Start** to launch the daemon
2. Enable/disable individual tasks
3. Configure agent behavior (complexity bias, adversarial intensity, permissions)
4. View event log for task results

The 5 agent tasks:
- **Connection Finder** — finds links between notes you didn't know existed
- **Daily Brief** — morning summary of what changed
- **Auto-Organizer** — tags and clusters unorganized notes
- **Research Assistant** — identifies research questions implicit in your notes
- **Learning Protocol** — multi-step deep learning from your knowledge base

## Export

Go to `/export` to download your data:
- **Formats:** JSON, CSV, Markdown, BibTeX, RIS
- **Data types:** All data, signals, papers, chat history, pipeline runs

## Keyboard Shortcuts

- `Cmd+\` — toggle notes sidebar
- Standard text editing shortcuts in the block editor

## Settings Reference

| Setting | Location | What It Does |
|---------|----------|-------------|
| Inference Mode | Settings → top | Simulation / API / Local |
| Suite Tier | Settings → Suite Tier | Feature gating (Notes / Deep Analysis / Full) |
| Analytics Engine | Settings → Analytics Engine | Enable/disable signal computation and SOAR |
| SOAR | Settings → SOAR | Toggle meta-reasoning and configure iterations |
| Theme | Settings → Appearance | 8 theme options (light, dark, OLED, cosmic, etc.) |
| Export | Settings → Export Data | Download data in various formats |
