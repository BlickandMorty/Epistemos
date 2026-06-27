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
    name: model.name || model.id,
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
  const response = await client.goose.providersList_unstable({});
  return ((response.entries ?? []) as ProviderInventoryEntry[]).map(providerDetails);
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

export async function validateAcpProviderModels(providerId: string): Promise<void> {
  const client = await getAcpClient();
  await client.goose.providersSupportedModelsList_unstable({ providerId });
}
TS

CONFIG_CONTEXT="$WORK_ROOT/ui/desktop/src/components/ConfigContext.tsx"
node - "$CONFIG_CONTEXT" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

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

const getProvidersAnchor = `        const response = await providers();
        const providersData = response.data || [];`;
const getProvidersReplacement = `        const providersData = USE_ACP_CHAT
          ? await getAcpProviders()
          : (await providers()).data || [];`;
if (source.includes(getProvidersAnchor)) {
  source = source.replace(getProvidersAnchor, getProvidersReplacement);
}

const initialLoadAnchor = `        const providersResponse = await providers();
        const providersData = providersResponse.data || [];`;
const initialLoadReplacement = `        const providersData = USE_ACP_CHAT
          ? await getAcpProviders()
          : (await providers()).data || [];`;
if (source.includes(initialLoadAnchor)) {
  source = source.replace(initialLoadAnchor, initialLoadReplacement);
}

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
if (source.includes(upsertAnchor)) {
  source = source.replace(upsertAnchor, upsertReplacement);
}

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
if (source.includes(readAnchor)) {
  source = source.replace(readAnchor, readReplacement);
}

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
if (source.includes(removeAnchor)) {
  source = source.replace(removeAnchor, removeReplacement);
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

ONBOARDING_GUARD="$WORK_ROOT/ui/desktop/src/components/onboarding/OnboardingGuard.tsx"
node - "$ONBOARDING_GUARD" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');

const importLine = "import { USE_ACP_CHAT } from '../../acpChatFeatureFlag';";
if (!source.includes(importLine)) {
  const anchor = "import { defineMessages, useIntl } from '../../i18n';";
  if (!source.includes(anchor)) {
    throw new Error('OnboardingGuard import anchor not found');
  }
  source = source.replace(anchor, `${anchor}\n${importLine}`);
}

const functionAnchor = "export default function OnboardingGuard({ children }: OnboardingGuardProps) {\n";
const acpBypass = `${functionAnchor}  if (USE_ACP_CHAT) {\n    return <>{children}</>;\n  }\n\n`;
if (!source.includes('if (USE_ACP_CHAT)')) {
  if (!source.includes(functionAnchor)) {
    throw new Error('OnboardingGuard function anchor not found');
  }
  source = source.replace(functionAnchor, acpBypass);
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

RENDERER_CONFIG="$WORK_ROOT/ui/desktop/vite.renderer.config.mts"
if ! grep -q "base: './'" "$RENDERER_CONFIG"; then
    node -e "const fs = require('fs'); const p = process.argv[1]; const source = fs.readFileSync(p, 'utf8'); fs.writeFileSync(p, source.replace('export default defineConfig({\n', \"export default defineConfig({\n  base: './',\n\"));" "$RENDERER_CONFIG"
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
