// 全局常量（对齐 SillyTavern constants.js），用于在整个运行时中统一引用固定配置值。
export interface SharedConstants {
  /**
   * 运行时名称，固定为 "Tavern Headless Runtime"，用于日志和调试信息标识来源。
   */
  APP_NAME: string;
  /**
   * 运行时版本号，固定为 "1.0.0"，用于版本兼容性检测和更新判断。
   */
  VERSION: string;
  /**
   * 最大上下文 token 数，固定为 128000，用于限制模型输入的最大 token 长度。
   */
  MAX_CONTEXT_TOKENS: number;
  /**
   * 默认用户 ID，固定为 "default"，用于未登录或匿名场景下的用户标识。
   */
  DEFAULT_USER_ID: string;
  /**
   * 数据存储根目录名，固定为 "tavern-data"，所有用户数据和配置文件均以此为基础路径。
   */
  DATA_ROOT: string;
  /**
   * 角色数据目录名，固定为 "characters"，用于存储角色卡片 JSON 文件。
   */
  CHARACTERS_DIR: string;
  /**
   * 聊天记录目录名，固定为 "chats"，用于存储消息历史 JSON 文件。
   */
  CHATS_DIR: string;
  /**
   * 群组数据目录名，固定为 "groups"，用于存储群组配置和成员信息。
   */
  GROUPS_DIR: string;
  /**
   * 世界书数据目录名，固定为 "worldbooks"，用于存储世界书 JSON 文件。
   */
  WORLD_BOOKS_DIR: string;
  /**
   * 预设配置目录名，固定为 "presets"，用于存储模型推理参数预设文件。
   */
  PRESETS_DIR: string;
  /**
   * 插件数据目录名，固定为 "plugins"，用于存储扩展插件的数据文件。
   */
  PLUGINS_DIR: string;
}

/**
 * 定义共享工具模块使用的固定配置值，供整个运行时各个模块统一引用。
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
 * 提示词部分的预期排列顺序，用于生成模型输入时按此顺序组装各段落，确保提示词结构一致性。
 */
export const PROMPT_SECTION_ORDER: Array<string> = [
  'system', 'character_description', 'personality', 'scenario',
  'example_dialogue', 'persona', 'world_info', 'rag_context',
  'memory_summary', 'chat_history', 'user_message', 'assistant_prefill',
];

/**
 * 默认停止字符串列表，用于指示模型停止生成的 token。在构建完成请求时附加到 API 参数中。
 */
export const DEFAULT_STOP_STRINGS: Array<string> = [
  '</s>', '<|eot_id|>', '<|end|>', '<|endoftext|>',
];

/**
 * 获取当前运行时的版本号。在初始化时用于版本兼容性判断和日志记录。
 * @returns 版本号字符串，如 "1.0.0"。
 */
export function getVersion(): string { return SHARED_CONSTANTS.VERSION; }

/**
 * 判断指定 token 是否为有效的停止字符串（非空且不在默认停止列表中）。在用户自定义停止字符串时进行校验。
 * @param token 待检查的 token，将被验证是否可用作自定义停止字符串。
 * @returns 该 token 可用作停止字符串时返回 true，否则返回 false。
 */
export function isValidStopString(token: string): boolean {
  return token.length > 0 && DEFAULT_STOP_STRINGS.indexOf(token) < 0;
}
