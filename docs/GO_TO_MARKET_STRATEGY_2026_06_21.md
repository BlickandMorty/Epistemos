# Go-To-Market / Visibility / Monetization — strategy notes (owner 2026-06-21)

Owner wants recognition + to sell it; anxious about visibility despite a strong multi-area moat. Honest plan.

## Monetization model (maps cleanly onto the dual-build we already planned)
- **MAS build = the FREE (or low-cost) funnel** — discoverability + Apple trust + one-click install. It's the
  ~95% version (no Linux-VM sandbox). Use it for REACH/acquisition.
- **Pro / direct-distribution build = the PAID full version** — VM sandbox + full power, sold on your
  website/GitHub release. You keep ~100% (no Apple 15-30% cut), no sandbox limits, Sparkle auto-update.
  Payments via Stripe / Paddle / Lemon Squeezy (Paddle/LemonSqueezy handle tax/merchant-of-record).
- Net: **free MAS for discovery + trust → paid Pro direct for power users + margin.** The dual-build IS the
  pricing tiering — no extra work. (Alt: paid MAS too; but free-funnel→paid-Pro is the stronger indie play.)

## Visibility levers (what actually works for dev-tool / PKM apps in 2026)
- **SHOW, don't tell — your unfair advantage.** The pixel-art UI + motion language + 120fps editor + agentic
  act/work are VISUALLY striking → screenshottable/demo-able = the thing that spreads. A great 30-60s demo
  video/GIF is your highest-leverage asset.
- **Launch surfaces:** Show HN (Hacker News), Product Hunt, r/macapps, r/ObsidianMD, r/LocalLLaMA, X/Twitter
  dev+PKM circles. You sit at the INTERSECTION of 3 communities (PKM, local-LLM, agentic-coding) → you can
  credibly post in all three; comparables (OpenCode 170k★, Goose, Tolaria) grew exactly here.
- **Open-source angle (high-leverage):** OpenCode/Goose/Tolaria grew via open source = distribution + trust +
  contributors. Consider an OPEN CORE / open components (you're already building ON open clones, so an open
  posture is natural + aligned) while the paid Pro stays closed. Stars = credibility = the flywheel.
- **Narrative hook:** lead with the uncontested combination — "a local-first agentic workspace that contains a
  Codex-class engine — not a weaker Codex, a broader tool." + "no lock-in, your models, your vault."
- **Build in public:** share the journey (Lucid→Epistemos rebuild, the Osaurus clone, the agent-native vault)
  — seeds an audience BEFORE launch. A killer landing page (owner already loves theirs) + one-line positioning.

## Honest reframe (the anxiety)
- The MOAT is real + uncontested (research-verified) — that's the part most fail at, and you have it. Moat ≠
  visibility, but a real moat makes visibility CONVERT (retention + word-of-mouth) once seeded.
- Visibility is a GRIND, not a switch — consistent showing-up; one HN/PH/viral-demo hit can be a big inflection.
- Your VISUAL DISTINCTIVENESS is itself a visibility asset (most dev tools look the same; yours doesn't).
- This is owner-domain (not an agent-build task) — captured so it's not lost. Build first; this is the launch plan.

## Distribution stack — where the PAID Pro goes (owner 2026-06-21)
MISCONCEPTION corrected: **GitHub Releases CAN host compiled binaries (.dmg/.zip) with NO source** — a repo
can be just a README + releases; you're not forced to publish code. BUT GitHub Releases has **no paywall** →
it's for FREE distribution only. For PAID you need a payment layer.
**Easiest paid path (no backend/website required): a merchant-of-record store** — **Lemon Squeezy / Gumroad /
Polar** (or Paddle). They host the binary + handle **payment + sales tax + license-key delivery** for a % per
sale, low/no upfront cost. You upload the .dmg; they sell + deliver download + license key. In-app: validate
the license via their API; **Sparkle** for auto-updates on direct builds. (Your own site + Stripe = more
revenue/control but more setup — do later.)
**Recommended stack:**
- FREE build → **MAS** (discovery/trust) + optionally **GitHub Releases** (direct free, no source).
- PAID Pro → **Lemon Squeezy / Gumroad / Polar** (binary + license + payment, NO backend). 
- **Website = a LANDING PAGE only** (the existing pixel-art web app) linking to free (MAS/GitHub) + paid
  (store) + the demo. **You do NOT need a paid/active backend site to start** — the store IS your checkout.
- Updates → Sparkle; license gate → store API.

## Visibility — easiest free method (answering "is this best?")
Your Reddit + website plan is GOOD + free. Refine:
- **Reddit (free, high-fit):** r/macapps, r/ObsidianMD, r/LocalLLaMA, r/SideProject — among the best free
  channels for a niche PKM/dev/local-LLM tool. Lead with a DEMO GIF/video.
- **Add (free, high-leverage, one-shot):** **Show HN** (Hacker News) + **Product Hunt** — strong for
  local-first/open-source/dev tools.
- **X with no followers:** don't GATE launch on building a following — slow. Post the demo anyway (striking
  visuals get picked up regardless of follower count); grind X as a slow-burn, not a prerequisite.
- **The multiplier = a 30-60s DEMO GIF/VIDEO** — it's what makes every channel work.
- **Landing page** links to free + paid + demo. That's the easiest, free, best-fit method — no paid site needed.
