# Epistemos Public Shell — Website Revamp & Interactive Tool Strategy
## Executive Summary
Your site is already aesthetically rare: a black-glass, pixel-opulence shell with a live star field, grain texture, grid overlay, and a restrained gold/sky/rose palette that signals seriousness without corporate sterility. The architecture is sound — Next.js 14 app router, file-system notes, waitlist form, a `SiteShell` wrapper that composes the entire aesthetic in one place. The goal is not to rebuild — it's to add depth, motion, and at least one genuinely useful interactive tool that makes a visitor *stay*, use something, and then see the app as the natural next step.[^1][^2][^3]

The four upgrade pillars are:
1. **Visual richness** — push the existing pixel-glass language further without adding noise
2. **Micro-interactions** — small moments that make the interface feel alive
3. **Interactive tool(s)** — one or two genuinely useful, free browser-based tools that create an "aha moment" before the download ask
4. **Smarter conversion path** — the funnel logic that connects tool → trust → app download

***
## Visual Upgrade: Still Minimal, Far More Interesting
### What You Already Have (Preserve All of It)
Your `globals.css` is sophisticated:[^4]
- Radial gradient body background with sky/gold/rose halos
- Pixel noise overlay at `opacity: 0.08` with `mix-blend-mode: soft-light`
- CSS grid overlay at `opacity: 0.12` with a fade mask
- Glass panels via `backdrop-filter: blur(18px) saturate(130%)`
- The `StarField` canvas component with shimmering, drift-offset pixels and warm gold stars[^5]
- Pixel font for badges and brand elements alongside an editorial serif for article prose[^4]

This is already the **"pixel opulence"** aesthetic trend that design publications are calling the dominant direction for 2025–2026: retro pixel elements used as *luxury texture* rather than novelty, fused with ultra-minimal layouts.[^6][^7][^8]
### Upgrade 1: Aceternity UI Dither Shader on Hero Images
Aceternity UI (which already aligns with your Next.js stack) ships a **Dither Shader** component — a real-time ordered dithering WebGL effect for images, with Bayer, Halftone, Noise, and Crosshatch modes, plus grayscale/duotone color processing. Applied to your hero or sneak-peek screenshots, this transforms flat images into moving pixel-art renders that look native to your aesthetic. The `animated` prop makes the dithering shimmer continuously — matching your existing star field motion language.[^9][^10][^11]

Drop it on the `pixel-mascot` GIFs slots or on any preview screenshots. Use `colorMode: "grayscale"` to stay monochrome, then accent with your `--gold` variable at `pixelRatio: 3` for a coarse, deliberate pixel look.
### Upgrade 2: Pixelated Canvas Mouse Distortion
Aceternity also ships a **Pixelated Canvas** component that converts any image into a pixelated canvas with mouse-distortion effects — the same technique used on the Tailwind CSS website. Placed in your hero panel alongside the current essay ribbon, this creates a tactile, interactive moment the moment a visitor moves their cursor. It takes zero content changes — just wraps existing images.[^10]
### Upgrade 3: Encrypted Text Reveal
Replace static heading renders with Aceternity's **Encrypted Text** component — a text reveal that cycles through gibberish before settling on the final string. Apply it to the `hero-title` or section eyebrows. This adds motion where there was none and reads as "the system is thinking" — perfectly on-brand for an AI cognition product like Brainiac/Epistemos.[^10]
### Upgrade 4: Canvas Reveal Effect on Feature Cards
The **Canvas Reveal Effect** (also Aceternity) creates expanding dot patterns on hover — seen on Clerk's website. Apply to your `.info-card` elements in the "Route Structure" three-up section. Hover → dots bloom from center → the card feels like a live surface. No layout changes required.[^10]
### Upgrade 5: Shooting Stars Addition
Your current `StarField` is static-shimmer. Add Aceternity's **Shooting Stars and Stars Background** component alongside it (it composes as a second canvas layer). One or two rare shooting stars every 8–12 seconds is the right density — noticeable but never distracting. This costs ~20 lines of code and makes first impressions dramatically more cinematic.[^10]
### Typography Upgrade: Maximalist Headline Contrast
2025 design trends specifically call out "minimalism meets maximalist flourish" — clean layouts with **statement typography**. Your `hero-title` is already large (`clamp(3.2rem, 7vw, 6rem)`) but consider:[^6]
- Adding a second editorial-serif line in italic at ~1.2× the current size with negative letter-spacing at `−0.08em`
- Using the **Colourful Text** component from Aceternity to cycle your `--gold`, `--sky`, `--rose` variables through the accent word — one color-animated word in an otherwise monochrome headline reads as intentional, not chaotic

***
## Interactive Tool Strategy: The App Funnel
The most proven web-to-app conversion mechanic studied across apps like Photoroom, Calm, Blinkist, and PlantIn follows one pattern: **give away real value with zero friction, then show the app as the expansion of that value**.[^12]

Photoroom lets users remove backgrounds on the web for free with no account — the "aha moment" happens before any commitment, and then the app appears as the natural "more of this". Calm runs a quiz that personalizes before asking for the download. The principle is the same: **the tool earns trust; the download ask benefits from that trust**.[^13][^12]

