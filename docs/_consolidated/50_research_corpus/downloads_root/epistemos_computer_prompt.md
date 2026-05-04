# EPISTEMOS PUBLIC SHELL — PERPLEXITY COMPUTER UPGRADE PROMPT

> **Instructions for use:** Paste everything below this line into Perplexity Computer (or Cursor/Claude Sonnet with computer-use). It is a complete, self-contained engineering spec. The agent should read it top to bottom and execute each phase in order.

---

## CONTEXT: WHAT THIS PROJECT IS

You are upgrading **Epistemos** — a Next.js 14 App Router web application (TypeScript, Tailwind CSS) that serves as the public shell for the Brainiac v2 cognitive research app. The public site:

- Hosts markdown essays and tech-logic posts via a file-system notes system (`lib/notes.ts`)
- Has a waitlist signup for the iOS App Store launch
- Has a "Sneak Peek" page (`app/sneak-peek/page.tsx`)
- Uses a star field canvas background, pixel font for badges, an editorial serif for articles
- Palette: `--bg-0: #0f0f12`, `--gold: #d7b36e`, `--sky: #90a9d8`, `--rose: #bb7564`, `--text: #f5eee4`

**PRESERVE EVERYTHING ABOUT THE CURRENT AESTHETIC.** Do not introduce color outside the existing palette. Do not add marketing sections. Do not add SaaS-style feature bullets. The brand is "pixel opulence" — restrained, deliberate, technically serious.

The favicon is a stark black circle with a white upward triangle. This is the primary visual anchor of the brand. Use it consistently.

---

## PHASE 1 — HERO & NAV SCALE-UP (Visual Polish, No Layout Break)

### 1A. Increase hero title size

In `globals.css`, find `.hero-title` and change:
```css
/* BEFORE */
.hero-title {
  font-size: clamp(3.2rem, 7vw, 6rem);
}

/* AFTER */
.hero-title {
  font-size: clamp(4rem, 9vw, 8rem);
  letter-spacing: -0.07em;
  line-height: 0.92;
}
```

### 1B. Increase brand orb in top-nav

In `globals.css`, find `.brand-orb` and change:
```css
/* BEFORE */
.brand-orb {
  width: 2.8rem;
  height: 2.8rem;
  border-radius: 0.95rem;
  font-size: 0.6rem;
}

/* AFTER */
.brand-orb {
  width: 3.4rem;
  height: 3.4rem;
  border-radius: 1.1rem;
  font-size: 0.72rem;
}
```

Replace the text content of `.brand-orb` in `top-nav.tsx` from `EPI` to the actual favicon triangle SVG:
```tsx
<div className="brand-orb">
  <svg width="16" height="14" viewBox="0 0 16 14" fill="none">
    <polygon points="8,1 15,13 1,13" fill="white" />
  </svg>
</div>
```

### 1C. Add a pixel eyebrow counter to the hero

In `page.tsx` (homepage), find the `<span className="eyebrow">` and replace its content:
```tsx
<span className="eyebrow">
  <span style={{ fontFamily: 'var(--font-pixel-stack)', fontSize: '0.58rem', letterSpacing: '0.14em', color: 'var(--gold)' }}>
    EPISTEMOS
  </span>
  &nbsp;·&nbsp;
  <span style={{ color: 'var(--muted)', fontSize: '0.62rem' }}>PUBLIC SHELL</span>
</span>
```

### 1D. Increase section headings

In `globals.css`, change `.section-title`:
```css
/* BEFORE */
.section-title {
  font-size: clamp(2rem, 4vw, 3rem);
}

/* AFTER */
.section-title {
  font-size: clamp(2.4rem, 5vw, 4rem);
  letter-spacing: -0.055em;
}
```

### 1E. Article title size increase

```css
/* BEFORE */
.article-title {
  font-size: clamp(2.6rem, 5vw, 4.8rem);
}

/* AFTER */
.article-title {
  font-size: clamp(3rem, 6vw, 6rem);
  letter-spacing: -0.07em;
}
```

---

## PHASE 2 — STAR FIELD UPGRADE (Shooting Stars Layer)

### 2A. Create `components/shooting-stars.tsx`

