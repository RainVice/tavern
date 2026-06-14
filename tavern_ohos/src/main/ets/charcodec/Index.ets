/**
 * 角色卡编解码模块统一导出入口。
 * 导出 CharacterCodecRuntime（角色卡编解码运行时）以及所有相关的数据结构类型，
 * 供 UI 层的角色导入/导出页面和外部模块通过 import { ... } from './charcodec' 的方式统一引用。
 */
export { CharacterCodecRuntime } from './CharacterCodecRuntime';
export type { CharacterBook, CharacterBookEntry, CharacterCardFormat, CharacterCardV1, CharacterCodecResult, CharxArchive, CodecExportData } from './CharacterCodecModels';
