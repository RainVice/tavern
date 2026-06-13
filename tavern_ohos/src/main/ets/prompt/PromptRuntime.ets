import { EventBus } from '../runtime/EventBus';
import type { ChatMessage } from '../chats/ChatModels';
import type {
  PromptBuildInput,
  PromptBuildResult,
  PromptBuiltPayload,
  PromptDebugSnapshot,
  PromptSection,
} from './PromptModels';

export class PromptRuntime {
  private events: EventBus;

  constructor(events: EventBus) {
    this.events = events;
  }

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
    while (total > maxEstimatedTokens && index < kept.length) {
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

  private totalTokens(sections: Array<PromptSection>): number {
    let total = 0;
    for (let index = 0; index < sections.length; index += 1) {
      total += sections[index].estimatedTokens;
    }
    return total;
  }

  private estimateTokens(content: string): number {
    const length = content.length;
    if (length === 0) {
      return 0;
    }
    return Math.ceil(length / 4);
  }

  private cloneResult(result: PromptBuildResult): PromptBuildResult {
    return {
      id: result.id,
      sections: this.cloneSections(result.sections),
      finalText: result.finalText,
      debug: this.cloneDebug(result.debug),
    };
  }

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

interface PromptTrimResult {
  sections: Array<PromptSection>;
  trimmedSections: Array<string>;
}