```tsx
'use client';
import { useEffect, useRef } from 'react';

interface Star {
  x: number;
  y: number;
  len: number;
  speed: number;
  alpha: number;
  active: boolean;
  trail: { x: number; y: number }[];
}

function createShootingStar(width: number, height: number): Star {
  const angle = (Math.PI / 180) * (210 + Math.random() * 30);
  return {
    x: Math.random() * width,
    y: Math.random() * height * 0.4,
    len: 80 + Math.random() * 120,
    speed: 6 + Math.random() * 8,
    alpha: 0,
    active: true,
    trail: [],
  };
}

export function ShootingStars() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let width = window.innerWidth;
    let height = window.innerHeight;
    const dpr = window.devicePixelRatio || 1;

    const resize = () => {
      width = window.innerWidth;
      height = window.innerHeight;
      canvas.width = Math.round(width * dpr);
      canvas.height = Math.round(height * dpr);
      canvas.style.width = width + 'px';
      canvas.style.height = height + 'px';
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    resize();
    window.addEventListener('resize', resize);

    const stars: Star[] = [];
    let frame = 0;
    let rafId = 0;
    let mounted = true;

    const spawnInterval = 420; // frames between spawns (~7s at 60fps)

    const draw = () => {
      if (!mounted) return;
      frame++;
      ctx.clearRect(0, 0, width, height);

      if (frame % spawnInterval === 0 && stars.filter(s => s.active).length < 2) {
        stars.push(createShootingStar(width, height));
      }

      const angle = (Math.PI / 180) * 225;

      for (const star of stars) {
        if (!star.active) continue;

        star.x += Math.cos(angle) * star.speed;
        star.y += Math.sin(angle) * star.speed;
        star.alpha = Math.min(1, star.alpha + 0.04);
        star.trail.unshift({ x: star.x, y: star.y });
        if (star.trail.length > 20) star.trail.pop();

        if (star.x < -200 || star.y > height + 200) {
          star.active = false;
          continue;
        }

        const grad = ctx.createLinearGradient(
          star.trail[star.trail.length - 1]?.x ?? star.x,
          star.trail[star.trail.length - 1]?.y ?? star.y,
          star.x, star.y
        );
        grad.addColorStop(0, `rgba(215, 179, 110, 0)`);
        grad.addColorStop(0.6, `rgba(215, 179, 110, ${star.alpha * 0.4})`);
        grad.addColorStop(1, `rgba(255, 255, 255, ${star.alpha * 0.9})`);

        ctx.beginPath();
        ctx.moveTo(star.trail[star.trail.length - 1]?.x ?? star.x, star.trail[star.trail.length - 1]?.y ?? star.y);
        for (const pt of [...star.trail].reverse()) {
          ctx.lineTo(pt.x, pt.y);
        }
        ctx.strokeStyle = grad;
        ctx.lineWidth = 1.5;
        ctx.stroke();

        // head pixel
        ctx.fillStyle = `rgba(255,255,255,${star.alpha})`;
        ctx.fillRect(Math.floor(star.x), Math.floor(star.y), 2, 2);
      }

      // prune inactive
      while (stars.length > 6) stars.shift();

      rafId = requestAnimationFrame(draw);
    };

    draw();
    return () => {
      mounted = false;
      cancelAnimationFrame(rafId);
      window.removeEventListener('resize', resize);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      style={{
        position: 'fixed', inset: 0, zIndex: 0,
        pointerEvents: 'none', opacity: 0.7,
      }}
    />
  );
}
```

### 2B. Add to `components/site-shell.tsx`

```tsx
import { TopNav } from '@/components/top-nav';
import { StarField } from '@/components/star-field';
import { ShootingStars } from '@/components/shooting-stars'; // ADD

export function SiteShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="site-shell">
      <StarField />
      <ShootingStars /> {/* ADD */}
      <div className="site-grid" aria-hidden="true" />
      <div className="site-noise" aria-hidden="true" />
      <div className="site-frame">
        <TopNav />
        {children}
      </div>
    </div>
  );
}
```

---

## PHASE 3 — ENCRYPTED TEXT REVEAL ON HERO TITLE

### 3A. Install dependency

```bash
# No npm install needed — implement inline. The effect is ~50 lines.
```

### 3B. Create `components/encrypted-text.tsx`

