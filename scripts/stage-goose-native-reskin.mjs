#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const desktopRoot = process.argv[2];
if (!desktopRoot) {
  console.error('usage: stage-goose-native-reskin.mjs <goose-ui-desktop-root>');
  process.exit(64);
}

const marker = 'epistemos-native-reskin-overlay';
const focusPolishMarker = 'epistemos-native-scrollbar-focus-polish';
const primitivePolishMarker = 'epistemos-native-primitive-polish';
const surfacePolishMarker = 'epistemos-native-surface-polish';
const catalogPolishMarker = 'epistemos-native-catalog-screen-polish';
const loadingErrorPolishMarker = 'epistemos-native-loading-error-polish';
const motionPolishMarker = 'epistemos-native-motion-polish';
const flatPolishMarker = 'epistemos-native-high-quality-flat-polish';
const claudePixelPolishMarker = 'epistemos-native-claude-pixel-polish';
const claudePixelContractMarker = 'epistemos-native-claude-pixel-contract';
const claudeDesktopLockMarker = 'epistemos-native-claude-desktop-lock';
const flatSourceSurfacesMarker = 'epistemos-native-flat-source-surfaces';

function read(relativePath) {
  return fs.readFileSync(path.join(desktopRoot, relativePath), 'utf8');
}

function write(relativePath, source) {
  fs.writeFileSync(path.join(desktopRoot, relativePath), source);
}

function walkFiles(root, predicate, files = []) {
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    const fullPath = path.join(root, entry.name);
    if (entry.isDirectory()) {
      walkFiles(fullPath, predicate, files);
    } else if (entry.isFile() && predicate(fullPath)) {
      files.push(fullPath);
    }
  }
  return files;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function replaceRequired(source, label, search, replacement) {
  const next = typeof search === 'string'
    ? source.replace(search, replacement)
    : source.replace(search, replacement);
  if (next === source) {
    throw new Error(`${label} replacement was not applied`);
  }
  return next;
}

function replaceOptional(source, search, replacement) {
  return typeof search === 'string'
    ? source.replace(search, replacement)
    : source.replace(search, replacement);
}

function replaceAllRequired(source, label, search, replacement) {
  const next = source.replaceAll(search, replacement);
  if (next === source) {
    throw new Error(`${label} replacement was not applied`);
  }
  return next;
}

function replaceAllOptional(source, search, replacement) {
  return source.replaceAll(search, replacement);
}

function replaceTokenValues(source, key, values) {
  let index = 0;
  const pattern = new RegExp(`((?:'|")${escapeRegExp(key)}(?:'|")\\s*:\\s*)(?:'[^']*'|"[^"]*")`, 'g');
  const next = source.replace(pattern, (match, prefix) => {
    if (index >= values.length) {
      return match;
    }
    const value = values[index++];
    return `${prefix}${JSON.stringify(value)}`;
  });
  if (index < values.length) {
    throw new Error(`token ${key} expected ${values.length} replacement(s), applied ${index}`);
  }
  return next;
}

function applyThemeTokens() {
  let source = read('src/theme/theme-tokens.ts');
  const base = {
    '--font-sans': '-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", system-ui, sans-serif',
    '--font-mono': 'ui-monospace, "SF Mono", SFMono-Regular, Menlo, Monaco, Consolas, monospace',
    '--font-weight-normal': '400',
    '--font-weight-medium': '600',
    '--font-weight-semibold': '600',
    '--font-weight-bold': '700',
    '--font-text-md-size': '1.0625rem',
    '--border-radius-xs': '6px',
    '--border-radius-sm': '8px',
    '--border-radius-md': '11px',
    '--border-radius-lg': '14px',
    '--border-radius-xl': '18px',
    '--border-radius-full': '9999px',
  };
  for (const [key, value] of Object.entries(base)) {
    source = replaceTokenValues(source, key, [value]);
  }

  const paired = {
    '--color-background-primary': ['#ffffff', '#000000'],
    '--color-background-secondary': ['#f5f5f7', '#272729'],
    '--color-background-tertiary': ['#fafafc', '#2a2a2c'],
    '--color-background-inverse': ['#1d1d1f', '#ffffff'],
    '--color-background-info': ['#f1f1f3', '#202024'],
    '--color-background-danger': ['#f1f1f3', '#202024'],
    '--color-background-success': ['#f1f1f3', '#202024'],
    '--color-background-warning': ['#f1f1f3', '#202024'],
    '--color-background-disabled': ['#f0f0f0', '#333333'],
    '--color-text-primary': ['#1d1d1f', '#ffffff'],
    '--color-text-secondary': ['#6e6e73', '#cccccc'],
    '--color-text-tertiary': ['#86868b', '#7a7a7a'],
    '--color-text-inverse': ['#ffffff', '#1d1d1f'],
    '--color-text-ghost': ['#86868b', '#7a7a7a'],
    '--color-text-info': ['#1d1d1f', '#ffffff'],
    '--color-text-danger': ['#1d1d1f', '#ffffff'],
    '--color-text-success': ['#1d1d1f', '#ffffff'],
    '--color-text-warning': ['#1d1d1f', '#ffffff'],
    '--color-text-disabled': ['#86868b', '#7a7a7a'],
    '--color-border-primary': ['#e0e0e0', '#333333'],
    '--color-border-secondary': ['#f0f0f0', '#252527'],
    '--color-border-tertiary': ['#d2d2d7', '#3a3a3c'],
    '--color-border-inverse': ['#1d1d1f', '#ffffff'],
    '--color-border-info': ['#d2d2d7', '#3a3a3c'],
    '--color-border-danger': ['#d2d2d7', '#3a3a3c'],
    '--color-border-success': ['#d2d2d7', '#3a3a3c'],
    '--color-border-warning': ['#d2d2d7', '#3a3a3c'],
    '--color-border-disabled': ['#e0e0e0', '#333333'],
    '--color-ring-primary': ['#1d1d1f', '#ffffff'],
    '--color-ring-secondary': ['#6e6e73', '#cccccc'],
    '--color-ring-inverse': ['#ffffff', '#1d1d1f'],
    '--color-ring-info': ['#1d1d1f', '#ffffff'],
    '--color-ring-danger': ['#1d1d1f', '#ffffff'],
    '--color-ring-success': ['#1d1d1f', '#ffffff'],
    '--color-ring-warning': ['#1d1d1f', '#ffffff'],
    '--shadow-hairline': ['none', 'none'],
    '--shadow-sm': ['none', 'none'],
    '--shadow-md': ['none', 'none'],
    '--shadow-lg': ['none', 'none'],
  };
  for (const [key, values] of Object.entries(paired)) {
    source = replaceTokenValues(source, key, values);
  }
  write('src/theme/theme-tokens.ts', source);
}

function applyMainCSS() {
  let source = read('src/styles/main.css');
  if (!source.includes(marker)) {
    source += `

/* ==========================================================================
   Epistemos durable native WebView reskin (${marker})
   Applied at build staging so Goose's existing shadcn/Radix UI keeps matching
   the native transparent-over-glass frame even when the upstream checkout is
   refreshed.
   ========================================================================== */
:root,
.goose-epistemos {
  --epistemos-native-reskin-overlay: 1;
  --epistemos-accent: var(--color-ring-primary);
  --epistemos-control-ease: linear(
    0,
    0.402 7.4%,
    0.711 15.3%,
    0.929 23.7%,
    1.067 33%,
    1.108 41%,
    1.019 70.1%,
    1
  );
  --epistemos-glass-fill: color-mix(in srgb, var(--color-background-primary) 78%, transparent);
  --epistemos-glass-fill-strong: color-mix(in srgb, var(--color-background-primary) 88%, transparent);
  --epistemos-glass-fill-muted: color-mix(in srgb, var(--color-background-secondary) 76%, transparent);
  --epistemos-glass-border: color-mix(in srgb, var(--color-border-primary) 78%, transparent);
  --epistemos-control-shadow:
    0 1px 1px rgba(0, 0, 0, 0.05),
    0 12px 32px rgba(0, 0, 0, 0.08);
  --epistemos-popover-shadow:
    0 1px 1px rgba(0, 0, 0, 0.08),
    0 18px 48px rgba(0, 0, 0, 0.14);
  --radius: 11px;
}

.dark,
.dark .goose-epistemos {
  --epistemos-glass-fill: color-mix(in srgb, var(--color-background-tertiary) 68%, transparent);
  --epistemos-glass-fill-strong: color-mix(in srgb, var(--color-background-tertiary) 82%, transparent);
  --epistemos-glass-fill-muted: color-mix(in srgb, var(--color-background-secondary) 66%, transparent);
  --epistemos-glass-border: color-mix(in srgb, var(--color-border-tertiary) 72%, transparent);
  --epistemos-control-shadow:
    0 1px 1px rgba(0, 0, 0, 0.18),
    0 14px 38px rgba(0, 0, 0, 0.24);
  --epistemos-popover-shadow:
    0 1px 1px rgba(0, 0, 0, 0.26),
    0 20px 52px rgba(0, 0, 0, 0.36);
}

html,
body,
#root,
:root,
.goose-epistemos {
  background: transparent !important;
}

body {
  color-scheme: light dark;
}

.goose-epistemos {
  font-family: var(--font-sans), -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
}

.goose-epistemos :is(
  .bg-background-primary,
  .bg-background-secondary,
  .bg-background-tertiary
) {
  background-color: var(--epistemos-glass-fill) !important;
}

.goose-epistemos :is(
  .goose-chat-input-card,
  .goose-user-message-bubble,
  .goose-message-content,
  .goose-message-tool,
  .select__menu,
  [role='dialog'],
  [data-radix-popper-content-wrapper] > *
) {
  -webkit-backdrop-filter: blur(22px) saturate(1.45);
  backdrop-filter: blur(22px) saturate(1.45);
  background-color: var(--epistemos-glass-fill-strong) !important;
  border-color: var(--epistemos-glass-border) !important;
  border-radius: var(--radius-md, 11px) !important;
  box-shadow: var(--epistemos-control-shadow) !important;
}

.goose-epistemos :is(button, [role='button'], [role='tab'], [role='menuitem'], [role='option']) {
  border-radius: 8px;
  transition-duration: 180ms;
  transition-timing-function: var(--epistemos-control-ease);
}

.goose-epistemos :is(input, textarea, select) {
  border-radius: 8px;
  background-color: var(--epistemos-glass-fill) !important;
  transition-duration: 180ms;
  transition-timing-function: var(--epistemos-control-ease);
}

.goose-epistemos :is(.font-mono) {
  font-family: var(--font-sans), -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
}

.goose-epistemos :is(code, pre, kbd, samp, .bg-inline-code, .prose code, .prose pre, [data-code]) {
  font-family: var(--font-mono), ui-monospace, "SF Mono", Menlo, monospace !important;
}

.goose-epistemos .select__menu {
  box-shadow: var(--epistemos-popover-shadow) !important;
}

.goose-epistemos .goose-user-message-bubble {
  border-color: color-mix(in srgb, var(--epistemos-accent) 62%, var(--epistemos-glass-border)) !important;
}

.goose-epistemos .goose-message {
  border-left-color: color-mix(in srgb, var(--epistemos-accent) 34%, var(--color-border-secondary)) !important;
}

@media (prefers-reduced-motion: reduce) {
  .goose-epistemos *,
  .goose-epistemos *::before,
  .goose-epistemos *::after {
    transition-duration: 0.01ms !important;
  }
}
`;
  }
  if (!source.includes(focusPolishMarker)) {
    source += `

/* ==========================================================================
   Epistemos native scrollbar + focus polish (${focusPolishMarker})
   These are global "web tells": Goose used custom hidden scrollbars and chunky
   focus outlines. Restore the WKWebView/system scrollbar path and use a quiet,
   token-driven focus inset that cannot fall back to the old blue OS ring.
   ========================================================================== */
.goose-epistemos,
.goose-epistemos :is(
  [data-radix-scroll-area-viewport],
  .overflow-auto,
  .overflow-scroll,
  .overflow-x-auto,
  .overflow-y-auto
) {
  --epistemos-native-scrollbar-focus-polish: 1;
  scrollbar-width: auto !important;
  scrollbar-color: auto !important;
}

.goose-epistemos::-webkit-scrollbar,
.goose-epistemos *::-webkit-scrollbar {
  display: initial !important;
  width: initial !important;
  height: initial !important;
  background: initial !important;
}

.goose-epistemos::-webkit-scrollbar-thumb,
.goose-epistemos *::-webkit-scrollbar-thumb,
.goose-epistemos::-webkit-scrollbar-track,
.goose-epistemos *::-webkit-scrollbar-track,
.goose-epistemos::-webkit-scrollbar-corner,
.goose-epistemos *::-webkit-scrollbar-corner {
  background: initial !important;
  border: initial !important;
  border-radius: initial !important;
  box-shadow: initial !important;
}

.goose-epistemos :is(
  button,
  [href],
  input,
  textarea,
  select,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  [tabindex]:not([tabindex='-1'])
):focus,
.goose-epistemos :is(
  button,
  [href],
  input,
  textarea,
  select,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  [tabindex]:not([tabindex='-1'])
):focus-visible {
  outline: none !important;
  outline-offset: 0 !important;
  box-shadow: none !important;
  background-color: color-mix(in srgb, var(--epistemos-accent) 7%, var(--epistemos-glass-fill)) !important;
}

.goose-epistemos :is(input, textarea, select):focus-visible {
  border-color: transparent !important;
}
`;
  }
  if (!source.includes(primitivePolishMarker)) {
    source += `

/* ==========================================================================
   Epistemos native primitive polish (${primitivePolishMarker})
   Research-backed retheme layer for Goose's shadcn/Radix primitives. This
   keeps Goose's components intact while matching the native frame's Apple
   tokens, 11px radius scale, vibrancy fills, accent focus, and compact control
   metrics.
   ========================================================================== */
.goose-epistemos {
  --epistemos-native-primitive-polish: 1;
}

.goose-epistemos [data-slot='button'],
.goose-epistemos :is(button, [role='button']):not([data-radix-scroll-area-corner]) {
  min-height: 28px;
  border-radius: 8px !important;
  font-family: var(--font-sans), -apple-system, BlinkMacSystemFont, system-ui, sans-serif !important;
  font-weight: 600;
}

.goose-epistemos [data-slot='button']:not(:disabled):active,
.goose-epistemos :is(button, [role='button']):not(:disabled):active {
  transform: scale(0.985);
}

.goose-epistemos [data-slot='card'],
.goose-epistemos :is(
  [data-slot='dialog-content'],
  [data-slot='dropdown-menu-content'],
  [data-slot='dropdown-menu-sub-content'],
  .select__menu,
  .goose-chat-input-card,
  .fixed.z-50.bg-background-primary.border.border-border-primary
) {
  -webkit-backdrop-filter: blur(24px) saturate(1.5);
  backdrop-filter: blur(24px) saturate(1.5);
  background-color: var(--epistemos-glass-fill-strong) !important;
  border-color: var(--epistemos-glass-border) !important;
  border-radius: var(--radius-md, 11px) !important;
  box-shadow: var(--epistemos-popover-shadow) !important;
}

.goose-epistemos [data-slot='card-title'],
.goose-epistemos [data-slot='dialog-title'] {
  font-family: var(--font-sans), -apple-system, BlinkMacSystemFont, system-ui, sans-serif !important;
  font-weight: 600 !important;
  letter-spacing: 0 !important;
}

.goose-epistemos [data-slot='dropdown-menu-item'],
.goose-epistemos [data-slot='dropdown-menu-checkbox-item'],
.goose-epistemos [data-slot='dropdown-menu-radio-item'],
.goose-epistemos [data-slot='dropdown-menu-sub-trigger'] {
  border-radius: 6px !important;
  min-height: 26px;
}

.goose-epistemos :is(
  [data-slot='dropdown-menu-item'],
  [data-slot='dropdown-menu-checkbox-item'],
  [data-slot='dropdown-menu-radio-item'],
  [data-slot='dropdown-menu-sub-trigger']
):focus {
  background-color: var(--epistemos-accent) !important;
  color: var(--color-text-inverse) !important;
}

.goose-epistemos :is(input, textarea, [contenteditable='true']) {
  font-family: var(--font-sans), -apple-system, BlinkMacSystemFont, system-ui, sans-serif !important;
  border-radius: 8px !important;
}

.goose-epistemos :is(.text-xs, .text-sm, .text-base, .font-mono) {
  letter-spacing: 0 !important;
}
`;
  }
  if (!source.includes(surfacePolishMarker)) {
    source += `

/* ==========================================================================
   Epistemos native surface polish (${surfacePolishMarker})
   Real Goose screen retheme: chat, tool calls, hub, session/list cards, mention
   popovers, and hosted MCP app frames. This keeps upstream Goose structure
   intact while removing the flat web-shell tells from the visible product path.
   ========================================================================== */
.goose-epistemos {
  --epistemos-native-surface-polish: 1;
}

.goose-epistemos .goose-chat-input-card {
  border-radius: 16px !important;
  background:
    linear-gradient(
      180deg,
      color-mix(in srgb, var(--color-background-primary) 88%, transparent),
      color-mix(in srgb, var(--color-background-secondary) 62%, transparent)
    ) !important;
  box-shadow: 0 18px 46px rgba(0, 0, 0, 0.10) !important;
}

.dark .goose-epistemos .goose-chat-input-card {
  box-shadow: 0 20px 54px rgba(0, 0, 0, 0.34) !important;
}

.goose-epistemos .goose-message {
  width: min(88%, 900px) !important;
}

.goose-epistemos :is(.goose-tool-call, .goose-message-content, .goose-message-tool) {
  border-radius: 14px !important;
  background-color: var(--epistemos-glass-fill-muted) !important;
  box-shadow: 0 10px 28px rgba(0, 0, 0, 0.07) !important;
}

.dark .goose-epistemos :is(.goose-tool-call, .goose-message-content, .goose-message-tool) {
  box-shadow: 0 12px 30px rgba(0, 0, 0, 0.24) !important;
}

.goose-epistemos .goose-tool-call > :first-child,
.goose-epistemos .goose-message-content > :first-child {
  border-top-left-radius: 14px;
  border-top-right-radius: 14px;
}

.goose-epistemos .prose {
  color: var(--color-text-primary);
}

.goose-epistemos .prose :is(p, li) {
  line-height: 1.58;
}

.goose-epistemos .prose :is(pre, table) {
  border: 0 !important;
  border-radius: 12px;
  background-color: color-mix(in srgb, var(--color-background-secondary) 74%, transparent) !important;
}

.goose-epistemos .prose code:not(pre code) {
  border: 0 !important;
  border-radius: 5px;
  padding: 1px 4px;
  background-color: color-mix(in srgb, var(--color-background-secondary) 72%, transparent);
}

.goose-epistemos :is(
  .mcp-app-container,
  .fixed.z-\\[900\\],
  [class*='rounded-\\[6px\\]'][class*='border-border-primary']
) {
  border-radius: 14px !important;
}

.goose-epistemos :is(.Toastify__toast, [role='status']) {
  -webkit-backdrop-filter: blur(24px) saturate(1.5);
  backdrop-filter: blur(24px) saturate(1.5);
  background-color: var(--epistemos-glass-fill-strong) !important;
  border: 0 !important;
  border-radius: 12px !important;
  box-shadow: var(--epistemos-popover-shadow) !important;
}
`;
  }
  if (!source.includes(catalogPolishMarker)) {
    source += `

/* ==========================================================================
   Epistemos native catalog/screen polish (${catalogPolishMarker})
   The visible Goose utility screens keep their upstream behavior and routes, but
   use the same transparent-over-glass card, list, badge, and header language as
   the native frame.
   ========================================================================== */
.goose-epistemos {
  --epistemos-native-catalog-screen-polish: 1;
}

.goose-epistemos :is(.ep-native-screen-card, .ep-native-list-card) {
  -webkit-backdrop-filter: blur(22px) saturate(1.45);
  backdrop-filter: blur(22px) saturate(1.45);
  background-color: var(--epistemos-glass-fill) !important;
  border-color: var(--epistemos-glass-border) !important;
  border-radius: 14px !important;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.07) !important;
}

.dark .goose-epistemos :is(.ep-native-screen-card, .ep-native-list-card) {
  box-shadow: 0 12px 34px rgba(0, 0, 0, 0.24) !important;
}

.goose-epistemos .ep-native-list-card {
  transition:
    background-color 180ms var(--epistemos-control-ease),
    border-color 180ms var(--epistemos-control-ease),
    box-shadow 180ms var(--epistemos-control-ease),
    transform 180ms var(--epistemos-control-ease);
}

.goose-epistemos .ep-native-list-card:hover {
  background-color: var(--epistemos-glass-fill-strong) !important;
  border-color: color-mix(in srgb, var(--epistemos-accent) 34%, var(--epistemos-glass-border)) !important;
  transform: translateY(-1px);
}

.goose-epistemos .ep-native-header-band {
  -webkit-backdrop-filter: blur(24px) saturate(1.5);
  backdrop-filter: blur(24px) saturate(1.5);
  background:
    linear-gradient(
      180deg,
      color-mix(in srgb, var(--color-background-primary) 72%, transparent),
      color-mix(in srgb, var(--color-background-secondary) 42%, transparent)
    ) !important;
  border-color: var(--epistemos-glass-border) !important;
}

.goose-epistemos .ep-native-badge {
  border-radius: 9999px !important;
  border-color: var(--epistemos-glass-border) !important;
  background-color: color-mix(in srgb, var(--color-background-secondary) 68%, transparent) !important;
  font-family: var(--font-sans), -apple-system, BlinkMacSystemFont, system-ui, sans-serif !important;
  font-weight: 600;
  letter-spacing: 0 !important;
}
`;
  }
  if (!source.includes(loadingErrorPolishMarker)) {
    source += `

/* ==========================================================================
   Epistemos native loading/error polish (${loadingErrorPolishMarker})
   Crash, suspense, and streaming-loading fallbacks must use the same tokenized
   glass language as the rest of the reskinned WebView.
   ========================================================================== */
.goose-epistemos {
  --epistemos-native-loading-error-polish: 1;
}

.goose-epistemos .ep-native-loading-dot {
  display: inline-block;
  width: 8px !important;
  height: 8px !important;
  flex: 0 0 auto;
  border: 0 !important;
  border-radius: 9999px !important;
  background-color: var(--epistemos-accent) !important;
  box-shadow:
    0 0 0 3px color-mix(in srgb, var(--epistemos-accent) 16%, transparent),
    0 0 18px color-mix(in srgb, var(--epistemos-accent) 24%, transparent);
}

.goose-epistemos .ep-native-loading-dot.is-active,
.goose-epistemos .ep-native-loading-dot.animate-pulse {
  animation: epistemos-native-breathe 1.25s var(--epistemos-control-ease) infinite;
}

.goose-epistemos .ep-native-status-line {
  font-family: var(--font-sans), -apple-system, BlinkMacSystemFont, system-ui, sans-serif !important;
  font-weight: 500;
  letter-spacing: 0 !important;
  text-transform: none !important;
}

.goose-epistemos .ep-native-error-shell {
  background:
    radial-gradient(
      circle at 50% 38%,
      color-mix(in srgb, var(--color-background-primary) 72%, transparent),
      transparent 56%
    );
}

.goose-epistemos .ep-native-error-card {
  -webkit-backdrop-filter: blur(26px) saturate(1.5);
  backdrop-filter: blur(26px) saturate(1.5);
  background-color: var(--epistemos-glass-fill-strong) !important;
  border-color: var(--epistemos-glass-border) !important;
  border-radius: 18px !important;
  box-shadow: var(--epistemos-popover-shadow) !important;
}

.goose-epistemos .ep-native-error-icon {
  border-color: color-mix(in srgb, var(--color-text-danger) 30%, var(--epistemos-glass-border)) !important;
  border-radius: 9999px !important;
  background-color: color-mix(in srgb, var(--color-background-danger) 72%, transparent) !important;
}

@keyframes epistemos-native-breathe {
  0%,
  100% {
    opacity: 0.56;
    transform: scale(0.82);
  }
  50% {
    opacity: 1;
    transform: scale(1);
  }
}
`;
  }
  if (!source.includes(motionPolishMarker)) {
    source += `

/* ==========================================================================
   Epistemos native motion polish (${motionPolishMarker})
   Uses Goose's existing framer-motion/CSS stack; keep motion small, fast, and
   transform/opacity-based so WebView content tracks the native frame.
   ========================================================================== */
.goose-epistemos {
  --epistemos-native-motion-polish: 1;
}

.goose-epistemos .page-transition {
  opacity: 1;
  animation: epistemos-native-page-enter 220ms var(--epistemos-control-ease) both;
  transform-origin: center top;
}

@keyframes epistemos-native-page-enter {
  from {
    opacity: 0;
    transform: translate3d(0, 4px, 0) scale(0.996);
  }
  to {
    opacity: 1;
    transform: translate3d(0, 0, 0) scale(1);
  }
}
`;
  }
  if (!source.includes(flatPolishMarker)) {
    source += `

/* ==========================================================================
   Epistemos high-quality flat polish (${flatPolishMarker})
   Final visual layer: Goose remains the product UI, edge-to-edge in the native
   window. Surfaces separate by spacing, tint, and state, not hard boxes.
   ========================================================================== */
.goose-epistemos {
  --epistemos-native-high-quality-flat-polish: 1;
  --epistemos-flat-app-bg: var(--color-background-primary);
  --epistemos-flat-surface: color-mix(in srgb, var(--color-background-secondary) 58%, var(--color-background-primary));
  --epistemos-flat-surface-strong: color-mix(in srgb, var(--color-background-secondary) 76%, var(--color-background-primary));
  --epistemos-flat-hover: color-mix(in srgb, var(--color-background-secondary) 88%, var(--color-background-primary));
  --epistemos-flat-separator: color-mix(in srgb, var(--color-text-primary) 8%, transparent);
  --epistemos-flat-focus: color-mix(in srgb, var(--epistemos-accent) 34%, transparent);
  --epistemos-control-shadow: none;
  --epistemos-popover-shadow: 0 18px 56px rgba(0, 0, 0, 0.12);
  background: var(--epistemos-flat-app-bg) !important;
}

.dark,
.dark .goose-epistemos {
  --epistemos-flat-surface: color-mix(in srgb, var(--color-background-secondary) 42%, var(--color-background-primary));
  --epistemos-flat-surface-strong: color-mix(in srgb, var(--color-background-secondary) 60%, var(--color-background-primary));
  --epistemos-flat-hover: color-mix(in srgb, var(--color-background-secondary) 72%, var(--color-background-primary));
  --epistemos-flat-separator: color-mix(in srgb, white 10%, transparent);
  --epistemos-popover-shadow: 0 18px 56px rgba(0, 0, 0, 0.32);
}

html,
body,
#root,
.goose-epistemos {
  min-height: 100%;
  background-color: var(--epistemos-flat-app-bg) !important;
}

.goose-epistemos :is(
  .bg-background-primary,
  .bg-background-secondary,
  .bg-background-tertiary,
  .bg-background-default
) {
  background-color: transparent !important;
}

.goose-epistemos :is(
  [class*='border-border'],
  [class*='border-primary'],
  [class*='border-secondary'],
  [class*='border-tertiary'],
  [class*='border-borderSubtle'],
  .border,
  .border-t,
  .border-r,
  .border-b,
  .border-l,
  [data-slot='card'],
  [data-slot='dialog-content'],
  [data-slot='dropdown-menu-content'],
  [data-slot='dropdown-menu-sub-content'],
  .select__menu,
  .goose-chat-input-card,
  .goose-user-message-bubble,
  .goose-message-content,
  .goose-message-tool,
  .ep-native-screen-card,
  .ep-native-list-card,
  .ep-native-error-card,
  .ep-native-badge,
  .mcp-app-container,
  [role='dialog'],
  [role='status'],
  [data-radix-popper-content-wrapper] > *
) {
  border-color: transparent !important;
  outline-color: transparent !important;
  box-shadow: none !important;
}

.goose-epistemos :is(
  .goose-chat-input-card,
  .goose-user-message-bubble,
  .goose-message-content,
  .goose-message-tool,
  .ep-native-screen-card,
  .ep-native-list-card,
  [data-slot='card']
) {
  -webkit-backdrop-filter: none !important;
  backdrop-filter: none !important;
  background: var(--epistemos-flat-surface) !important;
}

.goose-epistemos :is(
  [role='dialog'],
  [data-slot='dialog-content'],
  [data-slot='dropdown-menu-content'],
  [data-slot='dropdown-menu-sub-content'],
  .select__menu,
  [data-radix-popper-content-wrapper] > *
) {
  -webkit-backdrop-filter: none !important;
  backdrop-filter: none !important;
  background: var(--epistemos-flat-app-bg) !important;
  box-shadow: var(--epistemos-popover-shadow) !important;
}

.goose-epistemos :is(
  button,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  .ep-native-list-card
):not(:disabled):hover {
  background-color: var(--epistemos-flat-hover) !important;
}

.goose-epistemos :is(
  input,
  textarea,
  select,
  [contenteditable='true']
) {
  border-color: transparent !important;
  outline: none !important;
  background-color: var(--epistemos-flat-surface) !important;
  box-shadow: none !important;
}

.goose-epistemos :is(
  button,
  [href],
  input,
  textarea,
  select,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  [tabindex]:not([tabindex='-1'])
):focus,
.goose-epistemos :is(
  button,
  [href],
  input,
  textarea,
  select,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  [tabindex]:not([tabindex='-1'])
):focus-visible {
  outline: none !important;
  background-color: color-mix(in srgb, var(--epistemos-accent) 7%, var(--epistemos-flat-surface)) !important;
  box-shadow: none !important;
}

.goose-epistemos :is(
  .divide-y > :not([hidden]) ~ :not([hidden]),
  .border-t,
  .border-b,
  [data-orientation='horizontal']
) {
  border-color: var(--epistemos-flat-separator) !important;
}

.goose-epistemos :is(.goose-message, .goose-message-content, .goose-message-tool) {
  max-width: min(900px, 92vw) !important;
}

.goose-epistemos .goose-chat-input-card {
  border-radius: 18px !important;
}

.goose-epistemos :is(.shadow-sm, .shadow, .shadow-md, .shadow-lg, .shadow-xl, .shadow-2xl) {
  box-shadow: none !important;
}
`;
  }
  if (!source.includes(claudePixelPolishMarker)) {
    source += `

/* ==========================================================================
   Epistemos Claude-like pixel polish (${claudePixelPolishMarker})
   Visual target: Claude's calm single-sidebar app shell, adapted to Goose and
   Epistemos with a small pixel-art accent layer. No duplicate native nav rail.
   ========================================================================== */
:root,
.goose-epistemos {
  --epistemos-native-claude-pixel-polish: 1;
  --epistemos-pixel-font: "ChonkyPixels", "MatrixTypeDisplay", "MatrixTypeDisplay-Bold", "SF Mono", ui-monospace, Menlo, monospace;
  --epistemos-claude-bg: var(--color-background-primary);
  --epistemos-claude-sidebar: color-mix(in srgb, var(--color-background-secondary) 72%, var(--color-background-primary));
  --epistemos-claude-sidebar-strong: color-mix(in srgb, var(--color-background-secondary) 92%, var(--color-background-primary));
  --epistemos-claude-surface: color-mix(in srgb, var(--color-background-secondary) 58%, var(--color-background-primary));
  --epistemos-claude-surface-strong: color-mix(in srgb, var(--color-background-secondary) 78%, var(--color-background-primary));
  --epistemos-claude-hover: color-mix(in srgb, var(--color-background-secondary) 88%, var(--color-background-primary));
  --epistemos-claude-text: var(--color-text-primary);
  --epistemos-claude-muted: var(--color-text-secondary);
  --epistemos-claude-hairline: color-mix(in srgb, var(--color-text-primary) 8%, transparent);
  --epistemos-claude-soft-shadow-color: color-mix(in srgb, var(--color-text-primary) 8%, transparent);
  --epistemos-claude-soft-shadow: 0 18px 44px var(--epistemos-claude-soft-shadow-color);
  --epistemos-pixel-accent: var(--epistemos-accent);
  --epistemos-flat-app-bg: var(--epistemos-claude-bg);
  --epistemos-flat-surface: var(--epistemos-claude-surface);
  --epistemos-flat-hover: var(--epistemos-claude-hover);
  --epistemos-flat-separator: var(--epistemos-claude-hairline);
  background-color: var(--epistemos-claude-bg) !important;
  color: var(--epistemos-claude-text) !important;
}

.dark,
.dark .goose-epistemos {
  --epistemos-claude-sidebar: color-mix(in srgb, var(--color-background-secondary) 54%, var(--color-background-primary));
  --epistemos-claude-sidebar-strong: color-mix(in srgb, var(--color-background-secondary) 70%, var(--color-background-primary));
  --epistemos-claude-surface: color-mix(in srgb, var(--color-background-secondary) 44%, var(--color-background-primary));
  --epistemos-claude-surface-strong: color-mix(in srgb, var(--color-background-secondary) 62%, var(--color-background-primary));
  --epistemos-claude-hover: color-mix(in srgb, var(--color-background-secondary) 72%, var(--color-background-primary));
  --epistemos-claude-hairline: color-mix(in srgb, var(--color-text-primary) 10%, transparent);
  --epistemos-claude-soft-shadow-color: color-mix(in srgb, var(--color-background-inverse) 28%, transparent);
}

html,
body,
#root,
.goose-epistemos {
  background: var(--epistemos-claude-bg) !important;
}

.goose-epistemos {
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", system-ui, sans-serif !important;
}

.goose-epistemos :is(main, [role='main']) {
  background: var(--epistemos-claude-bg) !important;
  color: var(--epistemos-claude-text) !important;
}

.goose-epistemos :is(
  aside,
  nav[class*='sidebar'],
  [class*='Sidebar'],
  [class*='sidebar'],
  [data-sidebar],
  [data-slot='sidebar']
) {
  background: var(--epistemos-claude-sidebar) !important;
  border-color: transparent !important;
  box-shadow: none !important;
}

.goose-epistemos :is(
  .goose-chat-input-card,
  [data-slot='card'],
  .goose-user-message-bubble,
  .goose-message-content,
  .goose-message-tool,
  .ep-native-screen-card,
  .ep-native-list-card
) {
  background: var(--epistemos-claude-surface) !important;
  border-color: transparent !important;
  border-width: 0 !important;
  box-shadow: none !important;
}

.goose-epistemos .goose-chat-input-card {
  border-radius: 18px !important;
  background: var(--epistemos-claude-bg) !important;
  box-shadow: var(--epistemos-claude-soft-shadow) !important;
}

.goose-epistemos :is(
  button,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option']
) {
  border-color: transparent !important;
  border-width: 0 !important;
  box-shadow: none !important;
  color: inherit;
}

.goose-epistemos :is(
  button,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option']
):not(:disabled):hover {
  background: var(--epistemos-claude-hover) !important;
}

.goose-epistemos :is(
  input,
  textarea,
  select,
  [contenteditable='true']
) {
  background: var(--epistemos-claude-surface) !important;
  border-color: transparent !important;
  border-width: 0 !important;
  outline: none !important;
  box-shadow: none !important;
  color: var(--epistemos-claude-text) !important;
}

.goose-epistemos :is(
  button,
  [href],
  input,
  textarea,
  select,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  [tabindex]:not([tabindex='-1'])
):focus,
.goose-epistemos :is(
  button,
  [href],
  input,
  textarea,
  select,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  [tabindex]:not([tabindex='-1'])
):focus-visible {
  outline: none !important;
  background: color-mix(in srgb, var(--epistemos-pixel-accent) 7%, var(--epistemos-claude-surface)) !important;
  box-shadow: none !important;
}

.goose-epistemos .goose-chat-input-card:focus-within {
  outline: none !important;
  background: color-mix(in srgb, var(--epistemos-pixel-accent) 5%, var(--epistemos-claude-bg)) !important;
  box-shadow: 0 16px 42px var(--epistemos-claude-soft-shadow-color) !important;
}

.goose-epistemos :is(
  [role='dialog'],
  [data-slot='dialog-content'],
  [data-slot='dropdown-menu-content'],
  [data-slot='dropdown-menu-sub-content'],
  .select__menu,
  [data-radix-popper-content-wrapper] > *
) {
  background: var(--epistemos-claude-bg) !important;
  border-color: transparent !important;
  border-width: 0 !important;
  box-shadow: var(--epistemos-claude-soft-shadow) !important;
}

.goose-epistemos :is(.text-text-secondary, .text-text-tertiary, .text-muted-foreground) {
  color: var(--epistemos-claude-muted) !important;
}

.goose-epistemos :is(
  .divide-y > :not([hidden]) ~ :not([hidden]),
  .border-t,
  .border-b,
  .border-l,
  .border-r,
  [data-orientation='horizontal']
) {
  border-color: transparent !important;
  border-width: 0 !important;
}

.goose-epistemos :is(.border, .border-border-primary, .border-border-secondary, .border-border-subtle, .border-border-danger, .border-border-warning, .border-border-success) {
  border-color: transparent !important;
  border-width: 0 !important;
}

.goose-epistemos .border-t {
  border-top-width: 0 !important;
}

.goose-epistemos .border-b {
  border-bottom-width: 0 !important;
}

.goose-epistemos .border-l {
  border-left-width: 0 !important;
}

.goose-epistemos .border-r {
  border-right-width: 0 !important;
}

.goose-epistemos :is(
  h1,
  .ep-native-section-label,
  .ep-native-window-title,
  .ep-native-companion,
  [data-epistemos-pixel-heading],
  [data-epistemos-section-label],
  [data-epistemos-window-title],
  [data-epistemos-companion],
  [class*='section-label'],
  [class*='SectionLabel'],
  [class*='window-title'],
  [class*='WindowTitle'],
  [class*='companion-mascot'],
  [class*='CompanionMascot']
) {
  font-family: var(--epistemos-pixel-font) !important;
  font-weight: 600 !important;
  letter-spacing: 0 !important;
  image-rendering: pixelated;
}

.goose-epistemos :is(.ep-native-loading-dot, [class*='status'] [class*='dot']) {
  border-radius: 2px !important;
  background: var(--epistemos-pixel-accent) !important;
  image-rendering: pixelated;
}

.goose-epistemos :is(svg, img).epistemos-pixel-accent,
.goose-epistemos [data-epistemos-pixel-accent] {
  image-rendering: pixelated;
}
`;
  }
  if (!source.includes(claudePixelContractMarker)) {
    source += `

/* ==========================================================================
   Epistemos final Claude/pixel visual contract (${claudePixelContractMarker})
   This is the last visual layer on purpose. Older native/glass staging helpers
   may still add Tailwind classes for borders, shadows, rings, or backdrop blur;
   the product contract is Claude-like flat: single Goose sidebar, quiet canvas,
   borderless controls, no blue OS focus outline, and only a small pixel accent.
   ========================================================================== */
.goose-epistemos {
  --epistemos-native-claude-pixel-contract: 1;
  --epistemos-claude-bg: var(--color-background-primary);
  --epistemos-claude-sidebar: color-mix(in srgb, var(--color-background-secondary) 74%, var(--color-background-primary));
  --epistemos-claude-surface: color-mix(in srgb, var(--color-background-secondary) 46%, var(--color-background-primary));
  --epistemos-claude-surface-strong: color-mix(in srgb, var(--color-background-secondary) 66%, var(--color-background-primary));
  --epistemos-claude-hover: color-mix(in srgb, var(--color-background-secondary) 86%, var(--color-background-primary));
  --epistemos-claude-active: color-mix(in srgb, var(--epistemos-pixel-accent) 11%, var(--epistemos-claude-surface-strong));
  --epistemos-claude-soft-shadow: 0 12px 30px color-mix(in srgb, var(--color-text-primary) 4%, transparent);
  background: var(--epistemos-claude-bg) !important;
  color: var(--color-text-primary) !important;
  letter-spacing: 0 !important;
}

.dark .goose-epistemos {
  --epistemos-claude-sidebar: color-mix(in srgb, var(--color-background-secondary) 58%, var(--color-background-primary));
  --epistemos-claude-surface: color-mix(in srgb, var(--color-background-secondary) 34%, var(--color-background-primary));
  --epistemos-claude-surface-strong: color-mix(in srgb, var(--color-background-secondary) 52%, var(--color-background-primary));
  --epistemos-claude-hover: color-mix(in srgb, var(--color-background-secondary) 68%, var(--color-background-primary));
  --epistemos-claude-soft-shadow: 0 14px 34px color-mix(in srgb, black 20%, transparent);
}

html,
body,
#root,
.goose-epistemos,
.goose-epistemos :is(main, [role='main']) {
  background: var(--epistemos-claude-bg) !important;
}

.goose-epistemos,
.goose-epistemos * {
  letter-spacing: 0 !important;
}

.goose-epistemos :is(
  [class*='backdrop-blur'],
  [class*='backdrop-filter'],
  .backdrop-blur,
  .backdrop-blur-sm,
  .backdrop-blur-md,
  .backdrop-blur-lg,
  .backdrop-blur-xl
) {
  -webkit-backdrop-filter: none !important;
  backdrop-filter: none !important;
}

.goose-epistemos :is(
  [class*='shadow'],
  .shadow,
  .shadow-sm,
  .shadow-md,
  .shadow-lg,
  .shadow-xl,
  .shadow-2xl
) {
  box-shadow: none !important;
}

.goose-epistemos :is(
  [class*='border'],
  .border,
  .border-t,
  .border-r,
  .border-b,
  .border-l,
  .divide-y > :not([hidden]) ~ :not([hidden]),
  [data-orientation='horizontal'],
  [data-orientation='vertical']
) {
  border-color: transparent !important;
  outline-color: transparent !important;
}

.goose-epistemos :is(
  .border,
  .border-t,
  .border-r,
  .border-b,
  .border-l
) {
  border-width: 0 !important;
}

.goose-epistemos :is(
  aside,
  nav[class*='sidebar'],
  [class*='Sidebar'],
  [class*='sidebar'],
  [data-sidebar],
  [data-slot='sidebar'],
  .bg-background-secondary
) {
  background: var(--epistemos-claude-sidebar) !important;
}

.goose-epistemos :is(
  .bg-background-primary,
  .bg-background-default
) {
  background: transparent !important;
}

.goose-epistemos .bg-background-tertiary {
  background: var(--epistemos-claude-active) !important;
}

.goose-epistemos :is(
  button,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  input,
  textarea,
  select,
  [contenteditable='true']
) {
  border-color: transparent !important;
  border-width: 0 !important;
  outline: none !important;
  box-shadow: none !important;
  --tw-ring-color: transparent !important;
  --tw-ring-offset-color: transparent !important;
  --tw-ring-shadow: 0 0 #0000 !important;
  --tw-ring-offset-shadow: 0 0 #0000 !important;
}

.goose-epistemos :is(input, textarea, select, [contenteditable='true']) {
  background: var(--epistemos-claude-surface) !important;
  color: var(--color-text-primary) !important;
}

.goose-epistemos :is(
  button,
  [href],
  input,
  textarea,
  select,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  [tabindex]:not([tabindex='-1'])
):focus,
.goose-epistemos :is(
  button,
  [href],
  input,
  textarea,
  select,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  [tabindex]:not([tabindex='-1'])
):focus-visible {
  outline: none !important;
  outline-offset: 0 !important;
  box-shadow: none !important;
  --tw-ring-color: transparent !important;
  --tw-ring-offset-color: transparent !important;
  --tw-ring-shadow: 0 0 #0000 !important;
  --tw-ring-offset-shadow: 0 0 #0000 !important;
  background: var(--epistemos-claude-active) !important;
}

.goose-epistemos :is(
  button,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option']
):not(:disabled):hover {
  background: var(--epistemos-claude-hover) !important;
}

.goose-epistemos :is(
  .goose-chat-input-card,
  .goose-user-message-bubble,
  .goose-message-content,
  .goose-message-tool,
  .goose-tool-call,
  .ep-native-screen-card,
  .ep-native-list-card,
  [data-slot='card']
) {
  -webkit-backdrop-filter: none !important;
  backdrop-filter: none !important;
  background: var(--epistemos-claude-surface) !important;
  border-color: transparent !important;
  border-width: 0 !important;
  box-shadow: none !important;
}

.goose-epistemos .goose-chat-input-card {
  background: color-mix(in srgb, var(--epistemos-claude-surface) 42%, var(--epistemos-claude-bg)) !important;
  border-radius: 18px !important;
  box-shadow: none !important;
}

.goose-epistemos .goose-chat-input-card:focus-within {
  outline: none !important;
  border-color: transparent !important;
  background: color-mix(in srgb, var(--epistemos-pixel-accent) 5%, var(--epistemos-claude-surface)) !important;
  box-shadow: none !important;
}

.goose-epistemos :is(
  [role='dialog'],
  [data-slot='dialog-content'],
  [data-slot='dropdown-menu-content'],
  [data-slot='dropdown-menu-sub-content'],
  .select__menu,
  [data-radix-popper-content-wrapper] > *
) {
  -webkit-backdrop-filter: none !important;
  backdrop-filter: none !important;
  background: var(--epistemos-claude-bg) !important;
  border-color: transparent !important;
  border-width: 0 !important;
  box-shadow: var(--epistemos-claude-soft-shadow) !important;
}

.goose-epistemos :is(
  .ep-display,
  .ep-pixel,
  .ep-native-section-label,
  .ep-native-window-title,
  .ep-native-companion,
  [data-epistemos-pixel-heading],
  [data-epistemos-section-label],
  [data-epistemos-window-title],
  [data-epistemos-companion],
  [class*='section-label'],
  [class*='SectionLabel'],
  [class*='window-title'],
  [class*='WindowTitle'],
  [class*='companion-mascot'],
  [class*='CompanionMascot']
) {
  font-family: var(--epistemos-pixel-font) !important;
  font-weight: 600 !important;
  letter-spacing: 0 !important;
  image-rendering: pixelated;
}

.goose-epistemos :is(h1, h2, h3, h4, h5, h6):not(.ep-display):not(.ep-pixel):not(.ep-native-section-label):not([data-epistemos-pixel-heading]):not([data-epistemos-section-label]):not([data-epistemos-window-title]):not([data-epistemos-companion]) {
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", system-ui, sans-serif !important;
}

.goose-epistemos :is(.ep-native-loading-dot, [class*='status'] [class*='dot']) {
  border-radius: 2px !important;
  background: var(--epistemos-pixel-accent) !important;
  box-shadow: none !important;
  image-rendering: pixelated;
}
`;
  }
  write('src/styles/main.css', source);
}

