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
    'className="mb-4 inline-flex h-10 w-10 items-center justify-center rounded-[12px] border border-border-success bg-background-success/55 shadow-sm backdrop-blur-xl"'
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
    'className="mb-6 w-full rounded-[12px] border border-border-secondary bg-background-primary/68 p-4 text-left shadow-sm backdrop-blur-xl"'
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
    'local model picker back button native',
    'className="w-full px-3 py-2.5 text-text-primary text-sm font-medium border border-border-primary rounded-[6px] hover:bg-background-secondary transition-colors cursor-pointer"',
    'className="w-full cursor-pointer rounded-[8px] border border-border-secondary bg-background-primary/60 px-3 py-2.5 text-sm font-medium text-text-primary transition-colors hover:bg-background-secondary/72"'
  );
  source = replaceRequired(
    source,
    'local model picker download card native',
    'className="border border-border-primary rounded-[6px] p-3 bg-background-default"',
    'className="rounded-[10px] border border-border-secondary bg-background-primary/68 p-3 shadow-sm backdrop-blur-xl"'
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
    'className="h-11 w-full rounded-[8px] border border-border-secondary bg-background-primary/55 text-md font-medium text-text-primary hover:bg-background-secondary/75"'
  );
  write('src/components/settings/providers/modal/ProviderConfigurationModal.tsx', source);

  source = read('src/components/settings/providers/modal/subcomponents/ProviderLogo.tsx');
  source = replaceRequired(
    source,
    'provider modal logo native well',
    'className="w-12 h-12 bg-background-secondary border border-border-primary rounded-[6px] overflow-hidden flex items-center justify-center"',
    'className="flex h-12 w-12 items-center justify-center overflow-hidden rounded-[14px] border border-border-primary bg-background-secondary/70 shadow-sm backdrop-blur-xl"'
  );
  write('src/components/settings/providers/modal/subcomponents/ProviderLogo.tsx', source);

  source = read('src/components/settings/providers/modal/subcomponents/ProviderSetupActions.tsx');
  source = replaceRequired(
    source,
    'provider active delete warning panel native',
    'className="w-full px-6 py-4 bg-yellow-600/20 border-t border-yellow-500/30"',
    'className="w-full rounded-[12px] border border-border-warning bg-background-warning/72 px-6 py-4 backdrop-blur-xl"'
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
    'className="w-full rounded-[12px] border border-border-danger bg-background-danger/72 px-6 py-4 backdrop-blur-xl"'
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
    'className="h-11 w-full rounded-[8px] border border-border-danger bg-background-danger/45 text-md font-medium text-text-danger hover:bg-background-danger/72"'
  );
  source = replaceRequired(
    source,
    'provider modal delete action native',
    'className="w-full h-[60px] rounded-none border-t border-border-primary bg-transparent hover:bg-background-secondary text-red-500 font-medium text-md"',
    'className="h-11 w-full rounded-[8px] border border-border-danger bg-transparent text-md font-medium text-text-danger hover:bg-background-danger/45"'
  );
  source = replaceAllRequired(
    source,
    'provider modal submit action native',
    'className="w-full h-[60px] rounded-none border-t border-border-primary text-md hover:bg-background-secondary text-text-primary font-medium"',
    'className="h-11 w-full rounded-[8px] border border-border-secondary bg-background-primary/55 text-md font-medium text-text-primary hover:bg-background-secondary/75"'
  );
  source = replaceAllRequired(
    source,
    'provider modal cancel action native',
    'className="w-full h-[60px] rounded-none border-t border-border-primary hover:text-text-primary text-text-secondary hover:bg-background-secondary text-md font-regular"',
    'className="h-11 w-full rounded-[8px] border border-border-secondary text-md font-regular text-text-secondary hover:bg-background-secondary/75 hover:text-text-primary"'
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
    '} bg-background-primary/70 text-lg placeholder:text-text-secondary font-regular text-text-primary transition-all focus:border-[var(--epistemos-accent)] focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20`}'
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
    "? 'border-2 border-border-danger ring-[3px] ring-text-danger/15'"
  );
  source = replaceRequired(
    source,
    'default provider setup normal border native',
    ": 'border border-border-primary hover:border-border-primary'",
    ": 'border border-border-secondary hover:border-[var(--epistemos-accent)]'"
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
    'className="my-4 rounded-[10px] border border-dashed border-border-secondary bg-background-primary/55 shadow-sm backdrop-blur-xl"'
  );
  write('src/components/settings/providers/modal/subcomponents/forms/DefaultProviderSetupForm.tsx', source);

  source = read('src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx');
  source = replaceAllRequired(
    source,
    'custom provider choice cards native',
    'className="w-full p-4 text-left border border-border rounded-lg hover:bg-surfaceHover hover:border-primary transition-colors group"',
    'className="w-full rounded-[10px] border border-border-secondary bg-background-primary/68 p-4 text-left shadow-sm backdrop-blur-xl transition-colors hover:border-[var(--epistemos-accent)] hover:bg-background-secondary/62 group"'
  );
  source = replaceRequired(
    source,
    'custom provider template banner native',
    'className="p-3 bg-surfaceHover border border-border rounded-lg"',
    'className="rounded-[10px] border border-border-secondary bg-background-primary/68 p-3 shadow-sm backdrop-blur-xl"'
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
    'className="flex h-9 min-w-[60px] items-center justify-start gap-1 rounded-[8px] border border-borderSubtle bg-background-primary/70 px-2 pr-4 text-sm text-textStandard transition-colors hover:border-[var(--epistemos-accent)] hover:bg-background-secondary/75 [&>svg]:!size-4"'
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
    'className="rounded-[10px] border border-border-warning bg-background-warning/55 px-4 py-3"'
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
    'className="rounded-[10px] border border-border-danger bg-background-danger/55 px-4 py-3"'
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
    'className="mr-auto rounded-[8px] border-border-danger bg-background-danger/35 text-text-danger hover:bg-background-danger/65 hover:text-text-danger"'
  );
  write('src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx', source);

  source = read('src/components/settings/providers/modal/subcomponents/ProviderCatalogPicker.tsx');
  source = replaceRequired(
    source,
    'provider catalog picker row native',
    'className="w-full p-4 text-left border border-border rounded-lg hover:bg-surfaceHover hover:border-primary transition-colors group"',
    'className="w-full rounded-[10px] border border-border-secondary bg-background-primary/68 p-4 text-left shadow-sm backdrop-blur-xl transition-colors hover:border-[var(--epistemos-accent)] hover:bg-background-secondary/62 group"'
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
    'className="rounded-[12px] border border-border-primary bg-background-secondary/72 p-4 shadow-sm backdrop-blur-xl"'
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
    'className="border-t border-border-secondary/70"'
  );
  source = replaceRequired(
    source,
    'extension remove button native danger',
    'className="text-red-500 hover:text-red-600"',
    'className="border-border-danger bg-background-danger/35 text-text-danger hover:bg-background-danger/65 hover:text-text-danger"'
  );
  write('src/components/settings/extensions/modal/ExtensionModal.tsx', source);

  source = read('src/components/settings/extensions/modal/EnvVarsSection.tsx');
  source = replaceAllRequired(
    source,
    'env vars input native focus',
    "'w-full text-text-primary border-border-primary hover:border-border-primary'",
    "'w-full border-border-primary bg-background-primary/70 text-text-primary hover:border-border-tertiary focus:border-[var(--epistemos-accent)] focus-visible:ring-[3px] focus-visible:ring-[var(--epistemos-accent)]/20'"
  );
  source = replaceAllRequired(
    source,
    'env vars invalid token',
    "'border-red-500 focus:border-red-500'",
    "'border-border-danger focus:border-border-danger focus-visible:ring-text-danger/20'"
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
    'className="flex h-9 min-w-[60px] items-center justify-start gap-1 rounded-[8px] border border-border-secondary bg-background-primary/70 px-2 pr-4 text-sm text-text-primary transition-all hover:border-[var(--epistemos-accent)] hover:bg-background-secondary/75 [&>svg]:!size-4"'
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
    "'w-full border-border-primary bg-background-primary/70 text-text-primary hover:border-border-tertiary focus:border-[var(--epistemos-accent)] focus-visible:ring-[3px] focus-visible:ring-[var(--epistemos-accent)]/20'"
  );
  source = replaceAllRequired(
    source,
    'headers invalid token',
    "'border-red-500 focus:border-red-500'",
    "'border-border-danger focus:border-border-danger focus-visible:ring-text-danger/20'"
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
    'className="flex h-9 min-w-[60px] items-center justify-start gap-1 rounded-[8px] border border-border-secondary bg-background-primary/70 px-2 pr-4 text-sm text-text-primary transition-all hover:border-[var(--epistemos-accent)] hover:bg-background-secondary/75 [&>svg]:!size-4"'
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
    "className={`w-full bg-background-primary/70 text-text-primary focus:border-[var(--epistemos-accent)] focus-visible:ring-[3px] focus-visible:ring-[var(--epistemos-accent)]/20 ${!submitAttempted || isValid ? 'border-border-primary' : 'border-border-danger focus:border-border-danger'}`}"
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
    "className={`bg-background-primary/70 text-text-primary focus:border-[var(--epistemos-accent)] focus-visible:ring-[3px] focus-visible:ring-[var(--epistemos-accent)]/20 ${!submitAttempted || isNameValid() ? 'border-border-primary' : 'border-border-danger focus:border-border-danger'}`}"
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
    'className={`bg-background-primary/70 text-text-primary focus:border-[var(--epistemos-accent)] focus-visible:ring-[3px] focus-visible:ring-[var(--epistemos-accent)]/20`}'
  );
  write('src/components/settings/extensions/modal/ExtensionInfoFields.tsx', source);

  source = read('src/components/settings/extensions/modal/ExtensionTimeoutField.tsx');
  source = replaceRequired(
    source,
    'extension timeout input native',
    "className={`${!submitAttempted || isTimeoutValid() ? 'border-border-primary' : 'border-red-500'} text-text-primary focus:border-border-primary`}",
    "className={`bg-background-primary/70 text-text-primary focus:border-[var(--epistemos-accent)] focus-visible:ring-[3px] focus-visible:ring-[var(--epistemos-accent)]/20 ${!submitAttempted || isTimeoutValid() ? 'border-border-primary' : 'border-border-danger focus:border-border-danger'}`}"
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
    'className="rounded-[12px] border border-border-secondary bg-background-secondary/55 py-8 text-center text-text-secondary backdrop-blur-xl"'
  );
  write('src/components/settings/extensions/subcomponents/ExtensionList.tsx', source);

  source = read('src/components/settings/extensions/subcomponents/ExtensionItem.tsx');
  source = replaceRequired(
    source,
    'extension item card native glass',
    'className="transition-all duration-200 min-h-[120px] overflow-hidden"',
    'className="min-h-[128px] overflow-hidden border-border-secondary bg-background-primary/68 shadow-sm backdrop-blur-xl transition-all duration-200 ease-[var(--epistemos-control-ease)] hover:border-[var(--epistemos-accent)]/45 hover:bg-background-secondary/62"'
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
    'className="border-border-secondary bg-background-primary/68 pb-2 shadow-sm backdrop-blur-xl"'
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
    'className="flex items-center justify-between rounded-[9px] border border-transparent px-3 py-2.5 transition-all duration-200 ease-[var(--epistemos-control-ease)] hover:border-border-secondary hover:bg-background-secondary/65"'
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
    "className={`flex items-center justify-between rounded-[9px] border px-3 py-2.5 text-text-primary transition-all duration-200 ease-[var(--epistemos-control-ease)] ${checked ? 'border-border-secondary bg-background-secondary/78 shadow-sm ring-[1px] ring-[var(--epistemos-accent)]/25' : 'border-transparent bg-transparent hover:border-border-secondary hover:bg-background-secondary/55'}`}"
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
    `className="h-4 w-4 rounded-full border border-border-primary 
                    peer-checked:border-[6px] peer-checked:border-black dark:peer-checked:border-white
                    peer-checked:bg-white dark:peer-checked:bg-black
                    transition-all duration-200 ease-in-out group-hover:border-border-primary"`,
    `className="h-[18px] w-[18px] rounded-full border border-border-secondary bg-background-primary/70 shadow-inner
                    transition-all duration-200 ease-[var(--epistemos-control-ease)] group-hover:border-[var(--epistemos-accent)]
                    peer-checked:border-[5px] peer-checked:border-[var(--epistemos-accent)] peer-checked:bg-background-primary"`
  );
  write('src/components/settings/mode/ModeSelectionItem.tsx', source);

  source = read('src/components/settings/mode/ConversationLimitsDropdown.tsx');
  source = replaceRequired(
    source,
    'conversation limits disclosure native',
    'className="w-full flex items-center justify-between py-2 px-2 hover:bg-background-secondary rounded-[5px] transition-all group"',
    'className="group flex w-full items-center justify-between rounded-[9px] border border-transparent px-3 py-2.5 transition-all duration-200 ease-[var(--epistemos-control-ease)] hover:border-border-secondary hover:bg-background-secondary/60"'
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
    'className="flex items-center justify-between rounded-[9px] border border-border-secondary bg-background-secondary/60 px-3 py-2.5 shadow-sm backdrop-blur-xl transition-all duration-200 ease-[var(--epistemos-control-ease)]"'
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
    'className="fixed inset-0 bg-black/24 backdrop-blur-sm"'
  );
  source = replaceRequired(
    source,
    'approve mode card native glass',
    'className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[440px] bg-background-primary rounded-[6px] overflow-hidden p-[16px] pt-[24px] pb-0 border border-border-primary shadow-none"',
    'className="fixed left-1/2 top-1/2 w-[440px] -translate-x-1/2 -translate-y-1/2 overflow-hidden rounded-[14px] border border-border-primary bg-background-primary/88 p-[16px] pt-[24px] pb-0 shadow-2xl backdrop-blur-xl"'
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
    'className="h-11 w-full rounded-[8px] border border-border-secondary bg-background-primary/65 text-base font-medium text-text-primary hover:bg-background-secondary/75"'
  );
  source = replaceRequired(
    source,
    'approve mode cancel button native',
    'className="w-full h-[60px] rounded-none border-t border-border-primary text-text-secondary hover:bg-background-secondary dark:border-gray-600 text-base font-regular"',
    'className="h-11 w-full rounded-[8px] border border-border-secondary text-base font-regular text-text-secondary hover:bg-background-secondary/75 hover:text-text-primary"'
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
    "className={`flex items-center justify-between rounded-[9px] border px-3 py-2.5 text-text-primary transition-all duration-200 ease-[var(--epistemos-control-ease)] ${checked ? 'border-border-secondary bg-background-secondary/78 shadow-sm ring-[1px] ring-[var(--epistemos-accent)]/25' : 'border-transparent bg-transparent hover:border-border-secondary hover:bg-background-secondary/55'}`}"
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
    `className="h-[18px] w-[18px] rounded-full border border-border-secondary bg-background-primary/70 shadow-inner
                  transition-all duration-200 ease-[var(--epistemos-control-ease)] group-hover:border-[var(--epistemos-accent)]
                  peer-checked:border-[5px] peer-checked:border-[var(--epistemos-accent)] peer-checked:bg-background-primary"`
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
    'className="flex flex-col items-center justify-center rounded-[12px] border border-border-secondary bg-background-secondary/55 px-6 py-8 text-center backdrop-blur-xl"'
  );
  source = replaceRequired(
    source,
    'permission modal tool row native',
    'className="flex items-center justify-between grid grid-cols-12"',
    'className="grid grid-cols-12 items-center gap-3 rounded-[10px] border border-border-secondary bg-background-secondary/45 px-3 py-2.5 shadow-sm backdrop-blur-xl"'
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
    'className="flex h-auto w-full items-center justify-between gap-2 rounded-[11px] border border-border-secondary bg-background-primary/65 px-4 py-3 text-left shadow-sm backdrop-blur-xl hover:bg-background-secondary/70"'
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
    'className="flex h-12 w-12 items-center justify-center rounded-[14px] border border-border-secondary bg-background-secondary/72 shadow-sm backdrop-blur-xl"'
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
    'className="flex h-auto w-full items-center justify-between gap-2 rounded-[11px] border border-border-secondary bg-background-primary/65 px-4 py-3 text-left shadow-sm backdrop-blur-xl hover:bg-background-secondary/70"'
  );
  source = replaceRequired(
    source,
    'permission settings header icon native well',
    'className="rounded-[6px] bg-background-inverse w-12 h-12 flex items-center justify-center mb-4"',
    'className="mb-4 flex h-12 w-12 items-center justify-center rounded-[14px] border border-border-secondary bg-background-secondary/72 shadow-sm backdrop-blur-xl"'
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
    'settings header native glass',
    'className="bg-background-primary/58 px-6 pb-5 pt-14 border-b border-border-secondary backdrop-blur-xl"',
    'className="border-b border-border-secondary bg-background-primary/58 px-6 pb-5 pt-14 backdrop-blur-xl"'
  );
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
    'className="border-border-secondary bg-background-primary/68 shadow-sm backdrop-blur-xl"'
  );
  source = replaceAllRequired(
    source,
    'app settings rows native hover',
    'className="flex items-center justify-between"',
    'className="flex items-center justify-between rounded-[9px] border border-transparent px-3 py-2.5 transition-all hover:border-border-secondary hover:bg-background-secondary/60"'
  );
  source = replaceRequired(
    source,
    'app settings language trigger native',
    'className="flex w-full max-w-[260px] items-center justify-between gap-2 rounded-md border border-border-primary bg-background-primary px-3 py-2 text-sm text-text-primary transition-colors hover:border-border-primary"',
    'className="flex w-full max-w-[260px] items-center justify-between gap-2 rounded-[8px] border border-border-primary bg-background-primary/70 px-3 py-2 text-sm text-text-primary shadow-sm transition-all hover:border-[var(--epistemos-accent)] hover:bg-background-secondary/70"'
  );
  source = replaceRequired(
    source,
    'app settings version badge native',
    'className="flex h-8 w-8 items-center justify-center border border-border-primary bg-background-secondary font-mono text-sm text-text-primary"',
    'className="flex h-8 w-8 items-center justify-center rounded-[8px] border border-border-secondary bg-background-secondary/72 font-sans text-sm font-semibold text-text-primary shadow-sm"'
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
    'className="flex items-center justify-between rounded-[9px] border border-transparent px-3 py-2.5 transition-all hover:border-border-secondary hover:bg-background-secondary/60"'
  );
  source = replaceRequired(
    source,
    'telemetry card native glass',
    'className="rounded-[6px]"',
    'className="border-border-secondary bg-background-primary/68 shadow-sm backdrop-blur-xl"'
  );
  write('src/components/settings/app/TelemetrySettings.tsx', source);

  source = read('src/components/settings/config/ConfigSettings.tsx');
  source = replaceRequired(
    source,
    'config settings card native glass',
    'className="rounded-lg"',
    'className="border-border-secondary bg-background-primary/68 shadow-sm backdrop-blur-xl"'
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
    'className="grid grid-cols-[200px_1fr_auto] items-center gap-3 rounded-[10px] border border-border-secondary bg-background-secondary/45 px-3 py-2.5"'
  );
  source = replaceRequired(
    source,
    'config input native',
    "'text-text-primary border-border-primary hover:border-border-primary transition-colors'",
    "'border-border-primary bg-background-primary/70 text-text-primary transition-all hover:border-border-tertiary focus:border-[var(--epistemos-accent)] focus-visible:ring-[3px] focus-visible:ring-[var(--epistemos-accent)]/20'"
  );
  source = replaceRequired(
    source,
    'config modified input accent',
    "modifiedKeys.has(key) && 'border-blue-500 focus:ring-blue-500/20'",
    "modifiedKeys.has(key) && 'border-[var(--epistemos-accent)] focus:ring-[var(--epistemos-accent)]/20'"
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
    'className="border-border-secondary bg-background-primary/68 pb-2 shadow-sm backdrop-blur-xl"'
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
    'className="rounded-[10px] border border-border-secondary bg-background-secondary/60 p-3 text-sm text-text-secondary backdrop-blur-xl"'
  );
  source = replaceRequired(
    source,
    'prompt textarea native',
    'className="w-full flex-1 min-h-[500px] border rounded-md p-3 text-sm font-mono resize-y bg-background-primary text-text-primary border-border-primary focus:outline-none focus:ring-2 focus:ring-blue-500"',
    'className="min-h-[500px] w-full flex-1 resize-y rounded-[10px] border border-border-primary bg-background-primary/70 p-3 font-mono text-sm text-text-primary transition-all focus:border-[var(--epistemos-accent)] focus:outline-none focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20"'
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
    'className="border-border-warning bg-background-warning/55 pb-2 shadow-sm backdrop-blur-xl"'
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
    'className="flex items-center gap-2 border-border-warning text-text-warning hover:bg-background-warning/70"'
  );
  source = replaceRequired(
    source,
    'prompt row native glass',
    'className="flex items-center justify-between p-3 rounded-lg border border-border-primary hover:bg-background-secondary transition-colors"',
    'className="flex items-center justify-between rounded-[10px] border border-border-secondary bg-background-primary/55 p-3 shadow-sm transition-all hover:bg-background-secondary/70"'
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
    'className="border-border-secondary bg-background-primary/68 p-3 pb-4 shadow-sm backdrop-blur-xl"'
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
    'className="border-border-secondary bg-background-primary/68 pb-2 shadow-sm backdrop-blur-xl"'
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
    'className="rounded-[10px] border border-border-danger bg-background-danger/35 p-3"'
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
    'className="flex h-8 min-w-0 max-w-[180px] items-center rounded-[8px] border border-transparent bg-background-primary/45 px-2 text-text-primary/75 transition-all hover:cursor-pointer hover:border-border-secondary hover:bg-background-secondary/65 hover:text-text-primary md:max-w-[200px] lg:max-w-[380px]"'
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
    'className="fixed inset-0 z-50 flex items-center justify-center bg-black/24 backdrop-blur-sm"'
  );
  source = replaceRequired(
    source,
    'model bottom local modal native',
    'className="bg-background-primary border border-border-primary rounded-[6px] shadow-none w-[480px] max-h-[80vh] flex flex-col"',
    'className="flex max-h-[80vh] w-[480px] flex-col rounded-[14px] border border-border-primary bg-background-primary/88 shadow-2xl backdrop-blur-xl"'
  );
  source = replaceRequired(
    source,
    'model bottom local modal header native',
    'className="flex items-center justify-between px-4 py-3 border-b border-border-subtle"',
    'className="flex items-center justify-between border-b border-border-secondary bg-background-primary/45 px-4 py-3 backdrop-blur-xl"'
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
    "className={`flex items-center justify-between rounded-[10px] border px-3 py-2.5 text-text-primary transition-all duration-200 ease-[var(--epistemos-control-ease)] ${\n                        selectedPredefinedModel?.name === model.name\n                          ? 'border-border-secondary bg-background-secondary/78 shadow-sm ring-[1px] ring-[var(--epistemos-accent)]/25'\n                          : 'border-transparent bg-transparent hover:border-border-secondary hover:bg-background-secondary/55'\n                      }`}"
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
    `className="h-[18px] w-[18px] rounded-full border border-border-secondary bg-background-primary/70 shadow-inner
                                transition-all duration-200 ease-[var(--epistemos-control-ease)] group-hover:border-[var(--epistemos-accent)]
                                peer-checked:border-[5px] peer-checked:border-[var(--epistemos-accent)] peer-checked:bg-background-primary"`
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
    'className="rounded-[12px] border border-border-secondary bg-background-secondary/60 p-4 backdrop-blur-xl"'
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
    'className="self-start border-border-secondary bg-background-primary/60 text-text-primary hover:border-[var(--epistemos-accent)] hover:bg-background-secondary/75"'
  );
  source = replaceAllRequired(
    source,
    'switch model warning panel native',
    'className="rounded-md bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 p-3',
    'className="rounded-[12px] border border-border-warning bg-background-warning/55 p-3'
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
    'className="bg-background-primary/70 px-4 py-5 focus:border-[var(--epistemos-accent)] focus-visible:ring-[3px] focus-visible:ring-[var(--epistemos-accent)]/20"'
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
    'min-h-9 rounded-[8px] border px-3 py-2 font-mono text-xs transition-all duration-200 ease-[var(--epistemos-control-ease)]'
  );
  source = replaceRequired(
    source,
    'shortcut recorder recording state native',
    "? 'bg-background-primary ring-1'",
    "? 'border-[var(--epistemos-accent)] bg-background-primary/70 ring-[3px] ring-[var(--epistemos-accent)]/20'"
  );
  source = replaceRequired(
    source,
    'shortcut recorder conflict state native',
    "? 'bg-background-secondary border-yellow-600/50'",
    "? 'border-border-warning bg-background-warning/55 text-text-warning'"
  );
  source = replaceRequired(
    source,
    'shortcut recorder idle state native',
    ": 'bg-background-secondary border-border-primary cursor-pointer'",
    ": 'border-border-secondary bg-background-secondary/60 cursor-pointer hover:border-[var(--epistemos-accent)]'"
  );
  source = replaceRequired(
    source,
    'shortcut recorder focus native',
    'focus:outline-none focus:ring-1',
    'focus:outline-none focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20'
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
    'className="border-border-warning bg-background-warning/55 shadow-sm backdrop-blur-xl"'
  );
  source = replaceAllRequired(
    source,
    'keyboard cards native glass',
    'className="rounded-lg"',
    'className="border-border-secondary bg-background-primary/68 shadow-sm backdrop-blur-xl"'
  );
  source = replaceAllRequired(
    source,
    'keyboard rows native hover',
    'className="flex items-center justify-between"',
    'className="flex items-center justify-between rounded-[9px] border border-transparent px-3 py-2.5 transition-all hover:border-border-secondary hover:bg-background-secondary/60"'
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
    "return 'border-border-danger bg-background-danger/55 text-text-danger';"
  );
  source = replaceRequired(
    source,
    'auth valid badge native token',
    "return 'border-green-500/30 bg-green-500/10 text-green-700 dark:text-green-300';",
    "return 'border-border-success bg-background-success/55 text-text-success';"
  );
  source = replaceRequired(
    source,
    'auth card native glass',
    '<Card className="pb-2">',
    '<Card className="border-border-secondary bg-background-primary/68 pb-2 shadow-sm backdrop-blur-xl">'
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
    'className="flex flex-col gap-3 rounded-[10px] border border-transparent px-3 py-3 transition-all hover:border-border-secondary hover:bg-background-secondary/60 sm:flex-row sm:items-center sm:justify-between"'
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
    'className={`flex flex-col gap-3 rounded-[10px] border border-border-secondary bg-background-primary/68 p-3 shadow-sm backdrop-blur-xl sm:flex-row sm:items-center sm:justify-between ${className ?? \'\'}`}'
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
    'className="rounded-[10px] border border-border-secondary bg-background-primary/68 p-3 shadow-sm backdrop-blur-xl"'
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
    'className={`rounded-[10px] border p-3 shadow-sm backdrop-blur-xl transition-colors ${'
  );
  source = replaceRequired(
    source,
    'local selected card native',
    "? 'border-accent-primary bg-accent-primary/5'",
    "? 'border-[var(--epistemos-accent)] bg-background-primary/78 ring-[3px] ring-[var(--epistemos-accent)]/20'"
  );
  source = replaceRequired(
    source,
    'local unselected card native',
    ": 'border-border-subtle bg-background-default hover:border-border-default'",
    ": 'border-border-secondary bg-background-primary/68 hover:border-[var(--epistemos-accent)] hover:bg-background-secondary/62'"
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
    'className="rounded-[10px] border border-border-secondary bg-background-primary/68 p-3 shadow-sm backdrop-blur-xl transition-colors hover:border-[var(--epistemos-accent)] hover:bg-background-secondary/62"'
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
    '<div className="border-t border-border-secondary pt-5">'
  );
  source = replaceRequired(
    source,
    'local settings dialog native',
    '<DialogContent className="max-h-[80vh] overflow-y-auto sm:max-w-xl">',
    '<DialogContent className="max-h-[80vh] overflow-y-auto border-border-secondary bg-background-primary/82 shadow-lg backdrop-blur-xl sm:max-w-xl">'
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
    'className="min-h-9 w-full rounded-[9px] border border-border-secondary bg-background-primary/68 py-2 pl-9 pr-4 text-sm text-text-primary placeholder:text-text-secondary transition-all duration-200 ease-[var(--epistemos-control-ease)] focus:border-[var(--epistemos-accent)] focus:outline-none focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20"'
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
    'className="rounded-[10px] border border-border-secondary bg-background-primary/68 shadow-sm backdrop-blur-xl"'
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
    'className="space-y-1 border-t border-border-secondary px-3 pb-3 pt-2"'
  );
  source = replaceRequired(
    source,
    'hf variant row base native',
    'className={`flex items-center justify-between py-2 px-2 rounded ${',
    'className={`flex items-center justify-between rounded-[9px] border px-2 py-2 transition-colors ${'
  );
  source = replaceRequired(
    source,
    'hf downloaded variant native',
    "? 'bg-green-500/5 border border-green-500/20'",
    "? 'border-border-success bg-background-success/55'"
  );
  source = replaceRequired(
    source,
    'hf recommended variant native',
    "? 'bg-blue-500/5 border border-blue-500/20'",
    "? 'border-[var(--epistemos-accent)] bg-background-primary/78'"
  );
  source = replaceRequired(
    source,
    'hf neutral variant native',
    ": 'hover:bg-background-subtle'",
    ": 'border-transparent hover:border-border-secondary hover:bg-background-secondary/60'"
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
    'className="min-h-8 w-full rounded-[8px] border border-border-secondary bg-background-primary/68 px-2 py-1 text-sm text-text-primary transition-all focus:border-[var(--epistemos-accent)] focus:outline-none focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20"'
  );
  source = replaceAllRequired(
    source,
    'local settings compact rows native',
    'className="flex items-center justify-between gap-2"',
    'className="flex items-center justify-between gap-2 rounded-[9px] border border-transparent px-2 py-2 transition-colors hover:border-border-secondary hover:bg-background-secondary/60"'
  );
  source = replaceRequired(
    source,
    'local select field native',
    'className="rounded border border-border-subtle bg-background-default px-2 py-1 text-xs text-text-default"',
    'className="min-h-8 rounded-[8px] border border-border-secondary bg-background-primary/68 px-2 py-1 text-xs text-text-primary transition-all focus:border-[var(--epistemos-accent)] focus:outline-none focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20"'
  );
  source = replaceRequired(
    source,
    'local textarea field native',
    'className="min-h-32 rounded border border-border-subtle bg-background-default px-2 py-1 font-mono text-xs text-text-default"',
    'className="min-h-32 rounded-[8px] border border-border-secondary bg-background-primary/68 px-2 py-1 font-mono text-xs text-text-primary transition-all focus:border-[var(--epistemos-accent)] focus:outline-none focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20"'
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
    'className="mb-4 rounded-[10px] border border-border-danger bg-background-danger/55 p-3 text-sm text-text-danger"'
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
    'className="flex items-center justify-between rounded-[9px] border border-border-secondary bg-background-primary/68 px-2 py-1.5 text-sm"'
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
    '<Card className="border-border-secondary bg-background-primary/68 shadow-sm backdrop-blur-xl">'
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
    '<DialogContent className="border-border-secondary bg-background-primary/82 shadow-lg backdrop-blur-xl sm:max-w-[400px]">'
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
    'className="flex items-center justify-between rounded-[9px] border border-transparent px-2 py-2 transition-all hover:border-border-secondary hover:bg-background-secondary/60"'
  );
  source = replaceRequired(
    source,
    'dictation provider dropdown native',
    'className="flex items-center gap-2 px-3 py-1.5 text-sm border border-border-primary rounded-md hover:border-border-primary transition-colors text-text-primary bg-background-primary"',
    'className="flex min-h-9 items-center gap-2 rounded-[8px] border border-border-secondary bg-background-primary/68 px-3 py-1.5 text-sm text-text-primary transition-colors hover:border-[var(--epistemos-accent)]"'
  );
  source = replaceAllRequired(
    source,
    'dictation config panels native',
    'className="py-2 px-2 bg-background-secondary rounded-lg"',
    'className="rounded-[10px] border border-border-secondary bg-background-primary/68 px-2 py-2 shadow-sm backdrop-blur-xl"'
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
    'className="flex items-center justify-between rounded-[9px] border border-transparent px-2 py-2 transition-all hover:border-border-secondary hover:bg-background-secondary/60"'
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
    'className="flex min-h-9 max-w-[220px] items-center gap-2 rounded-[8px] border border-border-secondary bg-background-primary/68 px-3 py-1.5 text-sm text-text-primary transition-colors hover:border-[var(--epistemos-accent)]"'
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
    'className={`rounded-[10px] border p-3 shadow-sm backdrop-blur-xl transition-colors ${'
  );
  source = replaceRequired(
    source,
    'dictation local model selected native',
    "? 'border-text-inverse bg-background-inverse/5'",
    "? 'border-[var(--epistemos-accent)] bg-background-primary/78 ring-[3px] ring-[var(--epistemos-accent)]/20'"
  );
  source = replaceRequired(
    source,
    'dictation local model unselected native',
    ": 'border-border-primary bg-background-primary hover:border-border-primary'",
    ": 'border-border-secondary bg-background-primary/68 hover:border-[var(--epistemos-accent)] hover:bg-background-secondary/62'"
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
    'className={`min-h-9 w-full rounded-[8px] border px-3 py-2 text-sm placeholder:text-text-secondary transition-all focus:border-[var(--epistemos-accent)] focus:outline-none focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20 ${'
  );
  source = replaceRequired(
    source,
    'security threshold input native base',
    'className={`w-24 px-2 py-1 text-sm border rounded ${',
    'className={`min-h-8 w-24 rounded-[8px] border px-2 py-1 text-sm transition-all focus:border-[var(--epistemos-accent)] focus:outline-none focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20 ${'
  );
  source = replaceRequired(
    source,
    'security model select native base',
    'className={`w-full px-3 py-2 text-sm border rounded ${',
    'className={`min-h-9 w-full rounded-[8px] border px-3 py-2 text-sm transition-all focus:border-[var(--epistemos-accent)] focus:outline-none focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20 ${'
  );
  source = replaceAllRequired(
    source,
    'security enabled field state native',
    "? 'border-border-primary bg-background-primary text-text-primary'",
    "? 'border-border-secondary bg-background-primary/68 text-text-primary'"
  );
  source = replaceAllRequired(
    source,
    'security disabled field state native',
    ": 'border-border-primary bg-background-secondary text-text-secondary cursor-not-allowed'",
    ": 'border-border-secondary bg-background-secondary/60 text-text-secondary cursor-not-allowed'"
  );
  source = replaceRequired(
    source,
    'security main row native',
    'className="flex items-center justify-between py-2 px-2 hover:bg-background-secondary rounded-lg transition-all"',
    'className="flex items-center justify-between rounded-[9px] border border-transparent px-2 py-2 transition-all hover:border-border-secondary hover:bg-background-secondary/60"'
  );
  source = replaceAllRequired(
    source,
    'security nested rows native',
    'className="flex items-center justify-between py-2 hover:bg-background-secondary rounded-lg transition-all"',
    'className="flex items-center justify-between rounded-[9px] border border-transparent px-2 py-2 transition-all hover:border-border-secondary hover:bg-background-secondary/60"'
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
    'className="border-t border-border-secondary pt-4"'
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
    '<Card className="border-border-secondary bg-background-primary/68 pb-2 shadow-sm backdrop-blur-xl">'
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
    'className={`flex items-start gap-2 rounded-[10px] border p-3 text-sm ${'
  );
  source = replaceRequired(
    source,
    'session sharing success result native',
    "? 'bg-green-50 text-green-800 border border-green-200'",
    "? 'border-border-success bg-background-success/55 text-text-success'"
  );
  source = replaceRequired(
    source,
    'session sharing error result native',
    ": 'bg-red-50 text-red-800 border border-red-200'",
    ": 'border-border-danger bg-background-danger/55 text-text-danger'"
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
    'className="ep-native-list-card mb-2 border p-2"'
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
    'className="ep-native-list-card flex flex-col border p-3 hover:border-[var(--epistemos-accent)]"'
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

function applySessionDetailSurfaces() {
  let source = read('src/components/sessions/SharedSessionView.tsx');
  source = replaceRequired(
    source,
    'shared session header native glass',
    'className="flex flex-col pb-5 border-b border-border-secondary"',
    'className="ep-native-header-band flex flex-col rounded-[16px] border border-border-secondary p-4 shadow-sm"'
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
    'className="ep-native-header-band mb-5 flex items-center rounded-[12px] border border-border-secondary px-3 py-2 shadow-sm"'
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
    'className="ep-native-header-band flex flex-col rounded-[16px] border border-border-secondary p-4 pt-5 shadow-sm"'
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
    'className="relative flex items-center rounded-[10px] border border-border-primary bg-background-secondary/70 px-3 py-2 shadow-sm backdrop-blur-xl"'
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
    'className="ep-native-header-band mx-6 mt-6 flex-shrink-0 rounded-[16px] border border-border-secondary px-5 pb-4 pt-4 shadow-sm"'
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
    'className="rounded-[12px] border border-border-danger bg-background-danger/72 p-3 text-sm text-text-danger backdrop-blur-xl"'
  );
  source = replaceRequired(
    source,
    'schedule detail native info card',
    'className="p-4 bg-background-primary shadow-none mb-6 border border-border-primary rounded-[6px]"',
    'className="ep-native-screen-card mb-6 border p-4"'
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
    "'border-border-success bg-background-success/35 text-text-success hover:bg-background-success/55'"
  );
  source = replaceRequired(
    source,
    'schedule detail pause button token',
    "'text-orange-600 dark:text-orange-400 border-orange-300 dark:border-orange-600 hover:bg-orange-50 dark:hover:bg-orange-900/20'",
    "'border-border-warning bg-background-warning/35 text-text-warning hover:bg-background-warning/55'"
  );
  source = replaceRequired(
    source,
    'schedule detail kill button token',
    'className="w-full md:w-auto flex items-center gap-2 text-red-600 dark:text-red-400 border-red-300 dark:border-red-600 hover:bg-red-50 dark:hover:bg-red-900/20"',
    'className="flex w-full items-center gap-2 border-border-danger bg-background-danger/35 text-text-danger hover:bg-background-danger/55 md:w-auto"'
  );
  source = replaceRequired(
    source,
    'schedule detail recent session card',
    'className="p-4 bg-background-primary shadow-none cursor-pointer hover:bg-background-secondary transition-colors duration-150 border border-border-primary rounded-[6px]"',
    'className="ep-native-list-card cursor-pointer border p-4 hover:bg-background-secondary/72"'
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
    'className="ep-native-screen-card z-50 flex max-h-[90vh] w-full max-w-md flex-col overflow-hidden border"'
  );
  source = replaceRequired(
    source,
    'schedule modal native header border',
    'className="px-5 pt-5 pb-3 flex-shrink-0 border-b border-border-primary"',
    'className="flex-shrink-0 border-b border-border-secondary px-5 pb-3 pt-5"'
  );
  source = replaceAllRequired(
    source,
    'schedule modal native error panels',
    'className="text-text-danger text-sm mb-3 p-2 border border-border-danger rounded-[6px]"',
    'className="mb-3 rounded-[12px] border border-border-danger bg-background-danger/72 p-2 text-sm text-text-danger backdrop-blur-xl"'
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
    'className="grid grid-cols-2 rounded-[10px] border border-border-secondary bg-background-secondary/70 p-1 backdrop-blur-xl"'
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
    'bg-background-primary text-text-primary shadow-sm'
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
    'transition-all border-l border-border-secondary'
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
    'className="mt-2 rounded-[10px] border border-border-primary bg-background-secondary/70 p-2 shadow-sm backdrop-blur-xl"'
  );
  source = replaceRequired(
    source,
    'schedule modal native footer border',
    'className="flex gap-2 px-8 py-4 border-t border-border-primary"',
    'className="flex gap-2 border-t border-border-secondary px-8 py-4"'
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
    'className="ep-native-screen-card flex h-[90vh] w-[90vw] max-w-4xl flex-col border"'
  );
  source = replaceRequired(
    source,
    'recipe edit modal native header',
    'className="flex items-center justify-between p-6 border-b border-border-primary"',
    'className="flex items-center justify-between border-b border-border-secondary p-6"'
  );
  source = replaceRequired(
    source,
    'recipe edit modal native icon',
    'className="w-8 h-8 bg-background-primary border border-border-primary rounded-[6px] flex items-center justify-center"',
    'className="flex h-8 w-8 items-center justify-center rounded-[10px] border border-border-primary bg-background-secondary/70 shadow-sm backdrop-blur-xl"'
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
    'className="ep-native-screen-card mt-6 w-full border p-4"'
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
    'className="flex items-center justify-between border-t border-border-secondary p-6"'
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
    'className="ep-native-screen-card w-[500px] max-w-[90vw] border p-6"'
  );
  source = replaceRequired(
    source,
    'recipe import native textarea',
    'className={`w-full p-3 border rounded-lg bg-background-primary text-text-primary focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none ${',
    'className={`w-full resize-none rounded-[10px] border bg-background-primary/70 p-3 text-text-primary outline-none transition-all focus:border-[var(--epistemos-accent)] focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20 ${'
  );
  source = replaceRequired(
    source,
    'recipe import divider native',
    'className="w-full border-t border-border-primary"',
    'className="w-full border-t border-border-secondary"'
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
    'className="ep-native-screen-card flex max-h-[80vh] w-[800px] max-w-[90vw] flex-col border p-6"'
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
    'className="overflow-auto whitespace-pre rounded-[10px] border border-border-secondary bg-background-secondary/72 p-4 text-xs font-mono backdrop-blur-xl"'
  );
  source = replaceAllRequired(
    source,
    'recipe import invalid border token',
    'border-red-500',
    'border-border-danger'
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
    'className="flex h-6 w-6 items-center justify-center rounded-full border border-border-primary bg-background-secondary/70 shadow-sm backdrop-blur-xl"'
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
    'className="ep-native-screen-card mb-4 border p-3 animate-[fadein_500ms_ease-in_forwards]"'
  );
  source = replaceRequired(
    source,
    'recipe activities native pill',
    'className="cursor-pointer px-3 py-1.5 text-xs font-mono border border-border-secondary rounded-[5px] hover:bg-background-secondary transition-colors"',
    'className="ep-native-badge cursor-pointer border px-3 py-1.5 text-xs transition-colors hover:bg-background-secondary/80"'
  );
  write('src/components/recipes/RecipeActivities.tsx', source);

  source = read('src/components/recipes/RecipeActivityEditor.tsx');
  source = replaceRequired(
    source,
    'recipe activity editor textarea native',
    'className="w-full px-4 py-3 border rounded-lg bg-background-primary text-text-primary placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-border-secondary resize-vertical"',
    'className="w-full resize-vertical rounded-[10px] border border-border-primary bg-background-primary/70 px-4 py-3 text-text-primary placeholder:text-text-secondary outline-none transition-all focus:border-[var(--epistemos-accent)] focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20"'
  );
  source = replaceRequired(
    source,
    'recipe activity editor chip native',
    'className="inline-flex items-center bg-background-primary border border-border-primary rounded-[6px] px-3 py-2 text-sm text-text-primary"',
    'className="ep-native-badge inline-flex items-center border px-3 py-2 text-sm text-text-primary"'
  );
  source = replaceRequired(
    source,
    'recipe activity editor input native',
    'className="flex-1 px-3 py-2 border border-border-primary rounded-lg bg-background-primary text-text-primary focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"',
    'className="flex-1 rounded-[10px] border border-border-primary bg-background-primary/70 px-3 py-2 text-sm text-text-primary outline-none transition-all focus:border-[var(--epistemos-accent)] focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/20"'
  );
  source = replaceRequired(
    source,
    'recipe activity editor add button native',
    'className="px-4 py-2 bg-blue-500 text-white rounded-lg text-sm hover:bg-blue-600 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed"',
    'className="rounded-[8px] bg-[var(--epistemos-accent)] px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-[var(--epistemos-accent)]/90 disabled:cursor-not-allowed disabled:bg-background-disabled disabled:text-text-disabled"'
  );
  write('src/components/recipes/RecipeActivityEditor.tsx', source);

  source = read('src/components/recipes/shared/RecipeNameField.tsx');
  source = replaceAllRequired(source, 'recipe name invalid border token', 'border-red-500', 'border-border-danger');
  source = replaceAllRequired(source, 'recipe name validation text token', 'text-red-500', 'text-text-danger');
  write('src/components/recipes/shared/RecipeNameField.tsx', source);

  source = read('src/components/recipes/shared/InstructionsEditor.tsx');
  source = replaceAllRequired(source, 'recipe instructions invalid border token', 'border-red-500', 'border-border-danger');
  source = replaceAllRequired(source, 'recipe instructions validation text token', 'text-red-500', 'text-text-danger');
  write('src/components/recipes/shared/InstructionsEditor.tsx', source);

  source = read('src/components/recipes/shared/JsonSchemaEditor.tsx');
  source = replaceAllRequired(source, 'recipe json schema invalid border token', 'border-red-500', 'border-border-danger');
  source = replaceAllRequired(source, 'recipe json schema validation text token', 'text-red-500', 'text-text-danger');
  write('src/components/recipes/shared/JsonSchemaEditor.tsx', source);

  source = read('src/components/recipes/shared/RecipeFormFields.tsx');
  source = replaceAllRequired(source, 'recipe form invalid border token', 'border-red-500', 'border-border-danger');
  source = replaceAllRequired(source, 'recipe form validation text token', 'text-red-500', 'text-text-danger');
  source = replaceRequired(
    source,
    'recipe form activity add button native',
    'className="px-4 py-2 bg-blue-500 text-white rounded-lg text-sm hover:bg-blue-600 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed"',
    'className="rounded-[8px] bg-[var(--epistemos-accent)] px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-[var(--epistemos-accent)]/90 disabled:cursor-not-allowed disabled:bg-background-disabled disabled:text-text-disabled"'
  );
  write('src/components/recipes/shared/RecipeFormFields.tsx', source);

  source = read('src/components/recipes/shared/SubRecipeEditor.tsx');
  source = replaceRequired(
    source,
    'sub recipe editor card native',
    'className="border border-border-subtle rounded-lg p-4 bg-background-default hover:bg-background-muted transition-colors"',
    'className="rounded-[12px] border border-border-secondary bg-background-primary/68 p-4 shadow-sm backdrop-blur-xl transition-colors hover:bg-background-secondary/62"'
  );
  write('src/components/recipes/shared/SubRecipeEditor.tsx', source);

  source = read('src/components/recipes/shared/RecipeModelSelector.tsx');
  source = replaceRequired(
    source,
    'recipe model selector error panel native',
    'className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700"',
    'className="rounded-[12px] border border-border-danger bg-background-danger/55 p-3 text-sm text-text-danger"'
  );
  write('src/components/recipes/shared/RecipeModelSelector.tsx', source);

  source = read('src/components/ui/RecipeWarningModal.tsx');
  source = replaceRequired(
    source,
    'recipe warning modal panel native',
    'className="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-4"',
    'className="rounded-[12px] border border-border-warning bg-background-warning/55 p-4"'
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

function applyStatusIndicatorSurfaces() {
  let source = read('src/components/ToolCallStatusIndicator.tsx');
  source = replaceRequired(
    source,
    'tool status success token',
    "return 'bg-green-500';",
    "return 'border-border-success bg-background-success';"
  );
  source = replaceRequired(
    source,
    'tool status error token',
    "return 'bg-red-500';",
    "return 'border-border-danger bg-background-danger';"
  );
  source = replaceRequired(
    source,
    'tool status loading token',
    "return 'bg-yellow-500 animate-pulse';",
    "return 'border-border-warning bg-background-warning animate-pulse';"
  );
  source = replaceRequired(
    source,
    'tool status pending token',
    "return 'bg-gray-400';",
    "return 'border-border-secondary bg-background-secondary';"
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
    'className="h-4 w-4 rounded-full border border-border-success bg-background-success"'
  );
  source = replaceRequired(
    source,
    'grouped extension success summary icon token',
    'className="w-5 h-5 bg-green-500"',
    'className="h-5 w-5 rounded-full border border-border-success bg-background-success"'
  );
  source = replaceRequired(
    source,
    'grouped extension error icon token',
    'className="w-4 h-4 bg-red-500"',
    'className="h-4 w-4 rounded-full border border-border-danger bg-background-danger"'
  );
  source = replaceRequired(
    source,
    'grouped extension partial summary token',
    'className="w-5 h-5 bg-yellow-500"',
    'className="h-5 w-5 rounded-full border border-border-warning bg-background-warning"'
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
}

function applyFormValidationSurfaces() {
  let source = read('src/components/ParameterInputModal.tsx');
  source = replaceRequired(
    source,
    'parameter modal native glass',
    'className="bg-background-primary border border-border-primary rounded-[6px] shadow-none w-full max-w-lg max-h-[90vh] flex flex-col overflow-hidden"',
    'className="flex max-h-[90vh] w-full max-w-lg flex-col overflow-hidden rounded-[14px] border border-border-primary bg-background-primary/88 shadow-2xl backdrop-blur-xl"'
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
    'w-full rounded-[10px] border bg-background-primary/70 p-3 text-text-primary transition-all focus:outline-none focus:ring-[3px]'
  );
  source = replaceAllRequired(
    source,
    'parameter modal invalid ring token',
    "? 'border-red-500 focus:ring-red-500'",
    "? 'border-border-danger focus:ring-text-danger/20'"
  );
  source = replaceAllRequired(
    source,
    'parameter modal normal focus token',
    ": 'border-border-primary focus:ring-border-secondary'",
    ": 'border-border-secondary focus:border-[var(--epistemos-accent)] focus:ring-[var(--epistemos-accent)]/20'"
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
    'json schema checkbox native',
    'className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"',
    'className="h-4 w-4 rounded-[5px] border-border-primary accent-[var(--epistemos-accent)] focus:ring-[var(--epistemos-accent)]/20"'
  );
  source = replaceAllRequired(
    source,
    'json schema invalid input token',
    "className={error ? 'border-red-500' : ''}",
    "className={error ? 'border-border-danger focus-visible:ring-text-danger/20' : ''}"
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
    "className={`mt-3 flex items-center gap-2 border-t border-border-secondary pt-3 text-xs font-sans ${isUrgent ? 'text-text-danger' : 'text-text-secondary'}`}"
  );
  write('src/components/ElicitationRequest.tsx', source);

  source = read('src/components/common/InlineEditText.tsx');
  source = replaceRequired(
    source,
    'inline edit active border token',
    'border-blue-500 ring-2 ring-blue-500/20',
    'border-[var(--epistemos-accent)] ring-[3px] ring-[var(--epistemos-accent)]/20'
  );
  source = replaceRequired(
    source,
    'inline edit focus ring token',
    'focus:outline-none focus:ring-2 focus:ring-blue-500/40',
    'focus:outline-none focus:ring-[3px] focus:ring-[var(--epistemos-accent)]/25'
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
    'className="min-w-0 break-all rounded-[6px] text-left text-[var(--epistemos-accent)] underline-offset-2 hover:underline focus-visible:outline-none focus-visible:ring-[3px] focus-visible:ring-[var(--epistemos-accent)]/20"'
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
    'className="rounded-[12px] border border-border-danger bg-background-danger/55 p-4 text-text-danger"'
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
    "isError && 'rounded-[12px] border border-border-danger bg-background-danger/35'"
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
  write('src/components/UserMessage.tsx', source);

  source = read('src/components/context_management/CreditsExhaustedNotification.tsx');
  source = replaceRequired(
    source,
    'credits exhausted native warning panel',
    'className="rounded-lg border border-yellow-600/30 dark:border-yellow-500/30 bg-yellow-500/10 dark:bg-yellow-500/10 p-4 my-2"',
    'className="my-2 rounded-[12px] border border-border-warning bg-background-warning/55 p-4"'
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
    'className="mt-3 inline-flex items-center gap-2 rounded-[8px] bg-[var(--epistemos-accent)] px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-[var(--epistemos-accent)]/90"'
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
    'border-border-danger'
  );
  write('src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx', source);
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
    'className="w-full overflow-auto whitespace-pre-wrap rounded-[12px] border border-border bg-background-secondary/72 p-4 text-left text-sm text-text-danger backdrop-blur-xl"'
  );
  source = replaceRequired(
    source,
    'error boundary icon color token',
    '<AlertTriangle className="w-6 h-6 text-destructive" />',
    '<AlertTriangle className="h-6 w-6 text-text-danger" />'
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
applyLoadingAndErrorSurfaces();

console.log(`Applied Goose native reskin overlay: ${desktopRoot}`);