```tsx
'use client';
import { useEffect, useState, useRef } from 'react';

const CHARSET = '01▓░▒█▀▄■□◆◇∎∙';

interface Props {
  text: string;
  className?: string;
  delay?: number; // ms before animation starts
  as?: 'h1' | 'h2' | 'span' | 'p';
}

export function EncryptedText({ text, className, delay = 0, as: Tag = 'span' }: Props) {
  const [display, setDisplay] = useState(() => text.split('').map(() => CHARSET[Math.floor(Math.random() * CHARSET.length)]).join(''));
  const [done, setDone] = useState(false);
  const revealedRef = useRef(0);

  useEffect(() => {
    let timeout: ReturnType<typeof setTimeout>;
    let interval: ReturnType<typeof setInterval>;

    timeout = setTimeout(() => {
      interval = setInterval(() => {
        revealedRef.current += 1;
        const count = revealedRef.current;
        if (count > text.length) {
          setDisplay(text);
          setDone(true);
          clearInterval(interval);
          return;
        }
        setDisplay(
          text
            .split('')
            .map((char, i) => {
              if (char === ' ') return ' ';
              if (i < count) return char;
              return CHARSET[Math.floor(Math.random() * CHARSET.length)];
            })
            .join('')
        );
      }, 38);
    }, delay);

    return () => {
      clearTimeout(timeout);
      clearInterval(interval);
    };
  }, [text, delay]);

  return (
    <Tag
      className={className}
      aria-label={text}
      style={{ fontVariantNumeric: 'tabular-nums' }}
    >
      {done ? text : display}
    </Tag>
  );
}
```

### 3C. Use in `app/page.tsx` hero title

Replace the static `<h1 className="hero-title">` with:
```tsx
import { EncryptedText } from '@/components/encrypted-text';

// Replace:
<h1 className="hero-title">
  Epistemos, but the <span>public notes surface comes first.</span>
</h1>

// With:
<h1 className="hero-title" aria-label="Epistemos — public notes surface comes first.">
  <EncryptedText text="Epistemos" delay={200} />
  <span style={{ display: 'block', fontFamily: 'var(--font-editorial-stack)', fontStyle: 'italic', color: '#fff7ec' }}>
    <EncryptedText text="notes surface" delay={600} />
    {' '}comes first.
  </span>
</h1>
```

---

## PHASE 4 — CLARITY SCORE TOOL (Embedded in Sneak Peek, not a separate /tools page)

### Strategic rationale
Do NOT create a dedicated `/tools` page. The tools should feel native to the editorial identity of the site — not like bolt-on utilities. The **Clarity Score** lives embedded at the bottom of the Sneak Peek page, where it feels like a preview of the app's analytical capabilities. The Pixel Dither Lab lives in a subsection of the homepage's hero panel.

### 4A. Install `flesch-kincaid` (100% client-side, no API)

```bash
npm install flesch-kincaid syllable
```

If npm fails or types are missing, use this inline implementation instead — paste this as `lib/readability.ts`:

```typescript
// lib/readability.ts — zero-dependency Flesch-Kincaid implementation

function countSyllables(word: string): number {
  word = word.toLowerCase().replace(/[^a-z]/g, '');
  if (word.length <= 3) return 1;
  word = word.replace(/(?:[^laeiouy]es|ed|[^laeiouy]e)$/, '');
  word = word.replace(/^y/, '');
  const matches = word.match(/[aeiouy]{1,2}/g);
  return matches ? matches.length : 1;
}

function countSentences(text: string): number {
  const matches = text.match(/[.!?]+/g);
  return matches ? matches.length : 1;
}

function countWords(text: string): number {
  const words = text.trim().split(/\s+/).filter(Boolean);
  return words.length;
}

function totalSyllables(text: string): number {
  return text.trim().split(/\s+/).filter(Boolean).reduce((acc, w) => acc + countSyllables(w), 0);
}

export interface ReadabilityResult {
  fleschReadingEase: number;
  fleschKincaidGrade: number;
  gunningFog: number;
  avgSentenceLength: number;
  avgSyllablesPerWord: number;
  wordCount: number;
  sentenceCount: number;
  verdict: string;
  gradeLabel: string;
}

export function analyzeText(text: string): ReadabilityResult {
  const words = countWords(text);
  const sentences = countSentences(text);
  const syllables = totalSyllables(text);

  if (words < 10) {
    return {
      fleschReadingEase: 0, fleschKincaidGrade: 0, gunningFog: 0,
      avgSentenceLength: 0, avgSyllablesPerWord: 0,
      wordCount: words, sentenceCount: sentences,
      verdict: 'Too short to analyze.', gradeLabel: '—',
    };
  }

  const asl = words / sentences; // avg sentence length
  const asw = syllables / words; // avg syllables per word

  const fre = 206.835 - 1.015 * asl - 84.6 * asw;
  const fkgl = 0.39 * asl + 11.8 * asw - 15.59;

  // Gunning Fog (approximation without full complex-word count)
  const complexWords = text.trim().split(/\s+/).filter(w => countSyllables(w) >= 3).length;
  const fog = 0.4 * (asl + 100 * (complexWords / words));

  const gradeNum = Math.max(1, Math.round(fkgl));
  const gradeLabel =
    gradeNum <= 6 ? 'Elementary' :
    gradeNum <= 8 ? 'Middle School' :
    gradeNum <= 10 ? 'High School' :
    gradeNum <= 12 ? 'Senior High' :
    gradeNum <= 16 ? 'College Level' : 'Graduate Level';

  const freScore = Math.max(0, Math.min(100, Math.round(fre)));
  const verdict =
    freScore >= 80 ? 'Very easy — general audience will enjoy this.' :
    freScore >= 65 ? 'Standard — comfortable for most readers.' :
    freScore >= 50 ? 'Moderate — suitable for informed readers.' :
    freScore >= 30 ? 'Dense — needs a focused reader.' :
    'Very dense — academic or specialist text.';

  return {
    fleschReadingEase: freScore,
    fleschKincaidGrade: Math.round(fkgl * 10) / 10,
    gunningFog: Math.round(fog * 10) / 10,
    avgSentenceLength: Math.round(asl * 10) / 10,
    avgSyllablesPerWord: Math.round(asw * 100) / 100,
    wordCount: words,
    sentenceCount: sentences,
    verdict,
    gradeLabel,
  };
}
```

