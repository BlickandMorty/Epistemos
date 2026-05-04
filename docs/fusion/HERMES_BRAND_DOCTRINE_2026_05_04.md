# Hermes Brand Identity Doctrine — Real NousResearch Assets, Not Placeholders — 2026-05-04

> **Companion doctrine to `CANONICAL_RECOVERY_PLAN`.** The Hermes Expert
> Mode landing surface (T5) currently uses placeholder visuals — an
> SF Symbol `figure.stand.dress` for the sigil, the project's generic
> accent color for the brand, and `AppDisplayTypography` for the hero
> font. **None of this is canonical.** The real Hermes Agent visual
> identity comes from NousResearch and must drive every Hermes-branded
> surface in the app.
>
> **Status as of 2026-05-04:** doctrine written; assets NOT yet
> acquired; placeholder visuals carry explicit `HERMES-BRAND-STUB`
> markers for the recovery migration.

---

## 0. The thesis

When the user says "Hermes Agent" in the UI, they expect to see the
**actual NousResearch brand** — the Hermes wordmark, the Nous
Research logo, the canonical Hermes color, the canonical typeface.
Generic SF Symbols + system colors + system fonts are placeholders
that ship under explicit deferral; they're not the canon.

This doctrine pins:
1. What assets need to be acquired and from where
2. The licensing question (must be answered before bundling anything)
3. The design-token shape that lets every Hermes surface swap from
   placeholder → real assets in one file
4. The deferral discipline — every placeholder gets a `HERMES-BRAND-STUB`
   marker + row in §6 so the migration list is explicit

---

## 1. The asset inventory (what needs acquiring)

### 1.1 Logos

| Asset                              | Source                                                     | Licensing question |
|---|---|---|
| Nous Research wordmark / logo      | nousresearch.com (their official site)                     | **Confirm with user** before bundling. Likely needs explicit permission OR fair-use partnership framing |
| Hermes wordmark (if separate)      | NousResearch's Hermes brand assets                         | Same question |
| Hermes "agent" sigil / mark        | If they publish one; otherwise design a reverent placeholder per §3 | Same |
| Caduceus (the actual Hermes symbol — Greek mythology) | Public domain (mythological symbol); lots of vector versions on Wikimedia | Free to use; design choice question |

**Preferred approach:** the caduceus + a tasteful "Hermes" wordmark
is fully shippable without NousResearch licensing entanglement. If
the user wants the literal NousResearch identity, that requires
their permission and stays gated behind §5 below.

### 1.2 Typography

| Asset                              | Source                                                     | Licensing question |
|---|---|---|
| Hermes / NousResearch primary face | What font does nousresearch.com / their docs use?           | If it's a free face (Inter, IBM Plex, etc.) → bundle freely; if it's paid (e.g. a Klim Type Foundry face) → license per app or use a free analogue |
| Hermes monospace (for the terminal) | A monospaced face that matches NousResearch's developer aesthetic | Recommend JetBrains Mono (free, OFL) or Berkeley Mono (paid but high-quality dev font) |
| Hero typeface (for "Hermes Agent" big text) | Likely the same as primary, weight semibold or display | Same as primary |

**Preferred approach:** ship with **Inter** (free, OFL, broadly used,
neutral-modern aesthetic) + **JetBrains Mono** (free, OFL, the
canonical developer terminal font). Both are bundled into the app
under their open licenses; no NousResearch entanglement.

### 1.3 Colors

The current placeholder uses `theme.resolved.accent.color` (project
generic). The canonical Hermes colors per NousResearch's published
identity (verify on nousresearch.com):

| Token                              | Placeholder today                       | Target (verify with user / nousresearch.com) |
|---|---|---|
| `hermesBrandPrimary`               | project accent (varies by theme)        | NousResearch primary (likely a deep purple / violet — verify) |
| `hermesBrandSecondary`             | none                                    | Likely a complementary deep blue or warm accent |
| `hermesBrandInk` (text on brand)   | white / system foreground               | Verify contrast on the primary |
| `hermesBrandSurface` (terminal bg) | `.regularMaterial`                      | Likely a deep dark surface tone |

