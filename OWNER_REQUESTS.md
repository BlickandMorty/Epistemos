# Owner requests — complete tracked list (2026-07-03 overhaul session)

Durable mirror of the task list so no request is ever lost. Status is verified against builds; "DONE" = build-verified (compiles + owner must relaunch to see). Pending items grouped by what they need.

## ✅ DONE + build-verified (relaunch to see these)
1. Commit the session work — committed a6927ac03.
2. Delete 4 landing buttons (vault MCP, extensions, provenance, voice).
3. Delete the entire Browser-Use Pro lane (kept the lite browser).
4. arXiv page — full-page layout + Home button in toolbar + liquid-glass/pixel polish.
5. Meeting page — Home button in toolbar (with unsaved-transcript confirm) + polish.
6. Browser — no Home button + URL bar as a floating liquid-glass bubble.
7. Retire the HomeEmbeddedPage floating "← Home" chip (surfaces own their Home button).
8. All non-custom themes share Ember's font faces (Platinum keeps its OWN landing-greeting font; Ember+Classic share Ember's greeting font).
9. Platinum heading SIZE now matches the others (headingSizeMultiplier 0.72/0.82 → 1.0).
10. Custom theme → EXPERIMENTAL + OFF by default (Settings toggle).
11. Harden custom theme on web surfaces (KaTeX + appearance-aware HTMLWorkspace previews; full-custom-palette previews documented as a deferred experimental-edge case).
12. Browser ↔ notes: "Save to notes" button + browser opens as a TAB sharing the notes window (like HTMLWorkspace/code editor).
13. Browser forces the Epistemos palette + pixel font (headings) onto EVERY webpage, re-applied on theme change.
14. Links (detected in notes/text) auto-open in the in-app themed browser.
15. arXiv — auto-featured recent-AI/ML feed on open; "view paper" opens the abs page in the themed browser tab.

## ⏳ PENDING — in progress
- **#16 Reconcile tests broken by the overhaul** (regression) — theme-test subagent running; then I fix LandingFeatureButtonsPlan3Tests:78 + broad confirmation pass. THE OVERHAUL IS NOT "DONE" UNTIL THIS IS TEST-GREEN.

## ⏳ PENDING — next batched UI build (I apply after #16 clears)
- **#15** Prose preview (NotePreviewSurfaceView) — kill the top padding/space (HTMLWorkspace preview is fine per owner; it's the PROSE preview).
- **#17** Editor mode toolbar — native individual items (not one `.regularMaterial` Capsule) + **Circle** selection instead of the square box.
- **#18** Browser — apply the pixel font to links + bold + page titles (NOT body text).
- **#19** Browser — custom pixel-art, theme-aware home/new-tab page ("Epistemos Browser") with a search box + easy Google/DuckDuckGo picker.
- **#20** HTMLWorkspace + browser — start at a sensible larger size (they open compressed then snap on resize).
- **#21** arXiv — fix blank-on-open (likely old build; make the feed robust + a visible loading state) + add much more functionality/features.
- **#23** Epdoc — adaptive header sizing (longer header → smaller) to match prose for all themes. (Needs a js-editor/ npm bundle rebuild you'd run.)
- **#24** Epdoc↔prose color match in the embedded home graph (fix the two-tone).

## ⏳ PENDING — needs your visual confirm
- **#25** Platinum landing greeting size — tune a per-theme multiplier if it reads small.

## ⏳ PENDING — after all UI tasks
- **#22** Deep hardening pass on the non-Goose app (security/concurrency/webview/robustness) for enterprise + MAS review.

## KEY NOTE
Most of what looks missing in your running app (arXiv feed, browser theming, note-tab, toolbar changes) is **already written + verified-compiling** but NOT in your running copy — I haven't shipped a final green build yet because the test-regression reconciliation (#16) is finishing. **Relaunch after the next green build** to see everything at once.
