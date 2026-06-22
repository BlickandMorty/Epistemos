# Act surface — owner runtime-verify checklist (2026-06-22)

The act P0 is at the buildable done-bar (build-green, Pro + MAS). Per the owner's standing
directive — **build-green ≠ working; runtime-verify is mandatory** — here is the exact, ordered
check to run on ONE fresh Pro launch from Xcode (scheme **Epistemos**, not Epistemos-AppStore).
Each item names what it proves + the commit that delivered it, so a failure pinpoints the fix.

## Launch
1. Build + run the **Epistemos** scheme from Xcode (fresh build — not a stale archive).

## A. It IS Osaurus's own UI, reskinned (not the old chat with a badge)
2. Open act. The surface should be **Osaurus's real ChatView** (its landing/thread/composer),
   reskinned to the Epistemos cream/monospace look — NOT the byte-identical old chat.
   (commit `41081f4f9` mounts `EpistemosOsaurusChatHost`; reskin via `bootstrapAndThemeOnce`.)
3. **No white bar** at the very top, and clicking to open act lands on the **Osaurus landing**,
   NOT the old "Ask anything… Fast·Tools·Agent" search screen. (`9b43d37e9` `showingOsaurusSurface`.)
4. **One** act/work toggle (the top "Act | Work" capsule) — the duplicate pill under the
   "GREETINGS, RESEARCHER" greeting is gone. (`71c1e01f3`.)

## B. Send WORKS, with YOUR model (the #1 concern)
5. The model picker shows **your models** (the GGUF/QAT ladder), and the **default selected**
   model is **yours** (not Apple Foundation / an Osaurus default). (`efe95c8dd` seeds the owner's
   first model as the default-agent model, once; the bridge `item-4` makes them routable.)
6. Type "test" and send. It should return a **real reply from your model, in-process** — no
   "ActOsaurusError error 2" / requestFailed (that HTTP path is bypassed by the in-process
   ChatView). If a send fails, the chat shows an **actionable** message (not a raw code) — e.g.
   "Open Settings → Models…". (`ac8d3974e` + `2e7cd786a` LocalizedError.)
7. The **chat title** is a short clean title — NOT the model's self-description
   ("…a Large Language Model developed by Google DeepMind…"). (`0233c38ee` sanitizer.)

## C. The 3 grafts (owner must-keeps)
8. **Side panel** — Osaurus's session sidebar shows by default (reskinned). (`8a8c3a2cd`.)
9. **Scroll-blur** — content softly blurs at the top edge as you scroll up. (`3374898de`.)
10. **Message bar** — the composer carries the Epistemos cream/monospace look (white input,
    cream border, SF Mono). NOTE: this is the reskin; the exact old-composer STRUCTURE (chips
    layout) is NOT swapped in — Osaurus owns the composer + its send wiring. Tell the loop if
    you want specific composer structure changes (those need Osaurus ChatView surgery).

## If anything fails
- Note WHICH numbered item + what you saw. Each maps to a commit above → the loop fixes that
  specific surface. Build-green can't catch these; your one launch is the definitive signal.
