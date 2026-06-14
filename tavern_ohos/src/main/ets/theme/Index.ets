/**
 * theme 模块导出核心能力和类型。
 *
 * 提供主题运行时管理（ThemeRuntime）以及相关模型类型，
 * 包括保存参数、记录结构、导出数据和事件载荷。
 */
export { ThemeRuntime } from './ThemeRuntime';
export type {
  ThemeActivatedPayload,
  ThemeBackgroundChangedPayload,
  ThemeDeletedPayload,
  ThemeExportData,
  ThemeRecord,
  ThemeSaveParams,
  ThemeSavedPayload,
  ThemeStateRecord,
} from './ThemeModels';
