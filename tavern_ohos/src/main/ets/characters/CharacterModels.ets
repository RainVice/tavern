/**
 * 描述调用角色卡能力时需要传入的参数。
 */
export interface CharacterCreateParams {
  /**
   * 名称。
   */
  name: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * personality 值，由当前实例内部维护。
   */
  personality: string;
  /**
   * scenario 值，由当前实例内部维护。
   */
  scenario: string;
  /**
   * first Message 值，由当前实例内部维护。
   */
  firstMessage: string;
  /**
   * example Dialogue 值，由当前实例内部维护。
   */
  exampleDialogue: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
  /**
   * favorite 值，由当前实例内部维护。
   */
  favorite?: boolean;
  /**
   * talkativeness 列表，由当前实例内部维护。
   */
  talkativeness?: number;
  /**
   * world 值，由当前实例内部维护。
   */
  world?: string;
}

/**
 * 描述调用角色卡能力时需要传入的参数。
 */
export interface CharacterUpdateParams {
  /**
   * 名称。
   */
  name: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * personality 值，由当前实例内部维护。
   */
  personality: string;
  /**
   * scenario 值，由当前实例内部维护。
   */
  scenario: string;
  /**
   * first Message 值，由当前实例内部维护。
   */
  firstMessage: string;
  /**
   * example Dialogue 值，由当前实例内部维护。
   */
  exampleDialogue: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
  /**
   * favorite 值，由当前实例内部维护。
   */
  favorite: boolean;
}

/**
 * 描述角色卡持久化或内存索引中的一条记录。
 */
export interface CharacterRecord {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * personality 值，由当前实例内部维护。
   */
  personality: string;
  /**
   * scenario 值，由当前实例内部维护。
   */
  scenario: string;
  /**
   * first Message 值，由当前实例内部维护。
   */
  firstMessage: string;
  /**
   * example Dialogue 值，由当前实例内部维护。
   */
  exampleDialogue: string;
  /**
   * creator Notes 列表，由当前实例内部维护。
   */
  creatorNotes: string;
  /**
   * system Prompt 值，由当前实例内部维护。
   */
  systemPrompt: string;
  /**
   * post History Instructions 列表，由当前实例内部维护。
   */
  postHistoryInstructions: string;
  /**
   * creator 值，由当前实例内部维护。
   */
  creator: string;
  /**
   * character Version 值，由当前实例内部维护。
   */
  characterVersion: string;
  /**
   * avatar 路径。
   */
  avatarPath: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
  /**
   * alternate Greetings 列表，由当前实例内部维护。
   */
  alternateGreetings: Array<string>;
  /**
   * favorite 值，由当前实例内部维护。
   */
  favorite: boolean;
  /**
   * talkativeness 列表，由当前实例内部维护。
   */
  talkativeness: number;
  /**
   * world 值，由当前实例内部维护。
   */
  world: string;
  /**
   * source Format 值，由当前实例内部维护。
   */
  sourceFormat: string;
  /**
   * source JSON 字符串。
   */
  sourceJson: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述角色卡持久化或内存索引中的一条记录。
 */
export interface CharacterIndexEntry {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * avatar 路径。
   */
  avatarPath: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
  /**
   * favorite 值，由当前实例内部维护。
   */
  favorite: boolean;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述角色卡模块在运行时交换的数据结构。
 */
export interface CharacterIndex {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * next 标识。
   */
  nextId: number;
  /**
   * 项目列表，由当前实例内部维护。
   */
  items: Array<CharacterIndexEntry>;
}

/**
 * 描述角色卡事件发布时携带的数据结构。
 */
export interface CharacterEventPayload {
  /**
   * 角色记录，由当前实例内部维护。
   */
  character: CharacterRecord;
}

/**
 * 描述角色卡事件发布时携带的数据结构。
 */
export interface CharacterDeletedPayload {
  /**
   * 角色标识。
   */
  characterId: string;
}

/**
 * 描述角色卡模块在运行时交换的数据结构。
 */
export interface CharacterCardV2 {
  /**
   * spec 值，由当前实例内部维护。
   */
  spec: string;
  /**
   * spec version 值，由当前实例内部维护。
   */
  spec_version: string;
  /**
   * 数据内容。
   */
  data: CharacterCardV2Data;
}

/**
 * 描述角色卡模块在运行时交换的数据结构。
 */
export interface CharacterCardV2Data {
  /**
   * 名称。
   */
  name: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * personality 值，由当前实例内部维护。
   */
  personality: string;
  /**
   * scenario 值，由当前实例内部维护。
   */
  scenario: string;
  /**
   * first mes 列表，由当前实例内部维护。
   */
  first_mes: string;
  /**
   * mes example 值，由当前实例内部维护。
   */
  mes_example: string;
  /**
   * creator notes 列表，由当前实例内部维护。
   */
  creator_notes?: string;
  /**
   * system prompt 值，由当前实例内部维护。
   */
  system_prompt?: string;
  /**
   * post history instructions 列表，由当前实例内部维护。
   */
  post_history_instructions?: string;
  /**
   * creator 值，由当前实例内部维护。
   */
  creator?: string;
  /**
   * character version 值，由当前实例内部维护。
   */
  character_version?: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags?: Array<string>;
  /**
   * alternate greetings 列表，由当前实例内部维护。
   */
  alternate_greetings?: Array<string>;
  /**
   * extensions 列表，由当前实例内部维护。
   */
  extensions?: CharacterCardV2Extensions;
}

/**
 * 描述角色卡模块在运行时交换的数据结构。
 */
export interface CharacterCardV2Extensions {
  /**
   * fav 值，由当前实例内部维护。
   */
  fav?: boolean;
  /**
   * talkativeness 列表，由当前实例内部维护。
   */
  talkativeness?: number;
  /**
   * world 值，由当前实例内部维护。
   */
  world?: string;
}
