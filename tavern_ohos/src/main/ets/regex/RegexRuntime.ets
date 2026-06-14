import { EventBus } from '../runtime/EventBus';
import type {
  RegexAppliedPayload,
  RegexApplyInput,
  RegexApplyResult,
  RegexApplyTrace,
  RegexScriptRecord,
} from './RegexModels';

/**
 * 提供正则脚本相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class RegexRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 已注册的正则脚本列表，按注册顺序依次执行以处理消息文本。
   */
  private scripts: Array<RegexScriptRecord> = new Array<RegexScriptRecord>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 注册一条正则脚本记录到运行时，如果已存在相同 id 则覆盖。
   * @param script 待注册的脚本记录。
   * @returns 注册后的深拷贝副本，调用方修改返回值不影响内部状态。
   */
  registerScript(script: RegexScriptRecord): RegexScriptRecord {
    const existingIndex = this.findScriptIndex(script.id);
    const stored = this.copyScript(script);
    if (existingIndex >= 0) {
      this.scripts[existingIndex] = stored;
    } else {
      this.scripts.push(stored);
    }
    return this.copyScript(stored);
  }

  /**
   * 根据脚本标识从运行时移除已注册的脚本。
   * @param scriptId 要移除的目标脚本标识。
   */
  unregisterScript(scriptId: string): void {
    const index = this.findScriptIndex(scriptId);
    if (index >= 0) {
      this.scripts.splice(index, 1);
    }
  }

  /**
   * 获取当前所有已注册脚本的深拷贝列表。
   * @returns 注册脚本列表的副本，调用方修改返回值不影响内部状态。
   */
  listScripts(): Array<RegexScriptRecord> {
    const result = new Array<RegexScriptRecord>();
    for (let index = 0; index < this.scripts.length; index += 1) {
      result.push(this.copyScript(this.scripts[index]));
    }
    return result;
  }

  /**
   * 移除所有标记为临时脚本的记录，仅保留持久化脚本。
   */
  removeEphemeralScripts(): void {
    const kept = new Array<RegexScriptRecord>();
    for (let index = 0; index < this.scripts.length; index += 1) {
      const script = this.scripts[index];
      if (!script.ephemeral) {
        kept.push(script);
      }
    }
    this.scripts = kept;
  }

  /**
   * 对输入文本依次执行所有已注册且符合条件的正则脚本，并收集每次变更的跟踪信息。
   * @param input 待处理的输入参数。
   * @returns 处理后的最终文本及所有脚本的变更轨迹列表。
   */
  applyScripts(input: RegexApplyInput): RegexApplyResult {
    let current = input.text;
    const traces = new Array<RegexApplyTrace>();
    for (let index = 0; index < this.scripts.length; index += 1) {
      const script = this.scripts[index];
      if (!this.shouldRunScript(script, input)) {
        continue;
      }
      const before = current;
      const after = this.runScript(script, current);
      const changed = before !== after;
      current = after;
      if (changed) {
        const trace: RegexApplyTrace = {
          scriptId: script.id,
          scriptName: script.scriptName,
          placement: input.placement,
          before: before,
          after: after,
          changed: true,
          diff: `${before} -> ${after}`,
        };
        traces.push(trace);
        const payload: RegexAppliedPayload = {
          trace: this.copyTrace(trace),
        };
        this.events.publish<RegexAppliedPayload>('regex.applied', payload);
      }
    }
    return {
      text: current,
      traces: traces,
    };
  }
  private shouldRunScript(script: RegexScriptRecord, input: RegexApplyInput): boolean {
    if (script.disabled || script.findRegex.length === 0 || input.text.length === 0) {
      return false;
    }
    if (!script.placements.includes(input.placement)) {
      return false;
    }
    if (script.scopeId.length > 0 && script.scopeId !== input.scopeId) {
      return false;
    }
    if (input.isEdit && !script.runOnEdit) {
      return false;
    }
    if (script.minDepth >= 0 && input.depth < script.minDepth) {
      return false;
    }
    if (script.maxDepth >= 0 && input.depth > script.maxDepth) {
      return false;
    }
    if (script.markdownOnly) {
      return input.isMarkdown;
    }
    if (script.promptOnly) {
      return input.isPrompt;
    }
    return !input.isMarkdown && !input.isPrompt;
  }
  private runScript(script: RegexScriptRecord, value: string): string {
    let regex: RegExp;
    try {
      regex = new RegExp(script.findRegex, script.flags);
    } catch (error) {
      return value;
    }
    const replacement = this.replaceMatchPlaceholder(script.replaceString);
    let output = value.replace(regex, replacement);
    for (let index = 0; index < script.trimStrings.length; index += 1) {
      const trimString = script.trimStrings[index];
      if (trimString.length > 0) {
        output = output.split(trimString).join('');
      }
    }
    return output;
  }

  /**
   * 在当前集合中查找Script Index 值，未命中时返回空值或默认位置。
   * @param scriptId 目标脚本标识。
   */
  private findScriptIndex(scriptId: string): number {
    for (let index = 0; index < this.scripts.length; index += 1) {
      if (this.scripts[index].id === scriptId) {
        return index;
      }
    }
    return -1;
  }
  private replaceMatchPlaceholder(value: string): string {
    const needle = '{{match}}';
    const lower = value.toLowerCase();
    let output = '';
    let cursor = 0;
    let index = lower.indexOf(needle, cursor);
    while (index >= 0) {
      output += value.substring(cursor, index);
      output += '$&';
      cursor = index + needle.length;
      index = lower.indexOf(needle, cursor);
    }
    output += value.substring(cursor);
    return output;
  }

  /**
   * 复制Script 值，避免外部修改内部状态。
   */
  private copyScript(script: RegexScriptRecord): RegexScriptRecord {
    return {
      id: script.id,
      scriptName: script.scriptName,
      sourceType: script.sourceType,
      scopeId: script.scopeId,
      findRegex: script.findRegex,
      flags: script.flags,
      replaceString: script.replaceString,
      placements: script.placements.slice(),
      disabled: script.disabled,
      markdownOnly: script.markdownOnly,
      promptOnly: script.promptOnly,
      runOnEdit: script.runOnEdit,
      minDepth: script.minDepth,
      maxDepth: script.maxDepth,
      ephemeral: script.ephemeral,
      trimStrings: script.trimStrings.slice(),
    };
  }

  /**
   * 复制Trace 值，避免外部修改内部状态。
   */
  private copyTrace(trace: RegexApplyTrace): RegexApplyTrace {
    return {
      scriptId: trace.scriptId,
      scriptName: trace.scriptName,
      placement: trace.placement,
      before: trace.before,
      after: trace.after,
      changed: trace.changed,
      diff: trace.diff,
    };
  }
}