function applyButton() {
  let source = read('src/components/ui/button.tsx');
  source = replaceRequired(
    source,
    'button base chrome',
    `"inline-flex items-center justify-center gap-2 whitespace-nowrap text-sm transition-all cursor-pointer disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 shrink-0 [&_svg]:shrink-0 outline-none focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[1px] aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive"`,
    `"inline-flex items-center justify-center gap-2 whitespace-nowrap text-sm font-semibold transition-colors duration-200 ease-[var(--epistemos-control-ease)] cursor-pointer disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 shrink-0 [&_svg]:shrink-0 outline-none focus-visible:bg-[var(--epistemos-accent)]/10 focus-visible:ring-0 aria-invalid:bg-background-danger/30"`
  );
  source = replaceRequired(
    source,
    'button default variant',
    "default: 'bg-background-inverse text-text-inverse hover:bg-background-inverse/90 shadow-none'",
    "default: 'bg-[var(--epistemos-accent)] text-text-inverse hover:bg-[var(--epistemos-accent)]/90 shadow-none'"
  );
  source = replaceRequired(
    source,
    'button outline variant',
    "outline: 'border hover:bg-background-secondary'",
    "outline: 'bg-background-primary/45 hover:bg-background-secondary/75'"
  );
  source = replaceRequired(
    source,
    'button secondary variant',
    "secondary:\n          'bg-background-secondary text-text-primary hover:bg-background-secondary/80 shadow-none'",
    "secondary:\n          'bg-background-secondary/72 text-text-primary hover:bg-background-secondary/90 shadow-none'"
  );
  source = source.replaceAll("rounded-[5px]", "rounded-[8px]");
  write('src/components/ui/button.tsx', source);
}

function applyInput() {
  let source = read('src/components/ui/input.tsx');
  source = replaceRequired(
    source,
    'input native geometry',
    "'flex h-9 w-full rounded-[5px] border border-border-primary focus:border-border-secondary hover:border-border-secondary bg-background-primary px-3 py-1 text-sm transition-colors file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground placeholder:text-text-secondary placeholder:font-light focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50'",
    "'flex h-9 w-full rounded-[8px] bg-background-primary/60 px-3 py-1 text-sm transition-colors duration-200 ease-[var(--epistemos-control-ease)] file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground placeholder:text-text-secondary placeholder:font-light hover:bg-background-secondary/62 focus:bg-background-secondary/72 focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50'"
  );
  write('src/components/ui/input.tsx', source);
}

function applyCard() {
  let source = read('src/components/ui/card.tsx');
  source = replaceRequired(
    source,
    'card native glass',
    "'bg-background-primary text-text-primary flex flex-col gap-3 rounded-[6px] border border-border-secondary py-3 shadow-none'",
    "'bg-background-primary/58 text-text-primary flex flex-col gap-3 rounded-[11px] py-3 shadow-none'"
  );
  source = replaceRequired(
    source,
    'card title font',
    "return <div data-slot=\"card-title\" className={cn('leading-none font-mono text-sm', className)} {...props} />;",
    "return <div data-slot=\"card-title\" className={cn('leading-none font-sans text-sm font-semibold tracking-normal', className)} {...props} />;"
  );
  write('src/components/ui/card.tsx', source);
}

function applyDialog() {
  let source = read('src/components/ui/dialog.tsx');
  source = replaceRequired(
    source,
    'dialog overlay',
    "'data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed inset-0 z-40 bg-black/50'",
    "'data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed inset-0 z-40 bg-black/20'"
  );
  source = replaceRequired(
    source,
    'dialog content',
    "'bg-background-primary data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed top-[50%] left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] gap-4 rounded-[6px] border border-border-primary p-5 shadow-none duration-150 sm:max-w-lg'",
    "'bg-background-primary/92 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed top-[50%] left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] gap-4 rounded-[14px] p-5 duration-200 ease-[var(--epistemos-control-ease)] sm:max-w-lg'"
  );
  source = replaceRequired(
    source,
    'dialog close button',
    `DialogPrimitive.Close className="ring-offset-background p-1 hover:bg-background-secondary rounded-[4px] focus:ring-ring data-[state=open]:bg-background-secondary transition-all duration-150 data-[state=open]:text-text-secondary absolute top-4 right-4 opacity-70 hover:opacity-100 focus:ring-1 focus:outline-hidden disabled:pointer-events-none [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"`,
    `DialogPrimitive.Close className="p-1 hover:bg-background-secondary rounded-[8px] data-[state=open]:bg-background-secondary transition-all duration-150 data-[state=open]:text-text-secondary absolute top-4 right-4 opacity-70 hover:opacity-100 focus:outline-none disabled:pointer-events-none [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"`
  );
  source = replaceRequired(
    source,
    'dialog title font',
    "className={cn('text-base leading-none font-mono font-normal', className)}",
    "className={cn('text-base leading-none font-sans font-semibold tracking-normal', className)}"
  );
  write('src/components/ui/dialog.tsx', source);
}

function applyDropdownMenu() {
  let source = read('src/components/ui/dropdown-menu.tsx');
  source = replaceRequired(
    source,
    'dropdown content',
    "'bg-background-primary text-text-primary data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 z-50 max-h-(--radix-dropdown-menu-content-available-height) min-w-[8rem] origin-(--radix-dropdown-menu-content-transform-origin) overflow-x-hidden overflow-y-auto rounded-[6px] border border-border-primary p-1 shadow-none space-y-0.5'",
    "'bg-background-primary/92 text-text-primary data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 z-50 max-h-(--radix-dropdown-menu-content-available-height) min-w-[8rem] origin-(--radix-dropdown-menu-content-transform-origin) overflow-x-hidden overflow-y-auto rounded-[9px] p-1 space-y-0.5'"
  );
  source = source.replaceAll("rounded-sm px-2 py-1.5 text-sm", "rounded-[6px] px-2 py-1.5 text-sm");
  source = source.replaceAll("focus:bg-background-secondary focus:text-text-secondary", "focus:bg-[var(--epistemos-accent)] focus:text-text-inverse");
  source = replaceRequired(
    source,
    'dropdown sub content',
    "'bg-background-primary text-text-primary data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 z-50 min-w-[8rem] origin-(--radix-dropdown-menu-content-transform-origin) overflow-hidden rounded-[6px] border border-border-primary p-1 shadow-none'",
    "'bg-background-primary/92 text-text-primary data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 z-50 min-w-[8rem] origin-(--radix-dropdown-menu-content-transform-origin) overflow-hidden rounded-[9px] p-1'"
  );
  write('src/components/ui/dropdown-menu.tsx', source);
}

function applySwitch() {
  let source = read('src/components/ui/switch.tsx');
  source = replaceRequired(
    source,
    'switch root geometry',
    "'peer inline-flex h-[16px] w-[28px] shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:cursor-not-allowed disabled:opacity-50'",
    "'peer inline-flex h-[22px] w-[38px] shrink-0 cursor-pointer items-center rounded-full border-0 transition-[background-color,box-shadow] duration-200 ease-[var(--epistemos-control-ease)] focus-visible:outline-none focus-visible:ring-0 disabled:cursor-not-allowed disabled:opacity-50'"
  );
  source = replaceRequired(
    source,
    'switch default colors',
    "'data-[state=checked]:bg-background-primary data-[state=unchecked]:bg-input'",
    "'data-[state=checked]:bg-[var(--epistemos-accent)] data-[state=unchecked]:bg-border-secondary'"
  );
  source = replaceRequired(
    source,
    'switch mono colors',
    "'data-[state=checked]:bg-slate-900 dark:data-[state=checked]:bg-white data-[state=unchecked]:bg-slate-300 dark:data-[state=unchecked]:bg-slate-600'",
    "'data-[state=checked]:bg-[var(--epistemos-accent)] data-[state=unchecked]:bg-border-secondary'"
  );
  source = replaceRequired(
    source,
    'switch thumb geometry',
    "'pointer-events-none block h-3 w-3 rounded-full shadow-lg ring-0 transition-transform'",
    "'pointer-events-none block h-[18px] w-[18px] rounded-full bg-white shadow-[0_1px_2px_rgba(0,0,0,.25)] ring-0 transition-transform duration-200 ease-[var(--epistemos-control-ease)]'"
  );
  source = replaceRequired(
    source,
    'switch default thumb offsets',
    "'bg-background-primary data-[state=checked]:translate-x-3 data-[state=unchecked]:translate-x-0'",
    "'data-[state=checked]:translate-x-[18px] data-[state=unchecked]:translate-x-[2px]'"
  );
  source = replaceRequired(
    source,
    'switch mono thumb offsets',
    "'bg-white dark:data-[state=checked]:bg-black dark:data-[state=unchecked]:bg-white data-[state=checked]:translate-x-3 data-[state=unchecked]:translate-x-0'",
    "'data-[state=checked]:translate-x-[18px] data-[state=unchecked]:translate-x-[2px]'"
  );
  write('src/components/ui/switch.tsx', source);
}

function applyTabs() {
  let source = read('src/components/ui/tabs.tsx');
  source = replaceRequired(
    source,
    'tabs root',
    "'flex flex-col rounded-[6px] text-text-secondary'",
    "'flex flex-col rounded-[11px] text-text-secondary'"
  );
  source = replaceRequired(
    source,
    'tabs list',
    "'flex h-auto justify-start rounded-[6px] bg-background-primary p-1 text-muted-foreground gap-1'",
    "'flex h-auto justify-start rounded-[10px] bg-background-secondary/56 p-1 text-muted-foreground gap-1'"
  );
  source = replaceRequired(
    source,
    'tabs trigger',
    "'flex items-center justify-start whitespace-nowrap rounded-[5px] px-3 py-1.5 text-xs font-mono ring-offset-background transition-all focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 data-[state=active]:bg-background-secondary data-[state=active]:text-text-primary data-[state=active]:shadow-none hover:bg-background-secondary hover:text-text-primary'",
    "'flex items-center justify-start whitespace-nowrap rounded-[7px] px-3 py-1.5 text-xs font-sans transition-colors duration-200 ease-[var(--epistemos-control-ease)] focus-visible:outline-none disabled:pointer-events-none disabled:opacity-50 data-[state=active]:bg-background-primary/78 data-[state=active]:text-text-primary hover:bg-background-primary/68 hover:text-text-primary'"
  );
  write('src/components/ui/tabs.tsx', source);
}

function applySelect() {
  let source = read('src/components/ui/Select.tsx');
  source = replaceRequired(
    source,
    'select control',
    "`border ${isFocused ? 'border-border-primary' : 'border-border-primary'} focus:border-border-primary hover:border-border-primary rounded-md w-full px-4 py-2 text-sm text-text-secondary hover:cursor-pointer`",
    "`rounded-[8px] w-full px-3 py-1.5 min-h-9 text-sm text-text-secondary ${isFocused ? 'bg-background-secondary/72' : 'bg-background-primary/70'} hover:cursor-pointer hover:bg-background-secondary/72 transition-colors duration-200 ease-[var(--epistemos-control-ease)]`"
  );
  source = replaceRequired(
    source,
    'select menu',
    "'mt-1 bg-background-primary border border-border-primary rounded-[6px] text-text-secondary shadow-none select__menu z-[9999] absolute'",
    "'mt-1 bg-background-primary/92 rounded-[9px] text-text-secondary select__menu z-[9999] absolute overflow-hidden'"
  );
  source = replaceRequired(
    source,
    'select option selected',
    "classes += ' bg-background-inverse text-text-inverse pointer-events-auto';",
    "classes += ' bg-[var(--epistemos-accent)] text-text-inverse pointer-events-auto';"
  );
  source = replaceRequired(
    source,
    'select option focused',
    "classes += ' bg-background-secondary text-text-primary pointer-events-auto';",
    "classes += ' bg-background-secondary/85 text-text-primary pointer-events-auto';"
  );
  write('src/components/ui/Select.tsx', source);
}

function applyPrimitiveCompletionSurfaces() {
  let source = read('src/components/ui/Tooltip.tsx');
  source = replaceRequired(
    source,
    'tooltip native delay',
    'delayDuration = 0,',
    'delayDuration = 450,'
  );
  source = replaceRequired(
    source,
    'tooltip native offset',
    'sideOffset = 0,',
    'sideOffset = 6,'
  );
  source = replaceRequired(
    source,
    'tooltip native glass',
    "'bg-background-inverse text-text-inverse animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 z-[200] w-fit origin-(--radix-tooltip-content-transform-origin) rounded-md px-3 py-1.5 text-xs text-balance'",
    "'z-[200] w-fit origin-(--radix-tooltip-content-transform-origin) rounded-[8px] bg-background-primary/92 px-2.5 py-1.5 text-xs text-text-primary animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[side=bottom]:slide-in-from-top-1 data-[side=left]:slide-in-from-right-1 data-[side=right]:slide-in-from-left-1 data-[side=top]:slide-in-from-bottom-1'"
  );
  source = replaceRequired(
    source,
    'tooltip native arrow',
    "'bg-background-inverse fill-background-inverse z-[200] size-2.5 translate-y-[calc(-50%_-_2px)] rotate-45'",
    "'z-[200] size-2.5 translate-y-[calc(-50%_-_2px)] rotate-45 bg-background-primary/92 fill-background-primary'"
  );
  write('src/components/ui/Tooltip.tsx', source);

  source = read('src/components/ui/Pill.tsx');
  source = replaceRequired(
    source,
    'pill native base',
    "'inline-flex items-center justify-center rounded-[4px] transition-colors duration-150 font-mono uppercase tracking-normal'",
    "'inline-flex items-center justify-center rounded-full font-sans font-medium normal-case tracking-normal transition-colors duration-200 ease-[var(--epistemos-control-ease)]'"
  );
  source = replaceRequired(
    source,
    'pill default native',
    "default: 'bg-background-primary border border-border-primary hover:bg-background-secondary',",
    "default: 'bg-background-primary/58 hover:bg-background-secondary/72',"
  );
  source = replaceRequired(
    source,
    'pill glass native',
    "glass: 'bg-background-secondary border border-border-primary hover:bg-background-primary',",
    "glass: 'bg-background-secondary/62 hover:bg-background-primary/72',"
  );
  source = replaceRequired(
    source,
    'pill solid native',
    "solid: 'bg-background-primary border border-border-primary hover:bg-background-secondary',",
    "solid: 'bg-[var(--epistemos-accent)] text-text-inverse hover:bg-[var(--epistemos-accent)]/90',"
  );
  source = replaceRequired(
    source,
    'pill gradient native',
    "gradient: 'bg-background-inverse text-background-primary border border-background-inverse',",
    "gradient: 'bg-[var(--epistemos-accent)] text-text-inverse hover:bg-[var(--epistemos-accent)]/90',"
  );
  source = replaceRequired(
    source,
    'pill glow native',
    "glow: 'bg-background-inverse text-background-primary border border-background-inverse',",
    "glow: 'bg-[var(--epistemos-accent)]/12 text-text-primary hover:bg-background-secondary/72',"
  );
  write('src/components/ui/Pill.tsx', source);

  source = read('src/components/ui/skeleton.tsx');
  source = replaceRequired(
    source,
    'skeleton native shimmer',
    "className={cn('bg-background-secondary animate-pulse rounded-md', className)}",
    "className={cn('rounded-[10px] bg-background-secondary/70 animate-pulse', className)}"
  );
  write('src/components/ui/skeleton.tsx', source);

  source = read('src/components/ui/scroll-area.tsx');
  source = replaceRequired(
    source,
    'scroll area native root',
    "className={cn('relative overflow-hidden', className)}",
    "className={cn('relative overflow-hidden rounded-[inherit]', className)}"
  );
  source = replaceRequired(
    source,
    'scroll area native fade',
    "className={cn('absolute top-0 left-0 right-0 z-10 transition-all duration-200')}",
    "className={cn('pointer-events-none absolute left-0 right-0 top-0 z-10 transition-all duration-200 ease-[var(--epistemos-control-ease)]')}"
  );
  source = replaceRequired(
    source,
    'scrollbar native base',
    "'flex touch-none select-none transition-colors'",
    "'flex touch-none select-none transition-colors duration-200 ease-[var(--epistemos-control-ease)]'"
  );
  source = replaceRequired(
    source,
    'scrollbar native thumb',
    'className="relative flex-1 rounded-full bg-border-primary dark:bg-background-secondary"',
    'className="relative flex-1 rounded-full bg-border-tertiary/65 hover:bg-border-tertiary"'
  );
  write('src/components/ui/scroll-area.tsx', source);

  source = read('src/components/ui/separator.tsx');
  source = replaceRequired(
    source,
    'separator native hairline',
    "'bg-border-primary shrink-0 data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-px'",
    "'shrink-0 bg-border-secondary/80 data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-px'"
  );
  write('src/components/ui/separator.tsx', source);

  source = read('src/components/ui/collapsible.tsx');
  source = replaceRequired(
    source,
    'collapsible cn import',
    "import * as CollapsiblePrimitive from '@radix-ui/react-collapsible';",
    "import * as CollapsiblePrimitive from '@radix-ui/react-collapsible';\n\nimport { cn } from '../../utils';"
  );
  source = replaceRequired(
    source,
    'collapsible native content',
    `function CollapsibleContent({
  ...props
}: React.ComponentProps<typeof CollapsiblePrimitive.CollapsibleContent>) {
  return <CollapsiblePrimitive.CollapsibleContent data-slot="collapsible-content" {...props} />;
}`,
    `function CollapsibleContent({
  className,
  ...props
}: React.ComponentProps<typeof CollapsiblePrimitive.CollapsibleContent>) {
  return (
    <CollapsiblePrimitive.CollapsibleContent
      data-slot="collapsible-content"
      className={cn(
        'overflow-hidden transition-[height,opacity] duration-200 ease-[var(--epistemos-control-ease)] data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0',
        className
      )}
      {...props}
    />
  );
}`
  );
  write('src/components/ui/collapsible.tsx', source);

  source = read('src/components/ui/ConfirmationModal.tsx');
  source = replaceRequired(
    source,
    'confirmation modal native content sizing',
    'className="sm:max-w-[425px] max-h-[85vh] flex flex-col"',
    'className="flex max-h-[85vh] flex-col sm:max-w-[425px]"'
  );
  source = replaceRequired(
    source,
    'confirmation modal detail token',
    'className="overflow-y-auto min-h-0 text-sm text-text-muted break-all"',
    'className="min-h-0 overflow-y-auto break-all text-sm text-text-secondary"'
  );
  source = replaceAllRequired(
    source,
    'confirmation modal native focus ring',
    'className="focus-visible:ring-2 focus-visible:ring-background-accent focus-visible:ring-offset-2 focus-visible:ring-offset-background-default"',
    'className="focus-visible:bg-[var(--epistemos-accent)]/10 focus-visible:outline-none"'
  );
  write('src/components/ui/ConfirmationModal.tsx', source);
}

function applyMotionSurfaces() {
  let source = read('src/components/Layout/AppLayout.tsx');
  source = replaceRequired(
    source,
    'app layout native nav spring',
    "transition={{ type: 'spring', stiffness: 400, damping: 40 }}",
    "transition={{ type: 'spring', duration: 0.5, bounce: 0 }}"
  );
  write('src/components/Layout/AppLayout.tsx', source);

  source = read('src/components/Layout/NavigationPanel.tsx');
  source = replaceRequired(
    source,
    'navigation panel native fade spring',
    'transition={{ duration: 0.15 }}',
    "transition={{ type: 'spring', duration: 0.5, bounce: 0 }}"
  );
  source = replaceRequired(
    source,
    'navigation panel claude sidebar root',
    "className={cn('bg-background-secondary outline-none flex flex-col h-full', className)}",
    "className={cn('flex h-full flex-col bg-background-secondary/72 outline-none', className)}"
  );
  source = replaceRequired(
    source,
    'navigation primary group calm spacing',
    '<div className="px-2 pt-2 flex flex-col gap-0.5">',
    '<div className="flex flex-col gap-1 px-2 pt-2">'
  );
  source = replaceRequired(
    source,
    'navigation row native transition',
    "'border-l-2 px-2.5 py-1.5 text-xs font-medium transition-colors'",
    "'rounded-[8px] px-2.5 py-1.5 text-[13px] font-medium tracking-normal transition-all duration-200 ease-[var(--epistemos-control-ease)]'"
  );
  source = replaceAllRequired(
    source,
    'navigation active rows borderless',
    "'border-border-active bg-background-tertiary text-text-primary'",
    "'bg-background-tertiary text-text-primary'"
  );
  source = replaceAllRequired(
    source,
    'navigation inactive rows borderless',
    "'border-transparent text-text-secondary hover:bg-background-tertiary/60 hover:text-text-primary'",
    "'text-text-secondary hover:bg-background-tertiary/60 hover:text-text-primary'"
  );
  source = replaceRequired(
    source,
    'navigation session row native transition',
    "'hover:bg-background-tertiary/60 transition-colors text-text-secondary hover:text-text-primary'",
    "'hover:bg-background-tertiary/60 transition-all duration-200 ease-[var(--epistemos-control-ease)] text-text-secondary hover:text-text-primary'"
  );
  source = replaceRequired(
    source,
    'navigation label sf font',
    'className="text-left flex-1 truncate font-mono"',
    'className="text-left flex-1 truncate font-sans tracking-normal"'
  );
  source = replaceRequired(
    source,
    'navigation tag sf font',
    '<span className="text-xs font-mono text-text-secondary">{item.getTag()}</span>',
    '<span className="text-xs font-sans text-text-secondary">{item.getTag()}</span>'
  );
  source = replaceRequired(
    source,
    'navigation session row geometry',
    "'flex items-center gap-2 border-l-2 px-2.5 py-1.5 cursor-pointer text-xs'",
    "'flex items-center gap-2 rounded-[8px] px-2.5 py-1.5 cursor-pointer text-[13px]'"
  );
  source = replaceRequired(
    source,
    'navigation inline edit sf font',
    'className="truncate text-inherit flex-1 !px-0 !py-0 hover:bg-transparent font-mono"',
    'className="truncate text-inherit flex-1 !px-0 !py-0 hover:bg-transparent font-sans tracking-normal"'
  );
  source = replaceRequired(
    source,
    'navigation top spacer no divider',
    '<div className="h-[48px] no-drag border-b border-border-secondary" />',
    '<div className="h-[48px] no-drag" />'
  );
  source = replaceRequired(
    source,
    'navigation chats section no divider',
    '<div className="flex-1 min-h-0 flex flex-col mt-3 border-t border-border-secondary pt-2">',
    '<div className="flex-1 min-h-0 flex flex-col mt-3 pt-2">'
  );
  source = replaceRequired(
    source,
    'navigation chats section pixel label',
    'className="flex items-center gap-1 px-3 py-1 text-[11px] font-semibold uppercase text-text-secondary hover:text-text-primary transition-colors self-start font-mono"',
    'className="ep-pixel flex items-center gap-1 px-3 py-1 text-[11px] font-semibold uppercase text-text-secondary hover:text-text-primary transition-colors self-start tracking-normal"'
  );
  source = replaceRequired(
    source,
    'navigation settings footer no divider',
    '<div className="px-2 pt-2 pb-2 border-t border-border-secondary bg-background-secondary">',
    '<div className="px-2 pb-2 pt-2 bg-transparent">'
  );
  source = replaceRequired(
    source,
    'navigation empty chats sf density',
    '<div className="px-3 py-2 text-xs text-text-secondary">',
    '<div className="px-3 py-2 text-[13px] text-text-secondary">'
  );
  write('src/components/Layout/NavigationPanel.tsx', source);
}

function applyAppSurfaces() {
  let source = read('src/App.tsx');
  source = replaceRequired(
    source,
    'transparent app root',
    'className="goose-epistemos relative w-screen h-screen overflow-hidden bg-background-secondary flex flex-col"',
    'className="goose-epistemos relative w-screen h-screen overflow-hidden bg-transparent flex flex-col"'
  );
  source = replaceRequired(
    source,
    'configure providers transparent route',
    'className="w-screen h-screen bg-background-primary"',
    'className="w-screen h-screen bg-transparent"'
  );
  write('src/App.tsx', source);

  source = read('src/components/LauncherView.tsx');
  source = replaceRequired(
    source,
    'launcher frame',
    'className="relative flex h-full w-full flex-col overflow-hidden border border-border-primary bg-background-primary/95"',
    'className="relative flex h-full w-full flex-col overflow-hidden bg-transparent"'
  );
  source = replaceRequired(
    source,
    'launcher segmented control',
    'className="absolute left-1/2 top-4 z-10 flex -translate-x-1/2 items-center gap-1 border border-border-primary bg-background-primary/90 p-1"',
    'className="absolute left-1/2 top-4 z-10 flex -translate-x-1/2 items-center gap-1 rounded-[10px] bg-background-secondary/56 p-1"'
  );
  source = replaceRequired(
    source,
    'launcher segmented buttons',
    'className={`h-8 min-w-16 px-3 font-mono text-xs transition-colors ${',
    'className={`h-8 min-w-16 rounded-[7px] px-3 font-sans text-xs transition-colors duration-200 ease-[var(--epistemos-control-ease)] ${'
  );
  source = replaceRequired(
    source,
    'launcher selected segment',
    "? 'bg-background-tertiary text-text-primary'",
    "? 'bg-background-primary/78 text-text-primary'"
  );
  source = replaceRequired(
    source,
    'launcher input card',
    'className="goose-chat-input-card flex h-14 items-center border border-border-primary bg-background-secondary"',
    'className="goose-chat-input-card flex h-14 items-center rounded-[14px] bg-background-primary/40"'
  );
  source = replaceRequired(
    source,
    'launcher input font',
    'className="h-full min-w-0 flex-1 bg-transparent px-4 font-mono text-sm text-text-primary outline-none placeholder:text-text-secondary disabled:opacity-45"',
    'className="h-full min-w-0 flex-1 bg-transparent px-4 font-sans text-[15px] text-text-primary outline-none placeholder:text-text-secondary disabled:opacity-45"'
  );
  source = replaceRequired(
    source,
    'launcher submit button',
    'className="mr-2 inline-grid h-9 w-9 place-items-center border border-border-primary bg-background-inverse text-background-primary transition-opacity disabled:cursor-not-allowed disabled:opacity-35"',
    'className="mr-2 inline-grid h-9 w-9 place-items-center rounded-[10px] border border-transparent bg-[var(--epistemos-accent)] text-text-inverse transition-opacity disabled:cursor-not-allowed disabled:opacity-35"'
  );
  source = replaceRequired(
    source,
    'launcher launching card',
    'className="border border-border-primary bg-background-primary px-4 py-3 font-mono text-xs uppercase text-text-primary"',
    'className="rounded-[11px] bg-background-primary/58 px-4 py-3 font-sans text-xs uppercase text-text-primary"'
  );
  write('src/components/LauncherView.tsx', source);

  source = read('src/components/Layout/MainPanelLayout.tsx');
  source = replaceRequired(
    source,
    'main panel transparent default',
    "}> = ({ children, removeTopPadding = false, backgroundColor = 'bg-background-primary' }) => {",
    "}> = ({ children, removeTopPadding = false, backgroundColor = 'bg-transparent' }) => {"
  );
  write('src/components/Layout/MainPanelLayout.tsx', source);

  source = read('src/components/Layout/AppLayout.tsx');
  source = replaceRequired(
    source,
    'app layout transparent root',
    'className="flex flex-1 w-full h-full relative animate-fade-in bg-background-primary flex-row"',
    'className="flex flex-1 w-full h-full relative animate-fade-in bg-transparent flex-row"'
  );
  source = replaceRequired(
    source,
    'app layout nav glass',
    'className="relative flex-shrink-0 overflow-hidden h-full border-r border-border-secondary bg-background-secondary"',
    'className="relative flex-shrink-0 overflow-hidden h-full bg-background-secondary/70"'
  );
  source = replaceRequired(
    source,
    'app layout nav toggle glass',
    'className="no-drag border border-border-secondary bg-background-primary/85 hover:!bg-background-tertiary"',
    'className="no-drag bg-background-primary/70 hover:!bg-background-tertiary/80"'
  );
  write('src/components/Layout/AppLayout.tsx', source);
}

