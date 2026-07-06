// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// BUNDLE GATING REALITY: js-editor builds ONE webpack bundle shared by BOTH app targets (no
// DefinePlugin/env mechanism; CLAUDE.md's "esbuild" is stale — it's webpack 5 + ts-loader).
// v1 gate = NATIVE-INJECTION: this module is inert unless the Swift side (#if KINDRED_ENABLED)
// injects the companion bootstrap user-script/bridge handle. MAS never injects → no companion
// behavior, honest surface-level gate. Follow-up option if stricter exclusion is wanted: a
// webpack DefinePlugin variant producing a second staged bundle for the AppStore target.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// embodied-presence.ts — EPI-RP-05-KINDRED · D10 embodied editing (BINDING, headline).
//
// The spark: as the companion edits, you SEE it there — its body tracking the exact word
// being written, gliding along the caret, resting when idle. A tiny writer on your page,
// not a cursor.
//
// Feasibility is real and rests on documented ProseMirror APIs:
//   - view.coordsAtPos(pos) -> viewport rect {left,right,top,bottom} for a doc position
//   - only `transform` and `opacity` skip Layout + Paint (compositor-only) -> no thrash
//   - rAF keyed on elapsed TIME (performance.now delta), not frame count -> correct at 120Hz
//
// Every beat maps to a REAL event (token stream, transaction applied, turn end). Nothing faked.

import type { EditorView } from "prosemirror-view";

export interface EmbodiedOptions {
  /** Honor prefers-reduced-motion: no glide, static presence only. */
  reducedMotion: boolean;
  /** Quiet-edit mode: presence without the following animation. */
  quietEdit: boolean;
  /** Vertical offset above the caret so the sprite never obscures the text it edits. */
  offsetY: number;
  /** If the target jumps beyond this many px, teleport instead of gliding. */
  teleportThresholdPx: number;
  /** Spring stiffness for the lerp toward target (0..1 per frame-ish). */
  stiffness: number;
}

export const DEFAULT_EMBODIED: EmbodiedOptions = {
  reducedMotion: false,
  quietEdit: false,
  offsetY: 28,
  teleportThresholdPx: 240,
  stiffness: 0.18,
};

export class EmbodiedPresence {
  private raf = 0;
  private targetX = 0;
  private targetY = 0;
  private x = 0;
  private y = 0;
  private lastTs = 0;

  constructor(
    private readonly view: EditorView,
    private readonly sprite: HTMLElement,
    private opts: EmbodiedOptions = DEFAULT_EMBODIED
  ) {}

  /** Follow the caret at document position `pos` (the end of the active edit range). */
  followPos(pos: number): void {
    let rect: { left: number; top: number };
    try {
      // coordsAtPos is only valid for positions inside the current viewport.
      rect = this.view.coordsAtPos(pos);
    } catch {
      // Position outside the viewport (fast scroll / far jump) -> retreat gracefully.
      this.retreatToSidebar();
      return;
    }

    this.targetX = rect.left;
    this.targetY = rect.top - this.opts.offsetY; // never on the text — above it

    if (this.opts.reducedMotion || this.opts.quietEdit) {
      this.x = this.targetX;
      this.y = this.targetY;
      this.paint();
      return;
    }

    const jump = Math.hypot(this.targetX - this.x, this.targetY - this.y);
    if (jump > this.opts.teleportThresholdPx) {
      // Far jump: teleport, don't streak across the whole document.
      this.x = this.targetX;
      this.y = this.targetY;
      this.paint();
      return;
    }

    if (!this.raf) {
      this.lastTs = performance.now();
      this.raf = requestAnimationFrame(this.tick);
    }
  }

  private tick = (ts: number): void => {
    const dt = Math.min(48, ts - this.lastTs); // clamp to survive tab-switch stalls
    this.lastTs = ts;
    // Time-scaled lerp so speed is display-refresh-independent (correct on 120Hz).
    const k = 1 - Math.pow(1 - this.opts.stiffness, dt / 16.67);
    this.x += (this.targetX - this.x) * k;
    this.y += (this.targetY - this.y) * k;
    this.paint();

    const settled = Math.hypot(this.targetX - this.x, this.targetY - this.y) < 0.5;
    this.raf = settled ? 0 : requestAnimationFrame(this.tick);
  };

  /** Transform-only paint — compositor path, no layout/paint. */
  private paint(): void {
    this.sprite.style.transform = `translate(${this.x.toFixed(2)}px, ${this.y.toFixed(2)}px)`;
  }

  private scrollTicking = false;
  /** Re-anchor on scroll, throttled to one read per frame. */
  onScroll(activePos: number): void {
    if (this.scrollTicking) return;
    this.scrollTicking = true;
    requestAnimationFrame(() => {
      this.followPos(activePos);
      this.scrollTicking = false;
    });
  }

  /** On turn end (stop_reason: end_turn): glide back to the dock anchor, emote "done". */
  retreatToSidebar(): void {
    // TODO: set target to the sidebar bubble anchor; on arrival fire the done emote.
  }

  /** On any user transaction inside the edited range: step aside, never fight the cursor. */
  yieldToUser(): void {
    // TODO: offset the sprite clear of the user's selection; pause following.
  }

  setOptions(patch: Partial<EmbodiedOptions>): void {
    this.opts = { ...this.opts, ...patch };
  }
}