### 4B. Create `components/clarity-tool.tsx`

```tsx
'use client';
import { useState } from 'react';
import { analyzeText, type ReadabilityResult } from '@/lib/readability';
import Link from 'next/link';
import { ArrowRight } from 'lucide-react';

export function ClarityTool() {
  const [text, setText] = useState('');
  const [result, setResult] = useState<ReadabilityResult | null>(null);

  const analyze = () => {
    if (text.trim().length < 30) return;
    setResult(analyzeText(text));
  };

  return (
    <div style={{ display: 'grid', gap: '1rem' }}>
      <div style={{ display: 'grid', gap: '0.5rem' }}>
        <span className="pixel-badge">CLARITY SCORE — PROSE ANALYZER</span>
        <p style={{ color: 'var(--muted)', fontSize: '0.9rem', lineHeight: 1.65, maxWidth: '54ch' }}>
          Paste any paragraph. Get a Flesch-Kincaid reading grade, fog index, and a plain-English verdict — the same kind of clarity analysis Epistemos runs on your thinking.
        </p>
      </div>

      <textarea
        className="textarea"
        value={text}
        onChange={e => setText(e.target.value)}
        placeholder="Paste your writing here…"
        rows={5}
        style={{ minHeight: '7rem', fontFamily: 'var(--font-editorial-stack)', fontSize: '1rem', lineHeight: 1.7 }}
      />

      <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
        <button
          className="button-primary"
          onClick={analyze}
          disabled={text.trim().length < 30}
          style={{ opacity: text.trim().length < 30 ? 0.5 : 1 }}
        >
          Analyze Clarity
          <ArrowRight size={15} />
        </button>
        {text.length > 0 && (
          <span style={{ color: 'var(--muted)', fontSize: '0.78rem' }}>
            {text.trim().split(/\s+/).filter(Boolean).length} words
          </span>
        )}
      </div>

      {result && (
        <div style={{ display: 'grid', gap: '0.85rem', marginTop: '0.25rem' }}>
          <div className="signal-strip" style={{ gridTemplateColumns: 'repeat(3, minmax(0,1fr))' }}>
            <article className="signal-card">
              <div className="signal-label">READING EASE</div>
              <div className="signal-value" style={{ color: result.fleschReadingEase >= 60 ? 'var(--mint, #89c5a8)' : result.fleschReadingEase >= 40 ? 'var(--gold)' : 'var(--rose)' }}>
                {result.fleschReadingEase}<span style={{ fontSize: '0.7em', color: 'var(--muted)', marginLeft: '0.2em' }}>/100</span>
              </div>
              <p className="signal-note">Higher = easier to read</p>
            </article>
            <article className="signal-card">
              <div className="signal-label">GRADE LEVEL</div>
              <div className="signal-value">{result.fleschKincaidGrade}</div>
              <p className="signal-note">{result.gradeLabel}</p>
            </article>
            <article className="signal-card">
              <div className="signal-label">FOG INDEX</div>
              <div className="signal-value">{result.gunningFog}</div>
              <p className="signal-note">Avg sentence + complex words</p>
            </article>
          </div>

          <div className="stack-card" style={{ padding: '0.9rem 1rem' }}>
            <div className="pixel-badge" style={{ marginBottom: '0.5rem' }}>VERDICT</div>
            <p style={{ color: 'var(--text)', fontSize: '1rem', lineHeight: 1.65 }}>{result.verdict}</p>
            <div style={{ marginTop: '0.75rem', display: 'flex', gap: '1.5rem', color: 'var(--muted)', fontSize: '0.78rem' }}>
              <span>Avg sentence: <strong style={{ color: 'var(--text)' }}>{result.avgSentenceLength} words</strong></span>
              <span>Syllables/word: <strong style={{ color: 'var(--text)' }}>{result.avgSyllablesPerWord}</strong></span>
              <span>Sentences: <strong style={{ color: 'var(--text)' }}>{result.sentenceCount}</strong></span>
            </div>
          </div>

          <div style={{ paddingTop: '0.5rem', borderTop: '1px solid var(--border)' }}>
            <p style={{ color: 'var(--muted)', fontSize: '0.85rem', lineHeight: 1.6 }}>
              Epistemos goes deeper — tracking clarity across your entire note graph, not just single paragraphs.
            </p>
            <Link href="/waitlist" className="mini-button" style={{ marginTop: '0.65rem', display: 'inline-flex', alignItems: 'center', gap: '0.45rem' }}>
              Join the waitlist <ArrowRight size={14} />
            </Link>
          </div>
        </div>
      )}
    </div>
  );
}
```

