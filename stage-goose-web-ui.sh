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

cat > "$WORK_ROOT/ui/desktop/src/acp/providers.ts" <<'TS'
import type { ConfigKey, ModelInfo, ProviderDetails, ProviderType } from '../api';
import { getAcpClient } from './acpConnection';

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

type ProviderConfigFieldUpdate = {
  key: string;
  value: unknown;
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

function modelInfo(model: ProviderInventoryModel): ModelInfo {
  return {
    name: model.id || model.name,
    context_limit: model.contextLimit ?? 0,
    reasoning: model.reasoning ?? false,
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

export async function getAcpProviders(): Promise<ProviderDetails[]> {
  const client = await getAcpClient();
  const response = await client.goose.providersList_unstable({ providerIds: [] });
  const entries = (response.entries ?? []) as ProviderInventoryEntry[];
  if (entries.length === 0) {
    throw new Error('Goose ACP provider inventory returned zero providers.');
  }
  return entries.map(providerDetails);
}

export async function readAcpProviderConfigFields(
  providerId: string
): Promise<ProviderConfigFieldValue[]> {
  const client = await getAcpClient();
  const response = await client.goose.providersConfigRead_unstable({ providerId });
  return (response.fields ?? []) as ProviderConfigFieldValue[];
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

function configValue(value: unknown): string {
  return typeof value === 'string' ? value : String(value);
}

export async function readAcpProviderConfigValue(key: string): Promise<string | null> {
  const provider = await providerForConfigKey(key);
  const fields = await readAcpProviderConfigFields(provider.name);
  const field = fields.find((entry) => entry.key === key);
  return field?.isSet ? field.value ?? null : null;
}

export async function upsertAcpProviderConfig(
  key: string,
  value: unknown
): Promise<void> {
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
}

export async function removeAcpProviderConfig(key: string): Promise<void> {
  const provider = await providerForConfigKey(key);
  await deleteAcpProviderConfig(provider.name);
}

export async function deleteAcpProviderConfig(providerId: string): Promise<void> {
  const client = await getAcpClient();
  await client.goose.providersConfigDelete_unstable({ providerId });
}

export async function authenticateAcpProviderConfig(providerId: string): Promise<void> {
  const client = await getAcpClient();
  await client.goose.providersConfigAuthenticate_unstable({ providerId });
}

export async function listAcpProviderModels(providerId: string): Promise<ModelInfo[]> {
  const client = await getAcpClient();
  const response = await client.goose.providersSupportedModelsList_unstable({ providerId });
  return ((response.models ?? []) as string[]).map((model) => ({
    name: model,
    context_limit: 0,
    reasoning: false,
  }));
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
TS

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
if (source.includes(readConfigAnchor)) {
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
if (source.includes(modelValidationAnchor)) {
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
if (source.includes(oauthAnchor)) {
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
if (source.includes(cleanupAnchor)) {
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
if (source.includes(oauthAnchor)) {
  source = source.replace(oauthAnchor, oauthReplacement);
}

fs.writeFileSync(path, source);
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

replaceRequired(
  'ACP supported models branch',
  `    try {
      // For local provider, use listLocalModels and filter to only downloaded models`,
  `    try {
      if (USE_ACP_CHAT) {
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

for (const snippet of [
  'listAcpProviderModels(p.name)',
  'Goose ACP supported model inventory returned zero models',
  'const providers = await getAcpProviders()',
]) {
  if (!source.includes(snippet)) {
    throw new Error(`modelInterface staged source is missing required ACP model snippet: ${snippet}`);
  }
}

fs.writeFileSync(path, source);
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
            if (providerName && providerName !== currentProvider) {
              await saveAcpSessionProvider(sessionId, providerName);
            }
            await saveAcpSessionModel(sessionId, modelName);
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
if (fileDropSource.includes(filesAnchor)) {
  fileDropSource = fileDropSource.replace(filesAnchor, filesReplacement);
}
const pathAnchor = `          const path = window.electron.getPathForFile(file);`;
const pathReplacement = `          const path = nativePaths[i] || window.electron.getPathForFile(file);`;
if (fileDropSource.includes(pathAnchor)) {
  fileDropSource = fileDropSource.replace(pathAnchor, pathReplacement);
}
fs.writeFileSync(fileDropPath, fileDropSource);
NODE

RENDERER_CONFIG="$WORK_ROOT/ui/desktop/vite.renderer.config.mts"
if ! grep -q "base: './'" "$RENDERER_CONFIG"; then
    node -e "const fs = require('fs'); const p = process.argv[1]; const source = fs.readFileSync(p, 'utf8'); fs.writeFileSync(p, source.replace('export default defineConfig({\n', \"export default defineConfig({\n  base: './',\n\"));" "$RENDERER_CONFIG"
fi

if [ "${EPISTEMOS_GOOSE_UI_VALIDATE_ONLY:-0}" = "1" ]; then
    grep -q "providersList_unstable({ providerIds: \[\] })" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "name: model.id || model.name" "$WORK_ROOT/ui/desktop/src/acp/providers.ts"
    grep -q "listAcpProviderModels(p.name)" "$WORK_ROOT/ui/desktop/src/components/settings/models/modelInterface.ts"
    grep -q "saveAcpProviderDefaults(providerName, modelName)" "$WORK_ROOT/ui/desktop/src/components/ModelAndProviderContext.tsx"
    grep -q "saveAcpSessionModel(sessionId, modelName)" "$WORK_ROOT/ui/desktop/src/components/ModelAndProviderContext.tsx"
    grep -q "saveAcpSessionProvider(sessionId, providerName)" "$WORK_ROOT/ui/desktop/src/components/ModelAndProviderContext.tsx"
    ! grep -q "Changing provider for an active ACP session is not wired yet." "$WORK_ROOT/ui/desktop/src/components/ModelAndProviderContext.tsx"
    grep -q "Provider catalog failed:" "$WORK_ROOT/ui/desktop/src/components/settings/providers/ProviderSettingsPage.tsx"
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

cat > "$STAGED_OUTPUT/$MANIFEST_FILE" <<'JSON'
{"schemaVersion":1,"source":"epistemos-stage-goose-web-ui","acpMode":true}
JSON

rm -rf "$OUTPUT_DIR"
mv "$STAGED_OUTPUT" "$OUTPUT_DIR"
echo "Staged ACP Goose Web UI: $OUTPUT_DIR"
