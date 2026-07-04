// Env-driven config (Plan 1-MAS §5). Provider keys are server-only and never
// returned to the client. Missing values surface as clear errors at the point
// of use, not silent misbehavior.

export interface Config {
  port: number;
  sessionJwtSecret: string;
  sessionTtlSeconds: number;
  appleBundleId: string;
  appleIssuerId: string;
  appleKeyId: string;
  applePrivateKey: string;
  appleEnvironment: "Production" | "Sandbox";
  upstreamProvider: "anthropic" | "openai";
  upstreamBaseUrl: string;
  upstreamApiKey: string;
  upstreamModel: string;
}

function required(name: string): string {
  const value = process.env[name];
  if (!value || value.trim() === "") {
    throw new Error(`missing required env ${name}`);
  }
  return value;
}

function optional(name: string, fallback: string): string {
  const value = process.env[name];
  return value && value.trim() !== "" ? value : fallback;
}

export function loadConfig(): Config {
  return {
    port: Number(optional("PORT", "8787")),
    sessionJwtSecret: required("SESSION_JWT_SECRET"),
    sessionTtlSeconds: Number(optional("SESSION_TTL_SECONDS", "3600")),
    appleBundleId: optional("APPLE_BUNDLE_ID", "com.epistemos.appstore"),
    appleIssuerId: optional("APPLE_ISSUER_ID", ""),
    appleKeyId: optional("APPLE_KEY_ID", ""),
    applePrivateKey: optional("APPLE_PRIVATE_KEY", ""),
    appleEnvironment: optional("APPLE_ENVIRONMENT", "Production") as
      | "Production"
      | "Sandbox",
    upstreamProvider: optional("UPSTREAM_PROVIDER", "anthropic") as
      | "anthropic"
      | "openai",
    upstreamBaseUrl: optional("UPSTREAM_BASE_URL", "https://api.anthropic.com"),
    upstreamApiKey: optional("UPSTREAM_API_KEY", ""),
    upstreamModel: optional("UPSTREAM_MODEL", "claude-sonnet-4-6"),
  };
}
