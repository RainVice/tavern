import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  PromptRuntime,
  type ChatMessage,
  type CharacterRecord,
  type PromptBuildInput,
  type PromptBuiltPayload,
  type RuntimeEvent,
  type WorldInfoActivation,
  type WorldInfoEntry,
} from '../../Index';

export default function promptUnitTest() {
  describe('prompt runtime', () => {
    it('builds ordered prompt sections from character, world info, persona, and chat history', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new PromptRuntime(bus);
      const promptIds = new Array<string>();
      bus.subscribe<PromptBuiltPayload>('prompt.built', (event: RuntimeEvent<PromptBuiltPayload>) => {
        promptIds.push(event.payload.prompt.id);
      });
      const input: PromptBuildInput = {
        id: 'prompt-1',
        systemPrompt: 'Follow instructions.',
        personaName: 'Tester',
        personaDescription: 'A careful user.',
        authorNote: 'Keep answers concise.',
        character: makeCharacter(),
        messages: [
          makeMessage('msg-1', 0, 'Tester', 'user', 'Hello'),
          makeMessage('msg-2', 1, 'Alice', 'assistant', 'Hi.'),
        ],
        worldInfo: makeWorldInfoActivation(),
        maxEstimatedTokens: 500,
      };
      const prompt = runtime.buildPrompt(input);

      expect(prompt.sections.length).assertEqual(10);
      expect(prompt.sections[0].type).assertEqual('system');
      expect(prompt.sections[1].type).assertEqual('character_description');
      expect(prompt.sections[4].type).assertEqual('example_dialogue');
      expect(prompt.sections[5].type).assertEqual('persona');
      expect(prompt.sections[6].type).assertEqual('world_info');
      expect(prompt.sections[8].role).assertEqual('user');
      expect(prompt.sections[9].role).assertEqual('assistant');
      expect(prompt.finalText).assertContain('Dragon lore.');
      expect(prompt.debug.trimmedSections.length).assertEqual(0);
      expect(promptIds.length).assertEqual(1);
      expect(promptIds[0]).assertEqual('prompt-1');
    });

    it('includes character system and post history instructions', 0, () => {
      // 运行时实例。
      const runtime = new PromptRuntime(new EventBus());
      const character = makeCharacter();
      character.systemPrompt = 'Character system.';
      character.postHistoryInstructions = 'After history.';
      const input: PromptBuildInput = {
        id: 'prompt-character-fields',
        systemPrompt: 'Global system.',
        personaName: '',
        personaDescription: '',
        authorNote: '',
        character: character,
        messages: [makeMessage('msg-1', 0, 'Tester', 'user', 'Hello')],
        worldInfo: emptyWorldInfoActivation(),
        maxEstimatedTokens: 500,
      };
      const prompt = runtime.buildPrompt(input);

      expect(prompt.sections[1].type).assertEqual('character_system_prompt');
      expect(prompt.finalText).assertContain('Character system.');
      expect(prompt.finalText).assertContain('After history.');
      expect(prompt.sections[prompt.sections.length - 2].type).assertEqual('post_history_instruction');
      expect(prompt.sections[prompt.sections.length - 1].type).assertEqual('chat_history');
    });

    it('trims oldest chat sections when token budget is exceeded', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new PromptRuntime(bus);
      const input: PromptBuildInput = {
        id: 'prompt-budget',
        systemPrompt: 'System.',
        personaName: '',
        personaDescription: '',
        authorNote: '',
        character: makeCharacter(),
        messages: [
          makeMessage('msg-1', 0, 'Tester', 'user', 'old message that should trim'),
          makeMessage('msg-2', 1, 'Alice', 'assistant', 'new answer stays'),
        ],
        worldInfo: emptyWorldInfoActivation(),
        maxEstimatedTokens: 16,
      };
      const prompt = runtime.buildPrompt(input);

      expect(prompt.finalText).assertContain('new answer stays');
      expect(prompt.finalText.includes('old message that should trim')).assertFalse();
      expect(prompt.debug.trimmedSections.length).assertEqual(1);
      expect(prompt.debug.trimmedSections[0]).assertEqual('chat_history:msg-1');
    });

    it('does not expose built prompt through events or returned sections', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new PromptRuntime(bus);
      bus.subscribe<PromptBuiltPayload>('prompt.built', (event: RuntimeEvent<PromptBuiltPayload>) => {
        event.payload.prompt.sections[0].content = 'event-mutated';
        event.payload.prompt.debug.trimmedSections.push('event-mutated');
      });
      const input: PromptBuildInput = {
        id: 'prompt-copy',
        systemPrompt: 'System.',
        personaName: '',
        personaDescription: '',
        authorNote: '',
        character: makeCharacter(),
        messages: [makeMessage('msg-1', 0, 'Tester', 'user', 'Hello')],
        worldInfo: emptyWorldInfoActivation(),
        maxEstimatedTokens: 500,
      };
      const prompt = runtime.buildPrompt(input);
      prompt.sections[0].content = 'return-mutated';
      prompt.debug.trimmedSections.push('return-mutated');
      const next = runtime.buildPrompt(input);

      expect(next.sections[0].content).assertEqual('System.');
      expect(next.debug.trimmedSections.length).assertEqual(0);
    });
  });
}

