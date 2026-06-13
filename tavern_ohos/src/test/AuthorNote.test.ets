import { describe, it, expect } from '@ohos/hypium';
import {
  AuthorNoteRuntime,
  EventBus,
  type AuthorNoteBuildInput,
  type AuthorNoteBuiltPayload,
  type AuthorNoteCharacterNote,
  type AuthorNoteDefaults,
  type AuthorNoteMetadata,
  type RuntimeEvent,
} from '../../Index';

export default function authorNoteUnitTest() {
  describe('author note runtime', () => {
    it('builds default author note injection when interval is one', 0, () => {
      const bus = new EventBus();
      const runtime = new AuthorNoteRuntime(bus);
      const prompts = new Array<string>();
      bus.subscribe<AuthorNoteBuiltPayload>('authorNote.built', (event: RuntimeEvent<AuthorNoteBuiltPayload>) => {
        prompts.push(event.payload.injection.prompt);
      });

      const injection = runtime.buildInjection(makeInput(0, undefined));

      expect(injection.moduleName).assertEqual('2_floating_prompt');
      expect(injection.prompt).assertEqual('Default note');
      expect(injection.enabled).assertTrue();
      expect(injection.messagesTillInsertion).assertEqual(0);
      expect(injection.position).assertEqual(1);
      expect(injection.depth).assertEqual(4);
      expect(injection.role).assertEqual(0);
      expect(prompts.length).assertEqual(1);
      expect(prompts[0]).assertEqual('Default note');
    });

    it('disables injection when frequency does not match user message count', 0, () => {
      const bus = new EventBus();
      const runtime = new AuthorNoteRuntime(bus);
      const input = makeInput(3, undefined);
      input.metadata.interval = 4;

      const injection = runtime.buildInjection(input);

      expect(injection.enabled).assertFalse();
      expect(injection.prompt).assertEqual('');
      expect(injection.messagesTillInsertion).assertEqual(1);
    });

    it('combines enabled character notes before and after the chat note', 0, () => {
      const bus = new EventBus();
      const runtime = new AuthorNoteRuntime(bus);
      const before = makeCharacterNote('Before note', true, 1);
      const after = makeCharacterNote('After note', true, 2);

      const prepended = runtime.buildInjection(makeInput(2, before));
      const appended = runtime.buildInjection(makeInput(2, after));

      expect(prepended.prompt).assertEqual('Before note\nChat note');
      expect(appended.prompt).assertEqual('Chat note\nAfter note');
    });

    it('does not let event subscribers mutate returned injections', 0, () => {
      const bus = new EventBus();
      const runtime = new AuthorNoteRuntime(bus);
      bus.subscribe<AuthorNoteBuiltPayload>('authorNote.built', (event: RuntimeEvent<AuthorNoteBuiltPayload>) => {
        event.payload.injection.prompt = 'mutated';
      });

      const injection = runtime.buildInjection(makeInput(1, undefined));

      expect(injection.prompt).assertEqual('Chat note');
    });
  });
}

function makeInput(userMessageCount: number, characterNote: AuthorNoteCharacterNote | undefined): AuthorNoteBuildInput {
  const metadata: AuthorNoteMetadata = {
    prompt: 'Chat note',
    interval: 1,
    depth: 4,
    position: 1,
    role: 0,
  };
  const defaults: AuthorNoteDefaults = {
    prompt: 'Default note',
    interval: 1,
    depth: 4,
    position: 1,
    role: 0,
    allowWorldInfoScan: false,
  };
  return {
    chatId: 'chat-1',
    inChat: true,
    userMessageCount: userMessageCount,
    metadata: metadata,
    defaults: defaults,
    characterNote: characterNote,
  };
}

function makeCharacterNote(prompt: string, enabled: boolean, position: number): AuthorNoteCharacterNote {
  return {
    prompt: prompt,
    enabled: enabled,
    position: position,
  };
}
