export interface PluginManifest {
  name: string;
  version: string;
  description: string;
  author: string;
  permissions: Array<string>;
}

export interface PluginRecord {
  pluginId: string;
  manifest: PluginManifest;
  enabled: boolean;
  installedAt: number;
  updatedAt: number;
}

export interface PluginContext {
  pluginId: string;
  dataDir: string;
}

export interface PluginHookRegistration {
  hookPoint: string;
  priority: number;
}

export interface HookResult {
  allowed: boolean;
  reason: string;
}

export interface PluginCommandRegistration {
  pluginId: string;
  commandName: string;
  aliases: Array<string>;
  helpText: string;
  permission: string;
  enabled: boolean;
}

export interface PluginToolRegistration {
  pluginId: string;
  toolName: string;
  displayName: string;
  description: string;
  parametersJson: string;
  permission: string;
  stealth: boolean;
  enabled: boolean;
}

export interface PluginMacroRegistration {
  pluginId: string;
  macroName: string;
  handlerName: string;
  description: string;
}

export interface PluginPromptInjection {
  pluginId: string;
  hookPoint: string;
  content: string;
  position: string;
  priority: number;
}

export interface PluginSettingEntry {
  pluginId: string;
  key: string;
  value: string;
}

export interface PluginRegisteredPayload {
  plugin: PluginRecord;
}

export interface PluginEnabledPayload {
  plugin: PluginRecord;
}

export interface PluginDisabledPayload {
  plugin: PluginRecord;
}

export interface PluginUninstalledPayload {
  plugin: PluginRecord;
}

export interface PluginHookAppliedPayload {
  pluginId: string;
  hookPoint: string;
  result: HookResult;
}

export interface PluginErrorPayload {
  pluginId: string;
  message: string;
}

export interface PluginPromptInjectedPayload {
  pluginId: string;
  hookPoint: string;
  content: string;
  position: string;
}

export interface PluginExportData {
  manifest: PluginManifest;
  settings: Array<PluginSettingEntry>;
  promptInjections: Array<PluginPromptInjection>;
}
