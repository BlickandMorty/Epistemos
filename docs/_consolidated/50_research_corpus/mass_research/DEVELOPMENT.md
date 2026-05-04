# Brainiac 2.0 -- Development Guide

## Setup

```bash
npm install
npm run dev          # starts on localhost:3000 (Turbopack)
npm run build        # production build
npm run test         # 193 tests via Vitest (~1.4s)
npm run test:watch   # interactive mode
```

### Inference Modes

The app supports three inference modes, switchable at runtime from Settings:

| Mode         | What it does                                      | Requires         |
| ------------ | ------------------------------------------------- | ----------------- |
| **Simulation** | Deterministic fallback generators, no LLM calls | Nothing           |
| **API**        | Calls Anthropic / OpenAI / Google via AI SDK    | `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or `GOOGLE_GENERATIVE_AI_KEY` |
| **Local**      | Routes to a local Ollama instance               | Ollama running on `localhost:11434` |

Simulation mode is the default and works offline with zero configuration.

### Environment Variables

All optional. The app is local-first and runs without any env vars.

| Variable              | Purpose                                   |
| --------------------- | ----------------------------------------- |
| `ANTHROPIC_API_KEY`   | Anthropic API access (Claude models)      |
| `OPENAI_API_KEY`      | OpenAI API access                         |
| `GOOGLE_GENERATIVE_AI_KEY` | Google Gemini API access             |
| `PFC_API_TOKEN`       | When set, gates all API routes via edge proxy |

---

## Architecture

### Directory Tree

```
brainiac-2.0/
├── app/                          # Next.js App Router
│   ├── layout.tsx                # Server component root (ThemeProvider only)
│   ├── globals.css               # CSS vars + Tailwind
│   ├── (shell)/                  # Client shell (AppShell wraps all app routes)
│   │   ├── layout.tsx            # Client boundary -- renders AppShell
│   │   ├── (chat)/               # Chat routes + chat API
│   │   │   ├── page.tsx          # Home / new chat
│   │   │   ├── chat/[id]/        # Chat thread by ID
│   │   │   ├── chat-layout-shell.tsx
│   │   │   └── api/chat/         # Streaming chat endpoint
│   │   ├── analytics/            # Analytics hub (5 embedded views)
│   │   ├── notes/                # Notes system
│   │   ├── settings/             # Settings (4 sections)
│   │   ├── concept-atlas/        # Concept atlas page
│   │   ├── daemon/               # Daemon control panel
│   │   ├── docs/                 # Docs viewer
│   │   ├── export/               # Export tools
│   │   ├── library/              # Research library
│   │   └── research-copilot/     # Research copilot
│   ├── onboarding/               # Standalone -- no shell wrapper
│   ├── api/                      # API routes (outside shell)
│   │   ├── system/[action]/      # Ollama check, daemon, test-connection
│   │   ├── notes/[action]/       # Notes AI, learn, sync
│   │   └── assistant/            # Assistant endpoint
│   └── proxy.ts             # -> root proxy.ts (see below)
├── proxy.ts                 # Edge auth -- PFC_API_TOKEN gate
├── components/
│   ├── layout/                   # AppShell, PageShell, TopNav, PageTransition, ErrorBoundary
│   ├── chat/                     # Chat UI (20 components)
│   ├── assistant/                # Mini-chat shell + 4 tabs (chat, history, notes, research)
│   ├── notes/                    # Notes sidebar, graph view, AI chat, vault picker
│   │   └── block-editor/         # Block-based editor (nested)
│   ├── viz/                      # Concept hierarchy, concept mini-map, portal sidebar, thought visualizer
│   ├── decorative/               # Star field, wallpapers, pixel mascots
│   ├── shared/                   # Markdown renderer, Toast, EducationalTooltip
│   ├── analytics/                # 5 analytics views (diagnostics, visualizer, pipeline, steering-lab, cortex-archive)
│   ├── ui/                       # Radix/shadcn primitives
│   └── theme-provider.tsx        # next-themes wrapper
├── lib/
│   ├── engine/                   # Pipeline + AI core
│   │   ├── simulate.ts           # 10-stage pipeline orchestrator
│   │   ├── query-analysis.ts     # Query analysis functions
│   │   ├── signal-generation.ts  # Signal computation
│   │   ├── fallback-generators.ts# Simulation-mode generators (no LLM)
│   │   ├── synthesizer.ts        # Response synthesis
│   │   ├── reflection.ts         # Reflection pass
│   │   ├── arbitration.ts        # Multi-engine arbitration
│   │   ├── truthbot.ts           # Factual verification
│   │   ├── llm/                  # LLM provider resolution, prompts, schemas
│   │   │   ├── provider.ts       # Model selection + provider factory
│   │   │   ├── generate.ts       # Streaming generation wrapper
│   │   │   ├── config.ts         # Model configs
│   │   │   ├── prompts.ts        # System prompts
│   │   │   ├── assistant-prompt.ts
│   │   │   ├── schemas.ts        # Zod schemas for structured output
│   │   │   └── ollama.ts         # Ollama client
│   │   ├── steering/             # 3-layer steering engine
│   │   │   ├── engine.ts         # Main steering orchestrator
│   │   │   ├── encoder.ts        # Steering vector encoder
│   │   │   ├── feedback.ts       # User feedback processing
│   │   │   ├── memory.ts         # Steering memory
│   │   │   ├── prompt-composer.ts# Prompt composition with steering
│   │   │   └── types.ts
│   │   ├── soar/                 # Self-Optimizing Adaptive Reasoning
│   │   │   ├── engine.ts         # SOAR orchestrator
│   │   │   ├── student.ts        # Student model
│   │   │   ├── teacher.ts        # Teacher model
│   │   │   ├── contradiction.ts  # Contradiction detection
│   │   │   ├── detector.ts       # Pattern detection
│   │   │   ├── reward.ts         # Reward computation
│   │   │   └── types.ts
│   │   └── research/             # Research library data + types
│   ├── db/
│   │   ├── schema.ts             # Drizzle schema (SINGLE source of truth)
│   │   ├── queries.ts            # Chat/message queries (branded types)
│   │   ├── notes-queries.ts      # Notes queries (branded types, transactions)
│   │   ├── index.ts              # SQLite singleton + migration runner
│   │   └── migrations/           # Drizzle migration SQL files
│   ├── store/                    # Zustand state (13 slices)
│   │   ├── use-pfc-store.ts      # Combined store + event bus subscribers
│   │   ├── use-steering-store.ts # Separate steering store
│   │   ├── events.ts             # Typed event bus for cross-slice communication
│   │   ├── hydrate.ts            # Centralized hydration
│   │   └── slices/               # 13 slices: concepts, controls, cortex, inference,
│   │                             #   learning, message, notes, pipeline, portal,
│   │                             #   research, soar, toast, ui
│   ├── motion/
│   │   └── motion-config.ts      # ALL motion presets (springs, easings, CSS keyframes)
│   ├── branded.ts                # Branded types: UserId, ChatId, MessageId, etc.
│   ├── rate-limit.ts             # Sliding-window rate limiter
│   ├── api-proxy.ts         # withRateLimit() wrapper for route handlers
│   ├── api-utils.ts              # Shared API utilities (parseBodyWithLimit, etc.)
│   ├── daemon-ipc.ts             # Typed IPC for daemon communication
│   └── utils.ts                  # General utilities
├── hooks/                        # 6 React hooks
│   ├── use-chat-stream.ts        # Streaming chat with mutex
│   ├── use-assistant-stream.ts   # Assistant streaming with generation counter
│   ├── use-is-dark.ts            # Dark mode detection (hydration-safe)
│   ├── use-scroll-to-bottom.ts   # Auto-scroll for streaming
│   ├── use-setup-guard.ts        # Onboarding redirect guard
│   └── use-typewriter.ts         # Typewriter text effect
├── daemon/                       # Background daemon (separate process)
├── tests/                        # 12 test files, 193 tests
├── vitest.config.ts
├── drizzle.config.ts
└── proxy.ts                 # Edge auth middleware
```

### Key Architectural Decisions

1. **Root layout is a server component.** `app/layout.tsx` renders only `ThemeProvider`. All client-side shell logic (AppShell, navigation, store hydration) lives in `app/(shell)/layout.tsx`, which is a client component. This keeps the root layout server-renderable and avoids hydration mismatches.

2. **Branded types at the DB boundary.** All ID parameters in `lib/db/queries.ts` and `lib/db/notes-queries.ts` use branded types (`UserId`, `ChatId`, `MessageId`, etc.) defined in `lib/branded.ts`. Raw strings are cast to branded types at the API layer; DB functions require branded types in their signatures.

3. **Motion constants are centralized.** Every spring config, easing curve, and CSS keyframe lives in `lib/motion/motion-config.ts`. Components import from there. Never declare local spring/easing values.

4. **Event bus for cross-slice communication.** Slices must never mutate state owned by another slice. Instead, use the typed event bus in `lib/store/events.ts`. Events are emitted via `emit()` and subscribed via `onStoreEvent()` in `use-pfc-store.ts`. Defined events: `query:submitted`, `query:completed`, `chat:cleared`, `learning:page-created`, `learning:block-created`.

5. **Two-layer auth.** Edge proxy (`proxy.ts`) handles token authentication when `PFC_API_TOKEN` is set. Per-route rate limiting is handled by `withRateLimit()` in `lib/api-proxy.ts`, applied inside each route handler.

6. **Drizzle schema is the single source of truth.** All table definitions live in `lib/db/schema.ts`. To change the schema, edit that file and run `npx drizzle-kit generate` to produce a migration. Never write raw DDL.

7. **Transactions via `withTransaction()`.** Multi-row writes use the `withTransaction()` helper from `lib/db/index.ts`, which wraps better-sqlite3's `.transaction()`.

---

## Conventions

### Styling

- Tailwind CSS 4 with CSS custom properties defined in `app/globals.css`.
- No new inline style objects. Use Tailwind classes or CSS vars.
- Dark mode via `next-themes` + Tailwind `dark:` variant.

### Motion / Animation

- Import springs, easings, and keyframes from `@/lib/motion/motion-config.ts`.
- Never declare local `spring()` or easing constants in components.
- Use Framer Motion for layout animations, CSS for micro-interactions.

### Components

- Organized by feature: `components/chat/`, `components/notes/`, `components/viz/`, etc.
- Each feature directory has an `index.ts` barrel export.
- Target: no file over 500 lines. Allowed exceptions: canvas and visualization components (up to 800 lines).

### State Management

- Zustand with 13 slices composed in `lib/store/use-pfc-store.ts`.
- Direct mutations are allowed only within the owning slice.
- Cross-slice effects go through the event bus (`lib/store/events.ts`).
- Never use ES `get` property accessors in slice objects -- they evaluate during store init before all slices are composed.
- Watch for slice name collisions: in a flat store with spread slices, last-spread wins silently. Prefix slice-specific actions if needed.

### Types

- Use branded types (`UserId`, `ChatId`, `MessageId`) for all ID parameters in DB query functions.
- String unions (`EvidenceGrade`, `InferenceMode`) instead of plain `string` where applicable.
- `assertUnreachable()` for exhaustive switch/case matching.

### Hooks

- All React hooks must be called before any early return. Move hooks above `if (!mounted) return null` guards.
- Use generation counters (monotonic ref) to prevent race conditions in async cleanup.

### Testing

- Vitest 4 + happy-dom + @testing-library/react.
- 193 tests across 12 files, runtime ~1.4s.
- Test files live in `tests/` with a shared `tests/setup.ts`.
- Run `npm test` before committing.

---

## Common Tasks

### Adding a new component

1. Create the file in the appropriate feature directory under `components/`.
2. Export it from the directory's `index.ts` barrel file.
3. If it needs motion, import presets from `@/lib/motion/motion-config.ts`.

### Adding a new page

1. Create a directory under `app/(shell)/` (or `app/` if it should be standalone without AppShell).
2. Add `page.tsx` (and optionally `layout.tsx` with exported `Metadata` for SEO).
3. If it needs the page shell wrapper, use `<PageShell>` from `@/components/layout`.

### Adding a new store event

1. Define the event type and payload in `lib/store/events.ts`.
2. Emit with `emit('event:name', payload)` from the relevant slice action.
3. Subscribe in `use-pfc-store.ts` inside the event bus setup block.

### Changing the DB schema

1. Edit `lib/db/schema.ts` (this is the single source of truth).
2. Run `npx drizzle-kit generate` to produce a migration file in `lib/db/migrations/`.
3. The migration runs automatically on next app start via the singleton in `lib/db/index.ts`.
4. Commit both the schema change and the generated migration.

### Adding an API route

- System-related (Ollama, daemon, connectivity): add a case in `app/api/system/[action]/route.ts`.
- Notes-related (AI, learning, sync): add a case in `app/api/notes/[action]/route.ts`.
- Other: create a new route directory under `app/api/`.
- Wrap the handler with `withRateLimit()` from `lib/api-proxy.ts`.
- Use `parseBodyWithLimit()` from `lib/api-utils.ts` for POST body parsing.

### Running the daemon

```bash
npm run daemon:dev     # watch mode
npm run daemon:start   # production
npm run daemon:status  # check status
npm run daemon:stop    # stop
```
