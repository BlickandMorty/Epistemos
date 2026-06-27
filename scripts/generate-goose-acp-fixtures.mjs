#!/usr/bin/env node
import { spawn, execFileSync } from "node:child_process";
import { mkdir, writeFile } from "node:fs/promises";
import { accessSync, constants } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const fixtureRoot = path.join(repoRoot, "EpistemosTests", "Fixtures", "GooseACP");
const host = "127.0.0.1";
const port = 3284;
const secret = "phase0-fixture-capture-secret";
const baseURL = `http://${host}:${port}`;
const acpURL = `ws://${host}:${port}/acp?token=${encodeURIComponent(secret)}`;

const allowEnv = new Set(["PATH", "HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE", "TERM", "TZ"]);

const redactor = {
  sessions: new Map(),
  toolCalls: new Map(),
  serverRequests: new Map(),
};

let nextRequestID = 1;

function hostTriple() {
  if (process.arch === "arm64") return "aarch64-apple-darwin";
  if (process.arch === "x64") return "x86_64-apple-darwin";
  return "";
}

function executable(pathname) {
  try {
    accessSync(pathname, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function resolveGooseBinary() {
  if (process.env.EPISTEMOS_GOOSE_BINARY && executable(process.env.EPISTEMOS_GOOSE_BINARY)) {
    return process.env.EPISTEMOS_GOOSE_BINARY;
  }
  const targetRoot = path.join(repoRoot, ".research-clones", "work", "goose", "target");
  const triple = hostTriple();
  const candidates = [
    triple ? path.join(targetRoot, triple, "debug", "goose") : "",
    triple ? path.join(targetRoot, triple, "release", "goose") : "",
    path.join(targetRoot, "debug", "goose"),
    path.join(targetRoot, "release", "goose"),
  ].filter(Boolean);
  const found = candidates.find(executable);
  if (!found) throw new Error("No executable Goose binary found. Build .research-clones/work/goose first.");
  return found;
}

function gooseRevision() {
  try {
    return execFileSync("git", ["-C", path.join(repoRoot, ".research-clones", "work", "goose"), "rev-parse", "HEAD"], {
      encoding: "utf8",
    }).trim();
  } catch {
    return "unknown";
  }
}

function sanitizedEnv(binary) {
  const env = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (allowEnv.has(key)) env[key] = value;
  }
  env.GOOSE_SERVER__SECRET_KEY = secret;
  env.GOOSE_MODE = "approve";
  env.PATH = [path.dirname(binary), env.PATH].filter(Boolean).join(":");
  return env;
}

async function healthOK() {
  try {
    const response = await fetch(`${baseURL}/health`, { signal: AbortSignal.timeout(700) });
    return response.ok && (await response.text()).trim() === "ok";
  } catch {
    return false;
  }
}

async function startGoose(binary) {
  if (await healthOK()) {
    throw new Error(`${baseURL} is already serving /health; stop the existing listener before capture.`);
  }
  const child = spawn(
    binary,
    ["serve", "--host", host, "--port", String(port), "--with-builtin", "developer"],
    {
      cwd: repoRoot,
      detached: true,
      env: sanitizedEnv(binary),
      stdio: ["ignore", "pipe", "pipe"],
    }
  );
  child.stdout.on("data", (data) => process.stderr.write(data));
  child.stderr.on("data", (data) => process.stderr.write(data));
  for (let attempt = 0; attempt < 240; attempt += 1) {
    if (await healthOK()) return child;
    if (child.exitCode !== null) throw new Error(`goose serve exited early with ${child.exitCode}`);
    await sleep(100);
  }
  throw new Error("Timed out waiting for goose serve /health.");
}

async function stopGoose(child) {
  if (!child || child.killed) return;
  try {
    process.kill(-child.pid, "SIGTERM");
  } catch {}
  await sleep(500);
  if (child.exitCode === null) {
    try {
      process.kill(-child.pid, "SIGKILL");
    } catch {}
  }
}

class ACPRecorder {
  constructor(url) {
    this.url = url;
    this.socket = undefined;
    this.captureFrames = undefined;
    this.responses = new Map();
    this.messages = [];
    this.messageWaiters = [];
    this.requests = [];
    this.requestWaiters = [];
  }

  async open() {
    this.socket = new WebSocket(this.url);
    this.socket.addEventListener("message", (event) => this.receive(event.data));
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error("Timed out opening ACP WebSocket.")), 12_000);
      this.socket.addEventListener("open", () => {
        clearTimeout(timeout);
        resolve();
      }, { once: true });
      this.socket.addEventListener("error", () => {
        clearTimeout(timeout);
        reject(new Error("ACP WebSocket failed to open."));
      }, { once: true });
    });
  }

  close() {
    this.socket?.close();
  }

  receive(data) {
    const body = JSON.parse(String(data));
    this.messages.push(body);
    this.resolveMessageWaiters();
    this.record("goose_to_client", body);
    if (Object.prototype.hasOwnProperty.call(body, "id") && (body.result !== undefined || body.error !== undefined)) {
      const resolver = this.responses.get(String(body.id));
      if (resolver) {
        this.responses.delete(String(body.id));
        resolver(body);
      }
      return;
    }
    if (body.method && Object.prototype.hasOwnProperty.call(body, "id")) {
      this.requests.push(body);
      this.resolveRequestWaiters();
    }
  }

  async request(method, params = {}, frames = this.captureFrames) {
    const id = nextRequestID++;
    const body = { jsonrpc: "2.0", id, method, params };
    this.record("client_to_goose", body, frames);
    this.socket.send(JSON.stringify(body));
    return await this.waitForResponse(id);
  }

  async result(id, result, frames = this.captureFrames) {
    const body = { jsonrpc: "2.0", id, result };
    this.record("client_to_goose", body, frames);
    this.socket.send(JSON.stringify(body));
  }

  waitForResponse(id) {
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.responses.delete(String(id));
        reject(new Error(`Timed out waiting for response ${id}.`));
      }, 90_000);
      this.responses.set(String(id), (body) => {
        clearTimeout(timeout);
        resolve(body);
      });
    });
  }

  waitForRequest(predicate = () => true) {
    const queuedIndex = this.requests.findIndex(predicate);
    if (queuedIndex >= 0) {
      const [body] = this.requests.splice(queuedIndex, 1);
      return Promise.resolve(body);
    }
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error("Timed out waiting for Goose request.")), 90_000);
      this.requestWaiters.push({ predicate, resolve: (body) => {
        clearTimeout(timeout);
        resolve(body);
      }});
      this.resolveRequestWaiters();
    });
  }

  waitForBody(predicate) {
    const queued = this.messages.find(predicate);
    if (queued) return Promise.resolve(queued);
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error("Timed out waiting for Goose frame.")), 90_000);
      this.messageWaiters.push({ predicate, resolve: (body) => {
        clearTimeout(timeout);
        resolve(body);
      }});
      this.resolveMessageWaiters();
    });
  }

  record(direction, body, frames = this.captureFrames) {
    if (!frames) return;
    frames.push({ direction, body: deepSort(sanitize(body)) });
  }

  resolveRequestWaiters() {
    for (const waiter of [...this.requestWaiters]) {
      const queuedIndex = this.requests.findIndex(waiter.predicate);
      if (queuedIndex < 0) continue;
      const [body] = this.requests.splice(queuedIndex, 1);
      this.requestWaiters = this.requestWaiters.filter((candidate) => candidate !== waiter);
      waiter.resolve(body);
    }
  }

  resolveMessageWaiters() {
    for (const waiter of [...this.messageWaiters]) {
      const body = this.messages.find(waiter.predicate);
      if (!body) continue;
      this.messageWaiters = this.messageWaiters.filter((candidate) => candidate !== waiter);
      waiter.resolve(body);
    }
  }
}

