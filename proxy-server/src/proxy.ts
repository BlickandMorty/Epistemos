// OpenAI-compatible chat/completions proxy (Plan 1-MAS §5). Authenticated by
// the short-lived session token; forwards to the real provider with the
// server-held key and streams SSE back. agent_core's OpenAICompatibleProvider
// speaks this shape, so no special-casing is needed in the app.

import { ServerResponse } from "node:http";
import type { Config } from "./config.ts";

// The app sends an OpenAI-compatible request. For an Anthropic upstream we
// translate to the Messages API and re-emit OpenAI-style SSE chunks; for an
// OpenAI upstream we pass through. Both stream token deltas.
export async function proxyChatCompletion(
  config: Config,
  requestBody: unknown,
  res: ServerResponse,
): Promise<void> {
  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });

  if (config.upstreamProvider === "openai") {
    await passthroughOpenAI(config, requestBody, res);
  } else {
    await translateAnthropic(config, requestBody, res);
  }
}

async function passthroughOpenAI(
  config: Config,
  body: unknown,
  res: ServerResponse,
): Promise<void> {
  const upstream = await fetch(`${config.upstreamBaseUrl}/v1/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${config.upstreamApiKey}`,
    },
    body: JSON.stringify({ ...(body as object), stream: true, model: config.upstreamModel }),
  });
  await pipeSSE(upstream, res);
}

// Minimal OpenAI→Anthropic translation for the streaming path. Reference
// scope: text messages + system; extend for tools/images as the app needs.
async function translateAnthropic(
  config: Config,
  body: unknown,
  res: ServerResponse,
): Promise<void> {
  const req = body as {
    messages?: { role: string; content: unknown }[];
    max_tokens?: number;
    system?: string;
  };
  const messages = (req.messages ?? [])
    .filter((m) => m.role === "user" || m.role === "assistant")
    .map((m) => ({ role: m.role, content: stringifyContent(m.content) }));
  const system =
    req.system ??
    (req.messages ?? []).find((m) => m.role === "system")?.content;

  const upstream = await fetch(`${config.upstreamBaseUrl}/v1/messages`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": config.upstreamApiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: config.upstreamModel,
      max_tokens: req.max_tokens ?? 4096,
      stream: true,
      system: system ? stringifyContent(system) : undefined,
      messages,
    }),
  });

  if (!upstream.ok || !upstream.body) {
    const text = await upstream.text().catch(() => "");
    writeErrorChunk(res, `upstream ${upstream.status}: ${text.slice(0, 200)}`);
    return;
  }

  // Re-emit Anthropic SSE as OpenAI-compatible chat.completion.chunk deltas.
  const reader = upstream.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const events = buffer.split("\n\n");
    buffer = events.pop() ?? "";
    for (const evt of events) {
      const dataLine = evt.split("\n").find((l) => l.startsWith("data:"));
      if (!dataLine) continue;
      const json = dataLine.slice(5).trim();
      if (!json) continue;
      try {
        const parsed = JSON.parse(json) as {
          type?: string;
          delta?: { text?: string };
        };
        if (parsed.type === "content_block_delta" && parsed.delta?.text) {
          writeDeltaChunk(res, parsed.delta.text);
        }
      } catch {
        // ignore keep-alives / non-JSON
      }
    }
  }
  res.write("data: [DONE]\n\n");
  res.end();
}

async function pipeSSE(upstream: Response, res: ServerResponse): Promise<void> {
  if (!upstream.ok || !upstream.body) {
    const text = await upstream.text().catch(() => "");
    writeErrorChunk(res, `upstream ${upstream.status}: ${text.slice(0, 200)}`);
    return;
  }
  const reader = upstream.body.getReader();
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    res.write(value);
  }
  res.end();
}

function writeDeltaChunk(res: ServerResponse, text: string): void {
  const chunk = {
    object: "chat.completion.chunk",
    choices: [{ index: 0, delta: { content: text }, finish_reason: null }],
  };
  res.write(`data: ${JSON.stringify(chunk)}\n\n`);
}

function writeErrorChunk(res: ServerResponse, message: string): void {
  res.write(`data: ${JSON.stringify({ error: { message } })}\n\n`);
  res.write("data: [DONE]\n\n");
  res.end();
}

function stringifyContent(content: unknown): string {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .map((c) =>
        typeof c === "string" ? c : (c as { text?: string }).text ?? "",
      )
      .join("");
  }
  return String(content ?? "");
}
