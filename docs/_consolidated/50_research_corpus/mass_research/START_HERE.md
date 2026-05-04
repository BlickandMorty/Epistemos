# 🚀 Start Here

This repo always runs **brainiac-2.0** (the newest version) by default.

## Quick Start

```bash
npm install
npm run dev
```

Open http://localhost:3000

## Commands

| Command | What It Does |
|---------|-------------|
| `npm run dev` | Run brainiac-2.0 (newest version) |
| `npm run build` | Build brainiac-2.0 for production |
| `npm run dev:v1` | Run pfc-app (original version) |
| `npm run build:v1` | Build pfc-app for production |

## Project Structure

- **`brainiac-2.0/`** — Current version (polished UI, 14 Zustand slices, full SOAR engine, steering system)
- **`pfc-app/`** — Original version (kept for consensus engine logic reference)

## Why Two Projects?

brainiac-2.0 is the evolved version with:
- Polished Liquid Glass UI (Material You meets macOS vibrancy)
- 4 themes (Pitch White, Sunny, Sunset, OLED)
- Complete SOAR engine (teacher-student decomposition)
- 3-layer adaptive steering (contrastive vectors, Bayesian priors, k-NN recall)
- Notes canvas with paper cards
- Mini-chat with thread isolation
- SEO metadata on all routes

pfc-app contains the original consensus engine implementation that hasn't been ported yet. It's the reference for:
- Consensus pipeline (`lib/engine/research/consensus.ts`)
- Paper search + DOI import
- Research workstation UI patterns

When building the native Swift app (Lucid), both codebases will be referenced:
- brainiac-2.0 for UI/UX, patterns, architecture
- pfc-app for consensus engine logic

---

**For more:** See [README.md](README.md) for full docs.