function initializeParams() {
  return {
    protocolVersion: 1,
    clientCapabilities: {
      elicitation: { form: {} },
      _meta: {
        goose: {
          customNotifications: true,
          recipeParameterRequests: true,
        },
      },
    },
    clientInfo: {
      name: "Epistemos",
      version: "phase0-fixture-capture",
    },
  };
}

async function writeFixture(name, title, frames, metadata = {}) {
  const fixture = deepSort({
    id: name.replace(/\.json$/, ""),
    title,
    generatedAt: new Date().toISOString(),
    generator: "scripts/generate-goose-acp-fixtures.mjs",
    gooseRevision: metadata.gooseRevision,
    metadata,
    frames,
  });
  await writeFile(path.join(fixtureRoot, name), `${JSON.stringify(fixture, null, 2)}\n`, "utf8");
}

async function capture(binary) {
  await mkdir(fixtureRoot, { recursive: true });
  const revision = gooseRevision();
  const goose = await startGoose(binary);
  const recorder = new ACPRecorder(acpURL);
  try {
    await recorder.open();

    const f1 = [];
    recorder.captureFrames = f1;
    await recorder.request("initialize", initializeParams());
    await writeFixture("F1_initialize.json", "ACP initialize handshake", f1, { gooseRevision: revision });

    const f2 = [];
    recorder.captureFrames = f2;
    const session = await recorder.request("session/new", { cwd: repoRoot, mcpServers: [] });
    const sessionId = session.result.sessionId;
    await writeFixture("F2_session_new.json", "ACP session/new response", f2, { gooseRevision: revision });

    const f3 = [];
    recorder.captureFrames = f3;
    await recorder.request("session/prompt", {
      sessionId,
      prompt: [{ type: "text", text: "Reply with exactly this phrase and no markdown: phase0 fixture prompt ready" }],
    });
    await writeFixture("F3_prompt_answer_stream.json", "ACP prompt answer stream reaches end_turn", f3, { gooseRevision: revision });

    recorder.captureFrames = undefined;
    const customSession = await recorder.request("session/new", { cwd: repoRoot, mcpServers: [] }, undefined);
    const customSessionId = customSession.result.sessionId;
    const f5 = [];
    recorder.captureFrames = f5;
    await recorder.request("_goose/unstable/providers/list", { providerIds: [] });
    await recorder.request("_goose/unstable/config/extensions/list", {});
    await recorder.request("_goose/unstable/preferences/read", { keys: [] });
    await recorder.request("_goose/unstable/defaults/read", {});
    await recorder.request("_goose/unstable/session/info", { sessionId: customSessionId });
    await recorder.request("_goose/unstable/diagnostics/get", { sessionId: customSessionId, level: "summary" });
    await writeFixture("F5_custom_readonly.json", "Read-only Goose custom ACP subset", f5, { gooseRevision: revision });

    recorder.captureFrames = undefined;
    recorder.messages = [];
    recorder.requests = [];
    const permissionSession = await recorder.request("session/new", { cwd: repoRoot, mcpServers: [] }, undefined);
    const permissionSessionId = permissionSession.result.sessionId;
    const f4 = [];
    recorder.captureFrames = f4;
    const promptResponse = recorder.request("session/prompt", {
      sessionId: permissionSessionId,
      prompt: [
        {
          type: "text",
          text: "Use the developer shell tool to run `printf phase0_fixture_permission_probe`, then tell me the exact output.",
        },
      ],
    }).catch(() => undefined);
    const permission = await recorder.waitForRequest((body) => body.method === "session/request_permission");
    const option = allowOption(permission.params.options);
    if (!option) throw new Error("Goose permission request did not include an allow option.");
    await recorder.result(permission.id, { outcome: { outcome: "selected", optionId: option.optionId } });
    await recorder.waitForBody(isTerminalToolUpdate);
    await Promise.race([promptResponse, sleep(1_500)]);
    await writeFixture("F4_permission_tool_result.json", "ACP permission request and tool result stream", f4, { gooseRevision: revision });
  } finally {
    recorder.close();
    await stopGoose(goose);
  }
}