Interactive content can generate 30–40% higher conversion rates than static landing pages when properly integrated into the funnel. Micro-actions that build progressive commitment ("foot in the door" technique) guide visitors toward the macro-conversion — the download — without feeling coercive.[^14][^13]
### Tool Idea 1: The Clarity Score (Best Fit for Epistemos)
**What it is:** A browser-based prose clarity analyzer. User pastes a paragraph or short essay. The tool returns:
- Flesch-Kincaid reading grade level
- Average sentence length
- Passive voice ratio
- A "fog index" difficulty score
- One-line verdict: e.g., *"Clear enough for a general audience"* or *"Dense — tighten for wider reach"*

**Why it fits:** Your site publishes essays and tech-logic posts. Your app (Brainiac/Epistemos) is explicitly a cognition and research tool. A prose clarity checker is *exactly what a thinking/writing tool would offer* — it's a preview of the product's intellectual identity, not a random feature bolted on. Users who write essays and want feedback are precisely your target early adopters.

**Implementation:** Pure client-side TypeScript. Use `textstat` (JS port) or write a small Flesch-Kincaid function directly (it's a two-formula calculation over syllable count and sentence count — no API needed). Render results as pixel-badge styled score cards matching your `.signal-card` CSS class. Add a line at the bottom: *"Epistemos goes deeper → [Join Waitlist]"*

**Technical path in your stack:** Add a `/tools/clarity` route. Server-render the form, client-side hydrate the results panel. Uses zero API costs. Entire tool is ~120 lines of TypeScript.
### Tool Idea 2: The Pixel Dither Lab (Aesthetic Lure)
**What it is:** An in-browser image dithering tool. Upload any image → choose from Floyd-Steinberg, Bayer 4×4, or Atkinson dithering → download a black-and-white pixel-art version. The JS library `image-to-pixel.js` handles the entire pipeline with support for all major algorithms.[^15]

**Why it fits:** Your aesthetic *is* pixel dithering. Visitors who find this tool via search ("online image dithering tool" gets consistent search volume) land inside your branded shell, interact with your visual language, and discover Epistemos in context. It's a viral loop: they share the dithered image → others see the style → they visit your site.

**Implementation:** Client-side `anvas>` element + `image-to-pixel.js`. The Aceternity Dither Shader handles WebGL previews for live dithering on the page hero. Downloadable output is processed on the canvas client-side. Zero backend required.[^11][^15]

**Conversion hook:** After download, show: *"Built with the same pixel philosophy as Epistemos — a cognitive environment that thinks clearly so you don't have to → [See Sneak Peek]"*
### Tool Idea 3: The Reading Time + Density Estimator (Lightweight)
**What it is:** Paste an essay or note → get reading time, unique word ratio (lexical density), most-used unique words, and a "depth score." Lexical density is a real linguistic metric (content words ÷ total words × 100).[^16]

**Why it fits:** Your `notes.ts` already computes reading time (`Math.round(words / 220)`). Surfacing a richer version of this as a public tool mirrors what your app does internally — it makes the product philosophy visible and usable before the download ask.[^17]

***
## Recommended Tool Priority
| Tool | Fit with Brand | Technical Cost | SEO / Discovery | Conversion Clarity |
|------|---------------|----------------|-----------------|-------------------|
| Clarity Score | ⭐⭐⭐⭐⭐ | Low (pure TS) | Medium | Very high — direct tie to app |
| Pixel Dither Lab | ⭐⭐⭐⭐⭐ | Low (canvas JS) | High (niche search) | High — aesthetic demo |
| Reading Density | ⭐⭐⭐⭐ | Very low | Low | High for your audience |

**Build the Clarity Score first.** It directly demonstrates Brainiac's cognitive identity. Build the Pixel Dither Lab second — it will surface your site to new audiences outside your existing circle and is deeply aligned with your visual language.[^15][^18]

***
## Notes Page: The Center of Gravity
Your own `weekly-build-dispatch-001.md` makes the strategic point clearly: "The strongest move is to make the public notes room the center of gravity" and "The waitlist works better when it is downstream of trust. Trust comes from visible thinking." The tool strategy reinforces this — users who use the Clarity Score are already demonstrating a writing-and-thinking orientation. They are your audience.[^19]

**Specific notes improvements:**

- **Tag filter sidebar:** Your sidebar already has `.tag-row` elements. Add client-side tag filtering to the notes list so users can select "System Essay" or "Logic Breakdown" and see only relevant notes. This is ~40 lines of React state.[^4]
- **Reading progress indicator:** A thin 1px `--gold` line at the top of the viewport that fills as the user scrolls through an article. Purely CSS + a `scroll` listener. No libraries needed.
- **Estimated depth badge:** Surface your `readingTime` next to a custom "depth" badge (short/deep/dense) derived from lexical density — using the same computation as Tool 3 above. Makes notes feel curated rather than just posted.

***
## Conversion Path Redesign
The current path is: `Hero → Waitlist`. The upgraded path should be:

```
Hero (cinematic, dither shader on preview image)
  ↓
Tool (Clarity Score or Pixel Dither Lab) — "try this for free"
  ↓
Notes (essay room — visible thinking builds trust)
  ↓
Sneak Peek (controlled preview of Brainiac interface)
  ↓
Waitlist (now earned, not cold-asked)
```

This mirrors the exact funnel structure that Blinkist and Photoroom use: content and tool first, commitment ask after the value has been demonstrated. The key insight from conversion research is **psychological momentum** — visitors who take small actions (using the tool, reading a note) are substantially more likely to complete the macro-conversion (joining the waitlist, downloading the app).[^13][^12]

**Navigation change:** Add `/tools` to the top nav between `Notes` and `Sneak Peek`. The `.nav-link` CSS already handles active states perfectly.[^20]

***
## Implementation Checklist
### Visual (No layout changes)
- [ ] Install Aceternity UI (`npx shadcn@latest add "https://ui.aceternity.com/r/dither-shader"`)
- [ ] Wrap sneak-peek preview images in `DitherShader` component with `colorMode="grayscale"` and `animated={true}`
- [ ] Add `EncryptedText` to `hero-title` eyebrow or first heading word
- [ ] Layer `ShootingStars` alongside existing `StarField` in `site-shell.tsx`
- [ ] Apply `CanvasRevealEffect` to `.info-card` hover states in the three-up section
### Tool: Clarity Score (`/tools/clarity`)
- [ ] Create `app/tools/clarity/page.tsx` — server component wrapper
- [ ] Create `components/clarity-tool.tsx` — client component with textarea + results
- [ ] Implement Flesch-Kincaid Grade Level formula client-side (syllable counting function + sentence split)
- [ ] Style results using existing `.signal-card` and `.pixel-badge` CSS classes
- [ ] Add "Epistemos goes deeper" CTA linking to `/waitlist`
### Tool: Pixel Dither Lab (`/tools/dither`)
- [ ] Add `image-to-pixel.js` to public or install via npm
- [ ] Create `app/tools/dither/page.tsx`
- [ ] Create `components/dither-tool.tsx` — drag-and-drop image input, canvas output, download button
- [ ] Offer three palette options: Full Black & White, Warm (gold tones), Cool (sky tones) — matching CSS vars
- [ ] Add sharing hook: "Share this look → made with Epistemos"
### Notes Enhancements
- [ ] Add client-side tag filtering to `/notes` sidebar
- [ ] Implement reading progress bar using `scroll` event on article layout
- [ ] Surface `lexicalDensity` as a depth badge alongside `readingTime` in `notes.ts`
### Nav + Funnel
- [ ] Add `/tools` nav item to `top-nav.tsx` navItems array
- [ ] Add "Try a Tool" secondary CTA to hero actions alongside existing "Join Waitlist" and "Browse Notes"

***
## What to Avoid
- **Do not add more sections to the homepage.** The current structure (hero → route structure → latest notes → waitlist) is correctly minimal. The tools live on their own routes, not as homepage sections.
- **Do not add color.** Your palette is a deliberate design identity. The black/white pixel aesthetic with gold accents is literally trending as "pixel opulence" and "retro luxury texture" in 2025–2026 design. Do not dilute it.[^6][^7][^8]
- **Do not add testimonials or feature bullet lists.** That would contradict your own `public-shell-origin.md` principle: "the website should not look like marketing pasted on top of a serious product".[^2]
- **Do not gate the tools.** Zero friction before the aha moment is the entire point of the Photoroom/Blinkist model. No email required to use the Clarity Score or Dither Lab. The waitlist ask appears *after* they've used the tool and seen the product identity.[^12]

---

## References

1. [site-shell.tsx](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/67909917-cc8a-4ed0-ae2a-a6dfc9dd4013/site-shell.tsx?AWSAccessKeyId=ASIA2F3EMEYEYUTNXOMY&Signature=NeV%2BthUTqSkYi6JYTNGXBJNnblk%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEE8aCXVzLWVhc3QtMSJHMEUCIGdo8zHSoqDkInw58%2FZw4%2BsRnte8kECCXHsngs0klWS0AiEA1Nqv8H4ehX9YFlIUHv3gCMRPkZohuM2kbYQrOoKhwhwq8wQIFxABGgw2OTk3NTMzMDk3MDUiDIut50RjOk%2FSPRSsmirQBAKWpWKsWAVNZVC%2B6s4Ob%2FT6xVu40Kr%2BbxkfH3km4x50FuWkQtf%2BoFPvhHe59R0pBvy5XmLFlAdNIfUnJDABYqV5GijBn9KxnmA8aY6%2BFXfUZ8qQeJ4ZAQDjTkuAHzgcy08%2FTknqjp0iEohH5KjJ%2BAOS9jb7LWvxoXtaIsS3YEDSej0XWEuQwdrPQl72G%2BqIIskpt2EsY8Z7kY5v1843AG9bbGXQDuPcqsd5HiYTcNn%2BvKaF7yhVLPulBuXzIokWqMX12TZcb4bqw2wOqJTx96joDSuxgM0K8CM8I0hCo%2FreLJ5dGHw1zCzqs0ecbZ%2B3bBeSW0DF43p0xwvXjX7c163mDoKfHuYGu7wLlln04ameO4VwzGsDZxN1Jt97EeGr9ofM%2FVDpONKkV%2FgwfJx8hq3j6JbxARIlhqena497ZCUAoZJPcW1eibsEanLHIV%2FEPnBgv8u58WdHqDEDNC1G%2B5kwPg7x3uUbQg3ivhxnwsTFJJo9XFGs1s%2BzivufFcdGn%2BOX2nppv5aemy80y%2Fz7i6sg0GVBS9FJenDy0QdpVGj4ht1%2FBxnVkVvrgckGUIlQ2yX%2BtIqGxlsjC7bf%2F4YQsEl31FEo9PK6JSa2%2Fv8Q1gQzexpJpvmr0q3eud2aAcwbbEjnnQ0Ps9HTBMGlTv9uH85HEXsE4oWGLYaeFUR7PoWCjifm7Faq0ozc8jNazYbAWCDT5lGsbBCXTOkFzCS5kXW0SOPs6S1zUL3JxIp%2FVhE7KySGOmjkwfoDBMkxNxvGqrqh9ux16aVGSmRMh8muZkYw4cmmzgY6mAE0tnsYZkm1ghyIAprAThkfEXfc%2BNfPXUKHkZYlBmsPE%2BHpdxeMcV1u6GwUQvFpG3rz2mL2dt%2FrsyFmh%2BdhwugOl1JaLAEWYLzHpQJvIAfU4mSfxVTQyavCgUD2LZjn71Ez6%2BjxKLIfjBRTe8mmSBvAtBs381K4omoszyAXvnukUAedD0PjGpugfT0M%2Fw9eo9MkiS7OgANsFA%3D%3D&Expires=1774826164) - import TopNav from componentstop-nav import StarField from componentsstar-field export function Site...

2. [public-shell-origin.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/8e7ca236-6bb1-48cb-819c-2436e15b0498/public-shell-origin.md?AWSAccessKeyId=ASIA2F3EMEYEYUTNXOMY&Signature=owY2hZYzjJSn76oS6BCgs5TgUsk%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEE8aCXVzLWVhc3QtMSJHMEUCIGdo8zHSoqDkInw58%2FZw4%2BsRnte8kECCXHsngs0klWS0AiEA1Nqv8H4ehX9YFlIUHv3gCMRPkZohuM2kbYQrOoKhwhwq8wQIFxABGgw2OTk3NTMzMDk3MDUiDIut50RjOk%2FSPRSsmirQBAKWpWKsWAVNZVC%2B6s4Ob%2FT6xVu40Kr%2BbxkfH3km4x50FuWkQtf%2BoFPvhHe59R0pBvy5XmLFlAdNIfUnJDABYqV5GijBn9KxnmA8aY6%2BFXfUZ8qQeJ4ZAQDjTkuAHzgcy08%2FTknqjp0iEohH5KjJ%2BAOS9jb7LWvxoXtaIsS3YEDSej0XWEuQwdrPQl72G%2BqIIskpt2EsY8Z7kY5v1843AG9bbGXQDuPcqsd5HiYTcNn%2BvKaF7yhVLPulBuXzIokWqMX12TZcb4bqw2wOqJTx96joDSuxgM0K8CM8I0hCo%2FreLJ5dGHw1zCzqs0ecbZ%2B3bBeSW0DF43p0xwvXjX7c163mDoKfHuYGu7wLlln04ameO4VwzGsDZxN1Jt97EeGr9ofM%2FVDpONKkV%2FgwfJx8hq3j6JbxARIlhqena497ZCUAoZJPcW1eibsEanLHIV%2FEPnBgv8u58WdHqDEDNC1G%2B5kwPg7x3uUbQg3ivhxnwsTFJJo9XFGs1s%2BzivufFcdGn%2BOX2nppv5aemy80y%2Fz7i6sg0GVBS9FJenDy0QdpVGj4ht1%2FBxnVkVvrgckGUIlQ2yX%2BtIqGxlsjC7bf%2F4YQsEl31FEo9PK6JSa2%2Fv8Q1gQzexpJpvmr0q3eud2aAcwbbEjnnQ0Ps9HTBMGlTv9uH85HEXsE4oWGLYaeFUR7PoWCjifm7Faq0ozc8jNazYbAWCDT5lGsbBCXTOkFzCS5kXW0SOPs6S1zUL3JxIp%2FVhE7KySGOmjkwfoDBMkxNxvGqrqh9ux16aVGSmRMh8muZkYw4cmmzgY6mAE0tnsYZkm1ghyIAprAThkfEXfc%2BNfPXUKHkZYlBmsPE%2BHpdxeMcV1u6GwUQvFpG3rz2mL2dt%2FrsyFmh%2BdhwugOl1JaLAEWYLzHpQJvIAfU4mSfxVTQyavCgUD2LZjn71Ez6%2BjxKLIfjBRTe8mmSBvAtBs381K4omoszyAXvnukUAedD0PjGpugfT0M%2Fw9eo9MkiS7OgANsFA%3D%3D&Expires=1774826164) - --- title Public Shell Origin summary Why the public website should feel like a distilled Brainiac s...

3. [research-mode-public-boundary.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/b0b31f42-b264-411e-888c-8a576cc466c7/research-mode-public-boundary.md?AWSAccessKeyId=ASIA2F3EMEYEYUTNXOMY&Signature=lBAM%2B5WpKaQ4S7rmriPKezQApHQ%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEE8aCXVzLWVhc3QtMSJHMEUCIGdo8zHSoqDkInw58%2FZw4%2BsRnte8kECCXHsngs0klWS0AiEA1Nqv8H4ehX9YFlIUHv3gCMRPkZohuM2kbYQrOoKhwhwq8wQIFxABGgw2OTk3NTMzMDk3MDUiDIut50RjOk%2FSPRSsmirQBAKWpWKsWAVNZVC%2B6s4Ob%2FT6xVu40Kr%2BbxkfH3km4x50FuWkQtf%2BoFPvhHe59R0pBvy5XmLFlAdNIfUnJDABYqV5GijBn9KxnmA8aY6%2BFXfUZ8qQeJ4ZAQDjTkuAHzgcy08%2FTknqjp0iEohH5KjJ%2BAOS9jb7LWvxoXtaIsS3YEDSej0XWEuQwdrPQl72G%2BqIIskpt2EsY8Z7kY5v1843AG9bbGXQDuPcqsd5HiYTcNn%2BvKaF7yhVLPulBuXzIokWqMX12TZcb4bqw2wOqJTx96joDSuxgM0K8CM8I0hCo%2FreLJ5dGHw1zCzqs0ecbZ%2B3bBeSW0DF43p0xwvXjX7c163mDoKfHuYGu7wLlln04ameO4VwzGsDZxN1Jt97EeGr9ofM%2FVDpONKkV%2FgwfJx8hq3j6JbxARIlhqena497ZCUAoZJPcW1eibsEanLHIV%2FEPnBgv8u58WdHqDEDNC1G%2B5kwPg7x3uUbQg3ivhxnwsTFJJo9XFGs1s%2BzivufFcdGn%2BOX2nppv5aemy80y%2Fz7i6sg0GVBS9FJenDy0QdpVGj4ht1%2FBxnVkVvrgckGUIlQ2yX%2BtIqGxlsjC7bf%2F4YQsEl31FEo9PK6JSa2%2Fv8Q1gQzexpJpvmr0q3eud2aAcwbbEjnnQ0Ps9HTBMGlTv9uH85HEXsE4oWGLYaeFUR7PoWCjifm7Faq0ozc8jNazYbAWCDT5lGsbBCXTOkFzCS5kXW0SOPs6S1zUL3JxIp%2FVhE7KySGOmjkwfoDBMkxNxvGqrqh9ux16aVGSmRMh8muZkYw4cmmzgY6mAE0tnsYZkm1ghyIAprAThkfEXfc%2BNfPXUKHkZYlBmsPE%2BHpdxeMcV1u6GwUQvFpG3rz2mL2dt%2FrsyFmh%2BdhwugOl1JaLAEWYLzHpQJvIAfU4mSfxVTQyavCgUD2LZjn71Ez6%2BjxKLIfjBRTe8mmSBvAtBs381K4omoszyAXvnukUAedD0PjGpugfT0M%2Fw9eo9MkiS7OgANsFA%3D%3D&Expires=1774826164) - --- title Research Mode Public Boundary summary A note about what to expose from the web app and wha...

4. [globals.css](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/24f011cb-e093-46de-85d8-16aa22d741e6/globals.css?AWSAccessKeyId=ASIA2F3EMEYEYUTNXOMY&Signature=2PKx2SffTlZAsJ3z4gkh8%2FBqMkQ%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEE8aCXVzLWVhc3QtMSJHMEUCIGdo8zHSoqDkInw58%2FZw4%2BsRnte8kECCXHsngs0klWS0AiEA1Nqv8H4ehX9YFlIUHv3gCMRPkZohuM2kbYQrOoKhwhwq8wQIFxABGgw2OTk3NTMzMDk3MDUiDIut50RjOk%2FSPRSsmirQBAKWpWKsWAVNZVC%2B6s4Ob%2FT6xVu40Kr%2BbxkfH3km4x50FuWkQtf%2BoFPvhHe59R0pBvy5XmLFlAdNIfUnJDABYqV5GijBn9KxnmA8aY6%2BFXfUZ8qQeJ4ZAQDjTkuAHzgcy08%2FTknqjp0iEohH5KjJ%2BAOS9jb7LWvxoXtaIsS3YEDSej0XWEuQwdrPQl72G%2BqIIskpt2EsY8Z7kY5v1843AG9bbGXQDuPcqsd5HiYTcNn%2BvKaF7yhVLPulBuXzIokWqMX12TZcb4bqw2wOqJTx96joDSuxgM0K8CM8I0hCo%2FreLJ5dGHw1zCzqs0ecbZ%2B3bBeSW0DF43p0xwvXjX7c163mDoKfHuYGu7wLlln04ameO4VwzGsDZxN1Jt97EeGr9ofM%2FVDpONKkV%2FgwfJx8hq3j6JbxARIlhqena497ZCUAoZJPcW1eibsEanLHIV%2FEPnBgv8u58WdHqDEDNC1G%2B5kwPg7x3uUbQg3ivhxnwsTFJJo9XFGs1s%2BzivufFcdGn%2BOX2nppv5aemy80y%2Fz7i6sg0GVBS9FJenDy0QdpVGj4ht1%2FBxnVkVvrgckGUIlQ2yX%2BtIqGxlsjC7bf%2F4YQsEl31FEo9PK6JSa2%2Fv8Q1gQzexpJpvmr0q3eud2aAcwbbEjnnQ0Ps9HTBMGlTv9uH85HEXsE4oWGLYaeFUR7PoWCjifm7Faq0ozc8jNazYbAWCDT5lGsbBCXTOkFzCS5kXW0SOPs6S1zUL3JxIp%2FVhE7KySGOmjkwfoDBMkxNxvGqrqh9ux16aVGSmRMh8muZkYw4cmmzgY6mAE0tnsYZkm1ghyIAprAThkfEXfc%2BNfPXUKHkZYlBmsPE%2BHpdxeMcV1u6GwUQvFpG3rz2mL2dt%2FrsyFmh%2BdhwugOl1JaLAEWYLzHpQJvIAfU4mSfxVTQyavCgUD2LZjn71Ez6%2BjxKLIfjBRTe8mmSBvAtBs381K4omoszyAXvnukUAedD0PjGpugfT0M%2Fw9eo9MkiS7OgANsFA%3D%3D&Expires=1774826164) - root --bg-0 0f0f12 --bg-1 17151b --bg-2 231d1d --panel rgba25, 24, 31, 0.72 --panel-strong rgba18, 1...

5. [star-field.tsx](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/63bcbc1e-dad9-4ca5-96e1-3fb1da93cc55/star-field.tsx?AWSAccessKeyId=ASIA2F3EMEYEYUTNXOMY&Signature=kZU7weHtHBK%2FY65oCAtCi4gc1JM%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEE8aCXVzLWVhc3QtMSJHMEUCIGdo8zHSoqDkInw58%2FZw4%2BsRnte8kECCXHsngs0klWS0AiEA1Nqv8H4ehX9YFlIUHv3gCMRPkZohuM2kbYQrOoKhwhwq8wQIFxABGgw2OTk3NTMzMDk3MDUiDIut50RjOk%2FSPRSsmirQBAKWpWKsWAVNZVC%2B6s4Ob%2FT6xVu40Kr%2BbxkfH3km4x50FuWkQtf%2BoFPvhHe59R0pBvy5XmLFlAdNIfUnJDABYqV5GijBn9KxnmA8aY6%2BFXfUZ8qQeJ4ZAQDjTkuAHzgcy08%2FTknqjp0iEohH5KjJ%2BAOS9jb7LWvxoXtaIsS3YEDSej0XWEuQwdrPQl72G%2BqIIskpt2EsY8Z7kY5v1843AG9bbGXQDuPcqsd5HiYTcNn%2BvKaF7yhVLPulBuXzIokWqMX12TZcb4bqw2wOqJTx96joDSuxgM0K8CM8I0hCo%2FreLJ5dGHw1zCzqs0ecbZ%2B3bBeSW0DF43p0xwvXjX7c163mDoKfHuYGu7wLlln04ameO4VwzGsDZxN1Jt97EeGr9ofM%2FVDpONKkV%2FgwfJx8hq3j6JbxARIlhqena497ZCUAoZJPcW1eibsEanLHIV%2FEPnBgv8u58WdHqDEDNC1G%2B5kwPg7x3uUbQg3ivhxnwsTFJJo9XFGs1s%2BzivufFcdGn%2BOX2nppv5aemy80y%2Fz7i6sg0GVBS9FJenDy0QdpVGj4ht1%2FBxnVkVvrgckGUIlQ2yX%2BtIqGxlsjC7bf%2F4YQsEl31FEo9PK6JSa2%2Fv8Q1gQzexpJpvmr0q3eud2aAcwbbEjnnQ0Ps9HTBMGlTv9uH85HEXsE4oWGLYaeFUR7PoWCjifm7Faq0ozc8jNazYbAWCDT5lGsbBCXTOkFzCS5kXW0SOPs6S1zUL3JxIp%2FVhE7KySGOmjkwfoDBMkxNxvGqrqh9ux16aVGSmRMh8muZkYw4cmmzgY6mAE0tnsYZkm1ghyIAprAThkfEXfc%2BNfPXUKHkZYlBmsPE%2BHpdxeMcV1u6GwUQvFpG3rz2mL2dt%2FrsyFmh%2BdhwugOl1JaLAEWYLzHpQJvIAfU4mSfxVTQyavCgUD2LZjn71Ez6%2BjxKLIfjBRTe8mmSBvAtBs381K4omoszyAXvnukUAedD0PjGpugfT0M%2Fw9eo9MkiS7OgANsFA%3D%3D&Expires=1774826164) - use client import useEffect, useRef from react type Star x number y number radius number alpha numbe...

6. [7 design trends to look out for in 2025 - Threerooms](https://www.threerooms.com/blog/7-design-trends-to-look-out-for-in-2025) - Clean, minimalist layouts will be enhanced with unexpected bursts of maximalist details – think brig...

7. [11 Top Graphic Design Trends For 2025 - Stymix](https://www.stymix.com/blog/top-graphic-design-trends-2025) - Join us in exploring some of the top graphic design trends for 2025. Minimalism; 3D Design; Retro Pi...

8. [Graphic Design Trend Predictions 2025 - Studio 2am](https://studio2am.co/blogs/news/our-trend-predictions-for-2025) - In 2025, we predict pixel art will continue to evolve, blending with other styles to create a hybrid...

9. [Dither Shader | Aceternity UI Components](https://ui.aceternity.com/components/dither-shader) - A real-time ordered dithering effect for images, perfect for pixel art and retro aesthetics.

10. [Free React & Next.js Components | Aceternity UI](https://ui.aceternity.com/components) - 200+ free, copy-paste components for React and Next.js. Animated cards, hero sections, backgrounds, ...

11. [Template Preview - Aceternity UI](https://ui.aceternity.com/live-preview/dither-shader-interactive) - Bayer, Halftone, Noise, Crosshatch. Colors. Grayscale, Original, Duotone. Size: 3px. Threshold: 0.50...

12. [5 web-to-app funnel examples that actually convert - RevenueCat](https://www.revenuecat.com/blog/growth/web-to-app-funnel-examples/) - Real web-to-app funnel examples from Calm, Blinkist, YNAB, PlantIn, and Photoroom, showing how quizz...

13. [The Complete Guide to Conversion-Focused Website Design in 2025](https://buildwithkinetic.org/blog/conversion-focused-website-design-guide) - Learn the exact frameworks, principles, and techniques that turn ordinary websites into lead generat...

14. [5 Must-have Conversion Rate Optimization Tools in 2025](https://www.seodiscovery.com/blog/conversion-rate-optimization-tools/) - Let's check 5 Must-have Conversion Rate Optimization Tools You Should Try in 2025. for conversion ra...

15. [Convert Images to Pixel Art with JS Dithering & Custom Palettes](https://www.cssscript.com/image-to-pixel-art/) - Image-to-Pixel is a JavaScript-powered online editor that converts regular images into retro-style p...

16. [TextDescriptives: A Python package for calculating a large variety of metrics from text](https://joss.theoj.org/papers/10.21105/joss.05153.pdf) - TextDescriptives is a Python package for calculating a large variety of metrics from text. It is bui...

17. [notes.ts](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/852da264-6136-4da3-af75-8fd5f0d1f232/notes.ts?AWSAccessKeyId=ASIA2F3EMEYEYUTNXOMY&Signature=pYfeVmh8MsU5YGTM0ntRqDVx9g8%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEE8aCXVzLWVhc3QtMSJHMEUCIGdo8zHSoqDkInw58%2FZw4%2BsRnte8kECCXHsngs0klWS0AiEA1Nqv8H4ehX9YFlIUHv3gCMRPkZohuM2kbYQrOoKhwhwq8wQIFxABGgw2OTk3NTMzMDk3MDUiDIut50RjOk%2FSPRSsmirQBAKWpWKsWAVNZVC%2B6s4Ob%2FT6xVu40Kr%2BbxkfH3km4x50FuWkQtf%2BoFPvhHe59R0pBvy5XmLFlAdNIfUnJDABYqV5GijBn9KxnmA8aY6%2BFXfUZ8qQeJ4ZAQDjTkuAHzgcy08%2FTknqjp0iEohH5KjJ%2BAOS9jb7LWvxoXtaIsS3YEDSej0XWEuQwdrPQl72G%2BqIIskpt2EsY8Z7kY5v1843AG9bbGXQDuPcqsd5HiYTcNn%2BvKaF7yhVLPulBuXzIokWqMX12TZcb4bqw2wOqJTx96joDSuxgM0K8CM8I0hCo%2FreLJ5dGHw1zCzqs0ecbZ%2B3bBeSW0DF43p0xwvXjX7c163mDoKfHuYGu7wLlln04ameO4VwzGsDZxN1Jt97EeGr9ofM%2FVDpONKkV%2FgwfJx8hq3j6JbxARIlhqena497ZCUAoZJPcW1eibsEanLHIV%2FEPnBgv8u58WdHqDEDNC1G%2B5kwPg7x3uUbQg3ivhxnwsTFJJo9XFGs1s%2BzivufFcdGn%2BOX2nppv5aemy80y%2Fz7i6sg0GVBS9FJenDy0QdpVGj4ht1%2FBxnVkVvrgckGUIlQ2yX%2BtIqGxlsjC7bf%2F4YQsEl31FEo9PK6JSa2%2Fv8Q1gQzexpJpvmr0q3eud2aAcwbbEjnnQ0Ps9HTBMGlTv9uH85HEXsE4oWGLYaeFUR7PoWCjifm7Faq0ozc8jNazYbAWCDT5lGsbBCXTOkFzCS5kXW0SOPs6S1zUL3JxIp%2FVhE7KySGOmjkwfoDBMkxNxvGqrqh9ux16aVGSmRMh8muZkYw4cmmzgY6mAE0tnsYZkm1ghyIAprAThkfEXfc%2BNfPXUKHkZYlBmsPE%2BHpdxeMcV1u6GwUQvFpG3rz2mL2dt%2FrsyFmh%2BdhwugOl1JaLAEWYLzHpQJvIAfU4mSfxVTQyavCgUD2LZjn71Ez6%2BjxKLIfjBRTe8mmSBvAtBs381K4omoszyAXvnukUAedD0PjGpugfT0M%2Fw9eo9MkiS7OgANsFA%3D%3D&Expires=1774826164) - import server-only import fs from nodefs import path from nodepath import matter from gray-matter ex...

18. [Dither Effect - Free Online Tool - Vayce](https://vayce.app/tools/dither-effect/) - Adjust strength, pick any color, and fine-tune each image — all client-side and privacy-first. Launc...

19. [weekly-build-dispatch-001.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/16042942-336c-4a5c-9681-109690d51fd1/weekly-build-dispatch-001.md?AWSAccessKeyId=ASIA2F3EMEYEYUTNXOMY&Signature=AbOnXcFw1OS7FYfhmlXKDKszXcU%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEE8aCXVzLWVhc3QtMSJHMEUCIGdo8zHSoqDkInw58%2FZw4%2BsRnte8kECCXHsngs0klWS0AiEA1Nqv8H4ehX9YFlIUHv3gCMRPkZohuM2kbYQrOoKhwhwq8wQIFxABGgw2OTk3NTMzMDk3MDUiDIut50RjOk%2FSPRSsmirQBAKWpWKsWAVNZVC%2B6s4Ob%2FT6xVu40Kr%2BbxkfH3km4x50FuWkQtf%2BoFPvhHe59R0pBvy5XmLFlAdNIfUnJDABYqV5GijBn9KxnmA8aY6%2BFXfUZ8qQeJ4ZAQDjTkuAHzgcy08%2FTknqjp0iEohH5KjJ%2BAOS9jb7LWvxoXtaIsS3YEDSej0XWEuQwdrPQl72G%2BqIIskpt2EsY8Z7kY5v1843AG9bbGXQDuPcqsd5HiYTcNn%2BvKaF7yhVLPulBuXzIokWqMX12TZcb4bqw2wOqJTx96joDSuxgM0K8CM8I0hCo%2FreLJ5dGHw1zCzqs0ecbZ%2B3bBeSW0DF43p0xwvXjX7c163mDoKfHuYGu7wLlln04ameO4VwzGsDZxN1Jt97EeGr9ofM%2FVDpONKkV%2FgwfJx8hq3j6JbxARIlhqena497ZCUAoZJPcW1eibsEanLHIV%2FEPnBgv8u58WdHqDEDNC1G%2B5kwPg7x3uUbQg3ivhxnwsTFJJo9XFGs1s%2BzivufFcdGn%2BOX2nppv5aemy80y%2Fz7i6sg0GVBS9FJenDy0QdpVGj4ht1%2FBxnVkVvrgckGUIlQ2yX%2BtIqGxlsjC7bf%2F4YQsEl31FEo9PK6JSa2%2Fv8Q1gQzexpJpvmr0q3eud2aAcwbbEjnnQ0Ps9HTBMGlTv9uH85HEXsE4oWGLYaeFUR7PoWCjifm7Faq0ozc8jNazYbAWCDT5lGsbBCXTOkFzCS5kXW0SOPs6S1zUL3JxIp%2FVhE7KySGOmjkwfoDBMkxNxvGqrqh9ux16aVGSmRMh8muZkYw4cmmzgY6mAE0tnsYZkm1ghyIAprAThkfEXfc%2BNfPXUKHkZYlBmsPE%2BHpdxeMcV1u6GwUQvFpG3rz2mL2dt%2FrsyFmh%2BdhwugOl1JaLAEWYLzHpQJvIAfU4mSfxVTQyavCgUD2LZjn71Ez6%2BjxKLIfjBRTe8mmSBvAtBs381K4omoszyAXvnukUAedD0PjGpugfT0M%2Fw9eo9MkiS7OgANsFA%3D%3D&Expires=1774826164) - --- title Weekly Build Dispatch 001 summary The first dispatch in the public shell prototype what ge...

20. [top-nav.tsx](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/5aac534a-ba1f-4aaa-a235-64ebc05a9d5c/top-nav.tsx?AWSAccessKeyId=ASIA2F3EMEYEYUTNXOMY&Signature=o9osM8uVCIA86YWX4ZlKxXOmfxo%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEE8aCXVzLWVhc3QtMSJHMEUCIGdo8zHSoqDkInw58%2FZw4%2BsRnte8kECCXHsngs0klWS0AiEA1Nqv8H4ehX9YFlIUHv3gCMRPkZohuM2kbYQrOoKhwhwq8wQIFxABGgw2OTk3NTMzMDk3MDUiDIut50RjOk%2FSPRSsmirQBAKWpWKsWAVNZVC%2B6s4Ob%2FT6xVu40Kr%2BbxkfH3km4x50FuWkQtf%2BoFPvhHe59R0pBvy5XmLFlAdNIfUnJDABYqV5GijBn9KxnmA8aY6%2BFXfUZ8qQeJ4ZAQDjTkuAHzgcy08%2FTknqjp0iEohH5KjJ%2BAOS9jb7LWvxoXtaIsS3YEDSej0XWEuQwdrPQl72G%2BqIIskpt2EsY8Z7kY5v1843AG9bbGXQDuPcqsd5HiYTcNn%2BvKaF7yhVLPulBuXzIokWqMX12TZcb4bqw2wOqJTx96joDSuxgM0K8CM8I0hCo%2FreLJ5dGHw1zCzqs0ecbZ%2B3bBeSW0DF43p0xwvXjX7c163mDoKfHuYGu7wLlln04ameO4VwzGsDZxN1Jt97EeGr9ofM%2FVDpONKkV%2FgwfJx8hq3j6JbxARIlhqena497ZCUAoZJPcW1eibsEanLHIV%2FEPnBgv8u58WdHqDEDNC1G%2B5kwPg7x3uUbQg3ivhxnwsTFJJo9XFGs1s%2BzivufFcdGn%2BOX2nppv5aemy80y%2Fz7i6sg0GVBS9FJenDy0QdpVGj4ht1%2FBxnVkVvrgckGUIlQ2yX%2BtIqGxlsjC7bf%2F4YQsEl31FEo9PK6JSa2%2Fv8Q1gQzexpJpvmr0q3eud2aAcwbbEjnnQ0Ps9HTBMGlTv9uH85HEXsE4oWGLYaeFUR7PoWCjifm7Faq0ozc8jNazYbAWCDT5lGsbBCXTOkFzCS5kXW0SOPs6S1zUL3JxIp%2FVhE7KySGOmjkwfoDBMkxNxvGqrqh9ux16aVGSmRMh8muZkYw4cmmzgY6mAE0tnsYZkm1ghyIAprAThkfEXfc%2BNfPXUKHkZYlBmsPE%2BHpdxeMcV1u6GwUQvFpG3rz2mL2dt%2FrsyFmh%2BdhwugOl1JaLAEWYLzHpQJvIAfU4mSfxVTQyavCgUD2LZjn71Ez6%2BjxKLIfjBRTe8mmSBvAtBs381K4omoszyAXvnukUAedD0PjGpugfT0M%2Fw9eo9MkiS7OgANsFA%3D%3D&Expires=1774826164) - use client import Link from nextlink import usePathname from nextnavigation const navItems href , la...

