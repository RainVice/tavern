import { EventBus } from '../runtime/EventBus';
import type {
  SystemPromptPayload,
  SystemPromptRecord,
  SystemPromptState,
} from './SystemPromptModels';

/**
 * 提供系统 Prompt相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在消息发送给 AI 模型之前，负责管理注入的 system prompt 内容，支持多个预设模板的切换和管理。
 */
export class SystemPromptRuntime {
  /**
   * 事件总线实例。
   */
  private events: EventBus;
  /**
   * 按名称保存的系统提示词记录映射表，由 loadSystemPrompts 批量填充，供 selectSystemPrompt 查询使用。
   */
  private prompts: Map<string, SystemPromptRecord> = new Map<string, SystemPromptRecord>();
  private state: SystemPromptState = {
    enabled: false,
    name: '',
    content: '',
    postHistory: '',
  };

  /**
   * 初始化 SystemPromptRuntime 实例。
   * @param events 事件总线实例。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 批量加载系统提示词记录到内存中，替换所有现有记录。
   * 在应用启动或从持久化存储恢复数据时由宿主调用。
   */
  loadSystemPrompts(prompts: Array<SystemPromptRecord>): void {
    this.prompts.clear();
    for (let index = 0; index < prompts.length; index += 1) {
      const prompt = this.copyPrompt(prompts[index]);
      this.prompts.set(prompt.name, prompt);
    }
  }