**Preferred approach:** define design tokens in a single Swift file
(`HermesBrand.swift`) with placeholder values today + comments
linking to the §6 deferral list. When real values are confirmed,
swap the literals; every consuming view auto-updates.

### 1.4 Sigil / icon

The current `HermesShimmeringSigil` uses `figure.stand.dress`. The
user explicitly noted this isn't canon. The real options:

1. **Caduceus** (public domain) — the literal Hermes symbol; widely
   recognizable; renders well in SwiftUI `Canvas` from Bezier paths
2. **NousResearch sigil** if they publish one — requires permission
3. **Custom mark** — design a sigil that nods to Hermes mythology
   (winged sandal? winged caduceus?) without infringing

**Preferred approach:** caduceus rendered in SwiftUI `Canvas` with
the shimmer + halo treatment kept from `HermesShimmeringSigil` —
gives us a real Hermes-themed mark with zero licensing risk.

---

## 2. The licensing gate (must be cleared before bundling NousResearch assets)

Bundling any of the following requires explicit written permission
from NousResearch (or a confirmed fair-use justification reviewed by
counsel):

- The NousResearch wordmark
- The Hermes wordmark in NousResearch's specific typographic treatment
- Any NousResearch logo / mark
- A typeface NousResearch licenses (vs. publishes openly)

**Until permission is in writing, the placeholder discipline applies:**
every NousResearch-branded element ships behind a `HERMES-BRAND-STUB`
marker pointing to this doctrine + §6 deferral list. The app uses
mythological-Hermes assets (caduceus) + free typefaces (Inter,
JetBrains Mono) until permission unblocks the canonical NousResearch
identity.

This is a **user decision**, not an agent decision — the agent
cannot grant licensing. The user either:
1. Reaches out to NousResearch for permission, OR
2. Decides to ship with Hermes-mythology + free assets only, OR
3. Designs a fully independent visual identity inspired by but
   distinct from NousResearch

---

## 3. The design-token shape (so swapping is one file)

Every Hermes-branded surface consumes from a single file:

```swift
// Epistemos/Views/Landing/Hermes/HermesBrand.swift (NEW)

/// Single source of truth for Hermes Agent visual identity. Swap
/// these values when the canonical NousResearch brand assets are
/// confirmed (per HERMES_BRAND_DOCTRINE_2026_05_04 §6). Every
/// Hermes-branded view consumes from here — no per-view brand
/// constants.
nonisolated enum HermesBrand {
    // MARK: - Colors (HERMES-BRAND-STUB; verify against nousresearch.com)
    static let primary = Color(hex: "#7C3AED") ?? .purple   // deep violet placeholder
    static let primaryMuted = Color(hex: "#A78BFA") ?? .purple
    static let ink = Color.white
    static let surface = Color(hex: "#0F0B1F") ?? .black

    // MARK: - Typography (HERMES-BRAND-STUB; using Inter + JetBrains Mono)
    static func display(_ size: CGFloat) -> Font {
        // TODO: switch to bundled Inter Variable when font ships
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func mono(_ size: CGFloat) -> Font {
        // TODO: switch to bundled JetBrains Mono when font ships
        .system(size: size, weight: .regular, design: .monospaced)
    }
    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    // MARK: - Sigil (HERMES-BRAND-STUB; caduceus in Canvas TBD)
    static let sigilSystemImageFallback = "figure.stand.dress"  // current placeholder

    // MARK: - Wordmarks (HERMES-BRAND-STUB; awaiting licensing)
    static let agentTitle = "Hermes Agent"
    static let runtimeBadge = "powered by Hermes"  // generic until licensing
}
```

When real assets land:
- `HermesBrand.primary` → real NousResearch hex
- `HermesBrand.display(...)` → switch from `.system(...)` to
  `Font.custom("Inter-Semibold", size: ...)`
- `HermesBrand.sigilSystemImageFallback` → swap to the canvas-drawn
  caduceus or the licensed NousResearch sigil

**Every existing Hermes view migrates by replacing local constants
with `HermesBrand.*` references in one PR.**

---

## 4. The phase plan (slots into the Canonical Recovery Plan)

