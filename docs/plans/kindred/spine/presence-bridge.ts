// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// BUNDLE GATING REALITY: js-editor builds ONE webpack bundle shared by BOTH app targets (no
// DefinePlugin/env mechanism; CLAUDE.md's "esbuild" is stale — it's webpack 5 + ts-loader).
// v1 gate = NATIVE-INJECTION: this module is inert unless the Swift side (#if KINDRED_ENABLED)
// injects the companion bootstrap user-script/bridge handle. MAS never injects → no companion
// behavior, honest surface-level gate. Follow-up option if stricter exclusion is wanted: a
// webpack DefinePlugin variant producing a second staged bundle for the AppStore target.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// presence-bridge.ts — EPI-RP-05-KINDRED · F6 state bus, WebView side (BINDING).
//
// Receives CompanionPresence from Swift (via evaluateJavaScript), applies the same
// clock guard as the Rust bus (Yjs rule), drives the Rive rig's emote input, and hands the
// active edit range to the embodied sprite. This is the WebView half of "one identity,
// four surfaces" — the main chat and the minichat both render off THIS.

import type { EmbodiedPresence } from "./embodied-presence";

export interface CompanionPresenceDTO {
  companionId: string;
  activity: string;
  emote: string;              // maps to a Rive state-machine input name
  clock: number;
  noteId?: string;
  range?: [number, number];   // active edit range; range[1] is the write head
}

/** Set a Rive state-machine input by name. Same .riv as the native rive-ios path. */
export type SetRiveInput = (name: string, value: boolean | number) => void;

export class PresenceBridge {
  private lastClock = 0;

  constructor(
    private readonly embodied: EmbodiedPresence,
    private readonly setRiveInput: SetRiveInput
  ) {}

  /** Called by Swift. Idempotent + clock-guarded; a dropped message self-heals next tick. */
  onPresence(dto: CompanionPresenceDTO): void {
    if (dto.clock <= this.lastClock) return; // stale / duplicate
    this.lastClock = dto.clock;

    // Drive the emote (skin over real state — the string already came from a real RunState).
    this.setRiveInput(dto.emote, true);

    // Move the embodied sprite to the write head, if we're actively editing a range.
    if (dto.range) {
      this.embodied.followPos(dto.range[1]);
    }
  }
}

/** Expose a single global the Swift bridge can call into. */
export function installPresenceBridge(bridge: PresenceBridge): void {
  (window as unknown as { __epdocPresence?: PresenceBridge }).__epdocPresence = bridge;
  // Swift: evaluateJavaScript("window.__epdocPresence.onPresence(<json>)")
}
