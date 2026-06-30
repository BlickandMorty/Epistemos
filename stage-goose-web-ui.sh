#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOOSE_UI_DIR="${GOOSE_UI_DIR:-$ROOT_DIR/.research-clones/work/goose/ui/desktop}"
OUTPUT_DIR="${1:-${EPISTEMOS_GOOSE_UI_OUT:-$HOME/Library/Application Support/Epistemos/GooseWebUI}}"
MANIFEST_FILE=".epistemos-goose-webui.json"

if [ ! -d "$GOOSE_UI_DIR" ]; then
    echo "Goose desktop UI checkout not found: $GOOSE_UI_DIR" >&2
    exit 1
fi

VITE_BIN="$GOOSE_UI_DIR/../node_modules/.bin/vite"
if [ ! -x "$VITE_BIN" ]; then
    echo "Goose Vite binary not found: $VITE_BIN" >&2
    echo "Install/build Goose UI dependencies before staging the WebView artifact." >&2
    exit 1
fi
if [ ! -d "$GOOSE_UI_DIR/node_modules" ]; then
    echo "Goose desktop node_modules not found: $GOOSE_UI_DIR/node_modules" >&2
    echo "Install Goose UI dependencies before staging the WebView artifact." >&2
    exit 1
fi
if [ ! -d "$GOOSE_UI_DIR/../node_modules" ]; then
    echo "Goose UI workspace node_modules not found: $GOOSE_UI_DIR/../node_modules" >&2
    echo "Install Goose UI dependencies before staging the WebView artifact." >&2
    exit 1
fi

WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/epistemos-goose-webui-work.XXXXXX")"
STAGED_OUTPUT=""
cleanup() {
    rm -rf "$WORK_ROOT"
    if [ -n "$STAGED_OUTPUT" ] && [ -d "$STAGED_OUTPUT" ]; then
        rm -rf "$STAGED_OUTPUT"
    fi
}
trap cleanup EXIT

mkdir -p "$WORK_ROOT/ui"
rsync -a --delete \
    --exclude='node_modules' \
    --exclude='dist' \
    --exclude='.vite' \
    "$GOOSE_UI_DIR/" \
    "$WORK_ROOT/ui/desktop/"

ln -s "$GOOSE_UI_DIR/../node_modules" "$WORK_ROOT/ui/node_modules"
ln -s "$GOOSE_UI_DIR/node_modules" "$WORK_ROOT/ui/desktop/node_modules"
printf 'export const USE_ACP_CHAT = true;\n' > "$WORK_ROOT/ui/desktop/src/acpChatFeatureFlag.ts"

node "$ROOT_DIR/scripts/stage-goose-native-reskin.mjs" "$WORK_ROOT/ui/desktop"

cat > "$WORK_ROOT/ui/desktop/src/acp/providers.ts" <<'TS'
import type {
  ConfigKey,
  DeclarativeProviderConfig,
  DictationProviderStatus,
  DownloadProgress,
  ModelInfo,
  ModelTemplate,
  ProviderCatalogEntry,
  ProviderDetails,
  ProviderSecret,
  ProviderTemplate,
  ProviderType,
  ToolInfo,
  UpdateCustomProviderRequest,
  WhisperModelResponse,
} from '../api';
import { getAcpClient } from './acpConnection';
import type { PreferenceKey } from '@aaif/goose-sdk';

type ProviderConfigKey = {
  name: string;
  required: boolean;
  secret: boolean;
  default?: string | null;
  oauthFlow?: boolean;
  deviceCodeFlow?: boolean;
  primary?: boolean;
};

type ProviderInventoryModel = {
  id: string;
  name: string;
  contextLimit?: number | null;
  reasoning?: boolean | null;
};

type ProviderInventoryEntry = {
  providerId: string;
  providerName: string;
  description: string;
  defaultModel: string;
  configured: boolean;
  providerType: string;
  configKeys: ProviderConfigKey[];
  setupSteps: string[];
  models: ProviderInventoryModel[];
  modelSelectionHint?: string | null;
};

type ProviderConfigFieldValue = {
  key: string;
  value?: string | null;
  isSet?: boolean;
  isSecret?: boolean;
};

type ProviderConfigStatus = {
  providerId: string;
  isConfigured: boolean;
};

type ProviderConfigFieldUpdate = {
  key: string;
  value: unknown;
};

type AcpProviderCatalogEntry = {
  providerId: string;
  name: string;
  format: string;
  apiUrl: string;
  modelCount: number;
  docUrl: string;
  envVar: string;
};

type AcpProviderTemplateModel = {
  id: string;
  name: string;
  contextLimit: number;
  capabilities: {
    toolCall: boolean;
    reasoning: boolean;
    attachment: boolean;
    temperature: boolean;
  };
  deprecated: boolean;
};

type AcpProviderTemplate = {
  providerId: string;
  name: string;
  format: string;
  apiUrl: string;
  models: AcpProviderTemplateModel[];
  supportsStreaming: boolean;
  envVar: string;
  docUrl: string;
};

type AcpProviderSetupField = {
  key: string;
  label: string;
  secret: boolean;
  required: boolean;
  placeholder?: string | null;
  defaultValue?: string | null;
};

type AcpProviderSetupCatalogEntry = {
  providerId: string;
  name: string;
  category: string;
  description: string;
  setupMethod: string;
  nativeConnectQuery?: string | null;
  fields?: AcpProviderSetupField[];
  binaryName?: string | null;
  docUrl?: string | null;
  group: string;
  showOnlyWhenInstalled: boolean;
  aliases?: string[];
  supportsInstall: boolean;
  supportsAuth: boolean;
  supportsAuthStatus: boolean;
};

function providerType(value: string): ProviderType {
  if (value === 'Preferred' || value === 'Builtin' || value === 'Declarative' || value === 'Custom') {
    return value;
  }
  return 'Builtin';
}

function configKey(key: ProviderConfigKey): ConfigKey {
  return {
    name: key.name,
    required: key.required,
    secret: key.secret,
    default: key.default ?? null,
    oauth_flow: key.oauthFlow ?? false,
    device_code_flow: key.deviceCodeFlow ?? false,
    primary: key.primary ?? false,
  };
}

function setupConfigKey(field: AcpProviderSetupField, index: number, setupMethod?: string): ConfigKey {
  const isPrimary = index === 0;
  // Map the provider's LIVE setupMethod (oauth_browser / oauth_device_code /
  // host_with_oauth_fallback / single_api_key / config_fields / ...) onto the
  // oauth flags so the "Sign in with {provider}" button renders for OAuth
  // providers (gated on oauth_flow||device_code_flow). Permissive oauth* match so
  // it tracks Goose's setup methods without a hardcoded enum; the value comes live
  // from Goose, we only surface it. Marker: epistemos-acp-oauth-setup-method.
  const method = (setupMethod ?? '').toLowerCase();
  const isOauth = method.includes('oauth');
  const isDeviceCode = method.includes('device_code') || method.includes('devicecode');
  return {
    name: field.key,
    required: field.required,
    secret: field.secret,
    default: field.defaultValue ?? null,
    oauth_flow: isPrimary && isOauth,
    device_code_flow: isPrimary && isDeviceCode,
    primary: isPrimary,
  };
}

function modelInfo(model: ProviderInventoryModel): ModelInfo {
  return {
    name: model.id || model.name,
    context_limit: model.contextLimit ?? 0,
    reasoning: model.reasoning ?? false,
  };
}

function templateModelInfo(model: AcpProviderTemplateModel): ModelInfo {
  return {
    name: model.id || model.name,
    context_limit: model.contextLimit ?? 0,
    reasoning: model.capabilities?.reasoning ?? false,
  };
}

function providerDetails(entry: ProviderInventoryEntry): ProviderDetails {
  return {
    name: entry.providerId,
    is_configured: entry.configured,
    provider_type: providerType(entry.providerType),
    metadata: {
      name: entry.providerId,
      display_name: entry.providerName,
      description: entry.description,
      default_model: entry.defaultModel,
      known_models: entry.models.map(modelInfo),
      model_doc_link: '',
      model_selection_hint: entry.modelSelectionHint ?? null,
      config_keys: entry.configKeys.map(configKey),
      setup_steps: entry.setupSteps,
    },
  };
}

function setupCatalogProviderDetails(entry: AcpProviderSetupCatalogEntry): ProviderDetails {
  const fields = entry.fields ?? [];
  return {
    name: entry.providerId,
    is_configured: false,
    provider_type: 'Builtin',
    metadata: {
      name: entry.providerId,
      display_name: entry.name,
      description: entry.description || entry.name,
      default_model: '',
      known_models: [],
      model_doc_link: entry.docUrl ?? '',
      model_selection_hint: null,
      config_keys: fields.map((field, index) => setupConfigKey(field, index, entry.setupMethod)),
      setup_steps: entry.description ? [entry.description] : [],
    },
  };
}

function catalogTemplateProviderDetails(template: AcpProviderTemplate): ProviderDetails {
  const apiKeyConfig = template.envVar
    ? [{
        name: template.envVar,
        required: true,
        secret: true,
        default: null,
        oauth_flow: false,
        device_code_flow: false,
        primary: true,
      }]
    : [];
  const models = template.models.map(templateModelInfo);
  return {
    name: template.providerId,
    is_configured: false,
    provider_type: 'Custom',
    metadata: {
      name: template.providerId,
      display_name: template.name,
      description: template.apiUrl || template.name,
      default_model: models[0]?.name ?? '',
      known_models: models,
      model_doc_link: template.docUrl,
      model_selection_hint: null,
      config_keys: apiKeyConfig,
      setup_steps: template.docUrl ? [template.docUrl] : [],
    },
  };
}

function mergeProviderDetails(primary: ProviderDetails[], fallback: ProviderDetails[]): ProviderDetails[] {
  const byName = new Map<string, ProviderDetails>();
  for (const provider of fallback) {
    byName.set(provider.name, provider);
  }
  for (const provider of primary) {
    byName.set(provider.name, provider);
  }
  return Array.from(byName.values()).sort((a, b) =>
    (a.metadata.display_name || a.name).localeCompare(b.metadata.display_name || b.name)
  );
}

function providerCatalogEntry(entry: AcpProviderCatalogEntry): ProviderCatalogEntry {
  return {
    id: entry.providerId,
    name: entry.name,
    format: entry.format,
    api_url: entry.apiUrl,
    model_count: entry.modelCount,
    doc_url: entry.docUrl,
    env_var: entry.envVar,
  };
}

function modelTemplate(model: AcpProviderTemplateModel): ModelTemplate {
  return {
    id: model.id,
    name: model.name,
    context_limit: model.contextLimit,
    deprecated: model.deprecated,
    capabilities: {
      tool_call: model.capabilities?.toolCall ?? false,
      reasoning: model.capabilities?.reasoning ?? false,
      attachment: model.capabilities?.attachment ?? false,
      temperature: model.capabilities?.temperature ?? false,
    },
  };
}

function providerTemplate(template: AcpProviderTemplate): ProviderTemplate {
  return {
    id: template.providerId,
    name: template.name,
    format: template.format,
    api_url: template.apiUrl,
    models: template.models.map(modelTemplate),
    supports_streaming: template.supportsStreaming,
    env_var: template.envVar,
    doc_url: template.docUrl,
  };
}

function acpErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message) {
    return error.message;
  }
  if (typeof error === 'string') {
    return error;
  }
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

function recordProviderInventoryEvent(name: string, detail?: string): void {
  const target = window as Window & {
    __epistemosGooseProviderInventoryEvents?: Array<{ name: string; detail?: string }>;
  };
  target.__epistemosGooseProviderInventoryEvents ??= [];
  target.__epistemosGooseProviderInventoryEvents.push({ name, detail });
  target.__epistemosGooseProviderInventoryEvents =
    target.__epistemosGooseProviderInventoryEvents.slice(-32);
}

let providerInventoryPromise: Promise<ProviderDetails[]> | null = null;
let providerInventoryCache: ProviderDetails[] | null = null;
let providerCatalogSurfacePromise: Promise<ProviderDetails[]> | null = null;
let providerCatalogSurfaceCache: ProviderDetails[] | null = null;
// Config-status (which providers are configured) is cached so the overlay does
// NOT issue a fresh providers/config/status on EVERY getAcpProviders call — that
// serialized behind the catalog template fetches on the shared ACP client and
// timed out, blocking routes from rendering. Invalidated on any config write so a
// freshly-entered key flips the green check on. Marker: epistemos-acp-config-status-cache.
let providerConfigStatusPromise: Promise<Map<string, boolean>> | null = null;
let providerConfigStatusCache: Map<string, boolean> | null = null;
function resetProviderConfigStatusCache(): void {
  providerConfigStatusCache = null;
  providerConfigStatusPromise = null;
}
async function loadProviderConfigStatus(): Promise<Map<string, boolean>> {
  if (providerConfigStatusCache) {
    return providerConfigStatusCache;
  }
  if (providerConfigStatusPromise) {
    return providerConfigStatusPromise;
  }
  providerConfigStatusPromise = (async () => {
    const statuses = await withAcpTimeout(
      readAcpProviderConfigStatuses([]),
      4000,
      'Goose ACP provider configured-status overlay'
    );
    const map = new Map(statuses.map((status) => [status.providerId, status.isConfigured]));
    providerConfigStatusCache = map;
    return map;
  })().catch((error: unknown) => {
    providerConfigStatusPromise = null;
    throw error;
  });
  void providerConfigStatusPromise.catch(() => {});
  return providerConfigStatusPromise;
}
const SHARED_ACP_PROVIDER_CLIENT_MARKER = 'shared-getAcpClient-provider-inventory';

function getProviderInventoryAcpClient(): ReturnType<typeof getAcpClient> {
  recordProviderInventoryEvent('client-mode', SHARED_ACP_PROVIDER_CLIENT_MARKER);
  return getAcpClient();
}

function getProviderCatalogAcpClient(): ReturnType<typeof getAcpClient> {
  recordProviderInventoryEvent('client-mode', SHARED_ACP_PROVIDER_CLIENT_MARKER);
  return getAcpClient();
}

async function withAcpTimeout<T>(
  promise: Promise<T>,
  milliseconds: number,
  label: string
): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      promise,
      new Promise<T>((_, reject) => {
        timer = setTimeout(
          () => reject(new Error(`${label} timed out after ${milliseconds}ms`)),
          milliseconds
        );
      }),
    ]);
  } finally {
    if (timer) {
      clearTimeout(timer);
    }
  }
}

function startProviderInventoryLoad(): Promise<ProviderDetails[]> {
  if (providerInventoryPromise) {
    return providerInventoryPromise;
  }

  recordProviderInventoryEvent('list-start');
  providerInventoryPromise = (async () => {
    const client = await withAcpTimeout(
      getProviderInventoryAcpClient(),
      8000,
      'Goose ACP client initialization for provider inventory'
    );
    recordProviderInventoryEvent('client-ready');
    const response = await withAcpTimeout(
      client.goose.providersList_unstable({ providerIds: [] }),
      12000,
      'Goose ACP provider inventory'
    );
    const entries = (response.entries ?? []) as ProviderInventoryEntry[];
    if (entries.length === 0) {
      throw new Error('Goose ACP provider inventory returned zero providers.');
    }
    recordProviderInventoryEvent('list-success', String(entries.length));
    providerInventoryCache = entries.map(providerDetails);
    return providerInventoryCache;
  })().catch((error: unknown) => {
    providerInventoryPromise = null;
    const message = acpErrorMessage(error);
    recordProviderInventoryEvent('list-error', message);
    throw new Error(`Goose ACP provider inventory failed: ${message}`);
  });
  void providerInventoryPromise.catch(() => {});
  return providerInventoryPromise;
}

async function loadProviderCatalogSurface(): Promise<ProviderDetails[]> {
  if (providerCatalogSurfaceCache) {
    return providerCatalogSurfaceCache;
  }
  if (providerCatalogSurfacePromise) {
    return providerCatalogSurfacePromise;
  }

  providerCatalogSurfacePromise = (async () => {
    recordProviderInventoryEvent('catalog-surface-start');
    const client = await withAcpTimeout(
      getProviderCatalogAcpClient(),
      8000,
      'Goose ACP client initialization for provider catalog'
    );
    const setupResponse = await withAcpTimeout(
      client.goose.providersSetupCatalogList_unstable({}),
      12000,
      'Goose ACP provider setup catalog'
    );
    const setupProviders = ((setupResponse.providers ?? []) as AcpProviderSetupCatalogEntry[])
      .map(setupCatalogProviderDetails);
    const catalogResponse = await withAcpTimeout(
      client.goose.providersCatalogList_unstable({}),
      12000,
      'Goose ACP provider catalog'
    );
    const catalogEntries = (catalogResponse.providers ?? []) as AcpProviderCatalogEntry[];
    let templateProviders: ProviderDetails[] = [];
    for (const entry of catalogEntries.slice(0, 8)) {
      try {
        const templateResponse = await withAcpTimeout(
          client.goose.providersCatalogTemplate_unstable({ providerId: entry.providerId }),
          8000,
          `Goose ACP provider catalog template for ${entry.providerId}`
        );
        templateProviders.push(catalogTemplateProviderDetails(templateResponse.template as AcpProviderTemplate));
      } catch (error: unknown) {
        recordProviderInventoryEvent('catalog-template-skip', `${entry.providerId}:${acpErrorMessage(error)}`);
      }
    }
    const merged = mergeProviderDetails(templateProviders, setupProviders);
    if (merged.length === 0) {
      throw new Error('Goose ACP provider catalogs returned zero providers.');
    }
    providerCatalogSurfaceCache = merged;
    recordProviderInventoryEvent('catalog-surface-success', String(merged.length));
    return merged;
  })().catch((error: unknown) => {
    providerCatalogSurfacePromise = null;
    const message = acpErrorMessage(error);
    recordProviderInventoryEvent('catalog-surface-error', message);
    throw new Error(`Goose ACP provider catalog surface failed: ${message}`);
  });
  void providerCatalogSurfacePromise.catch(() => {});
  return providerCatalogSurfacePromise;
}

// Overlay the LIVE per-provider configured status from Goose onto the roster.
// The catalog/setup surface builders intentionally start is_configured:false
// because Goose only reports "configured" via providers/config/status. Without
// this overlay every provider shows "Configure" (no green check) and
// SwitchModelModal.filter(p => p.is_configured) returns an empty provider list,
// so no model can be picked. Fetched fresh each call so a freshly-entered key
// flips the green check on immediately. 100% live from Goose; on any failure we
// fall back to the un-overlaid roster (marker: config-status-overlay).
async function overlayConfiguredStatus(providers: ProviderDetails[]): Promise<ProviderDetails[]> {
  try {
    const byId = await loadProviderConfigStatus();
    if (byId.size === 0) {
      return providers;
    }
    let overlaid = 0;
    const merged = providers.map((provider) => {
      const configured = byId.get(provider.name);
      if (configured === undefined || configured === provider.is_configured) {
        return provider;
      }
      overlaid += 1;
      return { ...provider, is_configured: configured };
    });
    recordProviderInventoryEvent('config-status-overlay', String(overlaid));
    return merged;
  } catch (error: unknown) {
    recordProviderInventoryEvent('config-status-overlay-error', acpErrorMessage(error));
    return providers;
  }
}

async function getAcpProvidersBase(): Promise<ProviderDetails[]> {
  if (providerInventoryCache) {
    return providerInventoryCache;
  }
  if (providerCatalogSurfaceCache) {
    return providerCatalogSurfaceCache;
  }

  try {
    const catalogSurface = await loadProviderCatalogSurface();
    if (providerInventoryCache) {
      return providerInventoryCache;
    }
    return catalogSurface;
  } catch (catalogError: unknown) {
    recordProviderInventoryEvent('catalog-first-error', acpErrorMessage(catalogError));
    const inventory = startProviderInventoryLoad();
    const fastInventory = await withAcpTimeout(
      inventory.then((providers) => providers as ProviderDetails[] | null),
      3500,
      'Goose ACP provider inventory fast path'
    ).catch((error: unknown) => {
      recordProviderInventoryEvent('list-deferred', acpErrorMessage(error));
      return null;
    });
    if (fastInventory && fastInventory.length > 0) {
      return fastInventory;
    }
    if (providerInventoryCache) {
      return providerInventoryCache;
    }
    return await inventory;
  }
}

export async function getAcpProviders(): Promise<ProviderDetails[]> {
  const base = await getAcpProvidersBase();
  return overlayConfiguredStatus(base);
}

export async function listAcpProviderCatalog(format?: string | null): Promise<ProviderCatalogEntry[]> {
  try {
    const client = await getProviderCatalogAcpClient();
    const response = await client.goose.providersCatalogList_unstable({
      format: format || undefined,
    });
    return ((response.providers ?? []) as AcpProviderCatalogEntry[]).map(providerCatalogEntry);
  } catch (error: unknown) {
    throw new Error(`Goose ACP provider catalog list failed: ${acpErrorMessage(error)}`);
  }
}

export async function readAcpProviderCatalogTemplate(providerId: string): Promise<ProviderTemplate> {
  try {
    const client = await getProviderCatalogAcpClient();
    const response = await client.goose.providersCatalogTemplate_unstable({ providerId });
    return providerTemplate(response.template as AcpProviderTemplate);
  } catch (error: unknown) {
    throw new Error(`Goose ACP provider catalog template failed: ${acpErrorMessage(error)}`);
  }
}

export async function readAcpProviderConfigFields(
  providerId: string
): Promise<ProviderConfigFieldValue[]> {
  const client = await getAcpClient();
  const response = await client.goose.providersConfigRead_unstable({ providerId });
  return (response.fields ?? []) as ProviderConfigFieldValue[];
}

export async function readAcpProviderConfigStatuses(
  providerIds: string[] = []
): Promise<ProviderConfigStatus[]> {
  const client = await getAcpClient();
  const response = await client.goose.providersConfigStatus_unstable({ providerIds });
  return (response.statuses ?? []) as ProviderConfigStatus[];
}

type AcpDictationProviderStatus = {
  configured: boolean;
  host?: string | null;
  description: string;
  usesProviderConfig: boolean;
  settingsPath?: string | null;
  configKey?: string | null;
  defaultModel?: string | null;
  selectedModel?: string | null;
};

function dictationProviderStatus(entry: AcpDictationProviderStatus): DictationProviderStatus {
  return {
    configured: entry.configured,
    description: entry.description,
    host: entry.host ?? null,
    settings_path: entry.settingsPath ?? null,
    config_key: entry.configKey ?? null,
    uses_provider_config: entry.usesProviderConfig,
  };
}

export async function readAcpDictationConfig(): Promise<Record<string, DictationProviderStatus>> {
  const client = await getAcpClient();
  const response = await client.goose.dictationConfig_unstable({}); // epistemos-acp-dictation-config
  const entries = (response.providers ?? {}) as Record<string, AcpDictationProviderStatus>;
  return Object.fromEntries(
    Object.entries(entries).map(([provider, status]) => [provider, dictationProviderStatus(status)])
  );
}

export async function transcribeAcpDictation(
  audio: string,
  mimeType: string,
  provider: string
): Promise<string> {
  const client = await getAcpClient();
  const response = await client.goose.dictationTranscribe_unstable({
    audio,
    mimeType,
    provider,
  }); // epistemos-acp-dictation-transcribe
  return response.text ?? '';
}

export async function saveAcpDictationSecret(provider: string, value: string): Promise<void> {
  const client = await getAcpClient();
  await client.goose.dictationSecretSave_unstable({ provider, value }); // epistemos-acp-dictation-secret-save
}

export async function deleteAcpDictationSecret(provider: string): Promise<void> {
  const client = await getAcpClient();
  await client.goose.dictationSecretDelete_unstable({ provider }); // epistemos-acp-dictation-secret-delete
}

type AcpDictationLocalModelStatus = {
  id: string;
  label?: string;
  description: string;
  sizeMb: number;
  downloaded: boolean;
  downloadInProgress: boolean;
};

type AcpDictationDownloadProgress = {
  bytesDownloaded: number;
  totalBytes: number;
  progressPercent: number;
  status: string;
  error?: string | null;
};

function dictationModel(model: AcpDictationLocalModelStatus): WhisperModelResponse {
  return {
    id: model.id,
    description: model.description,
    size_mb: model.sizeMb,
    url: '',
    downloaded: model.downloaded,
    recommended: false,
  };
}

function dictationDownloadProgress(
  modelId: string,
  progress: AcpDictationDownloadProgress
): DownloadProgress {
  return {
    model_id: modelId,
    bytes_downloaded: progress.bytesDownloaded,
    total_bytes: progress.totalBytes,
    progress_percent: progress.progressPercent,
    status: progress.status as DownloadProgress['status'],
    error: progress.error ?? null,
  };
}

export async function listAcpDictationModels(): Promise<WhisperModelResponse[]> {
  const client = await getAcpClient();
  const response = await client.goose.dictationModelsList_unstable({}); // epistemos-acp-dictation-models-list
  return ((response.models ?? []) as AcpDictationLocalModelStatus[]).map(dictationModel);
}

export async function startAcpDictationModelDownload(modelId: string): Promise<void> {
  const client = await getAcpClient();
  await client.goose.dictationModelsDownload_unstable({ modelId }); // epistemos-acp-dictation-model-download
}

export async function readAcpDictationModelDownloadProgress(
  modelId: string
): Promise<DownloadProgress | null> {
  const client = await getAcpClient();
  const response = await client.goose.dictationModelsDownloadProgress_unstable({ modelId });
  const progress = response.progress as AcpDictationDownloadProgress | null | undefined;
  return progress ? dictationDownloadProgress(modelId, progress) : null;
}

export async function cancelAcpDictationModelDownload(modelId: string): Promise<void> {
  const client = await getAcpClient();
  await client.goose.dictationModelsCancel_unstable({ modelId }); // epistemos-acp-dictation-model-cancel
}

export async function deleteAcpDictationModel(modelId: string): Promise<void> {
  const client = await getAcpClient();
  await client.goose.dictationModelsDelete_unstable({ modelId }); // epistemos-acp-dictation-model-delete
}

export async function selectAcpDictationModel(provider: string, modelId: string): Promise<void> {
  const client = await getAcpClient();
  await client.goose.dictationModelsSelect_unstable({ provider, modelId }); // epistemos-acp-dictation-model-select
}

export async function readAcpDictationSelectedModel(provider: string): Promise<string | null> {
  const client = await getAcpClient();
  const response = await client.goose.dictationConfig_unstable({});
  const entry = ((response.providers ?? {}) as Record<string, AcpDictationProviderStatus>)[provider];
  return entry?.selectedModel ?? entry?.defaultModel ?? null;
}

async function providerForConfigKey(key: string): Promise<ProviderDetails> {
  const providers = await getAcpProviders();
  const matches = providers.filter((provider) =>
    provider.metadata.config_keys.some((configKey) => configKey.name === key)
  );
  if (matches.length === 1) {
    return matches[0];
  }
  if (matches.length > 1) {
    throw new Error(`Provider config key is ambiguous in ACP mode: ${key}`);
  }
  throw new Error(`Provider config key is not available through Goose ACP: ${key}`);
}

