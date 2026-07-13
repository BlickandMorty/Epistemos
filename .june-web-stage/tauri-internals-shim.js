// Epistemos overlay — Tauri internals polyfill for running June's web frontend
// inside a WKWebView with no Tauri runtime.
//
// Contract (verified against @tauri-apps/api 2.11.x as bundled):
//   window.__TAURI_INTERNALS__.invoke(cmd, args, options) -> Promise
//   window.__TAURI_INTERNALS__.transformCallback(cb, once) -> numeric id
//   window.__TAURI_INTERNALS__.unregisterCallback(id)
//   window.__TAURI_INTERNALS__.convertFileSrc(path, protocol) -> string
//   window.__TAURI_INTERNALS__.metadata.currentWindow.label
//   window.__TAURI_EVENT_PLUGIN_INTERNALS__.unregisterListener(event, id)
//
// `plugin:event|*` is served entirely in-page (local bus). Every other command
// is answered from the stub table below; unknown commands resolve to null and
// are recorded in window.__EPISTEMOS_TAURI_SHIM__.unknownCommands so the MAS
// adapter can enumerate the surface June's UI actually exercises. The real adapter
// (Swift WKScriptMessageHandler) replaces `deliverToHost` later — the shim's
// shape is designed so only that one function changes.
(function () {
  "use strict";
  if (window.__TAURI_INTERNALS__) return;

  var callbackSeq = 1;
  var callbacks = new Map(); // id -> { fn, once }

  function transformCallback(fn, once) {
    var id = callbackSeq++;
    callbacks.set(id, { fn: fn, once: !!once });
    return id;
  }

  function runCallback(id, payload) {
    var entry = callbacks.get(id);
    if (!entry) return;
    if (entry.once) callbacks.delete(id);
    try {
      entry.fn(payload);
    } catch (e) {
      console.error("[epistemos-shim] callback " + id + " threw:", e);
    }
  }

  function unregisterCallback(id) {
    callbacks.delete(id);
  }

  // ---- Local event bus (plugin:event|*) ------------------------------------
  var listeners = new Map(); // eventName -> Map(eventId -> handlerCallbackId)

  function eventListen(args) {
    var name = args.event;
    var id = args.handler; // already a transformCallback id
    if (!listeners.has(name)) listeners.set(name, new Map());
    listeners.get(name).set(id, id);
    return id;
  }

  function eventUnlisten(name, id) {
    var m = listeners.get(name);
    if (m) m.delete(id);
    unregisterCallback(id);
  }

  function emitLocal(name, payload) {
    var m = listeners.get(name);
    if (!m) return;
    m.forEach(function (cbId) {
      runCallback(cbId, { event: name, id: cbId, payload: payload });
    });
  }

  // ---- Gateway bridge (June WebSocket stand-in) -----------------------------
  // June's agent transport is one JSON-RPC-over-WebSocket client. The bridge
  // connection advertises a magic URL; the WebSocket wrapper below intercepts it
  // and serves the protocol without any server. Product turns require host mode:
  // the MAS adapter forwards frames to Swift/agent_core through this seam.
  var GATEWAY_URL = "epistemos://gateway";
  var gatewayConnection = {
    baseUrl: "epistemos://gateway-http",
    wsUrl: GATEWAY_URL,
    token: "", // no secret ever enters webview JS — in-process bridge needs none
    port: 0,
    command: "in-process June gateway",
    hermesHome: "",
    cwd: null,
    providerProxyPort: 0,
    pid: 0,
    sandboxed: true,
    fullMode: false,
    runtimeKind: "mas-in-process-june-gateway",
    message: "MAS uses June's in-process agent gateway; no external agent runtime or server is started.",
  };

  var NativeWebSocket = window.WebSocket;

  var activeGatewaySockets = [];

  function GatewaySocket(url) {
    var self = this;
    this.url = url;
    this.readyState = 0; // CONNECTING
    this._listeners = {};
    this._sessionSeq = 0;
    activeGatewaySockets.push(this);
    setTimeout(function () {
      self.readyState = 1; // OPEN
      self._dispatch("open", {});
    }, 0);
  }
  GatewaySocket.prototype.addEventListener = function (name, fn, opts) {
    var entry = { fn: fn, once: !!(opts && opts.once) };
    (this._listeners[name] = this._listeners[name] || []).push(entry);
  };
  GatewaySocket.prototype.removeEventListener = function (name, fn) {
    var list = this._listeners[name] || [];
    this._listeners[name] = list.filter(function (e) { return e.fn !== fn; });
  };
  GatewaySocket.prototype._dispatch = function (name, eventInit) {
    var list = (this._listeners[name] || []).slice();
    this._listeners[name] = (this._listeners[name] || []).filter(function (e) { return !e.once; });
    for (var i = 0; i < list.length; i++) {
      try { list[i].fn(eventInit); } catch (e) { console.error("[epistemos-shim] ws listener threw:", e); }
    }
  };
  GatewaySocket.prototype._reply = function (frame) {
    var self = this;
    setTimeout(function () {
      if (self.readyState !== 1) return;
      self._dispatch("message", { data: JSON.stringify(frame) });
    }, 0);
  };
  GatewaySocket.prototype._event = function (type, sessionId, payload, delayMs) {
    var self = this;
    setTimeout(function () {
      if (self.readyState !== 1) return;
      self._dispatch("message", {
        data: JSON.stringify({
          method: "event",
          params: { type: type, session_id: sessionId, payload: payload },
        }),
      });
    }, delayMs || 0);
  };
  GatewaySocket.prototype.send = function (raw) {
    if (HOST_MODE) {
      try {
        window.webkit.messageHandlers.epistemosGateway.postMessage({ frame: String(raw) });
      } catch (e) {
        console.error("[epistemos-shim] gateway post failed:", e);
      }
      return;
    }
    var frame;
    try { frame = JSON.parse(String(raw)); } catch (e) { return; }
    var id = frame.id, method = frame.method, params = frame.params || {};
    switch (method) {
      case "ping":
        this._reply({ id: id, result: {} });
        return;
      case "session.create":
      case "session.resume":
        this._reply({
          id: id,
          result: { session_id: params.session_id || ("spike-session-" + (++this._sessionSeq)) },
        });
        return;
      case "prompt.submit": {
        var sessionId = params.session_id;
        this._reply({
          id: id,
          error: {
            code: 5030,
            message: "MAS host bridge is not active; June cannot submit prompts from the fallback shim.",
          },
        });
        this._event("message.complete", sessionId, {
          text: "Error: MAS host bridge is not active. Reopen the App Store build so June can use the native gateway.",
          status: "error",
        }, 0);
        return;
      }
      default:
        this._reply({
          id: id,
          result: null,
        });
        console.warn("[epistemos-shim] gateway rpc defaulted: " + method);
        window.__EPISTEMOS_TAURI_SHIM__ &&
          window.__EPISTEMOS_TAURI_SHIM__.gatewayRpcSeen.push(method);
        return;
    }
  };
  GatewaySocket.prototype.close = function () {
    if (this.readyState === 3) return;
    this.readyState = 3; // CLOSED
    var idx = activeGatewaySockets.indexOf(this);
    if (idx !== -1) activeGatewaySockets.splice(idx, 1);
    this._dispatch("close", { code: 1000, reason: "closed" });
  };

  // Native → page: the host pushes JSON-RPC replies and streamed events here.
  function gatewayDeliver(frameJSON) {
    for (var i = 0; i < activeGatewaySockets.length; i++) {
      var socket = activeGatewaySockets[i];
      if (socket.readyState === 1) {
        socket._dispatch("message", { data: frameJSON });
      }
    }
  }

  function PatchedWebSocket(url, protocols) {
    if (typeof url === "string" && url.indexOf("epistemos://") === 0) {
      return new GatewaySocket(url);
    }
    return new NativeWebSocket(url, protocols);
  }
  PatchedWebSocket.CONNECTING = 0;
  PatchedWebSocket.OPEN = 1;
  PatchedWebSocket.CLOSING = 2;
  PatchedWebSocket.CLOSED = 3;
  PatchedWebSocket.prototype = NativeWebSocket.prototype; // instanceof stays true
  window.WebSocket = PatchedWebSocket;

  // ---- Stub table -----------------------------------------------------------
  // Minimal typed answers for commands June calls during boot; shapes mirror
  // src/lib/tauri.ts DTOs at pinned commit a626597.
  var shortcutStub = {
    code: "F5",
    modifiers: { command: false, control: false, option: false, shift: false, function: true },
    label: "fn F5",
    pressCount: 1,
  };
  var stubs = {
    bootstrap_app: function () {
      return { folders: [], notes: [], activeRecoveries: [], providerConfigured: false };
    },
    os_accounts_status: function () {
      return {
        signedIn: true,
        configured: true,
        localDev: true,
        user: { id: "local-user", handle: "you", displayName: "You" },
      };
    },
    ensure_hermes_bridge_gateway: function () {
      return { running: true, connections: [gatewayConnection], connection: gatewayConnection, runtimeKind: gatewayConnection.runtimeKind, message: gatewayConnection.message };
    },
    hermes_bridge_status: function () {
      return { running: true, connections: [gatewayConnection], connection: gatewayConnection, runtimeKind: gatewayConnection.runtimeKind, message: gatewayConnection.message };
    },
    start_hermes_bridge: function () {
      return { running: true, connections: [gatewayConnection], connection: gatewayConnection, runtimeKind: gatewayConnection.runtimeKind, message: gatewayConnection.message };
    },
    stop_hermes_bridge: function () {
      return { running: false };
    },
    list_agent_tasks: function () { return { items: [] }; },
    list_notes: function () { return { items: [] }; },
    list_folders: function () { return []; },
    list_session_folders: function () { return []; },
    list_dictionary_entries: function () { return []; },
    list_dictation_history: function () { return { items: [], retentionDays: 30 }; },
    hermes_bridge_sessions: function () { return { sessions: [] }; },
    hermes_bridge_skills: function () { return []; },
    hermes_bridge_toolsets: function () { return []; },
    hermes_bridge_cron_jobs: function () { return []; },
    hermes_bridge_messaging_platforms: function () { return { platforms: [] }; },
    hermes_agent_cli_access: function () { return { enabled: false }; },
    dictation_settings: function () {
      return {
        settings: {
          pushToTalkShortcut: shortcutStub,
          toggleShortcut: shortcutStub,
          microphone: {},
          style: "standard",
        },
      };
    },
    provider_model_settings: function () {
      return {
        settings: {
          transcriptionProvider: "stub",
          transcriptionModel: "stub",
          generationModel: "stub",
          imageModel: "stub",
        },
      };
    },
    dictation_hotkey_status: function () { return { type: "idle" }; },
    latest_dictation_event: function () { return undefined; },
    check_recording_source_readiness: function (args) {
      var mode = (args && args.request && args.request.sourceMode) || "microphoneOnly";
      return { sourceMode: mode, ready: false, sources: [] };
    },
    get_release_channel: function () { return "stable"; },
    create_note: function () {
      var now = new Date().toISOString();
      return {
        id: "spike-note-" + Date.now(),
        title: "Untitled",
        preview: "",
        processingStatus: "draft",
        folderIds: [],
        createdAt: now,
        updatedAt: now,
      };
    },
    list_venice_models: function (args) {
      var mode = (args && args.request && args.request.mode) || "generation";
      return { mode: mode, modelType: "stub", selectedModel: "", models: [] };
    },
    fetch_update: function () { return null; },
    set_dock_icon: function () { return null; },
    dictation_helper_command: function () { return null; },
    get_note: function (args) {
      var id = (args && args.request && args.request.noteId) || "spike-note";
      var now = new Date().toISOString();
      return {
        id: id, title: "Untitled", preview: "", processingStatus: "draft",
        folderIds: [], createdAt: now, updatedAt: now,
      };
    },
    os_accounts_referral_summary: function () {
      return {
        code: "SPIKE", url: "https://example.invalid", referredCount: 0,
        pendingCount: 0, qualifiedCount: 0, earnedMonths: 0, appliedMonths: 0,
        availableMonths: 0,
      };
    },
  };

  var unknownCommands = [];
  var calledCommands = [];

  // ---- Host mode ------------------------------------------------------------
  // When the native host injects `window.__EPISTEMOS_HOST__ = true` before this
  // script, every app command is answered by Swift (JuneAgentBridge) instead of
  // the in-page stub table, and gateway frames go to agent_core instead of the
  // canned echo. plugin:* handling stays in-page in both modes.
  var HOST_MODE = window.__EPISTEMOS_HOST__ === true;
  var hostCallSeq = 1;
  var hostPending = new Map(); // callId -> {resolve, reject}

  // Ceiling for a native invoke reply. In-process bridge calls answer in
  // microseconds; this only catches a genuine native-side hang (Swift threw
  // before replying) so June's UI rejects and degrades instead of waiting
  // forever on a dead Promise. Generous enough for any legitimate command.
  var HOST_INVOKE_TIMEOUT_MS = 30000;

  function hostInvoke(cmd, args) {
    return new Promise(function (resolve, reject) {
      var callId = hostCallSeq++;
      var timer = setTimeout(function () {
        if (hostPending.delete(callId)) {
          reject("bridge timeout: " + cmd);
        }
      }, HOST_INVOKE_TIMEOUT_MS);
      hostPending.set(callId, { resolve: resolve, reject: reject, timer: timer });
      try {
        window.webkit.messageHandlers.epistemosInvoke.postMessage({
          callId: callId,
          cmd: cmd,
          args: args || {},
        });
      } catch (e) {
        clearTimeout(timer);
        hostPending.delete(callId);
        reject("bridge post failed: " + String(e));
      }
    });
  }

  function resolveInvoke(callId, resultJSON, error) {
    var pending = hostPending.get(callId);
    if (!pending) return;
    if (pending.timer) clearTimeout(pending.timer);
    hostPending.delete(callId);
    if (error) {
      pending.reject(error);
      return;
    }
    try {
      // Swift wraps the payload as {v: ...} so scalars survive serialization.
      pending.resolve(resultJSON === null ? null : JSON.parse(resultJSON).v);
    } catch (e) {
      pending.reject("bridge result parse failed: " + String(e));
    }
  }

  // The spike's legacy enumeration hook (no-op in host mode).
  function deliverToHost(cmd, args) {
    if (HOST_MODE) return;
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.epistemosTauri) {
      window.webkit.messageHandlers.epistemosTauri.postMessage({ cmd: cmd });
    }
  }

  function invoke(cmd, args, options) {
    calledCommands.push(cmd);
    // Local event bus
    if (cmd === "plugin:event|listen") {
      return Promise.resolve(eventListen(args));
    }
    if (cmd === "plugin:event|unlisten") {
      eventUnlisten(args.event, args.eventId);
      return Promise.resolve();
    }
    if (cmd === "plugin:event|emit" || cmd === "plugin:event|emit_to") {
      emitLocal(args.event, args.payload);
      // Host mode: June's menu-bar state emits (agent activity counts) feed
      // the native chrome (mascot / all-chats). Forwarded only for the
      // june:menu-bar: namespace — page content never reaches this channel.
      if (HOST_MODE && typeof args.event === "string" && args.event.indexOf("june:menu-bar:") === 0) {
        try {
          window.webkit.messageHandlers.epistemosEvents.postMessage({
            event: args.event,
            payload: args.payload === undefined ? null : args.payload,
          });
        } catch (e) {}
      }
      return Promise.resolve();
    }
    // All window/webview chrome operations are meaningless in the embedded
    // surface — succeed silently.
    if (cmd.indexOf("plugin:window|") === 0 || cmd.indexOf("plugin:webview|") === 0) {
      // Getters that the API awaits for structured data:
      if (cmd === "plugin:window|theme") return Promise.resolve("dark");
      if (cmd === "plugin:window|is_visible" || cmd === "plugin:window|is_focused") {
        return Promise.resolve(true);
      }
      return Promise.resolve(null);
    }
    if (cmd.indexOf("plugin:notification|") === 0) {
      if (cmd === "plugin:notification|is_permission_granted") return Promise.resolve(true);
      if (cmd === "plugin:notification|request_permission") return Promise.resolve("granted");
      return Promise.resolve(null);
    }
    if (cmd.indexOf("plugin:dialog|") === 0 || cmd.indexOf("plugin:process|") === 0) {
      return Promise.resolve(null);
    }
    if (HOST_MODE) {
      return hostInvoke(cmd, args);
    }
    deliverToHost(cmd, args);
    var stub = stubs[cmd];
    if (stub) {
      try {
        return Promise.resolve(stub(args));
      } catch (e) {
        return Promise.reject(String(e));
      }
    }
    if (unknownCommands.indexOf(cmd) === -1) unknownCommands.push(cmd);
    console.warn("[epistemos-shim] unstubbed command: " + cmd);
    return Promise.resolve(null);
  }

  window.__TAURI_INTERNALS__ = {
    invoke: invoke,
    transformCallback: transformCallback,
    unregisterCallback: unregisterCallback,
    convertFileSrc: function (path, protocol) { return path; },
    metadata: {
      currentWindow: { label: "main" },
      currentWebview: { label: "main", windowLabel: "main" },
    },
    plugins: {},
  };

  window.__TAURI_EVENT_PLUGIN_INTERNALS__ = {
    unregisterListener: function (event, eventId) { eventUnlisten(event, eventId); },
  };

  // Probe + host-injection surface (the native side emits June agent events
  // through this in the real adapter).
  window.__EPISTEMOS_TAURI_SHIM__ = {
    emit: emitLocal,
    calledCommands: calledCommands,
    unknownCommands: unknownCommands,
    gatewayRpcSeen: [],
    resolveInvoke: resolveInvoke,
    gatewayDeliver: gatewayDeliver,
    hostMode: HOST_MODE,
  };
})();
