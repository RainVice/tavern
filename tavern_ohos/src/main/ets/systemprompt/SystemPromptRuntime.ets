import { EventBus } from '../runtime/EventBus';
import type {
  SystemPromptPayload,
  SystemPromptRecord,
  SystemPromptState,
} from './SystemPromptModels';

/**
 * 提供系统 Prompt相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class SystemPromptRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * prompts 列表，由当前实例内部维护。
   */
  private prompts: Map<string, SystemPromptRecord> = new Map<string, SystemPromptRecord>();
  private state: SystemPromptState = {
    enabled: false,
    name: '',
    content: '',
    postHistory: '',
  };

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 读取或解析SystemPrompts，调用方应处理不存在或不匹配的情况。

   */
  loadSystemPrompts(prompts: Array<SystemPromptRecord>): void {
    this.prompts.clear();
    for (let index = 0; index < prompts.length; index += 1) {
      const prompt = this.copyPrompt(prompts[index]);
      this.prompts.set(prompt.name, prompt);
    }
  }

  /**
   * 读取SystemPrompts列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 创建或写入提示词，完成持久化后返回可供调用方使用的结果。
   */
  saveSystemPrompt(prompt: SystemPromptRecord): SystemPromptRecord {
    const copy = this.copyPrompt(prompt);
    this.prompts.set(copy.name, copy);
    return this.copyPrompt(copy);
  }

  /**
   * 设置启用状态，用于切换运行时状态或保存配置。
   * @param enabled 是否启用该能力。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  setEnabled(enabled: boolean): string {
    this.state.enabled = enabled;
    this.publishState('systemprompt.state.changed');
    return String(this.state.enabled);
  }

  /**
   * 切换系统提示词状态并返回新的状态结构。
   * @param value 要保存或比较的字段值。
   */
  toggleSystemPrompt(value: string): string {
    if (value.length === 0) {
      return String(this.state.enabled);
    }
    return this.setEnabled(this.isTrueBoolean(value));
  }

  /**
   * 读取或解析提示词，调用方应处理不存在或不匹配的情况。
   * @param name 显示名称或注册名称。

   * @returns 条件命中时返回 true，否则返回 false。
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
   * 执行 migrateFromInstruct 的内部处理步骤，供当前模块复用。
   * @param presetName 预设名称。


   * @returns 条件命中时返回 true，否则返回 false。
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
   * 读取指定状态，不存在时抛出错误。
   * @returns 更新或读取后的记录副本。
   */
  getState(): SystemPromptState {
    return this.copyState(this.state);
  }

  /**
   * 在当前集合中查找Prompt 值，未命中时返回空值或默认位置。
   * @param name 显示名称或注册名称。
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
   * 在当前集合中查找Prompt By Content 值，未命中时返回空值或默认位置。
   * @param content 要写入或追加的文本内容。
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
    // 数量。
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
   * 判断True Boolean 值是否满足条件。
   * @param value 要保存或比较的字段值。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  private isTrueBoolean(value: string): boolean {
    const normalized = value.toLowerCase();
    return normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'on';
  }

  /**
   * 复制Prompt 值，避免外部修改内部状态。
   */
  private copyPrompt(prompt: SystemPromptRecord): SystemPromptRecord {
    return {
      name: prompt.name,
      content: prompt.content,
      postHistory: prompt.postHistory,
    };
  }

  /**
   * 复制State 值，避免外部修改内部状态。
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
   * 发布系统 Prompt事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要订阅或发布的事件名。
   */
  private publishState(eventName: string): void {
    const payload: SystemPromptPayload = {
      state: this.copyState(this.state),
    };
    this.events.publish<SystemPromptPayload>(eventName, payload);
  }
}