const localAcpConfigKeys = new Set([
  'GOOSE_MAX_TURNS',
  'GOOSE_MODE',
  'GOOSE_THINKING_EFFORT',
  'GOOSE_TELEMETRY_ENABLED',
  'LOCAL_WHISPER_MODEL',
  'SECURITY_COMMAND_CLASSIFIER_ENABLED',
  'SECURITY_COMMAND_CLASSIFIER_ENDPOINT',
  'SECURITY_COMMAND_CLASSIFIER_TOKEN',
  'SECURITY_PROMPT_CLASSIFIER_ENABLED',
  'SECURITY_PROMPT_CLASSIFIER_ENDPOINT',
  'SECURITY_PROMPT_CLASSIFIER_MODEL',
  'SECURITY_PROMPT_CLASSIFIER_TOKEN',
  'SECURITY_PROMPT_ENABLED',
  'SECURITY_PROMPT_THRESHOLD',
  'voice_dictation_preferred_mic',
  'voice_dictation_provider',
]);
const localAcpConfigValues = new Map<string, string>();
const localAcpConfigDefaults = new Map<string, string>([
  ['GOOSE_TELEMETRY_ENABLED', 'false'],
]);
const LOCAL_ACP_CONFIG_MARKER = 'local-acp-config-GOOSE_TELEMETRY_ENABLED';

function isLocalAcpConfigKey(key: string): boolean {
  void LOCAL_ACP_CONFIG_MARKER;
  return localAcpConfigKeys.has(key);
}

function localAcpConfigValue(key: string): string | null {
  if (localAcpConfigValues.has(key)) {
    return localAcpConfigValues.get(key) ?? null;
  }
  return localAcpConfigDefaults.get(key) ?? null;
}

function configValue(value: unknown): string {
  return typeof value === 'string' ? value : String(value);
}

// config_key -> Goose PreferenceKey wire string (camelCase). These keys persist
// LIVE via preferences/save+read so they survive restart and the agent actually
// applies them. Keys NOT here (GOOSE_MODE, GOOSE_MAX_TURNS, GOOSE_TELEMETRY_ENABLED,
// SECURITY_*) have no preference home in goose serve 1.39.0 and stay in the
// in-memory map. Marker: epistemos-acp-preference-backed-config.
const preferenceBackedConfigKeys: Record<string, PreferenceKey> = {
  GOOSE_THINKING_EFFORT: 'gooseThinkingEffort',
  GOOSE_AUTO_COMPACT_THRESHOLD: 'autoCompactThreshold',
  VOICE_DICTATION_PROVIDER: 'voiceDictationProvider',
  VOICE_DICTATION_PREFERRED_MIC: 'voiceDictationPreferredMic',
  voice_dictation_provider: 'voiceDictationProvider',
  voice_dictation_preferred_mic: 'voiceDictationPreferredMic',
};

async function savePreferenceConfig(key: string, value: unknown): Promise<void> {
  const prefKey = preferenceBackedConfigKeys[key];
  const client = await getAcpClient();
  await client.goose.preferencesSave_unstable({ values: [{ key: prefKey, value: configValue(value) }] });
}

async function readPreferenceConfig(key: string): Promise<string | null> {
  const prefKey = preferenceBackedConfigKeys[key];
  const client = await getAcpClient();
  const response = await withAcpTimeout(
    client.goose.preferencesRead_unstable({ keys: [prefKey] }),
    4000,
    'Goose ACP preference read'
  );
  const entry = ((response.values ?? []) as Array<{ key: string; value: unknown }>).find(
    (candidate) => candidate.key === prefKey
  );
  if (!entry || entry.value == null) {
    return null;
  }
  return typeof entry.value === 'string' ? entry.value : String(entry.value);
}

export async function readAcpProviderConfigValue(key: string): Promise<string | null> {
  if (key === 'GOOSE_PROVIDER' || key === 'GOOSE_DEFAULT_PROVIDER') {
    const defaults = await readAcpProviderDefaults();
    return defaults.providerId ?? null;
  }
  if (key === 'GOOSE_MODEL' || key === 'GOOSE_DEFAULT_MODEL') {
    const defaults = await readAcpProviderDefaults();
    return defaults.modelId ?? null;
  }
  if (key in preferenceBackedConfigKeys) {
    try {
      return await readPreferenceConfig(key);
    } catch {
      return localAcpConfigValue(key);
    }
  }
  if (isLocalAcpConfigKey(key)) {
    return localAcpConfigValue(key);
  }
  try {
    const provider = await providerForConfigKey(key);
    const fields = await readAcpProviderConfigFields(provider.name);
    const field = fields.find((entry) => entry.key === key);
    return field?.isSet ? field.value ?? null : null;
  } catch (error: unknown) {
    const message = acpErrorMessage(error);
    if (message.includes('Provider config key is not available through Goose ACP')) {
      return null;
    }
    throw error;
  }
}

// Reconstruct the ConfigContext config map from LIVE ACP sources. Upstream
// reloadConfig calls readAllConfig (dead REST in ACP mode -> config={}), which
// blanks the whole Settings config-driven UI (Chat/Security/Mode/etc.). We rebuild
// it from the app-local config values/defaults + the live provider/model defaults.
// 100% from Goose ACP + the local config the app owns; no hardcoded roster.
// Marker: epistemos-acp-config-map-reconstruct.
export async function reconstructAcpConfig(): Promise<Record<string, unknown>> {
  const config: Record<string, unknown> = {};
  for (const key of localAcpConfigKeys) {
    const value = localAcpConfigValue(key);
    if (value !== null) {
      config[key] = value;
    }
  }
  try {
    const client = await getAcpClient();
    const response = await withAcpTimeout(
      client.goose.preferencesRead_unstable({ keys: Object.values(preferenceBackedConfigKeys) }),
      4000,
      'Goose ACP preferences reconstruct'
    );
    const byPref = new Map(
      ((response.values ?? []) as Array<{ key: string; value: unknown }>).map((v) => [v.key, v.value])
    );
    for (const [configKey, prefKey] of Object.entries(preferenceBackedConfigKeys)) {
      const v = byPref.get(prefKey);
      if (v != null) {
        config[configKey] = typeof v === 'string' ? v : String(v);
      }
    }
  } catch {
    // Best-effort: persisted preferences overlay on top of the in-memory defaults.
  }
  try {
    const defaults = await readAcpProviderDefaults();
    if (defaults.providerId) {
      config['GOOSE_PROVIDER'] = defaults.providerId;
    }
    if (defaults.modelId) {
      config['GOOSE_MODEL'] = defaults.modelId;
    }
  } catch {
    // Best-effort: a missing default just leaves those keys unset.
  }
  return config;
}

export async function upsertAcpProviderConfig(
  key: string,
  value: unknown
): Promise<void> {
  if (
    key === 'GOOSE_PROVIDER' ||
    key === 'GOOSE_MODEL' ||
    key === 'GOOSE_DEFAULT_PROVIDER' ||
    key === 'GOOSE_DEFAULT_MODEL'
  ) {
    const defaults = await readAcpProviderDefaults();
    const isProviderKey = key === 'GOOSE_PROVIDER' || key === 'GOOSE_DEFAULT_PROVIDER';
    await saveAcpProviderDefaults(
      isProviderKey ? configValue(value) : defaults.providerId ?? '',
      isProviderKey ? defaults.modelId ?? null : configValue(value)
    );
    return;
  }
  if (key in preferenceBackedConfigKeys) {
    await savePreferenceConfig(key, value);
    return;
  }
  if (isLocalAcpConfigKey(key)) {
    localAcpConfigValues.set(key, configValue(value));
    return;
  }
  const provider = await providerForConfigKey(key);
  await saveAcpProviderConfig(provider.name, [{ key, value }]);
}

export async function saveAcpProviderConfig(
  providerId: string,
  fields: ProviderConfigFieldUpdate[]
): Promise<void> {
  if (fields.length === 0) {
    return;
  }
  const client = await getAcpClient();
  await client.goose.providersConfigSave_unstable({
    providerId,
    fields: fields.map((field) => ({ key: field.key, value: configValue(field.value) })),
  });
  resetProviderConfigStatusCache();
}

export async function removeAcpProviderConfig(key: string): Promise<void> {
  if (
    key === 'GOOSE_PROVIDER' ||
    key === 'GOOSE_MODEL' ||
    key === 'GOOSE_DEFAULT_PROVIDER' ||
    key === 'GOOSE_DEFAULT_MODEL'
  ) {
    return;
  }
  if (isLocalAcpConfigKey(key)) {
    localAcpConfigValues.delete(key);
    return;
  }
  const provider = await providerForConfigKey(key);
  await deleteAcpProviderConfig(provider.name);
}

export async function deleteAcpProviderConfig(providerId: string): Promise<void> {
  const client = await getAcpClient();
  await client.goose.providersConfigDelete_unstable({ providerId });
  resetProviderConfigStatusCache();
}

export async function authenticateAcpProviderConfig(providerId: string): Promise<void> {
  const client = await getAcpClient();
  await client.goose.providersConfigAuthenticate_unstable({ providerId });
}

// epistemos-acp-session-tools: the REST /agent/tools (getTools) 404s on the lean
// ACP `goose serve`. The live ACP toolsList_unstable({sessionId}) returns ALL the
// session's tools; scope to one extension by the `{extension}__{tool}` name prefix
// (extension_manager.rs) when an extensionName is given. If the prefix matches
// nothing (display-name vs registered-name casing, or an unprefixed extension) we
// fall back to the full list, so callers never get a worse result than the REST
// path they replace.
export async function listAcpSessionTools(
  sessionId: string,
  extensionName?: string
): Promise<ToolInfo[]> {
  const client = await getAcpClient();
  const response = await client.goose.toolsList_unstable({ sessionId });
  const all = (response.tools ?? []) as ToolInfo[];
  if (!extensionName) {
    return all;
  }
  const prefix = `${extensionName}__`;
  const scoped = all.filter(
    (tool) => typeof tool?.name === 'string' && tool.name.startsWith(prefix)
  );
  return scoped.length > 0 ? scoped : all;
}

type AcpMcpResourceContent = {
  uri?: string;
  text?: string;
  blob?: string;
  mimeType?: string | null;
  _meta?: Record<string, unknown> | null;
  meta?: Record<string, unknown> | null;
};

export type AcpMcpResource = {
  uri: string;
  text: string;
  mimeType?: string | null;
  _meta?: Record<string, unknown> | null;
};

export async function readAcpSessionResource(
  sessionId: string,
  uri: string,
  extensionName: string
): Promise<AcpMcpResource | null> {
  const client = await getAcpClient();
  const response = await client.goose.resourcesRead_unstable({
    sessionId,
    uri,
    extensionName,
  }); // epistemos-acp-mcp-resource-read
  const result = response.result as { contents?: AcpMcpResourceContent[] } | null | undefined;
  const content = result?.contents?.[0];
  if (!content) {
    return null;
  }
  const text =
    typeof content.text === 'string'
      ? content.text
      : typeof content.blob === 'string'
        ? globalThis.atob(content.blob)
        : '';
  return {
    uri: content.uri || uri,
    text,
    mimeType: content.mimeType ?? null,
    _meta: content._meta ?? content.meta ?? null,
  };
}

export async function callAcpSessionTool(
  sessionId: string,
  name: string,
  args: Record<string, unknown>
): Promise<{
  content: unknown[];
  isError: boolean;
  structuredContent?: unknown;
  _meta?: unknown;
}> {
  const client = await getAcpClient();
  const response = await client.goose.toolsCall_unstable({
    sessionId,
    name,
    arguments: args,
  }); // epistemos-acp-mcp-tool-call
  return {
    content: response.content ?? [],
    isError: response.isError,
    structuredContent: response.structuredContent,
    _meta: response._meta,
  };
}

// Custom-provider create/read/update/delete bridged onto the live ACP methods
// (providersCustom*_unstable). The upstream desktop UI hits the dead REST
// /config/custom-providers, which does not exist in ACP mode, so adding or
// editing a custom provider threw with no surfaced error. Map the desktop
// snake_case request body onto the ACP camelCase wire shape, and map the ACP
// read DTO back into the REST DeclarativeProviderConfig shape the edit form
// already consumes. Marker: epistemos-acp-custom-provider-crud.
function customProviderAcpPayload(data: UpdateCustomProviderRequest) {
  return {
    engine: data.engine,
    displayName: data.display_name,
    apiUrl: data.api_url,
    apiKey: data.api_key ?? null,
    models: data.models ?? [],
    supportsStreaming: data.supports_streaming ?? null,
    headers: data.headers ?? undefined,
    requiresAuth: data.requires_auth ?? false,
    catalogProviderId: data.catalog_provider_id ?? null,
    basePath: data.base_path ?? null,
    preservesThinking: data.preserves_thinking ?? null,
  };
}

export async function createAcpCustomProvider(data: UpdateCustomProviderRequest): Promise<string> {
  const client = await getAcpClient();
  const response = await client.goose.providersCustomCreate_unstable(customProviderAcpPayload(data));
  resetProviderConfigStatusCache();
  return response.providerId;
}

export async function updateAcpCustomProvider(
  providerId: string,
  data: UpdateCustomProviderRequest
): Promise<string> {
  const client = await getAcpClient();
  const response = await client.goose.providersCustomUpdate_unstable({
    providerId,
    ...customProviderAcpPayload(data),
  });
  resetProviderConfigStatusCache();
  return response.providerId;
}

export async function deleteAcpCustomProvider(providerId: string): Promise<void> {
  const client = await getAcpClient();
  await client.goose.providersCustomDelete_unstable({ providerId });
  resetProviderConfigStatusCache();
}

export async function readAcpCustomProvider(
  providerId: string
): Promise<{ config: DeclarativeProviderConfig; is_editable: boolean }> {
  const client = await getAcpClient();
  const response = await client.goose.providersCustomRead_unstable({ providerId });
  const dto = response.provider;
  const config = {
    engine: dto.engine,
    display_name: dto.displayName,
    base_url: dto.apiUrl,
    base_path: dto.basePath ?? null,
    catalog_provider_id: dto.catalogProviderId ?? null,
    supports_streaming: dto.supportsStreaming ?? null,
    requires_auth: dto.requiresAuth,
    headers: dto.headers ?? undefined,
    models: (dto.models ?? []).map((name) => ({ name })),
  } as unknown as DeclarativeProviderConfig;
  return { config, is_editable: response.editable };
}

export async function listAcpProviderModels(providerId: string): Promise<ModelInfo[]> {
  const client = await getAcpClient();
  // Prefer the provider INVENTORY (providers/list), whose models carry live
  // per-model capabilities (reasoning) + context_limit from Goose's canonical
  // model registry. The supported-models list returns names ONLY (no
  // capabilities), so it cannot drive the Thinking Effort selector (gated on
  // reasoning===true) or the context-window indicator denominator. Marker:
  // epistemos-acp-inventory-model-capabilities.
  try {
    const inventory = await client.goose.providersList_unstable({ providerIds: [providerId] });
    const entries = (inventory.entries ?? []) as ProviderInventoryEntry[];
    const entry = entries.find((candidate) => candidate.providerId === providerId) ?? entries[0];
    const models = (entry?.models ?? []).map(modelInfo);
    if (models.length > 0) {
      return models;
    }
  } catch (error: unknown) {
    recordProviderInventoryEvent('inventory-models-error', `${providerId}:${acpErrorMessage(error)}`);
  }
  // Fallback: capability-less supported-models name list if the inventory is empty.
  const response = await client.goose.providersSupportedModelsList_unstable({ providerId });
  return ((response.models ?? []) as string[]).map((model) => ({
    name: model,
    context_limit: 0,
    reasoning: false,
  }));
}

function acpProviderSecret(provider: ProviderDetails, key: ConfigKey, field: ProviderConfigFieldValue): ProviderSecret {
  const displayName = provider.metadata.display_name || provider.name;
  const isSet = Boolean(field.isSet);
  return {
    id: `acp_provider_config:${provider.name}:${key.name}`,
    provider: provider.name,
    provider_display_name: displayName,
    name: key.name,
    storage: 'secret_store',
    expires_at: null,
    status: 'unknown',
    configured: isSet,
    has_secret: isSet,
    can_delete: true,
    can_configure: Boolean(key.oauth_flow || key.device_code_flow),
    configure_provider: key.oauth_flow || key.device_code_flow ? provider.name : null,
  };
}

export async function listAcpProviderSecrets(): Promise<ProviderSecret[]> {
  const providers = await getAcpProviders();
  const secretProviders = providers.filter((provider) =>
    provider.metadata.config_keys.some((key) => key.secret)
  );
  if (secretProviders.length === 0) {
    return [];
  }

  let configuredProviderIds = new Set<string>();
  try {
    const statuses = await readAcpProviderConfigStatuses(secretProviders.map((provider) => provider.name));
    configuredProviderIds = new Set(
      statuses.filter((status) => status.isConfigured).map((status) => status.providerId)
    );
    recordProviderInventoryEvent('credential-status', String(configuredProviderIds.size));
  } catch (error: unknown) {
    recordProviderInventoryEvent('credential-status-error', acpErrorMessage(error));
    return [];
  }

  const secrets: ProviderSecret[] = [];
  for (const provider of secretProviders) {
    if (!configuredProviderIds.has(provider.name)) {
      continue;
    }
    const secretKeys = provider.metadata.config_keys.filter((key) => key.secret);
    try {
      const fields = await readAcpProviderConfigFields(provider.name);
      for (const key of secretKeys) {
        const field = fields.find((entry) => entry.key === key.name);
        if (field?.isSet) {
          secrets.push(acpProviderSecret(provider, key, field));
        }
      }
    } catch (error: unknown) {
      recordProviderInventoryEvent('credential-skip', `${provider.name}:${acpErrorMessage(error)}`);
    }
  }
  return secrets.sort((a, b) =>
    a.provider_display_name.localeCompare(b.provider_display_name) || a.name.localeCompare(b.name)
  );
}

export async function validateAcpProviderModels(providerId: string): Promise<void> {
  const models = await listAcpProviderModels(providerId);
  if (models.length === 0) {
    throw new Error(`Goose ACP supported model inventory returned zero models for ${providerId}.`);
  }
}

export async function readAcpProviderDefaults(): Promise<{
  providerId?: string | null;
  modelId?: string | null;
}> {
  const client = await getAcpClient();
  return await client.goose.defaultsRead_unstable({});
}

export async function saveAcpProviderDefaults(
  providerId: string,
  modelId?: string | null
): Promise<{
  providerId?: string | null;
  modelId?: string | null;
}> {
  const client = await getAcpClient();
  return await client.goose.defaultsSave_unstable({
    providerId,
    modelId: modelId || undefined,
  });
}

export async function saveAcpSessionModel(sessionId: string, modelId: string): Promise<void> {
  const client = await getAcpClient();
  await client.setSessionConfigOption({ sessionId, configId: 'model', value: modelId });
}

export async function saveAcpSessionProvider(sessionId: string, providerId: string): Promise<void> {
  const client = await getAcpClient();
  await client.setSessionConfigOption({ sessionId, configId: 'provider', value: providerId });
}

export async function saveAcpSessionThinkingEffort(sessionId: string, effort: string): Promise<void> {
  const client = await getAcpClient();
  await client.setSessionConfigOption({ sessionId, configId: 'thinking_effort', value: effort });
}

export async function saveAcpSessionMode(sessionId: string, mode: string): Promise<void> {
  const client = await getAcpClient();
  await client.setSessionConfigOption({ sessionId, configId: 'mode', value: mode });
}
TS

ACP_CONNECTION="$WORK_ROOT/ui/desktop/src/acp/acpConnection.ts"
node - "$ACP_CONNECTION" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

if (!source.includes('__epistemosGooseACPRequestSerialization')) {
  const stateAnchor = `let clientPromise: Promise<GooseClient> | null = null;
let resolvedClient: GooseClient | null = null;
`;
  const serializedState = `${stateAnchor}
const EPISTEMOS_ACP_SERIALIZATION_MARKER = '__epistemosGooseACPRequestSerialization';

function recordSerializedACPRequest(name: string, phase: string): void {
  const state = window as unknown as {
    __epistemosGooseACPRequestSerialization?: Array<{ name: string; phase: string; at: number }>;
  };
  const events = state.__epistemosGooseACPRequestSerialization || [];
  events.push({ name, phase, at: Date.now() });
  while (events.length > 120) events.shift();
  state.__epistemosGooseACPRequestSerialization = events;
  void EPISTEMOS_ACP_SERIALIZATION_MARKER;
}

function serializeACPRequests(client: GooseClient): GooseClient {
  let queue = Promise.resolve();
  // epistemos-acp-stop-bypass (#11): turn-scoped interrupt + long-running turn calls must NOT
  // queue behind the single FIFO, otherwise Stop (cancel) / steer are dead while a prompt() is
  // in flight (prompt does not resolve until end_turn). These issue immediately on the connection.
  const callACPImmediate = (fn: Function, thisArg: object, args: unknown[], name: string): unknown => {
    recordSerializedACPRequest(name, 'start');
    const result = Reflect.apply(fn, thisArg, args);
    Promise.resolve(result).then(
      () => recordSerializedACPRequest(name, 'success'),
      () => recordSerializedACPRequest(name, 'error')
    );
    return result;
  };
  const proxiedGoose = new Proxy(client.goose as object, {
    get(target, property, receiver) {
      const value = Reflect.get(target, property, receiver);
      if (typeof value !== 'function') return value;
      return (...args: unknown[]) => {
        const name = \`goose.\${String(property)}\`;
        if (String(property) === 'sessionSteer_unstable') {
          return callACPImmediate(value, target, args, name);
        }
        const response = queue.then(
          () => {
            recordSerializedACPRequest(name, 'start');
            return Reflect.apply(value, target, args);
          },
          () => {
            recordSerializedACPRequest(name, 'start');
            return Reflect.apply(value, target, args);
          }
        );
        queue = Promise.resolve(response).then(
          () => recordSerializedACPRequest(name, 'success'),
          () => recordSerializedACPRequest(name, 'error')
        );
        return response;
      };
    },
  });

  return new Proxy(client as object, {
    get(target, property, receiver) {
      if (property === 'goose') return proxiedGoose;
      const value = Reflect.get(target, property, receiver);
      if (typeof value !== 'function') return value;
      return (...args: unknown[]) => {
        const name = String(property);
        if (name === 'prompt' || name === 'cancel') {
          return callACPImmediate(value, target, args, name);
        }
        const response = queue.then(
          () => {
            recordSerializedACPRequest(name, 'start');
            return Reflect.apply(value, target, args);
          },
          () => {
            recordSerializedACPRequest(name, 'start');
            return Reflect.apply(value, target, args);
          }
        );
        queue = Promise.resolve(response).then(
          () => recordSerializedACPRequest(name, 'success'),
          () => recordSerializedACPRequest(name, 'error')
        );
        return response;
      };
    },
  }) as GooseClient;
}
`;
  if (!source.includes(stateAnchor)) {
    throw new Error('ACP connection state anchor not found');
  }
  source = source.replace(stateAnchor, serializedState);
  const returnAnchor = `  monitorConnection(client);
  return client;
`;
  const returnReplacement = `  monitorConnection(client);
  return serializeACPRequests(client);
`;
  if (!source.includes(returnAnchor)) {
    throw new Error('ACP connection return anchor not found');
  }
  source = source.replace(returnAnchor, returnReplacement);
  const getClientAnchor = `export async function getAcpClient(): Promise<GooseClient> {
`;
  fs.writeFileSync(path, source);
}

NODE

CONFIG_CONTEXT="$WORK_ROOT/ui/desktop/src/components/ConfigContext.tsx"
node - "$CONFIG_CONTEXT" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

function replaceRequired(label, pattern, replacement) {
  const next = source.replace(pattern, replacement);
  if (next === source) {
    throw new Error(`ConfigContext ${label} replacement not applied`);
  }
  source = next;
}

