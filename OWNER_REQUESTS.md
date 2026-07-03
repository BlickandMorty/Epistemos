# Owner requests — complete tracked list (2026-07-03 overhaul session)

Durable mirror of every request so none is lost. "DONE" = build-verified (compiles; relaunch to see). Verified against builds this session.

## ✅ DONE + build-verified (relaunch to see all of these)
1. Commit the session work (a6927ac03 + follow-ups).
2. Delete 4 landing buttons (vault MCP, extensions, provenance, voice).
3. Delete the entire Browser-Use Pro lane (kept the lite browser).
4. arXiv page — full-page layout + Home button in toolbar + liquid-glass/pixel polish.
5. Meeting page — Home button in toolbar (with unsaved-transcript confirm) + polish.
6. Browser — no Home button + URL bar as a floating liquid-glass bubble.
7. Retire the HomeEmbeddedPage floating "← Home" chip.
8. All non-custom themes share Ember's font faces (Platinum keeps its own greeting font).
9. Platinum heading SIZE now matches the others (headingSizeMultiplier → 1.0). [This was the real Platinum issue, not the greeting.]
10. Custom theme → EXPERIMENTAL + OFF by default (Settings toggle).
11. Harden custom theme on web surfaces (KaTeX + appearance-aware previews).
12. Browser ↔ notes: "Save to notes" + browser opens as a TAB sharing the notes window.
13. Browser forces the Epistemos palette + pixel font (headings/links/bold/titles) onto EVERY webpage.
14. Links (detected in notes/text) auto-open in the in-app themed browser.
15. arXiv — auto-featured recent-AI/ML feed on open + "view paper" in the themed browser tab.
16. Reconcile tests broken by the overhaul (theme-pair reconciliation).
17. Editor mode toolbar — native individual items + Circle selection (not the square box).
18. Browser — pixel font on links + bold + page titles (not body text).
19. Browser — custom pixel-art themed home/new-tab page + Google/DuckDuckGo picker.
20. HTMLWorkspace + browser — open at a sensible larger size (not compressed).
21. arXiv — blank-on-open fixed (loading state + robust feed) + category-browse chips (more features).
22. Deep hardening pass — adversarial audit of the overhaul: no CRITICAL/HIGH, no MAS blockers; 3 LOW fixes + 1 documented.
23. Epdoc adaptive header sizing (longer → smaller, mirrors prose) — runtime observer, all themes.
24. Epdoc↔prose color match in the embedded graph — editor body now paints the explicit solid canvasBackground (was a transparent webview compositing darker on Ember dark).
25. Platinum greeting — confirmed the real issue was headers (item 9), already fixed.
26. Classic greeting case — "GREETINGS," uppercase + "researcher" lowercase (matches Ember).

## ⏳ PARTIAL — needs your visual verification
- **#15 preview title** — the top PADDING is deleted (0). The SEE-THROUGH-TITLE part is confirmed root-caused (note windows use `.fullSizeContentView` + `titlebarAppearsTransparent`, NoteWindowManager:32-34, so preview content sits under the translucent titlebar). The note PROSE preview already covers this with a solid `previewTopChrome` bar. The HTMLWorkspace preview (your .htmlworkspace screenshots) needs the same solid top chrome, but the code path shows its WKWebView already laid out below the toolbar/header — so the exact bleed needs verifying against the live view before I change the layout (not guessing blind, per your instruction). ACTION: after relaunch, tell me if the see-through is on the note prose preview or the HTMLWorkspace preview and I'll add the titlebar-inset-aware solid chrome to the exact one.

## ▶ NEXT (owner-directed): deep recursive hardening
After the above, the owner asked for "deep deep hardening — beneath backend, frontend, engines." Proceeding autonomously through the EPISTEMOS_HARDENING_DIRECTIVE phases on the non-Goose app.

## KEY NOTE
Everything marked DONE is build-verified and committed but only visible after you RELAUNCH the app. Goose-owned code is excluded from all of this per your standing instruction.
