/**
 * 限定角色卡编解码模块可接受的格式字符串取值，用于导入时自动选择解析策略。
 */
export type CharacterCardFormat = 'v1' | 'v2' | 'charx' | 'png_metadata' | 'webp_metadata' | 'unknown';
/**
 * 描述角色卡编解码操作完成后返回给调用方的统一结果，供导入流程的用户确认和后续存储使用。
 */
export interface CharacterCodecResult {
  /**
   * 检测到的角色卡格式，用于导入时记录数据来源和格式兼容判断。
   */
  format: CharacterCardFormat; raw: string; name: string; description: string;
  /**
   * 角色的性格描述文本，用于 AI 生成符合角色个性的对话风格。
   */
  personality: string; scenario: string; firstMessage: string; exampleDialogue: string;
  /**
   * 角色创建者的备注说明，用于记录导入来源或自定义备忘。
   */
  creatorNotes: string; systemPrompt: string; postHistoryInstructions: string;
  /**
   * 角色创建者名称，用于在角色详情中展示来源信息。
   */
  creator: string; characterVersion: string; tags: Array<string>;
  /**
   * 替代开场问候语列表，可在对话开始时让用户从多个开场白中选择。
   */
  alternateGreetings: Array<string>; extensions: Record<string, string>;
}
/**
 * 描述 SillyTavern 角色卡 V1 格式的数据结构，用于导入时解析旧版角色卡。
 */
export interface CharacterCardV1 {
  /**
   * 角色名称，用于在导入时标识该角色，可选。
   */
  name?: string;
  /**
   * 角色的文字描述，用于 AI 理解角色背景，可选。
   */
  description?: string;
  /**
   * 角色的性格描述，用于 AI 生成符合角色个性的对话风格，可选。
   */
  personality?: string;
  /**
   * 对话场景设定，用于为 AI 提供对话发生的环境上下文，可选。
   */
  scenario?: string;
  /**
   * 角色的第一条开场消息，在导入时作为开场问候使用。
   */
  first_mes?: string;
  /**
   * 角色的对话示例，用于引导 AI 模仿角色的说话方式，可选。
   */
  mes_example?: string;
}
/**
 * 描述解码时输入的 SillyTavern 角色卡 V2 JSON 结构，用于导入流程中解析 V2 格式的角色卡。
 */
export interface CharacterCardV2Input {
  /**
   * 角色卡规范标识，如 'chara_card_v2'，用于格式识别。
   */
  spec?: string; spec_version?: string; data?: CharacterCardV2InputData;
}
/**
 * 描述解码时输入的 SillyTavern 角色卡 V2 数据字段，包含角色卡内的所有角色属性。
 */
export interface CharacterCardV2InputData {
  /**
   * 角色名称，用于在聊天界面和角色列表中标识该角色。
   */
  name?: string; description?: string; personality?: string; scenario?: string;
  /**
   * 角色的第一条开场消息，在开始新对话时自动发送。
   */
  first_mes?: string; mes_example?: string; creator_notes?: string; system_prompt?: string;
  /**
   * 对话历史结束后注入的额外指令，用于在每次 AI 回复前附加约束条件。
   */
  post_history_instructions?: string; creator?: string; character_version?: string;
  /**
   * 角色标签列表，用于在角色列表中的分类筛选和搜索匹配。
   */
  tags?: Array<string>; alternate_greetings?: Array<string>; extensions?: CharacterCardV2InputExtensions;
}
/**
 * 限定角色卡 V2 扩展字段的可接受值类型。
 */
export type CharacterCardV2InputExtensionValue = string | number | boolean;
/**
 * 限定角色卡 V2 扩展字段的键值对结构。
 */
export type CharacterCardV2InputExtensions = Record<string, CharacterCardV2InputExtensionValue>;
/**
 * 描述编码导出后的 SillyTavern 角色卡 V2 数据结构，用于导出流程中生成标准 V2 格式的角色卡。
 */
export interface CharacterCardV2Export {
  /**
   * 角色卡规范标识，固定为 'chara_card_v2'，用于导出的格式可识别性。
   */
  spec: string; spec_version: string; data: CharacterCardV2ExportData;
}
/**
 * 描述编码导出后的角色卡 V2 数据字段，包含导出时所有角色属性的最终值。
 */
export interface CharacterCardV2ExportData {
  /**
   * 角色名称，用于在聊天界面和角色列表中标识该角色。
   */
  name: string; description: string; personality: string; scenario: string;
  /**
   * 角色的第一条开场消息，在开始新对话时自动发送。
   */
  first_mes: string; mes_example: string; creator_notes: string; system_prompt: string;
  /**
   * 对话历史结束后注入的额外指令，用于在每次 AI 回复前附加约束条件。
   */
  post_history_instructions: string; creator: string; character_version: string;
  /**
   * 角色标签列表，用于在角色列表中的分类筛选和搜索匹配。
   */
  tags: Array<string>; alternate_greetings: Array<string>; extensions: Record<string, string>;
}
/**
 * 描述 charx 格式的角色卡归档文件结构，用于导入时解析多角色卡归档格式。
 */
export interface CharxArchive {
  /**
   * 归档格式标识，固定为 'charx'，用于导入时自动识别格式。
   */
  spec: string;
  /**
   * 归档格式版本号，用于导入时校验版本兼容性。
   */
  spec_version: string;
  /**
   * 归档中包含的角色卡列表（V1 格式），导入时通常只提取第一个角色。
   */
  characters: Array<CharacterCardV1>;
}
/**
 * 描述角色世界书（Lorebook）的 JSON 输入结构，用于导入世界书配置。
 */
export interface CharacterBookInput {
  /**
   * 世界书名称，用于在对话编辑界面中标识该世界书，可选。
   */
  name?: string;
  /**
   * 世界书条目列表，每条包含触发关键词和对应的注入内容，可选。
   */
  entries?: Array<CharacterBookEntryInput>;
}
/**
 * 描述角色世界书条目的 JSON 输入结构。
 */
export interface CharacterBookEntryInput {
  /**
   * 条目标识，用于在运行时区分不同条目，可选。
   */
  id?: string;
  /**
   * 触发关键词列表，当对话中出现这些关键词时自动注入该条目内容，可选。
   */
  keys?: Array<string>;
  /**
   * 条目内容文本，当关键词匹配时将此内容注入到 AI 上下文中，可选。
   */
  content?: string;
}
/**
 * 描述角色世界书条目在运行时中的完整结构，用于对话过程中根据关键词匹配自动注入内容。
 */
export interface CharacterBookEntry {
  /**
   * 条目的唯一标识，用于在运行时管理世界书条目的增删改。
   */
  id: string;
  /**
   * 触发关键词列表，匹配到这些词时将该条目内容注入到 AI 的上下文提示词中。
   */
  keys: Array<string>;
  /**
   * 条目内容文本，当对话中出现触发关键词时注入到 AI 上下文中的完整描述。
   */
  content: string;
}
/**
 * 描述角色世界书（Lorebook）在运行时的完整结构，用于在对话生成过程中向 AI 注入扩展的世界设定知识。
 */
export interface CharacterBook {
  /**
   * 世界书名称，用于在编辑界面中标识该世界书。
   */
  name: string;
  /**
   * 世界书条目列表，按触发关键词在对话中自动匹配注入。
   */
  entries: Array<CharacterBookEntry>;
}
/**
 * 描述编解码模块导出数据时附带的信息，用于向调用方说明支持哪些导出格式版本。
 */
export interface CodecExportData {
  /**
   * 支持的格式版本列表，用于导出选项的可用性判断和版本选择。
   */
  formatVersions: Array<string>;
}
