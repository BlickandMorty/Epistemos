#!/usr/bin/env node
// Step-3 native Models route — live parity witness (re-runnable evidence).
//
// Proves the EXACT live ACP data path the native SwiftUI Models picker
// (Epistemos/Goose/GooseNativeModelsView.swift) binds to, against a real Goose
// runtime, WITHOUT the (degraded) app test host. The native view reaches genuine
// parity with the WebView oracle (/settings?section=models) because BOTH render
// from these same live methods — nothing is Swift-hardcoded (GOLDEN RULE):
//   1. providers/list  -> provider picker source: available providers (built-in +
//      configured) each carrying their models INLINE (one call, no per-provider
//      live enumeration that could hang). Must be non-empty AND ≥1 provider must
//      carry inline models (the model-picker source).
//   2. defaults/read   -> current-default seed; a set default provider MUST be
//      present in providers/list (true parity — the picker can show the real
//      current selection; this is the case the template catalog FAILED on).
// READ-ONLY: never calls defaults/save (no state mutation in a probe).
//
// Usage:  node scripts/goose-native-models-probe.mjs "ws://127.0.0.1:PORT/acp?token=SECRET"
// Exit 0 = parity data path live + consistent; non-zero = a method failed/timed out.
// Requires Node >= 22 (built-in WebSocket).

const url = process.argv[2];
if (!url) { console.error('usage: goose-native-models-probe.mjs <ws-acp-url>'); process.exit(64); }

const ws = new WebSocket(url);
let id = 0; const pending = new Map();
const send = (method, params = {}) => new Promise((resolve) => {
  const myId = ++id; pending.set(myId, resolve);
  ws.send(JSON.stringify({ jsonrpc: '2.0', id: myId, method, params }));
  setTimeout(() => { if (pending.has(myId)) { pending.delete(myId); resolve({ __timeout: true }); } }, 15000);
});
ws.addEventListener('message', (ev) => {
  let m; try { m = JSON.parse(ev.data); } catch { return; }
  if (m.id && pending.has(m.id)) { const r = pending.get(m.id); pending.delete(m.id); r(m.error ? { __error: m.error } : (m.result ?? {})); }
});
ws.addEventListener('error', (e) => { console.log('WS_ERROR ' + (e.message || e)); process.exit(3); });

const CLIENT_CAPS = { elicitation: { form: {} }, meta: { goose: { customNotifications: true } } };
let failures = 0;
const fail = (msg) => { console.log('✘ ' + msg); failures++; };
const ok = (msg) => console.log('✓ ' + msg);
const pid = (e) => e.providerId ?? e.provider_id;

ws.addEventListener('open', async () => {
  console.log('— native Models route live parity probe —');

  const init = await send('initialize', { protocolVersion: 1, clientCapabilities: CLIENT_CAPS, clientInfo: { name: 'Epistemos', version: 'native-models-probe' } });
  if (init.__timeout || init.__error) { fail('initialize failed'); ws.close(); process.exit(1); }
  ok('initialize');

  // 1. Provider + model picker source (providers/list — models inline).
  const list = await send('_goose/unstable/providers/list', {});
  const entries = Array.isArray(list?.entries) ? list.entries : (Array.isArray(list?.providers) ? list.providers : []);
  if (list.__timeout || list.__error) fail('providers/list did not answer');
  else if (entries.length === 0) fail('providers/list returned an EMPTY inventory (native picker would be empty)');
  else {
    ok(`providers/list -> ${entries.length} providers (picker source)`);
    const withModels = entries.filter((e) => Array.isArray(e.models) && e.models.length > 0);
    if (withModels.length === 0) fail('no provider carries inline models (model picker would always be empty)');
    else {
      const sample = withModels[0];
      ok(`inline models present: ${withModels.length} providers have models (e.g. ${pid(sample)} -> ${sample.models.length})`);
    }
  }

  // 2. Current-default seed + parity (default provider must be in the inventory the picker shows).
  const defaults = await send('_goose/unstable/defaults/read', {});
  if (defaults.__timeout || defaults.__error) fail('defaults/read did not answer');
  else {
    const dp = defaults.providerId ?? defaults.provider_id ?? null;
    const dm = defaults.modelId ?? defaults.model_id ?? null;
    ok(`defaults/read -> provider=${dp ?? '(none)'} model=${dm ?? '(none)'} (current-default seed)`);
    if (dp) {
      if (entries.some((e) => pid(e) === dp)) ok(`default provider ${dp} IS present in providers/list (picker shows real current selection)`);
      else fail(`default provider ${dp} is NOT in providers/list inventory (picker could not show the real default)`);
    }
  }

  console.log(failures === 0
    ? '\nNATIVE_MODELS_PARITY_PASS (live data path the native picker binds to is reachable + consistent)'
    : `\nNATIVE_MODELS_PARITY_FAIL (${failures} checks failed)`);
  ws.close(); process.exit(failures === 0 ? 0 : 1);
});
