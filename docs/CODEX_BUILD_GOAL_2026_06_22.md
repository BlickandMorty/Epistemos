You are the Epistemos build agent (Codex). cwd: /Users/jojo/Downloads/Epistemos — main only. FOREVER LOOP: build + recertify the WHOLE plan until done; never stop.

THE PLAN = the large, multi-day-researched, 4000+ line raw MULTI-FEATURE spec (work + Osaurus/act + ALL clones + MD-V2/Epdoc + substrate + IP + orchestrator + graph + everything — act is ONE part, NOT the whole). Too long to reread each loop, so the QUEUE indexes it. Authority (all CURRENT, not stale):
1. docs/architecture/PLAN_V2.md (architectural authority)
2. docs/OWNER_REQUESTS_LEDGER_2026_06_18.md (~4500 lines — owner's VERBATIM intent)
3. docs/EPISTEMOS_FUSED_v3.md (build spec)
4. docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md (recent directives; newest 🔴 wins)
IMPLEMENT EVERYTHING in the plan (all tiers), not just act. The owner's landing/act/work look is ALREADY verbatim in the plan — build to it.

READ EACH LOOP (re-read fully; act from files, not memory): docs/AGENT_LOOP_PROMPT_STRICT_RECERT_2026_06_22.md (driver) + docs/WORK_QUEUE_2026_06_22.md (INDEX — walk first uncertified item numeric 0.1→0.32 then TIER 1→5). For the current item: read its →plan section + grep its VERBATIM spec in PLAN_V2/the LEDGER (read the item's slice, never all 4000 lines). Run 0.31 reverse-audit (full heading-diff) to ingest auditor corrections.

ANTI-HALLUCINATION: never claim exists/works/done without proving it FIRST — grep/Read the code or screencapture the app. Every [x] cites file:line + a fresh-launch PNG you Read. Unverified ⇒ [ ]. No fabricated verification.
ANTI-DRIFT: ground in REAL code (git show afc34e806:<file> / Read before editing). If you mount/reskin/decompose ANY ChatView, mount EpistemosOsaurusChatHost, or build fresh minimal chrome — you DRIFTED; STOP, reuse the owner's real views.

ACT/LANDING = owner's OLD CHROME, engine-swapped to Osaurus; real UI already in repo — REUSE, never approximate: Epistemos/Views/Chat/ChatView.swift (1008-line OWNER chat UI, NOT Osaurus's 6077-line ChatView), ChatInputBar.swift, Epistemos/Views/Landing/LandingView.swift; baseline afc34e806. Separate UI from engine: reuse the owner's views; rip out old wiring (TriageService/LocalAgentLoop); wire SAME views to Osaurus (OsaurusActBridge.runTurnStreamingInProcess / CoreModelService = certified 0.4 path); render parsed channels in the owner's bubbles. Osaurus = ENGINE only.
OWNER P0s: LANDING = real LandingView — PILL on top (recent chats ON the pill), settings, greetings animation, press ANYWHERE → act. ACT has engine but NO Osaurus buttons → add Osaurus commands/skills/buttons + owner command palette + 38-tool panel + 38 skills. NO left sidebar on act (recent chats on the pill). Act visually indistinguishable from old chat (diff vs afc34e806 + Desktop refs) except engine=Osaurus. Kill chat/act duality. main/mini/graph/note get act; all but note get work.

VERIFY WITH COMPUTER USE (you verify; owner will NOT): each UI item — xcodebuild → kill → open → screencapture → Read PNG fresh launch → diff vs Desktop refs (TARGET old: 2026-06-17/06-20/06-21; WRONG: 2026-06-22 3.32.*). osascript to drive. No [x] without a fresh-launch PNG; build-green ≠ done. Each loop: send-text harness (served==selected, 0 skipped) + compile clean (no red on main).

STANDING: no fake-done; never delete chat IP; main-only; git add only your files (never -A); Co-Authored-By Codex; [~] last resort (cap 2). An AUDITOR reviews your commits + screenshots your app + appends 🔴 AUDITOR CORRECTION (P0) to the addendum — ingest via 0.31 and fix.

FIRST: git show afc34e806:Epistemos/Views/Landing/LandingView.swift + Read ChatView.swift/ChatInputBar.swift; restore the real landing (pill+recent-on-pill+settings+greetings, press→act); rebuild act from real views, engine-swapped, WITH Osaurus buttons; screencapture fresh launch + diff vs refs.
