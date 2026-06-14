import { EventBus } from '../runtime/EventBus';
import {
  AUTHOR_NOTE_MODULE_NAME,
  type AuthorNoteBuildInput,
  type AuthorNoteBuiltPayload,
  type AuthorNoteCharacterNote,
  type AuthorNoteInjection,
} from './AuthorNoteModels';

/**
 * 提供作者注释相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在每次聊天消息处理流程中，由 Prompt 构建器调用 buildInjection 来决定是否注入作者注释。
 */
export class AuthorNoteRuntime {
  /**
   * 事件总线，用于在注入完成后发布 authorNote.built 事件通知其他模块。
   */
  private events: EventBus;

  /**
   * 初始化当前运行时实例，由宿主在应用启动时通过依赖注入创建。
   * @param events 事件总线，用于发布作者注释注入完成事件。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 根据输入参数构建作者注释注入，判断是否到达注入时机、应用角色注释并发布构建事件。
   * 在 Prompt 构建阶段被调用，用于决定是否向上下文插入作者注释。
   * @param input 构建输入，包含聊天状态、元数据、默认值和角色注释配置，用于计算注入时机和内容。
   * @returns 构建完成的 AuthorNoteInjection 对象副本，供 Prompt 构建器使用。
   */
  buildInjection(input: AuthorNoteBuildInput): AuthorNoteInjection {
    const interval = this.valueOrDefault(input.metadata.interval, input.defaults.interval, 1);
    const depth = this.valueOrDefault(input.metadata.depth, input.defaults.depth, 4);
    const position = this.valueOrDefault(input.metadata.position, input.defaults.position, 1);
    const role = this.valueOrDefault(input.metadata.role, input.defaults.role, 0);
    const basePrompt = input.userMessageCount <= 0
      ? input.defaults.prompt
      : this.resolvePrompt(input.metadata.prompt, input.defaults.prompt);

    if (!input.inChat) {
      return this.publish(this.makeInjection(input.chatId, '', false, false, 0, position, depth, role));
    }
    let userMessageCount = input.userMessageCount;
    if (interval === 1) {
      userMessageCount = 1;
    }

    if (userMessageCount <= 0 || interval <= 0) {
      return this.publish(this.makeInjection(input.chatId, '', false, false, 0, position, depth, role));
    }
    const messagesTillInsertion = userMessageCount >= interval ? userMessageCount % interval : interval - userMessageCount;
    if (messagesTillInsertion !== 0) {
      return this.publish(this.makeInjection(input.chatId, '', false, input.defaults.allowWorldInfoScan, messagesTillInsertion, position, depth, role));
    }
    const prompt = this.applyCharacterNote(basePrompt, input.characterNote);
    return this.publish(this.makeInjection(input.chatId, prompt, true, input.defaults.allowWorldInfoScan, 0, position, depth, role));
  }
  /**
   * 从元数据、默认值和硬编码默认值中逐级回退，返回最终有效的数值。
   */
  private valueOrDefault(value: number, fallback: number, hardDefault: number): number {
    if (Number.isNaN(value)) {
      if (Number.isNaN(fallback)) {
        return hardDefault;
      }
      return fallback;
    }
    return value;
  }

  /**
   * 解析最终的提示词：优先使用元数据中的 prompt，回退到默认值。
   */
  private resolvePrompt(prompt: string, fallback: string): string {
    if (prompt.length > 0) {
      return prompt;
    }
    return fallback;
  }
  private applyCharacterNote(prompt: string, characterNote: AuthorNoteCharacterNote | undefined): string {
    if (characterNote === undefined || !characterNote.enabled) {
      return prompt;
    }
    if (characterNote.position === 1) {
      return this.joinNotes(characterNote.prompt, prompt);
    }
    if (characterNote.position === 2) {
      return this.joinNotes(prompt, characterNote.prompt);
    }
    return characterNote.prompt;
  }
  private joinNotes(first: string, second: string): string {
    if (first.length === 0) {
      return second;
    }
    if (second.length === 0) {
      return first;
    }
    return `${first}\n${second}`;
  }
  private makeInjection(
    chatId: string,
    prompt: string,
    enabled: boolean,
    shouldScanWorldInfo: boolean,
    messagesTillInsertion: number,
    position: number,
    depth: number,
    role: number,
  ): AuthorNoteInjection {
    return {
      moduleName: AUTHOR_NOTE_MODULE_NAME,
      chatId: chatId,
      prompt: prompt,
      enabled: enabled,
      shouldScanWorldInfo: shouldScanWorldInfo,
      messagesTillInsertion: messagesTillInsertion,
      position: position,
      depth: depth,
      role: role,
    };
  }

  /**
   * 发布作者注释事件，把状态变化通知给宿主或其他 Runtime。
   */
  private publish(injection: AuthorNoteInjection): AuthorNoteInjection {
    const payload: AuthorNoteBuiltPayload = {
      injection: this.copyInjection(injection),
    };
    this.events.publish<AuthorNoteBuiltPayload>('authorNote.built', payload);
    return this.copyInjection(injection);
  }

  /**
   * 深拷贝 AuthorNoteInjection，防止外部修改内部状态。
   */
  private copyInjection(injection: AuthorNoteInjection): AuthorNoteInjection {
    return {
      moduleName: injection.moduleName,
      chatId: injection.chatId,
      prompt: injection.prompt,
      enabled: injection.enabled,
      shouldScanWorldInfo: injection.shouldScanWorldInfo,
      messagesTillInsertion: injection.messagesTillInsertion,
      position: injection.position,
      depth: injection.depth,
      role: injection.role,
    };
  }
}
