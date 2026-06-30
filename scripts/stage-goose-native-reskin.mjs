#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const desktopRoot = process.argv[2];
if (!desktopRoot) {
  console.error('usage: stage-goose-native-reskin.mjs <goose-ui-desktop-root>');
  process.exit(64);
}

const marker = 'epistemos-native-reskin-overlay';

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
  if (source.includes(marker)) {
    return;
  }
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
  write('src/styles/main.css', source);
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
}

applyThemeTokens();
applyMainCSS();
applySwitch();
applyTabs();
applySelect();
applyAppSurfaces();

console.log(`Applied Goose native reskin overlay: ${desktopRoot}`);
