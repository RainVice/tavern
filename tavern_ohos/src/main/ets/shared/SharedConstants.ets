// 全局常量（对齐 SillyTavern constants.js）
export interface SharedConstants {
  APP_NAME: string;
  VERSION: string;
  MAX_CONTEXT_TOKENS: number;
  DEFAULT_USER_ID: string;
  DATA_ROOT: string;
  CHARACTERS_DIR: string;
  CHATS_DIR: string;
  GROUPS_DIR: string;
  WORLD_BOOKS_DIR: string;
  PRESETS_DIR: string;
  PLUGINS_DIR: string;
}

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

export const PROMPT_SECTION_ORDER: Array<string> = [
  'system', 'character_description', 'personality', 'scenario',
  'example_dialogue', 'persona', 'world_info', 'rag_context',
  'memory_summary', 'chat_history', 'user_message', 'assistant_prefill',
];

export const DEFAULT_STOP_STRINGS: Array<string> = [
  '</s>', '<|eot_id|>', '<|end|>', '<|endoftext|>',
];

export function getVersion(): string { return SHARED_CONSTANTS.VERSION; }

export function isValidStopString(token: string): boolean {
  return token.length > 0 && DEFAULT_STOP_STRINGS.indexOf(token) < 0;
}