  /**
   * 返回所有已加载的系统提示词记录，按名称排序。
   * 在 UI 需要展示系统提示词选择列表时调用。
   * @returns 系统提示词记录的副本数组。
   */
  listSystemPrompts(): Array<SystemPromptRecord> {
    const values = Array.from(this.prompts.values());
    const result = new Array<SystemPromptRecord>();
    values.sort((left: SystemPromptRecord, right: SystemPromptRecord) => left.name.localeCompare(right.name));
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyPrompt(values[index]));
    }
    return result;
  }

  /**
   * 保存或更新一条系统提示词记录。
   * 在用户创建或编辑系统提示词预设时由 UI 层调用。
   * @returns 保存后的记录副本。
   */
  saveSystemPrompt(prompt: SystemPromptRecord): SystemPromptRecord {
    const copy = this.copyPrompt(prompt);
    this.prompts.set(copy.name, copy);
    return this.copyPrompt(copy);
  }

  /**
   * 设置系统提示词的启用状态。
   * 在用户切换系统提示词的开启/关闭时由 UI 层调用，影响消息组装时的 prompt 注入逻辑。
   * @param enabled 是否启用。
   * @returns 启用状态的字符串表示（"true"/"false"）。
   */
  setEnabled(enabled: boolean): string {
    this.state.enabled = enabled;
    this.publishState('systemprompt.state.changed');
    return String(this.state.enabled);
  }

  /**
   * 切换系统提示词的启用状态（通过字符串值判断）。
   * 在从持久化或外部配置恢复状态时调用，支持 "true"/"false"/"1"/"yes"/"on" 等多种格式。
   * @param value "true"/"false"/"1"/"yes"/"on" 等布尔字符串。
   */
  toggleSystemPrompt(value: string): string {
    if (value.length === 0) {
      return String(this.state.enabled);
    }
    return this.setEnabled(this.isTrueBoolean(value));
  }

  /**
   * 选中指定名称的系统提示词，更新当前状态并发布事件。
   * 在用户在 UI 上选择系统提示词模板时由 UI 层调用。
   * @param name 要选中的提示词名称；传空字符串表示保留当前名称。
   * @param forceGet 为 true 时即使未启用也加载提示词，用于预加载场景。
   * @returns 选中后的提示词记录。
   */
  selectSystemPrompt(name: string, forceGet: boolean): SystemPromptRecord {
    if (!this.state.enabled && !forceGet) {
      return {
        name: '',
        content: '',
        postHistory: '',
      };
    }
    if (name.length === 0) {
      return {
        name: this.state.name,
        content: this.state.content,
        postHistory: this.state.postHistory,
      };
    }
    const found = this.findPrompt(name);
    if (found === undefined) {
      throw new Error(`System prompt not found: ${name}`);
    }
    this.state.name = found.name;
    this.state.content = found.content;
    this.state.postHistory = found.postHistory;
    this.publishState('systemprompt.selected');
    return this.copyPrompt(found);
  }

  /**
   * 从旧的 instruct 模块导入系统提示词：按内容查找或创建新记录，并设置状态。
   * 在数据迁移流程中由宿主调用，用于将旧版本的系统提示词配置转换为新格式。
   * @param presetName 预设名称，用于创建迁移后的提示词名称。
   * @param instructEnabled 旧模块的启用状态。
   * @param systemPrompt 旧的系统提示词文本内容。
   * @returns 迁移后的系统提示词记录。
   */
  migrateFromInstruct(presetName: string, instructEnabled: boolean, systemPrompt: string): SystemPromptRecord {
    const existing = this.findPromptByContent(systemPrompt);
    const prompt = existing === undefined ? this.saveSystemPrompt({
      name: `[Migrated] ${presetName}`,
      content: systemPrompt,
      postHistory: '',
    }) : existing;
    this.state.enabled = instructEnabled;
    this.state.name = prompt.name;
    this.state.content = prompt.content;
    this.state.postHistory = prompt.postHistory;
    this.publishState('systemprompt.migrated');
    return this.copyPrompt(prompt);
  }

  /**
   * 获取当前系统提示词状态的副本。
   * 在消息组装流程中调用，用于获取需要注入到 AI 请求中的系统提示词内容。
   * @returns 状态快照副本。
   */
  getState(): SystemPromptState {
    return this.copyState(this.state);
  }

  /**
   * 按名称查找系统提示词记录，支持精确匹配和模糊匹配。
   * @param name 提示词名称（精确值或部分匹配字符串）。
   */
  private findPrompt(name: string): SystemPromptRecord | undefined {
    const exact = this.prompts.get(name);
    if (exact !== undefined) {
      return exact;
    }
    const normalized = name.toLowerCase();
    const values = Array.from(this.prompts.values());
    let best: SystemPromptRecord | undefined = undefined;
    let bestScore = 0;
    for (let index = 0; index < values.length; index += 1) {
      const candidate = values[index].name.toLowerCase();
      let score = 0;
      if (candidate === normalized) {
        score = 100;
      } else if (candidate.indexOf(normalized) >= 0) {
        score = normalized.length;
      } else {
        score = this.sharedPrefixLength(candidate, normalized);
      }
      if (score > bestScore) {
        best = values[index];
        bestScore = score;
      }
    }
    return bestScore > 0 ? best : undefined;
  }

  /**
   * 按文本内容精确查找系统提示词记录。
   * @param content 要匹配的提示词内容。
   */
  private findPromptByContent(content: string): SystemPromptRecord | undefined {
    const values = Array.from(this.prompts.values());
    for (let index = 0; index < values.length; index += 1) {
      if (values[index].content === content) {
        return values[index];
      }
    }
    return undefined;
  }
  private sharedPrefixLength(left: string, right: string): number {
    const max = Math.min(left.length, right.length);
    let count = 0;
    for (let index = 0; index < max; index += 1) {
      if (left[index] !== right[index]) {
        break;
      }
      count += 1;
    }
    return count;
  }

  /**
   * 判断字符串是否为真值（true/1/yes/on）。
   * @param value 待判断的字符串。
   * @returns 字符串表示真值时返回 true。
   */
  private isTrueBoolean(value: string): boolean {
    const normalized = value.toLowerCase();
    return normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'on';
  }

  /**
   * 深度复制 SystemPromptRecord，防止外部代码修改内部状态。
   */
  private copyPrompt(prompt: SystemPromptRecord): SystemPromptRecord {
    return {
      name: prompt.name,
      content: prompt.content,
      postHistory: prompt.postHistory,
    };
  }

  /**
   * 深度复制 SystemPromptState，防止外部代码修改内部状态。
   */
  private copyState(state: SystemPromptState): SystemPromptState {
    return {
      enabled: state.enabled,
      name: state.name,
      content: state.content,
      postHistory: state.postHistory,
    };
  }

  /**
   * 发布系统提示词状态变更事件。
   * @param eventName 要发布的事件名称。
   */
  private publishState(eventName: string): void {
    const payload: SystemPromptPayload = {
      state: this.copyState(this.state),
    };
    this.events.publish<SystemPromptPayload>(eventName, payload);
  }
}