function applyOnboardingSurfaces() {
  let source = read('src/components/onboarding/OnboardingGuard.tsx');
  source = replaceAllRequired(
    source,
    'onboarding guard transparent shells',
    'className="h-screen w-full bg-background-default',
    'className="h-screen w-full bg-transparent'
  );
  source = replaceRequired(
    source,
    'onboarding guard error title native font',
    'className="text-xl font-mono font-normal mb-3"',
    'className="mb-3 text-xl font-sans font-semibold tracking-normal"'
  );
  source = replaceRequired(
    source,
    'onboarding guard error body token',
    'className="text-text-muted mb-6"',
    'className="mb-6 text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'onboarding guard icon well borderless',
    'className={`flex h-8 w-8 items-center justify-center border border-border-primary bg-background-secondary ${className}`}',
    'className={`flex h-8 w-8 items-center justify-center rounded-[10px] bg-background-secondary/60 ${className}`}'
  );
  write('src/components/onboarding/OnboardingGuard.tsx', source);

  source = read('src/components/onboarding/OnboardingSuccess.tsx');
  source = replaceRequired(
    source,
    'onboarding success transparent shell',
    'className="h-screen w-full bg-background-default overflow-hidden"',
    'className="h-screen w-full overflow-hidden bg-transparent"'
  );
  source = replaceRequired(
    source,
    'onboarding success icon well native',
    'className="inline-flex items-center justify-center w-10 h-10 border border-border-primary bg-background-secondary mb-4"',
    'className="mb-4 inline-flex h-10 w-10 items-center justify-center rounded-[12px] bg-background-success/55"'
  );
  source = replaceRequired(
    source,
    'onboarding success icon token',
    'className="w-6 h-6 text-green-500"',
    'className="h-6 w-6 text-text-success"'
  );
  source = replaceRequired(
    source,
    'onboarding success title native font',
    'className="text-xl font-mono font-normal text-text-default mb-1"',
    'className="mb-1 text-xl font-sans font-semibold tracking-normal text-text-primary"'
  );
  source = replaceRequired(
    source,
    'onboarding success subtitle token',
    'className="text-text-muted text-sm"',
    'className="text-sm text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'onboarding success privacy card native',
    'className="w-full p-4 bg-transparent border border-border-primary rounded-[6px] text-left mb-6"',
    'className="mb-6 w-full rounded-[12px] bg-background-primary/54 p-4 text-left"'
  );
  source = replaceRequired(
    source,
    'onboarding success privacy title native',
    'className="font-mono font-normal text-text-default text-sm mb-1"',
    'className="mb-1 text-sm font-sans font-semibold tracking-normal text-text-primary"'
  );
  source = replaceRequired(
    source,
    'onboarding success privacy body token',
    'className="text-text-muted text-sm"',
    'className="text-sm text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'onboarding success privacy link token',
    'className="text-blue-600 dark:text-blue-400 hover:underline"',
    'className="text-[var(--epistemos-accent)] hover:underline"'
  );
  write('src/components/onboarding/OnboardingSuccess.tsx', source);

  source = read('src/components/onboarding/LocalModelPicker.tsx');
  source = replaceRequired(
    source,
    'local model picker shell borderless',
    'className="p-3 border border-border-primary rounded-[6px] bg-background-primary"',
    'className="rounded-[12px] bg-background-primary/54 p-3"'
  );
  source = replaceRequired(
    source,
    'local model picker error borderless',
    'className="border border-border-danger bg-background-danger rounded-[6px] p-3"',
    'className="rounded-[10px] bg-background-danger/35 p-3"'
  );
  source = replaceRequired(
    source,
    'local model picker retry button borderless',
    'className="w-full px-3 py-2 bg-transparent border border-border-primary rounded-[6px] text-text-default text-sm font-medium hover:bg-background-secondary transition-colors"',
    'className="w-full rounded-[8px] bg-background-primary/60 px-3 py-2 text-sm font-medium text-text-primary transition-colors hover:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'local model picker back button native',
    'className="w-full px-3 py-2.5 text-text-primary text-sm font-medium border border-border-primary rounded-[6px] hover:bg-background-secondary transition-colors cursor-pointer"',
    'className="w-full cursor-pointer rounded-[8px] bg-background-primary/60 px-3 py-2.5 text-sm font-medium text-text-primary transition-colors hover:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'local model picker download card native',
    'className="border border-border-primary rounded-[6px] p-3 bg-background-default"',
    'className="rounded-[10px] bg-background-primary/54 p-3"'
  );
  source = replaceRequired(
    source,
    'local model picker cancel download button borderless',
    'className="w-full px-3 py-2.5 bg-transparent text-text-muted border border-border-primary rounded-[6px] text-sm hover:bg-background-secondary transition-colors"',
    'className="w-full rounded-[8px] bg-background-primary/60 px-3 py-2.5 text-sm text-text-secondary transition-colors hover:bg-background-secondary/72 hover:text-text-primary"'
  );
  source = replaceRequired(
    source,
    'local model picker note borderless',
    'className="rounded-[6px] border border-border-primary bg-background-secondary p-3 mt-3"',
    'className="mt-3 rounded-[12px] bg-background-secondary/44 p-3"'
  );
  source = replaceAllRequired(
    source,
    'local model picker option base borderless',
    'w-full p-3 border rounded-[6px] cursor-pointer transition-colors duration-150',
    'w-full cursor-pointer rounded-[10px] p-3 transition-colors duration-150'
  );
  source = replaceAllRequired(
    source,
    'local model picker selected option token',
    "'border-primary bg-background-secondary'",
    "'bg-[var(--epistemos-accent)]/12'"
  );
  source = replaceAllRequired(
    source,
    'local model picker idle option token',
    "'border-border-primary hover:border-primary'",
    "'bg-background-primary/54 hover:bg-background-secondary/56'"
  );
  source = replaceRequired(
    source,
    'local model picker download title token',
    'className="font-medium text-text-default text-sm mb-3"',
    'className="mb-3 text-sm font-medium text-text-primary"'
  );
  source = replaceRequired(
    source,
    'local model picker progress track native',
    'className="w-full bg-background-secondary rounded-[3px] h-2 overflow-hidden"',
    'className="h-2 w-full overflow-hidden rounded-full bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'local model picker progress fill native',
    'className="bg-primary h-2 rounded-[3px] transition-all duration-500 ease-out"',
    'className="h-2 rounded-full bg-[var(--epistemos-accent)] transition-all duration-500 ease-[var(--epistemos-control-ease)]"'
  );
  write('src/components/onboarding/LocalModelPicker.tsx', source);

  source = read('src/components/onboarding/FreeOptionCards.tsx');
  source = replaceRequired(
    source,
    'free option card class borderless',
    "`w-full p-3 bg-transparent border rounded-[6px] transition-colors duration-150 cursor-pointer group ${\n    isSelected ? 'border-primary bg-background-secondary' : 'border-border-primary hover:border-primary hover:bg-background-secondary'\n  }`",
    "`w-full cursor-pointer rounded-[10px] p-3 transition-colors duration-150 group ${\n    isSelected ? 'bg-[var(--epistemos-accent)]/12' : 'bg-background-primary/54 hover:bg-background-secondary/56'\n  }`"
  );
  source = replaceRequired(
    source,
    'free option shell borderless',
    'className="p-3 border border-border-primary rounded-[6px] bg-background-primary"',
    'className="rounded-[12px] bg-background-primary/54 p-3"'
  );
  source = replaceRequired(
    source,
    'free option error borderless',
    'className="mt-3 p-3 border border-border-danger bg-background-danger rounded-[6px] flex items-center justify-between gap-3"',
    'className="mt-3 flex items-center justify-between gap-3 rounded-[10px] bg-background-danger/35 p-3"'
  );
  source = replaceRequired(
    source,
    'free option retry button borderless',
    'className="px-3 py-1 text-xs font-mono uppercase text-text-danger bg-background-primary border border-border-danger rounded-[4px] hover:bg-background-secondary shrink-0"',
    'className="shrink-0 rounded-[8px] bg-background-primary/60 px-3 py-1 text-xs font-sans uppercase text-text-danger transition-colors hover:bg-background-secondary/72"'
  );
  write('src/components/onboarding/FreeOptionCards.tsx', source);

  source = read('src/components/onboarding/ProviderSelector.tsx');
  source = replaceAllRequired(
    source,
    'provider selector branch inset borderless',
    'className="border-l border-border-primary pl-3"',
    'className="rounded-[12px] bg-background-primary/34 px-3 py-2"'
  );
  write('src/components/onboarding/ProviderSelector.tsx', source);

  source = read('src/components/onboarding/ProviderConfigForm.tsx');
  source = replaceRequired(
    source,
    'provider config shell borderless',
    'className="p-3 border border-border-primary rounded-[6px] bg-background-primary"',
    'className="rounded-[12px] bg-background-primary/54 p-3"'
  );
  source = replaceRequired(
    source,
    'provider config error borderless',
    'className="mt-3 p-3 rounded-[6px] bg-background-danger text-text-danger border border-border-danger text-sm"',
    'className="mt-3 rounded-[10px] bg-background-danger/35 p-3 text-sm text-text-danger"'
  );
  write('src/components/onboarding/ProviderConfigForm.tsx', source);
}

function applyChatSurfaces() {
  let source = read('src/components/ChatInputCard.tsx');
  source = replaceRequired(
    source,
    'chat input native glass',
    "'goose-chat-input-card border border-border-primary overflow-hidden bg-background-primary'",
    "'goose-chat-input-card overflow-hidden rounded-[16px] bg-background-primary/40'"
  );
  write('src/components/ChatInputCard.tsx', source);

  source = read('src/components/ChatInput.tsx');
  source = replaceRequired(
    source,
    'chat input queue wrapper borderless',
    'className="border-b border-border-primary"',
    'className="bg-background-primary/24"'
  );
  source = replaceRequired(
    source,
    'chat input recording badge borderless',
    'className="absolute right-2 -bottom-2 bg-background-primary px-2 py-1 text-xs whitespace-nowrap shadow-none border border-border-primary"',
    'className="absolute -bottom-2 right-2 whitespace-nowrap rounded-[8px] bg-background-secondary/72 px-2 py-1 text-xs"'
  );
  source = replaceRequired(
    source,
    'chat input attachments tray borderless',
    'className="flex flex-wrap gap-2 p-4 mt-2 border-t border-border-primary"',
    'className="mt-2 flex flex-wrap gap-2 bg-background-primary/24 p-4"'
  );
  source = replaceRequired(
    source,
    'chat input pasted image preview borderless',
    "className={`w-full h-full object-cover border ${img.error ? 'border-border-danger' : 'border-border-primary'}`}",
    "className={`h-full w-full rounded-[10px] bg-background-secondary/56 object-cover ${img.error ? 'opacity-70' : 'opacity-100'}`}"
  );
  source = replaceRequired(
    source,
    'chat input dropped image preview borderless',
    "className={`w-full h-full object-cover border ${file.error ? 'border-border-danger' : 'border-border-primary'}`}",
    "className={`h-full w-full rounded-[10px] bg-background-secondary/56 object-cover ${file.error ? 'opacity-70' : 'opacity-100'}`}"
  );
  source = replaceRequired(
    source,
    'chat input file chip borderless',
    'className="flex items-center gap-2 px-3 py-2 bg-bgSubtle border border-border-primary min-w-[120px] max-w-[200px]"',
    'className="flex min-w-[120px] max-w-[200px] items-center gap-2 rounded-[10px] bg-background-secondary/56 px-3 py-2"'
  );
  source = replaceRequired(
    source,
    'chat input file type badge borderless',
    'className="flex-shrink-0 w-8 h-8 bg-background-primary border border-border-primary flex items-center justify-center text-xs font-mono text-text-secondary"',
    'className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-[8px] bg-background-primary/70 text-xs font-sans font-medium text-text-secondary"'
  );
  write('src/components/ChatInput.tsx', source);

  source = read('src/components/Hub.tsx');
  source = replaceRequired(
    source,
    'hub clock compact system font',
    'className="flex items-baseline gap-2 mb-1 font-mono"',
    'className="mb-2 flex items-baseline gap-1 font-sans text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'hub clock compact size',
    'className="ep-display text-4xl font-normal text-text-primary tabular-nums"',
    'className="text-[13px] font-medium text-text-secondary tabular-nums"'
  );
  source = replaceRequired(
    source,
    'hub meridiem compact size',
    'className="text-sm text-text-secondary"',
    'className="text-[11px] text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'hub greeting native compact copy',
    'className="ep-pixel text-sm text-text-secondary mb-5 uppercase tracking-[0.06em]"',
    'className="mb-4 text-sm font-medium text-text-primary tracking-normal"'
  );
  write('src/components/Hub.tsx', source);

  source = read('src/components/GooseMessage.tsx');
  source = replaceRequired(
    source,
    'message width clamp',
    'className="goose-message flex w-[88%] justify-start min-w-0"',
    'className="goose-message flex w-[min(88%,900px)] justify-start min-w-0"'
  );
  source = replaceRequired(
    source,
    'message timestamp system font',
    'className="text-xs font-mono text-text-secondary pt-1 transition-all duration-200 group-hover:-translate-y-4 group-hover:opacity-0"',
    'className="text-xs font-sans text-text-secondary pt-1 transition-all duration-200 group-hover:-translate-y-4 group-hover:opacity-0"'
  );
  write('src/components/GooseMessage.tsx', source);

  source = read('src/components/MessageCopyLink.tsx');
  source = replaceRequired(
    source,
    'copy link system font',
    'className="flex font-mono items-center gap-1 text-xs text-text-secondary hover:cursor-pointer hover:text-text-primary transition-all duration-200 opacity-0 group-hover:opacity-100 -translate-y-4 group-hover:translate-y-0"',
    'className="flex font-sans items-center gap-1 text-xs text-text-secondary hover:cursor-pointer hover:text-text-primary transition-all duration-200 opacity-0 group-hover:opacity-100 -translate-y-4 group-hover:translate-y-0"'
  );
  write('src/components/MessageCopyLink.tsx', source);
}

function applyToolAndPopoverSurfaces() {
  let source = read('src/components/ToolCallWithResponse.tsx');
  source = replaceRequired(
    source,
    'tool call native glass',
    "'goose-tool-call w-full text-sm font-sans rounded-[6px] overflow-hidden border bg-background-secondary'",
    "'goose-tool-call w-full text-sm font-sans rounded-[14px] overflow-hidden bg-background-secondary/56'"
  );
  source = replaceRequired(
    source,
    'tool approval prompt font',
    'className="px-3 py-2 text-xs text-amber-700 dark:text-amber-300 bg-amber-50/10 font-mono"',
    'className="px-3 py-2 text-xs text-amber-700 dark:text-amber-300 bg-amber-50/10 font-sans"'
  );
  source = replaceRequired(
    source,
    'mcp inline note native radius',
    'className="mt-3 p-3 border border-border-primary rounded-[6px] bg-background-secondary flex items-center"',
    'className="mt-3 flex items-center rounded-[12px] bg-background-secondary/56 p-3"'
  );
  source = replaceRequired(
    source,
    'mcp inline note font',
    'className="text-xs font-mono"',
    'className="text-xs font-sans"'
  );
  source = replaceRequired(
    source,
    'tool expandable label font',
    'className="flex items-center font-mono text-xs truncate flex-1 min-w-0"',
    'className="flex items-center font-sans text-xs font-medium truncate flex-1 min-w-0"'
  );
  source = replaceAllRequired(
    source,
    'tool detail labels system font',
    'pl-3 font-mono text-xs',
    'pl-3 font-sans text-xs font-medium'
  );
  source = replaceAllRequired(
    source,
    'tool progress labels system font',
    'font-mono text-xs text-textSubtle',
    'font-sans text-xs text-textSubtle'
  );
  source = replaceAllRequired(
    source,
    'tool response detail separators borderless',
    'border-t border-border-primary',
    'bg-background-primary/24'
  );
  write('src/components/ToolCallWithResponse.tsx', source);

  source = read('src/components/ToolCallConfirmation.tsx');
  source = replaceRequired(
    source,
    'tool confirmation card borderless',
    'className="goose-message-content bg-background-primary border border-border-primary rounded-[6px] overflow-hidden"',
    'className="goose-message-content overflow-hidden rounded-[12px] bg-background-primary/54"'
  );
  source = replaceRequired(
    source,
    'tool confirmation header native',
    'className="bg-background-secondary px-3 py-2 text-xs font-mono text-text-primary"',
    'className="bg-background-secondary/62 px-3 py-2 text-xs font-sans text-text-primary"'
  );
  write('src/components/ToolCallConfirmation.tsx', source);

  source = read('src/components/MentionPopover.tsx');
  source = replaceRequired(
    source,
    'mention popover native glass',
    'className="fixed z-50 bg-background-primary border border-border-primary rounded-[6px] shadow-none min-w-96 max-w-lg max-h-80"',
    'className="fixed z-50 max-h-80 min-w-96 max-w-lg overflow-hidden rounded-[14px] bg-background-primary/92"'
  );
  source = replaceRequired(
    source,
    'mention selected row radius',
    'className={`flex items-center gap-3 p-2 rounded-md cursor-pointer transition-colors ${',
    'className={`flex items-center gap-3 p-2 rounded-[9px] cursor-pointer transition-colors ${'
  );
  source = replaceRequired(
    source,
    'mention selected row color',
    "index === selectedIndex ? 'bg-sidebar-accent' : 'hover:bg-sidebar-accent/50'",
    "index === selectedIndex ? 'bg-[var(--epistemos-accent)]/14' : 'hover:bg-background-secondary/70'"
  );
  write('src/components/MentionPopover.tsx', source);
}

function applyCatalogSurfaces() {
  const screenFiles = [
    'src/components/settings/SettingsView.tsx',
    'src/components/skills/SkillsView.tsx',
    'src/components/recipes/RecipesView.tsx',
    'src/components/schedule/SchedulesView.tsx',
    'src/components/apps/AppsView.tsx',
    'src/components/sessions/SessionListView.tsx',
  ];
  for (const file of screenFiles) {
    let source = read(file);
    source = replaceAllRequired(
      source,
      `${file} native header glass`,
      'className="bg-background-primary px-6 pb-5 pt-14 border-b border-border-secondary"',
      'className="bg-background-primary/58 px-6 pb-5 pt-14"'
    );
    source = replaceAllRequired(
      source,
      `${file} native heading font`,
      'text-2xl font-mono font-normal',
      'text-2xl font-sans font-semibold tracking-normal'
    );
    write(file, source);
  }
}

function applyProviderCatalogSurfaces() {
  let source = read('src/components/settings/providers/ProviderSettingsPage.tsx');
  source = replaceRequired(
    source,
    'provider settings transparent root',
    'className="h-screen w-full flex flex-col bg-background-primary text-text-primary"',
    'className="h-screen w-full flex flex-col bg-transparent text-text-primary"'
  );
  source = replaceRequired(
    source,
    'provider settings header glass',
    'className="flex flex-col pb-5 border-b border-border-secondary"',
    'className="ep-native-header-band flex flex-col rounded-[16px] bg-background-primary/42 p-4"'
  );
  source = replaceRequired(
    source,
    'provider settings heading font',
    'className="text-2xl font-mono font-normal mb-3 pt-4"',
    'className="text-2xl font-sans font-semibold tracking-normal mb-3 pt-4"'
  );
  write('src/components/settings/providers/ProviderSettingsPage.tsx', source);

  source = read('src/components/settings/providers/ProviderGrid.tsx');
  source = replaceRequired(
    source,
    'provider grid density',
    'gridTemplateColumns: \'repeat(auto-fill, minmax(200px, 200px))\',',
    'gridTemplateColumns: \'repeat(auto-fill, minmax(230px, 1fr))\','
  );
  source = replaceRequired(
    source,
    'provider grid stretch',
    "justifyContent: 'center',",
    "justifyContent: 'stretch',"
  );
  source = replaceRequired(
    source,
    'custom provider native card body',
    'className="flex flex-col items-center justify-center min-h-[200px]"',
    'className="flex min-h-[178px] flex-col items-center justify-center rounded-[12px]"'
  );
  source = replaceRequired(
    source,
    'custom provider plus token color',
    'className="w-8 h-8 text-gray-400 mb-2"',
    'className="mb-2 h-8 w-8 text-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'custom provider text token color',
    'className="text-sm text-gray-600 dark:text-gray-400 text-center"',
    'className="text-center text-sm text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'custom provider subtitle token color',
    'className="text-xs text-gray-500 mt-1"',
    'className="mt-1 text-xs text-text-tertiary"'
  );
  write('src/components/settings/providers/ProviderGrid.tsx', source);

  source = read('src/components/settings/providers/subcomponents/CardContainer.tsx');
  source = replaceRequired(
    source,
    'provider card outer radius',
    'rounded-[6px] group/card border',
    'ep-native-list-card rounded-[14px] group/card'
  );
  source = replaceRequired(
    source,
    'provider card disabled fill',
    "? 'bg-background-secondary border-border-primary'",
    "? 'bg-background-secondary/46 opacity-70'"
  );
  source = replaceRequired(
    source,
    'provider card enabled fill',
    ": 'bg-background-primary border-border-primary hover:border-primary'",
    ": 'bg-background-primary/46 hover:bg-background-primary/68'"
  );
  source = replaceRequired(
    source,
    'provider card inner native surface',
    'relative bg-background-primary rounded-[6px] p-3 transition-colors duration-150 h-[160px] flex flex-col',
    'relative rounded-[14px] bg-transparent p-4 transition-all duration-200 ease-[var(--epistemos-control-ease)] min-h-[178px] flex flex-col'
  );
  source = replaceRequired(
    source,
    'provider card inner borderless',
    `                   \${borderStyle === 'dashed' ? 'border-2 border-dashed' : 'border'}
                   \${
                     grayedOut
                       ? 'border-border-primary'
                       : 'border-border-primary hover:border-border-primary'
                   }`,
    `                   \${borderStyle === 'dashed' ? 'bg-background-secondary/24' : ''}
                   \${grayedOut ? 'opacity-75' : ''}`
  );
  write('src/components/settings/providers/subcomponents/CardContainer.tsx', source);

  source = read('src/components/settings/providers/subcomponents/CardHeader.tsx');
  source = replaceRequired(
    source,
    'provider card title native font',
    'className="text-base font-medium text-text-primary truncate mr-2"',
    'className="mr-2 truncate text-base font-semibold tracking-normal text-text-primary"'
  );
  write('src/components/settings/providers/subcomponents/CardHeader.tsx', source);
}

function applyProviderModalSurfaces() {
  let source = read('src/components/settings/providers/modal/ProviderConfigurationModal.tsx');
  source = replaceRequired(
    source,
    'provider setup inline code native chip',
    'className="px-1 py-0.5 rounded bg-background-secondary text-xs font-mono break-all"',
    'className="ep-native-badge px-1.5 py-0.5 text-xs break-all"'
  );
  source = replaceRequired(
    source,
    'provider modal delete icon token',
    "className={isActiveProvider ? 'text-yellow-500' : 'text-red-500'}",
    "className={isActiveProvider ? 'text-text-warning' : 'text-text-danger'}"
  );
  source = replaceRequired(
    source,
    'provider external setup close native button',
    'className="w-full h-[60px] rounded-none border-t border-border-primary text-md hover:bg-background-secondary text-text-primary font-medium"',
    'className="h-11 w-full rounded-[8px] bg-background-primary/55 text-md font-medium text-text-primary hover:bg-background-secondary/75"'
  );
  write('src/components/settings/providers/modal/ProviderConfigurationModal.tsx', source);

  source = read('src/components/settings/providers/modal/subcomponents/ProviderLogo.tsx');
  source = replaceRequired(
    source,
    'provider modal logo native well',
    'className="w-12 h-12 bg-background-secondary border border-border-primary rounded-[6px] overflow-hidden flex items-center justify-center"',
    'className="flex h-12 w-12 items-center justify-center overflow-hidden rounded-[14px] bg-background-secondary/70"'
  );
  write('src/components/settings/providers/modal/subcomponents/ProviderLogo.tsx', source);

  source = read('src/components/settings/providers/modal/subcomponents/ProviderSetupActions.tsx');
  source = replaceRequired(
    source,
    'provider active delete warning panel native',
    'className="w-full px-6 py-4 bg-yellow-600/20 border-t border-yellow-500/30"',
    'className="w-full rounded-[12px] bg-background-warning/55 px-6 py-4"'
  );
  source = replaceRequired(
    source,
    'provider active delete warning text native',
    'className="text-yellow-500 text-sm mb-2 flex items-start"',
    'className="mb-2 flex items-start text-sm text-text-warning"'
  );
  source = replaceRequired(
    source,
    'provider delete warning panel native',
    'className="w-full px-6 py-4 bg-red-900/20 border-t border-red-500/30"',
    'className="w-full rounded-[12px] bg-background-danger/55 px-6 py-4"'
  );
  source = replaceRequired(
    source,
    'provider delete warning text native',
    'className="text-red-400 text-sm mb-2"',
    'className="mb-2 text-sm text-text-danger"'
  );
  source = replaceAllRequired(
    source,
    'provider modal secondary full-width actions native',
    'className="w-full h-[60px] rounded-none hover:bg-background-secondary text-text-secondary hover:text-text-primary text-md font-regular"',
    'className="h-11 w-full rounded-[8px] text-md font-regular text-text-secondary hover:bg-background-secondary/75 hover:text-text-primary"'
  );
  source = replaceRequired(
    source,
    'provider modal confirm delete action native',
    'className="w-full h-[60px] rounded-none border-b border-border-primary bg-transparent hover:bg-red-900/20 text-red-500 font-medium text-md"',
    'className="h-11 w-full rounded-[8px] bg-background-danger/45 text-md font-medium text-text-danger hover:bg-background-danger/72"'
  );
  source = replaceRequired(
    source,
    'provider modal delete action native',
    'className="w-full h-[60px] rounded-none border-t border-border-primary bg-transparent hover:bg-background-secondary text-red-500 font-medium text-md"',
    'className="h-11 w-full rounded-[8px] bg-transparent text-md font-medium text-text-danger hover:bg-background-danger/45"'
  );
  source = replaceAllRequired(
    source,
    'provider modal submit action native',
    'className="w-full h-[60px] rounded-none border-t border-border-primary text-md hover:bg-background-secondary text-text-primary font-medium"',
    'className="h-11 w-full rounded-[8px] bg-background-primary/55 text-md font-medium text-text-primary hover:bg-background-secondary/75"'
  );
  source = replaceAllRequired(
    source,
    'provider modal cancel action native',
    'className="w-full h-[60px] rounded-none border-t border-border-primary hover:text-text-primary text-text-secondary hover:bg-background-secondary text-md font-regular"',
    'className="h-11 w-full rounded-[8px] text-md font-regular text-text-secondary hover:bg-background-secondary/75 hover:text-text-primary"'
  );
  write('src/components/settings/providers/modal/subcomponents/ProviderSetupActions.tsx', source);

  source = read('src/components/settings/providers/modal/subcomponents/forms/DefaultProviderSetupForm.tsx');
  source = replaceRequired(
    source,
    'default provider setup checkbox native',
    'className="rounded border-border-primary h-4 w-4"',
    'className="h-4 w-4 rounded-[5px] border-border-primary accent-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'default provider setup input native',
    '} bg-background-primary text-lg placeholder:text-text-secondary font-regular text-text-primary`}',
    '} bg-background-primary/70 text-lg placeholder:text-text-secondary font-regular text-text-primary transition-all focus:bg-background-secondary/72 focus:border-transparent`}'
  );
  source = replaceRequired(
    source,
    'default provider setup input geometry native',
    'className={`w-full h-14 px-4 font-regular rounded-lg shadow-none ${',
    'className={`min-h-12 w-full rounded-[10px] px-4 font-regular shadow-none ${'
  );
  source = replaceRequired(
    source,
    'default provider setup invalid border native',
    "? 'border-2 border-red-500'",
    "? 'bg-background-danger/30 text-text-danger'"
  );
  source = replaceRequired(
    source,
    'default provider setup normal border native',
    ": 'border border-border-primary hover:border-border-primary'",
    ": 'hover:bg-background-secondary/62'"
  );
  source = replaceAllRequired(
    source,
    'default provider setup required/error token',
    'text-red-500',
    'text-text-danger'
  );
  source = replaceRequired(
    source,
    'default provider setup empty token',
    'className="text-center text-gray-500"',
    'className="text-center text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'default provider setup optional native',
    'className="my-4 border-2 border-dashed border-secondary rounded-lg bg-secondary/10"',
    'className="my-4 rounded-[10px] bg-background-primary/55"'
  );
  write('src/components/settings/providers/modal/subcomponents/forms/DefaultProviderSetupForm.tsx', source);

  source = read('src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx');
  source = replaceAllRequired(
    source,
    'custom provider choice cards native',
    'className="w-full p-4 text-left border border-border rounded-lg hover:bg-surfaceHover hover:border-primary transition-colors group"',
    'className="w-full rounded-[10px] bg-background-primary/54 p-4 text-left transition-colors hover:bg-background-secondary/62 group"'
  );
  source = replaceRequired(
    source,
    'custom provider template banner native',
    'className="p-3 bg-surfaceHover border border-border rounded-lg"',
    'className="rounded-[10px] bg-background-primary/54 p-3"'
  );
  source = replaceAllRequired(
    source,
    'custom provider capability badges native',
    'className="text-[10px] font-mono uppercase px-2 py-0.5 rounded-[3px] bg-background-secondary text-primary border border-border-primary"',
    'className="ep-native-badge px-2 py-0.5 text-[10px] text-primary"'
  );
  source = replaceAllRequired(
    source,
    'custom provider checkbox native',
    'className="rounded border-border-primary"',
    'className="rounded-[5px] border-border-primary accent-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'custom provider add header button native',
    'className="flex items-center justify-start gap-1 px-2 pr-4 text-sm rounded-[6px] text-textStandard bg-background-primary border border-borderSubtle hover:border-borderStandard transition-colors min-w-[60px] h-9 [&>svg]:!size-4"',
    'className="flex h-9 min-w-[60px] items-center justify-start gap-1 rounded-[8px] bg-background-primary/70 px-2 pr-4 text-sm text-textStandard transition-colors hover:bg-background-secondary/75 [&>svg]:!size-4"'
  );
  source = replaceAllRequired(
    source,
    'custom provider validation text token',
    'text-red-500',
    'text-text-danger'
  );
  source = replaceRequired(
    source,
    'custom provider active delete warning native',
    'className="px-4 py-3 bg-yellow-600/20 border border-yellow-500/30 rounded"',
    'className="rounded-[10px] bg-background-warning/55 px-4 py-3"'
  );
  source = replaceRequired(
    source,
    'custom provider active delete warning text',
    'className="text-yellow-500 text-sm flex items-start"',
    'className="flex items-start text-sm text-text-warning"'
  );
  source = replaceRequired(
    source,
    'custom provider delete confirmation native',
    'className="px-4 py-3 bg-red-900/20 border border-red-500/30 rounded"',
    'className="rounded-[10px] bg-background-danger/55 px-4 py-3"'
  );
  source = replaceRequired(
    source,
    'custom provider delete confirmation text',
    'className="text-red-400 text-sm"',
    'className="text-sm text-text-danger"'
  );
  source = replaceRequired(
    source,
    'custom provider delete button native',
    'className="text-text-danger hover:text-red-600 mr-auto"',
    'className="mr-auto rounded-[8px] bg-background-danger/35 text-text-danger hover:bg-background-danger/65 hover:text-text-danger"'
  );
  write('src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx', source);

  source = read('src/components/settings/providers/modal/subcomponents/ProviderCatalogPicker.tsx');
  source = replaceRequired(
    source,
    'provider catalog picker row native',
    'className="w-full p-4 text-left border border-border rounded-lg hover:bg-surfaceHover hover:border-primary transition-colors group"',
    'className="w-full rounded-[10px] bg-background-primary/54 p-4 text-left transition-colors hover:bg-background-secondary/62 group"'
  );
  source = replaceRequired(
    source,
    'provider catalog picker error token',
    'className="text-center py-8 text-red-500"',
    'className="py-8 text-center text-text-danger"'
  );
  write('src/components/settings/providers/modal/subcomponents/ProviderCatalogPicker.tsx', source);
}