### 4C. Embed in `app/sneak-peek/page.tsx`

Add at the bottom of the sneak-peek page, inside the main `<section>` or `<div>`, before the closing tag:

```tsx
import { ClarityTool } from '@/components/clarity-tool';

// Add this section:
<section className="content-shell" style={{ padding: '1.4rem', marginTop: '1.25rem' }}>
  <div className="section-shell" style={{ gap: '0.75rem', marginBottom: '1.25rem' }}>
    <span className="eyebrow">Analytical Preview</span>
    <h2 className="section-title" style={{ fontSize: 'clamp(1.8rem, 3.5vw, 2.8rem)' }}>
      Try the engine on your own writing.
    </h2>
    <p className="section-blurb">
      This is a surface-level preview of how Epistemos reads text. Paste anything — a paragraph from an essay, a note, a draft argument.
    </p>
  </div>
  <ClarityTool />
</section>
```

---

## PHASE 5 — PIXEL DITHER LAB (Embedded in Hero Panel)

### 5A. Install `canvas-dither`

```bash
npm install canvas-dither
```

This is the `canvas-dither` npm package — a zero-dependency implementation of Atkinson and Floyd-Steinberg dithering that operates directly on `ImageData` from the Canvas API. It requires no backend.

### 5B. Create `components/dither-lab.tsx`

