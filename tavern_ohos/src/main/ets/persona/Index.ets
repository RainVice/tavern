/**
 * 用户人格模块导出。
 * PersonaRuntime：提供用户人格的 CRUD、选中切换、作用域绑定、Prompt 数据构建及导出/导入运行时能力。
 * 调用方（如聊天系统、Prompt 组装器）通过此模块管理用户身份的选择和 Prompt 注入数据提取。
 * PersonaModels：定义人格创建参数、记录、绑定关系、Prompt 数据及事件载荷的类型。
 * 类型用于描述用户人格在整个应用中的数据结构和事件通知格式。
 */
export { PersonaRuntime } from './PersonaRuntime';
export type {
  PersonaBindingRecord,
  PersonaChangedPayload,
  PersonaCreateParams,
  PersonaDeletedPayload,
  PersonaExportData,
  PersonaPromptData,
  PersonaRecord,
  PersonaUpdatedPayload,
} from './PersonaModels';
