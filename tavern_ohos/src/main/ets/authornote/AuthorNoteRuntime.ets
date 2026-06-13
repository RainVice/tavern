import { EventBus } from '../runtime/EventBus';
import {
  AUTHOR_NOTE_MODULE_NAME,
  type AuthorNoteBuildInput,
  type AuthorNoteBuiltPayload,
  type AuthorNoteCharacterNote,
  type AuthorNoteInjection,
} from './AuthorNoteModels';

export class AuthorNoteRuntime {
  private events: EventBus;

  constructor(events: EventBus) {
    this.events = events;
  }

  buildInjection(input: AuthorNoteBuildInput): AuthorNoteInjection {
    const interval = this.valueOrDefault(input.metadata.interval, input.defaults.interval, 1);
    const depth = this.valueOrDefault(input.metadata.depth, input.defaults.depth, 4);
    const position = this.valueOrDefault(input.metadata.position, input.defaults.position, 1);
    const role = this.valueOrDefault(input.metadata.role, input.defaults.role, 0);
    const basePrompt = this.resolvePrompt(input.metadata.prompt, input.defaults.prompt);

    if (!input.inChat) {
      return this.publish(this.makeInjection(input.chatId, '', false, false, 0, position, depth, role));
    }

    let userMessageCount = input.userMessageCount;
    if (interval === 1) {
      userMessageCount = 1;
    }

    if (userMessageCount <= 0 || interval <= 0) {
      return this.publish(this.makeInjection(input.chatId, '', false, false, 0, position, depth, role));
    }

    const messagesTillInsertion = userMessageCount >= interval ? userMessageCount % interval : interval - userMessageCount;
    if (messagesTillInsertion !== 0) {
      return this.publish(this.makeInjection(input.chatId, '', false, input.defaults.allowWorldInfoScan, messagesTillInsertion, position, depth, role));
    }

    const prompt = this.applyCharacterNote(basePrompt, input.characterNote);
    return this.publish(this.makeInjection(input.chatId, prompt, true, input.defaults.allowWorldInfoScan, 0, position, depth, role));
  }

  private valueOrDefault(value: number, fallback: number, hardDefault: number): number {
    if (Number.isNaN(value)) {
      if (Number.isNaN(fallback)) {
        return hardDefault;
      }
      return fallback;
    }
    return value;
  }

  private resolvePrompt(prompt: string, fallback: string): string {
    if (prompt.length > 0) {
      return prompt;
    }
    return fallback;
  }

  private applyCharacterNote(prompt: string, characterNote: AuthorNoteCharacterNote | undefined): string {
    if (characterNote === undefined || !characterNote.enabled) {
      return prompt;
    }
    if (characterNote.position === 1) {
      return this.joinNotes(characterNote.prompt, prompt);
    }
    if (characterNote.position === 2) {
      return this.joinNotes(prompt, characterNote.prompt);
    }
    return characterNote.prompt;
  }

  private joinNotes(first: string, second: string): string {
    if (first.length === 0) {
      return second;
    }
    if (second.length === 0) {
      return first;
    }
    return `${first}\n${second}`;
  }

  private makeInjection(
    chatId: string,
    prompt: string,
    enabled: boolean,
    shouldScanWorldInfo: boolean,
    messagesTillInsertion: number,
    position: number,
    depth: number,
    role: number,
  ): AuthorNoteInjection {
    return {
      moduleName: AUTHOR_NOTE_MODULE_NAME,
      chatId: chatId,
      prompt: prompt,
      enabled: enabled,
      shouldScanWorldInfo: shouldScanWorldInfo,
      messagesTillInsertion: messagesTillInsertion,
      position: position,
      depth: depth,
      role: role,
    };
  }

  private publish(injection: AuthorNoteInjection): AuthorNoteInjection {
    const payload: AuthorNoteBuiltPayload = {
      injection: this.copyInjection(injection),
    };
    this.events.publish<AuthorNoteBuiltPayload>('authorNote.built', payload);
    return this.copyInjection(injection);
  }

  private copyInjection(injection: AuthorNoteInjection): AuthorNoteInjection {
    return {
      moduleName: injection.moduleName,
      chatId: injection.chatId,
      prompt: injection.prompt,
      enabled: injection.enabled,
      shouldScanWorldInfo: injection.shouldScanWorldInfo,
      messagesTillInsertion: injection.messagesTillInsertion,
      position: injection.position,
      depth: injection.depth,
      role: injection.role,
    };
  }
}