function applyExtensionSettingsSurfaces() {
  let source = read('src/components/settings/extensions/modal/ExtensionModal.tsx');
  source = replaceRequired(
    source,
    'extension modal native sizing',
    'className="sm:max-w-[600px] max-h-[90vh] overflow-y-auto"',
    'className="max-h-[88vh] overflow-y-auto sm:max-w-[640px]"'
  );
  source = replaceRequired(
    source,
    'extension modal title native font',
    'className="flex items-center gap-2"',
    'className="flex items-center gap-2 font-sans tracking-normal"'
  );
  source = replaceRequired(
    source,
    'extension modal delete icon token',
    '<AlertTriangle className="text-red-500" size={24} />',
    '<AlertTriangle className="text-text-danger" size={24} />'
  );
  source = replaceRequired(
    source,
    'extension modal add icon token',
    '<PlusIcon className="text-iconStandard" size={24} />',
    '<PlusIcon className="text-[var(--epistemos-accent)]" size={24} />'
  );
  source = replaceRequired(
    source,
    'extension modal edit icon token',
    '<Edit className="text-iconStandard" size={24} />',
    '<Edit className="text-[var(--epistemos-accent)]" size={24} />'
  );
  source = replaceRequired(
    source,
    'extension installation note panel native glass',
    'className="bg-background-secondary border border-border-primary rounded-lg p-4"',
    'className="rounded-[12px] bg-background-secondary/62 p-4"'
  );
  source = replaceRequired(
    source,
    'extension installation note icon token',
    '<Info className="h-5 w-5 text-blue-400 shrink-0 mt-0.5" />',
    '<Info className="mt-0.5 h-5 w-5 shrink-0 text-[var(--epistemos-accent)]" />'
  );
  source = replaceAllRequired(
    source,
    'extension modal dividers softened',
    'className="border-t border-border-primary"',
    'className="pt-4"'
  );
  source = replaceRequired(
    source,
    'extension remove button native danger',
    'className="text-red-500 hover:text-red-600"',
    'className="bg-background-danger/35 text-text-danger hover:bg-background-danger/65 hover:text-text-danger"'
  );
  write('src/components/settings/extensions/modal/ExtensionModal.tsx', source);

  source = read('src/components/settings/extensions/modal/EnvVarsSection.tsx');
  source = replaceAllRequired(
    source,
    'env vars input native focus',
    "'w-full text-text-primary border-border-primary hover:border-border-primary'",
    "'w-full bg-background-primary/70 text-text-primary transition-colors hover:bg-background-secondary/72 focus:bg-background-secondary/72 focus:border-transparent focus-visible:ring-0'"
  );
  source = replaceAllRequired(
    source,
    'env vars invalid token',
    "'border-red-500 focus:border-red-500'",
    "'bg-background-danger/35 focus:bg-background-danger/45'"
  );
  source = replaceAllRequired(
    source,
    'env vars icon button native',
    'className="group p-2 h-auto text-iconSubtle hover:bg-transparent"',
    'className="group flex h-8 w-8 items-center justify-center rounded-[8px] p-0 text-iconSubtle hover:bg-background-secondary/75"'
  );
  source = replaceRequired(
    source,
    'env vars edit icon native',
    '<Edit className="h-3 w-3 text-gray-400 group-hover:text-white group-hover:drop-shadow-sm transition-all" />',
    '<Edit className="h-3.5 w-3.5 text-iconSubtle transition-all group-hover:text-[var(--epistemos-accent)]" />'
  );
  source = replaceRequired(
    source,
    'env vars remove icon native',
    '<X className="h-3 w-3 text-gray-400 group-hover:text-white group-hover:drop-shadow-sm transition-all" />',
    '<X className="h-3.5 w-3.5 text-iconSubtle transition-all group-hover:text-text-danger" />'
  );
  source = replaceRequired(
    source,
    'env vars add button native',
    'className="flex items-center justify-start gap-1 px-2 pr-4 text-sm rounded-[6px] text-text-primary bg-background-primary border border-border-primary hover:border-border-primary transition-colors min-w-[60px] h-9 [&>svg]:!size-4"',
    'className="flex h-9 min-w-[60px] items-center justify-start gap-1 rounded-[8px] bg-background-primary/70 px-2 pr-4 text-sm text-text-primary transition-colors hover:bg-background-secondary/75 [&>svg]:!size-4"'
  );
  source = replaceRequired(
    source,
    'env vars validation text token',
    '<div className="mt-2 text-red-500 text-sm">{validationError}</div>',
    '<div className="mt-2 text-sm text-text-danger">{validationError}</div>'
  );
  write('src/components/settings/extensions/modal/EnvVarsSection.tsx', source);

  source = read('src/components/settings/extensions/modal/HeadersSection.tsx');
  source = replaceAllRequired(
    source,
    'headers input native focus',
    "'w-full text-text-primary border-border-primary hover:border-border-primary'",
    "'w-full bg-background-primary/70 text-text-primary transition-colors hover:bg-background-secondary/72 focus:bg-background-secondary/72 focus:border-transparent focus-visible:ring-0'"
  );
  source = replaceAllRequired(
    source,
    'headers invalid token',
    "'border-red-500 focus:border-red-500'",
    "'bg-background-danger/35 focus:bg-background-danger/45'"
  );
  source = replaceRequired(
    source,
    'headers remove button native',
    'className="group p-2 h-auto text-iconSubtle hover:bg-transparent"',
    'className="group flex h-8 w-8 items-center justify-center rounded-[8px] p-0 text-iconSubtle hover:bg-background-secondary/75"'
  );
  source = replaceRequired(
    source,
    'headers remove icon native',
    '<X className="h-3 w-3 text-gray-400 group-hover:text-white group-hover:drop-shadow-sm transition-all" />',
    '<X className="h-3.5 w-3.5 text-iconSubtle transition-all group-hover:text-text-danger" />'
  );
  source = replaceRequired(
    source,
    'headers add button native',
    'className="flex items-center justify-start gap-1 px-2 pr-4 text-sm rounded-[6px] text-text-primary bg-background-primary border border-border-primary hover:border-border-primary transition-colors min-w-[60px] h-9 [&>svg]:!size-4"',
    'className="flex h-9 min-w-[60px] items-center justify-start gap-1 rounded-[8px] bg-background-primary/70 px-2 pr-4 text-sm text-text-primary transition-colors hover:bg-background-secondary/75 [&>svg]:!size-4"'
  );
  source = replaceRequired(
    source,
    'headers validation text token',
    '<div className="mt-2 text-red-500 text-sm">{validationError}</div>',
    '<div className="mt-2 text-sm text-text-danger">{validationError}</div>'
  );
  write('src/components/settings/extensions/modal/HeadersSection.tsx', source);

  source = read('src/components/settings/extensions/modal/ExtensionConfigFields.tsx');
  source = replaceAllRequired(
    source,
    'extension config input native',
    "className={`w-full ${!submitAttempted || isValid ? 'border-border-primary' : 'border-red-500'} text-text-primary`}",
    "className={`w-full bg-background-primary/70 text-text-primary transition-colors focus:bg-background-secondary/72 focus:border-transparent focus-visible:ring-0 ${!submitAttempted || isValid ? '' : 'bg-background-danger/35 focus:bg-background-danger/45'}`}"
  );
  source = replaceRequired(
    source,
    'extension config command error token',
    '<div className="absolute text-xs text-red-500 mt-1">{intl.formatMessage(i18n.commandRequired)}</div>',
    '<div className="absolute mt-1 text-xs text-text-danger">{intl.formatMessage(i18n.commandRequired)}</div>'
  );
  source = replaceRequired(
    source,
    'extension config endpoint error token',
    '<div className="absolute text-xs text-red-500 mt-1">{intl.formatMessage(i18n.endpointRequired)}</div>',
    '<div className="absolute mt-1 text-xs text-text-danger">{intl.formatMessage(i18n.endpointRequired)}</div>'
  );
  write('src/components/settings/extensions/modal/ExtensionConfigFields.tsx', source);

  source = read('src/components/settings/extensions/modal/ExtensionInfoFields.tsx');
  source = replaceRequired(
    source,
    'extension name input native',
    "className={`${!submitAttempted || isNameValid() ? 'border-border-primary' : 'border-red-500'} text-text-primary focus:border-border-primary`}",
    "className={`bg-background-primary/70 text-text-primary transition-colors focus:bg-background-secondary/72 focus:border-transparent focus-visible:ring-0 ${!submitAttempted || isNameValid() ? '' : 'bg-background-danger/35 focus:bg-background-danger/45'}`}"
  );
  source = replaceRequired(
    source,
    'extension name error token',
    '<div className="absolute text-xs text-red-500 mt-1">{intl.formatMessage(i18n.nameRequired)}</div>',
    '<div className="absolute mt-1 text-xs text-text-danger">{intl.formatMessage(i18n.nameRequired)}</div>'
  );
  source = replaceRequired(
    source,
    'extension description input native',
    'className={`text-text-primary focus:border-border-primary`}',
    'className={`bg-background-primary/70 text-text-primary transition-colors focus:bg-background-secondary/72 focus:border-transparent focus-visible:ring-0`}'
  );
  write('src/components/settings/extensions/modal/ExtensionInfoFields.tsx', source);

  source = read('src/components/settings/extensions/modal/ExtensionTimeoutField.tsx');
  source = replaceRequired(
    source,
    'extension timeout input native',
    "className={`${!submitAttempted || isTimeoutValid() ? 'border-border-primary' : 'border-red-500'} text-text-primary focus:border-border-primary`}",
    "className={`bg-background-primary/70 text-text-primary transition-colors focus:bg-background-secondary/72 focus:border-transparent focus-visible:ring-0 ${!submitAttempted || isTimeoutValid() ? '' : 'bg-background-danger/35 focus:bg-background-danger/45'}`}"
  );
  source = replaceRequired(
    source,
    'extension timeout error token',
    '<div className="absolute text-xs text-red-500 mt-1">Timeout </div>',
    '<div className="absolute mt-1 text-xs text-text-danger">Timeout </div>'
  );
  write('src/components/settings/extensions/modal/ExtensionTimeoutField.tsx', source);
}

function applyExtensionListSurfaces() {
  let source = read('src/components/settings/extensions/ExtensionsSection.tsx');
  source = replaceRequired(
    source,
    'extensions action row native spacing',
    'className="flex gap-4 pt-4 w-full"',
    'className="flex w-full gap-3 pt-4"'
  );
  source = replaceAllRequired(
    source,
    'extensions action buttons native',
    'className="flex items-center gap-2 justify-center"',
    'className="flex items-center justify-center gap-2 rounded-[8px]"'
  );
  write('src/components/settings/extensions/ExtensionsSection.tsx', source);

  source = read('src/components/settings/extensions/subcomponents/ExtensionList.tsx');
  source = replaceRequired(
    source,
    'enabled extensions heading native',
    'className="text-lg font-medium text-text-primary mb-4 flex items-center gap-2"',
    'className="mb-4 flex items-center gap-2 text-sm font-semibold tracking-normal text-text-primary"'
  );
  source = replaceRequired(
    source,
    'enabled extensions dot accent',
    'className="w-2 h-2 bg-green-500 rounded-full"',
    'className="h-2 w-2 rounded-full bg-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'enabled extensions grid native gap',
    'className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5 gap-2"',
    'className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5"'
  );
  source = replaceRequired(
    source,
    'available extensions heading native',
    'className="text-lg font-medium text-text-secondary mb-4 flex items-center gap-2"',
    'className="mb-4 flex items-center gap-2 text-sm font-semibold tracking-normal text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'available extensions dot native',
    'className="w-2 h-2 bg-gray-400 rounded-full"',
    'className="h-2 w-2 rounded-full bg-border-tertiary"'
  );
  source = replaceRequired(
    source,
    'available extensions grid native gap',
    'className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5 gap-2"',
    'className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5"'
  );
  source = replaceRequired(
    source,
    'empty extensions native panel',
    'className="text-center text-text-secondary py-8"',
    'className="rounded-[12px] bg-background-secondary/55 py-8 text-center text-text-secondary"'
  );
  write('src/components/settings/extensions/subcomponents/ExtensionList.tsx', source);

  source = read('src/components/settings/extensions/subcomponents/ExtensionItem.tsx');
  source = replaceRequired(
    source,
    'extension item card native glass',
    'className="transition-all duration-200 min-h-[120px] overflow-hidden"',
    'className="min-h-[128px] overflow-hidden bg-background-primary/54 transition-colors duration-200 ease-[var(--epistemos-control-ease)] hover:bg-background-secondary/62"'
  );
  source = replaceRequired(
    source,
    'extension item gear native button',
    'className="text-text-secondary hover:text-text-primary"',
    'className="flex h-8 w-8 items-center justify-center rounded-[8px] text-text-secondary transition-all hover:bg-background-secondary/75 hover:text-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'extension item gear native size',
    '<Gear className="w-4 h-4" />',
    '<Gear className="h-4 w-4" />'
  );
  source = replaceRequired(
    source,
    'extension item command native chip',
    '<span className="font-mono text-xs">{command}</span>',
    '<span className="ep-native-badge mt-1 inline-flex max-w-full truncate px-2 py-0.5 text-xs">{command}</span>'
  );
  source = replaceRequired(
    source,
    'extension item content native spacing',
    'className="px-4 overflow-hidden text-sm break-words text-text-secondary"',
    'className="overflow-hidden break-words px-4 text-sm leading-relaxed text-text-secondary"'
  );
  write('src/components/settings/extensions/subcomponents/ExtensionItem.tsx', source);
}

function applyChatSettingsSurfaces() {
  let source = read('src/components/settings/chat/ChatSettingsSection.tsx');
  source = replaceAllRequired(
    source,
    'chat settings cards native glass',
    'className="pb-2 rounded-[6px]"',
    'className="bg-background-primary/54 pb-2"'
  );
  source = replaceAllRequired(
    source,
    'chat settings card content breathing room',
    'className="px-2"',
    'className="px-2.5"'
  );
  write('src/components/settings/chat/ChatSettingsSection.tsx', source);

  source = read('src/components/settings/chat/SpellcheckToggle.tsx');
  source = replaceRequired(
    source,
    'spellcheck native row',
    'className="flex items-center justify-between py-2 px-2 hover:bg-background-secondary rounded-lg transition-all"',
    'className="flex items-center justify-between rounded-[9px] px-3 py-2.5 transition-colors duration-200 ease-[var(--epistemos-control-ease)] hover:bg-background-secondary/65"'
  );
  source = replaceRequired(
    source,
    'spellcheck title weight',
    'className="text-text-primary"',
    'className="font-medium text-text-primary"'
  );
  write('src/components/settings/chat/SpellcheckToggle.tsx', source);

  source = read('src/components/settings/mode/ModeSection.tsx');
  source = replaceRequired(
    source,
    'mode list spacing native',
    'className="space-y-1"',
    'className="space-y-1.5"'
  );
  write('src/components/settings/mode/ModeSection.tsx', source);

  source = read('src/components/settings/mode/ModeSelectionItem.tsx');
  source = replaceRequired(
    source,
    'mode item native row',
    "className={`flex items-center justify-between text-text-primary py-2 px-2 ${checked ? 'bg-background-secondary' : 'bg-background-primary hover:bg-background-secondary'} rounded-lg transition-all`}",
    "className={`flex items-center justify-between rounded-[9px] px-3 py-2.5 text-text-primary transition-colors duration-200 ease-[var(--epistemos-control-ease)] ${checked ? 'bg-[var(--epistemos-accent)]/12' : 'bg-transparent hover:bg-background-secondary/55'}`}"
  );
  source = replaceRequired(
    source,
    'mode item title native weight',
    '<h3 className="text-text-primary">{intl.formatMessage(mode.labelDescriptor)}</h3>',
    '<h3 className="font-medium text-text-primary">{intl.formatMessage(mode.labelDescriptor)}</h3>'
  );
  source = replaceRequired(
    source,
    'mode item description native size',
    '<p className="text-text-secondary mt-[2px]">{intl.formatMessage(mode.descriptionDescriptor)}</p>',
    '<p className="mt-[2px] text-xs text-text-secondary">{intl.formatMessage(mode.descriptionDescriptor)}</p>'
  );
  source = replaceRequired(
    source,
    'mode configure gear native button',
    '<button\n                onClick={(e) => {',
    '<button\n                className="flex h-8 w-8 items-center justify-center rounded-[8px] text-iconSubtle transition-all hover:bg-background-primary/80 hover:text-[var(--epistemos-accent)]"\n                onClick={(e) => {'
  );
  source = replaceRequired(
    source,
    'mode configure gear native icon',
    '<Gear className="w-4 h-4 text-text-secondary hover:text-text-primary" />',
    '<Gear className="h-4 w-4 transition-colors" />'
  );
  source = replaceRequired(
    source,
    'mode radio native accent',
    `className="h-4 w-4 rounded-full border border-border-primary ${''}
                    peer-checked:border-[6px] peer-checked:border-black dark:peer-checked:border-white
                    peer-checked:bg-white dark:peer-checked:bg-black
                    transition-all duration-200 ease-in-out group-hover:border-border-primary"`,
    `className="h-[18px] w-[18px] rounded-full bg-background-primary/70
                    transition-colors duration-200 ease-[var(--epistemos-control-ease)] group-hover:bg-background-secondary/80
                    peer-checked:bg-[var(--epistemos-accent)]"`
  );
  write('src/components/settings/mode/ModeSelectionItem.tsx', source);

  source = read('src/components/settings/mode/ConversationLimitsDropdown.tsx');
  source = replaceRequired(
    source,
    'conversation limits disclosure native',
    'className="w-full flex items-center justify-between py-2 px-2 hover:bg-background-secondary rounded-[5px] transition-all group"',
    'className="group flex w-full items-center justify-between rounded-[9px] px-3 py-2.5 transition-colors duration-200 ease-[var(--epistemos-control-ease)] hover:bg-background-secondary/60"'
  );
  source = replaceRequired(
    source,
    'conversation limits title native weight',
    '<h3 className="text-text-primary">{intl.formatMessage(i18n.conversationLimits)}</h3>',
    '<h3 className="font-medium text-text-primary">{intl.formatMessage(i18n.conversationLimits)}</h3>'
  );
  source = replaceRequired(
    source,
    'conversation limits row native glass',
    'className="flex items-center justify-between py-2 px-2 bg-background-secondary rounded-[5px] transform transition-all duration-200 ease-in-out"',
    'className="flex items-center justify-between rounded-[9px] bg-background-secondary/56 px-3 py-2.5 transition-colors duration-200 ease-[var(--epistemos-control-ease)]"'
  );
  source = replaceRequired(
    source,
    'conversation limits input native width',
    'className="w-20"',
    'className="w-24 text-right"'
  );
  write('src/components/settings/mode/ConversationLimitsDropdown.tsx', source);

  source = read('src/components/settings/mode/ConfigureApproveMode.tsx');
  source = replaceRequired(
    source,
    'approve mode overlay native blur',
    'className="fixed inset-0 bg-black/30"',
    'className="fixed inset-0 bg-black/20"'
  );
  source = replaceRequired(
    source,
    'approve mode card native glass',
    'className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[440px] bg-background-primary rounded-[6px] overflow-hidden p-[16px] pt-[24px] pb-0 border border-border-primary shadow-none"',
    'className="fixed left-1/2 top-1/2 w-[440px] -translate-x-1/2 -translate-y-1/2 overflow-hidden rounded-[14px] bg-background-primary/92 p-[16px] pt-[24px] pb-0"'
  );
  source = replaceRequired(
    source,
    'approve mode title native',
    'className="text-2xl font-regular text-text-primary"',
    'className="text-xl font-semibold tracking-normal text-text-primary"'
  );
  source = replaceRequired(
    source,
    'approve mode save button native',
    'className="w-full h-[60px] rounded-none border-t border-border-primary hover:bg-background-secondary text-text-primary dark:border-gray-600 text-base font-regular"',
    'className="h-11 w-full rounded-[8px] bg-background-primary/65 text-base font-medium text-text-primary hover:bg-background-secondary/75"'
  );
  source = replaceRequired(
    source,
    'approve mode cancel button native',
    'className="w-full h-[60px] rounded-none border-t border-border-primary text-text-secondary hover:bg-background-secondary dark:border-gray-600 text-base font-regular"',
    'className="h-11 w-full rounded-[8px] text-base font-regular text-text-secondary hover:bg-background-secondary/75 hover:text-text-primary"'
  );
  write('src/components/settings/mode/ConfigureApproveMode.tsx', source);

  source = read('src/components/settings/response_styles/ResponseStylesSection.tsx');
  source = replaceRequired(
    source,
    'response styles list spacing native',
    'className="space-y-1"',
    'className="space-y-1.5"'
  );
  write('src/components/settings/response_styles/ResponseStylesSection.tsx', source);

  source = read('src/components/settings/response_styles/ResponseStyleSelectionItem.tsx');
  source = replaceRequired(
    source,
    'response style item native row',
    "className={`flex items-center justify-between text-text-primary py-2 px-2 ${checked ? 'bg-background-secondary' : 'bg-background-primary hover:bg-background-secondary'} rounded-lg transition-all`}",
    "className={`flex items-center justify-between rounded-[9px] px-3 py-2.5 text-text-primary transition-colors duration-200 ease-[var(--epistemos-control-ease)] ${checked ? 'bg-[var(--epistemos-accent)]/12' : 'bg-transparent hover:bg-background-secondary/55'}`}"
  );
  source = replaceRequired(
    source,
    'response style title native weight',
    '<h3 className="text-text-primary">{intl.formatMessage(style.label)}</h3>',
    '<h3 className="font-medium text-text-primary">{intl.formatMessage(style.label)}</h3>'
  );
  source = replaceRequired(
    source,
    'response style radio native accent',
    `className="h-4 w-4 rounded-full border border-border-primary
                  peer-checked:border-[6px] peer-checked:border-black dark:peer-checked:border-white
                  peer-checked:bg-white dark:peer-checked:bg-black
                  transition-all duration-200 ease-in-out group-hover:border-border-primary"`,
    `className="h-[18px] w-[18px] rounded-full bg-background-primary/70
                  transition-colors duration-200 ease-[var(--epistemos-control-ease)] group-hover:bg-background-secondary/80
                  peer-checked:bg-[var(--epistemos-accent)]"`
  );
  write('src/components/settings/response_styles/ResponseStyleSelectionItem.tsx', source);
}

function applyPermissionSurfaces() {
  let source = read('src/components/settings/permission/PermissionModal.tsx');
  source = replaceRequired(
    source,
    'permission modal native sizing',
    'className="sm:max-w-[500px] max-h-[90vh] overflow-y-auto"',
    'className="max-h-[88vh] overflow-y-auto sm:max-w-[560px]"'
  );
  source = replaceRequired(
    source,
    'permission modal title native',
    'className="flex items-center gap-2"',
    'className="flex items-center gap-2 font-sans tracking-normal"'
  );
  source = replaceRequired(
    source,
    'permission modal icon accent',
    '<SlidersHorizontal className="text-iconStandard" size={24} />',
    '<SlidersHorizontal className="text-[var(--epistemos-accent)]" size={24} />'
  );
  source = replaceRequired(
    source,
    'permission modal spinner accent',
    'className="animate-spin h-8 w-8 text-grey-50 dark:text-white"',
    'className="h-8 w-8 animate-spin text-[var(--epistemos-accent)]"'
  );
  source = replaceAllRequired(
    source,
    'permission modal empty state native panel',
    'className="flex flex-col items-center justify-center py-8 text-center"',
    'className="flex flex-col items-center justify-center rounded-[12px] bg-background-secondary/55 px-6 py-8 text-center"'
  );
  source = replaceRequired(
    source,
    'permission modal tool row native',
    'className="flex items-center justify-between grid grid-cols-12"',
    'className="grid grid-cols-12 items-center gap-3 rounded-[10px] bg-background-secondary/45 px-3 py-2.5"'
  );
  source = replaceRequired(
    source,
    'permission modal dropdown trigger native',
    '<Button className="w-full" variant="secondary" size="lg">',
    '<Button className="w-full justify-between bg-background-primary/70" variant="secondary" size="lg">'
  );
  write('src/components/settings/permission/PermissionModal.tsx', source);

  source = read('src/components/settings/permission/PermissionRulesModal.tsx');
  source = replaceRequired(
    source,
    'permission rules item button native',
    'className="flex items-center text-left gap-2 w-full justify-between"',
    'className="flex h-auto w-full items-center justify-between gap-2 rounded-[11px] bg-background-primary/54 px-4 py-3 text-left hover:bg-background-secondary/70"'
  );
  source = replaceRequired(
    source,
    'permission rules dialog native shell',
    'className="sm:max-w-[800px] max-h-[80vh] p-0 flex flex-col overflow-hidden"',
    'className="flex max-h-[80vh] flex-col overflow-hidden p-0 sm:max-w-[800px]"'
  );
  source = replaceRequired(
    source,
    'permission rules header icon native well',
    'className="rounded-[6px] bg-background-inverse w-12 h-12 flex items-center justify-center"',
    'className="flex h-12 w-12 items-center justify-center rounded-[14px] bg-background-secondary/62"'
  );
  source = replaceRequired(
    source,
    'permission rules header icon token',
    'className="stroke-text-inverse fill-background-inverse"',
    'className="fill-transparent stroke-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'permission rules title native',
    'className="text-3xl font-medium text-text-primary"',
    'className="text-2xl font-semibold tracking-normal text-text-primary"'
  );
  write('src/components/settings/permission/PermissionRulesModal.tsx', source);

  source = read('src/components/settings/permission/PermissionSetting.tsx');
  source = replaceRequired(
    source,
    'permission settings root transparent',
    'className="bg-background-primary h-screen w-full animate-[fadein_200ms_ease-in_forwards]"',
    'className="h-screen w-full animate-[fadein_200ms_ease-in_forwards] bg-transparent"'
  );
  source = replaceRequired(
    source,
    'permission settings item button native',
    'className="flex items-center gap-2 w-full justify-between"',
    'className="flex h-auto w-full items-center justify-between gap-2 rounded-[11px] bg-background-primary/54 px-4 py-3 text-left hover:bg-background-secondary/70"'
  );
  source = replaceRequired(
    source,
    'permission settings header icon native well',
    'className="rounded-[6px] bg-background-inverse w-12 h-12 flex items-center justify-center mb-4"',
    'className="mb-4 flex h-12 w-12 items-center justify-center rounded-[14px] bg-background-secondary/62"'
  );
  source = replaceRequired(
    source,
    'permission settings header icon token',
    'className="stroke-text-inverse fill-background-inverse"',
    'className="fill-transparent stroke-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'permission settings title native',
    'className="text-3xl font-medium text-text-primary mt-4"',
    'className="mt-4 text-2xl font-semibold tracking-normal text-text-primary"'
  );
  write('src/components/settings/permission/PermissionSetting.tsx', source);
}

function applySettingsPanelSurfaces() {
  let source = read('src/components/settings/SettingsView.tsx');
  source = replaceRequired(
    source,
    'settings title native font',
    'className="text-2xl font-sans font-semibold tracking-normal"',
    'className="text-2xl font-sans font-semibold tracking-normal text-text-primary"'
  );
  source = replaceRequired(
    source,
    'settings tabs native list',
    'className="w-full mb-2 justify-start overflow-x-auto flex-nowrap rounded-[6px]"',
    'className="mb-2 w-full flex-nowrap justify-start overflow-x-auto rounded-[10px] bg-background-secondary/70"'
  );
  write('src/components/settings/SettingsView.tsx', source);

  source = read('src/components/settings/app/AppSettingsSection.tsx');
  source = replaceAllRequired(
    source,
    'app settings cards native glass',
    'className="rounded-lg"',
    'className="bg-background-primary/54"'
  );
  source = replaceAllRequired(
    source,
    'app settings rows native hover',
    'className="flex items-center justify-between"',
    'className="flex items-center justify-between rounded-[9px] px-3 py-2.5 transition-colors hover:bg-background-secondary/60"'
  );
  source = replaceRequired(
    source,
    'app settings language trigger native',
    'className="flex w-full max-w-[260px] items-center justify-between gap-2 rounded-md border border-border-primary bg-background-primary px-3 py-2 text-sm text-text-primary transition-colors hover:border-border-primary"',
    'className="flex w-full max-w-[260px] items-center justify-between gap-2 rounded-[8px] bg-background-primary/70 px-3 py-2 text-sm text-text-primary transition-colors hover:bg-background-secondary/70"'
  );
  source = replaceRequired(
    source,
    'app settings version badge native',
    'className="flex h-8 w-8 items-center justify-center border border-border-primary bg-background-secondary font-mono text-sm text-text-primary"',
    'className="flex h-8 w-8 items-center justify-center rounded-[8px] bg-background-secondary/62 font-sans text-sm font-semibold text-text-primary"'
  );
  source = replaceRequired(
    source,
    'app settings version text native',
    'className="text-2xl font-mono text-text-primary"',
    'className="text-xl font-semibold tracking-normal text-text-primary"'
  );
  source = replaceRequired(
    source,
    'notification settings dialog icon accent',
    '<Settings className="text-iconStandard" size={24} />',
    '<Settings className="text-[var(--epistemos-accent)]" size={24} />'
  );
  write('src/components/settings/app/AppSettingsSection.tsx', source);

  source = read('src/components/settings/app/TelemetrySettings.tsx');
  source = replaceRequired(
    source,
    'telemetry learn more accent',
    'className="text-blue-600 dark:text-blue-400 hover:underline"',
    'className="text-[var(--epistemos-accent)] hover:underline"'
  );
  source = replaceRequired(
    source,
    'telemetry row native',
    'className="flex items-center justify-between"',
    'className="flex items-center justify-between rounded-[9px] px-3 py-2.5 transition-colors hover:bg-background-secondary/60"'
  );
  source = replaceRequired(
    source,
    'telemetry card native glass',
    'className="rounded-[6px]"',
    'className="bg-background-primary/54"'
  );
  write('src/components/settings/app/TelemetrySettings.tsx', source);

  source = read('src/components/settings/config/ConfigSettings.tsx');
  source = replaceRequired(
    source,
    'config settings card native glass',
    'className="rounded-lg"',
    'className="bg-background-primary/54"'
  );
  source = replaceAllRequired(
    source,
    'config settings icon accent',
    '<FileText className="text-iconStandard" size={20} />',
    '<FileText className="text-[var(--epistemos-accent)]" size={20} />'
  );
  source = replaceRequired(
    source,
    'config edit button native',
    '<Button className="flex items-center gap-2" variant="secondary" size="sm">',
    '<Button className="flex items-center gap-2 bg-background-primary/70" variant="secondary" size="sm">'
  );
  source = replaceRequired(
    source,
    'config dialog native sizing',
    'className="max-w-4xl max-h-[80vh]"',
    'className="max-h-[80vh] max-w-4xl overflow-hidden"'
  );
  source = replaceRequired(
    source,
    'config row native',
    'className="grid grid-cols-[200px_1fr_auto] gap-3 items-center"',
    'className="grid grid-cols-[200px_1fr_auto] items-center gap-3 rounded-[10px] bg-background-secondary/45 px-3 py-2.5"'
  );
  source = replaceRequired(
    source,
    'config input native',
    "'text-text-primary border-border-primary hover:border-border-primary transition-colors'",
    "'bg-background-primary/70 text-text-primary transition-colors hover:bg-background-secondary/72 focus:bg-background-secondary/72 focus:border-transparent focus-visible:ring-0'"
  );
  source = replaceRequired(
    source,
    'config modified input accent',
    "modifiedKeys.has(key) && 'border-blue-500 focus:ring-blue-500/20'",
    "modifiedKeys.has(key) && 'bg-[var(--epistemos-accent)]/10'"
  );
  source = replaceRequired(
    source,
    'config save button native',
    'className="min-w-[60px]"',
    'className="min-w-[60px] rounded-[8px] hover:bg-background-primary/80"'
  );
  write('src/components/settings/config/ConfigSettings.tsx', source);

  source = read('src/components/settings/PromptsSettingsSection.tsx');
  source = replaceRequired(
    source,
    'prompt editor card native glass',
    'className="pb-2 rounded-lg"',
    'className="bg-background-primary/54 pb-2"'
  );
  source = replaceRequired(
    source,
    'prompt customized badge native editor',
    'className="px-2 py-0.5 text-[10px] font-mono uppercase rounded-[3px] bg-background-secondary text-primary border border-border-primary"',
    'className="ep-native-badge px-2 py-0.5 text-[10px] text-primary"'
  );
  source = replaceRequired(
    source,
    'prompt template tip native',
    'className="text-sm text-text-secondary bg-background-secondary p-3 rounded-lg"',
    'className="rounded-[10px] bg-background-secondary/56 p-3 text-sm text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'prompt textarea native',
    'className="w-full flex-1 min-h-[500px] border rounded-md p-3 text-sm font-mono resize-y bg-background-primary text-text-primary border-border-primary focus:outline-none focus:ring-2 focus:ring-blue-500"',
    'className="min-h-[500px] w-full flex-1 resize-y rounded-[10px] bg-background-primary/70 p-3 font-mono text-sm text-text-primary transition-colors focus:bg-background-secondary/72 focus:outline-none focus:ring-0"'
  );
  source = replaceRequired(
    source,
    'prompt unsaved warning token',
    'className="text-sm text-yellow-600 dark:text-yellow-400"',
    'className="text-sm text-text-warning"'
  );
  source = replaceRequired(
    source,
    'prompt list warning card native',
    'className="pb-2 rounded-lg border-yellow-500/50 bg-yellow-500/10"',
    'className="bg-background-warning/55 pb-2"'
  );
  source = replaceRequired(
    source,
    'prompt warning icon token',
    '<AlertTriangle className="h-5 w-5 text-yellow-500 flex-shrink-0 mt-1" />',
    '<AlertTriangle className="mt-1 h-5 w-5 flex-shrink-0 text-text-warning" />'
  );
  source = replaceRequired(
    source,
    'prompt warning title token',
    'className="text-yellow-600 dark:text-yellow-400"',
    'className="text-text-warning"'
  );
  source = replaceRequired(
    source,
    'prompt reset all button native',
    'className="flex items-center gap-2 border-yellow-500/50 hover:bg-yellow-500/20"',
    'className="flex items-center gap-2 text-text-warning hover:bg-background-warning/70"'
  );
  source = replaceRequired(
    source,
    'prompt row native glass',
    'className="flex items-center justify-between p-3 rounded-lg border border-border-primary hover:bg-background-secondary transition-colors"',
    'className="flex items-center justify-between rounded-[10px] bg-background-primary/55 p-3 transition-colors hover:bg-background-secondary/70"'
  );
  source = replaceRequired(
    source,
    'prompt customized badge native list',
    'className="px-2 py-0.5 text-[10px] font-mono uppercase rounded-[3px] bg-background-secondary text-primary border border-border-primary"',
    'className="ep-native-badge px-2 py-0.5 text-[10px] text-primary"'
  );
  write('src/components/settings/PromptsSettingsSection.tsx', source);
}

function applyModelSettingsSurfaces() {
  let source = read('src/components/settings/models/ModelsSection.tsx');
  source = replaceRequired(
    source,
    'models summary card native glass',
    'className="p-2 pb-4"',
    'className="bg-background-primary/42 p-3 pb-4"'
  );
  source = replaceRequired(
    source,
    'models summary heading native',
    'className="text-text-primary"',
    'className="font-medium text-text-primary"'
  );
  source = replaceRequired(
    source,
    'models reset card native glass',
    'className="pb-2 rounded-lg"',
    'className="bg-background-primary/42 pb-2"'
  );
  source = replaceRequired(
    source,
    'models reset card content breathing room',
    'className="px-2"',
    'className="px-2.5"'
  );
  write('src/components/settings/models/ModelsSection.tsx', source);

  source = read('src/components/settings/models/subcomponents/ModelSettingsButtons.tsx');
  source = replaceAllRequired(
    source,
    'model settings buttons native',
    'className="flex items-center gap-2 justify-center"',
    'className="flex items-center justify-center gap-2 rounded-[8px]"'
  );
  write('src/components/settings/models/subcomponents/ModelSettingsButtons.tsx', source);

  source = read('src/components/settings/reset_provider/ResetProviderSection.tsx');
  source = replaceRequired(
    source,
    'reset provider container native',
    'className="p-2"',
    'className="rounded-[10px] bg-background-danger/28 p-3"'
  );
  source = replaceRequired(
    source,
    'reset provider button native',
    'className="flex items-center justify-center gap-2"',
    'className="flex items-center justify-center gap-2 rounded-[8px]"'
  );
  write('src/components/settings/reset_provider/ResetProviderSection.tsx', source);

  source = read('src/components/settings/models/bottom_bar/ModelsBottomBar.tsx');
  source = replaceRequired(
    source,
    'model bottom trigger native',
    'className="flex items-center hover:cursor-pointer max-w-[180px] md:max-w-[200px] lg:max-w-[380px] min-w-0 text-text-primary/70 hover:text-text-primary transition-colors"',
    'className="flex h-8 min-w-0 max-w-[180px] items-center rounded-[8px] bg-background-primary/34 px-2 text-text-primary/75 transition-colors hover:cursor-pointer hover:bg-background-secondary/65 hover:text-text-primary md:max-w-[200px] lg:max-w-[380px]"'
  );
  source = replaceRequired(
    source,
    'model bottom dropdown native width',
    'className="w-64 text-sm"',
    'className="w-72 text-sm"'
  );
  source = replaceRequired(
    source,
    'model bottom local overlay native',
    'className="fixed inset-0 z-50 flex items-center justify-center bg-black/50"',
    'className="fixed inset-0 z-50 flex items-center justify-center bg-black/20"'
  );
  source = replaceRequired(
    source,
    'model bottom local modal native',
    'className="bg-background-primary border border-border-primary rounded-[6px] shadow-none w-[480px] max-h-[80vh] flex flex-col"',
    'className="flex max-h-[80vh] w-[480px] flex-col rounded-[14px] bg-background-primary/92"'
  );
  source = replaceRequired(
    source,
    'model bottom local modal header native',
    'className="flex items-center justify-between px-4 py-3 border-b border-border-subtle"',
    'className="flex items-center justify-between bg-background-primary/45 px-4 py-3"'
  );
  source = replaceRequired(
    source,
    'model bottom local close native',
    'className="text-text-muted hover:text-text-default text-lg leading-none"',
    'className="flex h-8 w-8 items-center justify-center rounded-[8px] text-lg leading-none text-text-muted transition-all hover:bg-background-secondary/75 hover:text-text-default"'
  );
  write('src/components/settings/models/bottom_bar/ModelsBottomBar.tsx', source);

  source = read('src/components/settings/models/subcomponents/SwitchModelModal.tsx');
  source = replaceRequired(
    source,
    'switch model modal native width',
    'className="sm:max-w-[500px]"',
    'className="sm:max-w-[560px]"'
  );
  source = replaceRequired(
    source,
    'switch model title native',
    'className="flex items-center gap-2"',
    'className="flex items-center gap-2 font-sans tracking-normal"'
  );
  source = replaceRequired(
    source,
    'switch model title icon accent',
    '<Bot size={24} className="text-text-primary" />',
    '<Bot size={24} className="text-[var(--epistemos-accent)]" />'
  );
  source = replaceRequired(
    source,
    'switch model predefined row native',
    "className={`flex items-center justify-between text-text-primary py-2 px-2 ${\n                        selectedPredefinedModel?.name === model.name\n                          ? 'bg-background-secondary'\n                          : 'bg-background-primary hover:bg-background-secondary'\n                      } rounded-lg transition-all`}",
    "className={`flex items-center justify-between rounded-[10px] px-3 py-2.5 text-text-primary transition-colors duration-200 ease-[var(--epistemos-control-ease)] ${\n                        selectedPredefinedModel?.name === model.name\n                          ? 'bg-[var(--epistemos-accent)]/12'\n                          : 'bg-transparent hover:bg-background-secondary/55'\n                      }`}"
  );
  source = replaceRequired(
    source,
    'switch model recommended badge native',
    'className="text-[10px] font-mono uppercase bg-background-secondary text-text-primary px-2 py-1 rounded-[3px] border border-border-primary ml-2"',
    'className="ep-native-badge ml-2 px-2 py-1 text-[10px] text-text-primary"'
  );
  source = replaceRequired(
    source,
    'switch model radio native accent',
    `className="h-4 w-4 rounded-full border border-border-primary
                                peer-checked:border-[6px] peer-checked:border-black dark:peer-checked:border-white
                                peer-checked:bg-white dark:peer-checked:bg-black
                                transition-all duration-200 ease-in-out group-hover:border-border-primary"`,
    `className="h-[18px] w-[18px] rounded-full bg-background-primary/70
                                transition-colors duration-200 ease-[var(--epistemos-control-ease)] group-hover:bg-background-secondary/80
                                peer-checked:bg-[var(--epistemos-accent)]"`
  );
  source = replaceAllRequired(
    source,
    'switch model validation danger token',
    'className="text-red-500 text-sm mt-1"',
    'className="mt-1 text-sm text-text-danger"'
  );
  source = replaceRequired(
    source,
    'switch model local info panel native',
    'className="rounded-md bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 p-4"',
    'className="rounded-[12px] bg-background-secondary/56 p-4"'
  );
  source = replaceRequired(
    source,
    'switch model local info title token',
    'className="text-sm font-medium text-blue-800 dark:text-blue-200"',
    'className="text-sm font-medium text-text-primary"'
  );
  source = replaceRequired(
    source,
    'switch model local info body token',
    'className="mt-1 text-sm text-blue-700 dark:text-blue-300"',
    'className="mt-1 text-sm text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'switch model local settings button native',
    'className="self-start border-blue-300 dark:border-blue-700 text-blue-700 dark:text-blue-300 hover:bg-blue-100 dark:hover:bg-blue-900/40"',
    'className="self-start bg-background-primary/60 text-text-primary hover:bg-background-secondary/75"'
  );
  source = replaceAllRequired(
    source,
    'switch model warning panel native',
    'className="rounded-md bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 p-3',
    'className="rounded-[12px] bg-background-warning/55 p-3'
  );
  source = replaceRequired(
    source,
    'switch model warning title token',
    'className="text-sm font-medium text-yellow-800 dark:text-yellow-200"',
    'className="text-sm font-medium text-text-warning"'
  );
  source = replaceAllRequired(
    source,
    'switch model warning body token',
    'className="mt-1 text-sm text-yellow-700 dark:text-yellow-300"',
    'className="mt-1 text-sm text-text-warning"'
  );
  source = replaceRequired(
    source,
    'switch model warning inline body token',
    'className="text-sm text-yellow-700 dark:text-yellow-300"',
    'className="text-sm text-text-warning"'
  );
  source = replaceRequired(
    source,
    'switch model warning helper token',
    'className="mt-2 text-xs text-yellow-600 dark:text-yellow-400"',
    'className="mt-2 text-xs text-text-warning"'
  );
  source = replaceAllRequired(
    source,
    'switch model custom input native',
    'className="border-2 px-4 py-5"',
    'className="bg-background-primary/70 px-4 py-5 focus:bg-background-secondary/72 focus:border-transparent focus-visible:ring-0"'
  );
  source = replaceRequired(
    source,
    'switch model back link native',
    '<button\n                          onClick={() => setIsCustomModel(false)}\n                          className="text-sm text-text-secondary"',
    '<button\n                          onClick={() => setIsCustomModel(false)}\n                          className="text-sm text-[var(--epistemos-accent)] hover:underline"'
  );
  source = replaceRequired(
    source,
    'switch model quickstart native link',
    'className="inline-flex items-center text-text-secondary hover:text-text-primary text-sm mr-auto"',
    'className="mr-auto inline-flex items-center text-sm text-text-secondary transition-colors hover:text-[var(--epistemos-accent)]"'
  );
  write('src/components/settings/models/subcomponents/SwitchModelModal.tsx', source);
}

