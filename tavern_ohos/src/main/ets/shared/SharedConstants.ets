// 全局常量（对齐 SillyTavern constants.js）
export interface SharedConstants {
  /**
   * 应用名称，用于日志和用户界面显示。
   */
  APP_NAME: string;
  /**
   * 当前运行时版本号。
   */
  VERSION: string;
  /**
   * 单次请求的最大上下文 token 数限制。
   */
  MAX_CONTEXT_TOKENS: number;
  /**
   * 默认用户标识符。
   */
  DEFAULT_USER_ID: string;
  /**
   * 数据存储的根目录名称。
   */
  DATA_ROOT: string;
  /**
   * 角色数据文件存放的目录名称。
   */
  CHARACTERS_DIR: string;
  /**
   * 聊天记录文件存放的目录名称。
   */
  CHATS_DIR: string;
  /**
   * 群组数据文件存放的目录名称。
   */
  GROUPS_DIR: string;
  /**
   * 世界书数据文件存放的目录名称。
   */
  WORLD_BOOKS_DIR: string;
  /**
   * 预设配置数据文件存放的目录名称。
   */
  PRESETS_DIR: string;
  /**
   * 插件数据文件存放的目录名称。
   */
  PLUGINS_DIR: string;
}

/**
 * 应用运行时使用的固定配置值集合。
 */
export const SHARED_CONSTANTS: SharedConstants = {
  APP_NAME: 'Tavern Headless Runtime',
  VERSION: '1.0.0',
  MAX_CONTEXT_TOKENS: 128000,
  DEFAULT_USER_ID: 'default',
  DATA_ROOT: 'tavern-data',
  CHARACTERS_DIR: 'characters',
  CHATS_DIR: 'chats',
  GROUPS_DIR: 'groups',
  WORLD_BOOKS_DIR: 'worldbooks',
  PRESETS_DIR: 'presets',
  PLUGINS_DIR: 'plugins',
};

/**
 * 提示词中各节（system、character_description、personality 等）的标准排列顺序。
 */
export const PROMPT_SECTION_ORDER: Array<string> = [
  'system', 'character_description', 'personality', 'scenario',
  'example_dialogue', 'persona', 'world_info', 'rag_context',
  'memory_summary', 'chat_history', 'user_message', 'assistant_prefill',
];

/**
 * 默认的停止字符串列表，用于提前终止模型生成。
 */
export const DEFAULT_STOP_STRINGS: Array<string> = [
  '</s>', '<|eot_id|>', '<|end|>', '<|endoftext|>',
];

/**
 * 返回当前运行时的版本号。
 * @returns 版本号字符串，例如 `"1.0.0"`。
 */
export function getVersion(): string { return SHARED_CONSTANTS.VERSION; }

/**
 * 判断给定的 token 是否为合法自定义停止字符串（非空且不在默认停止字符串列表中）。
 * @param token 待检查的 token。
 * @returns 合法时返回 true，否则返回 false。
 */
export function isValidStopString(token: string): boolean {
  return token.length > 0 && DEFAULT_STOP_STRINGS.indexOf(token) < 0;
}
