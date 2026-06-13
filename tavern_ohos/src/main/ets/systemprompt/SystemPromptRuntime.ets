import { EventBus } from '../runtime/EventBus';
import type {
  SystemPromptPayload,
  SystemPromptRecord,
  SystemPromptState,
} from './SystemPromptModels';

export class SystemPromptRuntime {
  private events: EventBus;
  private prompts: Map<string, SystemPromptRecord> = new Map<string, SystemPromptRecord>();
  private state: SystemPromptState = {
    enabled: false,
    name: '',
    content: '',
    postHistory: '',
  };

  constructor(events: EventBus) {
    this.events = events;
  }

  loadSystemPrompts(prompts: Array<SystemPromptRecord>): void {
    this.prompts.clear();
    for (let index = 0; index < prompts.length; index += 1) {
      const prompt = this.copyPrompt(prompts[index]);
      this.prompts.set(prompt.name, prompt);
    }
  }

  listSystemPrompts(): Array<SystemPromptRecord> {
    const values = Array.from(this.prompts.values());
    const result = new Array<SystemPromptRecord>();
    values.sort((left: SystemPromptRecord, right: SystemPromptRecord) => left.name.localeCompare(right.name));
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyPrompt(values[index]));
    }
    return result;
  }

  saveSystemPrompt(prompt: SystemPromptRecord): SystemPromptRecord {
    const copy = this.copyPrompt(prompt);
    this.prompts.set(copy.name, copy);
    return this.copyPrompt(copy);
  }

  setEnabled(enabled: boolean): string {
    this.state.enabled = enabled;
    this.publishState('systemprompt.state.changed');
    return String(this.state.enabled);
  }

  toggleSystemPrompt(value: string): string {
    if (value.length === 0) {
      return String(this.state.enabled);
    }
    return this.setEnabled(this.isTrueBoolean(value));
  }

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

  getState(): SystemPromptState {
    return this.copyState(this.state);
  }

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

  private isTrueBoolean(value: string): boolean {
    const normalized = value.toLowerCase();
    return normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'on';
  }

  private copyPrompt(prompt: SystemPromptRecord): SystemPromptRecord {
    return {
      name: prompt.name,
      content: prompt.content,
      postHistory: prompt.postHistory,
    };
  }

  private copyState(state: SystemPromptState): SystemPromptState {
    return {
      enabled: state.enabled,
      name: state.name,
      content: state.content,
      postHistory: state.postHistory,
    };
  }

  private publishState(eventName: string): void {
    const payload: SystemPromptPayload = {
      state: this.copyState(this.state),
    };
    this.events.publish<SystemPromptPayload>(eventName, payload);
  }
}