function applyKeyboardSettingsSurfaces() {
  let source = read('src/components/settings/keyboard/ShortcutRecorder.tsx');
  source = replaceRequired(
    source,
    'shortcut recorder native base',
    'text-xs font-mono px-3 py-2 rounded border',
    'min-h-9 rounded-[8px] px-3 py-2 font-mono text-xs transition-colors duration-200 ease-[var(--epistemos-control-ease)]'
  );
  source = replaceRequired(
    source,
    'shortcut recorder recording state native',
    "? 'bg-background-primary ring-1'",
    "? 'bg-[var(--epistemos-accent)]/12'"
  );
  source = replaceRequired(
    source,
    'shortcut recorder conflict state native',
    "? 'bg-background-secondary border-yellow-600/50'",
    "? 'bg-background-warning/55 text-text-warning'"
  );
  source = replaceRequired(
    source,
    'shortcut recorder idle state native',
    ": 'bg-background-secondary border-border-primary cursor-pointer'",
    ": 'bg-background-secondary/60 cursor-pointer hover:bg-background-secondary/72'"
  );
  source = replaceRequired(
    source,
    'shortcut recorder focus native',
    'focus:outline-none focus:ring-1',
    'focus:outline-none focus:ring-0'
  );
  source = replaceAllRequired(
    source,
    'shortcut recorder conflict text token',
    "conflict ? 'text-yellow-600' : 'text-text-primary'",
    "conflict ? 'text-text-warning' : 'text-text-primary'"
  );
  source = replaceAllRequired(
    source,
    'shortcut recorder action buttons native',
    'className="text-xs"',
    'className="rounded-[8px] text-xs"'
  );
  source = replaceRequired(
    source,
    'shortcut recorder warning row native',
    'className="text-xs text-yellow-600 flex items-center gap-1"',
    'className="flex items-center gap-1 text-xs text-text-warning"'
  );
  write('src/components/settings/keyboard/ShortcutRecorder.tsx', source);

  source = read('src/components/settings/keyboard/KeyboardShortcutsSection.tsx');
  source = replaceRequired(
    source,
    'keyboard restart warning native card',
    'className="rounded-lg border-yellow-600/50 bg-yellow-600/10"',
    'className="bg-background-warning/55"'
  );
  source = replaceAllRequired(
    source,
    'keyboard cards native glass',
    'className="rounded-lg"',
    'className="bg-background-primary/54"'
  );
  source = replaceAllRequired(
    source,
    'keyboard rows native hover',
    'className="flex items-center justify-between"',
    'className="flex items-center justify-between rounded-[9px] px-3 py-2.5 transition-colors hover:bg-background-secondary/60"'
  );
  source = replaceRequired(
    source,
    'keyboard shortcut chip native',
    'className="text-xs font-mono px-2 py-1 bg-background-secondary rounded min-w-[120px] text-center"',
    'className="ep-native-badge min-w-[120px] px-2 py-1 text-center text-xs"'
  );
  source = replaceRequired(
    source,
    'keyboard disabled chip native',
    'className="text-xs text-text-secondary min-w-[120px] text-center"',
    'className="ep-native-badge min-w-[120px] px-2 py-1 text-center text-xs text-text-secondary"'
  );
  source = replaceAllRequired(
    source,
    'keyboard small buttons native',
    'className="text-xs"',
    'className="rounded-[8px] text-xs"'
  );
  source = replaceRequired(
    source,
    'keyboard dismiss button native',
    'className="text-xs shrink-0"',
    'className="shrink-0 rounded-[8px] text-xs"'
  );
  write('src/components/settings/keyboard/KeyboardShortcutsSection.tsx', source);
}

function applyAuthSettingsSurfaces() {
  let source = read('src/components/settings/auth/AuthSettingsSection.tsx');
  source = replaceRequired(
    source,
    'auth expired badge native token',
    "return 'border-red-500/30 bg-red-500/10 text-red-700 dark:text-red-300';",
    "return 'bg-background-danger/55 text-text-danger';"
  );
  source = replaceRequired(
    source,
    'auth valid badge native token',
    "return 'border-green-500/30 bg-green-500/10 text-green-700 dark:text-green-300';",
    "return 'bg-background-success/55 text-text-success';"
  );
  source = replaceRequired(
    source,
    'auth card native glass',
    '<Card className="pb-2">',
    '<Card className="bg-background-primary/54 pb-2">'
  );
  source = replaceRequired(
    source,
    'auth content spacing native',
    '<CardContent className="px-4 py-2">',
    '<CardContent className="px-4 py-3">'
  );
  source = replaceRequired(
    source,
    'auth list spacing native',
    '<div className="divide-y divide-border-primary">',
    '<div className="space-y-2">'
  );
  source = replaceRequired(
    source,
    'auth credential row native',
    'className="flex flex-col gap-3 py-3 sm:flex-row sm:items-center sm:justify-between"',
    'className="flex flex-col gap-3 rounded-[10px] px-3 py-3 transition-colors hover:bg-background-secondary/60 sm:flex-row sm:items-center sm:justify-between"'
  );
  source = replaceRequired(
    source,
    'auth storage badge native',
    'className="rounded border border-border-primary bg-background-secondary px-2 py-0.5 text-xs text-text-secondary"',
    'className="ep-native-badge px-2 py-0.5 text-xs text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'auth expiry badge native',
    'className={`rounded border px-2 py-0.5 text-xs ${expiryClass(secret)}`}',
    'className={`ep-native-badge px-2 py-0.5 text-xs ${expiryClass(secret)}`}'
  );
  source = replaceRequired(
    source,
    'auth configure button native',
    'className="gap-2"',
    'className="gap-2 rounded-[8px]"'
  );
  source = replaceRequired(
    source,
    'auth delete button native',
    'className="text-text-secondary hover:text-text-primary"',
    'className="text-text-secondary transition-colors hover:text-text-danger"'
  );
  write('src/components/settings/auth/AuthSettingsSection.tsx', source);

  source = read('src/components/settings/auth/HuggingFaceSignInPrompt.tsx');
  source = replaceRequired(
    source,
    'huggingface sign-in prompt native glass',
    'className={`flex flex-col gap-3 rounded-lg border border-border-subtle bg-background-default p-3 sm:flex-row sm:items-center sm:justify-between ${className ?? \'\'}`}',
    'className={`flex flex-col gap-3 rounded-[10px] bg-background-primary/54 p-3 sm:flex-row sm:items-center sm:justify-between ${className ?? \'\'}`}'
  );
  source = replaceRequired(
    source,
    'huggingface sign-in title token',
    'className="text-sm font-medium text-text-default"',
    'className="text-sm font-medium text-text-primary"'
  );
  source = replaceRequired(
    source,
    'huggingface sign-in description token',
    'className="mt-1 text-xs text-text-muted"',
    'className="mt-1 text-xs text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'huggingface sign-in button native',
    'className="gap-2 self-start sm:self-auto"',
    'className="gap-2 self-start rounded-[8px] sm:self-auto"'
  );
  write('src/components/settings/auth/HuggingFaceSignInPrompt.tsx', source);
}

function applyLocalInferenceSurfaces() {
  let source = read('src/components/settings/localInference/LocalInferenceSettings.tsx');
  source = replaceRequired(
    source,
    'local vision downloaded badge native',
    'className="inline-flex items-center gap-1 text-xs text-green-400 bg-green-500/10 px-2 py-0.5 rounded"',
    'className="ep-native-badge gap-1 px-2 py-0.5 text-xs text-text-success"'
  );
  source = replaceRequired(
    source,
    'local vision downloading badge native',
    'className="inline-flex items-center gap-1 text-xs text-yellow-400 bg-yellow-500/10 px-2 py-0.5 rounded"',
    'className="ep-native-badge gap-1 px-2 py-0.5 text-xs text-text-warning"'
  );
  source = replaceRequired(
    source,
    'local vision idle badge native',
    'className="inline-flex items-center gap-1 text-xs text-text-muted bg-background-subtle px-2 py-0.5 rounded"',
    'className="ep-native-badge gap-1 px-2 py-0.5 text-xs text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'local downloads card native',
    'className="border rounded-lg p-3 border-border-subtle bg-background-default"',
    'className="rounded-[10px] bg-background-primary/54 p-3"'
  );
  source = replaceAllRequired(
    source,
    'local destructive icon buttons native',
    'className="text-destructive hover:text-destructive"',
    'className="text-text-secondary transition-colors hover:text-text-danger"'
  );
  source = replaceRequired(
    source,
    'local progress track native',
    'className="w-full bg-background-secondary rounded-[3px] h-2"',
    'className="h-2 w-full overflow-hidden rounded-full bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'local progress fill native',
    'className="bg-primary h-2 rounded-[3px] transition-all duration-300"',
    'className="h-2 rounded-full bg-[var(--epistemos-accent)] transition-all duration-300 ease-[var(--epistemos-control-ease)]"'
  );
  source = replaceRequired(
    source,
    'local failed progress error token',
    'className="text-xs text-destructive"',
    'className="text-xs text-text-danger"'
  );
  source = replaceRequired(
    source,
    'local downloaded card base native',
    'className={`border rounded-lg p-3 transition-colors ${',
    'className={`rounded-[10px] p-3 transition-colors ${'
  );
  source = replaceRequired(
    source,
    'local selected card native',
    "? 'border-accent-primary bg-accent-primary/5'",
    "? 'bg-[var(--epistemos-accent)]/12'"
  );
  source = replaceRequired(
    source,
    'local unselected card native',
    ": 'border-border-subtle bg-background-default hover:border-border-default'",
    ": 'bg-background-primary/54 hover:bg-background-secondary/62'"
  );
  source = replaceAllRequired(
    source,
    'local recommended badges native',
    'className="text-xs bg-blue-500 text-white px-2 py-0.5 rounded"',
    'className="ep-native-badge px-2 py-0.5 text-xs text-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'local featured card native',
    'className="border rounded-lg p-3 border-border-subtle bg-background-default hover:border-border-default"',
    'className="rounded-[10px] bg-background-primary/54 p-3 transition-colors hover:bg-background-secondary/62"'
  );
  source = replaceRequired(
    source,
    'local show featured toggle native',
    'className="w-full text-text-muted hover:text-text-default mt-2"',
    'className="mt-2 w-full rounded-[8px] text-text-secondary hover:text-text-primary"'
  );
  source = replaceRequired(
    source,
    'local search separator native',
    '<div className="border-t border-border-subtle pt-4">',
    '<div className="pt-5">'
  );
  source = replaceRequired(
    source,
    'local settings dialog native',
    '<DialogContent className="max-h-[80vh] overflow-y-auto sm:max-w-xl">',
    '<DialogContent className="max-h-[80vh] overflow-y-auto bg-background-primary/92 sm:max-w-xl">'
  );
  write('src/components/settings/localInference/LocalInferenceSettings.tsx', source);

  source = read('src/components/settings/localInference/HuggingFaceModelSearch.tsx');
  source = replaceRequired(
    source,
    'hf search title native token',
    'className="text-sm font-medium text-text-default mb-2"',
    'className="mb-2 text-sm font-medium text-text-primary"'
  );
  source = replaceRequired(
    source,
    'hf search input native',
    'className="w-full pl-9 pr-4 py-2 text-sm border border-border-subtle rounded-lg bg-background-default text-text-default placeholder:text-text-muted focus:outline-none focus:border-accent-primary"',
    'className="min-h-9 w-full rounded-[9px] bg-background-primary/70 py-2 pl-9 pr-4 text-sm text-text-primary placeholder:text-text-secondary transition-colors duration-200 ease-[var(--epistemos-control-ease)] focus:bg-background-secondary/72 focus:outline-none focus:ring-0"'
  );
  source = replaceRequired(
    source,
    'hf search error native',
    '{error && !searching && <p className="text-xs text-text-muted">{error}</p>}',
    '{error && !searching && <p className="text-xs text-text-danger">{error}</p>}'
  );
  source = replaceRequired(
    source,
    'hf result list spacing native',
    '<div className="space-y-1">',
    '<div className="space-y-2">'
  );
  source = replaceRequired(
    source,
    'hf repo card native',
    'className="border border-border-subtle rounded-lg"',
    'className="rounded-[10px] bg-background-primary/54"'
  );
  source = replaceRequired(
    source,
    'hf repo button native',
    'className="w-full flex items-center justify-between p-3 text-left hover:bg-background-subtle rounded-lg"',
    'className="flex w-full items-center justify-between rounded-[10px] p-3 text-left transition-colors hover:bg-background-secondary/60"'
  );
  source = replaceRequired(
    source,
    'hf variants panel native',
    'className="border-t border-border-subtle px-3 pb-3 space-y-1"',
    'className="space-y-1 px-3 pb-3 pt-2"'
  );
  source = replaceRequired(
    source,
    'hf variant row base native',
    'className={`flex items-center justify-between py-2 px-2 rounded ${',
    'className={`flex items-center justify-between rounded-[9px] px-2 py-2 transition-colors ${'
  );
  source = replaceRequired(
    source,
    'hf downloaded variant native',
    "? 'bg-green-500/5 border border-green-500/20'",
    "? 'bg-background-success/55'"
  );
  source = replaceRequired(
    source,
    'hf recommended variant native',
    "? 'bg-blue-500/5 border border-blue-500/20'",
    "? 'bg-[var(--epistemos-accent)]/12'"
  );
  source = replaceRequired(
    source,
    'hf neutral variant native',
    ": 'hover:bg-background-subtle'",
    ": 'hover:bg-background-secondary/60'"
  );
  source = replaceRequired(
    source,
    'hf format badge native',
    'className="text-xs rounded bg-background-muted border border-border-subtle px-1.5 py-0.5 text-text-muted uppercase"',
    'className="ep-native-badge px-1.5 py-0.5 text-xs uppercase text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'hf recommended badge native',
    'className="inline-flex items-center gap-1 text-xs bg-blue-500 text-white px-1.5 py-0.5 rounded"',
    'className="ep-native-badge gap-1 px-1.5 py-0.5 text-xs text-[var(--epistemos-accent)]"'
  );
  source = replaceAllRequired(
    source,
    'hf memory warning token',
    'className="inline-flex items-center gap-1 text-xs text-amber-500"',
    'className="inline-flex items-center gap-1 text-xs text-text-warning"'
  );
  source = replaceAllRequired(
    source,
    'hf disabled buttons native',
    'className="opacity-60"',
    'className="rounded-[8px] opacity-60"'
  );
  write('src/components/settings/localInference/HuggingFaceModelSearch.tsx', source);

  source = read('src/components/settings/localInference/ModelSettingsPanel.tsx');
  source = replaceRequired(
    source,
    'local number field native input',
    'className="w-full rounded border border-border-subtle bg-background-default px-2 py-1 text-sm text-text-default"',
    'className="min-h-8 w-full rounded-[8px] bg-background-primary/70 px-2 py-1 text-sm text-text-primary transition-colors focus:bg-background-secondary/72 focus:outline-none focus:ring-0"'
  );
  source = replaceAllRequired(
    source,
    'local settings compact rows native',
    'className="flex items-center justify-between gap-2"',
    'className="flex items-center justify-between gap-2 rounded-[9px] px-2 py-2 transition-colors hover:bg-background-secondary/60"'
  );
  source = replaceRequired(
    source,
    'local select field native',
    'className="rounded border border-border-subtle bg-background-default px-2 py-1 text-xs text-text-default"',
    'className="min-h-8 rounded-[8px] bg-background-primary/70 px-2 py-1 text-xs text-text-primary transition-colors focus:bg-background-secondary/72 focus:outline-none focus:ring-0"'
  );
  source = replaceRequired(
    source,
    'local textarea field native',
    'className="min-h-32 rounded border border-border-subtle bg-background-default px-2 py-1 font-mono text-xs text-text-default"',
    'className="min-h-32 rounded-[8px] bg-background-primary/70 px-2 py-1 font-mono text-xs text-text-primary transition-colors focus:bg-background-secondary/72 focus:outline-none focus:ring-0"'
  );
  source = replaceRequired(
    source,
    'local reset button native',
    '<Button variant="ghost" size="sm" onClick={resetDefaults} title={intl.formatMessage(i18n.resetToDefaults)}>',
    '<Button variant="ghost" size="sm" className="rounded-[8px]" onClick={resetDefaults} title={intl.formatMessage(i18n.resetToDefaults)}>'
  );
  write('src/components/settings/localInference/ModelSettingsPanel.tsx', source);
}

function applyGatewaySettingsSurfaces() {
  let source = read('src/components/settings/gateways/GatewaySettingsSection.tsx');
  source = replaceRequired(
    source,
    'gateway error banner native',
    'className="p-3 bg-red-100 dark:bg-red-900/20 border border-red-300 dark:border-red-800 rounded text-sm text-red-800 dark:text-red-200 mb-4"',
    'className="mb-4 rounded-[10px] bg-background-danger/55 p-3 text-sm text-text-danger"'
  );
  source = replaceRequired(
    source,
    'gateway paired users spacing native',
    '<div className="space-y-1 mt-2">',
    '<div className="mt-2 space-y-2">'
  );
  source = replaceRequired(
    source,
    'gateway paired users heading token',
    'className="text-xs text-text-muted font-medium"',
    'className="text-xs font-medium text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'gateway paired user row native',
    'className="flex items-center justify-between py-1.5 px-2 bg-background-muted rounded text-sm"',
    'className="flex items-center justify-between rounded-[9px] bg-background-primary/54 px-2 py-1.5 text-sm"'
  );
  source = replaceRequired(
    source,
    'gateway paired user icon token',
    'className="h-3 w-3 text-text-muted flex-shrink-0"',
    'className="h-3 w-3 flex-shrink-0 text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'gateway unpair button native',
    'className="h-6 w-6 p-0 text-text-muted hover:text-red-600 flex-shrink-0"',
    'className="h-6 w-6 flex-shrink-0 rounded-[8px] p-0 text-text-secondary transition-colors hover:text-text-danger"'
  );
  source = replaceRequired(
    source,
    'gateway card native glass',
    '<Card className="rounded-lg">',
    '<Card className="bg-background-primary/54">'
  );
  source = replaceRequired(
    source,
    'gateway running badge native',
    'className="inline-flex items-center text-[10px] font-mono uppercase text-text-primary bg-background-secondary border border-border-primary px-2 py-0.5 rounded-[3px]"',
    'className="ep-native-badge px-2 py-0.5 text-[10px] uppercase text-text-success"'
  );
  source = replaceRequired(
    source,
    'gateway stopped badge native',
    'className="inline-flex items-center text-[10px] font-mono uppercase text-text-muted bg-background-secondary border border-border-primary px-2 py-0.5 rounded-[3px]"',
    'className="ep-native-badge px-2 py-0.5 text-[10px] uppercase text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'gateway pair device button native',
    '<Button variant="outline" size="sm" onClick={onGenerateCode}>',
    '<Button variant="outline" size="sm" className="rounded-[8px]" onClick={onGenerateCode}>'
  );
  source = replaceRequired(
    source,
    'gateway stop button native',
    '<Button variant="destructive" size="sm" disabled={busy} onClick={wrap(onStop)}>',
    '<Button variant="destructive" size="sm" className="rounded-[8px]" disabled={busy} onClick={wrap(onStop)}>'
  );
  source = replaceRequired(
    source,
    'gateway restart button native',
    '<Button size="sm" disabled={busy} onClick={wrap(onRestart)}>',
    '<Button size="sm" className="rounded-[8px]" disabled={busy} onClick={wrap(onRestart)}>'
  );
  source = replaceRequired(
    source,
    'gateway remove button native',
    'className="text-red-600 hover:text-red-700 hover:bg-red-50 dark:text-red-400 dark:hover:text-red-300 dark:hover:bg-red-900/20"',
    'className="rounded-[8px] text-text-danger hover:bg-background-danger/55 hover:text-text-danger"'
  );
  source = replaceRequired(
    source,
    'gateway token input native',
    'className="text-sm"',
    'className="min-h-9 rounded-[8px] text-sm"'
  );
  source = replaceRequired(
    source,
    'gateway first start button native',
    '<Button size="sm" onClick={handleFirstStart} disabled={busy || !botToken.trim()}>',
    '<Button size="sm" className="rounded-[8px]" onClick={handleFirstStart} disabled={busy || !botToken.trim()}>'
  );
  source = replaceRequired(
    source,
    'gateway pairing dialog native',
    '<DialogContent className="sm:max-w-[400px]">',
    '<DialogContent className="bg-background-primary/92 sm:max-w-[400px]">'
  );
  source = replaceRequired(
    source,
    'gateway copy button native',
    'className="flex-shrink-0"',
    'className="flex-shrink-0 rounded-[8px]"'
  );
  source = replaceRequired(
    source,
    'gateway close button native',
    '<Button variant="outline" onClick={onClose}>',
    '<Button variant="outline" className="rounded-[8px]" onClick={onClose}>'
  );
  write('src/components/settings/gateways/GatewaySettingsSection.tsx', source);
}

function applyDictationSettingsSurfaces() {
  let source = read('src/components/settings/dictation/DictationSettings.tsx');
  source = replaceRequired(
    source,
    'dictation provider row native',
    'className="flex items-center justify-between py-2 px-2 hover:bg-background-secondary rounded-lg transition-all"',
    'className="flex items-center justify-between rounded-[9px] px-2 py-2 transition-colors hover:bg-background-secondary/60"'
  );
  source = replaceRequired(
    source,
    'dictation provider dropdown native',
    'className="flex items-center gap-2 px-3 py-1.5 text-sm border border-border-primary rounded-md hover:border-border-primary transition-colors text-text-primary bg-background-primary"',
    'className="flex min-h-9 items-center gap-2 rounded-[8px] bg-background-primary/70 px-3 py-1.5 text-sm text-text-primary transition-colors hover:bg-background-secondary/72"'
  );
  source = replaceAllRequired(
    source,
    'dictation config panels native',
    'className="py-2 px-2 bg-background-secondary rounded-lg"',
    'className="rounded-[10px] bg-background-primary/54 px-2 py-2"'
  );
  source = replaceAllRequired(
    source,
    'dictation configured text token',
    'text-green-600',
    'text-text-success'
  );
  source = replaceRequired(
    source,
    'dictation edit key button native',
    '<Button variant="outline" size="sm" onClick={() => setIsEditingKey(true)}>',
    '<Button variant="outline" size="sm" className="rounded-[8px]" onClick={() => setIsEditingKey(true)}>'
  );
  source = replaceRequired(
    source,
    'dictation remove key button native',
    '<Button variant="destructive" size="sm" onClick={handleRemoveKey}>',
    '<Button variant="destructive" size="sm" className="rounded-[8px]" onClick={handleRemoveKey}>'
  );
  source = replaceRequired(
    source,
    'dictation key input native',
    'className="max-w-md"',
    'className="min-h-9 max-w-md rounded-[8px]"'
  );
  source = replaceRequired(
    source,
    'dictation save button native',
    '<Button size="sm" onClick={handleSaveKey}>',
    '<Button size="sm" className="rounded-[8px]" onClick={handleSaveKey}>'
  );
  source = replaceRequired(
    source,
    'dictation cancel button native',
    '<Button variant="outline" size="sm" onClick={handleCancelEdit}>',
    '<Button variant="outline" size="sm" className="rounded-[8px]" onClick={handleCancelEdit}>'
  );
  write('src/components/settings/dictation/DictationSettings.tsx', source);

  source = read('src/components/settings/dictation/MicrophoneSelector.tsx');
  source = replaceAllRequired(
    source,
    'microphone rows native',
    'className="flex items-center justify-between py-2 px-2 hover:bg-background-secondary rounded-lg transition-all"',
    'className="flex items-center justify-between rounded-[9px] px-2 py-2 transition-colors hover:bg-background-secondary/60"'
  );
  source = replaceRequired(
    source,
    'microphone grant button native',
    '<Button variant="outline" size="sm" onClick={requestPermission}>',
    '<Button variant="outline" size="sm" className="rounded-[8px]" onClick={requestPermission}>'
  );
  source = replaceRequired(
    source,
    'microphone dropdown native',
    'className="flex items-center gap-2 px-3 py-1.5 text-sm border border-border-primary rounded-md hover:border-border-primary transition-colors text-text-primary bg-background-primary max-w-[220px]"',
    'className="flex min-h-9 max-w-[220px] items-center gap-2 rounded-[8px] bg-background-primary/70 px-3 py-1.5 text-sm text-text-primary transition-colors hover:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'microphone test button native',
    'className="shrink-0"',
    'className="shrink-0 rounded-[8px]"'
  );
  source = replaceRequired(
    source,
    'microphone meter track native',
    'className="w-full bg-background-secondary rounded-[3px] h-2 overflow-hidden"',
    'className="h-2 w-full overflow-hidden rounded-full bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'microphone meter fill native',
    'className="bg-primary h-2 rounded-[3px] transition-all duration-75"',
    'className="h-2 rounded-full bg-[var(--epistemos-accent)] transition-all duration-75"'
  );
  write('src/components/settings/dictation/MicrophoneSelector.tsx', source);

  source = read('src/components/settings/dictation/LocalModelManager.tsx');
  source = replaceRequired(
    source,
    'dictation local model card base native',
    'className={`border rounded-lg p-3 transition-colors ${',
    'className={`rounded-[10px] p-3 transition-colors ${'
  );
  source = replaceRequired(
    source,
    'dictation local model selected native',
    "? 'border-text-inverse bg-background-inverse/5'",
    "? 'bg-[var(--epistemos-accent)]/12'"
  );
  source = replaceRequired(
    source,
    'dictation local model unselected native',
    ": 'border-border-primary bg-background-primary hover:border-border-primary'",
    ": 'bg-background-primary/54 hover:bg-background-secondary/62'"
  );
  source = replaceRequired(
    source,
    'dictation recommended badge native',
    'className="text-xs bg-blue-500 text-white px-2 py-0.5 rounded"',
    'className="ep-native-badge px-2 py-0.5 text-xs text-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'dictation active badge native',
    'className="text-xs bg-background-inverse text-white px-2 py-0.5 rounded"',
    'className="ep-native-badge px-2 py-0.5 text-xs text-text-primary"'
  );
  source = replaceRequired(
    source,
    'dictation recommended text token',
    'className="text-xs text-blue-600 mt-1 font-medium"',
    'className="mt-1 text-xs font-medium text-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'dictation downloaded text token',
    'className="flex items-center gap-1 text-xs text-green-600"',
    'className="flex items-center gap-1 text-xs text-text-success"'
  );
  source = replaceRequired(
    source,
    'dictation destructive icon native',
    'className="text-destructive hover:text-destructive"',
    'className="rounded-[8px] text-text-secondary transition-colors hover:text-text-danger"'
  );
  source = replaceRequired(
    source,
    'dictation cancel download button native',
    '<Button variant="ghost" size="sm" onClick={() => cancelDownload(model.id)}>',
    '<Button variant="ghost" size="sm" className="rounded-[8px]" onClick={() => cancelDownload(model.id)}>'
  );
  source = replaceRequired(
    source,
    'dictation download button native',
    '<Button variant="outline" size="sm" onClick={() => startDownload(model.id)}>',
    '<Button variant="outline" size="sm" className="rounded-[8px]" onClick={() => startDownload(model.id)}>'
  );
  source = replaceRequired(
    source,
    'dictation local progress track native',
    'className="w-full bg-background-secondary rounded-[3px] h-1.5"',
    'className="h-1.5 w-full overflow-hidden rounded-full bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'dictation local progress fill native',
    'className="bg-background-inverse h-1.5 rounded-[3px] transition-all"',
    'className="h-1.5 rounded-full bg-[var(--epistemos-accent)] transition-all"'
  );
  source = replaceRequired(
    source,
    'dictation failed text token',
    'className="mt-2 text-xs text-destructive"',
    'className="mt-2 text-xs text-text-danger"'
  );
  source = replaceRequired(
    source,
    'dictation show all button native',
    'className="w-full text-text-secondary hover:text-text-primary"',
    'className="w-full rounded-[8px] text-text-secondary hover:text-text-primary"'
  );
  write('src/components/settings/dictation/LocalModelManager.tsx', source);
}

function applySecuritySettingsSurfaces() {
  let source = read('src/components/settings/security/SecurityToggle.tsx');
  source = replaceAllRequired(
    source,
    'security endpoint inputs native base',
    'className={`w-full px-3 py-2 text-sm border rounded placeholder:text-text-secondary ${',
    'className={`min-h-9 w-full rounded-[8px] bg-background-primary/70 px-3 py-2 text-sm placeholder:text-text-secondary transition-colors focus:bg-background-secondary/72 focus:outline-none focus:ring-0 ${'
  );
  source = replaceRequired(
    source,
    'security threshold input native base',
    'className={`w-24 px-2 py-1 text-sm border rounded ${',
    'className={`min-h-8 w-24 rounded-[8px] bg-background-primary/70 px-2 py-1 text-sm transition-colors focus:bg-background-secondary/72 focus:outline-none focus:ring-0 ${'
  );
  source = replaceRequired(
    source,
    'security model select native base',
    'className={`w-full px-3 py-2 text-sm border rounded ${',
    'className={`min-h-9 w-full rounded-[8px] bg-background-primary/70 px-3 py-2 text-sm transition-colors focus:bg-background-secondary/72 focus:outline-none focus:ring-0 ${'
  );
  source = replaceAllRequired(
    source,
    'security enabled field state native',
    "? 'border-border-primary bg-background-primary text-text-primary'",
    "? 'bg-background-primary/70 text-text-primary'"
  );
  source = replaceAllRequired(
    source,
    'security disabled field state native',
    ": 'border-border-primary bg-background-secondary text-text-secondary cursor-not-allowed'",
    ": 'bg-background-secondary/56 text-text-secondary cursor-not-allowed'"
  );
  source = replaceRequired(
    source,
    'security main row native',
    'className="flex items-center justify-between py-2 px-2 hover:bg-background-secondary rounded-lg transition-all"',
    'className="flex items-center justify-between rounded-[9px] px-2 py-2 transition-colors hover:bg-background-secondary/60"'
  );
  source = replaceAllRequired(
    source,
    'security nested rows native',
    'className="flex items-center justify-between py-2 hover:bg-background-secondary rounded-lg transition-all"',
    'className="flex items-center justify-between rounded-[9px] px-2 py-2 transition-colors hover:bg-background-secondary/60"'
  );
  source = replaceAllRequired(
    source,
    'security override text token',
    'text-slate-500 dark:text-slate-400',
    'text-text-secondary'
  );
  source = replaceAllRequired(
    source,
    'security dividers native',
    'className="border-t border-border-primary pt-4"',
    'className="pt-4"'
  );
  source = replaceRequired(
    source,
    'security command classifier active token',
    'className="text-sm text-gray-700 dark:text-gray-300 mt-2"',
    'className="mt-2 text-sm text-text-success"'
  );
  write('src/components/settings/security/SecurityToggle.tsx', source);
}

function applySessionSharingSurfaces() {
  let source = read('src/components/settings/sessions/SessionSharingSection.tsx');
  source = replaceRequired(
    source,
    'session sharing card native glass',
    '<Card className="pb-2">',
    '<Card className="bg-background-primary/54 pb-2">'
  );
  source = replaceRequired(
    source,
    'session sharing content spacing native',
    '<CardContent className="px-4 py-2">',
    '<CardContent className="px-4 py-3">'
  );
  source = replaceRequired(
    source,
    'session sharing configured icon token',
    '<Check className="w-5 h-5 text-green-500" />',
    '<Check className="h-5 w-5 text-text-success" />'
  );
  source = replaceRequired(
    source,
    'session sharing URL error token',
    '<p className="text-red-500 text-sm">{urlError}</p>',
    '<p className="text-sm text-text-danger">{urlError}</p>'
  );
  source = replaceRequired(
    source,
    'session sharing test button native',
    'className="flex items-center gap-2"',
    'className="flex items-center gap-2 rounded-[8px]"'
  );
  source = replaceRequired(
    source,
    'session sharing test result base native',
    'className={`flex items-start gap-2 p-3 rounded-md text-sm ${',
    'className={`flex items-start gap-2 rounded-[10px] p-3 text-sm ${'
  );
  source = replaceRequired(
    source,
    'session sharing success result native',
    "? 'bg-green-50 text-green-800 border border-green-200'",
    "? 'bg-background-success/55 text-text-success'"
  );
  source = replaceRequired(
    source,
    'session sharing error result native',
    ": 'bg-red-50 text-red-800 border border-red-200'",
    ": 'bg-background-danger/55 text-text-danger'"
  );
  write('src/components/settings/sessions/SessionSharingSection.tsx', source);
}

