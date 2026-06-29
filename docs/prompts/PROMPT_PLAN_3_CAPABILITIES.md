# PLAN 3 — Capabilities build prompt (paste to a build agent)

> The capabilities plan, hardened. Thermonuclear-strict, hard gates, FULL clones (EdgeParse/unpdf for App Store;
> browser-use full app for Pro). Runs in PARALLEL with Plan 1 (Goose) + Plan 2 (editor) — boundaries below.

---

```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ LOOP MODE — NEVER STOP until I (the owner) type "stop". This is a continuous loop, not a one-shot. Work the build order item by item; after each, immediately continue. When the whole build order is complete, DO NOT declare "done" and DO NOT idle — keep looping: (a) run a full-app thermonuclear pass and fix what it finds, (b) harden the weakest/thinnest area, (c) write the next OWED codepack (browser-use vendor / Voice / meeting-STT / whole-app-logos) then build it, (d) re-verify everything still green, then repeat. There is always a next hardening pass. Only the owner's "stop" ends the loop. Commit at every clean point.

You are building PLAN 3 = Epistemos capabilities. Deeply hardened, contradiction-free, nothing lost — and whatever is cloned must be FULLY cloned (settings and all, 100% capability, so no usefulness is lost).

READ FIRST (the PLAN doc wins on conflict):
  - docs/research/PLAN_3_CAPABILITIES_2026_06_28.md  (THE plan — scope, §1–§11, CLONES LEDGER, build order)
  - Codepacks (real code + file:line): PLAN_3_EDGEPARSE_CODEPACK, PLAN_3_PROVENANCE_CODEPACK, PLAN_3_VAULT_MCP_CODEPACK, PLAN_3_OBSCURA_TIER1_CODEPACK, PLAN_3_EXTENSIBILITY_CODEPACK, PLAN_3_APPLE_NATIVE_CODEPACK, PLAN_3_LANDING_BUTTONS_CODEPACK, PLAN_3_ARXIV_CODEPACK (all docs/research/*_2026_06_28.md)
  - Project rules: CLAUDE.md (NON-NEGOTIABLE CONSTRAINTS — esp. NO hidden subprocess/Python on the MAS path; keys in Keychain; honest capability gating; @Observable; never block @MainActor). RESEARCH-FIRST: read before editing, verify code/disk before asserting, tag [VERIFIED-CODE].

OWNER-FINAL scope (2026-06-28): Fast PDF→MD · Provenance moat · Extensibility (skill/MCP install + best-of preset + vault-as-MCP-server) · Apple-native maximization · Landing-page buttons (every feature is a one-tap button) · Browser (lite native WKWebView tab for the App Store + browser-use Chromium robot for Pro) · arXiv pull · Meeting/STT note · Voice · Whole-app brand logos. CUT (do NOT build/re-add): Obscura native automation engine (→ browser-use), ColBERT, local model-management (HF/BYOM/stack/vision), three-engine/Osaurus, DeerFlow. AI is Goose-only.

★ NATIVENESS + UNIFIED LOOK (BINDING — read docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md; web panels also read GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md for the VERIFIED tokens/springs/glass recipe/code-to-lift):
  - ONE unified Apple-native look across AppKit + WebView + the Goose surface, from SHARED sources: SF Pro (-apple-system) + shadcn Apple tokens (Action Blue #0066cc) + macOS HIG geometry + macOS-26 Liquid Glass + the EXACT SwiftUI springs. Everything Plan 3 ships must match Goose + the editor + the shell — the user never perceives native-vs-web.
  - PLAN-3 SPLIT: NATIVE = Apple-native shared views (QuickLook/VisionKit/Live-Text/thumbnails), landing-feature buttons, the lite Browser tab CHROME, arXiv/meeting/voice/provenance UI, the PDF viewer (consume Plan 2's — don't re-invent). WEB = browser-use's Chromium UI (Pro, its OWN surface — reskin its hosted web UI with the same tokens where feasible; stay HONEST that CDP-Chromium ≠ WKWebView, two separate browsers). The lite native Browser tab is a WKWebView → transparent-over-glass + tokens like any web body.
  - REAL Liquid Glass on native views (NSVisualEffectView / macOS-26 glassEffect — in-repo Theme/GlassModifiers.swift, Views/Shared/UnifiedFrostedGlass.swift). Any hosted web panel = TRANSPARENT (drawsBackground=false, proven Views/Epdoc/EpdocKaTeXPreview.swift:79) over real glass + SF Pro + theme tokens + frost/specular fallback (refraction Chromium-only).
  - MOTION: deeply fluid, ProMotion 120fps, MINIMAL. Verified SwiftUI springs → {duration,bounce}: .smooth {0.5,0} · .snappy {0.5,0.15} · .bouncy {0.5,0.3} · .interactiveSpring {0.15,0.14}. transform/opacity only; interruptible; reduce-motion. No lag/jank/bug; A/B pixel-diff vs native = the bar.
  - GRAPH = already full AppKit/Metal → DO NOT TOUCH. SF Symbols real only in native views; any web panel keeps web icons restyled to match (never bundle SF Symbols into a webview).
  - CODE-RESEARCH: back every change with REAL openable code (in-repo file:line first, then vetted OSS + license + ProvenanceGate). RESEARCH-BETWEEN-IMPLEMENTATION: between each slice, research local docs + repo + online primary sources, READ before editing; exhaustive (tokens are NOT a constraint); no-contradiction + preserve-nuance + break-nothing.

BUILD ORDER (per the plan): (1) Fast PDF→md — vendor EdgeParse + unpdf into agent_core, behind the EXISTING wired LiteParse import UI (same FFI envelope), flip it ON for MAS; + the PDF/parsed-.md coexistence (source_pdf frontmatter). (2) Provenance moat — the honest VRMLabel.honestLabel gate (no "Verified" chip without a real active anchored claim) + the tightened Settings audit + the hover-lineage card (ship Fix-A and the view IN THE SAME COMMIT). (3) Extensibility — vault-as-MCP-server (read-only, reuse WorkNativeMCPServer transport, persistent Keychain token, Pro) → skill/MCP install UI → best-of preset. (4) Apple-native (QuickLook/VisionKit Live Text/thumbnails) · Landing buttons (LandingFeatureButton) · arXiv pull. (5) Browser — lite native WKWebView tab (PLAN_3_OBSCURA_TIER1_CODEPACK, de-Obscura-named "Browser") for MAS; then browser-use (Pro). (6) Meeting/STT note · Voice · whole-app logos.

★ FULL-CLONE requirement (owner: "100% useful before I App-Store it"):
  - EdgeParse + unpdf: pin the REAL repo URL + a real SHA; vendor the full parser crates with the COMPLETE feature set (tables/headings/reading-order/multi-column config) — no partial graft. ProvenanceGate (Apache-2.0/MIT = direct_import). MAS-safe (pure Rust, no Python/dylib).
  - browser-use (Pro lane): vendor the FULL browser-use app — browser-use + web-ui + cdp-use + the Python 3.11 env + Playwright Chromium — host its web UI in a WKWebView and reskin the CSS, expose its actions to Goose as MCP tools. NOTHING dropped (all of its settings/features). HONEST: browser-use drives Chromium via CDP — it does NOT and CANNOT drive the native WKWebView "Browser" tab; they are two separate browsers. Pro/Developer-ID only (Python+Chromium is not App-Store-safe); the MAS build shows an honest "Pro only" gate. Needs a vendor codepack (write it first, grounded, then build).

THERMONUCLEAR DISCIPLINE (run the skill above, recurring — each capability + a full pass periodically):
  - Honest findings only: correctness, dead/stale code, honesty-constraint violations (esp. fake "verified" provenance chips), perf, contradictions.
  - DELETION GUARDRAIL: harden/dedupe over delete; never delete new/in-progress/owner-requested code; KEEP+flag when unsure; commit deletions separately.
  - NO CONTRADICTIONS: the plan was heavily edited (Obscura/ColBERT cut). Before each stage, grep the plan + codepacks for any stale claim that contradicts the OWNER-FINAL scope; fix the source.

HARD GATES / FORBIDDEN:
  × Any Python/subprocess/Chromium on the MAS (App Store) path — those are Pro-only (browser-use, etc.), honest-gated.
  × A "Verified" provenance chip that doesn't dereference a real active claim (the honest gate must ship WITH any chip).
  × Surfacing a write/exec tool through the read-only vault-as-MCP-server (enforce the read-only allowlist at the core).
  × Building the cut items (Obscura native robot, ColBERT, model-management). Leave the WebKitBrowserEngine stub NotConfigured.
  × Build-green ≠ done. PROVEN-DONE bar: real-state · live in-app · migrates existing data · end-to-end · witnessed (Swift Testing @Test compile-verify + manual run for UI; cargo test --lib for Rust — note xcodebuild/cargo check skip #[cfg(test)], so use cargo test). Zero regressions.
  × Keys in UserDefaults (Keychain only); editing .xcodeproj (xcodegen only); committing model files / .gguf.

PARALLELISM / NO-COLLISION (Plan 1 + Plan 2 agents build concurrently in this repo):
  - You OWN: the PDF→md PARSE engine (agent_core EdgeParse/unpdf + the LiteParse FFI/import controller) + the source_pdf storage contract, provenance moat (AnswerPacket/VRMLabel/provenance Swift), vault-as-MCP (Epistemos/Vault/*), extensibility (MCP registry/install/best-of), Apple-native shared views (Views/Shared/*), landing buttons (Views/Landing/LandingFeatureButtons), the lite Browser tab + browser-use (Pro), arXiv (Epistemos/Arxiv/*), meeting/STT, voice, logos.
  - Do NOT touch: Epistemos/Goose/* + Epistemos/Agent/* (Plan 1) · the Plan-2 editor surfaces (Epdoc/code-editor/Prose/MarkEdit-embed/js-editor/HTML-workspace/wikilinks). The PDF *viewer* (PDFKit PDFView) is PLAN 2's — you provide the resolved source_pdf URL, Plan 2 mounts the viewer. Vault-as-MCP read tools query the existing search/vault dispatcher; don't fork it.

Commit at clean points (main-only). When unsure, RESEARCH-FIRST then act. Stop only when I say stop OR the build order is complete with PROVEN-DONE evidence.
```
