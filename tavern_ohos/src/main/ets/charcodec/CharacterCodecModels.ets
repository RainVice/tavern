/**
 * 限定角色卡编解码模块可接受的字符串取值范围。
 */
export type CharacterCardFormat = 'v1' | 'v2' | 'charx' | 'png_metadata' | 'webp_metadata' | 'unknown';
/**
 * 描述角色卡编解码操作完成后返回给调用方的统一结果。
 * format 区分来源格式，raw 保留原始数据，其余字段为解析后的结构化信息。
 */
export interface CharacterCodecResult {
  /** 角色卡来源格式，如 'v1'、'v2'、'charx'、'png_metadata' 等。 */
  format: CharacterCardFormat;
  /** 原始 JSON 字符串，保留解析前的完整数据。 */
  raw: string;
  /** 角色名称。 */
  name: string;
  /** 角色描述文本。 */
  description: string;
  /** 角色性格设定文本。 */
  personality: string;
  /** 角色场景设定文本。 */
  scenario: string;
  /** 角色首次发言内容。 */
  firstMessage: string;
  /** 角色对话示例文本。 */
  exampleDialogue: string;
  /** 创作者备注文本（仅 V2 格式支持）。 */
  creatorNotes: string;
  /** 系统提示词文本。 */
  systemPrompt: string;
  /** 对话后指令文本，覆盖系统提示词之后的额外指引。 */
  postHistoryInstructions: string;
  /** 角色创作者名称。 */
  creator: string;
  /** 角色版本号。 */
  characterVersion: string;
  /** 角色标签列表，用于分类和检索。 */
  tags: Array<string>;
  /** 备选打招呼语列表，供用户首次对话时选择。 */
  alternateGreetings: Array<string>;
  /** 扩展字段映射表，承载各前端特有的附加数据。 */
  extensions: Record<string, string>;
}
/**
 * V1 格式角色卡的输入数据结构（SillyTavern 早期版本）。
 */
export interface CharacterCardV1 {
  /** 角色名称。 */
  name?: string;
  /** 角色描述文本。 */
  description?: string;
  /** 角色性格设定文本。 */
  personality?: string;
  /** 角色场景设定文本。 */
  scenario?: string;
  /** 角色首次发言内容。 */
  first_mes?: string;
  /** 角色对话示例文本。 */
  mes_example?: string;
}
/**
 * V2 格式角色卡的输入数据结构（SillyTavern chara_card_v2 spec），由 JSON 反序列化得到。
 */
export interface CharacterCardV2Input {
  /** 格式标识，固定为 'chara_card_v2'。 */
  spec?: string;
  /** spec 版本号，如 '2.0'。 */
  spec_version?: string;
  /** 角色卡核心数据。 */
  data?: CharacterCardV2InputData;
}
/**
 * V2 格式角色卡的核心数据字段（输入侧），各字段与 SillyTavern 规范一一对应。
 */
export interface CharacterCardV2InputData {
  /** 角色名称。 */
  name?: string;
  /** 角色描述文本。 */
  description?: string;
  /** 角色性格设定文本。 */
  personality?: string;
  /** 角色场景设定文本。 */
  scenario?: string;
  /** 角色首次发言内容。 */
  first_mes?: string;
  /** 角色对话示例文本。 */
  mes_example?: string;
  /** 创作者备注。 */
  creator_notes?: string;
  /** 系统提示词。 */
  system_prompt?: string;
  /** 对话后指令文本。 */
  post_history_instructions?: string;
  /** 角色创作者名称。 */
  creator?: string;
  /** 角色版本号。 */
  character_version?: string;
  /** 角色标签列表。 */
  tags?: Array<string>;
  /** 备选打招呼语列表。 */
  alternate_greetings?: Array<string>;
  /** 扩展字段映射表，承载各前端特有的附加数据。 */
  extensions?: CharacterCardV2InputExtensions;
}
/**
 * V2 扩展字段允许的取值类型：字符串、数值或布尔值。
 */
export type CharacterCardV2InputExtensionValue = string | number | boolean;
/**
 * V2 扩展字段的键值映射表。
 */
export type CharacterCardV2InputExtensions = Record<string, CharacterCardV2InputExtensionValue>;
/**
 * V2 格式角色卡的输出数据结构（导出侧），用于序列化为 JSON。
 */
export interface CharacterCardV2Export {
  /** 格式标识，固定为 'chara_card_v2'。 */
  spec: string;
  /** spec 版本号，如 '2.0'。 */
  spec_version: string;
  /** 角色卡核心数据。 */
  data: CharacterCardV2ExportData;
}
/**
 * V2 格式角色卡的核心数据字段（导出侧），所有字段均为非可选、已补全的完整数据。
 */
export interface CharacterCardV2ExportData {
  /** 角色名称。 */
  name: string;
  /** 角色描述文本。 */
  description: string;
  /** 角色性格设定文本。 */
  personality: string;
  /** 角色场景设定文本。 */
  scenario: string;
  /** 角色首次发言内容。 */
  first_mes: string;
  /** 角色对话示例文本。 */
  mes_example: string;
  /** 创作者备注。 */
  creator_notes: string;
  /** 系统提示词。 */
  system_prompt: string;
  /** 对话后指令文本。 */
  post_history_instructions: string;
  /** 角色创作者名称。 */
  creator: string;
  /** 角色版本号。 */
  character_version: string;
  /** 角色标签列表。 */
  tags: Array<string>;
  /** 备选打招呼语列表。 */
  alternate_greetings: Array<string>;
  /** 扩展字段映射表，承载各前端特有的附加数据。 */
  extensions: Record<string, string>;
}
/**
 * charx 归档格式的数据结构，将多个 V1 角色卡打包为一个文件。
 */
export interface CharxArchive {
  /** 格式标识，固定为 'charx'。 */
  spec: string;
  /** spec 版本号。 */
  spec_version: string;
  /** 归档中的角色卡列表，每张为 V1 格式。 */
  characters: Array<CharacterCardV1>;
}
/**
 * 角色书输入数据结构，由 JSON 反序列化得到。
 */
export interface CharacterBookInput {
  /** 角色书名称。 */
  name?: string;
  /** 条目列表。 */
  entries?: Array<CharacterBookEntryInput>;
}
/**
 * 角色书条目输入数据结构，各字段均为可选。
 */
export interface CharacterBookEntryInput {
  /** 条目唯一标识。 */
  id?: string;
  /** 触发关键词列表。 */
  keys?: Array<string>;
  /** 触发后插入的文本内容。 */
  content?: string;
}
/**
 * 角色书持久化存储中的一条完整记录。
 */
export interface CharacterBookEntry {
  /** 条目唯一标识。 */
  id: string;
  /** 触发关键词列表。 */
  keys: Array<string>;
  /** 触发后插入的文本内容。 */
  content: string;
}
/**
 * 角色书在内存或持久化中的完整数据结构。
 */
export interface CharacterBook {
  /** 角色书名称。 */
  name: string;
  /** 条目列表。 */
  entries: Array<CharacterBookEntry>;
}
/**
 * 编解码导出操作的元数据，描述导出内容的版本信息。
 */
export interface CodecExportData {
  /** 导出内容所支持的格式版本号列表。 */
  formatVersions: Array<string>;
}