function applyUtilityListSurfaces() {
  let source = read('src/components/skills/SkillsView.tsx');
  source = replaceRequired(
    source,
    'skill item native card',
    'className="py-2 px-3 mb-2 bg-background-primary border border-border-secondary rounded-[6px] hover:bg-background-secondary transition-all duration-150"',
    'className="ep-native-list-card mb-2 border px-3 py-2 hover:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'skill title native font',
    'className="text-sm font-mono truncate"',
    'className="truncate text-sm font-sans font-semibold tracking-normal"'
  );
  source = replaceRequired(
    source,
    'skill skeleton native card',
    'className="p-2 mb-2 bg-background-primary"',
    'className="ep-native-list-card mb-2 p-2"'
  );
  source = replaceRequired(
    source,
    'skills error icon token',
    'className="h-12 w-12 text-red-500 mb-4"',
    'className="mb-4 h-12 w-12 text-text-danger"'
  );
  write('src/components/skills/SkillsView.tsx', source);

  source = read('src/components/recipes/RecipesView.tsx');
  source = replaceRequired(
    source,
    'recipe item native card',
    'className="py-2 px-3 mb-2 bg-background-primary border border-border-secondary rounded-[6px] hover:bg-background-secondary transition-all duration-150"',
    'className="ep-native-list-card mb-2 px-3 py-2 hover:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'recipe title native font',
    'className="text-sm font-mono truncate max-w-[50vw]"',
    'className="max-w-[50vw] truncate text-sm font-sans font-semibold tracking-normal"'
  );
  source = replaceRequired(
    source,
    'recipe metadata native font',
    'className="flex flex-col gap-1 text-[11px] text-text-secondary font-mono"',
    'className="flex flex-col gap-1 text-[11px] font-sans text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'recipe skeleton native card',
    'className="p-2 mb-2 bg-background-primary border border-border-secondary rounded-[6px]"',
    'className="ep-native-list-card mb-2 p-2"'
  );
  source = replaceRequired(
    source,
    'recipe delete action native',
    'className="h-8 w-8 p-0 text-red-500 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20"',
    'className="h-8 w-8 rounded-[8px] p-0 text-text-secondary hover:bg-background-danger/55 hover:text-text-danger"'
  );
  source = replaceRequired(
    source,
    'recipes error icon token',
    'className="h-12 w-12 text-red-500 mb-4"',
    'className="mb-4 h-12 w-12 text-text-danger"'
  );
  write('src/components/recipes/RecipesView.tsx', source);

  source = read('src/components/schedule/SchedulesView.tsx');
  source = replaceRequired(
    source,
    'schedule item native card',
    'className="py-2 px-3 mb-2 bg-background-primary border border-border-secondary rounded-[6px] hover:bg-background-secondary cursor-pointer transition-all duration-150"',
    'className="ep-native-list-card mb-2 cursor-pointer px-3 py-2 hover:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'schedule title native font',
    'className="text-sm font-mono truncate max-w-[50vw]"',
    'className="max-w-[50vw] truncate text-sm font-sans font-semibold tracking-normal"'
  );
  source = replaceAllRequired(
    source,
    'schedule badge native font',
    'rounded-[4px] text-[11px] font-mono bg-background-secondary',
    'ep-native-badge text-[11px] bg-background-secondary'
  );
  source = replaceRequired(
    source,
    'schedule cron native font',
    'className="text-text-secondary text-xs mb-2 line-clamp-2 font-mono"',
    'className="mb-2 line-clamp-2 text-xs font-sans text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'schedule last run native font',
    'className="flex items-center text-[11px] text-text-secondary font-mono"',
    'className="flex items-center text-[11px] font-sans text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'schedule error native panel',
    'className="mb-4 p-4 bg-background-danger border border-border-danger rounded-md"',
    'className="mb-4 rounded-[12px] bg-background-danger/55 p-4"'
  );
  source = replaceRequired(
    source,
    'schedule delete action native',
    'className="h-8 text-red-500 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20"',
    'className="h-8 rounded-[8px] text-text-secondary hover:bg-background-danger/55 hover:text-text-danger"'
  );
  write('src/components/schedule/SchedulesView.tsx', source);

  source = read('src/components/apps/AppsView.tsx');
  source = replaceRequired(
    source,
    'app item native card',
    'className="flex flex-col p-3 border border-border-secondary rounded-[6px] hover:border-border-primary transition-colors bg-background-primary"',
    'className="ep-native-list-card flex flex-col p-3 hover:bg-background-secondary/62"'
  );
  source = replaceRequired(
    source,
    'app badge native chip',
    'className="inline-block px-2 py-1 text-xs bg-background-secondary text-text-secondary rounded-[4px] font-mono"',
    'className="ep-native-badge inline-block px-2 py-1 text-xs text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'apps empty error token',
    'className="text-red-500 mb-4"',
    'className="mb-4 text-text-danger"'
  );
  write('src/components/apps/AppsView.tsx', source);
}

function applySessionListSurfaces() {
  let source = read('src/components/sessions/SessionListView.tsx');
  source = replaceRequired(
    source,
    'session edit modal overlay',
    'className="fixed inset-0 z-[300] flex items-center justify-center bg-black/50"',
    'className="fixed inset-0 z-[300] flex items-center justify-center bg-black/24 backdrop-blur-sm"'
  );
  source = replaceRequired(
    source,
    'session edit modal native card',
    'className="bg-background-primary border border-border-primary rounded-[6px] p-4 w-[500px] max-w-[90vw]"',
    'className="ep-native-screen-card w-[500px] max-w-[90vw] p-4"'
  );
  source = replaceRequired(
    source,
    'session edit modal title font',
    'className="text-sm font-mono text-text-primary mb-4"',
    'className="mb-4 text-sm font-sans font-semibold tracking-normal text-text-primary"'
  );
  source = replaceRequired(
    source,
    'session edit modal input native',
    'className="w-full p-3 border border-border-primary rounded-[5px] bg-background-primary text-text-primary text-sm font-mono focus:outline-none focus:ring-1 focus:ring-primary"',
    'className="w-full rounded-[8px] bg-background-primary/70 p-3 text-sm font-sans text-text-primary outline-none transition-all focus:bg-background-secondary/72 focus:border-transparent"'
  );
  source = replaceRequired(
    source,
    'session item native card',
    'className="h-full py-3 px-3 border border-border-secondary rounded-[6px] bg-background-primary hover:bg-background-secondary cursor-pointer transition-all duration-150 flex flex-col justify-between relative group"',
    'className="ep-native-list-card group relative flex h-full cursor-pointer flex-col justify-between px-3 py-3 hover:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'session title native font',
    'className="text-sm font-mono break-words line-clamp-2 w-full mb-1"',
    'className="mb-1 w-full break-words text-sm font-sans font-semibold tracking-normal line-clamp-2"'
  );
  source = replaceRequired(
    source,
    'session count native font',
    'className="font-mono"',
    'className="font-sans font-medium"'
  );
  source = replaceAllRequired(
    source,
    'session action native radius',
    'rounded-[4px] hover:bg-background-tertiary',
    'rounded-[8px] hover:bg-background-tertiary/80'
  );
  source = replaceRequired(
    source,
    'session delete action native',
    'className="p-2 rounded-[4px] hover:bg-red-50 dark:hover:bg-red-900/20 cursor-pointer transition-colors"',
    'className="cursor-pointer rounded-[8px] p-2 transition-colors hover:bg-background-danger/55"'
  );
  source = replaceRequired(
    source,
    'session delete icon token',
    '<Trash2 className="w-3 h-3 text-red-500 hover:text-red-600" />',
    '<Trash2 className="h-3 w-3 text-text-secondary transition-colors hover:text-text-danger" />'
  );
  source = replaceRequired(
    source,
    'session list error icon token',
    '<AlertCircle className="h-12 w-12 text-red-500 mb-4" />',
    '<AlertCircle className="mb-4 h-12 w-12 text-text-danger" />'
  );
  source = replaceRequired(
    source,
    'session group sticky native glass',
    'className="sticky top-0 z-10 bg-background-primary/95"',
    'className="ep-native-header-band sticky top-0 z-10 rounded-[10px] bg-background-primary/50 px-2 py-1"'
  );
  source = replaceAllRequired(
    source,
    'session dialog native radius',
    'className="sm:max-w-lg rounded-[6px]"',
    'className="sm:max-w-lg rounded-[14px]"'
  );
  source = replaceRequired(
    source,
    'session import textarea native',
    'className="min-h-28 w-full resize-none rounded-[5px] border border-border-primary bg-background-primary p-3 text-sm font-mono text-text-primary outline-none focus:ring-1 focus:ring-border-active"',
    'className="min-h-28 w-full resize-none rounded-[9px] bg-background-primary/70 p-3 text-sm font-sans text-text-primary outline-none transition-colors focus:bg-background-secondary/72 focus:border-transparent"'
  );
  source = replaceRequired(
    source,
    'session share code native panel',
    'className="relative rounded-[5px] border border-border-primary bg-background-secondary p-3 pr-12"',
    'className="relative rounded-[10px] bg-background-secondary/62 p-3 pr-12"'
  );
  write('src/components/sessions/SessionListView.tsx', source);
}

function applySessionDetailSurfaces() {
  let source = read('src/components/sessions/SharedSessionView.tsx');
  source = replaceRequired(
    source,
    'shared session header native glass',
    'className="flex flex-col pb-5 border-b border-border-secondary"',
    'className="ep-native-header-band flex flex-col rounded-[16px] bg-background-primary/42 p-4"'
  );
  source = replaceRequired(
    source,
    'shared session heading native font',
    'className="text-2xl font-mono font-normal mb-3 pt-4"',
    'className="mb-3 pt-4 text-2xl font-sans font-semibold tracking-normal"'
  );
  source = replaceRequired(
    source,
    'shared session banner native glass',
    'className="flex items-center py-3 border-b border-border-secondary mb-5"',
    'className="ep-native-header-band mb-5 flex items-center rounded-[12px] bg-background-primary/42 px-3 py-2"'
  );
  source = replaceRequired(
    source,
    'shared session badge native font',
    'className="text-xs font-mono uppercase"',
    'className="ep-native-badge text-xs text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'shared session metadata native font',
    'className="flex items-center text-text-secondary text-xs space-x-4 font-mono"',
    'className="flex items-center space-x-4 text-xs font-sans text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'shared session directory native font',
    'className="flex items-center text-text-secondary text-xs mt-1 font-mono"',
    'className="mt-1 flex items-center text-xs font-sans text-text-secondary"'
  );
  write('src/components/sessions/SharedSessionView.tsx', source);

  source = read('src/components/sessions/SessionHistoryView.tsx');
  source = replaceRequired(
    source,
    'session history header native glass',
    'className="flex flex-col pb-5 border-b border-border-secondary pt-14"',
    'className="ep-native-header-band flex flex-col rounded-[16px] bg-background-primary/42 p-4 pt-5"'
  );
  source = replaceRequired(
    source,
    'session history heading native font',
    'className="text-2xl font-mono font-normal mb-3 pt-4"',
    'className="mb-3 pt-4 text-2xl font-sans font-semibold tracking-normal"'
  );
  source = replaceRequired(
    source,
    'session history metadata native font',
    'className="flex items-center text-text-secondary text-xs space-x-4 font-mono"',
    'className="flex items-center space-x-4 text-xs font-sans text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'session history directory native font',
    'className="flex items-center text-text-secondary text-xs mt-1 font-mono"',
    'className="mt-1 flex items-center text-xs font-sans text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'session history share dialog radius',
    '<DialogContent className="sm:max-w-md rounded-[6px]">',
    '<DialogContent className="sm:max-w-md rounded-[14px]">'
  );
  source = replaceRequired(
    source,
    'session history share dialog title font',
    '<DialogTitle className="flex justify-center items-center gap-2 font-mono">',
    '<DialogTitle className="flex items-center justify-center gap-2 font-sans font-semibold tracking-normal">'
  );
  source = replaceRequired(
    source,
    'session history share link native panel',
    'className="relative rounded-[5px] border border-border-primary px-3 py-2 flex items-center bg-background-secondary"',
    'className="relative flex items-center rounded-[10px] bg-background-secondary/62 px-3 py-2"'
  );
  source = replaceRequired(
    source,
    'session history error icon token',
    'className="text-red-500 mb-4"',
    'className="mb-4 text-text-danger"'
  );
  write('src/components/sessions/SessionHistoryView.tsx', source);

  source = read('src/components/sessions/SessionViewComponents.tsx');
  source = replaceRequired(
    source,
    'session detail error icon token',
    'className="text-red-500 mb-4"',
    'className="mb-4 text-text-danger"'
  );
  write('src/components/sessions/SessionViewComponents.tsx', source);
}

function applySchedulerDetailSurfaces() {
  let source = read('src/components/schedule/ScheduleDetailView.tsx');
  source = replaceRequired(
    source,
    'schedule detail transparent root',
    'className="h-screen w-full flex flex-col bg-background-primary text-text-primary"',
    'className="h-screen w-full flex flex-col bg-transparent text-text-primary"'
  );
  source = replaceRequired(
    source,
    'schedule detail native header',
    'className="px-8 pt-6 pb-4 border-b border-border-primary flex-shrink-0"',
    'className="ep-native-header-band mx-6 mt-6 flex-shrink-0 rounded-[16px] bg-background-primary/42 px-5 pb-4 pt-4"'
  );
  source = replaceRequired(
    source,
    'schedule detail native heading',
    'className="text-4xl font-light mt-1 mb-1 pt-8"',
    'className="mb-1 mt-2 text-2xl font-sans font-semibold tracking-normal"'
  );
  source = replaceAllRequired(
    source,
    'schedule detail native error panels',
    'className="text-text-danger text-sm p-3 bg-background-danger border border-border-danger rounded-md"',
    'className="rounded-[12px] bg-background-danger/55 p-3 text-sm text-text-danger"'
  );
  source = replaceRequired(
    source,
    'schedule detail native info card',
    'className="p-4 bg-background-primary shadow-none mb-6 border border-border-primary rounded-[6px]"',
    'className="ep-native-screen-card mb-6 p-4"'
  );
  source = replaceRequired(
    source,
    'schedule detail running dot',
    'className="inline-block w-2 h-2 bg-primary mr-1 animate-pulse"',
    'className="ep-native-loading-dot is-active mr-1"'
  );
  source = replaceRequired(
    source,
    'schedule detail running text token',
    'className="text-sm text-green-500 dark:text-green-400 font-semibold flex items-center"',
    'className="flex items-center text-sm font-semibold text-text-success"'
  );
  source = replaceRequired(
    source,
    'schedule detail paused text token',
    'className="text-sm text-orange-500 dark:text-orange-400 font-semibold flex items-center"',
    'className="flex items-center text-sm font-semibold text-text-warning"'
  );
  source = replaceAllRequired(
    source,
    'schedule detail neutral outline actions',
    'text-blue-600 dark:text-blue-400 border-blue-300 dark:border-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/20',
    ''
  );
  source = replaceRequired(
    source,
    'schedule detail unpause button token',
    "'text-green-600 dark:text-green-400 border-green-300 dark:border-green-600 hover:bg-green-50 dark:hover:bg-green-900/20'",
    "'bg-background-success/35 text-text-success hover:bg-background-success/55'"
  );
  source = replaceRequired(
    source,
    'schedule detail pause button token',
    "'text-orange-600 dark:text-orange-400 border-orange-300 dark:border-orange-600 hover:bg-orange-50 dark:hover:bg-orange-900/20'",
    "'bg-background-warning/35 text-text-warning hover:bg-background-warning/55'"
  );
  source = replaceRequired(
    source,
    'schedule detail kill button token',
    'className="w-full md:w-auto flex items-center gap-2 text-red-600 dark:text-red-400 border-red-300 dark:border-red-600 hover:bg-red-50 dark:hover:bg-red-900/20"',
    'className="flex w-full items-center gap-2 bg-background-danger/35 text-text-danger hover:bg-background-danger/55 md:w-auto"'
  );
  source = replaceRequired(
    source,
    'schedule detail recent session card',
    'className="p-4 bg-background-primary shadow-none cursor-pointer hover:bg-background-secondary transition-colors duration-150 border border-border-primary rounded-[6px]"',
    'className="ep-native-list-card cursor-pointer p-4 hover:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'schedule detail session id font',
    '<span className="font-mono">{sessionId}</span>',
    '<span className="font-sans font-medium">{sessionId}</span>'
  );
  write('src/components/schedule/ScheduleDetailView.tsx', source);

  source = read('src/components/schedule/ScheduleModal.tsx');
  source = replaceRequired(
    source,
    'schedule modal native overlay',
    'className="fixed inset-0 bg-black/35 z-40 flex items-center justify-center p-4"',
    'className="fixed inset-0 z-40 flex items-center justify-center bg-black/24 p-4 backdrop-blur-sm"'
  );
  source = replaceRequired(
    source,
    'schedule modal native card',
    'className="w-full max-w-md bg-background-primary shadow-none rounded-[6px] z-50 flex flex-col max-h-[90vh] overflow-hidden border border-border-primary"',
    'className="ep-native-screen-card z-50 flex max-h-[90vh] w-full max-w-md flex-col overflow-hidden"'
  );
  source = replaceRequired(
    source,
    'schedule modal native header border',
    'className="px-5 pt-5 pb-3 flex-shrink-0 border-b border-border-primary"',
    'className="flex-shrink-0 px-5 pb-3 pt-5"'
  );
  source = replaceAllRequired(
    source,
    'schedule modal native error panels',
    'className="text-text-danger text-sm mb-3 p-2 border border-border-danger rounded-[6px]"',
    'className="mb-3 rounded-[12px] bg-background-danger/55 p-2 text-sm text-text-danger"'
  );
  source = replaceAllRequired(
    source,
    'schedule modal required token',
    'text-red-500',
    'text-text-danger'
  );
  source = replaceRequired(
    source,
    'schedule modal segmented native container',
    'className="grid grid-cols-2 border border-border-primary rounded-[6px] overflow-hidden"',
    'className="grid grid-cols-2 rounded-[10px] bg-background-secondary/56 p-1"'
  );
  source = replaceAllRequired(
    source,
    'schedule modal segmented native button font',
    'px-3 py-2 text-xs font-mono uppercase transition-colors',
    'rounded-[7px] px-3 py-2 text-xs font-sans font-medium tracking-normal transition-all'
  );
  source = replaceAllRequired(
    source,
    'schedule modal segmented selected native style',
    'bg-background-inverse text-background-primary',
    'bg-background-primary/78 text-text-primary'
  );
  source = replaceAllRequired(
    source,
    'schedule modal segmented inactive native style',
    'text-text-muted hover:bg-background-secondary hover:text-text-primary',
    'text-text-secondary hover:bg-background-primary/80 hover:text-text-primary'
  );
  source = replaceRequired(
    source,
    'schedule modal segmented divider native',
    'transition-all border-l border-border-primary',
    'transition-all'
  );
  source = replaceRequired(
    source,
    'schedule modal browse button radius',
    'className="w-full justify-center rounded-[6px]"',
    'className="w-full justify-center rounded-[8px]"'
  );
  source = replaceRequired(
    source,
    'schedule modal deeplink input radius',
    'className="rounded-[6px]"',
    'className="rounded-[8px]"'
  );
  source = replaceRequired(
    source,
    'schedule modal parsed recipe panel',
    'className="mt-2 p-2 bg-background-secondary rounded-[6px] border border-border-primary"',
    'className="mt-2 rounded-[10px] bg-background-secondary/62 p-2"'
  );
  source = replaceRequired(
    source,
    'schedule modal native footer border',
    'className="flex gap-2 px-8 py-4 border-t border-border-primary"',
    'className="flex gap-2 px-8 py-4"'
  );
  source = replaceRequired(
    source,
    'schedule modal cancel neutral style',
    'className="flex-1 text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800"',
    'className="flex-1"'
  );
  write('src/components/schedule/ScheduleModal.tsx', source);
}

function applyRecipeDetailSurfaces() {
  let source = read('src/components/recipes/CreateEditRecipeModal.tsx');
  source = replaceRequired(
    source,
    'recipe edit modal native overlay',
    'className="fixed inset-0 z-[400] flex items-center justify-center bg-black/50"',
    'className="fixed inset-0 z-[400] flex items-center justify-center bg-black/24 backdrop-blur-sm"'
  );
  source = replaceRequired(
    source,
    'recipe edit modal native card',
    'className="bg-background-primary border border-border-primary rounded-lg w-[90vw] max-w-4xl h-[90vh] flex flex-col"',
    'className="ep-native-screen-card flex h-[90vh] w-[90vw] max-w-4xl flex-col"'
  );
  source = replaceRequired(
    source,
    'recipe edit modal native header',
    'className="flex items-center justify-between p-6 border-b border-border-primary"',
    'className="flex items-center justify-between p-6"'
  );
  source = replaceRequired(
    source,
    'recipe edit modal native icon',
    'className="w-8 h-8 bg-background-primary border border-border-primary rounded-[6px] flex items-center justify-center"',
    'className="flex h-8 w-8 items-center justify-center rounded-[10px] bg-background-secondary/62"'
  );
  source = replaceRequired(
    source,
    'recipe edit modal native link token',
    'className="inline-flex items-center gap-1 text-blue-500 hover:text-blue-600 hover:underline"',
    'className="inline-flex items-center gap-1 text-[var(--epistemos-accent)] hover:opacity-80 hover:underline"'
  );
  source = replaceRequired(
    source,
    'recipe edit modal native close button',
    'className="p-2 hover:bg-background-secondary rounded-lg transition-colors"',
    'className="rounded-[8px] p-2 transition-colors hover:bg-background-secondary/80"'
  );
  source = replaceRequired(
    source,
    'recipe edit modal native deeplink card',
    'className="w-full p-4 bg-background-secondary rounded-lg mt-6"',
    'className="ep-native-screen-card mt-6 w-full p-4"'
  );
  source = replaceRequired(
    source,
    'recipe edit modal native copy button',
    'className="ml-4 p-2 hover:bg-background-primary rounded-lg transition-colors flex items-center disabled:opacity-50 disabled:hover:bg-transparent"',
    'className="ml-4 flex items-center rounded-[8px] p-2 transition-colors hover:bg-background-primary/80 disabled:opacity-50 disabled:hover:bg-transparent"'
  );
  source = replaceRequired(
    source,
    'recipe edit modal native footer',
    'className="flex items-center justify-between p-6 border-t border-border-primary"',
    'className="flex items-center justify-between p-6"'
  );
  source = replaceRequired(
    source,
    'recipe edit modal native close action',
    'className="px-4 py-2 text-text-secondary rounded-lg hover:bg-background-secondary transition-colors"',
    'className="rounded-[8px] px-4 py-2 text-text-secondary transition-colors hover:bg-background-secondary/80"'
  );
  source = replaceRequired(
    source,
    'recipe edit modal success icon token',
    '<Check className="w-4 h-4 text-green-500" />',
    '<Check className="h-4 w-4 text-text-success" />'
  );
  write('src/components/recipes/CreateEditRecipeModal.tsx', source);

  source = read('src/components/recipes/ImportRecipeForm.tsx');
  source = replaceAllRequired(
    source,
    'recipe import native overlay',
    'className="fixed inset-0 z-[300] flex items-center justify-center bg-black/50"',
    'className="fixed inset-0 z-[300] flex items-center justify-center bg-black/24 backdrop-blur-sm"'
  );
  source = replaceRequired(
    source,
    'recipe import native modal card',
    'className="bg-background-primary border border-border-primary rounded-lg p-6 w-[500px] max-w-[90vw]"',
    'className="ep-native-screen-card w-[500px] max-w-[90vw] p-6"'
  );
  source = replaceRequired(
    source,
    'recipe import native textarea',
    'className={`w-full p-3 border rounded-lg bg-background-primary text-text-primary focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none ${',
    'className={`w-full resize-none rounded-[10px] bg-background-primary/70 p-3 text-text-primary outline-none transition-colors focus:bg-background-secondary/72 focus:border-transparent ${'
  );
  source = replaceRequired(
    source,
    'recipe import divider native',
    'className="w-full border-t border-border-primary"',
    'className="h-px w-full bg-background-secondary/70"'
  );
  source = replaceRequired(
    source,
    'recipe import divider label native',
    'className="px-3 bg-background-primary text-text-secondary font-medium"',
    'className="px-3 text-text-secondary font-medium"'
  );
  source = replaceRequired(
    source,
    'recipe import example link token',
    'className="text-xs text-blue-500 hover:text-blue-700 underline"',
    'className="text-xs text-[var(--epistemos-accent)] underline hover:opacity-80"'
  );
  source = replaceRequired(
    source,
    'recipe import schema overlay native',
    'className="fixed inset-0 z-[400] flex items-center justify-center bg-black/50"',
    'className="fixed inset-0 z-[400] flex items-center justify-center bg-black/24 backdrop-blur-sm"'
  );
  source = replaceRequired(
    source,
    'recipe import schema modal native',
    'className="bg-background-primary border border-border-primary rounded-lg p-6 w-[800px] max-w-[90vw] max-h-[80vh] flex flex-col"',
    'className="ep-native-screen-card flex max-h-[80vh] w-[800px] max-w-[90vw] flex-col p-6"'
  );
  source = replaceRequired(
    source,
    'recipe import schema description token',
    'className="mt-4 text-blue-700 text-sm"',
    'className="mt-4 text-sm text-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'recipe import schema pre native',
    'className="text-xs bg-whitedark:bg-gray-800 p-4 rounded overflow-auto whitespace-pre font-mono"',
    'className="overflow-auto whitespace-pre rounded-[10px] bg-background-secondary/62 p-4 text-xs font-mono"'
  );
  source = replaceAllRequired(
    source,
    'recipe import invalid border token',
    'border-red-500',
    'bg-background-danger/35'
  );
  source = replaceAllRequired(
    source,
    'recipe import validation text token',
    'text-red-500',
    'text-text-danger'
  );
  write('src/components/recipes/ImportRecipeForm.tsx', source);

  source = read('src/components/RecipeHeader.tsx');
  source = replaceRequired(
    source,
    'recipe header activity dot token',
    'className="w-2 h-2 rounded-full bg-green-500 mr-2"',
    'className="mr-2 h-2 w-2 rounded-full bg-background-success ring-[3px] ring-text-success/15"'
  );
  write('src/components/RecipeHeader.tsx', source);

  source = read('src/components/recipes/RecipeActivities.tsx');
  source = replaceRequired(
    source,
    'recipe activities native status mark container',
    'className="flex h-6 w-6 items-center justify-center border border-border-primary bg-background-secondary"',
    'className="flex h-6 w-6 items-center justify-center rounded-full bg-background-secondary/62"'
  );
  source = replaceRequired(
    source,
    'recipe activities native status mark',
    'className="h-1.5 w-1.5 bg-primary"',
    'className="ep-native-loading-dot is-active"'
  );
  source = replaceRequired(
    source,
    'recipe activities native message panel',
    'className="mb-4 p-3 rounded-[6px] border border-border-primary animate-[fadein_500ms_ease-in_forwards]"',
    'className="ep-native-screen-card mb-4 p-3 animate-[fadein_500ms_ease-in_forwards]"'
  );
  source = replaceRequired(
    source,
    'recipe activities native pill',
    'className="cursor-pointer px-3 py-1.5 text-xs font-mono border border-border-secondary rounded-[5px] hover:bg-background-secondary transition-colors"',
    'className="ep-native-badge cursor-pointer px-3 py-1.5 text-xs transition-colors hover:bg-background-secondary/80"'
  );
  write('src/components/recipes/RecipeActivities.tsx', source);

  source = read('src/components/recipes/RecipeActivityEditor.tsx');
  source = replaceRequired(
    source,
    'recipe activity editor textarea native',
    'className="w-full px-4 py-3 border rounded-lg bg-background-primary text-text-primary placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-border-secondary resize-vertical"',
    'className="w-full resize-vertical rounded-[10px] bg-background-primary/70 px-4 py-3 text-text-primary placeholder:text-text-secondary outline-none transition-colors focus:bg-background-secondary/72 focus:border-transparent"'
  );
  source = replaceRequired(
    source,
    'recipe activity editor chip native',
    'className="inline-flex items-center bg-background-primary border border-border-primary rounded-[6px] px-3 py-2 text-sm text-text-primary"',
    'className="ep-native-badge inline-flex items-center px-3 py-2 text-sm text-text-primary"'
  );
  source = replaceRequired(
    source,
    'recipe activity editor input native',
    'className="flex-1 px-3 py-2 border border-border-primary rounded-lg bg-background-primary text-text-primary focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"',
    'className="flex-1 rounded-[10px] bg-background-primary/70 px-3 py-2 text-sm text-text-primary outline-none transition-colors focus:bg-background-secondary/72 focus:border-transparent"'
  );
  source = replaceRequired(
    source,
    'recipe activity editor add button native',
    'className="px-4 py-2 bg-blue-500 text-white rounded-lg text-sm hover:bg-blue-600 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed"',
    'className="rounded-[8px] bg-[var(--epistemos-accent)] px-4 py-2 text-sm font-semibold text-text-inverse transition-colors hover:bg-[var(--epistemos-accent)]/90 disabled:cursor-not-allowed disabled:bg-background-disabled disabled:text-text-disabled"'
  );
  write('src/components/recipes/RecipeActivityEditor.tsx', source);

  source = read('src/components/recipes/shared/RecipeNameField.tsx');
  source = replaceAllRequired(source, 'recipe name invalid border token', 'border-red-500', 'bg-background-danger/35');
  source = replaceAllRequired(source, 'recipe name validation text token', 'text-red-500', 'text-text-danger');
  write('src/components/recipes/shared/RecipeNameField.tsx', source);

  source = read('src/components/recipes/shared/InstructionsEditor.tsx');
  source = replaceAllRequired(source, 'recipe instructions invalid border token', 'border-red-500', 'bg-background-danger/35');
  source = replaceAllRequired(source, 'recipe instructions validation text token', 'text-red-500', 'text-text-danger');
  write('src/components/recipes/shared/InstructionsEditor.tsx', source);

  source = read('src/components/recipes/shared/JsonSchemaEditor.tsx');
  source = replaceAllRequired(source, 'recipe json schema invalid border token', 'border-red-500', 'bg-background-danger/35');
  source = replaceAllRequired(source, 'recipe json schema validation text token', 'text-red-500', 'text-text-danger');
  write('src/components/recipes/shared/JsonSchemaEditor.tsx', source);

  source = read('src/components/recipes/shared/RecipeFormFields.tsx');
  source = replaceAllRequired(source, 'recipe form invalid border token', 'border-red-500', 'bg-background-danger/35');
  source = replaceAllRequired(source, 'recipe form validation text token', 'text-red-500', 'text-text-danger');
  source = replaceRequired(
    source,
    'recipe prompt textarea borderless',
    'className="w-full p-3 border border-border-primary rounded-lg bg-background-primary text-text-primary focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"',
    'className="w-full resize-none rounded-[10px] bg-background-primary/60 p-3 text-text-primary outline-none transition-colors focus:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'recipe advanced trigger borderless',
    'className="flex items-baseline gap-2 w-full py-3 px-4 bg-background-secondary hover:bg-background-secondary/80 rounded-lg transition-colors border border-border-primary"',
    'className="flex w-full items-baseline gap-2 rounded-[12px] bg-background-secondary/56 px-4 py-3 transition-colors hover:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'recipe advanced content borderless',
    'className="mt-4 space-y-4 pl-6 border-l-2 border-border-primary ml-2"',
    'className="ml-2 mt-4 space-y-4 rounded-[12px] bg-background-secondary/32 px-4 py-3"'
  );
  source = replaceRequired(
    source,
    'recipe parameter input borderless',
    'className="flex-1 px-3 py-2 border border-border-primary rounded-lg bg-background-primary text-text-primary focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"',
    'className="flex-1 rounded-[10px] bg-background-primary/60 px-3 py-2 text-sm text-text-primary outline-none transition-colors focus:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'recipe form activity add button native',
    'className="px-4 py-2 bg-blue-500 text-white rounded-lg text-sm hover:bg-blue-600 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed"',
    'className="rounded-[8px] bg-[var(--epistemos-accent)] px-4 py-2 text-sm font-semibold text-text-inverse transition-colors hover:bg-[var(--epistemos-accent)]/90 disabled:cursor-not-allowed disabled:bg-background-disabled disabled:text-text-disabled"'
  );
  write('src/components/recipes/shared/RecipeFormFields.tsx', source);

  source = read('src/components/recipes/shared/SubRecipeEditor.tsx');
  source = replaceRequired(
    source,
    'sub recipe editor card native',
    'className="border border-border-subtle rounded-lg p-4 bg-background-default hover:bg-background-muted transition-colors"',
    'className="rounded-[12px] bg-background-primary/54 p-4 transition-colors hover:bg-background-secondary/62"'
  );
  write('src/components/recipes/shared/SubRecipeEditor.tsx', source);

  source = read('src/components/recipes/shared/KeyValueEditor.tsx');
  source = replaceAllRequired(
    source,
    'key value editor input borderless',
    'className="flex-1 px-3 py-2 border border-border-subtle rounded-lg bg-background-primary text-text-standard focus:outline-none focus:ring-2 focus:ring-ring text-sm"',
    'className="flex-1 rounded-[10px] bg-background-primary/60 px-3 py-2 text-sm text-text-standard outline-none transition-colors focus:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'key value editor values container borderless',
    'className="space-y-2 border border-border-subtle rounded-lg p-3"',
    'className="space-y-2 rounded-[12px] bg-background-secondary/44 p-3"'
  );
  write('src/components/recipes/shared/KeyValueEditor.tsx', source);

  source = read('src/components/recipes/shared/RecipeModelSelector.tsx');
  source = replaceRequired(
    source,
    'recipe model selector error panel native',
    'className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700"',
    'className="rounded-[12px] bg-background-danger/55 p-3 text-sm text-text-danger"'
  );
  write('src/components/recipes/shared/RecipeModelSelector.tsx', source);

  source = read('src/components/ui/RecipeWarningModal.tsx');
  source = replaceRequired(
    source,
    'recipe warning modal panel native',
    'className="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-4"',
    'className="rounded-[12px] bg-background-warning/55 p-4"'
  );
  source = replaceRequired(
    source,
    'recipe warning modal text token',
    'className="mt-2 text-sm text-yellow-700 dark:text-yellow-300"',
    'className="mt-2 text-sm text-text-warning"'
  );
  write('src/components/ui/RecipeWarningModal.tsx', source);
}

function applySearchSurfaces() {
  let source = read('src/components/conversation/SearchBar.tsx');
  source = replaceRequired(
    source,
    'search bar native glass',
    'className={`sticky top-0 bg-background-inverse text-text-inverse z-30 mb-4 ${',
    'className={`sticky top-0 z-30 mb-4 rounded-[12px] bg-background-primary/72 text-text-primary ${'
  );
  source = replaceRequired(
    source,
    'search icon token color',
    'className="no-drag h-4 w-4 text-text-inverse/70 absolute left-3"',
    'className="no-drag absolute left-3 h-4 w-4 text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'search input native colors',
    `className="no-drag w-full text-sm pl-9 pr-24 py-3 bg-background-inverse text-text-inverse
                      placeholder:text-text-inverse/50 focus:outline-none ${''}
                       active:border-border-secondary"`,
    `className="no-drag w-full bg-transparent py-3 pl-9 pr-24 text-sm text-text-primary
                      placeholder:text-text-secondary focus:outline-none
                       active:border-border-secondary"`
  );
  source = replaceAllRequired(
    source,
    'search controls primary color',
    'text-text-inverse/70 hover:text-text-inverse hover:bg-white/10',
    'text-text-secondary hover:bg-background-secondary/70 hover:text-text-primary'
  );
  source = replaceRequired(
    source,
    'search count native color',
    'className="w-16 text-right text-sm text-text-inverse/80 flex items-center justify-end"',
    'className="flex w-16 items-center justify-end text-right text-sm text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'search case selected native color',
    "? 'bg-white/20 shadow-[inset_0_1px_2px_rgba(0,0,0,0.2)] text-text-inverse hover:bg-white/25'",
    "? 'bg-[var(--epistemos-accent)]/14 text-text-primary hover:bg-[var(--epistemos-accent)]/18'"
  );
  write('src/components/conversation/SearchBar.tsx', source);
}

