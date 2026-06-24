# Owner Verification & Decisions — Ontology Refactor (2026-06-24)

Consolidates the runtime checks and pending owner decisions from the iter54–67 work block
(STRICT_RECERT_LOG_2026_06_22.md). Everything below is **build-verified green + committed**;
what remains needs either your eyes on the running app or a decision only you can make.

Latest pushed commit: `42698a725`.

---

## ✅ What's DONE (build-verified + committed + regression-guarded)

The four authoritative refactor gaps are closed, and `OntologyRefactorRegressionGuardTests`
(5 guards, all passing) now prevents silent regression:

| Gap | What landed |
|-----|-------------|
| **A** no Osaurus UI mounted | Act surface is native ChatView; Osaurus is engine-only underneath. |
| **B** one shared Act core | main act + Mini Chat + graph/note all run `ActTurnStreamCore` (0.47/0.47b). |
| **C** one recent-chat store | main act (0.48) + mini + Work (0.48b/part2) all persist to `SDChat`; Act/Work two-section popover; both reopen. |
| **D** Work MCP + vault/skills | installs persist across quit (0.49, merge-preserving config); Work's MCP roots at the app vault so it sees notes + `skills/` (0.49b). |
| 0.42 | Work-side recent-chats button → the unified popover. |
| 0.46 | Work slow-start step 1: killed per-render disk I/O + "Starting…" state. |

---

## 🔎 NEEDS YOUR EYES ON THE RUNNING APP (I cannot drive the live app)

Run the app and confirm each. If any fails, that's the next loop target.

1. **Work MCP install persistence (0.49)** — in the Work TUI, install an MCP (e.g. Playwright);
   quit the app; reopen Work → the MCP is still installed + usable. (Fix: launch now MERGE-preserves
   `opencode.json` instead of overwriting it.)
2. **Work sees vault + skills (0.49b)** — in Work, confirm the agent can list/read your vault notes
   and `skills/*/SKILL.md` via MCP (the fusion server now roots at your app vault, not home).
3. **Act send parity (0.47)** — main-act send still streams + replies normally; Mini Chat send still
   streams with live thinking + tool affordances (both moved onto the shared core; should be identical).
4. **Main-act chats appear + reopen (0.48)** — send a main-act chat → it shows in the recent-chats
   popover → reopen restores it. (This was the likely root cause of "recent chats missing / navigate
   doesn't navigate" — main act wasn't persisting at all before.)
5. **Act/Work two-section popover (0.48b)** — the recent-chats popover shows an **Act** section and a
   **Work** section.
6. **Work rows appear + reopen (0.48b-part2)** — open Work → a "Work · <dir>" row appears in the Work
   section → tap it → switches back to Work.
7. **Work recent-chats button (0.42)** — in Work mode, the top-left button opens the same unified popover.
8. **Work "Starting…" state (0.46)** — opening Work shows "Starting work terminal…" then the TUI;
   switching theme while Work is open no longer rewrites `opencode.json`.

> Note: items 1/2/6/8 require the vendored OpenCode runtime present in the build; if Work shows the
> "not wired" placeholder, the runtime isn't bundled on that build yet (honest-inert by design).

---

## 🟨 PENDING DECISIONS (only you can authorize)

- **0.46 deeper — OpenCode/Bun cold-boot prewarm.** The TUI/Bun cold start is inside the vendored
  `opencode` binary. Speeding it means either prewarming `opencode serve` on app idle (lifecycle-risky,
  needs the runtime present to measure honestly) or verified boot-skip env flags. Say the word and I'll
  ground + prototype it.
- **0.45 — Goose engine beyond OpenCode.** By design the heavy `goose` crate is NOT vendored (660MB/
  179-dep bloat); OpenCode is the work engine, with select Goose algorithms clean-room vendored and an
  inert `WorkBackend` seam as a growth point. A full Goose engine = owner-gated heavy third-party
  vendoring (ProvenanceGate). OpenClaw's hardening algos are already ported + wired (`Omega/Safety`);
  the rest of its spec is Phase-K-deferred (post-App-Store, your policy).
- **0.42 deeper — persistent Work side rail.** Today Work has the recent-chats popover (button). A
  permanently-visible side rail is a bigger layout change; I left it as the popover unless you want it
  always-on (it would shrink the terminal).
- **0.44 — palette.** Closed MOOT: the cream Osaurus theme tokens drive only *unmounted* Osaurus views;
  your visible native surfaces already follow the live theme. Nothing to do unless an Osaurus surface is
  ever re-mounted (contra the directive).

---

## How to resume the loop on any of these

The forever loop continues hardening. If you want a specific item next, just say so; otherwise it keeps
finding durable hardening (guards, edge-cases, reviews) and will fold in your runtime findings from the
checklist above as they come.
