# B-2 Obscura Browser — User Decision Research

**Status:** COMPLETE_RESEARCH_READY  
**Date:** 2026-05-16  
**Terminal E scope:** user-decision preparation only; no implementation.

## Problem Statement

The user needs to decide whether to start a Pro-only Obscura browser sprint, or defer Obscura indefinitely.

MAS is already decided separately: `MAS_COMPLETE_FUSION` immutable rule 6 says MAS uses URL fetch plus Apple-native `WKWebView` only, with no in-process JavaScript runtime. The open decision is therefore Pro-only: should Epistemos invest in a Rust library-embedded browser engine plus `deno_core` V8 isolate and Eidos search path, or leave the current Pro browser automation surface alone?

The reconciliation gate found that current main has Pro browser automation through `agent_core/src/tools/browser.rs`, but it wraps a user-installed `agent-browser` CLI. It is not Obscura, not `deno_core`, and not the BrowserEngine trait. The Obscura-specific substrate is still not in main.

## Options

### Option A — Pro-only sprint kickoff, audit-first

Start a Pro-only sprint, but make the first milestone an audit and adapter spike: verify the Obscura crate API/security posture, pin V8 compatibility against `deno_core`, and land only a non-MAS BrowserEngine trait/mock plus decision gates before attempting full browser automation.

**Pros**
- Keeps MAS rule 6 intact while giving Pro a serious path beyond the current CLI wrapper.
- Forces the external crate and V8 versioning risks to the front.
- Gives Eidos and future browser tools a typed home instead of binding more features to `agent-browser`.
- Avoids indefinite drift while still refusing a big-bang integration.

**Cons**
- Adds Pro-scope engineering while V1/MAS work remains active elsewhere.
- Requires ongoing dependency pinning for `rusty_v8` / `deno_core`.
- May discover Obscura is not mature enough, making the spike partially throwaway.

### Option B — Full Pro implementation sprint now

Begin the full W6-A through W6-I implementation path: Obscura library embed, `deno_core`, UniFFI bridge, SwiftUI live view, Eidos index, Metal re-rank, constrained citations, and tool catalog additions.

**Pros**
- Fastest route to the addendum's full browser + Eidos product story.
- Replaces CLI subprocess browser automation with an in-process Pro architecture.
- Builds the search and browser substrate together.

**Cons**
- High blast radius and many new moving parts.
- External browser engine maturity is not yet proven.
- Full sprint competes with higher-priority Terminal E user decisions and sibling implementation tracks.
- This would be inappropriate for MAS and must remain Pro-gated.

### Option C — Keep current Pro CLI browser, defer Obscura

Do not start Obscura now. Keep the existing Pro `agent-browser` CLI tool surface as the working browser automation route, and revisit only if Pro customers need lower latency, tighter screenshot streaming, or Eidos web augmentation.

**Pros**
- No new dependency or V8 risk.
- Existing Pro browser tools remain available.
- Preserves focus for other decision items and V1 closure.

**Cons**
- Leaves the "in-process browser" doctrine dormant.
- Keeps Pro browser automation on a subprocess/CLI path.
- Eidos web augmentation remains future architecture rather than an executable search surface.

### Option D — Defer indefinitely

Record Obscura as not on the roadmap. Keep MAS URL-fetch/WKWebView, keep current Pro CLI browser tools, and do not schedule Obscura or `deno_core`.

**Pros**
- Eliminates a complex browser-engine integration class.
- Avoids V8/JIT dependency management entirely.

**Cons**
- Abandons the B3 addendum's Pro browser moat.
- Makes Eidos web augmentation less likely to ship as designed.
- Leaves future agents tempted to invent smaller, inconsistent browser backends.

## Canonical Sources

### `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md`

