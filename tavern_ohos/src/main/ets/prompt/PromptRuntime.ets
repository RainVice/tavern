import { EventBus } from '../runtime/EventBus';
import type { ChatMessage } from '../chats/ChatModels';
import type {
  ChatMessageRole,
  PromptSectionType,
  RuntimeSource,
} from '../contracts/PublicContracts';
import type {
  PromptBuildInput,
  PromptBuildResult,
  PromptBuiltPayload,
  PromptDebugSnapshot,
  PromptSection,
} from './PromptModels';

/**
 * Prompt 组装运行时，提供无 UI 依赖的 prompt 拼装能力。
 * 负责将角色数据、聊天历史、World Info 等各来源内容组装成最终 prompt，
 * 并按 Token 预算裁剪过程，在组装完成后通过事件总线广播结果。
 */
export class PromptRuntime {
  /**
   * 事件总线实例，用于广播 prompt 组装完成等运行时事件。
   */
  private events: EventBus;

  /**
   * 创建 PromptRuntime 实例。
   * @param events 事件总线实例，用于后续广播 prompt 事件。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 根据输入参数构建完整 prompt。
   * 按固定顺序将系统提示、角色定义、persona、World Info、Author's Note、
   * 历史指令以及聊天消息组装为 section 列表，根据 Token 预算裁剪历史消息，
   * 并将最终结果通过事件总线广播。
   *
   * @param input 组装所需的全部数据，包括角色信息、消息列表和预算上限。
   * @returns 构建完成的 prompt 结果，包含 section 列表、拼接文本和调试快照。
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
  /**
   * 将单个内容块加入 section 列表。
   * 若内容为空则跳过，不为空则估算 Token 数后添加。
   *
   * @param sections 目标 section 列表。
   * @param type section 的类型标识。
   * @param role section 在 prompt 中的角色。
   * @param source section 的来源标识。
   * @param id 来源 ID，与 type 组合形成唯一标识。
   * @param content 文本内容。
   */
  private pushSection(sections: Array<PromptSection>, type: PromptSectionType, role: ChatMessageRole, source: RuntimeSource, id: string, content: string): void {
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
   * 按 Token 预算裁剪 section 列表。
   * 从最早的聊天历史 section 开始移除，直到总 Token 数不超出预算。
   *
   * @param sections 待裁剪的 section 列表。
   * @param maxEstimatedTokens Token 预算上限，超过此值时触发裁剪。
   * @returns 包含保留的 section 列表和被移除的 section 标识列表。
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
   * 构建 prompt 调试快照。
   * 记录最终保留的 section 数量、总估算 Token 数、预算上限以及被移除的 section 列表。
   *
   * @param promptId 本次 prompt 会话标识。
   * @param sections 保留的 section 列表。
   * @param maxEstimatedTokens Token 预算上限。
   * @param trimmedSections 被移除的 section 标识列表。
   * @returns 调试快照对象。
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
  /**
   * 将 section 内容按顺序以双换行符拼接为一段完整文本。
   *
   * @param sections 待拼接的 section 列表。
   * @returns 拼接后的完整 prompt 文本。
   */
  private joinSections(sections: Array<PromptSection>): string {
    const chunks = new Array<string>();
    for (let index = 0; index < sections.length; index += 1) {
      chunks.push(sections[index].content);
    }
    return chunks.join('\n\n');
  }
  /**
   * 根据消息确定其在 prompt 中应占的角色。
   * 若消息已指定 role 则直接使用，否则按 isUser 标记判断。
   *
   * @param message 聊天消息对象。
   * @returns 对应的 prompt 角色（user / assistant）。
   */
  private roleForMessage(message: ChatMessage): ChatMessageRole {
    if (message.role.length > 0) {
      return message.role;
    }
    return message.isUser ? 'user' : 'assistant';
  }

  /**
   * 汇总各 section 的估算 Token 总数。
   *
   * @param sections 待统计的 section 列表。
   * @returns 所有 section 的 estimatedTokens 之和。
   */
  private totalTokens(sections: Array<PromptSection>): number {
    let total = 0;
    for (let index = 0; index < sections.length; index += 1) {
      total += sections[index].estimatedTokens;
    }
    return total;
  }
  /**
   * 统计列表中指定类型的 section 数量。
   *
   * @param sections section 列表。
   * @param type 目标类型。
   * @returns 匹配该类型的 section 数量。
   */
  private countSectionsByType(sections: Array<PromptSection>, type: PromptSectionType): number {
    let count = 0;
    for (let index = 0; index < sections.length; index += 1) {
      if (sections[index].type === type) {
        count += 1;
      }
    }
    return count;
  }
  /**
   * 粗略估算文本内容的 Token 数。
   * 按每 4 个字符约等于 1 个 Token 计算并向上取整。
   *
   * @param content 待估算的文本。
   * @returns 估算的 Token 数。
   */
  private estimateTokens(content: string): number {
    const length = content.length;
    if (length === 0) {
      return 0;
    }
    return Math.ceil(length / 4);
  }

  /**
   * 深度复制 PromptBuildResult，避免外部修改内部状态。
   *
   * @param result 原始结果对象。
   * @returns 完全独立的结果副本。
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
   * 深度复制 PromptSection 列表，避免外部修改内部状态。
   *
   * @param sections 原始 section 列表。
   * @returns 完全独立的 section 副本列表。
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
   * 深度复制 PromptDebugSnapshot，避免外部修改内部状态。
   *
   * @param debug 原始调试快照对象。
   * @returns 完全独立的调试快照副本。
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
 * Prompt 裁剪操作的内部结果，包含保留的 section 列表和被裁剪移除的 section 标识。
 */
interface PromptTrimResult {
  /**
   * 保留下的 section 列表。
   */
  sections: Array<PromptSection>;
  /**
   * 因超出 Token 预算而被移除的 section 标识列表。
   */
  trimmedSections: Array<string>;
}