/**
 * 封装单元测试中的 makeCharacter 步骤，供公开方法复用。
 */
function makeCharacter(): CharacterRecord {
  return {
    schemaVersion: 1,
    id: 'char-1',
    name: 'Alice',
    description: 'A helpful assistant.',
    personality: 'Curious.',
    scenario: 'In a lab.',
    firstMessage: 'Hello from Alice.',
    exampleDialogue: '<START>',
    creatorNotes: '',
    systemPrompt: '',
    postHistoryInstructions: '',
    creator: '',
    characterVersion: '',
    avatarPath: '',
    tags: new Array<string>(),
    alternateGreetings: new Array<string>(),
    favorite: false,
    talkativeness: 0.5,
    world: '',
    sourceFormat: 'runtime_json',
    sourceJson: '',
    createdAt: 1,
    updatedAt: 1,
  };
}

/**
 * 封装单元测试中的 makeMessage 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param index 索引数据或循环位置。
 * @param name 显示名称或注册名称。
 * @param role 消息角色。
 * @param text 文本内容。
 */
function makeMessage(id: string, index: number, name: string, role: string, text: string): ChatMessage {
  return {
    schemaVersion: 1,
    id: id,
    index: index,
    name: name,
    role: role,
    isUser: role === 'user',
    isSystem: role === 'system',
    sendDate: '',
    text: text,
    swipes: new Array<string>(),
    activeSwipeIndex: 0,
    extraJson: '',
  };
}

/**
 * 封装单元测试中的 makeWorldInfoActivation 步骤，供公开方法复用。
 */
function makeWorldInfoActivation(): WorldInfoActivation {
  return {
    entries: [makeWorldInfoEntry()],
    matches: new Array(),
    promptText: 'Dragon lore.',
  };
}

/**
 * 封装单元测试中的 emptyWorldInfoActivation 步骤，供公开方法复用。
 */
function emptyWorldInfoActivation(): WorldInfoActivation {
  return {
    entries: new Array<WorldInfoEntry>(),
    matches: new Array(),
    promptText: '',
  };
}

/**
 * 封装单元测试中的 makeWorldInfoEntry 步骤，供公开方法复用。
 */
function makeWorldInfoEntry(): WorldInfoEntry {
  return {
    id: 'entry-1',
    uid: 1,
    comment: 'Dragon',
    keys: ['dragon'],
    secondaryKeys: new Array<string>(),
    content: 'Dragon lore.',
    constant: false,
    selective: false,
    enabled: true,
    insertionOrder: 1,
    position: 'before',
    caseSensitive: false,
    createdAt: 1,
    updatedAt: 1,
  };
}
