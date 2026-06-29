#!/usr/bin/env node
// Goose Phase-0 live ACP surface probe (re-runnable evidence).
//
// Proves the live ACP methods that the env-blocked app-hosted live integration
// suites (GooseProviderCatalog / SessionLifecycle / CustomCapability / WebPrompt /
// WebRoute) depend on, by talking JSON-RPC over the same WebSocket transport the
// Swift client uses — WITHOUT the app test host. Faithful to the Swift protocol
// (Epistemos/Goose/GooseACPProtocol.swift): initialize protocolVersion 1 +
// clientCapabilities.epistemos; method names verbatim; ws://HOST:PORT/acp?token=SECRET.
//
// Usage:  node scripts/goose-acp-live-probe.mjs "ws://127.0.0.1:PORT/acp?token=SECRET"
// Exit 0 = every probed method reachable + answered (OK or structured JSON-RPC error,
// never a silent drop); non-zero = a method timed out or the transport failed.
// Requires Node >= 22 (built-in WebSocket). See scripts/goose-acp-live-probe.sh for a
// wrapper that spawns goose serve and runs this end-to-end.

const url = process.argv[2];
if (!url) { console.error('usage: goose-acp-live-probe.mjs <ws-acp-url>'); process.exit(64); }

const ws = new WebSocket(url);
let id = 0; const pending = new Map(); let updates = 0;
const send = (method, params = {}) => new Promise((resolve) => {
  const myId = ++id; pending.set(myId, resolve);
  ws.send(JSON.stringify({ jsonrpc: '2.0', id: myId, method, params }));
  setTimeout(() => { if (pending.has(myId)) { pending.delete(myId); resolve({ __timeout: true }); } }, 12000);
});
ws.addEventListener('message', (ev) => {
  let m; try { m = JSON.parse(ev.data); } catch { return; }
  if (m.method === 'session/update') { updates++; return; }
  if (m.id && pending.has(m.id)) { const r = pending.get(m.id); pending.delete(m.id); r(m.error ? { __error: m.error } : (m.result ?? {})); }
});
ws.addEventListener('error', (e) => { console.log('WS_ERROR ' + (e.message || e)); process.exit(3); });

const CLIENT_CAPS = { elicitation: { form: {} }, meta: { goose: { customNotifications: true, recipeParameterRequests: true } } };
let failures = 0;
const arrLen = (r) => { for (const k of ['providers','catalog','sessions','sources','extensions','statuses','items','models']) if (Array.isArray(r?.[k])) return r[k].length; return Array.isArray(r) ? r.length : null; };
const report = (label, r, { reachableOnError = true } = {}) => {
  if (r.__timeout) { console.log(`✘ TIMEOUT            ${label}`); failures++; return r; }
  if (r.__error) { console.log(`✓ HANDLED(-${r.__error.code})    ${label}  ${reachableOnError ? '(reachable; structured error)' : ''}`); if (!reachableOnError) failures++; return r; }
  const n = arrLen(r); console.log(`✓ OK${n !== null ? ' count=' + n : ''}            ${label}`); return r;
};

ws.addEventListener('open', async () => {
  const cwd = process.cwd();
  console.log('— Goose live ACP surface probe —');
  report('initialize', await send('initialize', { protocolVersion: 1, clientCapabilities: CLIENT_CAPS, clientInfo: { name: 'Epistemos', version: '1.0-probe' } }));

  // read-only catalog/config surface (Models/Auth/Extensions/Recipes/Skills/Scheduler routes)
  report('providers/catalog/list (GOLDEN RULE)', await send('_goose/unstable/providers/catalog/list', {}));
  report('providers/list', await send('_goose/unstable/providers/list', {}));
  report('providers/setup/catalog/list', await send('_goose/unstable/providers/setup/catalog/list', {}));
  report('providers/config/status (Auth)', await send('_goose/unstable/providers/config/status', { providerIds: [] }));
  report('config/extensions/list (Extensions)', await send('_goose/unstable/config/extensions/list', {}));
  report('sources/list[recipe] (Recipes)', await send('_goose/unstable/sources/list', { sourceType: 'recipe' }));
  report('sources/list[skill] (Skills)', await send('_goose/unstable/sources/list', { sourceType: 'skill' }));
  report('sources/list[schedule] (Scheduler)', await send('_goose/unstable/sources/list', { sourceType: 'schedule' }));

  // session lifecycle (Session History route)
  const sess = report('session/new', await send('session/new', { cwd, mcpServers: [], metadata: { client: 'goose-desktop', appName: 'Epistemos' } }));
  const sid = sess?.sessionId ?? sess?.session_id;
  report('session/list', await send('session/list', { _meta: { types: ['user', 'scheduled'] } }));
  if (sid) {
    report('session/load', await send('session/load', { sessionId: sid, cwd, mcpServers: [], additionalDirectories: [], metadata: {} }));
    const fork = report('session/fork', await send('session/fork', { sessionId: sid, cwd, additionalDirectories: [], metadata: {} }));
    const forkSid = fork?.sessionId ?? fork?.session_id;
    if (forkSid && forkSid !== sid) console.log(`  ↳ fork differs from original (${sid} → ${forkSid})`);

    // prompt → stream → end_turn (New Chat plumbing; needs a provider default set)
    const pr = report('session/prompt → stream', await send('session/prompt', { sessionId: sid, prompt: [{ type: 'text', text: 'Say hi in one word.' }] }));
    if (!pr.__timeout && !pr.__error) console.log(`  ↳ streamed ${updates} session/update events, stopReason=${pr.stopReason ?? pr.stop_reason ?? '?'}`);
  }

  console.log(failures === 0 ? '\nLIVE_ACP_SURFACE_PASS (all methods reachable + answered)' : `\nLIVE_ACP_SURFACE_FAIL (${failures} unreachable)`);
  ws.close(); process.exit(failures === 0 ? 0 : 1);
});
