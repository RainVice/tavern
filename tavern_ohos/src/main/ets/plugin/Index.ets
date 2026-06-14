/**
 * 插件模块导出。
 * PluginRuntime：提供插件的安装/卸载、启用/禁用、Hook 注册与分发、Prompt 注入管理、设置管理及导出/导入运行时能力。
 * 调用方（插件管理器、Hook 分发器、Prompt 合成器）通过此模块管理插件全生命周期和运行时扩展点。
 * PluginModels：定义插件清单、记录、Hook/命令/工具/宏注册、Prompt 注入、设置项及事件载荷的类型。
 * 类型用于描述插件的元数据、运行时注册信息和事件通知格式。
 */
export { PluginRuntime } from './PluginRuntime';
export type {
  HookResult,
  PluginCommandRegistration,
  PluginContext,
  PluginDisabledPayload,
  PluginEnabledPayload,
  PluginErrorPayload,
  PluginExportData,
  PluginHookAppliedPayload,
  PluginHookRegistration,
  PluginMacroRegistration,
  PluginManifest,
  PluginPromptInjectedPayload,
  PluginPromptInjection,
  PluginRecord,
  PluginRegisteredPayload,
  PluginSettingEntry,
  PluginToolRegistration,
  PluginUninstalledPayload,
} from './PluginModels';