```tsx
'use client';
import { useRef, useState } from 'react';
// @ts-ignore — canvas-dither has no types
import Dither from 'canvas-dither';

type Algorithm = 'atkinson' | 'floydsteinberg';

export function DitherLab() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [algorithm, setAlgorithm] = useState<Algorithm>('atkinson');
  const [hasImage, setHasImage] = useState(false);
  const [fileName, setFileName] = useState('');

  const processImage = (file: File) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      // Scale down to max 600px wide for performance
      const maxW = 600;
      const scale = img.width > maxW ? maxW / img.width : 1;
      canvas.width = Math.round(img.width * scale);
      canvas.height = Math.round(img.height * scale);
      const ctx = canvas.getContext('2d')!;
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      let imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
      imageData = algorithm === 'atkinson'
        ? Dither.atkinson(imageData)
        : Dither.floydsteinberg(imageData);
      ctx.putImageData(imageData, 0, 0);
      setHasImage(true);
      URL.revokeObjectURL(url);
    };
    img.src = url;
  };

  const handleFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setFileName(file.name.replace(/\.[^.]+$/, '') + '-dithered');
    processImage(file);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    const file = e.dataTransfer.files?.[0];
    if (file && file.type.startsWith('image/')) processImage(file);
  };

  const downloadImage = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const a = document.createElement('a');
    a.href = canvas.toDataURL('image/png');
    a.download = (fileName || 'dithered') + '.png';
    a.click();
  };

  return (
    <div style={{ display: 'grid', gap: '0.85rem' }}>
      <span className="pixel-badge">PIXEL DITHER LAB</span>

      <div
        onDrop={handleDrop}
        onDragOver={e => e.preventDefault()}
        style={{
          border: '1px dashed var(--border)',
          borderRadius: '1.2rem',
          padding: '1.25rem',
          textAlign: 'center',
          cursor: 'pointer',
          background: 'rgba(255,255,255,0.03)',
          transition: 'border-color 160ms ease',
        }}
        onClick={() => document.getElementById('dither-file-input')?.click()}
      >
        <input
          id="dither-file-input"
          type="file"
          accept="image/*"
          style={{ display: 'none' }}
          onChange={handleFile}
        />
        <p style={{ color: 'var(--muted)', fontSize: '0.85rem', margin: 0 }}>
          Drop an image or click to upload → convert to pixel art
        </p>
      </div>

      <div style={{ display: 'flex', gap: '0.6rem' }}>
        {(['atkinson', 'floydsteinberg'] as Algorithm[]).map(alg => (
          <button
            key={alg}
            className={algorithm === alg ? 'mini-button' : 'button-secondary'}
            style={{ fontSize: '0.75rem', padding: '0.5rem 0.85rem' }}
            onClick={() => setAlgorithm(alg)}
          >
            {alg === 'atkinson' ? 'Atkinson' : 'Floyd-Steinberg'}
          </button>
        ))}
      </div>

      <canvas
        ref={canvasRef}
        style={{
          display: hasImage ? 'block' : 'none',
          imageRendering: 'pixelated',
          borderRadius: '1rem',
          border: '1px solid var(--border)',
          maxWidth: '100%',
        }}
      />

      {hasImage && (
        <button className="button-primary" onClick={downloadImage} style={{ width: 'fit-content' }}>
          Download Dithered PNG
        </button>
      )}

      <p style={{ color: 'var(--muted)', fontSize: '0.78rem', lineHeight: 1.6, marginTop: '0.1rem' }}>
        Made with the same pixel philosophy as Epistemos — precision over noise.
      </p>
    </div>
  );
}
```

### 5C. Embed in the homepage hero panel

In `app/page.tsx`, find the `<aside className="hero-panel">` section and add `DitherLab` as a third `stack-card`:

```tsx
import { DitherLab } from '@/components/dither-lab';

// Inside <aside className="hero-panel">, after the last existing <article className="stack-card">:
<article className="stack-card">
  <header>
    <div>
      <div className="pixel-badge">Pixel Dither Lab</div>
      <h3>Convert any image to pixel art — free, in-browser.</h3>
    </div>
    <div className="pixel-line" aria-hidden="true">
      <span /><span /><span />
    </div>
  </header>
  <div style={{ marginTop: '0.75rem' }}>
    <DitherLab />
  </div>
</article>
```

---

## PHASE 6 — NAV ENHANCEMENT

### 6A. Update `components/top-nav.tsx`

Add a "Sneak Peek" link if not already present, and add a visual separator between the main nav and CTA:

```tsx
const navItems = [
  { href: '/', label: 'Home' },
  { href: '/notes', label: 'Notes' },
  { href: '/sneak-peek', label: 'Sneak Peek' },
] as const;
```

No other nav changes. Do NOT add a `/tools` link.

---

## PHASE 7 — NOTES PAGE POLISH

### 7A. Add reading progress bar to article pages

In `globals.css`, add:
```css
.reading-progress {
  position: fixed;
  top: 0;
  left: 0;
  height: 2px;
  background: linear-gradient(90deg, var(--gold), var(--rose));
  z-index: 100;
  transform-origin: left;
  transition: width 80ms linear;
  pointer-events: none;
}
```

Create `components/reading-progress.tsx`:
```tsx
'use client';
import { useEffect, useState } from 'react';

export function ReadingProgress() {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const update = () => {
      const el = document.documentElement;
      const scrollTop = el.scrollTop || document.body.scrollTop;
      const scrollHeight = el.scrollHeight - el.clientHeight;
      setProgress(scrollHeight > 0 ? (scrollTop / scrollHeight) * 100 : 0);
    };
    window.addEventListener('scroll', update, { passive: true });
    return () => window.removeEventListener('scroll', update);
  }, []);

  return (
    <div
      className="reading-progress"
      aria-hidden="true"
      style={{ width: `${progress}%` }}
    />
  );
}
```

Add `<ReadingProgress />` at the top of the individual note page layout in `app/notes/[slug]/page.tsx`.

### 7B. Add a lexical density badge to notes

In `lib/notes.ts`, add after `readingTime` computation:

```typescript
function getLexicalDensity(content: string): number {
  const words = content.trim().split(/\s+/).filter(Boolean);
  const stopwords = new Set(['the','a','an','and','or','but','in','on','at','to','for','of','with','by','from','is','was','are','were','be','been','being','have','has','had','do','does','did','will','would','could','should','may','might','shall','can','need','dare','ought','used','it','this','that','these','those','i','you','he','she','we','they','me','him','her','us','them','my','your','his','our','their','its','what','which','who','whom','whose','when','where','why','how','not','no','nor','so','yet','both','either','neither','each','few','more','most','other','some','such','than','then','there','too','very','just','as','if','though','although','because','since','while']);
  const contentWords = words.filter(w => !stopwords.has(w.toLowerCase().replace(/[^a-z]/g, '')));
  return Math.round((contentWords.length / words.length) * 100);
}

// Then add to parseNote return:
lexicalDensity: getLexicalDensity(content),
```

Also add `lexicalDensity: number` to the `NotePreview` type.

Display in note cards as a depth badge:
```tsx
// In note card rendering:
<span className="pixel-badge" style={{ 
  color: note.lexicalDensity > 65 ? 'var(--rose)' : note.lexicalDensity > 50 ? 'var(--gold)' : 'var(--sky)',
  marginLeft: '0.5rem'
}}>
  {note.lexicalDensity > 65 ? 'DENSE' : note.lexicalDensity > 50 ? 'DEEP' : 'CLEAR'}
</span>
```

---

## PHASE 8 — LOGSEQ / NOTION / OBSIDIAN INSPIRATION FEATURES

Logseq's key differentiator is its "bi-directional linking" and the idea that every block of information is navigable across contexts. Notion's 2025 additions focus on spatial layouts and dashboard-first pages. Obsidian's community uses "Maps of Content" (MOC) as navigational hubs.

The Epistemos equivalent is: **make the Notes page feel like a navigable knowledge environment, not a blog archive.**

### 8A. Add a tag-filter sidebar to notes

In `app/notes/page.tsx` (your notes listing page), make the sidebar tags interactive:

```tsx
'use client'; // convert to client component or split into client wrapper

import { useState } from 'react';

// Collect all unique tags from notes:
const allTags = Array.from(new Set(notes.flatMap(n => n.tags)));

// State:
const [activeTag, setActiveTag] = useState<string | null>(null);
const filtered = activeTag ? notes.filter(n => n.tags.includes(activeTag)) : notes;

// In the sidebar, replace static tag spans with buttons:
{allTags.map(tag => (
  <button
    key={tag}
    className="tag"
    onClick={() => setActiveTag(activeTag === tag ? null : tag)}
    style={{
      cursor: 'pointer',
      background: activeTag === tag ? 'rgba(215,179,110,0.2)' : undefined,
      color: activeTag === tag ? 'var(--gold)' : undefined,
      border: activeTag === tag ? '1px solid rgba(215,179,110,0.3)' : '1px solid transparent',
      transition: 'all 160ms ease',
    }}
  >
    {tag}
  </button>
))}
```

### 8B. Add a "knowledge graph teaser" to the Sneak Peek page

This nods directly to Logseq's graph view and Obsidian's graph — a key emotional selling point for thinking-tool users. Create a static SVG that *looks* like a simplified graph view of connected notes:

```tsx
// components/graph-teaser.tsx
export function GraphTeaser() {
  const nodes = [
    { x: 50, y: 50, label: 'AI Logic' },
    { x: 30, y: 75, label: 'Essay 01' },
    { x: 70, y: 72, label: 'Research' },
    { x: 20, y: 40, label: 'Clarity' },
    { x: 80, y: 35, label: 'Systems' },
    { x: 50, y: 22, label: 'Cognition' },
  ];
  const edges = [[0,1],[0,2],[0,3],[0,4],[0,5],[1,3],[2,5],[4,5]];
  const r = 5;

  return (
    <div style={{ position: 'relative', borderRadius: '1.2rem', overflow: 'hidden', border: '1px solid var(--border)', background: 'rgba(255,255,255,0.03)', padding: '1rem' }}>
      <span className="pixel-badge" style={{ position: 'absolute', top: '0.75rem', left: '0.75rem' }}>GRAPH PREVIEW</span>
      <svg viewBox="0 0 100 100" style={{ width: '100%', aspectRatio: '1.6', display: 'block', marginTop: '1.5rem' }}>
        {edges.map(([a, b], i) => (
          <line key={i}
            x1={nodes[a].x} y1={nodes[a].y}
            x2={nodes[b].x} y2={nodes[b].y}
            stroke="rgba(215,179,110,0.25)" strokeWidth="0.5"
          />
        ))}
        {nodes.map((n, i) => (
          <g key={i}>
            <circle cx={n.x} cy={n.y} r={r} fill="rgba(255,255,255,0.08)" stroke="rgba(215,179,110,0.5)" strokeWidth="0.6" />
            <text x={n.x} y={n.y + r + 4} textAnchor="middle" fill="rgba(245,238,228,0.6)" fontSize="3.5">
              {n.label}
            </text>
          </g>
        ))}
        {/* Central node highlight */}
        <circle cx={50} cy={50} r={r + 1.5} fill="rgba(215,179,110,0.15)" stroke="var(--gold)" strokeWidth="0.8" />
      </svg>
      <p style={{ color: 'var(--muted)', fontSize: '0.78rem', textAlign: 'center', marginTop: '0.5rem', lineHeight: 1.5 }}>
        Every note is a node. Every connection is navigable.<br />
        <span style={{ color: 'var(--gold)', fontFamily: 'var(--font-pixel-stack)', fontSize: '0.62rem', letterSpacing: '0.08em' }}>FULL GRAPH IN APP →</span>
      </p>
    </div>
  );
}
```

Add `<GraphTeaser />` to the Sneak Peek page between existing content sections.

---

## PHASE 9 — WAITLIST PAGE SMART MOBILE BANNER

In `app/waitlist/page.tsx`, add a sticky smart banner visible only on mobile that links to the App Store (replace `YOUR_APP_STORE_URL`):

```tsx
// In layout or in waitlist page:
<div
  style={{
    display: 'none', // override with media query
    position: 'fixed', bottom: 0, left: 0, right: 0,
    background: 'rgba(16,16,20,0.96)',
    backdropFilter: 'blur(16px)',
    borderTop: '1px solid var(--border)',
    padding: '0.85rem 1rem',
    zIndex: 50,
    alignItems: 'center',
    gap: '0.75rem',
  }}
  className="mobile-app-banner"
>
  <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
    <circle cx="14" cy="14" r="14" fill="black" />
    <polygon points="14,7 22,21 6,21" fill="white" />
  </svg>
  <div style={{ flex: 1 }}>
    <div style={{ fontFamily: 'var(--font-pixel-stack)', fontSize: '0.65rem', color: 'var(--gold)', letterSpacing: '0.1em' }}>EPISTEMOS</div>
    <div style={{ color: 'var(--muted)', fontSize: '0.78rem' }}>Available on the App Store</div>
  </div>
  <a href="YOUR_APP_STORE_URL" className="mini-button">Get App</a>
</div>
```

Add to `globals.css`:
```css
@media (max-width: 640px) {
  .mobile-app-banner {
    display: flex !important;
  }
}
```

---

## FINAL CHECKLIST — RUN BEFORE PUSHING TO PRODUCTION

- [ ] `npm run build` passes with zero errors
- [ ] No `any` type errors in new TypeScript files (use `// @ts-ignore` only for `canvas-dither`)
- [ ] `ClarityTool` textarea has `aria-label` set to "Paste text to analyze clarity"
- [ ] `DitherLab` file input has `aria-label` set to "Upload image for dithering"
- [ ] `ShootingStars` canvas has `aria-hidden="true"`
- [ ] `EncryptedText` components have `aria-label` set to the final resolved text
- [ ] Reading progress bar has `aria-hidden="true"`
- [ ] All new components are `'use client'` where they use hooks or browser APIs
- [ ] `lib/readability.ts` does NOT import any Node.js-only APIs (no `fs`, no `path`)
- [ ] `canvas-dither` is imported correctly (`import Dither from 'canvas-dither'` or `const Dither = require(...)`)
- [ ] Mobile-responsive: test all new components at 375px viewport width
- [ ] No new external API calls in any component — everything runs fully client-side

---

## WHAT NOT TO CHANGE

- Do not modify `globals.css` color variables
- Do not add any new fonts
- Do not add a `/tools` page route
- Do not add testimonials, social proof sections, or feature comparison tables
- Do not change the note file-system structure in `lib/notes.ts` (only add `lexicalDensity`)
- Do not change the existing `StarField` component — only ADD `ShootingStars` alongside it
- Do not add external analytics without consent (no Hotjar, FullStory, etc.)