- Lines 28-38: Obscura and `deno_core` are Pro browser/JS substrates.
- Lines 57-64: Obscura, `deno_core`, V8 dedup, Eidos, and SwiftUI browser surface are not in main.
- Lines 95-103: the build order is W6-A Obscura, W6-B `deno_core`, then bridge/UI/Eidos/tooling.
- Lines 117-123: the lift target intentionally does not add `deno_core`; security and V8 questions remain open.

### `/Users/jojo/Documents/Epistemos-QuickCapture/OBSCURA_BROWSER_ADDENDUM.md`

- Lines 3-9: FINAL_SYNTHESIS corrects the older "Obscura default" claim into BrowserEngine with WebKit baseline, Obscura Pro, and Mock.
- Lines 13-15: Wave 6 scope combines browser engine, `deno_core`, and Eidos.
- Lines 118-144: Obscura is a library embed with explicit V8 dedup discipline.
- Lines 277-293: `deno_core` is the intended Pro JS execution path, trading crash isolation for lower startup and bundle cost.
- Lines 909-977: Phase 14 splits Obscura, Metal kernels, `deno_core`, Eidos, and live view.
- Lines 1034-1040: V8 dedup, Pro JS crash radius, App Store/JIT, and `deno_core` API stability are explicit risks.

### `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md`

- Line 20: immutable rule 6 keeps MAS on URL-fetch and `WKWebView`; Obscura and `deno_core` are Pro-only.
- Lines 22-31: future egress allowlist is separate from BrowserEngine and remains not started.

### `docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md`

- Lines 54-59: B-5 resolved the MAS/Pro split and current code reality.
- Lines 138-142: H-11 says Obscura/`deno_core` are Pro-side post-V1 and not shipped in main.

### Current Code State

- `agent_core/Cargo.toml` lines 7-19: default build is MAS; `pro-build` gates Pro-only surfaces.
- `agent_core/Cargo.toml` lines 39-120: no `obscura`, `deno_core`, or `rusty_v8` dependency is present.
- `agent_core/src/lib.rs` lines 124-127: `tools::browser` is compiled only with `pro-build`.
- `agent_core/src/tools/browser.rs` lines 1-7: current browser tools wrap `agent-browser` CLI.
- `agent_core/src/tools/browser.rs` lines 530-574: current path searches for and runs `agent-browser`.
- `agent_core/src/tools/registry.rs` lines 2303-2384: browser tools register only under `pro-build`.

### External Primary Sources Checked

- GitHub `h4ckf0r0day/obscura` — https://github.com/h4ckf0r0day/obscura: public Obscura repo is active and positions itself as a Rust headless browser, but the repo itself is not proof of Epistemos security audit completion.
- docs.rs `deno_core` — https://docs.rs/deno_core: the crate is an embedding layer around V8 and Deno ops, supporting the addendum's library-runtime direction.
- Apple Developer `WKWebView` — https://developer.apple.com/documentation/webkit/wkwebview: confirms WKWebView is the platform-native web-content view for the MAS baseline.

## Code Impact Estimate

### Option A — Pro-only audit-first sprint

Estimated implementation: 500-1,500 LOC for spike artifacts and gates, excluding full browser engine integration.

Likely files:
- `agent_core/src/browser_engine/mod.rs` or equivalent new module.
- `agent_core/Cargo.toml` only if a gated spike dependency is deliberately added.
- `agent_core/src/tools/registry.rs` if the trait starts replacing `agent-browser` dispatch in Pro.
- A new decision/audit doc for Obscura security and V8 pinning.

Tests:
- BrowserEngine mock unit tests.
- Pro/MAS compile-gate tests proving no Obscura symbols in MAS.
- Dependency-resolution check for a single V8 version if crates are added.

### Option B — Full Pro implementation sprint now

Estimated implementation: 8,000-15,000 LOC across Rust, Swift, UniFFI, tool registry, tests, and Eidos.

Likely files/modules:
- `agent_core/src/browser_engine/`
- `agent_core/src/jsruntime/`
- `agent_core/src/eidos/`
- `agent_core/src/tools/action/browser_automate.rs`
- `agent_core/src/tools/search/eidos_query.rs`
- UniFFI browser/Eidos bindings
- `Epistemos/Browser/`
- `Epistemos/Search/EidosSearchView.swift`
- Cargo feature gates and dependency patches for V8 dedup

