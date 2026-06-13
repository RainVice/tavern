import { EventBus } from '../runtime/EventBus';
import type { ChatMessage } from '../chats/ChatModels';
import type {
  PromptBuildInput,
  PromptBuildResult,
  PromptBuiltPayload,
  PromptDebugSnapshot,
  PromptSection,
} from './PromptModels';

/**
 * 提供Prompt 组装相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class PromptRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 根据入参构建Prompt 值，仅生成数据结构，不直接执行外部请求。
   * @param input 待处理的输入对象。
   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildPrompt(input: PromptBuildInput): PromptBuildResult {
    const sections = new Array<PromptSection>();
    this.pushSection(sections, 'system', 'system', 'system', 'system', input.systemPrompt);
    this.pushSection(sections, 'character_system_prompt', 'system', 'character', input.character.id, input.character.systemPrompt);
    this.pushSection(sections, 'character_description', 'system', 'character', input.character.id, input.character.description);
    this.pushSection(sections, 'personality', 'system', 'character', input.character.id, input.character.personality);
    this.pushSection(sections, 'scenario', 'system', 'character', input.character.id, input.character.scenario);
    this.pushSection(sections, 'example_dialogue', 'system', 'character', input.character.id, input.character.exampleDialogue);
    this.pushSection(sections, 'persona', 'system', 'persona', input.personaName, input.personaDescription);
    this.pushSection(sections, 'world_info', 'system', 'worldinfo', 'activated', input.worldInfo.promptText);
    this.pushSection(sections, 'author_note', 'system', 'author_note', 'author_note', input.authorNote);
    this.pushSection(
      sections,
      'post_history_instruction',
      'system',
      'character',
      input.character.id,
      input.character.postHistoryInstructions,
    );

    for (let index = 0; index < input.messages.length; index += 1) {
      const message = input.messages[index];
      if (message.isSystem) {
        continue;
      }
      this.pushSection(sections, 'chat_history', this.roleForMessage(message), 'message', message.id, `${message.name}: ${message.text}`);
    }
    const trimmed = this.trimToBudget(sections, input.maxEstimatedTokens);
    const debug = this.buildDebug(input.id, trimmed.sections, input.maxEstimatedTokens, trimmed.trimmedSections);
    const result: PromptBuildResult = {
      id: input.id,
      sections: trimmed.sections,
      finalText: this.joinSections(trimmed.sections),
      debug: debug,
    };
    const payload: PromptBuiltPayload = {
      prompt: this.cloneResult(result),
    };
    this.events.publish<PromptBuiltPayload>('prompt.built', payload);
    return this.cloneResult(result);
  }
  private pushSection(sections: Array<PromptSection>, type: string, role: string, source: string, id: string, content: string): void {
    if (content.length === 0) {
      return;
    }
    const section: PromptSection = {
      id: `${type}:${id}`,
      type: type,
      role: role,
      source: source,
      content: content,
      estimatedTokens: this.estimateTokens(content),
    };
    sections.push(section);
  }

  /**
   * 按预算裁剪To Budget 值，避免超出上下文限制。

   * @param maxEstimatedTokens token 数量或 token 内容。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private trimToBudget(sections: Array<PromptSection>, maxEstimatedTokens: number): PromptTrimResult {
    const kept = sections.slice();
    const trimmed = new Array<string>();
    if (maxEstimatedTokens <= 0) {
      return {
        sections: kept,
        trimmedSections: trimmed,
      };
    }
    let total = this.totalTokens(kept);
    let index = 0;
    while (total > maxEstimatedTokens && index < kept.length && this.countSectionsByType(kept, 'chat_history') > 1) {
      if (kept[index].type === 'chat_history') {
        const removed = kept.splice(index, 1)[0];
        trimmed.push(removed.id);
        total = this.totalTokens(kept);
        continue;
      }
      index += 1;
    }

    return {
      sections: kept,
      trimmedSections: trimmed,
    };
  }

  /**
   * 根据入参构建Debug 值，仅生成数据结构，不直接执行外部请求。
   * @param promptId 目标提示词标识。

   * @param maxEstimatedTokens token 数量或 token 内容。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private buildDebug(promptId: string, sections: Array<PromptSection>, maxEstimatedTokens: number, trimmedSections: Array<string>): PromptDebugSnapshot {
    return {
      promptId: promptId,
      sectionCount: sections.length,
      estimatedTokens: this.totalTokens(sections),
      maxEstimatedTokens: maxEstimatedTokens,
      trimmedSections: trimmedSections.slice(),
    };
  }
  private joinSections(sections: Array<PromptSection>): string {
    const chunks = new Array<string>();
    for (let index = 0; index < sections.length; index += 1) {
      chunks.push(sections[index].content);
    }
    return chunks.join('\n\n');
  }
  private roleForMessage(message: ChatMessage): string {
    if (message.role.length > 0) {
      return message.role;
    }
    return message.isUser ? 'user' : 'assistant';
  }

  /**
   * 汇总各段提示词的 token 数量。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private totalTokens(sections: Array<PromptSection>): number {
    let total = 0;
    for (let index = 0; index < sections.length; index += 1) {
      total += sections[index].estimatedTokens;
    }
    return total;
  }
  private countSectionsByType(sections: Array<PromptSection>, type: string): number {
    let count = 0;
    for (let index = 0; index < sections.length; index += 1) {
      if (sections[index].type === type) {
        count += 1;
      }
    }
    return count;
  }
  private estimateTokens(content: string): number {
    const length = content.length;
    if (length === 0) {
      return 0;
    }
    return Math.ceil(length / 4);
  }

  /**
   * 复制Result 值，避免外部修改内部状态。
   * @param result 返回结果。
   */
  private cloneResult(result: PromptBuildResult): PromptBuildResult {
    return {
      id: result.id,
      sections: this.cloneSections(result.sections),
      finalText: result.finalText,
      debug: this.cloneDebug(result.debug),
    };
  }

  /**
   * 复制Sections 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private cloneSections(sections: Array<PromptSection>): Array<PromptSection> {
    const cloned = new Array<PromptSection>();
    for (let index = 0; index < sections.length; index += 1) {
      cloned.push({
        id: sections[index].id,
        type: sections[index].type,
        role: sections[index].role,
        source: sections[index].source,
        content: sections[index].content,
        estimatedTokens: sections[index].estimatedTokens,
      });
    }
    return cloned;
  }

  /**
   * 复制Debug 值，避免外部修改内部状态。
   */
  private cloneDebug(debug: PromptDebugSnapshot): PromptDebugSnapshot {
    return {
      promptId: debug.promptId,
      sectionCount: debug.sectionCount,
      estimatedTokens: debug.estimatedTokens,
      maxEstimatedTokens: debug.maxEstimatedTokens,
      trimmedSections: debug.trimmedSections.slice(),
    };
  }
}

/**
 * 描述Prompt 组装操作完成后返回给调用方的结果。
 */
interface PromptTrimResult {
  /**
   * sections 列表，由当前实例内部维护。
   */
  sections: Array<PromptSection>;
  /**
   * trimmed Sections 列表，由当前实例内部维护。
   */
  trimmedSections: Array<string>;
}
