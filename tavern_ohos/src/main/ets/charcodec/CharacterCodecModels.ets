/**
 * 限定角色卡编解码模块可接受的字符串取值范围。
 */
export type CharacterCardFormat = 'v1' | 'v2' | 'charx' | 'png_metadata' | 'webp_metadata' | 'unknown';
/**
 * 描述角色卡编解码操作完成后返回给调用方的结果。
 */
export interface CharacterCodecResult {
  /**
   * format 值，由当前实例内部维护。
   */
  format: CharacterCardFormat; raw: string; name: string; description: string;
  /**
   * personality 值，由当前实例内部维护。
   */
  personality: string; scenario: string; firstMessage: string; exampleDialogue: string;
  /**
   * creator Notes 列表，由当前实例内部维护。
   */
  creatorNotes: string; systemPrompt: string; postHistoryInstructions: string;
  /**
   * creator 值，由当前实例内部维护。
   */
  creator: string; characterVersion: string; tags: Array<string>;
  /**
   * alternate Greetings 列表，由当前实例内部维护。
   */
  alternateGreetings: Array<string>; extensions: Record<string, string>;
}
/**
 * 描述角色卡编解码模块在运行时交换的数据结构。
 */
export interface CharacterCardV1 {
  /**
   * 名称。
   */
  name?: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description?: string;
  /**
   * personality 值，由当前实例内部维护。
   */
  personality?: string;
  /**
   * scenario 值，由当前实例内部维护。
   */
  scenario?: string;
  /**
   * first mes 列表。
   */
  first_mes?: string;
  /**
   * mes example 值，由当前实例内部维护。
   */
  mes_example?: string;
}
/**
 * 描述调用角色卡编解码能力时需要传入的参数。
 */
export interface CharacterCardV2Input {
  /**
   * spec 值，由当前实例内部维护。
   */
  spec?: string; spec_version?: string; data?: CharacterCardV2InputData;
}
/**
 * 描述角色卡编解码模块在运行时交换的数据结构。
 */
export interface CharacterCardV2InputData {
  /**
   * 名称。
   */
  name?: string; description?: string; personality?: string; scenario?: string;
  /**
   * first mes 列表，由当前实例内部维护。
   */
  first_mes?: string; mes_example?: string; creator_notes?: string; system_prompt?: string;
  /**
   * post history instructions 列表，由当前实例内部维护。
   */
  post_history_instructions?: string; creator?: string; character_version?: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags?: Array<string>; alternate_greetings?: Array<string>; extensions?: CharacterCardV2InputExtensions;
}
/**
 * 限定角色卡编解码模块可接受的字符串取值范围。
 */
export type CharacterCardV2InputExtensionValue = string | number | boolean;
/**
 * 限定角色卡编解码模块可接受的字符串取值范围。
 */
export type CharacterCardV2InputExtensions = Record<string, CharacterCardV2InputExtensionValue>;
/**
 * 描述角色卡编解码模块在运行时交换的数据结构。
 */
export interface CharacterCardV2Export {
  /**
   * spec 值，由当前实例内部维护。
   */
  spec: string; spec_version: string; data: CharacterCardV2ExportData;
}
/**
 * 描述角色卡编解码模块在运行时交换的数据结构。
 */
export interface CharacterCardV2ExportData {
  /**
   * 名称。
   */
  name: string; description: string; personality: string; scenario: string;
  /**
   * first mes 列表，由当前实例内部维护。
   */
  first_mes: string; mes_example: string; creator_notes: string; system_prompt: string;
  /**
   * post history instructions 列表，由当前实例内部维护。
   */
  post_history_instructions: string; creator: string; character_version: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>; alternate_greetings: Array<string>; extensions: Record<string, string>;
}
/**
 * 描述角色卡编解码模块在运行时交换的数据结构。
 */
export interface CharxArchive {
  /**
   * spec 值，由当前实例内部维护。
   */
  spec: string;
  /**
   * spec version 值，由当前实例内部维护。
   */
  spec_version: string;
  /**
   * characters 列表。
   */
  characters: Array<CharacterCardV1>;
}
/**
 * 描述调用角色卡编解码能力时需要传入的参数。
 */
export interface CharacterBookInput {
  /**
   * 名称。
   */
  name?: string;
  /**
   * 条目列表。
   */
  entries?: Array<CharacterBookEntryInput>;
}
/**
 * 描述调用角色卡编解码能力时需要传入的参数。
 */
export interface CharacterBookEntryInput {
  /**
   * 标识。
   */
  id?: string;
  /**
   * keys 列表。
   */
  keys?: Array<string>;
  /**
   * 内容。
   */
  content?: string;
}
/**
 * 描述角色卡编解码持久化或内存索引中的一条记录。
 */
export interface CharacterBookEntry {
  /**
   * 标识。
   */
  id: string;
  /**
   * keys 列表。
   */
  keys: Array<string>;
  /**
   * 内容。
   */
  content: string;
}
/**
 * 描述角色卡编解码模块在运行时交换的数据结构。
 */
export interface CharacterBook {
  /**
   * 名称。
   */
  name: string;
  /**
   * 条目列表。
   */
  entries: Array<CharacterBookEntry>;
}
/**
 * 描述角色卡编解码模块在运行时交换的数据结构。
 */
export interface CodecExportData {
  /**
   * format Versions 列表。
   */
  formatVersions: Array<string>;
}