Tests:
- MAS symbol-leak tests.
- Pro browser render/screenshot/extract integration tests.
- `deno_core` op capability tests.
- Eidos indexing and citation grammar tests.
- Memory-pressure/concurrency tests on 16 GB hardware.

### Option C — Keep current Pro CLI browser, defer Obscura

Estimated implementation: 0-300 LOC for doctrine and status cleanup only.

Tests:
- Existing Pro browser handler tests remain sufficient.
- Optional audit asserting no Obscura/`deno_core` dependencies are present.

### Option D — Defer indefinitely

Estimated implementation: docs only, but downstream browser/Eidos architecture remains blocked.

Tests:
- No code tests; verify future docs do not imply Obscura is scheduled.

## Recommendation

Recommend **Option A: Pro-only sprint kickoff, audit-first**.

Reasoning:
- MAS is already protected by immutable rule 6, so a Pro-only spike does not create MAS review risk if compile gates stay strict.
- The current Pro browser path is real but CLI/subprocess-based; it does not satisfy the Obscura/Eidos doctrine and should not become the long-term anchor by accident.
- A full sprint is premature because the local corpus itself flags Obscura security posture, V8 deduplication, `deno_core` API stability, crash radius, and App Store/JIT questions as risks.
- Indefinite deferral is too blunt: it leaves Eidos and browser-engine architecture dormant and increases the chance of ad hoc future browser backends.

Recommended wording for the decision record:

> Start a Pro-only Obscura audit/spike sprint after V1 MAS closure. First milestone: BrowserEngine trait + mock + MAS symbol gate + Obscura repo/API/security audit + `deno_core`/`rusty_v8` pin proof. Do not begin full browser/Eidos implementation until that spike passes.

## Acceptance Criteria

If the user chooses **Option A**:
- MAS default build has no `obscura`, `deno_core`, or `rusty_v8` dependency.
- A BrowserEngine trait/mock lands without replacing MAS web tools.
- A Pro-only spike proves whether Obscura and `deno_core` can share one V8 version.
- Security audit records Obscura crate maturity, license, open issues, API stability, and stealth-mode implications.
- Current `agent-browser` CLI path remains available until the replacement proves better.

If the user chooses **Option B**:
- All Option A gates pass first.
- Pro build can render, screenshot, extract, and run bounded browser scripts in-process.
- `deno_core` ops expose only declared capabilities.
- Browser actions produce execution receipts and RunEventLog entries.
- Eidos returns citation-grounded results against vault drawer IDs.
- MAS symbol audit stays clean.

If the user chooses **Option C**:
- MAS rule 6 remains unchanged.
- Current Pro browser CLI status is documented as the active browser route.
- Obscura remains deferred with explicit revisit triggers.

If the user chooses **Option D**:
- B3/H-11 rows are marked dormant or superseded.
- Eidos web augmentation is either removed from roadmap or redesigned without Obscura.
- Future browser-related docs cannot claim an Obscura-backed path is planned.

## Decision-Ready Prompt

**B-2 Obscura browser decision:** What should happen with Obscura and `deno_core`?

1. **Pro-only audit-first kickoff** — after V1 MAS closure, start a bounded Pro spike for BrowserEngine trait/mock, Obscura security/API audit, and `deno_core`/V8 pin proof. **Recommended.**
2. **Full Pro implementation now** — start W6-A through W6-I immediately.
3. **Keep current Pro CLI browser, defer Obscura** — no Obscura work now; revisit only if the CLI path becomes limiting.
4. **Defer indefinitely** — remove Obscura from the active roadmap and redesign dependent Eidos/browser plans.

Answer with one option label and any constraints, for example: "Option 1, but no dependency additions until the audit doc is complete."
