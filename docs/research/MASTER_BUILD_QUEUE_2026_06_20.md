# MASTER BUILD QUEUE — the ENTIRE plan, in order (2026-06-20)

Owner: *"the queue can literally just BE the entire plan and go in order… make sure ALL things in the plan are in
the queue in a proper order, and that the research we did is ALSO deliberated on by the agent BEFORE it builds, with
all the nuclear/skills passes and repair passes. Plan↔queue connection so I can sleep and it works on all the things
in order."* This doc is that connection: it places **every one of the 194 open `[ ]` ledger items** into a single
ordered walk. The loop walks Tier 0 → Tier 5 top-to-bottom; the STANDING passes interleave; the OWNER-DOMAIN track is
parallel (owner's Cursor work, tracked not loop-built). Per-item detail lives in `OWNER_REQUESTS_LEDGER_2026_06_18.md`
(cited by line) + its SS-* slice — this is the ORDER + the operating contract, not a re-copy.

## OPERATING CONTRACT (applies to EVERY item in the walk)
1. **DELIBERATE-FIRST (research before build):** before coding an item, the loop reads its SS-* slice + the canonical
   source it names (CLAUDE.md RESEARCH-FIRST + `RESEARCH_FINALIZATION_INDEX` + `docs/fusion/*`), then verifies current
   code/logs. No building an item whose research hasn't been re-read that iteration.
2. **NO-RISK-DEFERRAL:** fragile surface → safe additive seam + regression guard + commit a clean savepoint, then code.
   A deferred safe-increment is captured to SS-FOLLOWON, never dropped.
3. **SELF-VERIFY + SHIP (owner-verification is NOT a gate):** render/behavior tests + cargo/swift + xcodebuild
   launch-smoke; honest tier (no fake-T4); "visual/live PENDING OWNER" is a non-blocking note. Commit each green.
4. **INTERLEAVED PASSES (the "nuclear + repair" cadence):** every ~5 items / end-of-cycle run SS-CLEAN (dead-flag/orphan,
   duplicate, stale, green-without-witness, CAPABILITY-SURFACE-PARITY, LAUNCH-SMOKE) + Owner-Request Coverage Sweep +
   NUANCE-COMPLETENESS + FOLLOW-ON-CAPTURE + the nuclear AGGRESSIVE CODE-CHECKER (ledger 3478) + a DEEP-REPAIR pass
   (SS-REPAIR: find→fix→verify + one perf + one usability win). P0 owner reports preempt everything.
5. **100% COMPLETION:** the walk does not end until every Tier 0–5 item is built + verified-or-honestly-tiered. The
   coverage sweep re-walks all open `[ ]` so nothing falls off. Order only sets *what's next*, never *what's dropped*.

---

## TIER 0 — LIVE P0 / blockers (do first; most already DONE — verify, don't assume)
Chat "credentials rejected" 4010/4310/4335 (fix landed 191c9291a, live-send pending-owner) · P0 launch crash 4262
(e9eb76b5c) · dark/light toggle crash 3488 · recent-crash log study 3512 · model-selection-not-honored 2897 ·
model-download-broken 2594 · default-Qwen-4B 1134/2258 · Qwen3-8B visible 1123 · memory-bypass-12B 1144.

## TIER 1 — SUBSTRATE completion (model-agnostic; authority SUBSTRATE_BUILD_SEQUENCE)
STAGE-2 RuntimeRouter LIVE flip 4417 (parity-gated) · SS-SH blank sidebar 3919/3734 (closed b3277d568 — verify) ·
P5 EML rerank + W-51 recall · P2 load-on-launch · P5.H deep-harden + FINISH substrate 1496/2459/2487/1834/2477/2469 ·
substrate-without-new-model 4214/4243/4200 · FIRST-DOMINO research/* note 2464 · instant-recall UMA zero-copy
3704/3753 · OBS Eidos→chat wiring 2196/2199 · MINE SYSTEM G → app 1838/2490 · provenance moat 3171 · founding thesis
1494 · REG harnesses 2236.

## TIER 2 — OWNER-FACING repairs + wins (the on-device muddiness the owner lives in)
Chat composer minimal/Apple/fuse-tools 4345/3538 · no-hidden-fallback 4380 · SS-VIS surface-all-caps 4186 + followons
4409/4410/4411 · SS-IR popup→editors + popover 3762/4134/4154 · SS-QC voice picker + premium 4023/4390/4399/3389/3191/1434
· SS-LT local multi-tool 4273/4416 · SS-GE graph edit + raw-thoughts + toggles 4287/4412/4413 · SS-2S two-surface +
image render 4107/4414/4415 · theme regression 4325/3980 · theme palette/font 1157/1160 · SS-HW HTML workspace
1211/2092/3156/4144/3945/3128 · SS-DD dropdown cleanup 4038 · model-picker simplify 1326/599/1128 · per-model vaults
651/4048 · deep settings repair 1817/2481 · cloned-app settings preserve 3259 · MiniChat/Note/Graph parity 1190 ·
tool toggles gate runtime 1192 · home-graph tunnel 3932/3762 · graph chrome + granular theme 3945 · vault best-essay 1184.

## TIER 3 — per-model engineering + skills + determinism (CHAT-FIRST; ledger 3572 scope rule)
SS-Z per-model framework 3559 · SS-AA GitHub study 3598 · SS-AB/profiles + picker descriptions 3796/3621 · SS-Y
hyperdynamic determinism / local>cloud 3548 · SS-H skills cross-engine 3296 · SS-I external skill ecosystems 3296 ·
skills/tools repair+harden 104/3373/1192/1193 · skill/tool/MCP install+manage 1195/2250/3296 · best-of preset 1201/2124
· capability ceiling Fast→tools 1188/1501 · harness systems 956 · CHAT=full ceiling 1501/2456 · more-useful local
models (LFM/ternary/Bonsai) 3425/1909/1887/1916/1894/1902/2561/2573 · vision runtime + Holo 1894/1902/2577 · BYOM +
HF/GitHub marketplace 1876/1863/1870 · data/fine-tuning substrate 678 · MLX-LoRA-Studio + adapter UX 3810/3830 ·
provider-specific agent 3357 · AI memory sharing 2587 · per-feature hardening 2450 · model-capability-profile combo 3621.

## TIER 4 — MAJOR CYCLES (sequenced after the quick wins; each its own multi-pass build)
EPDOC md-first + convergence 3658/3675/3495/3721/4091 + acceptance SS-EDGE · EPDOC/Tolaria v2 WebKit editor 3433/3779 ·
SS-WL wikilink + auto-research 4062/4072/3111 · Obscura built-in browser 1451/2101/2116/1444 · browser-use/computer-use
first-class 1309/1437/2096 · stealth browsing 1444/2116 · HTML canvas P7.2 2092 + live artifacts 3128/3137 · terminal/console
1213 · PDF live native viewer 3464/2157 · meeting/lecture note STT 2592 · arXiv pull 1870 · web clipper 3111 · vault MCP
server 3119 · DeerFlow 2.0 deep-research space 3224 · voice neural/cloning/bitcrush 3191/3389 · metal streaming overlay 4154.

## TIER 5 — research-ports + big-win backlog (last; deliberate each port via ProvenanceGate)
R-APPS study best OSS apps 1748/2244/2281 · R-KUKU port 2021 · R-CUA 2136 · R-LITEPARSE 2157 · R-LITELLM-CP 2553 ·
R-JSONRENDER 2557 · R-LIVE-ARTIFACTS 3128 · R-SYNC multi-device 3137 · R-VAULT-MCP 3119 · agent-framework deliberation
1856/2505 · arxiv/HF marketplace deepen 1863 · SS-BWB big-win backlog (⌘K, a11y, unified search, vault export) · living
index + lattice explainer 1480 · webkit-maximization policy 1290.

## OWNER-DOMAIN TRACK (PARALLEL — tracked in the plan, NOT loop-built; owner's Cursor/clone work)
Companion→Osaurus refactor 3903 · INFUSE Epistemos IP into ACT(Osaurus)+WORK(Goose) 1844/2493 · Osaurus+Unsloth feed
modes 1804 · WORK/Act/Chat three-modes 1214 · Goose engine-extraction R-GOOSE 1673/2267/2287 · OpenClaw full port
1680/2274 · Hermes fuse 1697/2277 · post-Osaurus enhancements 1671 · Osaurus/Act right-side panel 3345 (the Epistemos-UI
part may be loop-buildable; the clone backend is not). HARD OFF-LIMITS (never built/advertised): NEW MODEL brain-1, 70B.
These ride the plan for sequencing/coordination; the loop does NOT edit clone code (SCOPE BOUNDARY). DUAL-BRAIN
parallel-work coordination 3868.

## STANDING / CONTINUOUS (not one-time items — the passes that wrap every cycle)
Owner-Request Coverage Sweep 4165 · NO-RISK-DEFERRAL + savepoint 4173 · NUANCE-COMPLETENESS 4403 · anti-muddiness
4083 · hardening lifecycle before+after 3145 · tests each cycle 3608 · perf gate before+after 3741 · nuclear
code-checker 3478 · recursive deep research 3693 · initiative research 4028 · build-loop uses subagents 3369 ·
main-only 3415 · vulnerability research repair-before-add 3405 · app-wide staleness sweep 1821/2484 ·
left-unchanged robustness audit 3614 · recurring corpus sweep 1459/2109 · final session-coverage audit 3583 ·
ALL-research→coded + plan-references-all 3453 · OMNIBUS everything researched→hardened→built 3316 · reiteration 3654.

---
**Coverage assertion:** every open `[ ]` ledger line (194 total as of 2026-06-20) is placed in a Tier (0–5),
the Owner-Domain track, or the Standing track above. The ledger remains the per-item authority; this is the walk-order.
Cross-ref RESEARCH_FINALIZATION_INDEX (queue-vs-plan), SS-FOLLOWON, SS-CLEAN, SUBSTRATE_BUILD_SEQUENCE, SCOPE BOUNDARY.
