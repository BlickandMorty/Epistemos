# Home-Window Embedding + Fixes — Master Plan (owner 2026-07-01)

> Single sole-worker program folding in EVERY task / query / concern the owner raised. Work it until ALL done,
> build-verify + commit each step, keep the tree green. Surface only genuine design forks.

## North star (owner)
The app should feel **deeply integrated — visually + fluid**. Feature surfaces are **PAGES that animate into the
HOME window** (like the old chat), not separate windows. They must be **ready/instant** (pre-warmed, not cold-loaded
on navigation). Minimalist where possible; cut broken/messy excess.

## A. Home-window surface embedding
- [x] Meeting → embedded home page (blur-fade, back-to-Home chip)              — commit c2e78edc8
- [x] arXiv, Browser, Browser-Use → embedded home pages                        — commit f9eb96c5b
- [x] Goose → embedded home page (AgentSurfaceRootView/GooseWebSurfaceView)    — building; basic version
- [ ] **Goose PRE-WARM + KEEP-ALIVE (owner: "loads fully at app start, ready, no hang").** GooseWebSurfaceView spins
      its OWN GooseRuntimeSupervisor per mount → cold hang on nav. Fix: mount the Goose surface ONCE (persistent in the
      home ZStack, hidden when inactive) so the runtime stays warm; pre-warm it in the background at app start via
      AppBootstrap prewarm so it's connected before first navigation. Same robustness applied to any other surface
      that cold-loads/hangs.
- [ ] Deep-integration polish: consistent transition/fluidity across all pages; back affordance; no flashes.
- KEEP OUT of home pages (owner): Notes / HTML-Workspace / editor stay in the utility note-workspace window.

## B. Bugs / broken features
- [ ] **Prose editor crash** — not reproducible statically (range/observer suspects all guarded). Needs the
      crash-recorder file `<vault>/.epcache/diagnostics/` or repro steps. Add defensive prose hardening meanwhile.
- [ ] **Goose hang on navigation** → the pre-warm/keep-alive above.
- [ ] Any other surface hang/load issue → robust/lazy pre-warm.
- [x] Editor #7 dark/light theme-flip keystroke-loss (in-place setTheme)        — commit 7f161c3f0

## C. Landing cleanup
- [ ] Simplify the landing page — cleaner, fewer feature tiles that route into the embedded pages.

## D. Reduce messiness / HTML Workspace
- [ ] **Simplify HTML Workspace back toward its older, simpler form** (owner: "not working like it used to; we
      complexified it too much"). Cut the excess/regression back to near the original, BUT keep some integrated parts
      still accessible. Identify what broke vs. the older behavior; propose specific cuts before ripping features.
- [ ] **Fix "too connected" visuals** (owner): parts have NO borders/separation between certain buttons / words /
      tools (e.g. the context parts) — they blend together. Add clear borders/spacing/dividers so elements read as
      distinct. Applies to the workspace toolbar/context UI (and audit other surfaces for the same blend).
- [ ] Other over-built surfaces.

## G. Goose instant-feel (owner, high priority)
- [x] Pre-warm + keep-alive so nav is instant, not a cold-load hang           — commit 01d5a84ec
- [ ] If still laggy after owner test: shared app-lifetime Goose host, re-parented on nav (cannot reload).

## E. Already-landed fixes (this program)
- [x] Model-selection honors the user's chosen model (agent_core slug)          — 7f161c3f0
- [x] MAS self-containment: subprocess/openURL seams gated `#if EPISTEMOS_APP_STORE` (App Review 2.5.2) — 7f161c3f0
- [x] Editor #14 custom palette → closest CodeMirror theme                       — 7f161c3f0
- [x] LiteParse encrypted/password PDF refusal + multi-column + 5 tests          — 7f161c3f0
- [x] MAS empty sources/schedules/skills → live enumeration / honest bounded     — (earlier, verified)
- Verified NOT gaps: browser-use live submit already real; AVSpeech dead-code is test-guarded (left);
  RawThoughts refs are load-bearing plumbing (not deletable residual).
- Correctly deferred (need app / data-integrity): #5 off-MainActor, #6 per-section drop, content-hash collision.

## F. External / owner-only (not code)
- Kokoro model install (~0.5–1 GB); browser-use Dev-ID notarization; MAS go-live flag + sandboxed build; Paseo (deferred).

## Working rule
Sequential in the main tree (sole worker), build-verify + commit each step, keep green. Update this doc's checkboxes as
items land.