function isTerminalToolUpdate(body) {
  if (body?.method !== "session/update") return false;
  return hasTerminalToolStatus(body.params?.update);
}

function hasTerminalToolStatus(value) {
  if (Array.isArray(value)) return value.some(hasTerminalToolStatus);
  if (!value || typeof value !== "object") return false;
  if (value.toolCallId && (value.status === "completed" || value.status === "failed")) return true;
  return Object.values(value).some(hasTerminalToolStatus);
}

function allowOption(options = []) {
  return options.find((option) => option.kind === "allow_once")
    ?? options.find((option) => option.kind === "allow_always")
    ?? options.find((option) => !String(option.kind ?? "").startsWith("reject"));
}

function sanitize(value, parent = undefined, key = undefined) {
  if (Array.isArray(value)) return value.map((item) => sanitize(item));
  if (value && typeof value === "object") {
    const next = {};
    for (const [childKey, childValue] of Object.entries(value)) {
      next[childKey] = sanitize(childValue, value, childKey);
    }
    return next;
  }
  if (typeof value !== "string") return value;
  if (redactor.sessions.has(value)) return redactor.sessions.get(value);
  if (redactor.toolCalls.has(value)) return redactor.toolCalls.get(value);
  if (redactor.serverRequests.has(value)) return redactor.serverRequests.get(value);
  if (key === "sessionId") return remember(redactor.sessions, value, "session");
  if (key === "toolCallId") return remember(redactor.toolCalls, value, "tool-call");
  if (key === "id" && parent?.method) return remember(redactor.serverRequests, value, "server-request");
  return value.replaceAll(repoRoot, "<repo-root>").replaceAll(secret, "<redacted-secret>");
}

function remember(map, value, label) {
  if (!map.has(value)) map.set(value, `<${label}-${map.size + 1}>`);
  return map.get(value);
}

function deepSort(value) {
  if (Array.isArray(value)) return value.map(deepSort);
  if (!value || typeof value !== "object") return value;
  return Object.fromEntries(Object.keys(value).sort().map((key) => [key, deepSort(value[key])]));
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const binary = resolveGooseBinary();
await capture(binary);
console.log(`Wrote Goose ACP fixtures to ${fixtureRoot}`);
process.exit(0);
