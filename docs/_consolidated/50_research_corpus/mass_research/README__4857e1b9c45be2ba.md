# PFC — Meta-Analytical Reasoning Engine

A research-grade reasoning pipeline that processes queries through 10 cognitive stages inspired by prefrontal cortex function. Features structured prompt templates encoding statistical and Bayesian frameworks, adversarial red-teaming, multi-engine arbitration, and real-time signal monitoring.

PFC doesn't just answer questions — it shows you *how* it thinks, where it's uncertain, and what might be wrong with its own analysis.

## Features

- **10-Stage Pipeline** — Triage, Memory Retrieval, Routing, Statistical Analysis, Causal Reasoning, Meta-Analysis, Bayesian Updating, Synthesis, Adversarial Testing, Calibration
- **Dual-Layer Output** — Raw analytical text with `[DATA]`/`[MODEL]`/`[UNCERTAIN]`/`[CONFLICT]` tags + accessible layman summary
- **Real-Time Signal Dashboard** — Confidence, entropy, dissonance, Bayesian prior strength, and 12 other live signals
- **Truth Assessment** — Independent evaluation of response reliability with signal interpretation
- **Self-Reflection** — Identifies its own weakest claims and generates critical questions
- **Multi-Engine Arbitration** — Simulates disagreement between analytical engines and resolves conflicts
- **Adaptive Steering** — 3-layer hybrid feedback loop (contrastive + Bayesian + k-NN) that learns from your corrections over time
- **3 Inference Modes** — Simulation (built-in templates), API (OpenAI/Anthropic), Local (Ollama)
- **Concept Atlas** — Force-directed graph of extracted concepts across conversations
- **Cortex Archive** — Save and restore full brain state snapshots
- **Interactive Visualizer** — Drag-to-edit signal radar with real-time override controls

## Quick Start

```bash
git clone https://github.com/BlickandMorty/meta-analytical-pfc.git
cd meta-analytical-pfc/pfc-app
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

That's it. No API keys needed — PFC runs in **Simulation mode** by default with zero external dependencies.

### Automated Setup (includes Local Mode)

If you want Local Mode with Ollama ready to go, use the setup scripts. They install dependencies, install Ollama if needed, pull a model, and start the app — all in one command.

**macOS / Linux:**
```bash
git clone https://github.com/BlickandMorty/meta-analytical-pfc.git
cd meta-analytical-pfc/pfc-app
chmod +x setup.sh
./setup.sh
```

**Windows (PowerShell):**
```powershell
git clone https://github.com/BlickandMorty/meta-analytical-pfc.git
cd meta-analytical-pfc\pfc-app
powershell -ExecutionPolicy Bypass -File setup.ps1
```

**Windows (Command Prompt):**
```cmd
git clone https://github.com/BlickandMorty/meta-analytical-pfc.git
cd meta-analytical-pfc\pfc-app
setup.bat
```

The scripts will walk you through model selection and skip anything already installed.

## Inference Modes

### Simulation (Default)

Uses built-in template-based generation. No API keys, no GPU, no external services. Great for exploring the pipeline, understanding the architecture, and UI development.

**Requirements:** Any machine that can run Node.js.

### API Mode (Cloud LLM)

Sends queries to OpenAI (GPT-4o, GPT-4o-mini) or Anthropic (Claude Sonnet, Claude Opus) for real AI-powered analysis.

**Setup:**
1. Go to **Settings** > select **API Mode**
2. Choose your provider (OpenAI or Anthropic)
3. Enter your API key
4. Click **Test Connection** to verify
5. Start chatting

**Requirements:** An API key from [OpenAI](https://platform.openai.com/api-keys) or [Anthropic](https://console.anthropic.com/).

Your API key is stored **only in your browser's local storage**. It's sent per-request to the local Next.js server route, used to call the provider, and discarded. Never stored server-side or in any database.

### Local Mode (Ollama)

Runs a local LLM on your machine via [Ollama](https://ollama.ai). Full privacy — nothing leaves your device.

**Setup:**
1. Install Ollama: `curl -fsSL https://ollama.ai/install.sh | sh` (or download from [ollama.ai](https://ollama.ai))
2. Pull a model: `ollama pull llama3.1` (or `qwen2.5`, `mistral`, `phi3`, etc.)
3. Ollama runs automatically at `http://localhost:11434`
4. In PFC, go to **Settings** > select **Local Mode**
5. PFC auto-detects your Ollama instance and available models

## Hardware Requirements

### Simulation & API Mode

Minimal. If your machine runs a web browser and Node.js, you're good.

| Component | Minimum |
|-----------|---------|
| RAM | 4 GB |
| CPU | Any modern processor |
| Storage | ~500 MB (with node_modules) |
| GPU | Not needed |

### Local Mode (Ollama) — Read This Carefully

Running a local LLM is **compute-intensive**. The model runs on your hardware, which means your CPU/GPU will work hard and your machine will get warm and loud under load. This is normal.

#### Minimum Specs for Local Mode

| Component | 7B-8B Models (Recommended) | 13B Models | 70B+ Models |
|-----------|---------------------------|------------|-------------|
| RAM | 16 GB | 32 GB | 64+ GB |
| GPU VRAM | 6 GB (4-bit quantized) | 12 GB | 48+ GB |
| CPU | 4+ cores, modern (Intel 11th gen+ / AMD Zen 3+) | 8+ cores | 16+ cores |
| Storage | 5-10 GB per model | 10-15 GB | 40+ GB |

#### Recommended Models for Local Mode

