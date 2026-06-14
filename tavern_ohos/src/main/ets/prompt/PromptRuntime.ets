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
 * 提供 Prompt 组装相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 调用方（如模型调用客户端）在发起模型推理前通过此运行时将角色信息、对话历史、用户人格、
 * World Info 等数据组装成完整 Prompt 文本。
 */
export class PromptRuntime {
  /**
   * 事件总线，用于在 Prompt 构建完成后发布事件，通知监听方（如 UI 调试面板）。
   */
  private events: EventBus;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线实例，用于后续 Prompt 构建事件发布。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 根据输入参数组装完整的 Prompt，包含系统提示、角色描述、对话历史、World Info 等分段，并在超预算时裁剪聊天历史。
   * 调用方（如模型调用客户端）在每次发起推理请求前调用此方法，获取可直接送入模型的 Prompt 文本。
   * @param input Prompt 组装输入参数。
   * @returns 组装完成的 Prompt 结果。
   */
  buildPrompt(input: PromptBuildInput): PromptBuildResult {
    const sections = new Array<PromptSection>();
    this.pushSection(
      sections,
      'system',
      'system',
      'system',
      'system',
      input.systemPrompt,
    );
    this.pushSection(
      sections,
      'character_system_prompt',
      'system',
      'character',
      input.character.id,
      input.character.systemPrompt,
    );
    this.pushSection(
      sections,
      'character_description',
      'system',
      'character',
      input.character.id,
      input.character.description,
    );
    this.pushSection(
      sections,
      'personality',
      'system',
      'character',
      input.character.id,
      input.character.personality,
    );
    this.pushSection(
      sections,
      'scenario',
      'system',
      'character',
      input.character.id,
      input.character.scenario,
    );
    this.pushSection(
      sections,
      'example_dialogue',
      'system',
      'character',
      input.character.id,
      input.character.exampleDialogue,
    );
    this.pushSection(
      sections,
      'persona',
      'system',
      'persona',
      input.personaName,
      input.personaDescription,
    );
    this.pushSection(
      sections,
      'world_info',
      'system',
      'worldinfo',
      'activated',
      input.worldInfo.promptText,
    );
    this.pushSection(
      sections,
      'author_note',
      'system',
      'author_note',
      'author_note',
      input.authorNote,
    );
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
      this.pushSection(
        sections,
        'chat_history',
        this.roleForMessage(message),
        'message',
        message.id,
        `${message.name}: ${message.text}`,
      );
    }
    const trimmed = this.trimToBudget(sections, input.maxEstimatedTokens);
    const debug = this.buildDebug(
      input.id,
      trimmed.sections,
      input.maxEstimatedTokens,
      trimmed.trimmedSections,
    );
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
   * 向分段列表追加一个新的 Prompt 分段（内容非空时）。
   * 在 buildPrompt 中为每个数据来源（系统提示、角色描述、聊天消息等）调用，构建完整分段列表。
   * @param sections 分段列表，buildPrompt 中逐步填充。
   * @param type 分段类型，如 system、chat_history、persona 等。
   * @param role 角色标识（system、user、assistant），用于模型区分消息来源。
   * @param source 来源类型（system、character、persona、worldinfo、message），标识分段数据来源。
   * @param id 来源标识，用于生成分段的唯一 ID。
   * @param content 分段文本内容，空内容时跳过添加。
   */
  private pushSection(
    sections: Array<PromptSection>,
    type: string,
    role: string,
    source: string,
    id: string,
    content: string,
  ): void {
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
   * 按最大 token 预算裁剪分段列表：只丢弃聊天历史分段，直到总 token 数低于预算。
   * 在 buildPrompt 中调用，确保最终生成的 Prompt 不超过模型上下文窗口限制。
   * @param sections 分段列表。
   * @param maxEstimatedTokens 允许的最大 token 数。
   * @returns 裁剪后的分段列表和被裁剪的分段 ID。
   */
  private trimToBudget(
    sections: Array<PromptSection>,
    maxEstimatedTokens: number,
  ): PromptTrimResult {
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
    while (
      total > maxEstimatedTokens &&
      index < kept.length &&
      this.countSectionsByType(kept, 'chat_history') > 1
    ) {
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
   * 构建 Prompt 调试快照，包含分段数、预估 token、预算值和被裁剪的分段。
   * 在 buildPrompt 中完成裁剪后调用。
   * @param promptId Prompt 请求标识。
   * @param sections 最终分段列表。
   * @param maxEstimatedTokens 允许的最大 token 数。
   * @param trimmedSections 裁剪掉的分段 ID 列表。
   * @returns 调试快照。
   */
  private buildDebug(
    promptId: string,
    sections: Array<PromptSection>,
    maxEstimatedTokens: number,
    trimmedSections: Array<string>,
  ): PromptDebugSnapshot {
    return {
      promptId: promptId,
      sectionCount: sections.length,
      estimatedTokens: this.totalTokens(sections),
      maxEstimatedTokens: maxEstimatedTokens,
      trimmedSections: trimmedSections.slice(),
    };
  }

  /**
   * 将所有分段的内容以双换行连接成完整文本。
   * 在 buildPrompt 中生成最终可送入模型的 Prompt 文本。
   */
  private joinSections(sections: Array<PromptSection>): string {
    const chunks = new Array<string>();
    for (let index = 0; index < sections.length; index += 1) {
      chunks.push(sections[index].content);
    }
    return chunks.join('\n\n');
  }

  /**
   * 根据消息对象推断该消息在 Prompt 中的角色（user 或 assistant）。
   * 在 buildPrompt 中为每条聊天历史消息确定其在 Prompt 中的角色标识。
   */
  private roleForMessage(message: ChatMessage): string {
    if (message.role.length > 0) {
      return message.role;
    }
    return message.isUser ? 'user' : 'assistant';
  }

  /**
   * 汇总各分段预估 token 数的总和。
   * 在 trimToBudget 和 buildDebug 中用于计算当前总 token 数。
   * @param sections 分段列表。
   * @returns token 总数。
   */
  private totalTokens(sections: Array<PromptSection>): number {
    let total = 0;
    for (let index = 0; index < sections.length; index += 1) {
      total += sections[index].estimatedTokens;
    }
    return total;
  }

  /**
   * 统计指定类型的分段数量。
   * 在 trimToBudget 中用于判断聊天历史分段数，确保至少保留一条以防止全部被删。
   */
  private countSectionsByType(
    sections: Array<PromptSection>,
    type: string,
  ): number {
    let count = 0;
    for (let index = 0; index < sections.length; index += 1) {
      if (sections[index].type === type) {
        count += 1;
      }
    }
    return count;
  }

  /**
   * 根据文本长度粗略预估 token 数（字符数 / 4 向上取整）。
   * 在 pushSection 中为每个分段计算预估 token 数，用于裁剪决策。
   */
  private estimateTokens(content: string): number {
    const length = content.length;
    if (length === 0) {
      return 0;
    }
    return Math.ceil(length / 4);
  }

  /**
   * 深拷贝 PromptBuildResult。
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
   * 深拷贝 PromptSection 列表。
   * @returns 分段副本列表。
   */
  private cloneSections(
    sections: Array<PromptSection>,
  ): Array<PromptSection> {
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
   * 深拷贝 PromptDebugSnapshot。
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
 * Prompt 裁剪操作的内部返回结果。
 * 由 trimToBudget 返回，包含裁剪后的分段列表和被移除的分段 ID。
 */
interface PromptTrimResult {
  /**
   * 裁剪后保留的分段列表。
   */
  sections: Array<PromptSection>;
  /**
   * 被裁剪掉的分段 ID 列表。
   */
  trimmedSections: Array<string>;
}
