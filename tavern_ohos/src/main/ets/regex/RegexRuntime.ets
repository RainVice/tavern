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
   * scripts 列表，由当前实例内部维护。
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
   * 注册Script 值，使其可被后续运行时流程使用。
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
   * 取消注册Script 值，避免后续流程继续调用。
   * @param scriptId 目标脚本标识。
   */
  unregisterScript(scriptId: string): void {
    const index = this.findScriptIndex(scriptId);
    if (index >= 0) {
      this.scripts.splice(index, 1);
    }
  }

  /**
   * 读取Scripts列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listScripts(): Array<RegexScriptRecord> {
    const result = new Array<RegexScriptRecord>();
    for (let index = 0; index < this.scripts.length; index += 1) {
      result.push(this.copyScript(this.scripts[index]));
    }
    return result;
  }

  /**
   * 移除临时脚本列表，用于解除注册、绑定或索引关系。
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
   * 执行 applyScripts 的内部处理步骤，供当前模块复用。
   * @param input 待处理的输入对象。
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
