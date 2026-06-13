import { EventBus } from '../runtime/EventBus';
import type {
  RegexAppliedPayload,
  RegexApplyInput,
  RegexApplyResult,
  RegexApplyTrace,
  RegexScriptRecord,
} from './RegexModels';

export class RegexRuntime {
  private events: EventBus;
  private scripts: Array<RegexScriptRecord> = new Array<RegexScriptRecord>();

  constructor(events: EventBus) {
    this.events = events;
  }

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

  unregisterScript(scriptId: string): void {
    const index = this.findScriptIndex(scriptId);
    if (index >= 0) {
      this.scripts.splice(index, 1);
    }
  }

  listScripts(): Array<RegexScriptRecord> {
    const result = new Array<RegexScriptRecord>();
    for (let index = 0; index < this.scripts.length; index += 1) {
      result.push(this.copyScript(this.scripts[index]));
    }
    return result;
  }

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
