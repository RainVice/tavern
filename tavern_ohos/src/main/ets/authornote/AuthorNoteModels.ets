/**
 * 定义作者注释模块使用的固定配置值。
 */
export const AUTHOR_NOTE_MODULE_NAME: string = '2_floating_prompt';

/**
 * 描述作者注释模块在运行时交换的数据结构。
 */
export interface AuthorNoteMetadata {
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
  /**
   * interval 值，由当前实例内部维护。
   */
  interval: number;
  /**
   * depth 值，由当前实例内部维护。
   */
  depth: number;
  /**
   * position 值，由当前实例内部维护。
   */
  position: number;
  /**
   * role 值，由当前实例内部维护。
   */
  role: number;
}

/**
 * 描述作者注释模块在运行时交换的数据结构。
 */
export interface AuthorNoteDefaults {
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
  /**
   * interval 值，由当前实例内部维护。
   */
  interval: number;
  /**
   * depth 值，由当前实例内部维护。
   */
  depth: number;
  /**
   * position 值，由当前实例内部维护。
   */
  position: number;
  /**
   * role 值，由当前实例内部维护。
   */
  role: number;
  /**
   * allow World Info Scan 值，由当前实例内部维护。
   */
  allowWorldInfoScan: boolean;
}

/**
 * 描述作者注释模块在运行时交换的数据结构。
 */
export interface AuthorNoteCharacterNote {
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * position 值，由当前实例内部维护。
   */
  position: number;
}

/**
 * 描述调用作者注释能力时需要传入的参数。
 */
export interface AuthorNoteBuildInput {
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * in Chat 值，由当前实例内部维护。
   */
  inChat: boolean;
  /**
   * user Message Count 值，由当前实例内部维护。
   */
  userMessageCount: number;
  /**
   * metadata 值，由当前实例内部维护。
   */
  metadata: AuthorNoteMetadata;
  /**
   * defaults 列表，由当前实例内部维护。
   */
  defaults: AuthorNoteDefaults;
  /**
   * character Note 值，由当前实例内部维护。
   */
  characterNote?: AuthorNoteCharacterNote;
}

/**
 * 描述作者注释模块在运行时交换的数据结构。
 */
export interface AuthorNoteInjection {
  /**
   * module 名称。
   */
  moduleName: string;
  /**
   * 聊天标识。
   */
  chatId: string;
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * should Scan World Info 值，由当前实例内部维护。
   */
  shouldScanWorldInfo: boolean;
  /**
   * messages Till Insertion 值，由当前实例内部维护。
   */
  messagesTillInsertion: number;
  /**
   * position 值，由当前实例内部维护。
   */
  position: number;
  /**
   * depth 值，由当前实例内部维护。
   */
  depth: number;
  /**
   * role 值，由当前实例内部维护。
   */
  role: number;
}

/**
 * 描述作者注释事件发布时携带的数据结构。
 */
export interface AuthorNoteBuiltPayload {
  /**
   * injection 值，由当前实例内部维护。
   */
  injection: AuthorNoteInjection;
}