function applyStatusIndicatorSurfaces() {
  let source = read('src/components/ToolCallStatusIndicator.tsx');
  source = replaceRequired(
    source,
    'tool status success token',
    "return 'bg-green-500';",
    "return 'bg-background-success';"
  );
  source = replaceRequired(
    source,
    'tool status error token',
    "return 'bg-red-500';",
    "return 'bg-background-danger';"
  );
  source = replaceRequired(
    source,
    'tool status loading token',
    "return 'bg-yellow-500 animate-pulse';",
    "return 'bg-background-warning animate-pulse';"
  );
  source = replaceRequired(
    source,
    'tool status pending token',
    "return 'bg-gray-400';",
    "return 'bg-background-secondary';"
  );
  source = replaceRequired(
    source,
    'tool status dot borderless surface',
    "'absolute -top-0.5 -right-0.5 w-2 h-2 rounded-full border border-border-primary'",
    "'absolute -right-0.5 -top-0.5 h-2 w-2 rounded-full'"
  );
  write('src/components/ToolCallStatusIndicator.tsx', source);

  source = read('src/components/SessionIndicators.tsx');
  source = replaceRequired(
    source,
    'session indicator error token',
    'className="w-3.5 h-3.5 text-red-500"',
    'className="h-3.5 w-3.5 text-text-danger"'
  );
  source = replaceRequired(
    source,
    'session indicator streaming token',
    'className="w-3 h-3 text-blue-500 animate-spin"',
    'className="h-3 w-3 animate-spin text-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'session indicator unread token',
    'className="w-2 h-2 bg-green-500 rounded-full"',
    'className="h-2 w-2 rounded-full bg-background-success ring-[3px] ring-text-success/15"'
  );
  write('src/components/SessionIndicators.tsx', source);

  source = read('src/components/GroupedExtensionLoadingToast.tsx');
  source = replaceAllRequired(
    source,
    'grouped extension loading icon token',
    'className="w-4 h-4 animate-spin text-blue-500"',
    'className="h-4 w-4 animate-spin text-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'grouped extension loading summary icon token',
    'className="w-5 h-5 animate-spin text-blue-500"',
    'className="h-5 w-5 animate-spin text-[var(--epistemos-accent)]"'
  );
  source = replaceAllRequired(
    source,
    'grouped extension success icon token',
    'className="w-4 h-4 bg-green-500"',
    'className="h-4 w-4 rounded-full bg-background-success"'
  );
  source = replaceRequired(
    source,
    'grouped extension success summary icon token',
    'className="w-5 h-5 bg-green-500"',
    'className="h-5 w-5 rounded-full bg-background-success"'
  );
  source = replaceRequired(
    source,
    'grouped extension error icon token',
    'className="w-4 h-4 bg-red-500"',
    'className="h-4 w-4 rounded-full bg-background-danger"'
  );
  source = replaceRequired(
    source,
    'grouped extension partial summary token',
    'className="w-5 h-5 bg-yellow-500"',
    'className="h-5 w-5 rounded-full bg-background-warning"'
  );
  write('src/components/GroupedExtensionLoadingToast.tsx', source);

  source = read('src/components/ui/Dot.tsx');
  source = replaceRequired(
    source,
    'dot loading token',
    "loading: 'bg-blue-500',",
    "loading: 'bg-[var(--epistemos-accent)]',"
  );
  source = replaceRequired(
    source,
    'dot success token',
    "success: 'bg-green-600',",
    "success: 'bg-background-success',"
  );
  source = replaceRequired(
    source,
    'dot error token',
    "error: 'bg-red-600',",
    "error: 'bg-background-danger',"
  );
  write('src/components/ui/Dot.tsx', source);

  source = read('src/components/bottom_menu/ContextWindowIndicator.tsx');
  source = replaceRequired(
    source,
    'context window warning token',
    "if (percentage <= 90) return 'text-orange-500';",
    "if (percentage <= 90) return 'text-text-warning';"
  );
  source = replaceRequired(
    source,
    'context window danger token',
    "return 'text-red-500';",
    "return 'text-text-danger';"
  );
  write('src/components/bottom_menu/ContextWindowIndicator.tsx', source);

  source = read('src/components/bottom_menu/DirSwitcher.tsx');
  source = replaceRequired(
    source,
    'directory switcher readable path helpers',
    `interface DirSwitcherProps {
  className: string;
  sessionId: string | undefined;
  workingDir: string;
  onWorkingDirChange?: (newDir: string) => Promise<void> | void;
  onRestartStart?: () => void;
  onRestartEnd?: () => void;
}`,
    `interface DirSwitcherProps {
  className: string;
  sessionId: string | undefined;
  workingDir: string;
  onWorkingDirChange?: (newDir: string) => Promise<void> | void;
  onRestartStart?: () => void;
  onRestartEnd?: () => void;
}

function epistemosDirBaseName(dir: string): string {
  const cleaned = dir.replace(/[\\\\/]+$/, '');
  return cleaned.split(/[\\\\/]/).pop() || dir;
}

function epistemosDirParent(dir: string): string {
  const cleaned = dir.replace(/[\\\\/]+$/, '');
  const parts = cleaned.split(/[\\\\/]/);
  parts.pop();
  return parts.join('/') || '/';
}`
  );
  source = replaceRequired(
    source,
    'directory switcher trigger basename helper',
    `{workingDir.replace(/\\/+\$/, '').split('/').pop() || workingDir}`,
    `{epistemosDirBaseName(workingDir)}`
  );
  source = replaceRequired(
    source,
    'directory switcher current readable row',
    `<span className="truncate">{workingDir}</span>
              <Check className="ml-auto h-4 w-4" />`,
    `<span className="min-w-0 flex-1" data-epistemos-dir-menu-item>
                <span className="block truncate font-medium text-text-primary">
                  {epistemosDirBaseName(workingDir)}
                </span>
                <span className="block truncate text-[11px] text-text-secondary">
                  {epistemosDirParent(workingDir)}
                </span>
              </span>
              <Check className="ml-2 h-4 w-4 shrink-0" />`
  );
  source = replaceRequired(
    source,
    'directory switcher worktree readable rows',
    `<GitBranch className="mr-2 h-4 w-4" />
                  <span className="truncate">{dir}</span>`,
    `<GitBranch className="mr-2 h-4 w-4 shrink-0" />
                  <span className="min-w-0 flex-1" data-epistemos-worktree-menu-item>
                    <span className="block truncate font-medium text-text-primary">
                      {epistemosDirBaseName(dir)}
                    </span>
                    <span className="block truncate text-[11px] text-text-secondary">{dir}</span>
                  </span>`
  );
  source = replaceRequired(
    source,
    'directory switcher recent readable rows',
    `<FolderDot className="mr-2 h-4 w-4" />
                    <span className="truncate">{dir}</span>`,
    `<FolderDot className="mr-2 h-4 w-4 shrink-0" />
                    <span className="min-w-0 flex-1" data-epistemos-recent-dir-menu-item>
                      <span className="block truncate font-medium text-text-primary">
                        {epistemosDirBaseName(dir)}
                      </span>
                      <span className="block truncate text-[11px] text-text-secondary">{dir}</span>
                    </span>`
  );
  write('src/components/bottom_menu/DirSwitcher.tsx', source);
}

function applyFormValidationSurfaces() {
  let source = read('src/components/ParameterInputModal.tsx');
  source = replaceRequired(
    source,
    'parameter modal native glass',
    'className="bg-background-primary border border-border-primary rounded-[6px] shadow-none w-full max-w-lg max-h-[90vh] flex flex-col overflow-hidden"',
    'className="flex max-h-[90vh] w-full max-w-lg flex-col overflow-hidden rounded-[14px] bg-background-primary/92"'
  );
  source = replaceRequired(
    source,
    'parameter modal title native',
    'className="text-xl font-bold text-text-primary mb-6"',
    'className="mb-6 text-xl font-sans font-semibold tracking-normal text-text-primary"'
  );
  source = replaceAllRequired(
    source,
    'parameter modal required token',
    'text-red-500',
    'text-text-danger'
  );
  source = replaceAllRequired(
    source,
    'parameter modal control native base',
    'w-full p-3 border rounded-[6px] bg-background-secondary text-text-primary focus:outline-none focus:ring-1',
    'w-full rounded-[10px] bg-background-primary/70 p-3 text-text-primary transition-colors focus:bg-background-secondary/72 focus:outline-none focus:ring-0'
  );
  source = replaceAllRequired(
    source,
    'parameter modal invalid ring token',
    "? 'border-red-500 focus:ring-red-500'",
    "? 'bg-background-danger/35 focus:bg-background-danger/45'"
  );
  source = replaceAllRequired(
    source,
    'parameter modal normal focus token',
    ": 'border-border-primary focus:ring-border-secondary'",
    ": ''"
  );
  write('src/components/ParameterInputModal.tsx', source);

  source = read('src/components/parameter/ParameterInput.tsx');
  source = replaceRequired(
    source,
    'parameter input delete button native',
    'className="p-1 text-red-500 hover:text-red-700 hover:bg-red-50 rounded transition-colors"',
    'className="rounded-[8px] p-1 text-text-secondary transition-colors hover:bg-background-danger/55 hover:text-text-danger"'
  );
  write('src/components/parameter/ParameterInput.tsx', source);

  source = read('src/components/ui/JsonSchemaForm.tsx');
  source = replaceRequired(
    source,
    'json schema select native',
    'className="flex h-9 w-full rounded-md border focus:border-border-secondary hover:border-border-secondary bg-background-primary px-3 py-1 text-base transition-colors focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm"',
    'className="flex h-9 w-full rounded-[8px] bg-background-primary/70 px-3 py-1 text-base text-text-primary transition-colors duration-200 ease-[var(--epistemos-control-ease)] hover:bg-background-secondary/72 focus:bg-background-secondary/72 focus-visible:outline-none focus-visible:ring-0 disabled:cursor-not-allowed disabled:opacity-50 md:text-sm"'
  );
  source = replaceRequired(
    source,
    'json schema checkbox native',
    'className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"',
    'className="h-4 w-4 rounded-[5px] accent-[var(--epistemos-accent)] focus:ring-0"'
  );
  source = replaceAllRequired(
    source,
    'json schema invalid input token',
    "className={error ? 'border-red-500' : ''}",
    "className={error ? 'bg-background-danger/35' : ''}"
  );
  source = replaceAllRequired(
    source,
    'json schema validation text token',
    'text-red-500',
    'text-text-danger'
  );
  write('src/components/ui/JsonSchemaForm.tsx', source);

  source = read('src/components/ElicitationRequest.tsx');
  source = replaceRequired(
    source,
    'elicitation submit error token',
    'className="mt-3 text-sm text-red-500"',
    'className="mt-3 text-sm text-text-danger"'
  );
  source = replaceRequired(
    source,
    'elicitation urgent token',
    "className={`mt-3 pt-3 border-t border-border-primary flex items-center gap-2 text-xs font-mono ${isUrgent ? 'text-red-500' : 'text-text-secondary'}`}",
    "className={`mt-3 flex items-center gap-2 rounded-[8px] bg-background-secondary/44 px-2 py-1.5 text-xs font-sans ${isUrgent ? 'text-text-danger' : 'text-text-secondary'}`}"
  );
  write('src/components/ElicitationRequest.tsx', source);

  source = read('src/components/common/InlineEditText.tsx');
  source = replaceRequired(
    source,
    'inline edit active border token',
    'border-blue-500 ring-2 ring-blue-500/20',
    'bg-[var(--epistemos-accent)]/10'
  );
  source = replaceRequired(
    source,
    'inline edit focus ring token',
    'focus:outline-none focus:ring-2 focus:ring-blue-500/40',
    'focus:outline-none focus:ring-0'
  );
  write('src/components/common/InlineEditText.tsx', source);

  source = read('src/components/TelemetryConsentPrompt.tsx');
  source = replaceRequired(
    source,
    'telemetry consent link token',
    'className="text-blue-600 dark:text-blue-400 hover:underline"',
    'className="text-[var(--epistemos-accent)] hover:underline"'
  );
  write('src/components/TelemetryConsentPrompt.tsx', source);

  source = read('src/components/SessionActionsHeader.tsx');
  source = replaceRequired(
    source,
    'session action long text link token',
    'className="min-w-0 rounded-sm text-left text-blue-600 underline-offset-2 hover:underline focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-border-active dark:text-blue-300 break-all"',
    'className="min-w-0 break-all rounded-[6px] text-left text-[var(--epistemos-accent)] underline-offset-2 hover:underline focus-visible:bg-[var(--epistemos-accent)]/10 focus-visible:outline-none focus-visible:ring-0"'
  );
  source = replaceRequired(
    source,
    'session action json string token',
    'className="min-w-0 text-emerald-700 dark:text-emerald-300 break-all"',
    'className="min-w-0 break-all text-text-primary"'
  );
  source = replaceRequired(
    source,
    'session action json number token',
    'className="text-purple-700 dark:text-purple-300"',
    'className="text-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'session action json boolean token',
    'className="text-amber-700 dark:text-amber-300"',
    'className="text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'session action json tree indent surface',
    'className="ml-3 border-l border-border-primary/70 pl-3"',
    'className="ml-3 rounded-[8px] bg-background-secondary/40 px-3 py-1"'
  );
  source = replaceRequired(
    source,
    'session action header trigger surface',
    'className="flex h-7 max-w-full items-center gap-1 rounded-md px-2.5 text-text-primary transition-colors hover:bg-background-secondary focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-border-active"',
    'className="flex h-7 max-w-full items-center gap-1 rounded-[8px] px-2.5 text-text-primary transition-colors hover:bg-background-secondary/60 focus-visible:bg-background-secondary/70 focus-visible:outline-none focus-visible:ring-0"'
  );
  source = replaceRequired(
    source,
    'session action rename input borderless',
    'className="w-full rounded-lg border border-border-primary bg-background-primary p-3 text-text-primary outline-none focus:ring-2 focus:ring-border-active"',
    'className="w-full rounded-[10px] bg-background-primary/60 p-3 text-text-primary outline-none transition-colors focus:bg-background-secondary/72 focus:ring-0"'
  );
  source = replaceRequired(
    source,
    'session action json panel borderless',
    'className="min-h-0 overflow-hidden rounded-lg border border-border-primary bg-background-secondary"',
    'className="min-h-0 overflow-hidden rounded-[12px] bg-background-secondary/54"'
  );
  source = replaceRequired(
    source,
    'session action full text pre borderless',
    'className="max-h-[55vh] overflow-auto whitespace-pre-wrap break-words rounded-lg border border-border-primary bg-background-secondary p-4 text-xs leading-5 text-text-primary"',
    'className="max-h-[55vh] overflow-auto whitespace-pre-wrap break-words rounded-[12px] bg-background-secondary/54 p-4 text-xs leading-5 text-text-primary outline-none"'
  );
  write('src/components/SessionActionsHeader.tsx', source);
}

function applyRemainingTokenDriftSurfaces() {
  let source = read('src/components/ExtensionInstallModal.tsx');
  source = replaceRequired(
    source,
    'extension install blocked title token',
    "return 'text-red-600 dark:text-red-400';",
    "return 'text-text-danger';"
  );
  source = replaceRequired(
    source,
    'extension install warning title token',
    "return 'text-yellow-600 dark:text-yellow-400';",
    "return 'text-text-warning';"
  );
  write('src/components/ExtensionInstallModal.tsx', source);

  source = read('src/components/McpApps/McpAppRenderer.tsx');
  source = replaceRequired(
    source,
    'mcp app error text token',
    'className="p-4 text-red-700 dark:text-red-300"',
    'className="rounded-[12px] bg-background-danger/55 p-4 text-text-danger"'
  );
  source = replaceRequired(
    source,
    'mcp app loading dot token',
    'className="h-2 w-2 bg-primary animate-pulse"',
    'className="ep-native-loading-dot is-active"'
  );
  source = replaceRequired(
    source,
    'mcp app error container token',
    "isError && 'border border-red-500 rounded-lg bg-red-50 dark:bg-red-900/20'",
    "isError && 'rounded-[12px] bg-background-danger/35'"
  );
  write('src/components/McpApps/McpAppRenderer.tsx', source);

  source = read('src/components/ImagePreview.tsx');
  source = replaceRequired(
    source,
    'image preview error token',
    'className="text-red-500 text-xs italic mt-1 mb-1"',
    'className="mb-1 mt-1 text-xs italic text-text-danger"'
  );
  write('src/components/ImagePreview.tsx', source);

  source = read('src/components/UserMessage.tsx');
  source = replaceRequired(
    source,
    'user message error token',
    'className="text-red-400 text-xs mt-2 mb-2"',
    'className="mb-2 mt-2 text-xs text-text-danger"'
  );
  source = replaceRequired(
    source,
    'user edit card borderless',
    'className="w-full max-w-4xl mx-auto text-text-primary rounded-[6px] border border-border-primary bg-background-secondary py-3 px-3 my-2 transition-all duration-200 ease-in-out"',
    'className="mx-auto my-2 w-full max-w-4xl rounded-[12px] bg-background-secondary/56 px-3 py-3 text-text-primary transition-all duration-200 ease-in-out"'
  );
  source = replaceRequired(
    source,
    'user edit textarea borderless',
    'className="w-full resize-none bg-background-primary text-text-primary placeholder:text-text-secondary border border-border-primary rounded-[5px] focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary transition-all duration-200 text-sm leading-relaxed font-mono"',
    'className="w-full resize-none rounded-[10px] bg-background-primary/60 text-sm leading-relaxed text-text-primary placeholder:text-text-secondary outline-none transition-colors duration-200 focus:bg-background-secondary/72"'
  );
  write('src/components/UserMessage.tsx', source);

  source = read('src/components/BaseChat.tsx');
  source = replaceRequired(
    source,
    'base chat error card borderless',
    'className="text-text-danger bg-background-danger border border-border-danger p-4 mb-4 max-w-md"',
    'className="mb-4 max-w-md rounded-[12px] bg-background-danger/35 p-4 text-text-danger"'
  );
  source = replaceRequired(
    source,
    'base chat go home button borderless',
    'className="px-4 py-2 text-center cursor-pointer text-text-primary border border-border-primary hover:bg-background-secondary transition-all duration-150"',
    'className="cursor-pointer rounded-[8px] bg-background-secondary/56 px-4 py-2 text-center text-text-primary transition-all duration-150 hover:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'base chat docs chip borderless',
    'className="no-drag flex items-center gap-2 border border-border-secondary bg-background-primary/90 px-2 py-1 text-[11px] font-mono uppercase text-text-secondary hover:text-text-primary"',
    'className="no-drag flex items-center gap-2 rounded-[8px] bg-background-primary/58 px-2 py-1 text-[11px] font-sans uppercase text-text-secondary hover:text-text-primary"'
  );
  write('src/components/BaseChat.tsx', source);

  source = read('src/components/context_management/CreditsExhaustedNotification.tsx');
  source = replaceRequired(
    source,
    'credits exhausted native warning panel',
    'className="rounded-lg border border-yellow-600/30 dark:border-yellow-500/30 bg-yellow-500/10 dark:bg-yellow-500/10 p-4 my-2"',
    'className="my-2 rounded-[12px] bg-background-warning/55 p-4"'
  );
  source = replaceRequired(
    source,
    'credits exhausted warning icon token',
    'className="h-4 w-4 text-yellow-600 dark:text-yellow-400 mt-0.5 shrink-0"',
    'className="mt-0.5 h-4 w-4 shrink-0 text-text-warning"'
  );
  source = replaceRequired(
    source,
    'credits exhausted title token',
    'className="text-sm font-semibold text-yellow-800 dark:text-yellow-200"',
    'className="text-sm font-semibold text-text-warning"'
  );
  source = replaceRequired(
    source,
    'credits exhausted body token',
    'className="text-sm text-yellow-800/80 dark:text-yellow-200/80 mt-1"',
    'className="mt-1 text-sm text-text-warning"'
  );
  source = replaceRequired(
    source,
    'credits exhausted action token',
    'className="mt-3 inline-flex items-center gap-2 rounded-md bg-yellow-600 hover:bg-yellow-500 dark:bg-yellow-700 dark:hover:bg-yellow-600 text-white text-sm font-medium px-4 py-2 transition-colors"',
    'className="mt-3 inline-flex items-center gap-2 rounded-[8px] bg-[var(--epistemos-accent)] px-4 py-2 text-sm font-medium text-text-inverse transition-colors hover:bg-[var(--epistemos-accent)]/90"'
  );
  write('src/components/context_management/CreditsExhaustedNotification.tsx', source);

  source = read('src/components/MessageQueue.tsx');
  source = replaceAllRequired(
    source,
    'message queue active dot token',
    'className="w-2 h-2 bg-blue-500 animate-pulse"',
    'className="ep-native-loading-dot is-active"'
  );
  source = replaceRequired(
    source,
    'message queue compact header borderless',
    'className="flex items-center justify-between px-4 py-2.5 bg-background border-b border-border/20 cursor-pointer hover:bg-muted/30 transition-all duration-200"',
    'className="flex cursor-pointer items-center justify-between rounded-[12px] bg-background-primary/42 px-4 py-2.5 transition-all duration-200 hover:bg-background-secondary/46"'
  );
  source = replaceRequired(
    source,
    'message queue count badge borderless',
    'className="flex items-center gap-1 text-[10px] font-mono uppercase text-muted-foreground bg-background-secondary border border-border-primary px-2 py-1 rounded-[3px]"',
    'className="flex items-center gap-1 rounded-[8px] bg-background-secondary/60 px-2 py-1 text-[10px] font-sans uppercase text-muted-foreground"'
  );
  source = replaceRequired(
    source,
    'message queue compact paused banner borderless',
    'className="px-4 py-1.5 bg-amber-50/60 dark:bg-amber-900/20 border-b border-amber-200/30 dark:border-amber-800/30"',
    'className="mt-1 rounded-[10px] bg-background-warning/35 px-4 py-1.5"'
  );
  source = replaceRequired(
    source,
    'message queue compact paused text token',
    'className="flex items-center gap-2 text-xs text-amber-700 dark:text-amber-300"',
    'className="flex items-center gap-2 text-xs text-text-warning"'
  );
  source = replaceRequired(
    source,
    'message queue expanded header borderless',
    'className="flex items-center justify-between px-4 py-3 bg-background border-b border-border/30"',
    'className="flex items-center justify-between rounded-[12px] bg-background-primary/42 px-4 py-3"'
  );
  source = replaceRequired(
    source,
    'message queue expanded paused banner borderless',
    'className="px-4 py-2 bg-amber-50/80 dark:bg-amber-900/20 border-b border-amber-200/50 dark:border-amber-800/50"',
    'className="mt-1 rounded-[10px] bg-background-warning/35 px-4 py-2"'
  );
  source = replaceRequired(
    source,
    'message queue expanded paused text token',
    'className="flex items-center gap-2 text-sm text-amber-800 dark:text-amber-200"',
    'className="flex items-center gap-2 text-sm text-text-warning"'
  );
  source = replaceRequired(
    source,
    'message queue bubble base borderless',
    'rounded-[6px] px-3 py-2 border transition-colors duration-150',
    'rounded-[10px] px-3 py-2 transition-colors duration-150'
  );
  source = replaceRequired(
    source,
    'message queue dragged bubble borderless',
    "'bg-background-secondary border-primary opacity-70'",
    "'bg-background-secondary/72 opacity-70'"
  );
  source = replaceRequired(
    source,
    'message queue dragover bubble borderless',
    "'bg-background-secondary border-primary'",
    "'bg-background-secondary/72'"
  );
  source = replaceRequired(
    source,
    'message queue hover bubble borderless',
    "'bg-background-secondary border-border-primary'",
    "'bg-background-secondary/64'"
  );
  source = replaceRequired(
    source,
    'message queue idle bubble borderless',
    "'bg-background-primary hover:bg-background-secondary border-border-primary'",
    "'bg-background-primary/54 hover:bg-background-secondary/56'"
  );
  source = replaceRequired(
    source,
    'message queue order chip borderless',
    "'bg-background-secondary text-text-muted border border-border-primary'",
    "'bg-background-secondary/60 text-text-muted'"
  );
  source = replaceRequired(
    source,
    'message queue edit textarea borderless',
    'className="w-full text-sm bg-background-primary border border-border-primary rounded-[6px] px-2 py-1 resize-none focus:outline-none focus:ring-1 focus:ring-border-primary"',
    'className="w-full resize-none rounded-[8px] bg-background-primary/60 px-2 py-1 text-sm outline-none transition-colors focus:bg-background-secondary/72 focus:ring-0"'
  );
  source = replaceRequired(
    source,
    'message queue cancel button token',
    'className="text-xs h-7 px-3 text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors"',
    'className="h-7 rounded-[8px] px-3 text-xs text-text-secondary transition-colors hover:bg-background-danger/55 hover:text-text-danger"'
  );
  source = replaceRequired(
    source,
    'message queue remove button token',
    'className="opacity-60 hover:opacity-100 transition-opacity h-6 w-6 p-0 hover:bg-destructive/20 hover:text-destructive rounded-[4px]"',
    'className="h-6 w-6 rounded-[8px] p-0 text-text-secondary opacity-60 transition-opacity hover:bg-background-danger/55 hover:text-text-danger hover:opacity-100"'
  );
  write('src/components/MessageQueue.tsx', source);

  source = read('src/components/settings/chat/GoosehintsModal.tsx');
  source = replaceRequired(
    source,
    'goosehints link token',
    'className="text-blue-500 hover:text-blue-600 p-0 h-auto"',
    'className="h-auto p-0 text-[var(--epistemos-accent)] hover:opacity-80"'
  );
  source = replaceRequired(
    source,
    'goosehints error token',
    'className="text-red-600"',
    'className="text-text-danger"'
  );
  source = replaceRequired(
    source,
    'goosehints success token',
    'className="text-green-600"',
    'className="text-text-success"'
  );
  source = replaceRequired(
    source,
    'goosehints saved token',
    'className="text-green-600 text-sm flex items-center gap-1 mr-auto"',
    'className="mr-auto flex items-center gap-1 text-sm text-text-success"'
  );
  write('src/components/settings/chat/GoosehintsModal.tsx', source);

  source = read('src/components/settings/providers/subcomponents/buttons/CardButtons.tsx');
  source = replaceRequired(
    source,
    'provider card active button token',
    "'text-green-600 dark:text-green-500 hover:text-green-600 cursor-default'",
    "'cursor-default text-text-success hover:text-text-success'"
  );
  write('src/components/settings/providers/subcomponents/buttons/CardButtons.tsx', source);

  source = read('src/components/settings/providers/subcomponents/utils/StringUtils.tsx');
  source = replaceRequired(
    source,
    'provider string url token',
    'className="text-blue-600 underline hover:text-blue-800"',
    'className="text-[var(--epistemos-accent)] underline hover:opacity-80"'
  );
  write('src/components/settings/providers/subcomponents/utils/StringUtils.tsx', source);

  source = read('src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx');
  source = replaceAllRequired(
    source,
    'custom provider invalid border token',
    'border-red-500',
    'bg-background-danger/35'
  );
  write('src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx', source);
}

function applyNeutralTokenDriftSurfaces() {
  let source = read('src/components/context_management/SystemNotificationInline.tsx');
  source = replaceRequired(
    source,
    'inline system notification neutral token',
    'className="text-xs text-gray-400 py-2 text-left"',
    'className="py-2 text-left text-xs text-text-secondary"'
  );
  write('src/components/context_management/SystemNotificationInline.tsx', source);

  source = read('src/components/sessions/SessionViewComponents.tsx');
  source = replaceRequired(
    source,
    'session thinking neutral token',
    'className="mb-2 text-sm text-gray-400 italic"',
    'className="mb-2 text-sm italic text-text-secondary"'
  );
  source = replaceRequired(
    source,
    'session tool native glass',
    'className="goose-message-tool bg-background-primary border border-border-primary dark:border-gray-700 rounded-[6px] px-3 pt-3 pb-2 mt-1"',
    'className="goose-message-tool mt-1 rounded-[12px] bg-background-primary/54 px-3 pb-2 pt-3"'
  );
  write('src/components/sessions/SessionViewComponents.tsx', source);

  source = read('src/components/recipes/ImportRecipeForm.tsx');
  source = replaceRequired(
    source,
    'recipe import disabled control token',
    "isDisabled ? 'cursor-not-allowed bg-gray-40 text-gray-300' : ''",
    "isDisabled ? 'cursor-not-allowed bg-background-disabled text-text-disabled' : ''"
  );
  source = replaceAllRequired(
    source,
    'recipe import disabled hint token',
    "isDisabled ? 'text-gray-300' : 'text-text-secondary'",
    "isDisabled ? 'text-text-disabled' : 'text-text-secondary'"
  );
  write('src/components/recipes/ImportRecipeForm.tsx', source);

  source = read('src/components/schedule/ScheduleDetailView.tsx');
  source = replaceRequired(
    source,
    'schedule missing state transparent root',
    'className="h-screen w-full flex flex-col items-center justify-center bg-white dark:bg-gray-900 text-text-primary p-8"',
    'className="flex h-screen w-full flex-col items-center justify-center bg-transparent p-8 text-text-primary"'
  );
  write('src/components/schedule/ScheduleDetailView.tsx', source);

  source = read('src/components/schedule/ScheduleModal.tsx');
  source = replaceRequired(
    source,
    'schedule modal helper neutral token',
    'className="mt-2 text-xs text-gray-500 dark:text-gray-400 italic"',
    'className="mt-2 text-xs italic text-text-secondary"'
  );
  write('src/components/schedule/ScheduleModal.tsx', source);

  source = read('src/components/schedule/CronPicker.tsx');
  source = replaceRequired(
    source,
    'cron picker native select token',
    "const selectClassName = 'px-2 py-1 border rounded bg-white dark:bg-gray-800 dark:border-gray-600';",
    "const selectClassName = 'min-h-8 rounded-[8px] bg-background-primary/70 px-2 py-1 text-sm text-text-primary outline-none transition-colors focus:bg-background-secondary/72 focus:border-transparent';"
  );
  source = replaceRequired(
    source,
    'cron picker readable neutral token',
    "hasCronError ? 'text-text-danger' : 'text-gray-500'",
    "hasCronError ? 'text-text-danger' : 'text-text-secondary'"
  );
  write('src/components/schedule/CronPicker.tsx', source);

  source = read('src/components/McpApps/McpAppRenderer.tsx');
  source = replaceRequired(
    source,
    'mcp app fullscreen header borderless',
    'className="flex shrink-0 items-center border-b border-border-primary bg-background-primary px-3"',
    'className="flex shrink-0 items-center bg-background-primary/70 px-3"'
  );
  source = replaceRequired(
    source,
    'mcp app loading neutral surface',
    'className="relative flex h-full w-full items-center justify-center overflow-hidden rounded bg-black/[0.03] dark:bg-white/[0.03]"',
    'className="relative flex h-full w-full items-center justify-center overflow-hidden rounded-[12px] bg-background-secondary/55"'
  );
  source = replaceRequired(
    source,
    'mcp app loading dot frame native',
    'className="relative z-10 flex h-8 w-8 items-center justify-center border border-border-primary bg-background-primary/80"',
    'className="relative z-10 flex h-8 w-8 items-center justify-center rounded-[10px] bg-background-primary/70"'
  );
  source = replaceAllRequired(
    source,
    'mcp app header button neutral token',
    'className="no-drag cursor-pointer rounded-md p-1.5 text-text-secondary transition-colors hover:bg-black/10 hover:text-text-primary dark:hover:bg-white/10"',
    'className="no-drag cursor-pointer rounded-[8px] p-1.5 text-text-secondary transition-colors hover:bg-background-secondary/72 hover:text-text-primary"'
  );
  source = replaceRequired(
    source,
    'mcp app pip native container',
    "'fixed z-[900] overflow-y-auto overflow-x-hidden rounded-[6px] border border-border-primary shadow-none'",
    "'fixed z-[900] overflow-y-auto overflow-x-hidden rounded-[12px] bg-background-primary/88'"
  );
  source = replaceRequired(
    source,
    'mcp app inline bordered container native',
    "isInline && !isError && meta.prefersBorder && 'border border-border-primary rounded-lg'",
    "isInline && !isError && meta.prefersBorder && 'rounded-[12px] bg-background-primary/50'"
  );
  source = replaceRequired(
    source,
    'mcp app pip placeholder native',
    'className="mt-6 mb-2 flex items-center justify-center rounded-lg border border-dashed border-border-primary bg-black/[0.02] dark:bg-white/[0.02]"',
    'className="mt-6 mb-2 flex items-center justify-center rounded-[12px] bg-background-secondary/45"'
  );
  source = replaceRequired(
    source,
    'mcp app pip placeholder button native',
    'className="cursor-pointer flex items-center gap-2 rounded-md px-3 py-1.5 text-xs text-text-secondary transition-colors hover:bg-black/5 hover:text-text-primary dark:hover:bg-white/5"',
    'className="flex cursor-pointer items-center gap-2 rounded-[8px] px-3 py-1.5 text-xs text-text-secondary transition-colors hover:bg-background-secondary/72 hover:text-text-primary"'
  );
  write('src/components/McpApps/McpAppRenderer.tsx', source);

  source = read('src/components/MarkdownContent.tsx');
  source = replaceRequired(
    source,
    'markdown copy button neutral token',
    `className="absolute right-2 bottom-2 p-1.5 rounded-lg bg-gray-700/50 text-gray-300 font-sans text-sm
                 opacity-0 group-hover:opacity-100 transition-opacity duration-200
                 hover:bg-gray-600/50 hover:text-gray-100 z-10"`,
    `className="absolute bottom-2 right-2 z-10 rounded-[8px] bg-background-primary/70 p-1.5 font-sans text-sm text-text-secondary opacity-0 transition-opacity duration-200 hover:bg-background-secondary/72 hover:text-text-primary group-hover:opacity-100"`
  );
  write('src/components/MarkdownContent.tsx', source);

  source = read('src/components/ui/BaseModal.tsx');
  source = replaceRequired(
    source,
    'base modal overlay native',
    'className="fixed inset-0 bg-black/20 z-[9999]"',
    'className="fixed inset-0 z-[9999] bg-black/20"'
  );
  source = replaceRequired(
    source,
    'base modal native card',
    'className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[440px] bg-background-primary rounded-[6px] shadow-none overflow-hidden p-[16px] pt-[20px] pb-0"',
    'className="fixed left-1/2 top-1/2 w-[440px] -translate-x-1/2 -translate-y-1/2 overflow-hidden rounded-[14px] bg-background-primary/92 p-[16px] pb-0 pt-[20px]"'
  );
  source = replaceRequired(
    source,
    'base modal title native',
    'className="text-base font-mono dark:text-white text-gray-900"',
    'className="text-base font-sans font-semibold tracking-normal text-text-primary"'
  );
  write('src/components/ui/BaseModal.tsx', source);

  source = read('src/components/ui/Diagnostics.tsx');
  source = replaceRequired(
    source,
    'diagnostics overlay native',
    'className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"',
    'className="fixed inset-0 z-50 flex items-center justify-center bg-black/20"'
  );
  source = replaceRequired(
    source,
    'diagnostics modal native card',
    'className="bg-background-primary border border-border-primary rounded-lg p-6 max-w-md mx-4"',
    'className="mx-4 max-w-md rounded-[14px] bg-background-primary/92 p-6"'
  );
  source = replaceRequired(
    source,
    'diagnostics warning icon token',
    'className="text-orange-500 flex-shrink-0 mt-1"',
    'className="mt-1 flex-shrink-0 text-text-warning"'
  );
  source = replaceRequired(
    source,
    'diagnostics github button token',
    'className="bg-slate-600 text-white hover:bg-slate-700"',
    'className="bg-[var(--epistemos-accent)] text-text-inverse hover:bg-[var(--epistemos-accent)]/90"'
  );
  write('src/components/ui/Diagnostics.tsx', source);

  source = read('src/components/alerts/AlertBox.tsx');
  source = replaceRequired(
    source,
    'alert error native token',
    "[AlertType.Error]: 'bg-[#d7040e] text-white',",
    "[AlertType.Error]: 'bg-background-danger/55 text-text-danger',"
  );
  source = replaceRequired(
    source,
    'alert warning native token',
    "[AlertType.Warning]: 'bg-[#cc4b03] text-white',",
    "[AlertType.Warning]: 'bg-background-warning/55 text-text-warning',"
  );
  source = replaceRequired(
    source,
    'alert info native token',
    "[AlertType.Info]: 'dark:bg-white dark:text-black bg-black text-white',",
    "[AlertType.Info]: 'bg-background-primary/70 text-text-primary',"
  );
  source = replaceRequired(
    source,
    'alert threshold input native token',
    'className="w-12 px-1 text-[10px] bg-white/10 border border-current/30 rounded outline-none text-center focus:bg-white/20 focus:border-current/50 transition-colors"',
    'className="w-12 rounded-[6px] bg-background-primary/15 px-1 text-center text-[10px] outline-none transition-colors focus:bg-background-primary/25 focus:border-transparent"'
  );
  write('src/components/alerts/AlertBox.tsx', source);

  source = read('src/components/settings/providers/modal/subcomponents/SecureStorageNotice.tsx');
  source = replaceRequired(
    source,
    'secure storage neutral token',
    'className={`flex items-center mt-2 text-gray-600 dark:text-gray-300 ${className}`}',
    'className={`mt-2 flex items-center text-text-secondary ${className}`}'
  );
  write('src/components/settings/providers/modal/subcomponents/SecureStorageNotice.tsx', source);

  source = read('src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx');
  source = replaceRequired(
    source,
    'custom provider remove icon neutral token',
    'className="h-3 w-3 text-gray-400 group-hover:text-white group-hover:drop-shadow-sm transition-all"',
    'className="h-3 w-3 text-text-secondary transition-all group-hover:text-text-primary"'
  );
  write('src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx', source);
}