| Model | Size | Good For | Min RAM |
|-------|------|----------|---------|
| `llama3.1:8b` | ~4.7 GB | General reasoning, best overall | 16 GB |
| `qwen2.5:7b` | ~4.4 GB | Multilingual, strong reasoning | 16 GB |
| `mistral:7b` | ~4.1 GB | Fast, good quality | 16 GB |
| `phi3:mini` | ~2.3 GB | Lightweight, fast on limited hardware | 8 GB |
| `llama3.1:70b` | ~40 GB | Research-grade quality | 64 GB |

#### Platform-Specific Notes

**Windows / Linux (with dedicated GPU):**
Best experience for Local mode. NVIDIA GPUs with 8+ GB VRAM (RTX 3060 and up) give excellent performance — 30-50+ tokens/second on 7B-8B models. AMD GPUs work via ROCm on Linux. This is the recommended setup for serious local inference work.

**macOS (Apple Silicon — M1/M2/M3/M4):**
Apple Silicon uses **unified memory**, meaning your entire RAM is available as VRAM. A MacBook with 16 GB runs 7B-8B models well. However:
- Your fans **will** spin up during inference — this is normal
- Battery drain increases significantly during active inference
- Performance scales with memory bandwidth: M1 Pro/Max/Ultra and M3 Pro/Max chips will noticeably outperform base M1/M2
- 8 GB Macs can run small models (3B-7B) but expect slower speeds and shorter context windows

**macOS (Intel):**
Not recommended for Local mode. Intel Macs lack the unified memory architecture and Metal GPU acceleration that makes Apple Silicon viable. Use API mode instead.

**Low-spec machines / Older laptops:**
Use **Simulation mode** or **API mode**. Local inference on machines with <16 GB RAM or no dedicated GPU will be extremely slow or may crash. This isn't a PFC limitation — it's a physics-of-running-billions-of-parameters limitation.

#### Tips for Local Mode Performance

- **Close other apps** — LLMs want all available RAM. Chrome alone can eat 4-8 GB.
- **Use quantized models** — Ollama defaults to Q4_K_M quantization which is the sweet spot of quality vs performance.
- **Start small** — Try `phi3:mini` first to test your setup, then move to `llama3.1:8b`.
- **Monitor temps** — If your laptop thermal throttles, responses will slow down. Consider a cooling pad for sustained use.
- **Plugged in** — Always run on AC power for local inference. Battery mode throttles CPU/GPU.
- **If it's too slow** — Switch to API mode. A $5 OpenAI credit goes a long way.

## Architecture

```
User Query
    │
    ▼
┌─────────────────────────────────────────────┐
│              10-Stage Pipeline               │
│                                              │
│  Triage → Memory → Routing → Statistical     │
│  → Causal → Meta-Analysis → Bayesian        │
│  → Synthesis → Adversarial → Calibration    │
│                                              │
│  Each stage generates:                       │
│    • Status text + signals                   │
│    • Confidence, entropy, dissonance, etc.   │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│           Text Generation (5 functions)      │
│                                              │
│  Mode: Simulation │ API (Cloud) │ Local      │
│                                              │
│  1. Raw Analysis (tagged analytical text)    │
│  2. Layman Summary (5-section accessible)    │
│  3. Self-Reflection (critique + questions)   │
│  4. Arbitration (multi-engine voting)        │
│  5. Truth Assessment (reliability eval)      │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│              Steering Engine                  │
│                                              │
│  Records corrections → builds exemplar DB    │
│  → computes activation bias → adjusts        │
│    future signal generation                  │
└─────────────────────────────────────────────┘
```

## Tech Stack

- **Framework:** Next.js 16 (App Router)
- **UI:** React 19, Tailwind CSS 4, Radix UI, Framer Motion
- **Database:** SQLite via better-sqlite3 + Drizzle ORM (local file, zero config)
- **State:** Zustand
- **AI SDK:** Vercel AI SDK (multi-provider: OpenAI, Anthropic, Ollama)
- **Validation:** Zod (structured LLM output)

## Project Structure

```
pfc-app/
├── app/                    # Pages (chat, settings, visualizer, diagnostics, etc.)
├── components/             # React components (sidebar, messages, controls, etc.)
├── hooks/                  # Custom hooks (chat stream, theme, etc.)
├── lib/
│   ├── engine/             # Core reasoning pipeline
│   │   ├── llm/            # LLM integration (providers, prompts, schemas)
│   │   ├── steering/       # Activation steering engine
│   │   ├── simulate.ts     # 10-stage pipeline + signal generation
│   │   └── types.ts        # TypeScript interfaces
│   ├── db/                 # SQLite schema + queries (Drizzle ORM)
│   ├── store/              # Zustand state management
│   └── constants.ts        # Pipeline stage definitions
└── public/                 # Static assets
```

## Data & Privacy

- **All data stays local.** Chat history is stored in a SQLite file (`pfc.db`) on your machine.
- **No telemetry.** PFC sends nothing to any server except your chosen LLM provider (when using API mode).
- **API keys never leave your browser** except in the per-request POST to your own local Next.js server.
- **No accounts.** No sign-up, no login, no tracking.

## Troubleshooting

**"Ollama not detected" in Local mode:**
- Make sure Ollama is running: `ollama serve`
- Check the URL in Settings (default: `http://localhost:11434`)
- Try `curl http://localhost:11434/api/tags` in your terminal

**Pipeline completes but text looks templated:**
- You're in Simulation mode. Switch to API or Local mode in Settings for real LLM output.

**API mode returns errors:**
- Verify your API key with the "Test Connection" button in Settings
- Check that you have credits/quota with your provider

**Local mode is very slow:**
- Your model may be too large for your hardware. Try a smaller model.
- Close other applications to free RAM.
- Check if your machine is thermal throttling.

## License

MIT License — see [LICENSE](./LICENSE) for details.
