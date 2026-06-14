/**
 * 调用 `createCharacter()` 时所需参数的完整定义。
 */
export interface CharacterCreateParams {
  /**
   * 角色名称。
   */
  name: string;
  /**
   * 角色描述。
   */
  description: string;
  /**
   * 角色性格设定。
   */
  personality: string;
  /**
   * 角色场景设定。
   */
  scenario: string;
  /**
   * 角色首发消息。
   */
  firstMessage: string;
  /**
   * 角色示例对话。
   */
  exampleDialogue: string;
  /**
   * 角色标签列表。
   */
  tags: Array<string>;
  /**
   * 是否标记为收藏。
   */
  favorite?: boolean;
  /**
   * 话痨程度 (0-1 区间)。
   */
  talkativeness?: number;
  /**
   * 关联的世界设定标识。
   */
  world?: string;
}

/**
 * 调用 `updateCharacter()` 时所需参数的完整定义。
 */
export interface CharacterUpdateParams {
  /**
   * 角色名称。
   */
  name: string;
  /**
   * 角色描述。
   */
  description: string;
  /**
   * 角色性格设定。
   */
  personality: string;
  /**
   * 角色场景设定。
   */
  scenario: string;
  /**
   * 角色首发消息。
   */
  firstMessage: string;
  /**
   * 角色示例对话。
   */
  exampleDialogue: string;
  /**
   * 角色标签列表。
   */
  tags: Array<string>;
  /**
   * 是否标记为收藏。
   */
  favorite: boolean;
}

/**
 * 一条持久化的完整角色记录，包含角色卡所有字段及元信息。
 */
export interface CharacterRecord {
  /**
   * 数据格式版本号。
   */
  schemaVersion: number;
  /**
   * 角色唯一标识。
   */
  id: string;
  /**
   * 角色名称。
   */
  name: string;
  /**
   * 角色描述。
   */
  description: string;
  /**
   * 角色性格设定。
   */
  personality: string;
  /**
   * 角色场景设定。
   */
  scenario: string;
  /**
   * 角色首发消息。
   */
  firstMessage: string;
  /**
   * 角色示例对话。
   */
  exampleDialogue: string;
  /**
   * 创作者备注。
   */
  creatorNotes: string;
  /**
   * 系统提示词。
   */
  systemPrompt: string;
  /**
   * 对话历史结束后的附加指令。
   */
  postHistoryInstructions: string;
  /**
   * 创作者名称。
   */
  creator: string;
  /**
   * 角色卡版本号。
   */
  characterVersion: string;
  /**
   * 头像文件路径。
   */
  avatarPath: string;
  /**
   * 角色标签列表。
   */
  tags: Array<string>;
  /**
   * 备选首发消息列表。
   */
  alternateGreetings: Array<string>;
  /**
   * 是否标记为收藏。
   */
  favorite: boolean;
  /**
   * 话痨程度 (0-1 区间)。
   */
  talkativeness: number;
  /**
   * 关联的世界设定标识。
   */
  world: string;
  /**
   * 数据来源格式，如 `runtime_json` 或 `character_card_v2_json`。
   */
  sourceFormat: string;
  /**
   * 原始导入的 JSON 字符串；运行时创建的角色此值为空。
   */
  sourceJson: string;
  /**
   * 创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 角色索引中用于快速列表展示的摘要条目。
 */
export interface CharacterIndexEntry {
  /**
   * 角色唯一标识。
   */
  id: string;
  /**
   * 角色名称。
   */
  name: string;
  /**
   * 头像文件路径。
   */
  avatarPath: string;
  /**
   * 角色标签列表。
   */
  tags: Array<string>;
  /**
   * 是否标记为收藏。
   */
  favorite: boolean;
  /**
   * 创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 角色索引的顶层结构，包含版本号和条目列表。
 */
export interface CharacterIndex {
  /**
   * 索引格式版本号。
   */
  schemaVersion: number;
  /**
   * 下一个可用的角色标识数字编号。
   */
  nextId: number;
  /**
   * 索引条目列表。
   */
  items: Array<CharacterIndexEntry>;
}

/**
 * 角色创建/更新/导入/删除事件发布时携带的载荷。
 */
export interface CharacterEventPayload {
  /**
   * 受影响的完整角色记录副本。
   */
  character: CharacterRecord;
}

/**
 * 角色删除事件（仅携带 ID 的轻量版本）的载荷。
 */
export interface CharacterDeletedPayload {
  /**
   * 被删除角色的唯一标识。
   */
  characterId: string;
}

/**
 * SillyTavern Character Card V2 格式的顶层结构。
 */
export interface CharacterCardV2 {
  /**
   * 规范标识，固定为 `chara_card_v2`。
   */
  spec: string;
  /**
   * 规范版本号，如 `2.0`。
   */
  spec_version: string;
  /**
   * 角色卡数据内容。
   */
  data: CharacterCardV2Data;
}

/**
 * SillyTavern Character Card V2 格式的数据部分。
 */
export interface CharacterCardV2Data {
  /**
   * 角色名称。
   */
  name: string;
  /**
   * 角色描述。
   */
  description: string;
  /**
   * 角色性格设定。
   */
  personality: string;
  /**
   * 角色场景设定。
   */
  scenario: string;
  /**
   * 角色首发消息。
   */
  first_mes: string;
  /**
   * 角色示例对话。
   */
  mes_example: string;
  /**
   * 创作者备注。
   */
  creator_notes?: string;
  /**
   * 系统提示词。
   */
  system_prompt?: string;
  /**
   * 对话历史结束后的附加指令。
   */
  post_history_instructions?: string;
  /**
   * 创作者名称。
   */
  creator?: string;
  /**
   * 角色卡版本号。
   */
  character_version?: string;
  /**
   * 角色标签列表。
   */
  tags?: Array<string>;
  /**
   * 备选首发消息列表。
   */
  alternate_greetings?: Array<string>;
  /**
   * 自定义扩展字段。
   */
  extensions?: CharacterCardV2Extensions;
}

/**
 * SillyTavern Character Card V2 自定义扩展字段。
 */
export interface CharacterCardV2Extensions {
  /**
   * 是否标记为收藏。
   */
  fav?: boolean;
  /**
   * 话痨程度 (0-1 区间)。
   */
  talkativeness?: number;
  /**
   * 关联的世界设定标识。
   */
  world?: string;
}
