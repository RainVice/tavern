// 全局常量（对齐 SillyTavern constants.js）
export interface SharedConstants {
  /**
   * APP NAME 值，由当前实例内部维护。
   */
  APP_NAME: string;
  /**
   * VERSION 值，由当前实例内部维护。
   */
  VERSION: string;
  /**
   * MAX CONTEXT TOKENS 值，由当前实例内部维护。
   */
  MAX_CONTEXT_TOKENS: number;
  /**
   * DEFAULT USER ID 值，由当前实例内部维护。
   */
  DEFAULT_USER_ID: string;
  /**
   * DATA ROOT 值，由当前实例内部维护。
   */
  DATA_ROOT: string;
  /**
   * CHARACTERS DIR 值，由当前实例内部维护。
   */
  CHARACTERS_DIR: string;
  /**
   * CHATS DIR 值，由当前实例内部维护。
   */
  CHATS_DIR: string;
  /**
   * GROUPS DIR 值，由当前实例内部维护。
   */
  GROUPS_DIR: string;
  /**
   * WORLD BOOKS DIR 值，由当前实例内部维护。
   */
  WORLD_BOOKS_DIR: string;
  /**
   * PRESETS DIR 值，由当前实例内部维护。
   */
  PRESETS_DIR: string;
  /**
   * PLUGINS DIR 值，由当前实例内部维护。
   */
  PLUGINS_DIR: string;
}

/**
 * 定义共享工具模块使用的固定配置值。
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
 * 定义共享工具模块使用的固定配置值。
 */
export const PROMPT_SECTION_ORDER: Array<string> = [
  'system', 'character_description', 'personality', 'scenario',
  'example_dialogue', 'persona', 'world_info', 'rag_context',
  'memory_summary', 'chat_history', 'user_message', 'assistant_prefill',
];

/**
 * 定义共享工具模块使用的固定配置值。
 */
export const DEFAULT_STOP_STRINGS: Array<string> = [
  '</s>', '<|eot_id|>', '<|end|>', '<|endoftext|>',
];

/**
 * 读取指定Version，不存在时抛出错误。
 * @returns 更新或读取后的记录副本。
 */
export function getVersion(): string { return SHARED_CONSTANTS.VERSION; }

/**
 * 判断Valid Stop String 值是否满足条件。
 * @param token 待处理的 token。
 * @returns 条件命中时返回 true，否则返回 false。
 */
export function isValidStopString(token: string): boolean {
  return token.length > 0 && DEFAULT_STOP_STRINGS.indexOf(token) < 0;
}
