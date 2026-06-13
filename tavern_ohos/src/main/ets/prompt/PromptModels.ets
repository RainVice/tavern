import type { CharacterRecord } from '../characters/CharacterModels';
import type { ChatMessage } from '../chats/ChatModels';
import type { WorldInfoActivation } from '../worldinfo/WorldInfoModels';

/**
 * 描述调用Prompt 组装能力时需要传入的参数。
 */
export interface PromptBuildInput {
  /**
   * 标识。
   */
  id: string;
  /**
   * system Prompt 值，由当前实例内部维护。
   */
  systemPrompt: string;
  /**
   * persona 名称。
   */
  personaName: string;
  /**
   * persona Description 值，由当前实例内部维护。
   */
  personaDescription: string;
  /**
   * author Note 值，由当前实例内部维护。
   */
  authorNote: string;
  /**
   * 角色记录，由当前实例内部维护。
   */
  character: CharacterRecord;
  /**
   * 消息列表。
   */
  messages: Array<ChatMessage>;
  /**
   * world Info 值，由当前实例内部维护。
   */
  worldInfo: WorldInfoActivation;
  /**
   * max Estimated Tokens 列表，由当前实例内部维护。
   */
  maxEstimatedTokens: number;
}

/**
 * 描述Prompt 组装操作完成后返回给调用方的结果。
 */
export interface PromptBuildResult {
  /**
   * 标识。
   */
  id: string;
  /**
   * sections 列表，由当前实例内部维护。
   */
  sections: Array<PromptSection>;
  /**
   * final Text 值，由当前实例内部维护。
   */
  finalText: string;
  /**
   * debug 值，由当前实例内部维护。
   */
  debug: PromptDebugSnapshot;
}

/**
 * 描述Prompt 组装模块在运行时交换的数据结构。
 */
export interface PromptSection {
  /**
   * 标识。
   */
  id: string;
  /**
   * type 值，由当前实例内部维护。
   */
  type: string;
  /**
   * role 值，由当前实例内部维护。
   */
  role: string;
  /**
   * 来源类型，由当前实例内部维护。
   */
  source: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * estimated Tokens 列表，由当前实例内部维护。
   */
  estimatedTokens: number;
}

/**
 * 描述Prompt 组装模块在运行时交换的数据结构。
 */
export interface PromptDebugSnapshot {
  /**
   * prompt 标识。
   */
  promptId: string;
  /**
   * section Count 值，由当前实例内部维护。
   */
  sectionCount: number;
  /**
   * estimated Tokens 列表，由当前实例内部维护。
   */
  estimatedTokens: number;
  /**
   * max Estimated Tokens 列表，由当前实例内部维护。
   */
  maxEstimatedTokens: number;
  /**
   * trimmed Sections 列表，由当前实例内部维护。
   */
  trimmedSections: Array<string>;
}

/**
 * 描述Prompt 组装事件发布时携带的数据结构。
 */
export interface PromptBuiltPayload {
  /**
   * prompt 值，由当前实例内部维护。
   */
  prompt: PromptBuildResult;
}