This work fits into the recovery plan as **Stage E.0 — Hermes Brand
Assets** (alongside Stage E Simulation Assets):

```
Stage E.0 — Hermes Brand Assets (new sub-stage)
  E.0.1  Author HermesBrand.swift design-token file with placeholder values
  E.0.2  Migrate every Hermes view to consume from HermesBrand.* (no per-view literals)
  E.0.3  Build the caduceus-in-Canvas sigil (free; ships immediately)
  E.0.4  Bundle Inter + JetBrains Mono fonts in app Resources/
  E.0.5  USER DECISION: pursue NousResearch licensing? (yes / no / design distinct)
  E.0.6  If user pursues: write permission request; gate canonical identity behind
         HERMES-BRAND-LICENSED feature flag until written permission lands
  E.0.7  Swap HermesBrand.* values when permission lands (or when alternate
         design ships)
```

Sequence relative to the rest:
- **E.0.1 + E.0.2 + E.0.3 + E.0.4** can ship at any time; no
  dependencies. Recommended: bundle with Stage A.4 (Hermes Expert
  Mode renderer migration) so the visual + structural unwinds land
  together.
- **E.0.5 + E.0.6 + E.0.7** are user-decision-gated; never agent-driven.

---

## 5. The phrase

> *"The placeholder isn't the canon; it's the deferral."*

Use this when explaining why a view ships with system colors instead
of the real Hermes brand: the canon is documented (this doctrine);
the implementation is placeholder pending licensing + design
decisions. **Do not let the placeholder calcify into "the way it
looks."**

---

## 6. The HERMES-BRAND-STUB deferral list (current)

Single source of truth for every Hermes view currently using
placeholder identity. `grep -rn 'HERMES-BRAND-STUB'` MUST return
exactly the items in this list — no more, no less.

| Surface / file                                                    | Placeholder used                            | Migration |
|---|---|---|
| `HermesShimmeringSigil.swift` — `systemImageName: "figure.stand.dress"` | SF Symbol fallback                  | E.0.3 caduceus or licensed NousResearch sigil |
| `HermesShimmeringSigil.swift` — `accent: Color(hue: 0.55, ...)`   | Generic blue accent                         | E.0.1 → `HermesBrand.primary` |
| `HermesExpertModeView.swift` — accent uses `theme.resolved.accent.color` | Project accent (varies by theme)      | E.0.2 → `HermesBrand.primary` |
| `HermesExpertModeView.swift` — `monoFont = .system(..., design: .monospaced)` | System mono                          | E.0.4 → bundled JetBrains Mono via `HermesBrand.mono(...)` |
| `LiquidGreeting.hermesHeroPhrase` — uses `AppDisplayTypography.font(size: 44)` | Project display font            | E.0.4 → `HermesBrand.display(44)` |
| `HermesExpertModeToggleChip.swift` — uses `theme.resolved.accent.color` | Project accent                          | E.0.2 → `HermesBrand.primary` |
| `HermesExpertModeView.swift` — prompt label "hermes ›"            | Generic prompt; no NousResearch wordmark    | E.0.7 if user opts for canonical identity |

When a surface migrates, REMOVE its row from this list (don't strike
through). Empty list = doctrine met.

---

## 7. Cross-references

```
docs/fusion/HERMES_BRAND_DOCTRINE_2026_05_04.md      ← this doc (canon)
docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md    (Stage E.0 sub-stage)
docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md   (T5 Hermes status)
docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md   (asset bundling counts as MAS-eligible work)
reference_nousresearch                               (memory: existing NousResearch reference patterns)
Epistemos/Views/Landing/Hermes/HermesShimmeringSigil.swift  (current placeholder sigil)
Epistemos/Views/Landing/Hermes/HermesExpertModeView.swift   (current placeholder accent + fonts)
```

The user's correction (verbatim, 2026-05-04):
> "the ui for the hermes agent all that is basically like not at
> all what i wanted it should be the actual assets and hermes agent
> font and color with the real nous research logo, etc."

This doctrine is the structured response to that correction. The
hackathon shipped placeholders; the recovery is to surface the gap
explicitly, route every Hermes view through a single brand token
file, acquire / license / design the real assets, and swap.