function applyModalScrimAndElicitationSurfaces() {
  let source = read('src/components/ParameterInputModal.tsx');
  source = replaceRequired(
    source,
    'parameter cancel scrim native',
    'className="fixed inset-0 bg-black/25 z-50 flex justify-center items-center animate-[fadein_200ms_ease-in]"',
    'className="fixed inset-0 z-50 flex items-center justify-center bg-black/20 animate-[fadein_200ms_ease-in]"'
  );
  source = replaceRequired(
    source,
    'parameter cancel modal native card',
    'className="bg-background-primary border border-border-primary rounded-[6px] p-6 shadow-none w-full max-w-md"',
    'className="w-full max-w-md rounded-[14px] bg-background-primary/92 p-6"'
  );
  source = replaceRequired(
    source,
    'parameter cancel title native',
    'className="text-xl font-bold text-text-primary mb-4"',
    'className="mb-4 text-xl font-sans font-semibold tracking-normal text-text-primary"'
  );
  write('src/components/ParameterInputModal.tsx', source);

  source = read('src/components/ElicitationRequest.tsx');
  source = replaceRequired(
    source,
    'elicitation prompt header native',
    'className="goose-message-content bg-background-secondary rounded-[6px] rounded-b-none px-3 py-2 text-xs font-mono text-text-primary"',
    'className="goose-message-content rounded-t-[12px] bg-background-secondary/62 px-3 py-2 text-xs font-sans text-text-primary"'
  );
  source = replaceRequired(
    source,
    'elicitation prompt body native',
    'className="goose-message-content bg-background-primary border border-border-primary dark:border-gray-700 rounded-b-[6px] px-3 py-3"',
    'className="goose-message-content rounded-b-[12px] bg-background-primary/54 px-3 py-3"'
  );
  write('src/components/ElicitationRequest.tsx', source);

  for (const file of [
    'src/components/recipes/shared/SubRecipeModal.tsx',
    'src/components/recipes/shared/CreateSubRecipeInline.tsx',
  ]) {
    source = read(file);
    source = replaceRequired(
      source,
      `${file} native scrim`,
      'className="fixed inset-0 z-[500] flex items-center justify-center bg-black/50"',
      'className="fixed inset-0 z-[500] flex items-center justify-center bg-black/20"'
    );
    source = replaceRequired(
      source,
      `${file} native card`,
      'className="bg-background-primary border border-borderSubtle rounded-lg w-[90vw] max-w-2xl max-h-[90vh] flex flex-col"',
      'className="flex max-h-[90vh] w-[90vw] max-w-2xl flex-col overflow-hidden rounded-[14px] bg-background-primary/92"'
    );
    source = replaceRequired(
      source,
      `${file} header borderless`,
      'className="flex items-center justify-between p-6 border-b border-borderSubtle"',
      'className="flex items-center justify-between bg-background-primary/42 p-6"'
    );
    source = replaceAllRequired(
      source,
      `${file} full input borderless`,
      'className="w-full p-3 border border-border-subtle rounded-lg bg-background-primary text-text-standard focus:outline-none focus:ring-2 focus:ring-ring"',
      'className="w-full rounded-[10px] bg-background-primary/60 p-3 text-text-standard outline-none transition-colors focus:bg-background-secondary/72"'
    );
    source = replaceAllOptional(
      source,
      'className="flex-1 p-3 border border-border-subtle rounded-lg bg-background-primary text-text-standard focus:outline-none focus:ring-2 focus:ring-ring"',
      'className="flex-1 rounded-[10px] bg-background-primary/60 p-3 text-text-standard outline-none transition-colors focus:bg-background-secondary/72"'
    );
    source = replaceAllRequired(
      source,
      `${file} full textarea borderless`,
      'className="w-full p-3 border border-border-subtle rounded-lg bg-background-primary text-text-standard focus:outline-none focus:ring-2 focus:ring-ring resize-none"',
      'className="w-full resize-none rounded-[10px] bg-background-primary/60 p-3 text-text-standard outline-none transition-colors focus:bg-background-secondary/72"'
    );
    source = replaceAllOptional(
      source,
      'className="w-full p-3 border border-border-subtle rounded-lg bg-background-primary text-text-standard focus:outline-none focus:ring-2 focus:ring-ring resize-none font-mono text-sm"',
      'className="w-full resize-none rounded-[10px] bg-background-primary/60 p-3 text-sm text-text-standard outline-none transition-colors focus:bg-background-secondary/72"'
    );
    source = replaceAllRequired(
      source,
      `${file} checkbox accent native`,
      'className="w-4 h-4 border-border-subtle rounded focus:ring-2 focus:ring-ring"',
      'className="h-4 w-4 rounded-[5px] accent-[var(--epistemos-accent)]"'
    );
    source = replaceOptional(
      source,
      'className="flex gap-2 p-6 border-t border-borderSubtle"',
      'className="flex gap-2 bg-background-primary/42 p-6"'
    );
    source = replaceOptional(
      source,
      'className="flex gap-3 p-6 border-t border-borderSubtle justify-end"',
      'className="flex justify-end gap-3 bg-background-primary/42 p-6"'
    );
    write(file, source);
  }

  for (const file of [
    'src/components/recipes/shared/InstructionsEditor.tsx',
    'src/components/recipes/shared/JsonSchemaEditor.tsx',
  ]) {
    source = read(file);
    source = replaceRequired(
      source,
      `${file} native scrim`,
      'className="fixed inset-0 z-[400] flex items-center justify-center bg-black/50"',
      'className="fixed inset-0 z-[400] flex items-center justify-center bg-black/20"'
    );
    source = replaceRequired(
      source,
      `${file} footer borderless`,
      'className="flex justify-end space-x-3 mt-6 pt-4 border-t border-border-primary"',
      'className="mt-6 flex justify-end space-x-3 rounded-[10px] bg-background-primary/42 p-3"'
    );
    write(file, source);
  }

  source = read('src/components/recipes/shared/InstructionsEditor.tsx');
  source = replaceRequired(
    source,
    'instructions editor modal card borderless',
    'className="bg-background-primary border border-border-primary rounded-lg p-6 w-[900px] max-w-[90vw] max-h-[90vh] overflow-hidden flex flex-col"',
    'className="flex max-h-[90vh] w-[900px] max-w-[90vw] flex-col overflow-hidden rounded-[14px] bg-background-primary/92 p-6"'
  );
  write('src/components/recipes/shared/InstructionsEditor.tsx', source);

  source = read('src/components/recipes/shared/JsonSchemaEditor.tsx');
  source = replaceRequired(
    source,
    'json schema editor modal card borderless',
    'className="bg-background-primary border border-border-primary rounded-lg p-6 w-[800px] max-w-[90vw] max-h-[90vh] overflow-hidden flex flex-col"',
    'className="flex max-h-[90vh] w-[800px] max-w-[90vw] flex-col overflow-hidden rounded-[14px] bg-background-primary/92 p-6"'
  );
  write('src/components/recipes/shared/JsonSchemaEditor.tsx', source);

  source = read('src/components/ui/sheet.tsx');
  source = replaceRequired(
    source,
    'sheet overlay native scrim',
    "'data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed inset-0 z-50 bg-black/50'",
    "'data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed inset-0 z-50 bg-black/20'"
  );
  source = replaceRequired(
    source,
    'sheet content native glass',
    "'bg-background-primary data-[state=open]:animate-in data-[state=closed]:animate-out fixed z-50 flex flex-col gap-4 transition ease-in-out data-[state=closed]:duration-300 data-[state=open]:duration-500 shadow-none'",
    "'bg-background-primary/92 data-[state=open]:animate-in data-[state=closed]:animate-out fixed z-50 flex flex-col gap-4 transition ease-[var(--epistemos-control-ease)] data-[state=closed]:duration-200 data-[state=open]:duration-200'"
  );
  source = replaceRequired(
    source,
    'sheet close button native',
    'className="ring-offset-background focus:ring-ring data-[state=open]:bg-background-secondary absolute top-4 right-4 rounded-xs opacity-70 transition-opacity hover:opacity-100 focus:ring-2 focus:ring-offset-2 focus:outline-hidden disabled:pointer-events-none"',
    'className="ring-offset-background absolute top-4 right-4 rounded-[8px] p-1 opacity-70 transition-all duration-150 hover:bg-background-secondary/75 hover:opacity-100 focus:bg-background-secondary/75 focus:outline-none disabled:pointer-events-none data-[state=open]:bg-background-secondary/75"'
  );
  source = replaceRequired(
    source,
    'sheet title native font',
    "className={cn('text-text-primary font-medium', className)}",
    "className={cn('text-text-primary font-sans font-semibold tracking-normal', className)}"
  );
  write('src/components/ui/sheet.tsx', source);

  source = read('src/components/bottom_menu/BottomMenuAlertPopover.tsx');
  source = replaceRequired(
    source,
    'bottom alert divider token',
    "className={cn(index > 0 && 'border-t border-white/20')}",
    "className={cn(index > 0 && 'pt-3')}"
  );
  write('src/components/bottom_menu/BottomMenuAlertPopover.tsx', source);

  source = read('src/components/GroupedExtensionLoadingToast.tsx');
  source = replaceRequired(
    source,
    'extension loading toast divider token',
    'className="mt-3 pt-3 border-t border-white/20"',
    'className="mt-3 pt-3"'
  );
  write('src/components/GroupedExtensionLoadingToast.tsx', source);
}

function applyLoadingAndErrorSurfaces() {
  let source = read('src/suspense-loader.tsx');
  source = replaceRequired(
    source,
    'suspense loader transparent root',
    'className="flex flex-col items-start justify-end w-screen h-screen overflow-hidden p-6 page-transition"',
    'className="goose-epistemos flex h-screen w-screen flex-col items-start justify-end overflow-hidden bg-transparent p-6 page-transition"'
  );
  source = replaceRequired(
    source,
    'suspense loader native card',
    'className="flex gap-2 items-center justify-end"',
    'className="ep-native-screen-card flex items-center justify-end gap-2 px-3 py-2"'
  );
  source = replaceRequired(
    source,
    'suspense loader native dot',
    'className="h-3 w-3 border border-border-prominent bg-background-muted animate-pulse"',
    'className="ep-native-loading-dot is-active"'
  );
  source = replaceRequired(
    source,
    'suspense loader native text',
    'className="font-mono text-xs uppercase text-text-secondary"',
    'className="ep-native-status-line text-xs text-text-secondary"'
  );
  write('src/suspense-loader.tsx', source);

  source = read('src/components/LoadingEpistemos.tsx');
  source = replaceRequired(
    source,
    'loading epistemos native dot',
    "className={`h-1.5 w-1.5 bg-primary ${active ? 'animate-pulse' : ''}`}",
    "className={`ep-native-loading-dot ${active ? 'is-active' : 'opacity-50'}`}"
  );
  source = replaceRequired(
    source,
    'loading epistemos native status text',
    'className="flex items-center gap-2 text-[11px] text-text-secondary py-2 font-mono uppercase"',
    'className="ep-native-status-line flex items-center gap-2 py-2 text-[11px] text-text-secondary"'
  );
  write('src/components/LoadingEpistemos.tsx', source);

  source = read('src/components/ErrorBoundary.tsx');
  source = replaceRequired(
    source,
    'error boundary native transparent shell',
    'className="fixed inset-0 w-full h-full flex flex-col items-center justify-center gap-6 bg-background"',
    'className="goose-epistemos ep-native-error-shell fixed inset-0 flex h-full w-full flex-col items-center justify-center gap-6 bg-transparent"'
  );
  source = replaceRequired(
    source,
    'error boundary native card',
    'className="flex flex-col items-center gap-4 max-w-[600px] text-center px-6"',
    'className="ep-native-error-card flex max-w-[620px] flex-col items-center gap-4 px-6 py-7 text-center"'
  );
  source = replaceRequired(
    source,
    'error boundary native icon',
    'className="w-12 h-12 bg-destructive/10 border border-border-primary flex items-center justify-center mb-2"',
    'className="ep-native-error-icon mb-2 flex h-12 w-12 items-center justify-center"'
  );
  source = replaceRequired(
    source,
    'error boundary native heading',
    'className="text-2xl font-mono font-normal text-foreground dark:text-white"',
    'className="text-2xl font-sans font-semibold tracking-normal text-foreground dark:text-white"'
  );
  source = replaceRequired(
    source,
    'error boundary native pre',
    'className="text-destructive text-sm dark:text-white p-4 bg-muted rounded-[6px] w-full overflow-auto border border-border whitespace-pre-wrap"',
    'className="w-full overflow-auto whitespace-pre-wrap rounded-[12px] bg-background-secondary/62 p-4 text-left text-sm text-text-danger"'
  );
  source = replaceRequired(
    source,
    'error boundary icon color token',
    '<AlertTriangle className="w-6 h-6 text-destructive" />',
    '<AlertTriangle className="h-6 w-6 text-text-danger" />'
  );
  write('src/components/ErrorBoundary.tsx', source);
}

function applyFinalBorderlessDriftSurfaces() {
  let source = read('src/components/AnnouncementModal.tsx');
  source = replaceRequired(
    source,
    'announcement action borderless',
    'className="w-full h-[60px] rounded-none border-b border-border-primary bg-transparent hover:bg-background-secondary text-text-primary font-medium text-md"',
    'className="h-11 w-full rounded-[8px] bg-background-primary/58 text-md font-medium text-text-primary transition-colors hover:bg-background-secondary/72"'
  );
  write('src/components/AnnouncementModal.tsx', source);

  source = read('src/components/sessions/SessionViewComponents.tsx');
  source = replaceRequired(
    source,
    'session view tool badge borderless',
    "? 'bg-bgSecondary border border-border-primary'",
    "? 'bg-background-secondary/56'"
  );
  write('src/components/sessions/SessionViewComponents.tsx', source);

  source = read('src/components/schedule/SchedulesView.tsx');
  source = replaceAllRequired(
    source,
    'schedule badge borders borderless',
    ' border border-border-secondary',
    ''
  );
  write('src/components/schedule/SchedulesView.tsx', source);

  source = read('src/components/bottom_menu/BottomMenuAlertPopover.tsx');
  source = replaceRequired(
    source,
    'bottom menu alert popover borderless',
    'className="fixed w-[275px] p-0 rounded-[6px] overflow-hidden bg-app border border-border-primary z-50 shadow-none pointer-events-auto text-left"',
    'className="pointer-events-auto fixed z-50 w-[275px] overflow-hidden rounded-[12px] bg-background-primary/92 p-0 text-left"'
  );
  write('src/components/bottom_menu/BottomMenuAlertPopover.tsx', source);

  source = read('src/components/ImagePreview.tsx');
  source = replaceRequired(
    source,
    'image preview thumbnail borderless',
    'className={`rounded-[5px] border border-border-primary cursor-pointer hover:border-border-primary transition-all ${',
    'className={`cursor-pointer rounded-[10px] bg-background-primary/54 transition-all hover:bg-background-secondary/56 ${'
  );
  write('src/components/ImagePreview.tsx', source);

  source = read('src/components/extensions/ExtensionsView.tsx');
  source = replaceRequired(
    source,
    'extensions header borderless',
    'className="bg-background-primary px-6 pb-3 pt-14 border-b border-border-secondary"',
    'className="bg-background-primary/58 px-6 pb-3 pt-14"'
  );
  write('src/components/extensions/ExtensionsView.tsx', source);

  source = read('src/components/RecipeHeader.tsx');
  source = replaceRequired(
    source,
    'recipe header borderless',
    'className="flex items-center justify-between px-4 py-2 border-b border-border-primary"',
    'className="flex items-center justify-between bg-background-primary/42 px-4 py-2"'
  );
  write('src/components/RecipeHeader.tsx', source);

  source = read('src/components/MCPUIResourceRenderer.tsx');
  source = replaceRequired(
    source,
    'mcp ui resource renderer borderless',
    'className="mt-3 border border-border-secondary bg-background-secondary p-2"',
    'className="mt-3 rounded-[12px] bg-background-secondary/56 p-2"'
  );
  write('src/components/MCPUIResourceRenderer.tsx', source);

  source = read('src/components/parameter/ParameterInput.tsx');
  source = replaceRequired(
    source,
    'parameter nested editor borderless',
    'className="px-4 pb-4 border-t border-border-primary"',
    'className="rounded-[12px] bg-background-primary/32 px-4 pb-4 pt-3"'
  );
  write('src/components/parameter/ParameterInput.tsx', source);

  source = read('src/components/recipes/shared/RecipeExtensionSelector.tsx');
  source = replaceRequired(
    source,
    'recipe extension selector list borderless',
    'className="max-h-[300px] overflow-y-auto border border-borderSubtle rounded-lg"',
    'className="max-h-[300px] overflow-y-auto rounded-[12px] bg-background-secondary/44"'
  );
  source = replaceRequired(
    source,
    'recipe extension selector row borderless',
    'className="flex items-center justify-between px-4 py-3 hover:bg-bgSubtle transition-colors cursor-pointer border-b border-borderSubtle last:border-b-0"',
    'className="flex cursor-pointer items-center justify-between px-4 py-3 transition-colors hover:bg-background-secondary/62"'
  );
  write('src/components/recipes/shared/RecipeExtensionSelector.tsx', source);

  source = read('src/components/recipes/shared/SubRecipeEditor.tsx');
  source = replaceRequired(
    source,
    'sub recipe editor value chip borderless',
    'className="text-xs px-2 py-1 bg-background-muted border border-border-subtle rounded"',
    'className="rounded-[8px] bg-background-secondary/60 px-2 py-1 text-xs"'
  );
  write('src/components/recipes/shared/SubRecipeEditor.tsx', source);

  source = read('src/components/ui/RecipeWarningModal.tsx');
  source = replaceRequired(
    source,
    'recipe warning dialog shell borderless',
    "'bg-background-primary data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed top-[50%] left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] gap-4 rounded-[6px] border border-border-primary p-6 shadow-none duration-150 sm:max-w-[80vw] max-h-[80vh] flex flex-col p-0'",
    "'fixed left-[50%] top-[50%] z-50 flex max-h-[80vh] w-full max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] flex-col gap-4 overflow-hidden rounded-[14px] bg-background-primary/92 p-0 duration-150 data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:animate-out data-[state=open]:animate-in sm:max-w-[80vw]'"
  );
  write('src/components/ui/RecipeWarningModal.tsx', source);

  source = read('src/components/settings/mode/ModeSelectionItem.tsx');
  source = replaceAllOptional(source, ' border border-border-secondary', '');
  write('src/components/settings/mode/ModeSelectionItem.tsx', source);

  source = read('src/components/settings/response_styles/ResponseStyleSelectionItem.tsx');
  source = replaceAllOptional(source, ' border border-border-secondary', '');
  write('src/components/settings/response_styles/ResponseStyleSelectionItem.tsx', source);

  source = read('src/components/settings/models/subcomponents/SwitchModelModal.tsx');
  source = replaceAllOptional(source, ' border border-border-secondary', '');
  write('src/components/settings/models/subcomponents/SwitchModelModal.tsx', source);

  source = read('src/components/settings/app/UpdateSection.tsx');
  source = replaceRequired(
    source,
    'update section divider borderless',
    'className="mt-6 pt-4 border-t border-borderSubtle"',
    'className="mt-6 rounded-[12px] bg-background-primary/34 p-4"'
  );
  write('src/components/settings/app/UpdateSection.tsx', source);

  source = read('src/components/settings/app/ExternalBackendSection.tsx');
  source = replaceRequired(
    source,
    'external backend warning borderless',
    'className="bg-background-warning border border-border-warning rounded-md p-3"',
    'className="rounded-[12px] bg-background-warning/55 p-3"'
  );
  write('src/components/settings/app/ExternalBackendSection.tsx', source);
}

function applyFinalFlatPixelAudit() {
  const paletteClassReplacements = [
    ['text-red-500', 'text-text-danger'],
    ['hover:text-red-600', 'hover:text-text-danger'],
    ['hover:text-red-700', 'hover:text-text-danger'],
    ['text-orange-500', 'text-text-warning'],
    ['text-orange-600', 'text-text-warning'],
    ['dark:text-orange-400', 'dark:text-text-warning'],
    ['text-amber-600', 'text-text-warning'],
    ['text-amber-700', 'text-text-warning'],
    ['dark:text-amber-300', 'dark:text-text-warning'],
    ['dark:text-amber-400', 'dark:text-text-warning'],
    ['text-yellow-500', 'text-text-warning'],
    ['text-emerald-700', 'text-text-success'],
    ['dark:text-emerald-300', 'dark:text-text-success'],
    ['text-purple-700', 'text-[var(--epistemos-accent)]'],
    ['dark:text-purple-300', 'dark:text-[var(--epistemos-accent)]'],
    ['text-gray-500', 'text-text-secondary'],
    ['dark:text-gray-400', 'dark:text-text-secondary'],
    ['bg-amber-500', 'bg-background-warning'],
    ['bg-amber-50/10', 'bg-background-warning/35'],
    ['bg-orange-400', 'bg-background-warning'],
    ['bg-red-50', 'bg-background-danger/35'],
    ['fill-orange-400', 'fill-[var(--color-background-warning)]'],
    ['dark:hover:bg-red-900/20', 'dark:hover:bg-background-danger/55'],
    ['hover:bg-red-50', 'hover:bg-background-danger/55'],
    ['hover:bg-red-900/20', 'hover:bg-background-danger/55'],
    ['border-amber-500/30', ''],
    ['border-amber-500/60', ''],
    ['border-orange-300', ''],
    ['dark:border-orange-600', ''],
    ['hover:bg-orange-50', 'hover:bg-background-warning/55'],
    ['dark:hover:bg-orange-900/20', 'dark:hover:bg-background-warning/55'],
  ];

  const sourceRoot = path.join(desktopRoot, 'src');
  const files = walkFiles(
    sourceRoot,
    (file) => /\.(css|tsx?|jsx?)$/.test(file)
  );
  for (const file of files) {
    const relativePath = path.relative(desktopRoot, file);
    const isCSS = relativePath.endsWith('.css');
    const isThemeTokens = relativePath === 'src/theme/theme-tokens.ts';
    let source = fs.readFileSync(file, 'utf8');
    let next = source;

    next = next
      .replaceAll('text-red-500/bg-blue-50', 'text-red-500/accent-tint')
      .replace(/outline:\s*2px solid var\(--color-border-active,\s*#[0-9a-fA-F]{6}\)\s*!important;/g, 'outline: none !important;')
      .replace(/outline:\s*2px solid var\(--color-border-active,\s*#[0-9a-fA-F]{6}\);/g, 'outline: none !important;')
      .replaceAll('#0066cc', 'var(--epistemos-pixel-accent)')
      .replaceAll('#2997ff', 'var(--epistemos-pixel-accent)')
      .replaceAll('outline: 2px solid var(--color-border-active, var(--epistemos-accent)) !important;', 'outline: none !important;')
      .replaceAll('outline: 2px solid var(--color-border-active, var(--epistemos-accent));', 'outline: none !important;')
      .replaceAll('outline-offset: 2px !important;', 'outline-offset: 0 !important;')
      .replaceAll('outline-offset: 2px;', 'outline-offset: 0;')
      .replaceAll('bg-black/20', 'ep-native-modal-scrim');

    if (!isCSS && !isThemeTokens) {
      next = next
        .replace(/\sfocus(?:-visible)?:ring(?:-[^\s"'`}$]+)?/g, '')
        .replace(/\sfocus(?:-visible)?:ring-opacity-[^\s"'`}$]+/g, '')
        .replace(/\sfocus(?:-visible)?:ring-offset-[^\s"'`}$]+/g, '')
        .replace(/\sfocus((?:-visible)?):outline-hidden/g, ' focus$1:outline-none')
        .replace(/\soutline-hidden/g, ' outline-none')
        .replace(/\sfocus(?:-visible)?:border-(?:\[[^\s"'`}$]+\]|[^\s"'`}$]+)/g, ' focus:border-transparent')
        .replace(/\sring-blue-[^\s"'`}$]+/g, '')
        .replace(/\sring-\[3px\]/g, '')
        .replace(/\sring-(?:\[[^\s"'`}$]+\](?:\/[^\s"'`}$]+)?|[^\s"'`}$]+)/g, '')
        .replace(/\sborder-blue-[^\s"'`}$]+/g, ' border-[var(--epistemos-accent)]')
        .replace(/\stext-blue-[^\s"'`}$]+/g, ' text-[var(--epistemos-accent)]')
        .replace(/\sbg-blue-[^\s"'`}$]+/g, ' bg-[var(--epistemos-accent)]/10')
        .replace(/\bfocus(?:-visible)?:ring(?:-[^\s"'`}$]+)?/g, '')
        .replace(/\bfocus(?:-visible)?:ring-opacity-[^\s"'`}$]+/g, '')
        .replace(/\bfocus(?:-visible)?:ring-offset-[^\s"'`}$]+/g, '')
        .replace(/\bfocus((?:-visible)?):outline-hidden/g, 'focus$1:outline-none')
        .replace(/\boutline-hidden/g, 'outline-none')
        .replace(/\bfocus(?:-visible)?:border-(?:\[[^\s"'`}$]+\]|[^\s"'`}$]+)/g, 'focus:border-transparent')
        .replace(/\bring-blue-[^\s"'`}$]+/g, '')
        .replace(/\bring-\[3px\]/g, '')
        .replace(/\bring-(?:\[[^\s"'`}$]+\](?:\/[^\s"'`}$]+)?|[^\s"'`}$]+)/g, '')
        .replace(/\bborder-blue-[^\s"'`}$]+/g, 'border-[var(--epistemos-accent)]')
        .replace(/\btext-blue-[^\s"'`}$]+/g, 'text-[var(--epistemos-accent)]')
        .replace(/\bbg-blue-[^\s"'`}$]+/g, 'bg-[var(--epistemos-accent)]/10');

      for (const [from, to] of paletteClassReplacements) {
        next = next.replaceAll(from, to);
      }
    }

    if (relativePath === 'src/styles/main.css' && !next.includes('epistemos-native-final-flat-pixel-audit')) {
      next += `

/* Epistemos final flat/pixel audit (epistemos-native-final-flat-pixel-audit)
   Last staging guard: no blue fallback focus rings or hard outline rules after
   upstream Goose component rewrites have run. */
.goose-epistemos :is(button, [href], input, textarea, select, [role='button'], [role='tab'], [role='menuitem'], [role='option'], [tabindex]:not([tabindex='-1'])):focus,
.goose-epistemos :is(button, [href], input, textarea, select, [role='button'], [role='tab'], [role='menuitem'], [role='option'], [tabindex]:not([tabindex='-1'])):focus-visible {
  outline: none !important;
  outline-offset: 0 !important;
  border-color: transparent !important;
  border-width: 0 !important;
  box-shadow: none !important;
}
`;
    }
    if (relativePath === 'src/styles/main.css' && !next.includes(claudeDesktopLockMarker)) {
      next += `

/* Epistemos Claude desktop lock (${claudeDesktopLockMarker})
   Absolute final visual lock for the owner-approved direction: Claude-like
   flat desktop shell, one Goose sidebar, no native rail, no box borders, no
   blue focus ring, and only a small pixel accent on display/section labels. */
.goose-epistemos {
  --epistemos-native-claude-desktop-lock: 1;
  --${flatSourceSurfacesMarker}: 1;
  --epistemos-claude-bg: var(--color-background-primary);
  --epistemos-claude-sidebar: color-mix(in srgb, var(--color-background-secondary) 72%, var(--color-background-primary));
  --epistemos-claude-sidebar-hover: color-mix(in srgb, var(--color-background-secondary) 88%, var(--color-background-primary));
  --epistemos-claude-surface: color-mix(in srgb, var(--color-background-secondary) 36%, var(--color-background-primary));
  --epistemos-claude-surface-strong: color-mix(in srgb, var(--color-background-secondary) 56%, var(--color-background-primary));
  --epistemos-claude-active: color-mix(in srgb, var(--epistemos-pixel-accent) 9%, var(--epistemos-claude-sidebar-hover));
  --epistemos-claude-focus: color-mix(in srgb, var(--epistemos-pixel-accent) 6%, var(--epistemos-claude-surface-strong));
  --epistemos-claude-modal-scrim: color-mix(in srgb, var(--color-background-inverse) 18%, transparent);
  --epistemos-claude-float-shadow: 0 18px 50px color-mix(in srgb, var(--color-background-inverse) 10%, transparent);
  --epistemos-claude-composer-shadow: 0 14px 38px color-mix(in srgb, var(--color-text-primary) 5%, transparent);
  background: var(--epistemos-claude-bg) !important;
  color: var(--color-text-primary) !important;
}

.dark .goose-epistemos {
  --epistemos-claude-sidebar: color-mix(in srgb, var(--color-background-secondary) 54%, var(--color-background-primary));
  --epistemos-claude-sidebar-hover: color-mix(in srgb, var(--color-background-secondary) 64%, var(--color-background-primary));
  --epistemos-claude-surface: color-mix(in srgb, var(--color-background-secondary) 28%, var(--color-background-primary));
  --epistemos-claude-surface-strong: color-mix(in srgb, var(--color-background-secondary) 44%, var(--color-background-primary));
  --epistemos-claude-float-shadow: 0 18px 50px color-mix(in srgb, black 26%, transparent);
  --epistemos-claude-composer-shadow: 0 16px 44px color-mix(in srgb, black 24%, transparent);
}

html,
body,
#root,
.goose-epistemos,
.goose-epistemos :is(main, [role='main']) {
  background: var(--epistemos-claude-bg) !important;
}

.goose-epistemos :is(
  aside,
  [data-sidebar],
  [data-slot='sidebar'],
  [class*='Sidebar'],
  [class*='sidebar'],
  .bg-background-secondary
) {
  background: var(--epistemos-claude-sidebar) !important;
  box-shadow: none !important;
}

.goose-epistemos :is(
  .bg-background-primary,
  .bg-background-default
) {
  background: transparent !important;
}

.goose-epistemos :is(
  [class*='border'],
  .border,
  .border-t,
  .border-r,
  .border-b,
  .border-l,
  .divide-y > :not([hidden]) ~ :not([hidden]),
  [data-orientation='horizontal'],
  [data-orientation='vertical']
) {
  border-color: transparent !important;
  outline-color: transparent !important;
}

.goose-epistemos :is(.border, .border-t, .border-r, .border-b, .border-l) {
  border-width: 0 !important;
}

.goose-epistemos :is(
  [class*='shadow'],
  [class*='backdrop-blur'],
  .shadow,
  .shadow-sm,
  .shadow-md,
  .shadow-lg,
  .shadow-xl,
  .shadow-2xl,
  .backdrop-blur,
  .backdrop-blur-sm,
  .backdrop-blur-md,
  .backdrop-blur-lg,
  .backdrop-blur-xl
) {
  -webkit-backdrop-filter: none !important;
  backdrop-filter: none !important;
  box-shadow: none !important;
}

.goose-epistemos :is(
  button,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  input,
  textarea,
  select,
  [contenteditable='true']
) {
  border-color: transparent !important;
  border-width: 0 !important;
  outline: none !important;
  box-shadow: none !important;
  --tw-ring-color: transparent !important;
  --tw-ring-offset-color: transparent !important;
  --tw-ring-shadow: 0 0 #0000 !important;
  --tw-ring-offset-shadow: 0 0 #0000 !important;
}

.goose-epistemos :is(
  button,
  [href],
  input,
  textarea,
  select,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  [tabindex]:not([tabindex='-1'])
):focus,
.goose-epistemos :is(
  button,
  [href],
  input,
  textarea,
  select,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option'],
  [tabindex]:not([tabindex='-1'])
):focus-visible {
  outline: none !important;
  outline-offset: 0 !important;
  background: var(--epistemos-claude-focus) !important;
  box-shadow: none !important;
  --tw-ring-color: transparent !important;
  --tw-ring-offset-color: transparent !important;
  --tw-ring-shadow: 0 0 #0000 !important;
  --tw-ring-offset-shadow: 0 0 #0000 !important;
}

.goose-epistemos :is(
  button,
  [role='button'],
  [role='tab'],
  [role='menuitem'],
  [role='option']
):not(:disabled):hover {
  background: var(--epistemos-claude-sidebar-hover) !important;
}

.goose-epistemos :is(
  [aria-current='page'],
  [data-state='active'],
  button[aria-selected='true'],
  [role='tab'][aria-selected='true']
) {
  background: var(--epistemos-claude-active) !important;
}

.ep-native-modal-scrim,
.goose-epistemos .ep-native-modal-scrim {
  background: color-mix(in srgb, var(--color-background-inverse) 18%, transparent) !important;
}

.goose-epistemos [class~='bg-[var(--epistemos-accent)]'] {
  background: var(--epistemos-pixel-accent) !important;
  color: var(--color-text-inverse) !important;
}

.goose-epistemos [class~='bg-[var(--epistemos-accent)]']:not(:disabled):hover {
  background: color-mix(in srgb, var(--epistemos-pixel-accent) 88%, var(--epistemos-claude-bg)) !important;
}

.goose-epistemos :is(
  input,
  textarea,
  select,
  [contenteditable='true'],
  .goose-chat-input-card,
  .goose-user-message-bubble,
  .goose-message-content,
  .goose-message-tool,
  .goose-tool-call,
  .ep-native-screen-card,
  .ep-native-list-card,
  [data-slot='card']
) {
  background: var(--epistemos-claude-surface) !important;
  border-color: transparent !important;
  border-width: 0 !important;
  box-shadow: none !important;
}

.goose-epistemos .goose-chat-input-card {
  background: color-mix(in srgb, var(--epistemos-claude-surface) 44%, var(--epistemos-claude-bg)) !important;
  border-radius: 16px !important;
  box-shadow: var(--epistemos-claude-composer-shadow) !important;
}

.goose-epistemos .goose-chat-input-card:focus-within {
  outline: none !important;
  background: var(--epistemos-claude-focus) !important;
  box-shadow: 0 18px 46px color-mix(in srgb, var(--epistemos-pixel-accent) 9%, transparent) !important;
}

.goose-epistemos :is(
  [role='dialog'],
  [data-slot='dialog-content'],
  [data-slot='dropdown-menu-content'],
  [data-slot='dropdown-menu-sub-content'],
  .select__menu,
  [data-radix-popper-content-wrapper] > *
) {
  -webkit-backdrop-filter: none !important;
  backdrop-filter: none !important;
  background: var(--epistemos-claude-bg) !important;
  border-color: transparent !important;
  border-width: 0 !important;
  box-shadow: var(--epistemos-claude-float-shadow) !important;
}

.goose-epistemos :is(
  .ep-display,
  .ep-pixel,
  .ep-native-section-label,
  .ep-native-window-title,
  .ep-native-companion,
  [data-epistemos-pixel-heading],
  [data-epistemos-section-label],
  [data-epistemos-window-title],
  [data-epistemos-companion],
  [class*='section-label'],
  [class*='SectionLabel'],
  [class*='window-title'],
  [class*='WindowTitle'],
  [class*='companion-mascot'],
  [class*='CompanionMascot']
) {
  font-family: var(--epistemos-pixel-font) !important;
  font-weight: 600 !important;
  letter-spacing: 0 !important;
  image-rendering: pixelated;
}

.goose-epistemos :is(h2, h3, h4, h5, h6):not(.ep-display):not(.ep-pixel):not(.ep-native-section-label):not([data-epistemos-pixel-heading]):not([data-epistemos-section-label]):not([data-epistemos-window-title]):not([data-epistemos-companion]) {
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", system-ui, sans-serif !important;
}
`;
    }

    if (next !== source) {
      fs.writeFileSync(file, next);
    }
  }
}

applyThemeTokens();
applyMainCSS();
applyButton();
applyInput();
applyCard();
applyDialog();
applyDropdownMenu();
applySwitch();
applyTabs();
applySelect();
applyPrimitiveCompletionSurfaces();
applyMotionSurfaces();
applyAppSurfaces();
applyOnboardingSurfaces();
applyChatSurfaces();
applyToolAndPopoverSurfaces();
applyCatalogSurfaces();
applyProviderCatalogSurfaces();
applyProviderModalSurfaces();
applyExtensionSettingsSurfaces();
applyExtensionListSurfaces();
applyChatSettingsSurfaces();
applyPermissionSurfaces();
applySettingsPanelSurfaces();
applyModelSettingsSurfaces();
applyKeyboardSettingsSurfaces();
applyAuthSettingsSurfaces();
applyLocalInferenceSurfaces();
applyGatewaySettingsSurfaces();
applyDictationSettingsSurfaces();
applySecuritySettingsSurfaces();
applySessionSharingSurfaces();
applyUtilityListSurfaces();
applySessionListSurfaces();
applySessionDetailSurfaces();
applySchedulerDetailSurfaces();
applyRecipeDetailSurfaces();
applySearchSurfaces();
applyStatusIndicatorSurfaces();
applyFormValidationSurfaces();
applyRemainingTokenDriftSurfaces();
applyNeutralTokenDriftSurfaces();
applyModalScrimAndElicitationSurfaces();
applyLoadingAndErrorSurfaces();
applyFinalBorderlessDriftSurfaces();
applyFinalFlatPixelAudit();

console.log(`Applied Goose native reskin overlay: ${desktopRoot}`);
