// Epistemos MAS proxy — reference server entrypoint (Plan 1-MAS §5 / §11 R4).
// No framework: plain node:http keeps the reference dependency-light and easy
// to audit. Three routes: verify-receipt, chat/completions (SSE), and the
// App Store Server Notifications V2 webhook.

import { createServer, IncomingMessage, ServerResponse } from "node:http";
import { loadConfig, type Config } from "./config.ts";
import { mintSession, verifySession } from "./tokens.ts";
import { verifyStoreKitJWS, isEntitlementActive } from "./appstore.ts";
import { proxyChatCompletion } from "./proxy.ts";

const config = loadConfig();

function json(res: ServerResponse, status: number, body: unknown): void {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(payload),
  });
  res.end(payload);
}

async function readBody(req: IncomingMessage): Promise<string> {
  const chunks: Buffer[] = [];
  let total = 0;
  for await (const chunk of req) {
    total += (chunk as Buffer).length;
    if (total > 8 * 1024 * 1024) throw new Error("request body too large");
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks).toString("utf8");
}

async function handleVerifyReceipt(
  req: IncomingMessage,
  res: ServerResponse,
): Promise<void> {
  const body = JSON.parse(await readBody(req)) as {
    storekit_jws?: string;
    app_account_token?: string;
  };
  if (!body.storekit_jws) {
    return json(res, 400, { error: "missing storekit_jws" });
  }
  let tx;
  try {
    tx = await verifyStoreKitJWS(config, body.storekit_jws);
  } catch (err) {
    return json(res, 401, { error: `invalid receipt: ${(err as Error).message}` });
  }
  const active = await isEntitlementActive(config, tx);
  if (!active) {
    return json(res, 403, { error: "no active subscription" });
  }
  const session = await mintSession(config, {
    appAccountToken: body.app_account_token ?? tx.appAccountToken,
    originalTransactionId: tx.originalTransactionId,
    productId: tx.productId,
  });
  // Matches EpistemosProxyClient's TokenResponse: { token, expiresAt }.
  return json(res, 200, { token: session.token, expiresAt: session.expiresAt });
}

async function handleChatCompletions(
  req: IncomingMessage,
  res: ServerResponse,
): Promise<void> {
  const auth = req.headers.authorization ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (!token) return json(res, 401, { error: "missing bearer token" });
  try {
    await verifySession(config, token);
  } catch {
    return json(res, 401, { error: "invalid or expired session token" });
  }
  const body = JSON.parse(await readBody(req));
  await proxyChatCompletion(config, body, res);
}

async function handleWebhook(
  req: IncomingMessage,
  res: ServerResponse,
): Promise<void> {
  // App Store Server Notifications V2: { signedPayload: <JWS> }. Verify and
  // act (revoke/refresh) — here we validate and 200 promptly + idempotently.
  // Entitlement state is re-derived on the next verify-receipt, so this
  // reference logs the decoded notification type rather than persisting.
  try {
    const body = JSON.parse(await readBody(req)) as { signedPayload?: string };
    if (body.signedPayload) {
      const tx = await verifyStoreKitJWS(config, body.signedPayload).catch(
        () => null,
      );
      if (tx) {
        console.log(
          `[webhook] notification for otid=${tx.originalTransactionId} revoked=${tx.revoked}`,
        );
      }
    }
  } catch {
    // Respond 2xx regardless (idempotent, prompt) — Apple retries on non-2xx.
  }
  res.writeHead(200);
  res.end();
}

const server = createServer((req, res) => {
  const url = req.url ?? "";
  const method = req.method ?? "GET";
  const route = url.split("?")[0];

  const dispatch = async () => {
    if (method === "POST" && route === "/v1/auth/verify-receipt") {
      return handleVerifyReceipt(req, res);
    }
    if (method === "POST" && route === "/v1/chat/completions") {
      return handleChatCompletions(req, res);
    }
    if (method === "POST" && route === "/v1/webhooks/appstore") {
      return handleWebhook(req, res);
    }
    if (method === "GET" && route === "/healthz") {
      return json(res, 200, { ok: true });
    }
    return json(res, 404, { error: "not found" });
  };

  dispatch().catch((err) => {
    if (!res.headersSent) {
      json(res, 500, { error: (err as Error).message });
    } else {
      try {
        res.end();
      } catch {
        /* already closed */
      }
    }
  });
});

server.listen(config.port, () => {
  console.log(
    `[epistemos-mas-proxy] listening on :${config.port} (upstream=${config.upstreamProvider}, env=${config.appleEnvironment})`,
  );
});
