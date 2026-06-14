import { EventBus } from '../runtime/EventBus';
import type {
  SystemPromptPayload,
  SystemPromptRecord,
  SystemPromptState,
} from './SystemPromptModels';

/**
 * 提供系统 Prompt 相关的无 UI 运行时能力，负责提示词记录的加载、查询、选择和状态管理，并通过事件总线发布对应的状态变更事件。
 */
export class SystemPromptRuntime {
  /**
   * 事件总线实例，用于发布系统提示词状态变更事件。
   */
  private events: EventBus;
  /**
   * 按名称索引的系统提示词记录 Map，由当前运行时内部维护。
   */
  private prompts: Map<string, SystemPromptRecord> = new Map<string, SystemPromptRecord>();
  private state: SystemPromptState = {
    enabled: false,
    name: '',
    content: '',
    postHistory: '',
  };

  /**
   * 构建系统提示词运行时实例。
   * @param events 注入的事件总线实例。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 加载系统提示词列表，替换当前内存中的所有记录。
   * @param prompts 要加载的系统提示词记录列表。
   */
  loadSystemPrompts(prompts: Array<SystemPromptRecord>): void {
    this.prompts.clear();
    for (let index = 0; index < prompts.length; index += 1) {
      const prompt = this.copyPrompt(prompts[index]);
      this.prompts.set(prompt.name, prompt);
    }
  }

  /**
   * 获取所有系统提示词记录的排序列表副本。
   * @returns 按名称字母序排列的系统提示词记录副本列表。
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
   * 保存（创建或覆盖）一条系统提示词记录并返回副本。
   * @param prompt 要保存的系统提示词记录。
   * @returns 保存后的记录副本。
   */
  saveSystemPrompt(prompt: SystemPromptRecord): SystemPromptRecord {
    const copy = this.copyPrompt(prompt);
    this.prompts.set(copy.name, copy);
    return this.copyPrompt(copy);
  }

  /**
   * 设置系统提示词启用状态，发布 systemprompt.state.changed 事件。
   * @param enabled 是否启用。
   * @returns 启用状态的字符串表示（"true" / "false"）。
   */
  setEnabled(enabled: boolean): string {
    this.state.enabled = enabled;
    this.publishState('systemprompt.state.changed');
    return String(this.state.enabled);
  }

  /**
   * 切换系统提示词启用状态。如果传入有效字符串值（"true"/"1"/"yes"/"on"）则启用，否则返回当前状态不变。
   * @param value 布尔值的字符串表示。
   * @returns 切换后的启用状态字符串（"true" / "false"）。
   */
  toggleSystemPrompt(value: string): string {
    if (value.length === 0) {
      return String(this.state.enabled);
    }
    return this.setEnabled(this.isTrueBoolean(value));
  }

  /**
   * 选择并激活指定名称的系统提示词。如果 forceGet 为 false 且系统提示词未启用，则返回空记录。
   * @param name 要选择的提示词名称。传入空字符串时返回当前已选中的提示词。
   * @param forceGet 是否强制获取，忽略 enabled 状态。
   * @returns 选中的提示词记录副本。
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
   * 从旧的 instruct 配置迁移到系统提示词机制，创建或查找匹配的提示词记录并设为当前选中。
   * @param presetName 预设名称，用于生成迁移后的提示词名称。
   * @param instructEnabled 旧配置中 instruct 是否启用。
   * @param systemPrompt 旧配置中的系统提示词内容。
   * @returns 迁移后选中的提示词记录副本。
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
   * 获取当前运行时状态快照副本。
   * @returns 系统提示词运行时状态副本。
   */
  getState(): SystemPromptState {
    return this.copyState(this.state);
  }

  /**
   * 通过精确匹配或模糊搜索查找指定名称的提示词记录。
   * @param name 提示词名称。
   * @returns 找到的记录，未找到时返回 undefined。
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
   * 通过正文内容精确查找提示词记录。
   * @param content 提示词正文。
   * @returns 找到的记录，未找到时返回 undefined。
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
   * 判断字符串是否为真值：true / 1 / yes / on。
   * @param value 待判断的字符串。
   * @returns 是当真值时返回 true，否则 false。
   */
  private isTrueBoolean(value: string): boolean {
    const normalized = value.toLowerCase();
    return normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'on';
  }

  /**
   * 深度复制 SystemPromptRecord，防止外部修改内部状态。
   */
  private copyPrompt(prompt: SystemPromptRecord): SystemPromptRecord {
    return {
      name: prompt.name,
      content: prompt.content,
      postHistory: prompt.postHistory,
    };
  }

  /**
   * 深度复制 SystemPromptState，防止外部修改内部状态。
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
   * 发布系统提示词事件，通知监听者状态已变更。
   * @param eventName 要发布的事件名称。
   */
  private publishState(eventName: string): void {
    const payload: SystemPromptPayload = {
      state: this.copyState(this.state),
    };
    this.events.publish<SystemPromptPayload>(eventName, payload);
  }
}
