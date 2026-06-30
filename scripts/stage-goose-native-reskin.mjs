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

function read(relativePath) {
  return fs.readFileSync(path.join(desktopRoot, relativePath), 'utf8');
}

function write(relativePath, source) {
  fs.writeFileSync(path.join(desktopRoot, relativePath), source);
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

function replaceAllRequired(source, label, search, replacement) {
  const next = source.replaceAll(search, replacement);
  if (next === source) {
    throw new Error(`${label} replacement was not applied`);
  }
  return next;
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
    '--color-background-info': ['#e8f2ff', '#0c2742'],
    '--color-background-danger': ['#fff1ef', '#3a1c19'],
    '--color-background-success': ['#eaf7ee', '#17351f'],
    '--color-background-warning': ['#fff6df', '#332611'],
    '--color-background-disabled': ['#f0f0f0', '#333333'],
    '--color-text-primary': ['#1d1d1f', '#ffffff'],
    '--color-text-secondary': ['#6e6e73', '#cccccc'],
    '--color-text-tertiary': ['#86868b', '#7a7a7a'],
    '--color-text-inverse': ['#ffffff', '#1d1d1f'],
    '--color-text-ghost': ['#86868b', '#7a7a7a'],
    '--color-text-info': ['#0066cc', '#2997ff'],
    '--color-text-danger': ['#bf3b30', '#ff9f96'],
    '--color-text-success': ['#248a3d', '#8fd69d'],
    '--color-text-warning': ['#8a5b00', '#ffd45a'],
    '--color-text-disabled': ['#86868b', '#7a7a7a'],
    '--color-border-primary': ['#e0e0e0', '#333333'],
    '--color-border-secondary': ['#f0f0f0', '#252527'],
    '--color-border-tertiary': ['#d2d2d7', '#3a3a3c'],
    '--color-border-inverse': ['#1d1d1f', '#ffffff'],
    '--color-border-info': ['#9dccff', '#2f6ea8'],
    '--color-border-danger': ['#ffb4ab', '#7a3934'],
    '--color-border-success': ['#9ad8aa', '#346b42'],
    '--color-border-warning': ['#e6c76f', '#7a5d1c'],
    '--color-border-disabled': ['#e0e0e0', '#333333'],
    '--color-ring-primary': ['#0066cc', '#2997ff'],
    '--color-ring-secondary': ['#0071e3', '#0066cc'],
    '--color-ring-inverse': ['#ffffff', '#1d1d1f'],
    '--color-ring-info': ['#0066cc', '#2997ff'],
    '--color-ring-danger': ['#bf3b30', '#ff9f96'],
    '--color-ring-success': ['#248a3d', '#8fd69d'],
    '--color-ring-warning': ['#8a5b00', '#ffd45a'],
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
  --epistemos-accent: var(--color-ring-primary, #0066cc);
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
   These are global "web tells": Goose used custom hidden scrollbars and neutral
   focus outlines. Restore the WKWebView/system scrollbar path and use the same
   accent-driven focus ring as the native frame.
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
):focus-visible {
  outline: 2px solid color-mix(in srgb, var(--epistemos-accent) 86%, transparent) !important;
  outline-offset: 2px !important;
  box-shadow:
    0 0 0 1px color-mix(in srgb, var(--epistemos-accent) 50%, transparent),
    0 0 0 5px color-mix(in srgb, var(--epistemos-accent) 16%, transparent) !important;
}

.goose-epistemos :is(input, textarea, select):focus-visible {
  border-color: var(--epistemos-accent) !important;
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
  color: white !important;
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
  box-shadow:
    0 1px 0 color-mix(in srgb, white 55%, transparent) inset,
    0 18px 46px rgba(0, 0, 0, 0.10) !important;
}

.dark .goose-epistemos .goose-chat-input-card {
  box-shadow:
    0 1px 0 rgba(255, 255, 255, 0.08) inset,
    0 20px 54px rgba(0, 0, 0, 0.34) !important;
}

.goose-epistemos .goose-message {
  width: min(88%, 900px) !important;
}

.goose-epistemos :is(.goose-tool-call, .goose-message-content, .goose-message-tool) {
  border-radius: 14px !important;
  background-color: var(--epistemos-glass-fill-muted) !important;
  box-shadow:
    0 1px 0 color-mix(in srgb, white 46%, transparent) inset,
    0 10px 28px rgba(0, 0, 0, 0.07) !important;
}

.dark .goose-epistemos :is(.goose-tool-call, .goose-message-content, .goose-message-tool) {
  box-shadow:
    0 1px 0 rgba(255, 255, 255, 0.07) inset,
    0 12px 30px rgba(0, 0, 0, 0.24) !important;
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
  border: 1px solid var(--epistemos-glass-border);
  border-radius: 12px;
  background-color: color-mix(in srgb, var(--color-background-secondary) 74%, transparent) !important;
}

.goose-epistemos .prose code:not(pre code) {
  border: 1px solid color-mix(in srgb, var(--color-border-primary) 70%, transparent);
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
  border: 1px solid var(--epistemos-glass-border);
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
  box-shadow:
    0 1px 0 color-mix(in srgb, white 42%, transparent) inset,
    0 10px 30px rgba(0, 0, 0, 0.07) !important;
}

.dark .goose-epistemos :is(.ep-native-screen-card, .ep-native-list-card) {
  box-shadow:
    0 1px 0 rgba(255, 255, 255, 0.07) inset,
    0 12px 34px rgba(0, 0, 0, 0.24) !important;
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
  write('src/styles/main.css', source);
}

function applyButton() {
  let source = read('src/components/ui/button.tsx');
  source = replaceRequired(
    source,
    'button base chrome',
    `"inline-flex items-center justify-center gap-2 whitespace-nowrap text-sm transition-all cursor-pointer disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 shrink-0 [&_svg]:shrink-0 outline-none focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[1px] aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive"`,
    `"inline-flex items-center justify-center gap-2 whitespace-nowrap text-sm font-semibold transition-all duration-200 ease-[var(--epistemos-control-ease)] cursor-pointer disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 shrink-0 [&_svg]:shrink-0 outline-none focus-visible:border-[var(--epistemos-accent)] focus-visible:ring-[var(--epistemos-accent)]/30 focus-visible:ring-[3px] aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive"`
  );
  source = replaceRequired(
    source,
    'button default variant',
    "default: 'bg-background-inverse text-text-inverse hover:bg-background-inverse/90 shadow-none'",
    "default: 'bg-[var(--epistemos-accent)] text-white hover:bg-[var(--epistemos-accent)]/90 shadow-sm'"
  );
  source = replaceRequired(
    source,
    'button outline variant',
    "outline: 'border hover:bg-background-secondary'",
    "outline: 'border border-border-primary bg-background-primary/55 hover:bg-background-secondary/75 backdrop-blur-xl'"
  );
  source = replaceRequired(
    source,
    'button secondary variant',
    "secondary:\n          'bg-background-secondary text-text-primary hover:bg-background-secondary/80 shadow-none'",
    "secondary:\n          'bg-background-secondary/72 text-text-primary hover:bg-background-secondary/90 shadow-sm backdrop-blur-xl'"
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
    "'flex h-9 w-full rounded-[8px] border border-border-primary bg-background-primary/70 px-3 py-1 text-sm transition-all duration-200 ease-[var(--epistemos-control-ease)] file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground placeholder:text-text-secondary placeholder:font-light hover:border-border-tertiary focus:border-[var(--epistemos-accent)] focus-visible:outline-none focus-visible:ring-[3px] focus-visible:ring-[var(--epistemos-accent)]/20 disabled:cursor-not-allowed disabled:opacity-50'"
  );
  write('src/components/ui/input.tsx', source);
}

function applyCard() {
  let source = read('src/components/ui/card.tsx');
  source = replaceRequired(
    source,
    'card native glass',
    "'bg-background-primary text-text-primary flex flex-col gap-3 rounded-[6px] border border-border-secondary py-3 shadow-none'",
    "'bg-background-primary/72 text-text-primary flex flex-col gap-3 rounded-[11px] border border-border-secondary py-3 shadow-sm backdrop-blur-xl'"
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
    "'data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed inset-0 z-40 bg-black/24 backdrop-blur-sm'"
  );
  source = replaceRequired(
    source,
    'dialog content',
    "'bg-background-primary data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed top-[50%] left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] gap-4 rounded-[6px] border border-border-primary p-5 shadow-none duration-150 sm:max-w-lg'",
    "'bg-background-primary/86 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed top-[50%] left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] gap-4 rounded-[14px] border border-border-primary p-5 shadow-2xl backdrop-blur-xl duration-200 ease-[var(--epistemos-control-ease)] sm:max-w-lg'"
  );
  source = replaceRequired(
    source,
    'dialog close button',
    `DialogPrimitive.Close className="ring-offset-background p-1 hover:bg-background-secondary rounded-[4px] focus:ring-ring data-[state=open]:bg-background-secondary transition-all duration-150 data-[state=open]:text-text-secondary absolute top-4 right-4 opacity-70 hover:opacity-100 focus:ring-1 focus:outline-hidden disabled:pointer-events-none [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"`,
    `DialogPrimitive.Close className="ring-offset-background p-1 hover:bg-background-secondary rounded-[8px] focus:ring-[var(--epistemos-accent)] data-[state=open]:bg-background-secondary transition-all duration-150 data-[state=open]:text-text-secondary absolute top-4 right-4 opacity-70 hover:opacity-100 focus:ring-2 focus:outline-hidden disabled:pointer-events-none [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"`
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
    "'bg-background-primary/88 text-text-primary data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 z-50 max-h-(--radix-dropdown-menu-content-available-height) min-w-[8rem] origin-(--radix-dropdown-menu-content-transform-origin) overflow-x-hidden overflow-y-auto rounded-[9px] border border-border-primary p-1 shadow-lg backdrop-blur-xl space-y-0.5'"
  );
  source = source.replaceAll("rounded-sm px-2 py-1.5 text-sm", "rounded-[6px] px-2 py-1.5 text-sm");
  source = source.replaceAll("focus:bg-background-secondary focus:text-text-secondary", "focus:bg-[var(--epistemos-accent)] focus:text-white");
  source = replaceRequired(
    source,
    'dropdown sub content',
    "'bg-background-primary text-text-primary data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 z-50 min-w-[8rem] origin-(--radix-dropdown-menu-content-transform-origin) overflow-hidden rounded-[6px] border border-border-primary p-1 shadow-none'",
    "'bg-background-primary/88 text-text-primary data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 z-50 min-w-[8rem] origin-(--radix-dropdown-menu-content-transform-origin) overflow-hidden rounded-[9px] border border-border-primary p-1 shadow-lg backdrop-blur-xl'"
  );
  write('src/components/ui/dropdown-menu.tsx', source);
}

function applySwitch() {
  let source = read('src/components/ui/switch.tsx');
  source = replaceRequired(
    source,
    'switch root geometry',
    "'peer inline-flex h-[16px] w-[28px] shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:cursor-not-allowed disabled:opacity-50'",
    "'peer inline-flex h-[22px] w-[38px] shrink-0 cursor-pointer items-center rounded-full border-0 transition-[background-color,box-shadow] duration-200 ease-[var(--epistemos-control-ease)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:cursor-not-allowed disabled:opacity-50'"
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
    "'flex h-auto justify-start rounded-[10px] bg-background-secondary/70 p-1 text-muted-foreground gap-1 backdrop-blur-xl'"
  );
  source = replaceRequired(
    source,
    'tabs trigger',
    "'flex items-center justify-start whitespace-nowrap rounded-[5px] px-3 py-1.5 text-xs font-mono ring-offset-background transition-all focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 data-[state=active]:bg-background-secondary data-[state=active]:text-text-primary data-[state=active]:shadow-none hover:bg-background-secondary hover:text-text-primary'",
    "'flex items-center justify-start whitespace-nowrap rounded-[7px] px-3 py-1.5 text-xs font-sans ring-offset-background transition-all duration-200 ease-[var(--epistemos-control-ease)] focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 data-[state=active]:bg-background-primary data-[state=active]:text-text-primary data-[state=active]:shadow-sm hover:bg-background-primary/80 hover:text-text-primary'"
  );
  write('src/components/ui/tabs.tsx', source);
}

function applySelect() {
  let source = read('src/components/ui/Select.tsx');
  source = replaceRequired(
    source,
    'select control',
    "`border ${isFocused ? 'border-border-primary' : 'border-border-primary'} focus:border-border-primary hover:border-border-primary rounded-md w-full px-4 py-2 text-sm text-text-secondary hover:cursor-pointer`",
    "`border ${isFocused ? 'border-[var(--epistemos-accent)]' : 'border-border-primary'} focus:border-[var(--epistemos-accent)] hover:border-border-tertiary rounded-[8px] w-full px-3 py-1.5 min-h-9 text-sm text-text-secondary bg-background-primary/70 shadow-none hover:cursor-pointer transition-all duration-200 ease-[var(--epistemos-control-ease)]`"
  );
  source = replaceRequired(
    source,
    'select menu',
    "'mt-1 bg-background-primary border border-border-primary rounded-[6px] text-text-secondary shadow-none select__menu z-[9999] absolute'",
    "'mt-1 bg-background-primary/85 border border-border-primary rounded-[9px] text-text-secondary shadow-lg select__menu z-[9999] absolute backdrop-blur-xl overflow-hidden'"
  );
  source = replaceRequired(
    source,
    'select option selected',
    "classes += ' bg-background-inverse text-text-inverse pointer-events-auto';",
    "classes += ' bg-[var(--epistemos-accent)] text-white pointer-events-auto';"
  );
  source = replaceRequired(
    source,
    'select option focused',
    "classes += ' bg-background-secondary text-text-primary pointer-events-auto';",
    "classes += ' bg-background-secondary/85 text-text-primary pointer-events-auto';"
  );
  write('src/components/ui/Select.tsx', source);
}

function applyAppSurfaces() {
  let source = read('src/App.tsx');
  source = replaceRequired(
    source,
    'transparent app root',
    'className="goose-epistemos relative w-screen h-screen overflow-hidden bg-background-secondary flex flex-col"',
    'className="goose-epistemos relative w-screen h-screen overflow-hidden bg-transparent flex flex-col"'
  );
  write('src/App.tsx', source);

  source = read('src/components/LauncherView.tsx');
  source = replaceRequired(
    source,
    'launcher frame',
    'className="relative flex h-full w-full flex-col overflow-hidden border border-border-primary bg-background-primary/95"',
    'className="relative flex h-full w-full flex-col overflow-hidden rounded-[22px] border border-border-primary bg-background-primary/70 shadow-[0_18px_48px_rgba(0,0,0,.14)] backdrop-blur-xl"'
  );
  source = replaceRequired(
    source,
    'launcher segmented control',
    'className="absolute left-1/2 top-4 z-10 flex -translate-x-1/2 items-center gap-1 border border-border-primary bg-background-primary/90 p-1"',
    'className="absolute left-1/2 top-4 z-10 flex -translate-x-1/2 items-center gap-1 rounded-[10px] border border-border-primary bg-background-secondary/70 p-1 shadow-sm backdrop-blur-xl"'
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
    "? 'bg-background-primary text-text-primary shadow-sm'"
  );
  source = replaceRequired(
    source,
    'launcher input card',
    'className="goose-chat-input-card flex h-14 items-center border border-border-primary bg-background-secondary"',
    'className="goose-chat-input-card flex h-14 items-center rounded-[14px] border border-border-primary bg-background-primary/76 shadow-[0_10px_32px_rgba(0,0,0,.10)] backdrop-blur-xl"'
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
    'className="mr-2 inline-grid h-9 w-9 place-items-center rounded-[10px] border border-transparent bg-[var(--epistemos-accent)] text-white transition-opacity disabled:cursor-not-allowed disabled:opacity-35"'
  );
  source = replaceRequired(
    source,
    'launcher launching card',
    'className="border border-border-primary bg-background-primary px-4 py-3 font-mono text-xs uppercase text-text-primary"',
    'className="rounded-[11px] border border-border-primary bg-background-primary/85 px-4 py-3 font-sans text-xs uppercase text-text-primary shadow-lg backdrop-blur-xl"'
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
    'className="relative flex-shrink-0 overflow-hidden h-full border-r border-border-secondary bg-background-secondary/62 backdrop-blur-xl"'
  );
  source = replaceRequired(
    source,
    'app layout nav toggle glass',
    'className="no-drag border border-border-secondary bg-background-primary/85 hover:!bg-background-tertiary"',
    'className="no-drag border border-border-secondary bg-background-primary/70 shadow-sm backdrop-blur-xl hover:!bg-background-tertiary/80"'
  );
  write('src/components/Layout/AppLayout.tsx', source);
}

function applyChatSurfaces() {
  let source = read('src/components/ChatInputCard.tsx');
  source = replaceRequired(
    source,
    'chat input native glass',
    "'goose-chat-input-card border border-border-primary overflow-hidden bg-background-primary'",
    "'goose-chat-input-card overflow-hidden rounded-[16px] border border-border-primary bg-background-primary/76 shadow-[0_18px_46px_rgba(0,0,0,.10)] backdrop-blur-xl'"
  );
  write('src/components/ChatInputCard.tsx', source);

  source = read('src/components/Hub.tsx');
  source = replaceRequired(
    source,
    'hub clock system font',
    'className="flex items-baseline gap-2 mb-1 font-mono"',
    'className="flex items-baseline gap-2 mb-1 font-sans"'
  );
  source = replaceRequired(
    source,
    'hub greeting native copy',
    'className="ep-pixel text-sm text-text-secondary mb-5 uppercase tracking-[0.06em]"',
    'className="text-[13px] font-medium text-text-secondary mb-5 tracking-normal"'
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
    "'goose-tool-call w-full text-sm font-sans rounded-[14px] overflow-hidden border bg-background-secondary/68 shadow-sm backdrop-blur-xl'"
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
    'className="mt-3 p-3 border border-border-primary rounded-[12px] bg-background-secondary/70 shadow-sm backdrop-blur-xl flex items-center"'
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
  write('src/components/ToolCallWithResponse.tsx', source);

  source = read('src/components/MentionPopover.tsx');
  source = replaceRequired(
    source,
    'mention popover native glass',
    'className="fixed z-50 bg-background-primary border border-border-primary rounded-[6px] shadow-none min-w-96 max-w-lg max-h-80"',
    'className="fixed z-50 bg-background-primary/88 border border-border-primary rounded-[14px] shadow-2xl backdrop-blur-xl min-w-96 max-w-lg max-h-80 overflow-hidden"'
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
      'className="bg-background-primary/58 px-6 pb-5 pt-14 border-b border-border-secondary backdrop-blur-xl"'
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
    'className="ep-native-header-band flex flex-col rounded-[16px] border border-border-secondary p-4 shadow-sm"'
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
    'ep-native-list-card rounded-[14px] group/card border'
  );
  source = replaceRequired(
    source,
    'provider card disabled fill',
    "? 'bg-background-secondary border-border-primary'",
    "? 'bg-background-secondary/56 border-border-secondary opacity-70'"
  );
  source = replaceRequired(
    source,
    'provider card enabled fill',
    ": 'bg-background-primary border-border-primary hover:border-primary'",
    ": 'bg-background-primary/64 border-border-secondary hover:border-[var(--epistemos-accent)] hover:bg-background-primary/78'"
  );
  source = replaceRequired(
    source,
    'provider card inner native surface',
    'relative bg-background-primary rounded-[6px] p-3 transition-colors duration-150 h-[160px] flex flex-col',
    'relative rounded-[14px] bg-transparent p-4 transition-all duration-200 ease-[var(--epistemos-control-ease)] min-h-[178px] flex flex-col'
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
    'className="ep-native-list-card mb-2 border p-2"'
  );
  write('src/components/skills/SkillsView.tsx', source);

  source = read('src/components/recipes/RecipesView.tsx');
  source = replaceRequired(
    source,
    'recipe item native card',
    'className="py-2 px-3 mb-2 bg-background-primary border border-border-secondary rounded-[6px] hover:bg-background-secondary transition-all duration-150"',
    'className="ep-native-list-card mb-2 border px-3 py-2 hover:bg-background-secondary/72"'
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
    'className="ep-native-list-card mb-2 border p-2"'
  );
  write('src/components/recipes/RecipesView.tsx', source);

  source = read('src/components/schedule/SchedulesView.tsx');
  source = replaceRequired(
    source,
    'schedule item native card',
    'className="py-2 px-3 mb-2 bg-background-primary border border-border-secondary rounded-[6px] hover:bg-background-secondary cursor-pointer transition-all duration-150"',
    'className="ep-native-list-card mb-2 cursor-pointer border px-3 py-2 hover:bg-background-secondary/72"'
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
    'className="mb-4 rounded-[12px] border border-border-danger bg-background-danger/72 p-4 backdrop-blur-xl"'
  );
  write('src/components/schedule/SchedulesView.tsx', source);

  source = read('src/components/apps/AppsView.tsx');
  source = replaceRequired(
    source,
    'app item native card',
    'className="flex flex-col p-3 border border-border-secondary rounded-[6px] hover:border-border-primary transition-colors bg-background-primary"',
    'className="ep-native-list-card flex flex-col border p-3 hover:border-[var(--epistemos-accent)]"'
  );
  source = replaceRequired(
    source,
    'app badge native chip',
    'className="inline-block px-2 py-1 text-xs bg-background-secondary text-text-secondary rounded-[4px] font-mono"',
    'className="ep-native-badge inline-block px-2 py-1 text-xs text-text-secondary"'
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
    'className="ep-native-screen-card w-[500px] max-w-[90vw] border p-4"'
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
    'className="w-full rounded-[8px] border border-border-primary bg-background-primary/70 p-3 text-sm font-sans text-text-primary outline-none transition-all focus:border-[var(--epistemos-accent)] focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20"'
  );
  source = replaceRequired(
    source,
    'session item native card',
    'className="h-full py-3 px-3 border border-border-secondary rounded-[6px] bg-background-primary hover:bg-background-secondary cursor-pointer transition-all duration-150 flex flex-col justify-between relative group"',
    'className="ep-native-list-card group relative flex h-full cursor-pointer flex-col justify-between border px-3 py-3 hover:bg-background-secondary/72"'
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
    'session group sticky native glass',
    'className="sticky top-0 z-10 bg-background-primary/95"',
    'className="ep-native-header-band sticky top-0 z-10 rounded-[10px] border border-border-secondary px-2 py-1 shadow-sm"'
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
    'className="min-h-28 w-full resize-none rounded-[9px] border border-border-primary bg-background-primary/70 p-3 text-sm font-sans text-text-primary outline-none focus:border-[var(--epistemos-accent)] focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20"'
  );
  source = replaceRequired(
    source,
    'session share code native panel',
    'className="relative rounded-[5px] border border-border-primary bg-background-secondary p-3 pr-12"',
    'className="relative rounded-[10px] border border-border-primary bg-background-secondary/70 p-3 pr-12 backdrop-blur-xl"'
  );
  write('src/components/sessions/SessionListView.tsx', source);
}

function applySearchSurfaces() {
  let source = read('src/components/conversation/SearchBar.tsx');
  source = replaceRequired(
    source,
    'search bar native glass',
    'className={`sticky top-0 bg-background-inverse text-text-inverse z-30 mb-4 ${',
    'className={`sticky top-0 z-30 mb-4 rounded-[12px] border border-border-secondary bg-background-primary/82 text-text-primary shadow-sm backdrop-blur-xl ${'
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
                      placeholder:text-text-inverse/50 focus:outline-none 
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
    "? 'bg-[var(--epistemos-accent)]/14 text-text-primary shadow-sm hover:bg-[var(--epistemos-accent)]/18'"
  );
  write('src/components/conversation/SearchBar.tsx', source);
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
    'className="ep-native-screen-card flex items-center justify-end gap-2 border px-3 py-2"'
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
    'className="ep-native-error-card flex max-w-[620px] flex-col items-center gap-4 border px-6 py-7 text-center"'
  );
  source = replaceRequired(
    source,
    'error boundary native icon',
    'className="w-12 h-12 bg-destructive/10 border border-border-primary flex items-center justify-center mb-2"',
    'className="ep-native-error-icon mb-2 flex h-12 w-12 items-center justify-center border"'
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
    'className="w-full overflow-auto whitespace-pre-wrap rounded-[12px] border border-border bg-background-secondary/72 p-4 text-left text-sm text-destructive backdrop-blur-xl dark:text-white"'
  );
  write('src/components/ErrorBoundary.tsx', source);
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
applyAppSurfaces();
applyChatSurfaces();
applyToolAndPopoverSurfaces();
applyCatalogSurfaces();
applyProviderCatalogSurfaces();
applyUtilityListSurfaces();
applySessionListSurfaces();
applySearchSurfaces();
applyLoadingAndErrorSurfaces();

console.log(`Applied Goose native reskin overlay: ${desktopRoot}`);