const importAnchor = "import { readAllConfig, readConfig, removeConfig, upsertConfig, providers } from '../api';";
const imports = `${importAnchor}
import { USE_ACP_CHAT } from '../acpChatFeatureFlag';
import {
  getAcpProviders,
  readAcpProviderConfigValue,
  reconstructAcpConfig,
  removeAcpProviderConfig,
  upsertAcpProviderConfig,
} from '../acp/providers';`;
if (!source.includes("getAcpProviders")) {
  if (!source.includes(importAnchor)) {
    throw new Error('ConfigContext API import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

replaceRequired(
  'ACP config map reconstruction',
  `    const response = await readAllConfig();
    setConfig(response.data?.config || {});`,
  `    if (USE_ACP_CHAT) {
      setConfig(await reconstructAcpConfig());
      return;
    }
    const response = await readAllConfig();
    setConfig(response.data?.config || {});`
);

replaceRequired(
  'provider catalog ACP branch',
  /const response = await providers\(\);\s*const providersData = response\.data \|\| \[\];/,
  `const providersData = USE_ACP_CHAT
          ? await getAcpProviders()
          : (await providers()).data || [];`
);

replaceRequired(
  'initial provider catalog ACP branch',
  /const providersResponse = await providers\(\);\s*const providersData = providersResponse\.data \|\| \[\];/,
  `const providersData = USE_ACP_CHAT
          ? await getAcpProviders()
          : (await providers()).data || [];`
);

const upsertAnchor = `      const query: UpsertConfigQuery = {
        key: key,
        value: value,
        is_secret: isSecret,
      };
      await upsertConfig({
        body: query,
      });
      await reloadConfig();`;
const upsertReplacement = `      if (USE_ACP_CHAT) {
        await upsertAcpProviderConfig(key, value);
        await reloadConfig();
        return;
      }
      const query: UpsertConfigQuery = {
        key: key,
        value: value,
        is_secret: isSecret,
      };
      await upsertConfig({
        body: query,
      });
      await reloadConfig();`;
replaceRequired('provider config save ACP branch', upsertAnchor, upsertReplacement);

const readAnchor = `      const query: ConfigKeyQuery = { key: key, is_secret: is_secret };
      const response = await readConfig({
        body: query,
      });
      if (options?.throwOnError && response.error) {
        throw response.error;
      }
      return response.data;`;
const readReplacement = `      if (USE_ACP_CHAT) {
        return await readAcpProviderConfigValue(key);
      }
      const query: ConfigKeyQuery = { key: key, is_secret: is_secret };
      const response = await readConfig({
        body: query,
      });
      if (options?.throwOnError && response.error) {
        throw response.error;
      }
      return response.data;`;
replaceRequired('provider config read ACP branch', readAnchor, readReplacement);

const removeAnchor = `      const query: ConfigKeyQuery = { key: key, is_secret: is_secret };
      await removeConfig({
        body: query,
      });
      await reloadConfig();`;
const removeReplacement = `      if (USE_ACP_CHAT) {
        await removeAcpProviderConfig(key);
        await reloadConfig();
        return;
      }
      const query: ConfigKeyQuery = { key: key, is_secret: is_secret };
      await removeConfig({
        body: query,
      });
      await reloadConfig();`;
replaceRequired('provider config delete ACP branch', removeAnchor, removeReplacement);

for (const snippet of [
  'await getAcpProviders()',
  'await upsertAcpProviderConfig(key, value)',
  'return await readAcpProviderConfigValue(key)',
  'await removeAcpProviderConfig(key)',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`ConfigContext staged source is missing required ACP provider snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

PROVIDER_SETTINGS_PAGE="$WORK_ROOT/ui/desktop/src/components/settings/providers/ProviderSettingsPage.tsx"
node - "$PROVIDER_SETTINGS_PAGE" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

function replaceRequired(label, pattern, replacement) {
  const next = source.replace(pattern, replacement);
  if (next === source) {
    throw new Error(`ProviderSettingsPage ${label} replacement not applied`);
  }
  source = next;
}

const importAnchor = "import { defineMessages, useIntl } from '../../../i18n';";
const imports = `${importAnchor}
import { USE_ACP_CHAT } from '../../../acpChatFeatureFlag';
import { getAcpProviders } from '../../../acp/providers';`;
if (!source.includes("../../../acp/providers")) {
  if (!source.includes(importAnchor)) {
    throw new Error('ProviderSettingsPage import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

replaceRequired(
  'provider error state',
  'const [providers, setProviders] = useState<ProviderDetails[]>([]);',
  `const [providers, setProviders] = useState<ProviderDetails[]>([]);
  const [providerLoadError, setProviderLoadError] = useState<string | null>(null);`
);

replaceRequired(
  'initial ACP provider load',
  'const result = await getProviders(!initialLoadDone.current);',
  `const result = USE_ACP_CHAT
        ? await getAcpProviders()
        : await getProviders(!initialLoadDone.current);`
);

replaceRequired(
  'clear provider load error',
  'try {\n      // Only force refresh when explicitly requested, not on initial load',
  `try {
      setProviderLoadError(null);
      // Only force refresh when explicitly requested, not on initial load`
);

replaceRequired(
  'visible provider load error',
  "console.error('Failed to load providers:', error);",
  `const message = error instanceof Error ? error.message : String(error);
      (window as Window & { __epistemosGooseProviderLoadError?: string }).__epistemosGooseProviderLoadError = message;
      setProviderLoadError(message);
      console.error('Failed to load providers:', error);`
);

replaceRequired(
  'refresh ACP provider load',
  'const result = await getProviders(true);',
  'const result = USE_ACP_CHAT ? await getAcpProviders() : await getProviders(true);'
);

replaceRequired(
  'render provider load error',
  'loading ? (\n                <div>{intl.formatMessage(i18n.loadingProviders)}</div>\n              ) : (',
  `loading ? (
                <div>{intl.formatMessage(i18n.loadingProviders)}</div>
              ) : providerLoadError ? (
                <div data-testid="provider-catalog-error">Provider catalog failed: {providerLoadError}</div>
              ) : (`
);

for (const snippet of [
  'import { getAcpProviders }',
  'USE_ACP_CHAT',
  'await getAcpProviders()',
  'providerLoadError',
  'Provider catalog failed:',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`ProviderSettingsPage staged source is missing required ACP provider snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

PROVIDER_CATALOG_PICKER="$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/ProviderCatalogPicker.tsx"
node - "$PROVIDER_CATALOG_PICKER" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

function replaceRequired(label, pattern, replacement) {
  const next = source.replace(pattern, replacement);
  if (next === source) {
    throw new Error(`ProviderCatalogPicker ${label} replacement not applied`);
  }
  source = next;
}

replaceRequired(
  'remove REST provider catalog API imports',
  `import {
  getProviderCatalog,
  getProviderCatalogTemplate,
  type ProviderCatalogEntry,
  type ProviderTemplate,
} from '../../../../../api';`,
  `import type {
  ProviderCatalogEntry,
  ProviderTemplate,
} from '../../../../../api';`
);

const importAnchor = "import { defineMessages, useIntl } from '../../../../../i18n';";
const imports = `${importAnchor}
import {
  listAcpProviderCatalog,
  readAcpProviderCatalogTemplate,
} from '../../../../../acp/providers';`;
if (!source.includes('readAcpProviderCatalogTemplate')) {
  if (!source.includes(importAnchor)) {
    throw new Error('ProviderCatalogPicker import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

if (!source.includes('function providerCatalogErrorMessage(error: unknown): string')) {
  replaceRequired(
    'provider catalog error helper',
    `interface ProviderCatalogPickerProps {
  onSelect: (template: ProviderTemplate) => void;
  onCancel: () => void;
  embedded?: boolean;
}
`,
    `interface ProviderCatalogPickerProps {
  onSelect: (template: ProviderTemplate) => void;
  onCancel: () => void;
  embedded?: boolean;
}

function providerCatalogErrorMessage(error: unknown): string {
  if (error && typeof error === 'object' && 'message' in error) {
    const message = (error as { message?: unknown }).message;
    if (typeof message === 'string' && message.length > 0) {
      return message;
    }
  }
  if (typeof error === 'string') {
    return error;
  }
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

function recordProviderCatalogEvent(name: string, detail?: string): void {
  const target = window as Window & {
    __epistemosGooseProviderCatalogEvents?: Array<{ name: string; detail?: string }>;
  };
  target.__epistemosGooseProviderCatalogEvents ??= [];
  target.__epistemosGooseProviderCatalogEvents.push({ name, detail });
  target.__epistemosGooseProviderCatalogEvents =
    target.__epistemosGooseProviderCatalogEvents.slice(-32);
}
`
  );
}

replaceRequired(
  'ACP provider catalog list',
  `      const { data } = await getProviderCatalog({
        query: { format },
        throwOnError: true,
      });
      setProviders(data || []);
      setFilteredProviders(data || []);`,
  `      recordProviderCatalogEvent('list-start', format);
      const data = await listAcpProviderCatalog(format);
      recordProviderCatalogEvent('list-success', String((data || []).length));
      setProviders(data || []);
      setFilteredProviders(data || []);`
);

replaceRequired(
  'ACP provider catalog template',
  `      const { data: template } = await getProviderCatalogTemplate({
        path: { id: providerId },
        throwOnError: true,
      });
      if (template) {
        onSelect(template);
      }`,
  `      recordProviderCatalogEvent('template-start', providerId);
      const template = await readAcpProviderCatalogTemplate(providerId);
      recordProviderCatalogEvent('template-success', providerId);
      if (template) {
        onSelect(template);
      }`
);

source = source.replaceAll(
  `err instanceof Error ? err.message : 'Unknown error'`,
  `providerCatalogErrorMessage(err)`
);

source = source.replaceAll(
  `    setError(null);`,
  `    setError(null);
    (window as Window & { __epistemosGooseProviderCatalogError?: string }).__epistemosGooseProviderCatalogError = undefined;`
);

source = source.replaceAll(
  `      setError(providerCatalogErrorMessage(err));`,
  `      const message = providerCatalogErrorMessage(err);
      recordProviderCatalogEvent('error', message);
      (window as Window & { __epistemosGooseProviderCatalogError?: string }).__epistemosGooseProviderCatalogError = message;
      console.error('Failed to load Goose ACP provider catalog:', err);
      setError(message);`
);

for (const snippet of [
  'const data = await listAcpProviderCatalog(format)',
  'const template = await readAcpProviderCatalogTemplate(providerId)',
  'import type {',
  'providerCatalogErrorMessage(err)',
  'recordProviderCatalogEvent',
  '__epistemosGooseProviderCatalogEvents',
  '__epistemosGooseProviderCatalogError',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`ProviderCatalogPicker staged source is missing required ACP catalog snippet: ${snippet}`);
  }
}

for (const forbiddenSnippet of [
  'getProviderCatalog({',
  'getProviderCatalogTemplate({',
]) {
  if (source.includes(forbiddenSnippet)) {
    throw new Error(`ProviderCatalogPicker staged source still contains REST catalog fallback: ${forbiddenSnippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

CUSTOM_PROVIDER_FORM="$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx"
node - "$CUSTOM_PROVIDER_FORM" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

const anchor = `<button
          type="button"
          onClick={() => setStep('catalog')}`;
const replacement = `<button
          type="button"
          data-testid="provider-catalog-template-choice"
          onClick={() => setStep('catalog')}`;
if (!source.includes('data-testid="provider-catalog-template-choice"')) {
  if (!source.includes(anchor)) {
    throw new Error('CustomProviderForm provider catalog choice anchor not found');
  }
  source = source.replace(anchor, replacement);
}

if (!source.includes('data-testid="provider-catalog-template-choice"')) {
  throw new Error('CustomProviderForm staged source is missing provider catalog choice test id');
}

fs.writeFileSync(path, source);
NODE

DEFAULT_SUBMIT_HANDLER="$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/handlers/DefaultSubmitHandler.tsx"
node - "$DEFAULT_SUBMIT_HANDLER" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

const importAnchor = "import { getProviderModels, readConfig } from '../../../../../../api';";
const imports = `${importAnchor}
import { USE_ACP_CHAT } from '../../../../../../acpChatFeatureFlag';
import {
  readAcpProviderConfigFields,
  readAcpProviderConfigValue,
  saveAcpProviderConfig,
  validateAcpProviderModels,
} from '../../../../../../acp/providers';`;
if (!source.includes('validateAcpProviderModels')) {
  if (!source.includes(importAnchor)) {
    throw new Error('DefaultSubmitHandler import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

const acpSubmitAnchor = `  const parameters = provider.metadata.config_keys || [];

`;
const acpSubmitReplacement = `  const parameters = provider.metadata.config_keys || [];

  if (USE_ACP_CHAT) {
    const fields = parameters.flatMap((parameter) => {
      if (!configValues[parameter.name] && !parameter.required) {
        return [];
      }
      const value =
        configValues[parameter.name] !== undefined
          ? configValues[parameter.name]
          : parameter.default;
      if (value === undefined || value === null) {
        return [];
      }
      return [{ key: parameter.name, value }];
    });
    const previousFields = (await readAcpProviderConfigFields(provider.name)).filter(
      (field) => field.isSet && !field.isSecret && field.value != null
    );

    if (fields.length > 0) {
      await saveAcpProviderConfig(provider.name, fields);
    }

    try {
      await validateAcpProviderModels(provider.name);
    } catch (error) {
      if (previousFields.length > 0) {
        await saveAcpProviderConfig(
          provider.name,
          previousFields.map((field) => ({ key: field.key, value: field.value ?? '' }))
        );
      }
      throw error;
    }
    return;
  }

`;
if (!source.includes('saveAcpProviderConfig(provider.name')) {
  if (!source.includes(acpSubmitAnchor)) {
    throw new Error('DefaultSubmitHandler submit anchor not found');
  }
  source = source.replace(acpSubmitAnchor, acpSubmitReplacement);
}

const readConfigAnchor = `        const currentValue = await readConfig({
          body: { key: param.name, is_secret: false },
        });
        if (currentValue.data) {
          previousConfigValues[param.name] = {
            value: currentValue.data,
            isSecret: false,
          };
        }`;
const readConfigReplacement = `        const currentValue = USE_ACP_CHAT
          ? await readAcpProviderConfigValue(param.name)
          : (await readConfig({
              body: { key: param.name, is_secret: false },
            })).data;
        if (currentValue) {
          previousConfigValues[param.name] = {
            value: currentValue,
            isSecret: false,
          };
        }`;
// epistemos-acp-graft-hardfail: upstream anchor drift must FAIL the build, not
// silently drop the ACP branch and revert to the (dead-in-ACP) REST endpoint.
if (!source.includes('readAcpProviderConfigValue(param.name)')) {
  if (!source.includes(readConfigAnchor)) {
    throw new Error('DefaultSubmitHandler readConfig ACP anchor not found (drift would silently revert to REST readConfig)');
  }
  source = source.replace(readConfigAnchor, readConfigReplacement);
}

const modelValidationAnchor = `    await getProviderModels({
      path: { name: provider.name },
      throwOnError: true,
    });`;
const modelValidationReplacement = `    if (USE_ACP_CHAT) {
      await validateAcpProviderModels(provider.name);
    } else {
      await getProviderModels({
        path: { name: provider.name },
        throwOnError: true,
      });
    }`;
if (!source.includes('validateAcpProviderModels(provider.name)')) {
  if (!source.includes(modelValidationAnchor)) {
    throw new Error('DefaultSubmitHandler getProviderModels ACP anchor not found (drift would silently revert to REST getProviderModels)');
  }
  source = source.replace(modelValidationAnchor, modelValidationReplacement);
}

fs.writeFileSync(path, source);
NODE

PROVIDER_CONFIG_MODAL="$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/ProviderConfigurationModal.tsx"
node - "$PROVIDER_CONFIG_MODAL" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

const importAnchor = "import { defineMessages, useIntl } from '../../../../i18n';";
const imports = `${importAnchor}
import { USE_ACP_CHAT } from '../../../../acpChatFeatureFlag';
import {
  authenticateAcpProviderConfig,
  deleteAcpProviderConfig,
  saveAcpProviderConfig,
} from '../../../../acp/providers';`;
if (!source.includes('authenticateAcpProviderConfig')) {
  if (!source.includes(importAnchor)) {
    throw new Error('ProviderConfigurationModal import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

const oauthConfigAnchor = `      if (hasConfig) {
        for (const key of configKeys) {
          const entry = configValues[key.name];
          const value =
            entry?.value ?? (typeof entry?.serverValue === 'string' ? entry.serverValue : null);
          if (value) {
            await upsert(key.name, value, key.secret);
          }
        }
      }`;
const oauthConfigReplacement = `      if (hasConfig) {
        const fields = configKeys.flatMap((key) => {
          const entry = configValues[key.name];
          const value =
            entry?.value ?? (typeof entry?.serverValue === 'string' ? entry.serverValue : null);
          return value ? [{ key: key.name, value }] : [];
        });
        if (USE_ACP_CHAT) {
          if (fields.length > 0) {
            await saveAcpProviderConfig(provider.name, fields);
          }
        } else {
          for (const field of fields) {
            const key = configKeys.find((configKey) => configKey.name === field.key);
            await upsert(field.key, field.value, key?.secret === true);
          }
        }
      }`;
if (!source.includes('saveAcpProviderConfig(provider.name, fields)')) {
  if (!source.includes(oauthConfigAnchor)) {
    throw new Error('ProviderConfigurationModal OAuth config anchor not found');
  }
  source = source.replace(oauthConfigAnchor, oauthConfigReplacement);
}

const oauthAnchor = `      const oauthResult = await configureProviderOauth({
        path: { name: provider.name },
      });
      if (oauthResult.error) {
        const err = oauthResult.error as Record<string, unknown>;
        const errDetail = typeof oauthResult.error === 'string'
          ? oauthResult.error
          : (err?.message as string) ?? (err?.detail as string) ?? JSON.stringify(oauthResult.error);
        throw new Error(errDetail);
      }`;
const oauthReplacement = `      if (USE_ACP_CHAT) {
        await authenticateAcpProviderConfig(provider.name);
      } else {
        const oauthResult = await configureProviderOauth({
          path: { name: provider.name },
        });
        if (oauthResult.error) {
          const err = oauthResult.error as Record<string, unknown>;
          const errDetail = typeof oauthResult.error === 'string'
            ? oauthResult.error
            : (err?.message as string) ?? (err?.detail as string) ?? JSON.stringify(oauthResult.error);
          throw new Error(errDetail);
        }
      }`;
if (!source.includes('await authenticateAcpProviderConfig(provider.name)')) {
  if (!source.includes(oauthAnchor)) {
    throw new Error('ProviderConfigurationModal OAuth ACP anchor not found (drift would silently revert to REST configureProviderOauth)');
  }
  source = source.replace(oauthAnchor, oauthReplacement);
}

const cleanupAnchor = `    // Clean up provider-specific cache files (e.g., OAuth tokens) before removing config
    try {
      await cleanupProviderCache({ path: { name: provider.name } });
    } catch {
      // Cleanup is best-effort — proceed with deletion even if it fails
    }

    const isCustomProvider = provider.provider_type === 'Custom';`;
const cleanupReplacement = `    if (USE_ACP_CHAT && provider.provider_type !== 'Custom') {
      await deleteAcpProviderConfig(provider.name);
      onClose();
      return;
    }

    // Clean up provider-specific cache files (e.g., OAuth tokens) before removing config
    try {
      await cleanupProviderCache({ path: { name: provider.name } });
    } catch {
      // Cleanup is best-effort — proceed with deletion even if it fails
    }

    const isCustomProvider = provider.provider_type === 'Custom';`;
if (!source.includes('await deleteAcpProviderConfig(provider.name)')) {
  if (!source.includes(cleanupAnchor)) {
    throw new Error('ProviderConfigurationModal delete-cleanup ACP anchor not found (drift would silently revert to REST cleanupProviderCache path)');
  }
  source = source.replace(cleanupAnchor, cleanupReplacement);
}

fs.writeFileSync(path, source);
NODE

ONBOARDING_PROVIDER_CONFIG="$WORK_ROOT/ui/desktop/src/components/onboarding/ProviderConfigForm.tsx"
node - "$ONBOARDING_PROVIDER_CONFIG" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

const importAnchor = "import { configureProviderOauth, ProviderDetails } from '../../api';";
const imports = `${importAnchor}
import { USE_ACP_CHAT } from '../../acpChatFeatureFlag';
import { authenticateAcpProviderConfig } from '../../acp/providers';`;
if (!source.includes('authenticateAcpProviderConfig')) {
  if (!source.includes(importAnchor)) {
    throw new Error('ProviderConfigForm import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

const oauthAnchor = `      await configureProviderOauth({
        path: { name: provider.name },
        throwOnError: true,
      });`;
const oauthReplacement = `      if (USE_ACP_CHAT) {
        await authenticateAcpProviderConfig(provider.name);
      } else {
        await configureProviderOauth({
          path: { name: provider.name },
          throwOnError: true,
        });
      }`;
if (!source.includes('await authenticateAcpProviderConfig(provider.name)')) {
  if (!source.includes(oauthAnchor)) {
    throw new Error('ProviderConfigForm onboarding OAuth ACP anchor not found (drift would silently revert to REST configureProviderOauth)');
  }
  source = source.replace(oauthAnchor, oauthReplacement);
}

fs.writeFileSync(path, source);
NODE

PROVIDER_GRID="$WORK_ROOT/ui/desktop/src/components/settings/providers/ProviderGrid.tsx"
node - "$PROVIDER_GRID" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

function replaceRequired(label, pattern, replacement) {
  const next = source.replace(pattern, replacement);
  if (next === source) {
    throw new Error(`ProviderGrid ${label} replacement not applied`);
  }
  source = next;
}

// epistemos-acp-custom-provider-crud: ProviderGrid is rendered by the
// (ACP-grafted) ProviderSettingsPage and manages custom providers via dead REST
// /config/custom-providers (get/create/update/remove), which 404s in ACP mode.
// Bridge each onto the live providersCustom*_unstable methods.
const importAnchor = `import {
  DeclarativeProviderConfig,
  ProviderDetails,
  UpdateCustomProviderRequest,
} from '../../../api';`;
const imports = `${importAnchor}
import { USE_ACP_CHAT } from '../../../acpChatFeatureFlag';
import {
  createAcpCustomProvider,
  deleteAcpCustomProvider,
  readAcpCustomProvider,
  updateAcpCustomProvider,
} from '../../../acp/providers';`;
if (!source.includes('createAcpCustomProvider')) {
  if (!source.includes(importAnchor)) {
    throw new Error('ProviderGrid import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

replaceRequired(
  'custom provider read',
  `        const { getCustomProvider } = await import('../../../api');
        const result = await getCustomProvider({ path: { id: provider.name }, throwOnError: true });`,
  `        const result = USE_ACP_CHAT
          ? { data: await readAcpCustomProvider(provider.name) }
          : await (await import('../../../api')).getCustomProvider({
              path: { id: provider.name },
              throwOnError: true,
            });`
);

replaceRequired(
  'custom provider update',
  `      const { updateCustomProvider } = await import('../../../api');
      await updateCustomProvider({
        path: { id: editingProvider.id },
        body: data,
        throwOnError: true,
      });`,
  `      if (USE_ACP_CHAT) {
        await updateAcpCustomProvider(editingProvider.id, data);
      } else {
        const { updateCustomProvider } = await import('../../../api');
        await updateCustomProvider({
          path: { id: editingProvider.id },
          body: data,
          throwOnError: true,
        });
      }`
);

replaceRequired(
  'custom provider delete',
  `    const { removeCustomProvider } = await import('../../../api');
    await removeCustomProvider({
      path: { id: editingProvider.id },
      throwOnError: true,
    });`,
  `    if (USE_ACP_CHAT) {
      await deleteAcpCustomProvider(editingProvider.id);
    } else {
      const { removeCustomProvider } = await import('../../../api');
      await removeCustomProvider({
        path: { id: editingProvider.id },
        throwOnError: true,
      });
    }`
);

replaceRequired(
  'custom provider create',
  `      const { createCustomProvider } = await import('../../../api');
      const result = await createCustomProvider({ body: data, throwOnError: true });
      const providerId = result.data?.provider_name;`,
  `      let providerId: string | undefined;
      if (USE_ACP_CHAT) {
        // epistemos-acp-custom-provider-crud
        providerId = await createAcpCustomProvider(data);
      } else {
        const { createCustomProvider } = await import('../../../api');
        const result = await createCustomProvider({ body: data, throwOnError: true });
        providerId = result.data?.provider_name;
      }`
);

for (const snippet of [
  'createAcpCustomProvider',
  'readAcpCustomProvider',
  'updateAcpCustomProvider',
  'deleteAcpCustomProvider',
  'epistemos-acp-custom-provider-crud',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`ProviderGrid staged source is missing required ACP snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

ONBOARDING_PROVIDER_SELECTOR="$WORK_ROOT/ui/desktop/src/components/onboarding/ProviderSelector.tsx"
node - "$ONBOARDING_PROVIDER_SELECTOR" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

// epistemos-acp-onboarding-provider-grid: the first-run welcome provider list
// (OnboardingGuard -> ProviderSelector) populated from the dead REST
// /config/providers, which does not exist in ACP mode -> fetchProviders threw and
// the provider dropdown rendered empty ("my app is not doing that at all"). Source
// it from the live ACP catalog instead, same as every other provider surface.
const importAnchor = `import {
  providers as fetchProviders,
  createCustomProvider,
  ProviderDetails,
  UpdateCustomProviderRequest,
} from '../../api';`;
const imports = `${importAnchor}
import { USE_ACP_CHAT } from '../../acpChatFeatureFlag';
import { createAcpCustomProvider, getAcpProviders } from '../../acp/providers';`;
if (!source.includes('getAcpProviders')) {
  if (!source.includes(importAnchor)) {
    throw new Error('ProviderSelector import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

// epistemos-acp-custom-provider-crud: the onboarding "Add a custom provider"
// submit also went through the dead REST createCustomProvider; bridge it onto ACP.
const createAnchor = `    const result = await createCustomProvider({ body: data, throwOnError: true });
    setShowCustomModal(false);
    if (result.data?.provider_name) {
      onConfigured(result.data.provider_name);
    }`;
const createReplacement = `    if (USE_ACP_CHAT) {
      const providerId = await createAcpCustomProvider(data);
      setShowCustomModal(false);
      if (providerId) {
        onConfigured(providerId);
      }
      return;
    }
    const result = await createCustomProvider({ body: data, throwOnError: true });
    setShowCustomModal(false);
    if (result.data?.provider_name) {
      onConfigured(result.data.provider_name);
    }`;
if (!source.includes('createAcpCustomProvider(data)')) {
  if (!source.includes(createAnchor)) {
    throw new Error('ProviderSelector create anchor not found');
  }
  source = source.replace(createAnchor, createReplacement);
}

const loadAnchor = `        const response = await fetchProviders({ throwOnError: true });
        if (response.data) {
          const list = Array.isArray(response.data)
            ? response.data
            : (response.data as { providers: ProviderDetails[] }).providers || [];
          setProviderList(list);
        }`;
const loadReplacement = `        if (USE_ACP_CHAT) {
          // epistemos-acp-onboarding-provider-grid
          setProviderList(await getAcpProviders());
          return;
        }
        const response = await fetchProviders({ throwOnError: true });
        if (response.data) {
          const list = Array.isArray(response.data)
            ? response.data
            : (response.data as { providers: ProviderDetails[] }).providers || [];
          setProviderList(list);
        }`;
if (!source.includes('epistemos-acp-onboarding-provider-grid')) {
  if (!source.includes(loadAnchor)) {
    throw new Error('ProviderSelector load anchor not found');
  }
  source = source.replace(loadAnchor, loadReplacement);
}

// epistemos-acp-hide-rest-free-onboarding: NanoGPT/Tetrate "free/local" setup
// cards call REST-only setup helpers. In ACP mode the supported path is the live
// provider catalog/config bridge above, so keep onboarding on Connect Provider
// and remove the dead free/local branch from the reachable UI.
const selectedPathAnchor = `  const [selectedPath, setSelectedPath] = useState<SelectedPath>(null);`;
const selectedPathReplacement = `  const [selectedPath, setSelectedPath] = useState<SelectedPath>(
    USE_ACP_CHAT ? OWN_PROVIDER : null
  );`;
if (!source.includes('USE_ACP_CHAT ? OWN_PROVIDER : null')) {
  if (!source.includes(selectedPathAnchor)) {
    throw new Error('ProviderSelector selectedPath anchor not found');
  }
  source = source.replace(selectedPathAnchor, selectedPathReplacement);
}

const gridAnchor = `      <div className="grid grid-cols-2 gap-2 mb-4">
        <div
          onClick={handleFreeCreditClick}`;
const gridReplacement = `      <div
        className={USE_ACP_CHAT ? 'grid grid-cols-1 gap-2 mb-4' : 'grid grid-cols-2 gap-2 mb-4'}
        data-epistemos-acp-hide-rest-free-onboarding="true"
      >
        {!USE_ACP_CHAT && (
        <div
          onClick={handleFreeCreditClick}`;
if (!source.includes('data-epistemos-acp-hide-rest-free-onboarding')) {
  if (!source.includes(gridAnchor)) {
    throw new Error('ProviderSelector free/local grid anchor not found');
  }
  source = source.replace(gridAnchor, gridReplacement);
}

const freeCardCloseAnchor = `          </p>
        </div>

        <div
          onClick={handleOwnProviderClick}`;
const freeCardCloseReplacement = `          </p>
        </div>
        )}

        <div
          onClick={handleOwnProviderClick}`;
if (!source.includes('        )}\n\n        <div\n          onClick={handleOwnProviderClick}')) {
  if (!source.includes(freeCardCloseAnchor)) {
    throw new Error('ProviderSelector free/local close anchor not found');
  }
  source = source.replace(freeCardCloseAnchor, freeCardCloseReplacement);
}

source = source.replace(
  '{selectedPath === FREE_OPTIONS && (',
  '{!USE_ACP_CHAT && selectedPath === FREE_OPTIONS && ('
);

for (const snippet of [
  'getAcpProviders',
  'USE_ACP_CHAT',
  'epistemos-acp-onboarding-provider-grid',
  'epistemos-acp-hide-rest-free-onboarding',
  'USE_ACP_CHAT ? OWN_PROVIDER : null',
  '!USE_ACP_CHAT && selectedPath === FREE_OPTIONS',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`ProviderSelector staged source is missing required ACP snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

ALERT_BOX="$WORK_ROOT/ui/desktop/src/components/alerts/AlertBox.tsx"
node - "$ALERT_BOX" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

// epistemos-acp-alertbox-threshold: saving an edited auto-compact threshold used the
// dead REST upsertConfig directly, which throws in ACP mode ("Failed to save
// threshold"). The component already reads via useConfig(); route the SAVE through
// the same already-ACP-wired ConfigContext.upsert, which persists
// GOOSE_AUTO_COMPACT_THRESHOLD through the live preferences path. Correct in both
// ACP and non-ACP modes; drop the now-unused dead-REST import.
const useConfigAnchor = 'const { read } = useConfig();';
if (source.includes(useConfigAnchor) && !source.includes('const { read, upsert } = useConfig();')) {
  source = source.replace(useConfigAnchor, 'const { read, upsert } = useConfig();');
}

const upsertAnchor = `await upsertConfig({
        body: {
          key: 'GOOSE_AUTO_COMPACT_THRESHOLD',
          value: newThreshold,
          is_secret: false,
        },
      });`;
const upsertReplacement = `await upsert('GOOSE_AUTO_COMPACT_THRESHOLD', newThreshold, false); // epistemos-acp-alertbox-threshold`;
if (!source.includes('epistemos-acp-alertbox-threshold')) {
  if (!source.includes(upsertAnchor)) {
    throw new Error('AlertBox threshold upsertConfig anchor not found');
  }
  source = source.replace(upsertAnchor, upsertReplacement);
}

// Remove the now-unused dead-REST import so tsc stays clean.
source = source.replace("import { upsertConfig } from '../../api';\n", '');

for (const snippet of ['const { read, upsert } = useConfig();', 'epistemos-acp-alertbox-threshold']) {
  if (!source.includes(snippet)) {
    throw new Error(`AlertBox staged source missing required snippet: ${snippet}`);
  }
}
if (source.includes("import { upsertConfig }")) {
  throw new Error('AlertBox unused upsertConfig import was not removed');
}

fs.writeFileSync(path, source);
NODE

TOOLS_CACHE="$WORK_ROOT/ui/desktop/src/components/McpApps/toolsCache.ts"
node - "$TOOLS_CACHE" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

// epistemos-acp-tools-cache: getTools (REST /agent/tools) 404s on the lean ACP
// `goose serve`; route through the live toolsList_unstable via listAcpSessionTools
// (extension-scoped, full-list fallback). Restores the tool list MCP-UI apps +
// tool-call rendering depend on instead of the .catch() silent null. (Audit gap #1.)
const importAnchor = "import { getTools } from '../../api';";
const imports = `${importAnchor}
import { USE_ACP_CHAT } from '../../acpChatFeatureFlag';
import { listAcpSessionTools } from '../../acp/providers';`;
if (!source.includes('listAcpSessionTools')) {
  if (!source.includes(importAnchor)) {
    throw new Error('toolsCache import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

const callAnchor = `  const promise = getTools({
    query: { session_id: sessionId, extension_name: extensionName || undefined },
  })
    .then((response) => response.data ?? null)
    .catch(() => {`;
const callReplacement = `  const promise = (
    USE_ACP_CHAT
      ? listAcpSessionTools(sessionId, extensionName) // epistemos-acp-tools-cache
      : getTools({
          query: { session_id: sessionId, extension_name: extensionName || undefined },
        }).then((response) => response.data ?? null)
  )
    .catch(() => {`;
if (!source.includes('epistemos-acp-tools-cache')) {
  if (!source.includes(callAnchor)) {
    throw new Error('toolsCache getTools call anchor not found');
  }
  source = source.replace(callAnchor, callReplacement);
}

for (const snippet of ['listAcpSessionTools', 'epistemos-acp-tools-cache']) {
  if (!source.includes(snippet)) {
    throw new Error(`toolsCache staged source missing: ${snippet}`);
  }
}
fs.writeFileSync(path, source);
NODE

MCP_APP_RENDERER="$WORK_ROOT/ui/desktop/src/components/McpApps/McpAppRenderer.tsx"
node - "$MCP_APP_RENDERER" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

const importAnchor = "import { callTool, readResource } from '../../api';";
const imports = `${importAnchor}
import { USE_ACP_CHAT } from '../../acpChatFeatureFlag';
import { callAcpSessionTool, readAcpSessionResource } from '../../acp/providers';`;
if (!source.includes('callAcpSessionTool')) {
  if (!source.includes(importAnchor)) {
    throw new Error('McpAppRenderer API import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

source = source.replace(
  `          const response = await readResource({
            body: {
              session_id: sessionId,
              uri: resourceUri,
              extension_name: extensionName,
            },
          });

          if (cancelled) return;

          if (response.data) {
            const content = response.data;`,
  `          const content = USE_ACP_CHAT
            ? await readAcpSessionResource(sessionId, resourceUri, extensionName) // epistemos-acp-mcp-resource-read-ui
            : (
                await readResource({
                  body: {
                    session_id: sessionId,
                    uri: resourceUri,
                    extension_name: extensionName,
                  },
                })
              ).data ?? null;

          if (cancelled) return;

          if (content) {`
);
source = source.replace(
  `      const response = await callTool({
        body: {
          session_id: sessionId,
          name: fullToolName,
          arguments: args || {},
        },
      });

      return {
        content: (response.data?.content || []) as unknown as CallToolResult['content'],
        isError: response.data?.isError || false,
        structuredContent: response.data?.structuredContent as
          | { [key: string]: unknown }
          | undefined,
        _meta: response.data?._meta as { [key: string]: unknown } | undefined,
      };`,
  `      const response = USE_ACP_CHAT
        ? await callAcpSessionTool(sessionId, fullToolName, args || {}) // epistemos-acp-mcp-tool-call-ui
        : (
            await callTool({
              body: {
                session_id: sessionId,
                name: fullToolName,
                arguments: args || {},
              },
            })
          ).data ?? null;

      return {
        content: (response?.content || []) as unknown as CallToolResult['content'],
        isError: response?.isError || false,
        structuredContent: response?.structuredContent as
          | { [key: string]: unknown }
          | undefined,
        _meta: response?._meta as { [key: string]: unknown } | undefined,
      };`
);
source = source.replace(
  `      const response = await readResource({
        body: {
          session_id: sessionId,
          uri,
          extension_name: extensionName,
        },
      });
      const data = response.data;`,
  `      const data = USE_ACP_CHAT
        ? await readAcpSessionResource(sessionId, uri, extensionName) // epistemos-acp-mcp-resource-read-handler
        : (
            await readResource({
              body: {
                session_id: sessionId,
                uri,
                extension_name: extensionName,
              },
            })
          ).data ?? null;`
);

for (const snippet of [
  'callAcpSessionTool',
  'readAcpSessionResource',
  'epistemos-acp-mcp-resource-read-ui',
  'epistemos-acp-mcp-tool-call-ui',
  'epistemos-acp-mcp-resource-read-handler',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`McpAppRenderer staged source missing required ACP MCP app snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

PERMISSION_MODAL="$WORK_ROOT/ui/desktop/src/components/settings/permission/PermissionModal.tsx"
node - "$PERMISSION_MODAL" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

source = source.replace(
  "import { getTools, PermissionLevel, ToolInfo, upsertPermissions } from '../../../api';",
  "import { getTools, PermissionLevel, ToolInfo, upsertPermissions } from '../../../api';\nimport { USE_ACP_CHAT } from '../../../acpChatFeatureFlag';\nimport { listAcpSessionTools } from '../../../acp/providers';"
);
source = source.replace(
  `  saveChanges: {
    id: 'permissionModal.saveChanges',
    defaultMessage: 'Save Changes',
  },
});`,
  `  saveChanges: {
    id: 'permissionModal.saveChanges',
    defaultMessage: 'Save Changes',
  },
  permissionEditingUnavailable: {
    id: 'permissionModal.permissionEditingUnavailable',
    defaultMessage:
      'This ACP build can show live tool permissions, but per-tool permission editing is not available yet.',
  },
});`
);
source = source.replace(
  `        const response = await getTools({
          query: { extension_name: extensionName, session_id: sessionId },
        });
        if (response.error) {
          console.error('Failed to get tools:', response.error);
          setLoadError('fetch_failed');
        } else {
          const filteredTools = (response.data || []).filter(
            (tool: ToolInfo) =>
              tool.name !== 'platform__read_resource' && tool.name !== 'platform__list_resources'
          );
          setTools(filteredTools);
        }`,
  `        if (USE_ACP_CHAT) {
          const acpTools = await listAcpSessionTools(sessionId, extensionName); // epistemos-acp-permission-tools-list
          const filteredTools = acpTools.filter(
            (tool: ToolInfo) =>
              tool.name !== 'platform__read_resource' && tool.name !== 'platform__list_resources'
          );
          setTools(filteredTools);
          return;
        }

        const response = await getTools({
          query: { extension_name: extensionName, session_id: sessionId },
        });
        if (response.error) {
          console.error('Failed to get tools:', response.error);
          setLoadError('fetch_failed');
        } else {
          const filteredTools = (response.data || []).filter(
            (tool: ToolInfo) =>
              tool.name !== 'platform__read_resource' && tool.name !== 'platform__list_resources'
          );
          setTools(filteredTools);
        }`
);
source = source.replace(
  `      if (payload.tool_permissions.length === 0) {
        onClose();
        return;
      }

      const response = await upsertPermissions({`,
  `      if (payload.tool_permissions.length === 0) {
        onClose();
        return;
      }

      if (USE_ACP_CHAT) {
        console.warn('Per-tool permission editing is not available over Goose ACP yet.');
        return; // epistemos-acp-permission-save-unavailable
      }

      const response = await upsertPermissions({`
);
source = source.replace(
  `          {!loadError && (
            <Button disabled={!hasChanges} onClick={handleSave}>
              {intl.formatMessage(i18n.saveChanges)}
            </Button>
          )}`,
  `          {USE_ACP_CHAT && !loadError && tools.length > 0 ? (
            <p className="mr-auto max-w-xs text-xs text-text-secondary">
              {intl.formatMessage(i18n.permissionEditingUnavailable)}
            </p>
          ) : null}
          {!loadError && !USE_ACP_CHAT && (
            <Button disabled={!hasChanges} onClick={handleSave}>
              {intl.formatMessage(i18n.saveChanges)}
            </Button>
          )}`
);

for (const snippet of [
  'listAcpSessionTools(sessionId, extensionName)',
  'epistemos-acp-permission-tools-list',
  'epistemos-acp-permission-save-unavailable',
  'permissionEditingUnavailable',
  '!USE_ACP_CHAT',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`PermissionModal staged source missing required ACP snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

DICTATION_SETTINGS="$WORK_ROOT/ui/desktop/src/components/settings/dictation/DictationSettings.tsx"
node - "$DICTATION_SETTINGS" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

source = source.replace(
  "import { DictationProvider, getDictationConfig, DictationProviderStatus } from '../../../api';",
  "import { DictationProvider, getDictationConfig, DictationProviderStatus } from '../../../api';\nimport { USE_ACP_CHAT } from '../../../acpChatFeatureFlag';\nimport { deleteAcpDictationSecret, readAcpDictationConfig, saveAcpDictationSecret } from '../../../acp/providers';"
);
source = source.replace(
  `  const refreshStatuses = async () => {
    const audioConfig = await getDictationConfig();
    setProviderStatuses(audioConfig.data || {});
  };`,
  `  const refreshStatuses = async () => {
    if (USE_ACP_CHAT) {
      setProviderStatuses(await readAcpDictationConfig()); // epistemos-acp-dictation-config-ui
      return;
    }
    const audioConfig = await getDictationConfig();
    setProviderStatuses(audioConfig.data || {});
  };`
);
source = source.replace(
  `    const keyName = providerConfig.config_key!;
    await upsert(keyName, trimmedKey, true);`,
  `    if (USE_ACP_CHAT) {
      await saveAcpDictationSecret(provider, trimmedKey); // epistemos-acp-dictation-secret-save-ui
    } else {
      const keyName = providerConfig.config_key!;
      await upsert(keyName, trimmedKey, true);
    }`
);
source = source.replace(
  `    const keyName = providerConfig.config_key!;
    await remove(keyName, true);`,
  `    if (USE_ACP_CHAT) {
      await deleteAcpDictationSecret(provider); // epistemos-acp-dictation-secret-delete-ui
    } else {
      const keyName = providerConfig.config_key!;
      await remove(keyName, true);
    }`
);

for (const snippet of [
  'readAcpDictationConfig',
  'saveAcpDictationSecret(provider, trimmedKey)',
  'deleteAcpDictationSecret(provider)',
  'epistemos-acp-dictation-config-ui',
  'epistemos-acp-dictation-secret-save-ui',
  'epistemos-acp-dictation-secret-delete-ui',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`DictationSettings staged source missing required ACP snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

USE_AUDIO_RECORDER="$WORK_ROOT/ui/desktop/src/hooks/useAudioRecorder.ts"
node - "$USE_AUDIO_RECORDER" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

source = source.replace(
  "import { transcribeDictation, getDictationConfig, DictationProvider } from '../api';",
  "import { transcribeDictation, getDictationConfig, DictationProvider } from '../api';\nimport { USE_ACP_CHAT } from '../acpChatFeatureFlag';\nimport { readAcpDictationConfig, transcribeAcpDictation } from '../acp/providers';"
);
source = source.replace(
  `        const resp = await getDictationConfig();
        setIsEnabled(!!resp.data?.[pref]?.configured);
        setProvider(pref);`,
  `        if (USE_ACP_CHAT) {
          const statuses = await readAcpDictationConfig(); // epistemos-acp-dictation-config-hook
          setIsEnabled(!!statuses[pref]?.configured);
          setProvider(pref);
          return;
        }
        const resp = await getDictationConfig();
        setIsEnabled(!!resp.data?.[pref]?.configured);
        setProvider(pref);`
);
source = source.replace(
  `      const result = await transcribeDictation({
        body: { audio: base64, mime_type: 'audio/wav', provider: prov },
        throwOnError: true,
      });
      if (result.data?.text) {
        onTranscriptionRef.current(result.data.text);
      }`,
  `      const text = USE_ACP_CHAT
        ? await transcribeAcpDictation(base64, 'audio/wav', prov) // epistemos-acp-dictation-transcribe-hook
        : (
            await transcribeDictation({
              body: { audio: base64, mime_type: 'audio/wav', provider: prov },
              throwOnError: true,
            })
          ).data?.text;
      if (text) {
        onTranscriptionRef.current(text);
      }`
);

for (const snippet of [
  'readAcpDictationConfig',
  'transcribeAcpDictation',
  'epistemos-acp-dictation-config-hook',
  'epistemos-acp-dictation-transcribe-hook',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`useAudioRecorder staged source missing required ACP dictation snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

LOCAL_MODEL_MANAGER="$WORK_ROOT/ui/desktop/src/components/settings/dictation/LocalModelManager.tsx"
node - "$LOCAL_MODEL_MANAGER" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

source = source.replace(
  "import { defineMessages, useIntl } from '../../../i18n';",
  "import { USE_ACP_CHAT } from '../../../acpChatFeatureFlag';\nimport {\n  cancelAcpDictationModelDownload,\n  deleteAcpDictationModel,\n  listAcpDictationModels,\n  readAcpDictationModelDownloadProgress,\n  readAcpDictationSelectedModel,\n  selectAcpDictationModel,\n  startAcpDictationModelDownload,\n} from '../../../acp/providers';\nimport { defineMessages, useIntl } from '../../../i18n';"
);
source = source.replace(
  `  const loadSelectedModel = async () => {
    try {
      const value = await read(LOCAL_WHISPER_MODEL_CONFIG_KEY, false);`,
  `  const loadSelectedModel = async () => {
    try {
      if (USE_ACP_CHAT) {
        setSelectedModelId(await readAcpDictationSelectedModel('local')); // epistemos-acp-dictation-selected-model
        return;
      }
      const value = await read(LOCAL_WHISPER_MODEL_CONFIG_KEY, false);`
);
source = source.replace(
  `  const selectModel = async (modelId: string) => {
    await upsert(LOCAL_WHISPER_MODEL_CONFIG_KEY, modelId, false);
    setSelectedModelId(modelId);
  };`,
  `  const selectModel = async (modelId: string) => {
    if (USE_ACP_CHAT) {
      await selectAcpDictationModel('local', modelId); // epistemos-acp-dictation-model-select-ui
    } else {
      await upsert(LOCAL_WHISPER_MODEL_CONFIG_KEY, modelId, false);
    }
    setSelectedModelId(modelId);
  };`
);
source = source.replace(
  `  const loadModels = async () => {
    try {
      const response = await listModels();
      if (response.data) {
        setModels(response.data);
      }
    } catch (error) {
      console.error('Failed to load models:', error);
    }
  };`,
  `  const loadModels = async () => {
    try {
      if (USE_ACP_CHAT) {
        setModels(await listAcpDictationModels()); // epistemos-acp-dictation-models-list-ui
        return;
      }
      const response = await listModels();
      if (response.data) {
        setModels(response.data);
      }
    } catch (error) {
      console.error('Failed to load models:', error);
    }
  };`
);
source = source.replace(
  `  const startDownload = async (modelId: string) => {
    try {
      await downloadModel({ path: { model_id: modelId } });
      pollDownloadProgress(modelId);
    } catch (error) {
      console.error('Failed to start download:', error);
    }
  };`,
  `  const startDownload = async (modelId: string) => {
    try {
      if (USE_ACP_CHAT) {
        await startAcpDictationModelDownload(modelId); // epistemos-acp-dictation-model-download-ui
      } else {
        await downloadModel({ path: { model_id: modelId } });
      }
      pollDownloadProgress(modelId);
    } catch (error) {
      console.error('Failed to start download:', error);
    }
  };`
);
source = source.replace(
  `        const response = await getDownloadProgress({ path: { model_id: modelId } });
        if (response.data) {
          const progress = response.data;`,
  `        const progress = USE_ACP_CHAT
          ? await readAcpDictationModelDownloadProgress(modelId)
          : (await getDownloadProgress({ path: { model_id: modelId } })).data ?? null;
        if (progress) {`
);
source = source.replace(
  `      await cancelDownloadApi({ path: { model_id: modelId } });`,
  `      if (USE_ACP_CHAT) {
        await cancelAcpDictationModelDownload(modelId); // epistemos-acp-dictation-model-cancel-ui
      } else {
        await cancelDownloadApi({ path: { model_id: modelId } });
      }`
);
source = source.replace(
  `      await deleteModelApi({ path: { model_id: modelId } });
      if (selectedModelId === modelId) {
        await upsert(LOCAL_WHISPER_MODEL_CONFIG_KEY, '', false);
        setSelectedModelId(null);
      }`,
  `      if (USE_ACP_CHAT) {
        await deleteAcpDictationModel(modelId); // epistemos-acp-dictation-model-delete-ui
      } else {
        await deleteModelApi({ path: { model_id: modelId } });
      }
      if (selectedModelId === modelId) {
        if (!USE_ACP_CHAT) {
          await upsert(LOCAL_WHISPER_MODEL_CONFIG_KEY, '', false);
        }
        setSelectedModelId(null);
      }`
);
source = source.replace(
  `  const displayedModels =
    showAllModels || hasDownloadedNonRecommended ? models : models.filter((m) => m.recommended);
  const hasNonRecommendedModels = models.some((m) => !m.recommended);`,
  `  const displayedModels =
    USE_ACP_CHAT || showAllModels || hasDownloadedNonRecommended
      ? models
      : models.filter((m) => m.recommended);
  const hasNonRecommendedModels = !USE_ACP_CHAT && models.some((m) => !m.recommended);`
);

for (const snippet of [
  'epistemos-acp-dictation-selected-model',
  'epistemos-acp-dictation-model-select-ui',
  'epistemos-acp-dictation-models-list-ui',
  'epistemos-acp-dictation-model-download-ui',
  'readAcpDictationModelDownloadProgress(modelId)',
  'epistemos-acp-dictation-model-cancel-ui',
  'epistemos-acp-dictation-model-delete-ui',
  'USE_ACP_CHAT || showAllModels',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`LocalModelManager staged source missing required ACP snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

AUTH_SETTINGS_SECTION="$WORK_ROOT/ui/desktop/src/components/settings/auth/AuthSettingsSection.tsx"
node - "$AUTH_SETTINGS_SECTION" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

function replaceRequired(label, pattern, replacement) {
  const next = source.replace(pattern, replacement);
  if (next === source) {
    throw new Error(`AuthSettingsSection ${label} replacement not applied`);
  }
  source = next;
}

const importAnchor = `import {
  configureProviderOauth,
  deleteProviderSecret,
  listProviderSecrets,
  ProviderSecret,
} from '../../../api';`;
const imports = `${importAnchor}
import { USE_ACP_CHAT } from '../../../acpChatFeatureFlag';
import {
  authenticateAcpProviderConfig,
  deleteAcpProviderConfig,
  listAcpProviderSecrets,
} from '../../../acp/providers';`;
if (!source.includes('listAcpProviderSecrets')) {
  if (!source.includes(importAnchor)) {
    throw new Error('AuthSettingsSection API import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

replaceRequired(
  'ACP provider secret load',
  `      const response = await listProviderSecrets({ throwOnError: true });
      setSecrets(response.data?.secrets ?? []);`,
  `      if (USE_ACP_CHAT) {
        setSecrets(await listAcpProviderSecrets());
        return;
      }
      const response = await listProviderSecrets({ throwOnError: true });
      setSecrets(response.data?.secrets ?? []);`
);

replaceRequired(
  'ACP provider OAuth configure',
  `      await configureProviderOauth({
        path: { name: secret.configure_provider },
        throwOnError: true,
      });`,
  `      if (USE_ACP_CHAT) {
        await authenticateAcpProviderConfig(secret.configure_provider);
      } else {
        await configureProviderOauth({
          path: { name: secret.configure_provider },
          throwOnError: true,
        });
      }`
);

replaceRequired(
  'ACP provider secret delete',
  `      await deleteProviderSecret({
        path: { id: secretToDelete.id },
        throwOnError: true,
      });`,
  `      if (USE_ACP_CHAT) {
        await deleteAcpProviderConfig(secretToDelete.provider);
      } else {
        await deleteProviderSecret({
          path: { id: secretToDelete.id },
          throwOnError: true,
        });
      }`
);

for (const snippet of [
  'USE_ACP_CHAT',
  'listAcpProviderSecrets()',
  'authenticateAcpProviderConfig(secret.configure_provider)',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`AuthSettingsSection staged source is missing required ACP auth snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

EXTENSION_UTILS="$WORK_ROOT/ui/desktop/src/components/settings/extensions/utils.ts"
ACP_EXTENSIONS="$WORK_ROOT/ui/desktop/src/acp/extensions.ts"
EXTENSION_MODAL="$WORK_ROOT/ui/desktop/src/components/settings/extensions/modal/ExtensionModal.tsx"
node - "$EXTENSION_UTILS" "$ACP_EXTENSIONS" "$EXTENSION_MODAL" <<'NODE'
const fs = require('fs');
const [utilsPath, acpExtensionsPath, modalPath] = process.argv.slice(2);

let utilsSource = fs.readFileSync(utilsPath, 'utf8');
const envKeysAnchor = `  // Extract just the keys from env vars
  const env_keys = formData.envVars.map(({ key }) => key).filter((key) => key.length > 0);
`;
const envKeysReplacement = `  // Extract just the keys from env vars
  const env_keys = formData.envVars.map(({ key }) => key).filter((key) => key.length > 0);
  const editedEnvValues = formData.envVars
    .filter(
      ({ key, value, isEdited }) =>
        key.length > 0 && value.length > 0 && isEdited === true && value !== '••••••••'
    )
    .reduce(
      (envs, { key, value }) => {
        envs[key] = value;
        return envs;
      },
      {} as Record<string, string>
    ); // epistemos-acp-stdio-extension-secret-env-values
`;
if (!utilsSource.includes('epistemos-acp-stdio-extension-secret-env-values')) {
  if (!utilsSource.includes(envKeysAnchor)) {
    throw new Error('Extension utils env_keys anchor not found');
  }
  utilsSource = utilsSource.replace(envKeysAnchor, envKeysReplacement);
}
const stdioEnvKeysAnchor = `      ...(env_keys.length > 0 ? { env_keys } : {}),
`;
const stdioEnvKeysReplacement = `      ...(env_keys.length > 0 ? { env_keys } : {}),
      ...(Object.keys(editedEnvValues).length > 0 ? { envs: editedEnvValues } : {}), // epistemos-acp-stdio-extension-secret-envs
`;
if (!utilsSource.includes('epistemos-acp-stdio-extension-secret-envs')) {
  if (!utilsSource.includes(stdioEnvKeysAnchor)) {
    throw new Error('Extension utils stdio env_keys anchor not found');
  }
  utilsSource = utilsSource.replace(stdioEnvKeysAnchor, stdioEnvKeysReplacement);
}
for (const snippet of [
  'epistemos-acp-stdio-extension-secret-env-values',
  'epistemos-acp-stdio-extension-secret-envs',
]) {
  if (!utilsSource.includes(snippet)) {
    throw new Error(`Extension utils staged source missing required ACP snippet: ${snippet}`);
  }
}
fs.writeFileSync(utilsPath, utilsSource);

let acpExtensionsSource = fs.readFileSync(acpExtensionsPath, 'utf8');
const stdioServerAnchor = `        server: { name: config.name, command: config.cmd, args: config.args, env: [] },
`;
const stdioServerReplacement = `        server: {
          name: config.name,
          command: config.cmd,
          args: config.args,
          env: Object.entries(config.envs ?? {}).map(([name, value]) => ({
            name,
            value: String(value),
          })), // epistemos-acp-stdio-extension-server-env
        },
`;
if (!acpExtensionsSource.includes('epistemos-acp-stdio-extension-server-env')) {
  if (!acpExtensionsSource.includes(stdioServerAnchor)) {
    throw new Error('ACP extensions stdio server env anchor not found');
  }
  acpExtensionsSource = acpExtensionsSource.replace(stdioServerAnchor, stdioServerReplacement);
}
if (!acpExtensionsSource.includes('epistemos-acp-stdio-extension-server-env')) {
  throw new Error('ACP extensions staged source missing stdio secret env graft');
}
fs.writeFileSync(acpExtensionsPath, acpExtensionsSource);

let modalSource = fs.readFileSync(modalPath, 'utf8');
const apiImportAnchor = `import { upsertConfig } from '../../../../api';
`;
if (!modalSource.includes("import { USE_ACP_CHAT } from '../../../../acpChatFeatureFlag';")) {
  if (!modalSource.includes(apiImportAnchor)) {
    throw new Error('ExtensionModal API import anchor not found');
  }
  modalSource = modalSource.replace(
    apiImportAnchor,
    `${apiImportAnchor}import { USE_ACP_CHAT } from '../../../../acpChatFeatureFlag';
`
  );
}
const i18nAnchor = `  closeWithoutSaving: {
    id: 'extensionModal.closeWithoutSaving',
    defaultMessage: 'Close Without Saving',
  },
`;
const i18nReplacement = `${i18nAnchor}  unsupportedStreamableHttpSecrets: {
    id: 'extensionModal.unsupportedStreamableHttpSecrets',
    defaultMessage:
      'Secret environment variables for streamable HTTP extensions are not supported in this ACP build yet.',
  },
`;
if (!modalSource.includes('unsupportedStreamableHttpSecrets')) {
  if (!modalSource.includes(i18nAnchor)) {
    throw new Error('ExtensionModal i18n anchor not found');
  }
  modalSource = modalSource.replace(i18nAnchor, i18nReplacement);
}
const storeSecretAnchor = `  // Function to store a secret value
  const storeSecret = async (key: string, value: string) => {
    try {
`;
const storeSecretReplacement = `  // Function to store a secret value
  const storeSecret = async (key: string, value: string) => {
    if (USE_ACP_CHAT) {
      return true; // epistemos-acp-stdio-extension-secret-store-via-config
    }
    try {
`;
if (!modalSource.includes('epistemos-acp-stdio-extension-secret-store-via-config')) {
  if (!modalSource.includes(storeSecretAnchor)) {
    throw new Error('ExtensionModal storeSecret anchor not found');
  }
  modalSource = modalSource.replace(storeSecretAnchor, storeSecretReplacement);
}
const finalEnvVarsAnchor = `  const getFinalEnvVars = () => {
    const finalEnvVars = [...formData.envVars];
    if (
      pendingEnvVar &&
      pendingEnvVar.key.trim() !== '' &&
      pendingEnvVar.value.trim() !== '' &&
      !pendingEnvVar.key.includes(' ')
    ) {
      finalEnvVars.push({ ...pendingEnvVar, isEdited: true });
    }
    return finalEnvVars;
  };
`;
const finalEnvVarsReplacement = `${finalEnvVarsAnchor}
  const hasUnsupportedAcpStreamableHttpSecrets = (envVars = getFinalEnvVars()) =>
    USE_ACP_CHAT &&
    formData.type === 'streamable_http' &&
    envVars.some(
      ({ key, value, isEdited }) =>
        key.trim() !== '' &&
        value.trim() !== '' &&
        isEdited === true &&
        value !== '••••••••'
    ); // epistemos-acp-block-http-extension-secret-env
`;
if (!modalSource.includes('epistemos-acp-block-http-extension-secret-env')) {
  if (!modalSource.includes(finalEnvVarsAnchor)) {
    throw new Error('ExtensionModal final env vars anchor not found');
  }
  modalSource = modalSource.replace(finalEnvVarsAnchor, finalEnvVarsReplacement);
}
const formValidAnchor = `      isNameValid() && isConfigValid() && isEnvVarsValid() && isHeadersValid() && isTimeoutValid()
`;
const formValidReplacement = `      isNameValid() &&
      isConfigValid() &&
      isEnvVarsValid() &&
      isHeadersValid() &&
      isTimeoutValid() &&
      !hasUnsupportedAcpStreamableHttpSecrets()
`;
if (!modalSource.includes('!hasUnsupportedAcpStreamableHttpSecrets()')) {
  if (!modalSource.includes(formValidAnchor)) {
    throw new Error('ExtensionModal form validity anchor not found');
  }
  modalSource = modalSource.replace(formValidAnchor, formValidReplacement);
}
const finalFormDataAnchor = `      const finalFormData = {
        ...formData,
        envVars: getFinalEnvVars(),
        headers: getFinalHeaders(),
      };
`;
const finalFormDataReplacement = `${finalFormDataAnchor}
      if (hasUnsupportedAcpStreamableHttpSecrets(finalFormData.envVars)) {
        console.error(
          'Secret environment variables for streamable HTTP extensions are not supported in ACP'
        );
        return; // epistemos-acp-block-http-extension-secret-submit
      }
`;
if (!modalSource.includes('epistemos-acp-block-http-extension-secret-submit')) {
  if (!modalSource.includes(finalFormDataAnchor)) {
    throw new Error('ExtensionModal submit guard anchor not found');
  }
  modalSource = modalSource.replace(finalFormDataAnchor, finalFormDataReplacement);
}
const envVarsSectionAnchor = `                      onPendingInputChange={handlePendingEnvVarChange}
                    />
`;
const envVarsSectionReplacement = `${envVarsSectionAnchor}                    {hasUnsupportedAcpStreamableHttpSecrets() && (
                      <p
                        className="mt-3 text-xs text-text-warning"
                        data-epistemos-acp-block-http-extension-secret-env="true"
                      >
                        {intl.formatMessage(i18n.unsupportedStreamableHttpSecrets)}
                      </p>
                    )}
`;
if (!modalSource.includes('data-epistemos-acp-block-http-extension-secret-env')) {
  if (!modalSource.includes(envVarsSectionAnchor)) {
    throw new Error('ExtensionModal env vars section anchor not found');
  }
  modalSource = modalSource.replace(envVarsSectionAnchor, envVarsSectionReplacement);
}
for (const snippet of [
  'USE_ACP_CHAT',
  'epistemos-acp-stdio-extension-secret-store-via-config',
  'epistemos-acp-block-http-extension-secret-env',
  'epistemos-acp-block-http-extension-secret-submit',
  'unsupportedStreamableHttpSecrets',
]) {
  if (!modalSource.includes(snippet)) {
    throw new Error(`ExtensionModal staged source missing required ACP snippet: ${snippet}`);
  }
}
fs.writeFileSync(modalPath, modalSource);
NODE

MODEL_INTERFACE="$WORK_ROOT/ui/desktop/src/components/settings/models/modelInterface.ts"
node - "$MODEL_INTERFACE" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

function replaceRequired(label, pattern, replacement) {
  const next = source.replace(pattern, replacement);
  if (next === source) {
    throw new Error(`modelInterface ${label} replacement not applied`);
  }
  source = next;
}

const importAnchor = "import { errorMessage as getErrorMessage } from '../../../utils/conversionUtils';";
const imports = `${importAnchor}
import { USE_ACP_CHAT } from '../../../acpChatFeatureFlag';
import { getAcpProviders, listAcpProviderModels } from '../../../acp/providers';`;
if (!source.includes("../../../acp/providers")) {
  if (!source.includes(importAnchor)) {
    throw new Error('modelInterface import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

if (!source.includes('function epistemosProviderModelErrorMessage')) {
  replaceRequired(
    'Epistemos provider model error helper',
    `export interface ProviderModelsResult {
  provider: ProviderDetails;
  models: Model[] | null;
  error: string | null;
  warning: string | null;
}
`,
    `export interface ProviderModelsResult {
  provider: ProviderDetails;
  models: Model[] | null;
  error: string | null;
  warning: string | null;
}

function epistemosProviderModelErrorMessage(provider: ProviderDetails, error: unknown): string {
  const errMsg = getErrorMessage(error);
  if (provider.name === 'lmstudio') {
    const hint =
      'LM Studio is not reachable at http://localhost:1234. Start the LM Studio local server or update the LMSTUDIO_HOST provider setting.';
    return \`Failed to fetch models for \${provider.name}: \${hint}\${errMsg ? \` (\${errMsg})\` : ''}\`;
  }
  return \`Failed to fetch models for \${provider.name}\${errMsg ? \`: \${errMsg}\` : ''}\`;
}

function epistemosKnownModelFallback(provider: ProviderDetails): Model[] {
  return provider.metadata.known_models.map(
    (m) =>
      ({
        name: m.name,
        provider: provider.name,
        context_limit: m.context_limit,
        reasoning: m.reasoning ?? undefined,
      }) as Model
  );
}
`
  );
}

replaceRequired(
  'known model fallback helper',
  `        const fallbackModels = p.metadata.known_models.map(
          (m) =>
            ({
              name: m.name,
              provider: p.name,
              context_limit: m.context_limit,
              reasoning: m.reasoning ?? undefined,
            }) as Model
        );`,
  `        const fallbackModels = epistemosKnownModelFallback(p);`
);

replaceRequired(
  'ACP supported models branch',
  `    try {
      // For local provider, use listLocalModels and filter to only downloaded models`,
  `    try {
      if (USE_ACP_CHAT) {
        try {
          const acpModels = await listAcpProviderModels(p.name);
          if (acpModels.length === 0) {
            throw new Error(\`Goose ACP supported model inventory returned zero models for \${p.name}.\`);
          }
          const inventoryModels = new Map(p.metadata.known_models.map((model) => [model.name, model]));
          const models = acpModels.map(
            (m) =>
              ({
                name: m.name,
                provider: p.name,
                context_limit: inventoryModels.get(m.name)?.context_limit ?? m.context_limit,
                reasoning: inventoryModels.get(m.name)?.reasoning ?? m.reasoning ?? undefined,
              }) as Model
          );
          return { provider: p, models, error: null, warning: null };
        } catch (e: unknown) {
          const fallbackModels = epistemosKnownModelFallback(p);
          if (fallbackModels.length > 0) {
            console.warn(\`Failed to fetch ACP models for \${p.name}:\`, getErrorMessage(e));
            return {
              provider: p,
              models: fallbackModels,
              error: null,
              warning: \`Could not fetch live models from Goose ACP - showing Goose catalog models instead.\`,
            };
          }
          throw e;
        }
      }

      // For local provider, use listLocalModels and filter to only downloaded models`
);

replaceRequired(
  'ACP model reasoning branch',
  `  try {
    const response = await getProviderModelInfo({`,
  `  try {
    if (USE_ACP_CHAT) {
      const providers = await getAcpProviders();
      const providerInfo = providers.find((entry) => entry.name === provider);
      const modelInfo = providerInfo?.metadata.known_models.find((entry) => entry.name === model);
      return modelInfo?.reasoning ?? fallback ?? null;
    }

    const response = await getProviderModelInfo({`
);

replaceRequired(
  'Epistemos provider model error wording',
  "      const errMsg = getErrorMessage(e);\n      const errorMessage = `Failed to fetch models for ${p.name}${errMsg ? `: ${errMsg}` : ''}`;",
  "      const errorMessage = epistemosProviderModelErrorMessage(p, e);"
);

for (const snippet of [
  'listAcpProviderModels(p.name)',
  'Goose ACP supported model inventory returned zero models',
  'epistemosKnownModelFallback(p)',
  'showing Goose catalog models instead',
  'const providers = await getAcpProviders()',
  'LM Studio is not reachable at http://localhost:1234',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`modelInterface staged source is missing required ACP model snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

mkdir -p "$WORK_ROOT/ui/desktop/src/epistemos"
cat > "$WORK_ROOT/ui/desktop/src/epistemos/appsBridge.ts" <<'TS'
import type { GooseApp } from '../api';

type ApiResponse<T> = {
  data?: T;
  error?: unknown;
};

type BridgeOptions = {
  throwOnError?: boolean;
  query?: { session_id?: string | null };
  body?: { html?: string };
  path?: { name?: string };
};

type EpistemosAppsBridge = {
  listApps: (sessionId?: string | null) => Promise<{ apps: GooseApp[] }>;
  importApp: (html: string) => Promise<{ name: string; message: string }>;
  exportApp: (name: string) => Promise<string>;
};

declare global {
  interface Window {
    epistemos?: {
      goose?: {
        apps?: EpistemosAppsBridge;
      };
    };
  }
}

function appsBridge(): EpistemosAppsBridge {
  const bridge = window.epistemos?.goose?.apps;
  if (!bridge) {
    throw new Error('Epistemos Apps bridge unavailable');
  }
  return bridge;
}

function failure<T>(options: BridgeOptions | undefined, error: unknown): ApiResponse<T> {
  if (options?.throwOnError) {
    throw error;
  }
  return { error };
}

export async function listApps(
  options: BridgeOptions = {}
): Promise<ApiResponse<{ apps: GooseApp[] }>> {
  try {
    return { data: await appsBridge().listApps(options.query?.session_id ?? null) };
  } catch (error) {
    return failure(options, error);
  }
}

export async function importApp(
  options: BridgeOptions
): Promise<ApiResponse<{ name: string; message: string }>> {
  try {
    const html = options.body?.html;
    if (typeof html !== 'string') {
      throw new Error('Epistemos Apps import requires an HTML body.');
    }
    return { data: await appsBridge().importApp(html) };
  } catch (error) {
    return failure(options, error);
  }
}

export async function exportApp(options: BridgeOptions): Promise<ApiResponse<string>> {
  try {
    const name = options.path?.name;
    if (typeof name !== 'string' || name.length === 0) {
      throw new Error('Epistemos Apps export requires an app name.');
    }
    return { data: await appsBridge().exportApp(name) };
  } catch (error) {
    return failure(options, error);
  }
}
TS

cat > "$WORK_ROOT/ui/desktop/src/epistemos/contextBridge.ts" <<'TS'
export type EpistemosContextSnapshot = {
  available?: boolean;
  source?: string;
  appMode?: string;
  capturedAt?: string;
  vaultPath?: string | null;
  activeNote?: {
    id?: string;
    title?: string;
    path?: string | null;
    vaultRelativePath?: string | null;
    preview?: string | null;
    wordCount?: number;
  } | null;
  graph?: {
    route?: string;
    sourceId?: string | null;
    selectedNodeId?: string | null;
    selectedNodeTitle?: string | null;
    selectedNodeType?: string | null;
    selectedNodeSourceId?: string | null;
  } | null;
  attachments?: Array<{
    kind?: string;
    title?: string;
    path?: string | null;
    targetId?: string | null;
    summary?: string | null;
  }>;
  promptContext?: string | null;
};

type EpistemosContextBridge = {
  snapshot: () => Promise<EpistemosContextSnapshot>;
};

function contextBridge(): EpistemosContextBridge {
  const bridge = (window as Window & {
    epistemos?: { context?: EpistemosContextBridge };
  }).epistemos?.context;
  if (!bridge?.snapshot) {
    throw new Error('Epistemos context bridge unavailable');
  }
  return bridge;
}

export async function getEpistemosContextSnapshot(): Promise<EpistemosContextSnapshot> {
  const snapshot = await contextBridge().snapshot();
  return snapshot && typeof snapshot === 'object' ? snapshot : { available: false };
}

export function formatEpistemosContextForPrompt(snapshot: EpistemosContextSnapshot): string {
  if (snapshot.available === false) return '';

  const direct = typeof snapshot.promptContext === 'string' ? snapshot.promptContext.trim() : '';
  if (direct) return direct;

  const lines: string[] = ['Epistemos context snapshot:'];
  if (snapshot.vaultPath) lines.push(`- Vault: ${snapshot.vaultPath}`);
  if (snapshot.activeNote?.title) {
    lines.push(`- Active note: ${snapshot.activeNote.title}`);
    const notePath = snapshot.activeNote.path || snapshot.activeNote.vaultRelativePath;
    if (notePath) lines.push(`  Path: ${notePath}`);
    if (snapshot.activeNote.preview) lines.push(`  Preview: ${snapshot.activeNote.preview}`);
  }
  if (snapshot.graph?.route) {
    lines.push(`- Graph route: ${snapshot.graph.route}`);
    const selected = snapshot.graph.selectedNodeTitle || snapshot.graph.selectedNodeId;
    if (selected) lines.push(`  Selected node: ${selected}`);
  }
  return lines.length > 1 ? lines.join('\n') : '';
}
TS

node - "$WORK_ROOT/ui/desktop/src/components/ChatInput.tsx" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

source = source.replace(
  "import { ArrowUp, Bug, ScrollText } from 'lucide-react';",
  "import { ArrowUp, BookOpen, Bug, ScrollText } from 'lucide-react';"
);
source = source.replace(
  "import type { NextChatExtensionDraft } from '../utils/nextChatExtensions';",
  "import type { NextChatExtensionDraft } from '../utils/nextChatExtensions';\nimport { formatEpistemosContextForPrompt, getEpistemosContextSnapshot } from '../epistemos/contextBridge';"
);
source = source.replace(
  "  const [isFilePickerOpen, setIsFilePickerOpen] = useState(false);",
  "  const [isFilePickerOpen, setIsFilePickerOpen] = useState(false);\n  const [isContextAttachInFlight, setIsContextAttachInFlight] = useState(false);"
);
source = source.replace(
  `  const handleFileSelect = () => {
    if (isFilePickerOpen) return;
    fileInputRef.current?.click();
  };
`,
  `  const handleFileSelect = () => {
    if (isFilePickerOpen) return;
    fileInputRef.current?.click();
  };

  const handleAttachEpistemosContext = async () => {
    if (isContextAttachInFlight) return;
    setIsContextAttachInFlight(true);
    try {
      const snapshot = await getEpistemosContextSnapshot();
      const contextText = formatEpistemosContextForPrompt(snapshot);
      if (!contextText) {
        toastError({
          title: 'No Epistemos context',
          msg: 'Open a note, vault, or graph selection before attaching context.',
        });
        return;
      }
      const prefix = displayValue.trimEnd();
      const nextValue = prefix ? \`\${prefix}\\n\\n\${contextText}\` : contextText;
      setDisplayValue(nextValue);
      setValue(nextValue);
      setHasUserTyped(true);
      setTimeout(() => textAreaRef.current?.focus(), 0);
    } catch (error) {
      toastError({
        title: 'Context unavailable',
        msg: error instanceof Error ? error.message : 'Epistemos context bridge failed.',
      });
    } finally {
      setIsContextAttachInFlight(false);
    }
  };
`
);
source = source.replace(
  `            {/* Right: attach */}
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  type="button"
                  onClick={handleFileSelect}
                  disabled={isFilePickerOpen}
                  variant="ghost"
                  size="sm"
                  shape="round"
                  className={cn(
                    'text-text-primary/70 hover:text-text-primary transition-colors',
                    isFilePickerOpen ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'
                  )}
                >
                  <Attach className="w-4 h-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Attach file</TooltipContent>
            </Tooltip>
`,
  `            {/* Right: Epistemos context */}
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  type="button"
                  onClick={handleAttachEpistemosContext}
                  disabled={isContextAttachInFlight}
                  variant="ghost"
                  size="sm"
                  shape="round"
                  className={cn(
                    'text-text-primary/70 hover:text-text-primary transition-colors',
                    isContextAttachInFlight ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'
                  )}
                  aria-label="Attach Epistemos context"
                >
                  <BookOpen className="w-4 h-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Attach Epistemos context</TooltipContent>
            </Tooltip>

            {/* Right: attach */}
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  type="button"
                  onClick={handleFileSelect}
                  disabled={isFilePickerOpen}
                  variant="ghost"
                  size="sm"
                  shape="round"
                  className={cn(
                    'text-text-primary/70 hover:text-text-primary transition-colors',
                    isFilePickerOpen ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'
                  )}
                >
                  <Attach className="w-4 h-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Attach file</TooltipContent>
            </Tooltip>
`
);

for (const snippet of [
  'getEpistemosContextSnapshot',
  'formatEpistemosContextForPrompt',
  'handleAttachEpistemosContext',
  'Attach Epistemos context',
  'BookOpen',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`ChatInput Epistemos context patch missing snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

node - "$WORK_ROOT/ui/desktop/src/components/settings/mode/ModeSection.tsx" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

source = source.replace(
  "import { ConversationLimitsDropdown } from './ConversationLimitsDropdown';",
  "import { ConversationLimitsDropdown } from './ConversationLimitsDropdown';\nimport { USE_ACP_CHAT } from '../../../acpChatFeatureFlag';\nimport { saveAcpSessionMode } from '../../../acp/providers';\nimport { useChatContext } from '../../../contexts/ChatContext';"
);
source = source.replace(
  '  const { config, read, upsert } = useConfig();',
  "  const { config, read, upsert } = useConfig();\n  const chatContext = useChatContext();\n  const sessionId = chatContext?.chat.sessionId || '';"
);
source = source.replace(
  `      await upsert('GOOSE_MODE', newMode, false);
      setCurrentMode(newMode);`,
  `      if (USE_ACP_CHAT && sessionId) {
        await saveAcpSessionMode(sessionId, newMode); // epistemos-acp-session-mode-setting
      }
      await upsert('GOOSE_MODE', newMode, false); // epistemos-acp-next-session-mode-default
      setCurrentMode(newMode);`
);

for (const snippet of [
  'USE_ACP_CHAT && sessionId',
  'saveAcpSessionMode(sessionId, newMode)',
  'epistemos-acp-session-mode-setting',
  'epistemos-acp-next-session-mode-default',
  'useChatContext()',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`ModeSection staged source missing required snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

node - "$WORK_ROOT/ui/desktop/src/components/Hub.tsx" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

source = source.replace(
  "import { UserInput } from '../types/message';",
  "import { UserInput } from '../types/message';\nimport type { GooseMode } from '../api';"
);
source = source.replace(
  '  const { extensionsList } = useConfig();',
  '  const { extensionsList, read } = useConfig();'
);
source = source.replace(
  `      const selectedExtensions = nextChatExtensionDraft
        ? selectNextChatExtensions(extensionsList, nextChatExtensionDraft)
        : [];
      const sessionOptions =
        selectedExtensions.length > 0
          ? { extensionConfigs: selectedExtensions }
          : { allExtensions: extensionsList };`,
  `      const selectedExtensions = nextChatExtensionDraft
        ? selectNextChatExtensions(extensionsList, nextChatExtensionDraft)
        : [];
      let configuredGooseMode: GooseMode | undefined;
      try {
        configuredGooseMode = ((await read('GOOSE_MODE', false)) as GooseMode | undefined) || undefined;
      } catch (error) {
        console.warn('Failed to read Goose mode for new session:', error);
      }
      const modeSessionOption = configuredGooseMode
        ? { gooseMode: configuredGooseMode } // epistemos-acp-new-session-mode-default
        : {};
      const sessionOptions =
        selectedExtensions.length > 0
          ? { extensionConfigs: selectedExtensions, ...modeSessionOption }
          : { allExtensions: extensionsList, ...modeSessionOption };`
);

for (const snippet of [
  "import type { GooseMode } from '../api';",
  'const { extensionsList, read } = useConfig();',
  "read('GOOSE_MODE', false)",
  'epistemos-acp-new-session-mode-default',
  'gooseMode: configuredGooseMode',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`Hub staged source missing required mode-default snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

node - "$WORK_ROOT/ui/desktop/src/components/apps/AppsView.tsx" \
       "$WORK_ROOT/ui/desktop/src/utils/platform_events.ts" \
       "$WORK_ROOT/ui/desktop/src/hooks/useChatStream.ts" \
       "$WORK_ROOT/ui/desktop/src/components/apps/StandaloneAppView.tsx" <<'NODE'
const fs = require('fs');
const [appsViewPath, platformEventsPath, chatStreamPath, standalonePath] = process.argv.slice(2);

function writeRequired(path, update, label) {
  const source = fs.readFileSync(path, 'utf8');
  const next = update(source);
  if (next === source) {
    throw new Error(`${label} Apps bridge replacement not applied`);
  }
  fs.writeFileSync(path, next);
}

writeRequired(
  appsViewPath,
  (source) => {
    let next = source.replace(
      "import { exportApp, GooseApp, importApp, listApps } from '../../api';",
      "import type { GooseApp } from '../../api';\nimport { exportApp, importApp, listApps } from '../../epistemos/appsBridge';"
    );
    next = next.replace(
      `  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleImportClick = () => {
    fileInputRef.current?.click();
  };

  const handleUploadApp = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    try {
      const text = await file.text();
      await importApp({
        throwOnError: true,
        body: { html: text },
      });

      const response = await listApps({
        throwOnError: true,
      });
      const cachedApps = response.data?.apps || [];
      // Only show apps from the "apps" extension.
      setApps(cachedApps.filter((a) => a.mcpServers?.includes('apps')));
      setError(null);
    } catch (err) {
      console.error('Failed to import app:', err);
      setError(errorMessage(err, 'Failed to import app'));
    }
    event.target.value = '';
  };
`,
      `  const fileInputRef = useRef<HTMLInputElement>(null);

  const refreshImportedApps = useCallback(async () => {
    const response = await listApps({
      throwOnError: true,
    });
    const cachedApps = response.data?.apps || [];
    // Only show apps from the "apps" extension.
    setApps(cachedApps.filter((a) => a.mcpServers?.includes('apps')));
  }, []);

  const importHtmlApp = useCallback(
    async (html: string) => {
      await importApp({
        throwOnError: true,
        body: { html },
      });
      await refreshImportedApps();
      setError(null);
    },
    [refreshImportedApps]
  );

  type NativeFileReadResult = {
    file?: string;
    filePath?: string;
    found?: boolean;
    error?: string | null;
  };

  const handleImportClick = async () => {
    const nativeElectron = window.electron as typeof window.electron & {
      readFile?: (path: string) => Promise<NativeFileReadResult>;
      showOpenDialog?: (options?: unknown) => Promise<{ canceled?: boolean; filePaths?: string[] }>;
    };
    if (
      typeof nativeElectron.showOpenDialog === 'function' &&
      typeof nativeElectron.readFile === 'function'
    ) {
      try {
        const result = await nativeElectron.showOpenDialog({
          properties: ['openFile'],
          filters: [{ name: 'HTML', extensions: ['html', 'htm'] }],
        });
        const filePath = result?.filePaths?.[0];
        if (result?.canceled || !filePath) return;
        const fileResponse = await nativeElectron.readFile(filePath);
        if (fileResponse?.found !== true || typeof fileResponse.file !== 'string') {
          throw new Error(fileResponse?.error || 'Native file contents were unavailable');
        }
        await importHtmlApp(fileResponse.file);
      } catch (err) {
        console.error('Failed to import app:', err);
        setError(errorMessage(err, 'Failed to import app'));
      }
      return;
    }
    fileInputRef.current?.click();
  };

  const handleUploadApp = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    try {
      const text = await file.text();
      await importHtmlApp(text);
    } catch (err) {
      console.error('Failed to import app:', err);
      setError(errorMessage(err, 'Failed to import app'));
    }
    event.target.value = '';
  };
`
    );
    return next;
  },
  'AppsView'
);

writeRequired(
  platformEventsPath,
  (source) =>
    source.replace(
      "import { listApps, GooseApp } from '../api';",
      "import type { GooseApp } from '../api';\nimport { listApps } from '../epistemos/appsBridge';"
    ),
  'platform_events'
);

writeRequired(
  chatStreamPath,
  (source) =>
    source.replace(
      /,\n  listApps,\n} from '\.\.\/api';/,
      "\n} from '../api';\nimport { listApps } from '../epistemos/appsBridge';"
    ),
  'useChatStream'
);

writeRequired(
  standalonePath,
  (source) =>
    source.replace(
      "import { startAgent, resumeAgent, listApps, stopAgent } from '../../api';",
      "import { startAgent, resumeAgent, stopAgent } from '../../api';\nimport { listApps } from '../../epistemos/appsBridge';"
    ),
  'StandaloneAppView'
);
NODE

MODEL_AND_PROVIDER_CONTEXT="$WORK_ROOT/ui/desktop/src/components/ModelAndProviderContext.tsx"
node - "$MODEL_AND_PROVIDER_CONTEXT" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

function replaceRequired(label, pattern, replacement) {
  const next = source.replace(pattern, replacement);
  if (next === source) {
    throw new Error(`ModelAndProviderContext ${label} replacement not applied`);
  }
  source = next;
}

const importAnchor = "import { defineMessages, useIntl } from '../i18n';";
const imports = `${importAnchor}
import { USE_ACP_CHAT } from '../acpChatFeatureFlag';
import {
  readAcpProviderDefaults,
  saveAcpProviderDefaults,
  saveAcpSessionModel,
  saveAcpSessionProvider,
  saveAcpSessionThinkingEffort,
} from '../acp/providers';`;
if (!source.includes("../acp/providers")) {
  if (!source.includes(importAnchor)) {
    throw new Error('ModelAndProviderContext import anchor not found');
  }
  source = source.replace(importAnchor, imports);
}

replaceRequired(
  'ACP session model change',
  `        if (sessionId) {
          const response = await updateAgentProvider({
            body: {
              session_id: sessionId,
              provider: providerName,
              model: modelName,
              context_limit: model.context_limit,
              request_params: model.request_params,
            },
          });
          if (response.error) {
            throw new Error(\`Failed to update agent provider: \${response.error}\`);
          }
        }`,
  `        if (sessionId) {
          if (USE_ACP_CHAT) {
            if (providerName) {
              await saveAcpSessionProvider(sessionId, providerName);
            }
            await saveAcpSessionModel(sessionId, modelName);
            const thinkingEffort = model.request_params?.thinking_effort;
            if (thinkingEffort) {
              await saveAcpSessionThinkingEffort(sessionId, String(thinkingEffort));
            }
          } else {
            const response = await updateAgentProvider({
              body: {
                session_id: sessionId,
                provider: providerName,
                model: modelName,
                context_limit: model.context_limit,
                request_params: model.request_params,
              },
            });
            if (response.error) {
              throw new Error(\`Failed to update agent provider: \${response.error}\`);
            }
          }
        }`
);

replaceRequired(
  'ACP global model change',
  `        if (!sessionId) {
          phase = 'config';
          await setConfigProvider({
            body: {
              provider: providerName,
              model: modelName,
            },
            throwOnError: true,
          });
        }`,
  `        if (!sessionId) {
          phase = 'config';
          if (USE_ACP_CHAT) {
            await saveAcpProviderDefaults(providerName, modelName);
          } else {
            await setConfigProvider({
              body: {
                provider: providerName,
                model: modelName,
              },
              throwOnError: true,
            });
          }
        }`
);

replaceRequired(
  'change model callback dependencies',
  `    [intl]
  );`,
  `    [intl, currentProvider]
  );`
);

replaceRequired(
  'ACP fallback defaults',
  `  const getFallbackModelAndProvider = useCallback(async () => {
    const provider = window.appConfig.get('GOOSE_DEFAULT_PROVIDER') as string;
    const model = window.appConfig.get('GOOSE_DEFAULT_MODEL') as string;`,
  `  const getFallbackModelAndProvider = useCallback(async () => {
    if (USE_ACP_CHAT) {
      const defaults = await readAcpProviderDefaults();
      return { model: defaults.modelId || '', provider: defaults.providerId || '' };
    }

    const provider = window.appConfig.get('GOOSE_DEFAULT_PROVIDER') as string;
    const model = window.appConfig.get('GOOSE_DEFAULT_MODEL') as string;`
);

replaceRequired(
  'ACP current defaults read',
  `    // read from config
    try {
      model = (await read('GOOSE_MODEL', false)) as string;
      provider = (await read('GOOSE_PROVIDER', false)) as string;
    } catch {`,
  `    if (USE_ACP_CHAT) {
      const defaults = await readAcpProviderDefaults();
      model = defaults.modelId || '';
      provider = defaults.providerId || '';
    } else {
      // read from config
      try {
        model = (await read('GOOSE_MODEL', false)) as string;
        provider = (await read('GOOSE_PROVIDER', false)) as string;
      } catch {`
);

replaceRequired(
  'close non ACP current defaults catch',
  `      console.error(\`Failed to read GOOSE_MODEL or GOOSE_PROVIDER from config\`);
      throw new Error('Failed to read GOOSE_MODEL or GOOSE_PROVIDER from config');
    }
    if (!model || !provider) {`,
  `        console.error(\`Failed to read GOOSE_MODEL or GOOSE_PROVIDER from config\`);
        throw new Error('Failed to read GOOSE_MODEL or GOOSE_PROVIDER from config');
      }
    }
    if (!model || !provider) {`
);

replaceRequired(
  'ACP current model display',
  `  const getCurrentModelDisplayName = useCallback(async () => {
    try {
      const currentModelName = (await read('GOOSE_MODEL', false)) as string;
      return getModelDisplayName(currentModelName);`,
  `  const getCurrentModelDisplayName = useCallback(async () => {
    try {
      if (USE_ACP_CHAT) {
        const defaults = await readAcpProviderDefaults();
        return defaults.modelId || intl.formatMessage(i18n.selectModel);
      }

      const currentModelName = (await read('GOOSE_MODEL', false)) as string;
      return getModelDisplayName(currentModelName);`
);

replaceRequired(
  'ACP current provider display',
  `  const getCurrentProviderDisplayName = useCallback(async () => {
    try {
      const currentModelName = (await read('GOOSE_MODEL', false)) as string;`,
  `  const getCurrentProviderDisplayName = useCallback(async () => {
    try {
      if (USE_ACP_CHAT) {
        const { provider } = await getCurrentModelAndProviderForDisplay();
        return provider;
      }

      const currentModelName = (await read('GOOSE_MODEL', false)) as string;`
);

for (const snippet of [
  'await saveAcpSessionModel(sessionId, modelName)',
  'await saveAcpSessionProvider(sessionId, providerName)',
  'await saveAcpProviderDefaults(providerName, modelName)',
  'const defaults = await readAcpProviderDefaults()',
  'return defaults.modelId || intl.formatMessage(i18n.selectModel)',
  'const { provider } = await getCurrentModelAndProviderForDisplay()',
  'USE_ACP_CHAT',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`ModelAndProviderContext staged source is missing required ACP defaults snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

SESSION_LIST_VIEW="$WORK_ROOT/ui/desktop/src/components/sessions/SessionListView.tsx"
node - "$SESSION_LIST_VIEW" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

const acpImport = "import { USE_ACP_CHAT } from '../../acpChatFeatureFlag';";
if (!source.includes(acpImport)) {
  const importAnchor = "import { getTunnelStatus } from '../../api/sdk.gen';";
  if (!source.includes(importAnchor)) {
    throw new Error('SessionListView tunnel import anchor not found');
  }
  source = source.replace(importAnchor, `${importAnchor}\n${acpImport}`);
}

if (source.includes('const [nostrEnabled, setNostrEnabled] = useState(true);')) {
  source = source.replace(
    'const [nostrEnabled, setNostrEnabled] = useState(true);',
    'const [nostrEnabled, setNostrEnabled] = useState(!USE_ACP_CHAT); // epistemos-acp-disable-nostr-session-links'
  );
}

const tunnelEffectAnchor = `    // Hide Nostr sharing when tunnel is disabled (restricted/enterprise bundles)
    useEffect(() => {
      getTunnelStatus()`;
const acpTunnelEffect = `    // Hide Nostr sharing when tunnel is disabled (restricted/enterprise bundles)
    useEffect(() => {
      if (USE_ACP_CHAT) {
        setNostrEnabled(false); // epistemos-acp-disable-nostr-session-links
        return;
      }
      getTunnelStatus()`;
if (!source.includes('setNostrEnabled(false); // epistemos-acp-disable-nostr-session-links')) {
  if (!source.includes(tunnelEffectAnchor)) {
    throw new Error('SessionListView tunnel effect anchor not found');
  }
  source = source.replace(tunnelEffectAnchor, acpTunnelEffect);
}

for (const snippet of [
  acpImport,
  'const [nostrEnabled, setNostrEnabled] = useState(!USE_ACP_CHAT); // epistemos-acp-disable-nostr-session-links',
  'setNostrEnabled(false); // epistemos-acp-disable-nostr-session-links',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`SessionListView staged source is missing required ACP Nostr disable snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

SETTINGS_VIEW="$WORK_ROOT/ui/desktop/src/components/settings/SettingsView.tsx"
node - "$SETTINGS_VIEW" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

const acpImport = "import { USE_ACP_CHAT } from '../../acpChatFeatureFlag';";
if (!source.includes(acpImport)) {
  const importAnchor = "import { getTunnelStatus } from '../../api/sdk.gen';";
  if (!source.includes(importAnchor)) {
    throw new Error('SettingsView tunnel import anchor not found');
  }
  source = source.replace(importAnchor, `${importAnchor}\n${acpImport}`);
}

if (source.includes('const [tunnelDisabled, setTunnelDisabled] = useState(false);')) {
  source = source.replace(
    'const [tunnelDisabled, setTunnelDisabled] = useState(false);',
    'const [tunnelDisabled, setTunnelDisabled] = useState(USE_ACP_CHAT); // epistemos-acp-hide-session-sharing'
  );
}

if (source.includes("        sharing: 'sharing',")) {
  source = source.replace(
    "        sharing: 'sharing',",
    "        sharing: USE_ACP_CHAT ? 'models' : 'sharing', // epistemos-acp-hide-session-sharing"
  );
}
if (source.includes("        gateway: 'sharing',")) {
  source = source.replace(
    "        gateway: 'sharing',",
    "        gateway: USE_ACP_CHAT ? 'models' : 'sharing',"
  );
}
if (source.includes("        prompts: 'prompts',")) {
  source = source.replace(
    "        prompts: 'prompts',",
    "        prompts: USE_ACP_CHAT ? 'models' : 'prompts', // epistemos-acp-hide-prompts-settings"
  );
}

const tunnelEffectAnchor = `  useEffect(() => {
    getTunnelStatus()`;
const tunnelEffectReplacement = `  useEffect(() => {
    if (USE_ACP_CHAT) {
      setTunnelDisabled(true); // epistemos-acp-hide-session-sharing
      return;
    }
    getTunnelStatus()`;
if (!source.includes('setTunnelDisabled(true); // epistemos-acp-hide-session-sharing')) {
  if (!source.includes(tunnelEffectAnchor)) {
    throw new Error('SettingsView tunnel effect anchor not found');
  }
  source = source.replace(tunnelEffectAnchor, tunnelEffectReplacement);
}

const sharingTabAnchor = `                  <TabsTrigger
                    value="sharing"
                    className="flex gap-2"
                    data-testid="settings-sharing-tab"
                  >
                    <Share2 className="h-4 w-4" />
                    {intl.formatMessage(i18n.tabSession)}
                  </TabsTrigger>`;
const sharingTabReplacement = `                  {!USE_ACP_CHAT && (
                    <TabsTrigger
                      value="sharing"
                      className="flex gap-2"
                      data-testid="settings-sharing-tab"
                    >
                      <Share2 className="h-4 w-4" />
                      {intl.formatMessage(i18n.tabSession)}
                    </TabsTrigger>
                  )}`;
if (!source.includes('{!USE_ACP_CHAT && (\n                    <TabsTrigger\n                      value="sharing"')) {
  if (!source.includes(sharingTabAnchor)) {
    throw new Error('SettingsView sharing tab anchor not found');
  }
  source = source.replace(sharingTabAnchor, sharingTabReplacement);
}

const sharingContentAnchor = `                <TabsContent
                  value="sharing"
                  className="mt-0 focus-visible:outline-none"
                >
                  <div className="space-y-8 pb-8">
                    <SessionSharingSection />
                    <ExternalBackendSection />
                    {!tunnelDisabled && <GatewaySettingsSection />}
                  </div>
                </TabsContent>`;
const sharingContentReplacement = `                {!USE_ACP_CHAT && (
                  <TabsContent
                    value="sharing"
                    className="mt-0 focus-visible:outline-none"
                  >
                    <div className="space-y-8 pb-8">
                      <SessionSharingSection />
                      <ExternalBackendSection />
                      {!tunnelDisabled && <GatewaySettingsSection />}
                    </div>
                  </TabsContent>
                )}`;
if (!source.includes('{!USE_ACP_CHAT && (\n                  <TabsContent\n                    value="sharing"')) {
  if (!source.includes(sharingContentAnchor)) {
    throw new Error('SettingsView sharing content anchor not found');
  }
  source = source.replace(sharingContentAnchor, sharingContentReplacement);
}

// epistemos-acp-hide-prompts-settings: prompt template CRUD has no Goose ACP
// method. Hide the Prompts tab/content in ACP so the product does not expose a
// broken editor backed by dead REST calls.
const promptsTabAnchor = `                  <TabsTrigger
                    value="prompts"
                    className="flex gap-2"
                    data-testid="settings-prompts-tab"
                  >
                    <FileText className="h-4 w-4" />
                    {intl.formatMessage(i18n.tabPrompts)}
                  </TabsTrigger>`;
const promptsTabReplacement = `                  {!USE_ACP_CHAT && (
                    <TabsTrigger
                      value="prompts"
                      className="flex gap-2"
                      data-testid="settings-prompts-tab"
                    >
                      <FileText className="h-4 w-4" />
                      {intl.formatMessage(i18n.tabPrompts)}
                    </TabsTrigger>
                  )}`;
if (!source.includes('{!USE_ACP_CHAT && (\n                    <TabsTrigger\n                      value="prompts"')) {
  if (!source.includes(promptsTabAnchor)) {
    throw new Error('SettingsView prompts tab anchor not found');
  }
  source = source.replace(promptsTabAnchor, promptsTabReplacement);
}

const promptsContentAnchor = `                <TabsContent
                  value="prompts"
                  className="mt-0 focus-visible:outline-none"
                >
                  <PromptsSettingsSection />
                </TabsContent>`;
const promptsContentReplacement = `                {!USE_ACP_CHAT && (
                  <TabsContent
                    value="prompts"
                    className="mt-0 focus-visible:outline-none"
                  >
                    <PromptsSettingsSection />
                  </TabsContent>
                )}`;
if (!source.includes('{!USE_ACP_CHAT && (\n                  <TabsContent\n                    value="prompts"')) {
  if (!source.includes(promptsContentAnchor)) {
    throw new Error('SettingsView prompts content anchor not found');
  }
  source = source.replace(promptsContentAnchor, promptsContentReplacement);
}

for (const snippet of [
  acpImport,
  'const [tunnelDisabled, setTunnelDisabled] = useState(USE_ACP_CHAT); // epistemos-acp-hide-session-sharing',
  "sharing: USE_ACP_CHAT ? 'models' : 'sharing', // epistemos-acp-hide-session-sharing",
  'setTunnelDisabled(true); // epistemos-acp-hide-session-sharing',
  "prompts: USE_ACP_CHAT ? 'models' : 'prompts', // epistemos-acp-hide-prompts-settings",
  'epistemos-acp-hide-prompts-settings',
  '{!USE_ACP_CHAT && (',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`SettingsView staged source is missing required ACP sharing snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

SESSION_HISTORY_VIEW="$WORK_ROOT/ui/desktop/src/components/sessions/SessionHistoryView.tsx"
node - "$SESSION_HISTORY_VIEW" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

const acpImport = "import { USE_ACP_CHAT } from '../../acpChatFeatureFlag';";
if (!source.includes(acpImport)) {
  const importAnchor = "import { createSharedSession } from '../../sharedSessions';";
  if (!source.includes(importAnchor)) {
    throw new Error('SessionHistoryView shared session import anchor not found');
  }
  source = source.replace(importAnchor, `${importAnchor}\n${acpImport}`);
}

const shareEffectAnchor = `  useEffect(() => {
    window.electron.getSetting('sessionSharing').then((config) => {`;
const shareEffectReplacement = `  useEffect(() => {
    if (USE_ACP_CHAT) {
      setCanShare(false); // epistemos-acp-hide-session-history-sharing
      return;
    }
    window.electron.getSetting('sessionSharing').then((config) => {`;
if (!source.includes('setCanShare(false); // epistemos-acp-hide-session-history-sharing')) {
  if (!source.includes(shareEffectAnchor)) {
    throw new Error('SessionHistoryView share effect anchor not found');
  }
  source = source.replace(shareEffectAnchor, shareEffectReplacement);
}

const handleShareAnchor = `  const handleShare = async () => {
    setIsSharing(true);`;
const handleShareReplacement = `  const handleShare = async () => {
    if (USE_ACP_CHAT) {
      return; // epistemos-acp-hide-session-history-sharing
    }
    setIsSharing(true);`;
if (!source.includes('return; // epistemos-acp-hide-session-history-sharing')) {
  if (!source.includes(handleShareAnchor)) {
    throw new Error('SessionHistoryView handleShare anchor not found');
  }
  source = source.replace(handleShareAnchor, handleShareReplacement);
}

const shareButtonAnchor = `      <Tooltip>
        <TooltipTrigger asChild>
          <Button
            onClick={handleShare}
            disabled={!canShare || isSharing}
            size="sm"
            variant="outline"
            className={canShare ? '' : 'cursor-not-allowed opacity-50'}
          >
            {isSharing ? (
              <>
                <LoaderCircle className="w-4 h-4 mr-2 animate-spin" />
                {intl.formatMessage(i18n.sharing)}
              </>
            ) : (
              <>
                <Share2 className="w-4 h-4" />
                {intl.formatMessage(i18n.share)}
              </>
            )}
          </Button>
        </TooltipTrigger>
        {!canShare ? (
          <TooltipContent>
            <p>
              {intl.formatMessage(i18n.shareTooltip, {
                b: (chunks: React.ReactNode) => <b>{chunks}</b>,
              })}
            </p>
          </TooltipContent>
        ) : null}
      </Tooltip>`;
const shareButtonReplacement = `      {!USE_ACP_CHAT && (
        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              onClick={handleShare}
              disabled={!canShare || isSharing}
              size="sm"
              variant="outline"
              className={canShare ? '' : 'cursor-not-allowed opacity-50'}
            >
              {isSharing ? (
                <>
                  <LoaderCircle className="w-4 h-4 mr-2 animate-spin" />
                  {intl.formatMessage(i18n.sharing)}
                </>
              ) : (
                <>
                  <Share2 className="w-4 h-4" />
                  {intl.formatMessage(i18n.share)}
                </>
              )}
            </Button>
          </TooltipTrigger>
          {!canShare ? (
            <TooltipContent>
              <p>
                {intl.formatMessage(i18n.shareTooltip, {
                  b: (chunks: React.ReactNode) => <b>{chunks}</b>,
                })}
              </p>
            </TooltipContent>
          ) : null}
        </Tooltip>
      )}`;
if (!source.includes('{!USE_ACP_CHAT && (\n        <Tooltip>')) {
  if (!source.includes(shareButtonAnchor)) {
    throw new Error('SessionHistoryView share button anchor not found');
  }
  source = source.replace(shareButtonAnchor, shareButtonReplacement);
}

for (const snippet of [
  acpImport,
  'setCanShare(false); // epistemos-acp-hide-session-history-sharing',
  'return; // epistemos-acp-hide-session-history-sharing',
  '{!USE_ACP_CHAT && (',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`SessionHistoryView staged source is missing required ACP sharing snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
NODE

PERMISSION_REQUESTS="$WORK_ROOT/ui/desktop/src/acp/permissionRequests.ts"
ELICITATION_REQUESTS="$WORK_ROOT/ui/desktop/src/acp/elicitationRequests.ts"
node - "$PERMISSION_REQUESTS" "$ELICITATION_REQUESTS" <<'NODE'
const fs = require('fs');
const [permissionPath, elicitationPath] = process.argv.slice(2);

let permissionSource = fs.readFileSync(permissionPath, 'utf8');
const permissionAnchor = `  if (!USE_ACP_CHAT) {
    return cancelledPermissionResponse();
  }

`;
const permissionNativeBridge = `${permissionAnchor}  const epistemosGoose = (window as unknown as {
    epistemos?: {
      goose?: {
        requestPermission?: (
          request: RequestPermissionRequest
        ) => Promise<RequestPermissionResponse>;
      };
    };
  }).epistemos?.goose;
  if (typeof epistemosGoose?.requestPermission === 'function') {
    try {
      return await epistemosGoose.requestPermission(request);
    } catch (error) {
      console.error('Epistemos native permission bridge failed', error);
    }
  }

`;
if (!permissionSource.includes('requestPermission(request)')) {
  if (!permissionSource.includes(permissionAnchor)) {
    throw new Error('permissionRequests ACP anchor not found');
  }
  permissionSource = permissionSource.replace(permissionAnchor, permissionNativeBridge);
  fs.writeFileSync(permissionPath, permissionSource);
}

let elicitationSource = fs.readFileSync(elicitationPath, 'utf8');
const elicitationAnchor = `  if (!USE_ACP_CHAT || !isSessionScopedFormElicitation(request)) {
    return cancelledElicitationResponse();
  }

`;
const elicitationNativeBridge = `${elicitationAnchor}  const epistemosGoose = (window as unknown as {
    epistemos?: {
      goose?: {
        requestElicitation?: (
          request: SessionScopedFormElicitationRequest
        ) => Promise<CreateElicitationResponse>;
      };
    };
  }).epistemos?.goose;
  if (typeof epistemosGoose?.requestElicitation === 'function') {
    try {
      return await epistemosGoose.requestElicitation(request);
    } catch (error) {
      console.error('Epistemos native elicitation bridge failed', error);
    }
  }

`;
if (!elicitationSource.includes('requestElicitation(request)')) {
  if (!elicitationSource.includes(elicitationAnchor)) {
    throw new Error('elicitationRequests ACP anchor not found');
  }
  elicitationSource = elicitationSource.replace(elicitationAnchor, elicitationNativeBridge);
  fs.writeFileSync(elicitationPath, elicitationSource);
}
NODE

CHAT_INPUT="$WORK_ROOT/ui/desktop/src/components/ChatInput.tsx"
FILE_DROP_HOOK="$WORK_ROOT/ui/desktop/src/hooks/useFileDrop.ts"
node - "$CHAT_INPUT" "$FILE_DROP_HOOK" <<'NODE'
const fs = require('fs');
const [chatInputPath, fileDropPath] = process.argv.slice(2);

let chatInputSource = fs.readFileSync(chatInputPath, 'utf8');
const fileSelectAnchor = `  const fileInputRef = React.useRef<HTMLInputElement>(null);

  const handleFileSelect = () => {
    if (isFilePickerOpen) return;
    fileInputRef.current?.click();
  };

`;
const fileSelectReplacement = `  const fileInputRef = React.useRef<HTMLInputElement>(null);

  const nativeImageMimeTypeForPath = (filePath: string): string | null => {
    const extension = filePath.split(/[\\\\/]/).pop()?.split('.').pop()?.toLowerCase();
    switch (extension) {
      case 'apng':
        return 'image/apng';
      case 'avif':
        return 'image/avif';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'svg':
        return 'image/svg+xml';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  };

  const handleNativeFilePath = async (filePath: string) => {
    const imageMimeType = nativeImageMimeTypeForPath(filePath);
    if (imageMimeType) {
      trackFileAttached('file');

      if (pastedImages.length >= MAX_IMAGES_PER_MESSAGE) {
        console.warn(\`Maximum \${MAX_IMAGES_PER_MESSAGE} images per message\`);
        return;
      }

      const uniqueId = \`upload-\${Date.now()}-\${Math.random().toString(36).substr(2, 9)}\`;
      setPastedImages((prev) => [
        ...prev,
        {
          id: uniqueId,
          dataUrl: '',
          isLoading: true,
          error: undefined,
        },
      ]);

      try {
        const nativeElectron = window.electron as typeof window.electron & {
          readFileDataURL?: (path: string) => Promise<string | null>;
          showOpenDialog?: (options?: unknown) => Promise<{ canceled?: boolean; filePaths?: string[] }>;
        };
        const dataUrl = await nativeElectron.readFileDataURL?.(filePath);
        if (!dataUrl || !dataUrl.startsWith('data:image/')) {
          throw new Error('Native image data is unavailable');
        }
        const compressedDataUrl = await compressImageDataUrl(dataUrl);
        setPastedImages((prev) =>
          prev.map((img) =>
            img.id === uniqueId
              ? { ...img, dataUrl: compressedDataUrl, isLoading: false, error: undefined }
              : img
          )
        );
      } catch (error) {
        const message = error instanceof Error ? error.message : intl.formatMessage(i18n.failedToReadImage);
        setPastedImages((prev) =>
          prev.map((img) =>
            img.id === uniqueId ? { ...img, isLoading: false, error: message } : img
          )
        );
      }
      return;
    }

    trackFileAttached('file');
    const newValue = displayValue.trim() ? \`\${displayValue.trim()} \${filePath}\` : filePath;
    setDisplayValue(newValue);
    setValue(newValue);
  };

  const handleFileSelect = async () => {
    if (isFilePickerOpen) return;
    const nativeElectron = window.electron as typeof window.electron & {
      readFileDataURL?: (path: string) => Promise<string | null>;
      showOpenDialog?: (options?: unknown) => Promise<{ canceled?: boolean; filePaths?: string[] }>;
    };
    if (
      typeof nativeElectron.showOpenDialog === 'function' &&
      typeof nativeElectron.readFileDataURL === 'function'
    ) {
      setIsFilePickerOpen(true);
      try {
        const result = await nativeElectron.showOpenDialog({
          properties: ['openFile'],
        });
        const filePath = result?.filePaths?.[0];
        if (result?.canceled || !filePath) return;
        await handleNativeFilePath(filePath);
      } finally {
        setIsFilePickerOpen(false);
      }
      textAreaRef.current?.focus();
      return;
    }
    fileInputRef.current?.click();
  };

`;
if (!chatInputSource.includes('handleNativeFilePath')) {
  if (!chatInputSource.includes(fileSelectAnchor)) {
    throw new Error('ChatInput file select anchor not found');
  }
  chatInputSource = chatInputSource.replace(fileSelectAnchor, fileSelectReplacement);
  fs.writeFileSync(chatInputPath, chatInputSource);
}

let fileDropSource = fs.readFileSync(fileDropPath, 'utf8');
const fileDropImportAnchor = `import { compressImageDataUrl, errorMessage } from '../utils/conversionUtils';

`;
const fileDropHelpers = `${fileDropImportAnchor}function nativeFilePathsFromDataTransfer(dataTransfer: DataTransfer): string[] {
  const values = ['text/uri-list', 'public.file-url', 'text/plain']
    .flatMap((type) => {
      try {
        return dataTransfer.getData(type).split(/\\r?\\n/);
      } catch {
        return [];
      }
    })
    .map((value) => value.trim())
    .filter((value) => value && !value.startsWith('#'));

  const seen = new Set<string>();
  return values.flatMap((value) => {
    try {
      const url = new URL(value);
      if (url.protocol !== 'file:') return [];
      const path = decodeURIComponent(url.pathname);
      if (!path || seen.has(path)) return [];
      seen.add(path);
      return [path];
    } catch {
      if (!value.startsWith('/') || seen.has(value)) return [];
      seen.add(value);
      return [value];
    }
  });
}

`;
if (!fileDropSource.includes('nativeFilePathsFromDataTransfer')) {
  if (!fileDropSource.includes(fileDropImportAnchor)) {
    throw new Error('useFileDrop import anchor not found');
  }
  fileDropSource = fileDropSource.replace(fileDropImportAnchor, fileDropHelpers);
}
const filesAnchor = `    const files = e.dataTransfer.files;
    if (files.length > 0) {`;
const filesReplacement = `    const files = e.dataTransfer.files;
    const nativePaths = nativeFilePathsFromDataTransfer(e.dataTransfer);
    if (files.length > 0) {`;
// #7/#20: marker-guarded hard-fail (idempotent on re-stage, but FAILS LOUDLY if upstream
// drifts) instead of silently no-opping the native drag-drop path resolution.
if (!fileDropSource.includes('nativeFilePathsFromDataTransfer(e.dataTransfer)')) {
  if (!fileDropSource.includes(filesAnchor)) {
    throw new Error('useFileDrop files anchor not found');
  }
  fileDropSource = fileDropSource.replace(filesAnchor, filesReplacement);
}
const pathAnchor = `          const path = window.electron.getPathForFile(file);`;
const pathReplacement = `          const path = nativePaths[i] || window.electron.getPathForFile(file);`;
if (!fileDropSource.includes('nativePaths[i] ||')) {
  if (!fileDropSource.includes(pathAnchor)) {
    throw new Error('useFileDrop path anchor not found');
  }
  fileDropSource = fileDropSource.replace(pathAnchor, pathReplacement);
}
fs.writeFileSync(fileDropPath, fileDropSource);
NODE

RECIPE_MANAGEMENT="$WORK_ROOT/ui/desktop/src/recipe/recipe_management.ts"
node - "$RECIPE_MANAGEMENT" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

if (!source.includes('EPISTEMOS_ACP_RECIPE_ID_RECONCILIATION_MARKER')) {
  const importAnchor = `import type { Recipe, RecipeManifest } from '.';
`;
  const helper = `${importAnchor}
const EPISTEMOS_ACP_RECIPE_ID_RECONCILIATION_MARKER =
  'epistemos-acp-recipe-id-reconciliation';

type SavedRecipeResponse = { id: string; file_name: string; file_path: string };

function normalizeRecipePath(path?: string | null): string {
  if (!path) return '';
  return path.startsWith('/private/var/') ? path.slice('/private'.length) : path;
}

function fileNameFromPath(path?: string | null): string {
  if (!path) return '';
  const parts = path.split(/[\\\\/]/);
  return parts[parts.length - 1] || '';
}

function recordRecipeIDReconciliation(savedId: string, resolvedId: string): void {
  const target = window as Window & {
    __epistemosGooseRecipeIDReconciliation?: Array<{ savedId: string; resolvedId: string }>;
  };
  target.__epistemosGooseRecipeIDReconciliation ??= [];
  target.__epistemosGooseRecipeIDReconciliation.push({ savedId, resolvedId });
  target.__epistemosGooseRecipeIDReconciliation =
    target.__epistemosGooseRecipeIDReconciliation.slice(-16);
  void EPISTEMOS_ACP_RECIPE_ID_RECONCILIATION_MARKER;
}

async function reconcileSavedRecipeResponse(
  recipe: Recipe,
  response: SavedRecipeResponse
): Promise<SavedRecipeResponse> {
  try {
    const savedPath = normalizeRecipePath(response.file_path);
    const savedFileName = response.file_name || fileNameFromPath(response.file_path);
    const recipes = await acpListRecipes();
    const listed = recipes.find((entry) => normalizeRecipePath(entry.file_path) === savedPath)
      ?? recipes.find((entry) =>
        fileNameFromPath(entry.file_path) === savedFileName &&
        entry.recipe?.title === recipe.title
      );
    if (!listed?.id) {
      return response;
    }
    if (listed.id !== response.id) {
      recordRecipeIDReconciliation(response.id, listed.id);
    }
    return {
      id: listed.id,
      file_name: response.file_name || fileNameFromPath(listed.file_path),
      file_path: listed.file_path || response.file_path,
    };
  } catch (error) {
    console.warn('Failed to reconcile saved recipe id through ACP list:', error);
    return response;
  }
}
`;
  if (!source.includes(importAnchor)) {
    throw new Error('recipe_management import anchor not found');
  }
  source = source.replace(importAnchor, helper);

  const saveAnchor = `    const response = await acpSaveRecipe(stripEmptyExtensions(recipe), recipeId);
    return {
      id: response.id,
      fileName: response.file_name,
      filePath: response.file_path,
    };`;
  const saveReplacement = `    const response = await reconcileSavedRecipeResponse(
      recipe,
      await acpSaveRecipe(stripEmptyExtensions(recipe), recipeId)
    );
    return {
      id: response.id,
      fileName: response.file_name,
      filePath: response.file_path,
    };`;
  if (!source.includes(saveAnchor)) {
    throw new Error('recipe_management save response anchor not found');
  }
  source = source.replace(saveAnchor, saveReplacement);
  fs.writeFileSync(path, source);
}
NODE

RENDERER_CONFIG="$WORK_ROOT/ui/desktop/vite.renderer.config.mts"
if ! grep -q "base: './'" "$RENDERER_CONFIG"; then
    node -e "const fs = require('fs'); const p = process.argv[1]; const source = fs.readFileSync(p, 'utf8'); fs.writeFileSync(p, source.replace('export default defineConfig({\n', \"export default defineConfig({\n  base: './',\n\"));" "$RENDERER_CONFIG"
fi

if [ "${EPISTEMOS_GOOSE_UI_VALIDATE_ONLY:-0}" = "1" ]; then
    grep -q "export const USE_ACP_CHAT = true;" "$WORK_ROOT/ui/desktop/src/acpChatFeatureFlag.ts"
    grep -q "providersList_unstable({ providerIds: \[\] })" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "providersSetupCatalogList_unstable({})" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "getProviderInventoryAcpClient()" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "getProviderCatalogAcpClient()" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "shared-getAcpClient-provider-inventory" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "localAcpConfigKeys = new Set" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "local-acp-config-GOOSE_TELEMETRY_ENABLED" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "GOOSE_TELEMETRY_ENABLED" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "__epistemosGooseProviderInventoryEvents" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "Goose ACP provider inventory failed:" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "__epistemosGooseACPRequestSerialization" "$WORK_ROOT/ui/desktop/src/acp/acpConnection.ts"
    grep -q "return serializeACPRequests(client);" "$WORK_ROOT/ui/desktop/src/acp/acpConnection.ts"
    grep -q "name: model.id || model.name" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "listAcpProviderModels(p.name)" "$WORK_ROOT/ui/desktop/src/components/settings/models/modelInterface.ts"
    grep -q "LM Studio is not reachable at http://localhost:1234" "$WORK_ROOT/ui/desktop/src/components/settings/models/modelInterface.ts"
    grep -q "listAcpProviderSecrets" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "providersConfigStatus_unstable" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "await listAcpProviderSecrets()" "$WORK_ROOT/ui/desktop/src/components/settings/auth/AuthSettingsSection.tsx"
    grep -q "border-border-danger bg-background-danger/55 text-text-danger" "$WORK_ROOT/ui/desktop/src/components/settings/auth/AuthSettingsSection.tsx"
    grep -q "rounded-\\[10px\\] border border-transparent px-3 py-3" "$WORK_ROOT/ui/desktop/src/components/settings/auth/AuthSettingsSection.tsx"
    grep -q "ep-native-badge px-2 py-0.5 text-xs" "$WORK_ROOT/ui/desktop/src/components/settings/auth/AuthSettingsSection.tsx"
    grep -q "rounded-\\[10px\\] border border-border-secondary bg-background-primary/68 p-3" "$WORK_ROOT/ui/desktop/src/components/settings/auth/HuggingFaceSignInPrompt.tsx"
    grep -q "rounded-\\[10px\\] border border-border-secondary bg-background-primary/68 p-3 shadow-sm" "$WORK_ROOT/ui/desktop/src/components/settings/localInference/LocalInferenceSettings.tsx"
    grep -q "h-2 w-full overflow-hidden rounded-full bg-background-secondary/72" "$WORK_ROOT/ui/desktop/src/components/settings/localInference/LocalInferenceSettings.tsx"
    grep -q "border-\\[var(--epistemos-accent)\\] bg-background-primary/78" "$WORK_ROOT/ui/desktop/src/components/settings/localInference/LocalInferenceSettings.tsx"
    grep -q "text-xs text-text-danger" "$WORK_ROOT/ui/desktop/src/components/settings/localInference/LocalInferenceSettings.tsx"
    grep -q "min-h-9 w-full rounded-\\[9px\\]" "$WORK_ROOT/ui/desktop/src/components/settings/localInference/HuggingFaceModelSearch.tsx"
    grep -q "rounded-\\[10px\\] border border-border-secondary bg-background-primary/68 shadow-sm" "$WORK_ROOT/ui/desktop/src/components/settings/localInference/HuggingFaceModelSearch.tsx"
    grep -q "ep-native-badge px-1.5 py-0.5 text-xs uppercase" "$WORK_ROOT/ui/desktop/src/components/settings/localInference/HuggingFaceModelSearch.tsx"
    grep -q "min-h-8 w-full rounded-\\[8px\\] border border-border-secondary" "$WORK_ROOT/ui/desktop/src/components/settings/localInference/ModelSettingsPanel.tsx"
    grep -q "flex items-center justify-between gap-2 rounded-\\[9px\\] border border-transparent px-2 py-2" "$WORK_ROOT/ui/desktop/src/components/settings/localInference/ModelSettingsPanel.tsx"
    grep -q "min-h-32 rounded-\\[8px\\] border border-border-secondary" "$WORK_ROOT/ui/desktop/src/components/settings/localInference/ModelSettingsPanel.tsx"
    grep -q "rounded-\\[10px\\] border border-border-danger bg-background-danger/55" "$WORK_ROOT/ui/desktop/src/components/settings/gateways/GatewaySettingsSection.tsx"
    grep -q "rounded-\\[9px\\] border border-border-secondary bg-background-primary/68 px-2 py-1.5" "$WORK_ROOT/ui/desktop/src/components/settings/gateways/GatewaySettingsSection.tsx"
    grep -q "border-border-secondary bg-background-primary/68 shadow-sm backdrop-blur-xl" "$WORK_ROOT/ui/desktop/src/components/settings/gateways/GatewaySettingsSection.tsx"
    grep -q "ep-native-badge px-2 py-0.5 text-\\[10px\\] uppercase" "$WORK_ROOT/ui/desktop/src/components/settings/gateways/GatewaySettingsSection.tsx"
    grep -q "border-border-secondary bg-background-primary/82 shadow-lg backdrop-blur-xl" "$WORK_ROOT/ui/desktop/src/components/settings/gateways/GatewaySettingsSection.tsx"
    grep -q "rounded-\\[9px\\] border border-transparent px-2 py-2" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/DictationSettings.tsx"
    grep -q "epistemos-acp-dictation-config-ui" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/DictationSettings.tsx"
    grep -q "epistemos-acp-dictation-secret-save-ui" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/DictationSettings.tsx"
    grep -q "epistemos-acp-dictation-secret-delete-ui" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/DictationSettings.tsx"
    grep -q "voice_dictation_provider: 'voiceDictationProvider'" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "voice_dictation_preferred_mic: 'voiceDictationPreferredMic'" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "epistemos-acp-dictation-config" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "epistemos-acp-dictation-transcribe" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "dictationTranscribe_unstable" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "epistemos-acp-dictation-secret-save" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "epistemos-acp-dictation-secret-delete" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "epistemos-acp-dictation-models-list" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "epistemos-acp-dictation-model-download" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "epistemos-acp-dictation-model-cancel" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "epistemos-acp-dictation-model-delete" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "epistemos-acp-dictation-model-select" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "min-h-9 items-center gap-2 rounded-\\[8px\\] border border-border-secondary" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/DictationSettings.tsx"
    grep -q "rounded-\\[9px\\] border border-transparent px-2 py-2" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/MicrophoneSelector.tsx"
    grep -q "h-2 w-full overflow-hidden rounded-full bg-background-secondary/72" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/MicrophoneSelector.tsx"
    grep -q "epistemos-acp-dictation-config-hook" "$WORK_ROOT/ui/desktop/src/hooks/useAudioRecorder.ts"
    grep -q "epistemos-acp-dictation-transcribe-hook" "$WORK_ROOT/ui/desktop/src/hooks/useAudioRecorder.ts"
    grep -q "transcribeAcpDictation(base64, 'audio/wav', prov)" "$WORK_ROOT/ui/desktop/src/hooks/useAudioRecorder.ts"
    grep -q "rounded-\\[10px\\] border p-3 shadow-sm backdrop-blur-xl" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/LocalModelManager.tsx"
    grep -q "epistemos-acp-dictation-selected-model" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/LocalModelManager.tsx"
    grep -q "epistemos-acp-dictation-models-list-ui" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/LocalModelManager.tsx"
    grep -q "epistemos-acp-dictation-model-download-ui" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/LocalModelManager.tsx"
    grep -q "readAcpDictationModelDownloadProgress(modelId)" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/LocalModelManager.tsx"
    grep -q "epistemos-acp-dictation-model-delete-ui" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/LocalModelManager.tsx"
    grep -q "ep-native-badge px-2 py-0.5 text-xs text-\\[var(--epistemos-accent)\\]" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/LocalModelManager.tsx"
    grep -q "h-1.5 w-full overflow-hidden rounded-full bg-background-secondary/72" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/LocalModelManager.tsx"
    grep -q "mt-2 text-xs text-text-danger" "$WORK_ROOT/ui/desktop/src/components/settings/dictation/LocalModelManager.tsx"
    grep -q "min-h-9 w-full rounded-\\[8px\\] border px-3 py-2 text-sm placeholder:text-text-secondary" "$WORK_ROOT/ui/desktop/src/components/settings/security/SecurityToggle.tsx"
    grep -q "min-h-8 w-24 rounded-\\[8px\\] border px-2 py-1 text-sm" "$WORK_ROOT/ui/desktop/src/components/settings/security/SecurityToggle.tsx"
    grep -q "rounded-\\[9px\\] border border-transparent px-2 py-2" "$WORK_ROOT/ui/desktop/src/components/settings/security/SecurityToggle.tsx"
    grep -q "border-t border-border-secondary pt-4" "$WORK_ROOT/ui/desktop/src/components/settings/security/SecurityToggle.tsx"
    grep -q "mt-2 text-sm text-text-success" "$WORK_ROOT/ui/desktop/src/components/settings/security/SecurityToggle.tsx"
    grep -q "border-border-secondary bg-background-primary/68 pb-2 shadow-sm backdrop-blur-xl" "$WORK_ROOT/ui/desktop/src/components/settings/sessions/SessionSharingSection.tsx"
    grep -q "text-sm text-text-danger" "$WORK_ROOT/ui/desktop/src/components/settings/sessions/SessionSharingSection.tsx"
    grep -q "rounded-\\[10px\\] border p-3 text-sm" "$WORK_ROOT/ui/desktop/src/components/settings/sessions/SessionSharingSection.tsx"
    grep -q "border-border-success bg-background-success/55 text-text-success" "$WORK_ROOT/ui/desktop/src/components/settings/sessions/SessionSharingSection.tsx"
    grep -q "Epistemos Apps bridge unavailable" "$WORK_ROOT/ui/desktop/src/epistemos/appsBridge.ts"
    grep -q "Epistemos context bridge unavailable" "$WORK_ROOT/ui/desktop/src/epistemos/contextBridge.ts"
    grep -q "if (snapshot.available === false) return '';" "$WORK_ROOT/ui/desktop/src/epistemos/contextBridge.ts"
    grep -q "formatEpistemosContextForPrompt" "$WORK_ROOT/ui/desktop/src/epistemos/contextBridge.ts"
    grep -q "getEpistemosContextSnapshot" "$WORK_ROOT/ui/desktop/src/components/ChatInput.tsx"
    grep -q "handleAttachEpistemosContext" "$WORK_ROOT/ui/desktop/src/components/ChatInput.tsx"
    grep -q "Attach Epistemos context" "$WORK_ROOT/ui/desktop/src/components/ChatInput.tsx"
    grep -q "BookOpen" "$WORK_ROOT/ui/desktop/src/components/ChatInput.tsx"
    grep -q "epistemos-acp-session-mode-setting" "$WORK_ROOT/ui/desktop/src/components/settings/mode/ModeSection.tsx"
    grep -q "saveAcpSessionMode(sessionId, newMode)" "$WORK_ROOT/ui/desktop/src/components/settings/mode/ModeSection.tsx"
    grep -q "epistemos-acp-next-session-mode-default" "$WORK_ROOT/ui/desktop/src/components/settings/mode/ModeSection.tsx"
    grep -q "useChatContext()" "$WORK_ROOT/ui/desktop/src/components/settings/mode/ModeSection.tsx"
    grep -q "epistemos-acp-new-session-mode-default" "$WORK_ROOT/ui/desktop/src/components/Hub.tsx"
    grep -q "gooseMode: configuredGooseMode" "$WORK_ROOT/ui/desktop/src/components/Hub.tsx"
    grep -q "read('GOOSE_MODE', false)" "$WORK_ROOT/ui/desktop/src/components/Hub.tsx"
    grep -q "mb-4 text-text-danger" "$WORK_ROOT/ui/desktop/src/components/apps/AppsView.tsx"
    grep -q "import { exportApp, importApp, listApps } from '../../epistemos/appsBridge';" "$WORK_ROOT/ui/desktop/src/components/apps/AppsView.tsx"
    grep -q "import { listApps } from '../epistemos/appsBridge';" "$WORK_ROOT/ui/desktop/src/hooks/useChatStream.ts"
    grep -q "import { listApps } from '../epistemos/appsBridge';" "$WORK_ROOT/ui/desktop/src/utils/platform_events.ts"
    grep -q "import { listApps } from '../../epistemos/appsBridge';" "$WORK_ROOT/ui/desktop/src/components/apps/StandaloneAppView.tsx"
    grep -q "saveAcpProviderDefaults(providerName, modelName)" "$WORK_ROOT/ui/desktop/src/components/ModelAndProviderContext.tsx"
    grep -q "saveAcpSessionModel(sessionId, modelName)" "$WORK_ROOT/ui/desktop/src/components/ModelAndProviderContext.tsx"
    grep -q "saveAcpSessionProvider(sessionId, providerName)" "$WORK_ROOT/ui/desktop/src/components/ModelAndProviderContext.tsx"
    ! grep -q "Changing provider for an active ACP session is not wired yet." "$WORK_ROOT/ui/desktop/src/components/ModelAndProviderContext.tsx"
    grep -q "Provider catalog failed:" "$WORK_ROOT/ui/desktop/src/components/settings/providers/ProviderSettingsPage.tsx"
    grep -q "epistemos-acp-recipe-id-reconciliation" "$WORK_ROOT/ui/desktop/src/recipe/recipe_management.ts"
    grep -q "epistemos-native-reskin-overlay" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "epistemos-native-scrollbar-focus-polish" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "epistemos-native-primitive-polish" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "epistemos-native-surface-polish" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "epistemos-native-catalog-screen-polish" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "epistemos-native-loading-error-polish" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "ep-native-loading-dot is-active" "$WORK_ROOT/ui/desktop/src/suspense-loader.tsx"
    grep -q "ep-native-status-line flex items-center gap-2" "$WORK_ROOT/ui/desktop/src/components/LoadingEpistemos.tsx"
    grep -q "ep-native-error-card" "$WORK_ROOT/ui/desktop/src/components/ErrorBoundary.tsx"
    grep -q "h-6 w-6 text-text-danger" "$WORK_ROOT/ui/desktop/src/components/ErrorBoundary.tsx"
    grep -q "text-sm text-text-danger backdrop-blur-xl" "$WORK_ROOT/ui/desktop/src/components/ErrorBoundary.tsx"
    grep -q "border-border-success bg-background-success" "$WORK_ROOT/ui/desktop/src/components/ToolCallStatusIndicator.tsx"
    grep -q "text-\\[var(--epistemos-accent)\\]" "$WORK_ROOT/ui/desktop/src/components/SessionIndicators.tsx"
    grep -q "rounded-full border border-border-success bg-background-success" "$WORK_ROOT/ui/desktop/src/components/GroupedExtensionLoadingToast.tsx"
    grep -q "success: 'bg-background-success'" "$WORK_ROOT/ui/desktop/src/components/ui/Dot.tsx"
    grep -q "text-text-warning" "$WORK_ROOT/ui/desktop/src/components/bottom_menu/ContextWindowIndicator.tsx"
    grep -q "rounded-\\[14px\\] border border-border-primary bg-background-primary/88" "$WORK_ROOT/ui/desktop/src/components/ParameterInputModal.tsx"
    grep -q "border-border-danger" "$WORK_ROOT/ui/desktop/src/components/ParameterInputModal.tsx"
    grep -q "hover:bg-background-danger/55 hover:text-text-danger" "$WORK_ROOT/ui/desktop/src/components/parameter/ParameterInput.tsx"
    grep -q "accent-\\[var(--epistemos-accent)\\]" "$WORK_ROOT/ui/desktop/src/components/ui/JsonSchemaForm.tsx"
    grep -q "border-border-danger" "$WORK_ROOT/ui/desktop/src/components/ui/JsonSchemaForm.tsx"
    grep -q "isUrgent ? 'text-text-danger' : 'text-text-secondary'" "$WORK_ROOT/ui/desktop/src/components/ElicitationRequest.tsx"
    grep -q "border-\\[var(--epistemos-accent)\\]" "$WORK_ROOT/ui/desktop/src/components/common/InlineEditText.tsx"
    grep -q "text-\\[var(--epistemos-accent)\\] hover:underline" "$WORK_ROOT/ui/desktop/src/components/TelemetryConsentPrompt.tsx"
    grep -q "text-\\[var(--epistemos-accent)\\] underline-offset-2" "$WORK_ROOT/ui/desktop/src/components/SessionActionsHeader.tsx"
    grep -q "return 'text-text-danger';" "$WORK_ROOT/ui/desktop/src/components/ExtensionInstallModal.tsx"
    grep -q "return 'text-text-warning';" "$WORK_ROOT/ui/desktop/src/components/ExtensionInstallModal.tsx"
    grep -q "rounded-\\[12px\\] border border-border-danger bg-background-danger/55 p-4 text-text-danger" "$WORK_ROOT/ui/desktop/src/components/McpApps/McpAppRenderer.tsx"
    grep -q "isError && 'rounded-\\[12px\\] border border-border-danger bg-background-danger/35'" "$WORK_ROOT/ui/desktop/src/components/McpApps/McpAppRenderer.tsx"
    grep -q "mb-1 mt-1 text-xs italic text-text-danger" "$WORK_ROOT/ui/desktop/src/components/ImagePreview.tsx"
    grep -q "mb-2 mt-2 text-xs text-text-danger" "$WORK_ROOT/ui/desktop/src/components/UserMessage.tsx"
    grep -q "my-2 rounded-\\[12px\\] border border-border-warning bg-background-warning/55 p-4" "$WORK_ROOT/ui/desktop/src/components/context_management/CreditsExhaustedNotification.tsx"
    grep -q "ep-native-loading-dot is-active" "$WORK_ROOT/ui/desktop/src/components/MessageQueue.tsx"
    grep -q "hover:bg-background-danger/55 hover:text-text-danger" "$WORK_ROOT/ui/desktop/src/components/MessageQueue.tsx"
    grep -q "text-\\[var(--epistemos-accent)\\] hover:opacity-80" "$WORK_ROOT/ui/desktop/src/components/settings/chat/GoosehintsModal.tsx"
    grep -q "mr-auto flex items-center gap-1 text-sm text-text-success" "$WORK_ROOT/ui/desktop/src/components/settings/chat/GoosehintsModal.tsx"
    grep -q "cursor-default text-text-success hover:text-text-success" "$WORK_ROOT/ui/desktop/src/components/settings/providers/subcomponents/buttons/CardButtons.tsx"
    grep -q "text-\\[var(--epistemos-accent)\\] underline hover:opacity-80" "$WORK_ROOT/ui/desktop/src/components/settings/providers/subcomponents/utils/StringUtils.tsx"
    grep -q "border-border-danger" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx"
    grep -q "py-2 text-left text-xs text-text-secondary" "$WORK_ROOT/ui/desktop/src/components/context_management/SystemNotificationInline.tsx"
    grep -q "mb-2 text-sm italic text-text-secondary" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionViewComponents.tsx"
    grep -q "goose-message-tool mt-1 rounded-\\[12px\\] border border-border-secondary bg-background-primary/68" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionViewComponents.tsx"
    grep -q "cursor-not-allowed bg-background-disabled text-text-disabled" "$WORK_ROOT/ui/desktop/src/components/recipes/ImportRecipeForm.tsx"
    grep -q "flex h-screen w-full flex-col items-center justify-center bg-transparent" "$WORK_ROOT/ui/desktop/src/components/schedule/ScheduleDetailView.tsx"
    grep -q "min-h-8 rounded-\\[8px\\] border border-border-secondary bg-background-primary/70" "$WORK_ROOT/ui/desktop/src/components/schedule/CronPicker.tsx"
    grep -q "relative flex h-full w-full items-center justify-center overflow-hidden rounded-\\[12px\\] bg-background-secondary/55" "$WORK_ROOT/ui/desktop/src/components/McpApps/McpAppRenderer.tsx"
    grep -q "hover:bg-background-secondary/72 hover:text-text-primary" "$WORK_ROOT/ui/desktop/src/components/McpApps/McpAppRenderer.tsx"
    grep -q "rounded-\\[8px\\] border border-border-secondary bg-background-primary/78 p-1.5" "$WORK_ROOT/ui/desktop/src/components/MarkdownContent.tsx"
    grep -q "fixed inset-0 z-\\[9999\\] bg-black/24 backdrop-blur-sm" "$WORK_ROOT/ui/desktop/src/components/ui/BaseModal.tsx"
    grep -q "rounded-\\[14px\\] border border-border-primary bg-background-primary/88" "$WORK_ROOT/ui/desktop/src/components/ui/BaseModal.tsx"
    grep -q "fixed inset-0 z-50 flex items-center justify-center bg-black/24 backdrop-blur-sm" "$WORK_ROOT/ui/desktop/src/components/ui/Diagnostics.tsx"
    grep -q "bg-\\[var(--epistemos-accent)\\] text-white hover:bg-\\[var(--epistemos-accent)\\]/90" "$WORK_ROOT/ui/desktop/src/components/ui/Diagnostics.tsx"
    grep -q "border border-border-warning bg-background-warning/75 text-text-warning" "$WORK_ROOT/ui/desktop/src/components/alerts/AlertBox.tsx"
    grep -q "mt-2 flex items-center text-text-secondary" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/SecureStorageNotice.tsx"
    grep -q "group-hover:text-text-primary" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx"
    grep -q "fixed inset-0 z-50 flex items-center justify-center bg-black/24 backdrop-blur-sm animate-\\[fadein_200ms_ease-in\\]" "$WORK_ROOT/ui/desktop/src/components/ParameterInputModal.tsx"
    grep -q "w-full max-w-md rounded-\\[14px\\] border border-border-primary bg-background-primary/88 p-6" "$WORK_ROOT/ui/desktop/src/components/ParameterInputModal.tsx"
    grep -q "goose-message-content rounded-t-\\[12px\\] border border-border-secondary bg-background-secondary/70" "$WORK_ROOT/ui/desktop/src/components/ElicitationRequest.tsx"
    grep -q "goose-message-content rounded-b-\\[12px\\] border border-border-secondary bg-background-primary/68" "$WORK_ROOT/ui/desktop/src/components/ElicitationRequest.tsx"
    grep -q "fixed inset-0 z-\\[500\\] flex items-center justify-center bg-black/24 backdrop-blur-sm" "$WORK_ROOT/ui/desktop/src/components/recipes/shared/SubRecipeModal.tsx"
    grep -q "flex max-h-\\[90vh\\] w-\\[90vw\\] max-w-2xl flex-col overflow-hidden rounded-\\[14px\\]" "$WORK_ROOT/ui/desktop/src/components/recipes/shared/CreateSubRecipeInline.tsx"
    grep -q "fixed inset-0 z-\\[400\\] flex items-center justify-center bg-black/24 backdrop-blur-sm" "$WORK_ROOT/ui/desktop/src/components/recipes/shared/InstructionsEditor.tsx"
    grep -q "fixed inset-0 z-\\[400\\] flex items-center justify-center bg-black/24 backdrop-blur-sm" "$WORK_ROOT/ui/desktop/src/components/recipes/shared/JsonSchemaEditor.tsx"
    grep -q "fixed inset-0 z-50 bg-black/24 backdrop-blur-sm" "$WORK_ROOT/ui/desktop/src/components/ui/sheet.tsx"
    grep -q "border-t border-border-secondary" "$WORK_ROOT/ui/desktop/src/components/bottom_menu/BottomMenuAlertPopover.tsx"
    grep -q "mt-3 border-t border-border-secondary pt-3" "$WORK_ROOT/ui/desktop/src/components/GroupedExtensionLoadingToast.tsx"
    grep -q "scrollbar-width: auto !important" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "epistemos-native-high-quality-flat-polish" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "epistemos-native-claude-pixel-polish" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "epistemos-native-claude-pixel-contract" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "epistemos-native-final-flat-pixel-audit" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q -- "--epistemos-pixel-font:" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q -- "--tw-ring-shadow: 0 0 #0000 !important" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "backdrop-filter: none !important" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "outline: none !important" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "border-width: 0 !important" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "border-right-width: 0 !important" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "background-color: color-mix(in srgb, var(--epistemos-accent) 7%, var(--epistemos-glass-fill))" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    grep -q "background: color-mix(in srgb, var(--epistemos-pixel-accent) 7%, var(--epistemos-claude-surface))" "$WORK_ROOT/ui/desktop/src/styles/main.css"
    if grep -R -E "focus:ring|ring-blue|text-blue|bg-blue|border-blue|#0066cc|#2997ff|outline: 2px solid|inset 0 0 0 1px|ring-\\[3px\\]|ring-\\[var\\(--epistemos-accent\\)\\]" "$WORK_ROOT/ui/desktop/src" >/dev/null 2>&1; then
        echo "Goose Web UI staging still contains blue/ring/outline visual leftovers." >&2
        exit 1
    fi
    grep -q "bg-\\[var(--epistemos-accent)\\] text-white hover:bg-\\[var(--epistemos-accent)\\]/90" "$WORK_ROOT/ui/desktop/src/components/ui/button.tsx"
    grep -q "rounded-\\[8px\\] border border-border-primary bg-background-primary/70" "$WORK_ROOT/ui/desktop/src/components/ui/input.tsx"
    grep -q "rounded-\\[11px\\] border border-border-secondary" "$WORK_ROOT/ui/desktop/src/components/ui/card.tsx"
    grep -q "rounded-\\[14px\\] border border-border-primary" "$WORK_ROOT/ui/desktop/src/components/ui/dialog.tsx"
    grep -q "rounded-\\[9px\\] border border-border-primary p-1 shadow-lg backdrop-blur-xl" "$WORK_ROOT/ui/desktop/src/components/ui/dropdown-menu.tsx"
    grep -q "className=\"goose-epistemos relative w-screen h-screen overflow-hidden bg-transparent flex flex-col\"" "$WORK_ROOT/ui/desktop/src/App.tsx"
    grep -q "className=\"h-screen w-full bg-transparent" "$WORK_ROOT/ui/desktop/src/components/onboarding/OnboardingGuard.tsx"
    grep -q "rounded-\\[12px\\] border border-border-success bg-background-success/55" "$WORK_ROOT/ui/desktop/src/components/onboarding/OnboardingSuccess.tsx"
    grep -q "rounded-\\[10px\\] border border-border-secondary bg-background-primary/68 p-3" "$WORK_ROOT/ui/desktop/src/components/onboarding/LocalModelPicker.tsx"
    grep -q "backgroundColor = 'bg-transparent'" "$WORK_ROOT/ui/desktop/src/components/Layout/MainPanelLayout.tsx"
    grep -q "bg-background-secondary/62 backdrop-blur-xl" "$WORK_ROOT/ui/desktop/src/components/Layout/AppLayout.tsx"
    grep -q "goose-chat-input-card overflow-hidden rounded-\\[16px\\]" "$WORK_ROOT/ui/desktop/src/components/ChatInputCard.tsx"
    grep -q "goose-tool-call w-full text-sm font-sans rounded-\\[14px\\]" "$WORK_ROOT/ui/desktop/src/components/ToolCallWithResponse.tsx"
    grep -q "fixed z-50 bg-background-primary/88 border border-border-primary rounded-\\[14px\\]" "$WORK_ROOT/ui/desktop/src/components/MentionPopover.tsx"
    grep -q "text-2xl font-sans font-semibold tracking-normal" "$WORK_ROOT/ui/desktop/src/components/settings/SettingsView.tsx"
    grep -q "epistemos-acp-hide-session-sharing" "$WORK_ROOT/ui/desktop/src/components/settings/SettingsView.tsx"
    grep -q "const \\[tunnelDisabled, setTunnelDisabled\\] = useState(USE_ACP_CHAT); // epistemos-acp-hide-session-sharing" "$WORK_ROOT/ui/desktop/src/components/settings/SettingsView.tsx"
    grep -q "sharing: USE_ACP_CHAT ? 'models' : 'sharing', // epistemos-acp-hide-session-sharing" "$WORK_ROOT/ui/desktop/src/components/settings/SettingsView.tsx"
    grep -q "bg-background-primary/58 px-6 pb-5 pt-14 border-b border-border-secondary backdrop-blur-xl" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionListView.tsx"
    grep -q "import { USE_ACP_CHAT } from '../../acpChatFeatureFlag';" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionListView.tsx"
    grep -q "const \\[nostrEnabled, setNostrEnabled\\] = useState(!USE_ACP_CHAT); // epistemos-acp-disable-nostr-session-links" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionListView.tsx"
    grep -q "setNostrEnabled(false); // epistemos-acp-disable-nostr-session-links" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionListView.tsx"
    grep -q "hover:bg-background-danger/55" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionListView.tsx"
    grep -q "mb-4 h-12 w-12 text-text-danger" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionListView.tsx"
    grep -q "ep-native-header-band flex flex-col rounded-\\[16px\\] border border-border-secondary p-4 shadow-sm" "$WORK_ROOT/ui/desktop/src/components/sessions/SharedSessionView.tsx"
    grep -q "ep-native-header-band flex flex-col rounded-\\[16px\\] border border-border-secondary p-4 pt-5 shadow-sm" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionHistoryView.tsx"
    grep -q "epistemos-acp-hide-session-history-sharing" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionHistoryView.tsx"
    grep -q "setCanShare(false); // epistemos-acp-hide-session-history-sharing" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionHistoryView.tsx"
    grep -q "return; // epistemos-acp-hide-session-history-sharing" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionHistoryView.tsx"
    grep -q "mb-4 text-text-danger" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionHistoryView.tsx"
    grep -q "mb-4 text-text-danger" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionViewComponents.tsx"
    grep -q "DialogTitle className=\"flex items-center justify-center gap-2 font-sans font-semibold tracking-normal\"" "$WORK_ROOT/ui/desktop/src/components/sessions/SessionHistoryView.tsx"
    grep -q "ep-native-header-band mx-6 mt-6 flex-shrink-0 rounded-\\[16px\\]" "$WORK_ROOT/ui/desktop/src/components/schedule/ScheduleDetailView.tsx"
    grep -q "font-semibold text-text-success" "$WORK_ROOT/ui/desktop/src/components/schedule/ScheduleDetailView.tsx"
    grep -q "border-border-danger bg-background-danger/35 text-text-danger" "$WORK_ROOT/ui/desktop/src/components/schedule/ScheduleDetailView.tsx"
    grep -q "ep-native-list-card cursor-pointer border p-4" "$WORK_ROOT/ui/desktop/src/components/schedule/ScheduleDetailView.tsx"
    grep -q "h-8 rounded-\\[8px\\] text-text-secondary hover:bg-background-danger/55" "$WORK_ROOT/ui/desktop/src/components/schedule/SchedulesView.tsx"
    grep -q "ep-native-screen-card z-50 flex max-h-\\[90vh\\]" "$WORK_ROOT/ui/desktop/src/components/schedule/ScheduleModal.tsx"
    grep -q "text-text-danger" "$WORK_ROOT/ui/desktop/src/components/schedule/ScheduleModal.tsx"
    grep -q "rounded-\\[10px\\] border border-border-secondary bg-background-secondary/70" "$WORK_ROOT/ui/desktop/src/components/schedule/ScheduleModal.tsx"
    grep -q "ep-native-screen-card flex h-\\[90vh\\] w-\\[90vw\\] max-w-4xl" "$WORK_ROOT/ui/desktop/src/components/recipes/CreateEditRecipeModal.tsx"
    grep -q "h-4 w-4 text-text-success" "$WORK_ROOT/ui/desktop/src/components/recipes/CreateEditRecipeModal.tsx"
    grep -q "ep-native-screen-card w-\\[500px\\] max-w-\\[90vw\\] border p-6" "$WORK_ROOT/ui/desktop/src/components/recipes/ImportRecipeForm.tsx"
    grep -q "ep-native-screen-card flex max-h-\\[80vh\\] w-\\[800px\\]" "$WORK_ROOT/ui/desktop/src/components/recipes/ImportRecipeForm.tsx"
    grep -q "border-border-danger" "$WORK_ROOT/ui/desktop/src/components/recipes/ImportRecipeForm.tsx"
    grep -q "mr-2 h-2 w-2 rounded-full bg-background-success" "$WORK_ROOT/ui/desktop/src/components/RecipeHeader.tsx"
    grep -q "h-8 w-8 rounded-\\[8px\\] p-0 text-text-secondary hover:bg-background-danger/55" "$WORK_ROOT/ui/desktop/src/components/recipes/RecipesView.tsx"
    grep -q "mb-4 h-12 w-12 text-text-danger" "$WORK_ROOT/ui/desktop/src/components/recipes/RecipesView.tsx"
    grep -q "mb-4 h-12 w-12 text-text-danger" "$WORK_ROOT/ui/desktop/src/components/skills/SkillsView.tsx"
    grep -q "ep-native-badge cursor-pointer border px-3 py-1.5" "$WORK_ROOT/ui/desktop/src/components/recipes/RecipeActivities.tsx"
    grep -q "bg-\\[var(--epistemos-accent)\\] px-4 py-2" "$WORK_ROOT/ui/desktop/src/components/recipes/RecipeActivityEditor.tsx"
    grep -q "border-border-danger" "$WORK_ROOT/ui/desktop/src/components/recipes/shared/RecipeNameField.tsx"
    grep -q "border-border-danger" "$WORK_ROOT/ui/desktop/src/components/recipes/shared/InstructionsEditor.tsx"
    grep -q "border-border-danger" "$WORK_ROOT/ui/desktop/src/components/recipes/shared/JsonSchemaEditor.tsx"
    grep -q "rounded-\\[8px\\] bg-\\[var(--epistemos-accent)\\] px-4 py-2" "$WORK_ROOT/ui/desktop/src/components/recipes/shared/RecipeFormFields.tsx"
    grep -q "rounded-\\[12px\\] border border-border-secondary bg-background-primary/68 p-4" "$WORK_ROOT/ui/desktop/src/components/recipes/shared/SubRecipeEditor.tsx"
    grep -q "rounded-\\[12px\\] border border-border-danger bg-background-danger/55" "$WORK_ROOT/ui/desktop/src/components/recipes/shared/RecipeModelSelector.tsx"
    grep -q "rounded-\\[12px\\] border border-border-warning bg-background-warning/55" "$WORK_ROOT/ui/desktop/src/components/ui/RecipeWarningModal.tsx"
    grep -q "ep-native-badge px-1.5 py-0.5 text-xs break-all" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/ProviderConfigurationModal.tsx"
    grep -q "text-text-warning' : 'text-text-danger" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/ProviderConfigurationModal.tsx"
    grep -q "rounded-\\[14px\\] border border-border-primary bg-background-secondary/70" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/ProviderLogo.tsx"
    grep -q "h-11 w-full rounded-\\[8px\\] border border-border-secondary" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/ProviderSetupActions.tsx"
    grep -q "accent-\\[var(--epistemos-accent)\\]" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/forms/DefaultProviderSetupForm.tsx"
    grep -q "min-h-12 w-full rounded-\\[10px\\] px-4" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/forms/DefaultProviderSetupForm.tsx"
    grep -q "rounded-\\[10px\\] border border-dashed border-border-secondary bg-background-primary/55" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/forms/DefaultProviderSetupForm.tsx"
    grep -q "rounded-\\[10px\\] border border-border-secondary bg-background-primary/68 p-4" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx"
    grep -q "rounded-\\[10px\\] border border-border-warning bg-background-warning/55" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx"
    grep -q "rounded-\\[10px\\] border border-border-danger bg-background-danger/55" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx"
    grep -q "ep-native-badge px-2 py-0.5 text-\\[10px\\] text-primary" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/forms/CustomProviderForm.tsx"
    grep -q "rounded-\\[10px\\] border border-border-secondary bg-background-primary/68 p-4" "$WORK_ROOT/ui/desktop/src/components/settings/providers/modal/subcomponents/ProviderCatalogPicker.tsx"
    grep -q "max-h-\\[88vh\\] overflow-y-auto sm:max-w-\\[640px\\]" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/modal/ExtensionModal.tsx"
    grep -q "rounded-\\[12px\\] border border-border-primary bg-background-secondary/72" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/modal/ExtensionModal.tsx"
    grep -q "rounded-\\[8px\\] border border-border-secondary bg-background-primary/70" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/modal/EnvVarsSection.tsx"
    grep -q "rounded-\\[8px\\] border border-border-secondary bg-background-primary/70" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/modal/HeadersSection.tsx"
    grep -q "epistemos-acp-stdio-extension-secret-env-values" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/utils.ts"
    grep -q "epistemos-acp-stdio-extension-secret-envs" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/utils.ts"
    grep -q "epistemos-acp-stdio-extension-server-env" "$WORK_ROOT/ui/desktop/src/acp/extensions.ts"
    grep -q "epistemos-acp-stdio-extension-secret-store-via-config" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/modal/ExtensionModal.tsx"
    grep -q "epistemos-acp-block-http-extension-secret-env" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/modal/ExtensionModal.tsx"
    grep -q "epistemos-acp-block-http-extension-secret-submit" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/modal/ExtensionModal.tsx"
    grep -q "focus:border-transparent" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/modal/ExtensionConfigFields.tsx"
    grep -q "border-border-danger" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/modal/ExtensionTimeoutField.tsx"
    grep -q "flex w-full gap-3 pt-4" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/ExtensionsSection.tsx"
    grep -q "bg-\\[var(--epistemos-accent)\\]" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/subcomponents/ExtensionList.tsx"
    grep -q "grid grid-cols-1 gap-3 sm:grid-cols-2" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/subcomponents/ExtensionList.tsx"
    grep -q "min-h-\\[128px\\] overflow-hidden border-border-secondary bg-background-primary/68" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/subcomponents/ExtensionItem.tsx"
    grep -q "hover:text-\\[var(--epistemos-accent)\\]" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/subcomponents/ExtensionItem.tsx"
    grep -q "ep-native-badge mt-1 inline-flex max-w-full truncate" "$WORK_ROOT/ui/desktop/src/components/settings/extensions/subcomponents/ExtensionItem.tsx"
    grep -q "border-border-secondary bg-background-primary/68 pb-2" "$WORK_ROOT/ui/desktop/src/components/settings/chat/ChatSettingsSection.tsx"
    grep -q "rounded-\\[9px\\] border px-3 py-2.5 text-text-primary" "$WORK_ROOT/ui/desktop/src/components/settings/mode/ModeSelectionItem.tsx"
    grep -q "peer-checked:border-\\[var(--epistemos-accent)\\]" "$WORK_ROOT/ui/desktop/src/components/settings/mode/ModeSelectionItem.tsx"
    grep -q "rounded-\\[9px\\] border border-border-secondary bg-background-secondary/60" "$WORK_ROOT/ui/desktop/src/components/settings/mode/ConversationLimitsDropdown.tsx"
    grep -q "bg-background-primary/88 p-\\[16px\\]" "$WORK_ROOT/ui/desktop/src/components/settings/mode/ConfigureApproveMode.tsx"
    grep -q "rounded-\\[9px\\] border px-3 py-2.5 text-text-primary" "$WORK_ROOT/ui/desktop/src/components/settings/response_styles/ResponseStyleSelectionItem.tsx"
    grep -q "epistemos-acp-permission-tools-list" "$WORK_ROOT/ui/desktop/src/components/settings/permission/PermissionModal.tsx"
    grep -q "listAcpSessionTools(sessionId, extensionName)" "$WORK_ROOT/ui/desktop/src/components/settings/permission/PermissionModal.tsx"
    grep -q "epistemos-acp-permission-save-unavailable" "$WORK_ROOT/ui/desktop/src/components/settings/permission/PermissionModal.tsx"
    grep -q "permissionEditingUnavailable" "$WORK_ROOT/ui/desktop/src/components/settings/permission/PermissionModal.tsx"
    grep -q "epistemos-acp-mcp-resource-read" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "epistemos-acp-mcp-tool-call" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "resourcesRead_unstable" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "toolsCall_unstable" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "epistemos-acp-mcp-resource-read-ui" "$WORK_ROOT/ui/desktop/src/components/McpApps/McpAppRenderer.tsx"
    grep -q "epistemos-acp-mcp-tool-call-ui" "$WORK_ROOT/ui/desktop/src/components/McpApps/McpAppRenderer.tsx"
    grep -q "epistemos-acp-mcp-resource-read-handler" "$WORK_ROOT/ui/desktop/src/components/McpApps/McpAppRenderer.tsx"
    grep -q "sm:max-w-\\[560px\\]" "$WORK_ROOT/ui/desktop/src/components/settings/permission/PermissionModal.tsx"
    grep -q "grid grid-cols-12 items-center gap-3 rounded-\\[10px\\]" "$WORK_ROOT/ui/desktop/src/components/settings/permission/PermissionModal.tsx"
    grep -q "rounded-\\[11px\\] border border-border-secondary bg-background-primary/65" "$WORK_ROOT/ui/desktop/src/components/settings/permission/PermissionRulesModal.tsx"
    grep -q "rounded-\\[14px\\] border border-border-secondary bg-background-secondary/72" "$WORK_ROOT/ui/desktop/src/components/settings/permission/PermissionRulesModal.tsx"
    grep -q "bg-transparent" "$WORK_ROOT/ui/desktop/src/components/settings/permission/PermissionSetting.tsx"
    grep -q "stroke-\\[var(--epistemos-accent)\\]" "$WORK_ROOT/ui/desktop/src/components/settings/permission/PermissionSetting.tsx"
    grep -q "bg-background-primary/58 px-6" "$WORK_ROOT/ui/desktop/src/components/settings/SettingsView.tsx"
    grep -q "rounded-\\[10px\\] bg-background-secondary/70" "$WORK_ROOT/ui/desktop/src/components/settings/SettingsView.tsx"
    grep -q "bg-background-primary/68 shadow-sm backdrop-blur-xl" "$WORK_ROOT/ui/desktop/src/components/settings/app/AppSettingsSection.tsx"
    grep -q "text-\\[var(--epistemos-accent)\\] hover:underline" "$WORK_ROOT/ui/desktop/src/components/settings/app/TelemetrySettings.tsx"
    grep -q "grid grid-cols-\\[200px_1fr_auto\\] items-center gap-3 rounded-\\[10px\\]" "$WORK_ROOT/ui/desktop/src/components/settings/config/ConfigSettings.tsx"
    grep -q "focus:border-transparent" "$WORK_ROOT/ui/desktop/src/components/settings/config/ConfigSettings.tsx"
    grep -q "min-h-\\[500px\\] w-full flex-1 resize-y rounded-\\[10px\\]" "$WORK_ROOT/ui/desktop/src/components/settings/PromptsSettingsSection.tsx"
    grep -q "border-border-warning bg-background-warning/55" "$WORK_ROOT/ui/desktop/src/components/settings/PromptsSettingsSection.tsx"
    grep -q "bg-background-primary/68 p-3 pb-4" "$WORK_ROOT/ui/desktop/src/components/settings/models/ModelsSection.tsx"
    grep -q "rounded-\\[10px\\] border border-border-danger bg-background-danger/35" "$WORK_ROOT/ui/desktop/src/components/settings/reset_provider/ResetProviderSection.tsx"
    grep -q "bg-background-primary/45 px-2" "$WORK_ROOT/ui/desktop/src/components/settings/models/bottom_bar/ModelsBottomBar.tsx"
    grep -q "rounded-\\[14px\\] border border-border-primary bg-background-primary/88" "$WORK_ROOT/ui/desktop/src/components/settings/models/bottom_bar/ModelsBottomBar.tsx"
    grep -q "border-b border-border-secondary bg-background-primary/45 px-4 py-3" "$WORK_ROOT/ui/desktop/src/components/settings/models/bottom_bar/ModelsBottomBar.tsx"
    grep -q "sm:max-w-\\[560px\\]" "$WORK_ROOT/ui/desktop/src/components/settings/models/subcomponents/SwitchModelModal.tsx"
    grep -q "rounded-\\[10px\\] border px-3 py-2.5 text-text-primary" "$WORK_ROOT/ui/desktop/src/components/settings/models/subcomponents/SwitchModelModal.tsx"
    grep -q "peer-checked:border-\\[var(--epistemos-accent)\\]" "$WORK_ROOT/ui/desktop/src/components/settings/models/subcomponents/SwitchModelModal.tsx"
    grep -q "border-border-warning bg-background-warning/55" "$WORK_ROOT/ui/desktop/src/components/settings/models/subcomponents/SwitchModelModal.tsx"
    grep -q "mt-1 text-sm text-text-warning" "$WORK_ROOT/ui/desktop/src/components/settings/models/subcomponents/SwitchModelModal.tsx"
    grep -q "className=\"text-sm text-text-warning\"" "$WORK_ROOT/ui/desktop/src/components/settings/models/subcomponents/SwitchModelModal.tsx"
    grep -q "min-h-9 rounded-\\[8px\\] border px-3 py-2" "$WORK_ROOT/ui/desktop/src/components/settings/keyboard/ShortcutRecorder.tsx"
    grep -q "min-h-9 rounded-\\[8px\\] border px-3 py-2" "$WORK_ROOT/ui/desktop/src/components/settings/keyboard/ShortcutRecorder.tsx"
    grep -q "border-border-warning bg-background-warning/55" "$WORK_ROOT/ui/desktop/src/components/settings/keyboard/KeyboardShortcutsSection.tsx"
    grep -q "ep-native-badge min-w-\\[120px\\] px-2 py-1" "$WORK_ROOT/ui/desktop/src/components/settings/keyboard/KeyboardShortcutsSection.tsx"
    grep -q "rounded-\\[9px\\] border border-transparent px-3 py-2.5" "$WORK_ROOT/ui/desktop/src/components/settings/keyboard/KeyboardShortcutsSection.tsx"
    grep -q "h-\\[22px\\] w-\\[38px\\]" "$WORK_ROOT/ui/desktop/src/components/ui/switch.tsx"
    grep -q "rounded-\\[10px\\] bg-background-secondary/70" "$WORK_ROOT/ui/desktop/src/components/ui/tabs.tsx"
    grep -q "select__menu z-\\[9999\\] absolute backdrop-blur-xl" "$WORK_ROOT/ui/desktop/src/components/ui/Select.tsx"
    grep -q "base: './'" "$RENDERER_CONFIG"
    if [ "${EPISTEMOS_GOOSE_UI_VALIDATE_TYPECHECK:-0}" = "1" ]; then
        (
            cd "$WORK_ROOT/ui/desktop"
            ../node_modules/.bin/tsc --noEmit
        )
    fi
    echo "Validated ACP Goose Web UI staging overlay without building."
    exit 0
fi

OUTPUT_PARENT="$(dirname "$OUTPUT_DIR")"
mkdir -p "$OUTPUT_PARENT"
STAGED_OUTPUT="$(mktemp -d "$OUTPUT_PARENT/.GooseWebUI.XXXXXX")"

(
    cd "$WORK_ROOT/ui/desktop"
    "$VITE_BIN" build --config vite.renderer.config.mts --outDir "$STAGED_OUTPUT" --emptyOutDir
)

if grep -qE '(src|href)="/assets/' "$STAGED_OUTPUT/index.html"; then
    echo "Goose Web UI artifact is not file-loadable: absolute /assets paths found." >&2
    exit 1
fi

node - "$STAGED_OUTPUT/index.html" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
const marker = 'local-acp-config-GOOSE_TELEMETRY_ENABLED';
const source = fs.readFileSync(path, 'utf8');
if (!source.includes(marker)) {
  fs.writeFileSync(path, source.replace('</head>', `<!-- ${marker} --></head>`));
}
NODE

node - "$STAGED_OUTPUT" <<'NODE'
const fs = require('fs');
const path = require('path');

const root = process.argv[2];
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const references = Array.from(html.matchAll(/(?:src|href)\s*=\s*["']([^"']+)["']/gi), match => match[1]);
for (const rawReference of references) {
  const reference = String(rawReference || '').trim();
  if (
    !reference ||
    reference.startsWith('#') ||
    reference.startsWith('data:') ||
    reference.startsWith('blob:') ||
    reference.startsWith('http://') ||
    reference.startsWith('https://') ||
    reference.startsWith('ws://') ||
    reference.startsWith('wss://') ||
    reference.startsWith('//')
  ) {
    continue;
  }
  if (reference.startsWith('/')) {
    console.error(`Goose Web UI artifact references an absolute local asset: ${reference}`);
    process.exit(1);
  }
  const withoutFragment = reference.split('#', 1)[0];
  const withoutQuery = withoutFragment.split('?', 1)[0];
  const normalized = withoutQuery.startsWith('./') ? withoutQuery.slice(2) : withoutQuery;
  const resolved = path.resolve(root, normalized);
  if (!normalized || normalized.includes('../') || !resolved.startsWith(path.resolve(root) + path.sep) || !fs.existsSync(resolved)) {
    console.error(`Goose Web UI artifact references a missing local asset: ${reference}`);
    process.exit(1);
  }
}
NODE

for required_marker in \
    "providersList_unstable" \
    "providersCatalogList_unstable" \
    "providersSetupCatalogList_unstable" \
    "providersCatalogTemplate_unstable" \
    "shared-getAcpClient-provider-inventory" \
    "local-acp-config-GOOSE_TELEMETRY_ENABLED" \
    "__epistemosGooseACPRequestSerialization" \
    "__epistemosGooseProviderInventoryEvents" \
    "__epistemosGooseProviderCatalogEvents" \
    "Epistemos Apps bridge unavailable" \
    "LM Studio is not reachable at http://localhost:1234" \
    "epistemos-native-reskin-overlay" \
    "epistemos-native-scrollbar-focus-polish" \
    "epistemos-native-primitive-polish" \
    "epistemos-native-surface-polish" \
    "epistemos-native-catalog-screen-polish" \
    "epistemos-native-loading-error-polish" \
    "provider-catalog-template-choice"; do
    if ! grep -R -q -- "$required_marker" "$STAGED_OUTPUT/index.html" "$STAGED_OUTPUT/assets" 2>/dev/null; then
        echo "Goose Web UI artifact is missing required ACP provider catalog marker: $required_marker" >&2
        exit 1
    fi
done

cat > "$STAGED_OUTPUT/$MANIFEST_FILE" <<'JSON'
{"schemaVersion":1,"source":"epistemos-stage-goose-web-ui","acpMode":true}
JSON

rm -rf "$OUTPUT_DIR"
mv "$STAGED_OUTPUT" "$OUTPUT_DIR"
echo "Staged ACP Goose Web UI: $OUTPUT_DIR"
