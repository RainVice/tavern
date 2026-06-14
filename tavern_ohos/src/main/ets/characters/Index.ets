/**
 * 角色卡模块统一导出入口。
 * 导出 CharacterRuntime（角色管理运行时）以及所有相关的数据结构和事件载荷类型，
 * 供 UI 层和外部模块通过 import { ... } from './characters' 的方式统一引用。
 */
export { CharacterRuntime } from './CharacterRuntime';
export type {
  CharacterCardV2,
  CharacterCardV2Data,
  CharacterCardV2Extensions,
  CharacterCreateParams,
  CharacterDeletedPayload,
  CharacterEventPayload,
  CharacterIndex,
  CharacterIndexEntry,
  CharacterRecord,
  CharacterUpdateParams,
} from './CharacterModels';
