import { describe, expect, it } from '@ohos/hypium';
import {
  InMemoryFileStore,
  type CharacterRecord,
  type ChatMessage,
  type ConnectionHeaderRecord,
  type ConnectionProfileCreateParams,
  type ConnectionResolvedProfile,
} from 'tavern_ohos';
import { TavernRuntimeContainer } from '../main/ets/tavern/TavernRuntimeContainer';

export default function tavernRuntimeTest() {
  describe('tavernRuntime', () => {
    it('savesCharacterThroughTavernRuntime', 0, async () => {
      const runtime = TavernRuntimeContainer.configure('unit-test', new InMemoryFileStore());
      const saved: CharacterRecord = await runtime.characters.createCharacter({
        name: '莉莉',
        description: '旅馆里的向导',
        personality: '温和',
        scenario: '大厅',
        firstMessage: '欢迎回来',
        exampleDialogue: '用户: 你好',
        tags: new Array<string>(),
      });

      await runtime.writeCharacterAvatar(saved, 'data:image/jpeg;base64,AAA');
      const avatar = await runtime.readCharacterAvatar(saved);
      const loaded = await runtime.characters.getCharacter(saved.id);

      expect(saved.id.length > 0).assertTrue();
      expect(loaded.name).assertEqual('莉莉');
      expect(loaded.description).assertEqual('旅馆里的向导');
      expect(loaded.personality).assertEqual('温和');
      expect(loaded.scenario).assertEqual('大厅');
      expect(loaded.firstMessage).assertEqual('欢迎回来');
      expect(loaded.exampleDialogue).assertEqual('用户: 你好');
      expect(avatar).assertEqual('data:image/jpeg;base64,AAA');
    });

    it('savesDefaultConnectionProfile', 0, async () => {
      const runtime = TavernRuntimeContainer.configure('unit-test', new InMemoryFileStore());
      await runtime.loadConnections();
      const profileId = 'provider-test-' + Date.now().toString();
      const params: ConnectionProfileCreateParams = {
        id: profileId,
        name: '本地模型',
        apiType: 'openai-compatible',
        model: 'test-model',
        serverUrl: 'https://api.example.com/v1',
        secretRef: 'sk-test',
        generationPresetId: '',
        systemPromptPresetId: '',
        contextTemplateId: '',
        instructTemplateId: '',
        tokenizer: 'provider',
        stopStrings: new Array<string>(),
        reasoningFormat: '',
        toolCallingEnabled: false,
        proxyUrl: '',
        additionalHeaders: new Array<ConnectionHeaderRecord>(),
        enabled: true,
      };
      runtime.connections.createProfile(params);
      runtime.connections.setActiveProfile(
        TavernRuntimeContainer.DEFAULT_CONNECTION_SCOPE,
        TavernRuntimeContainer.DEFAULT_CONNECTION_SCOPE_ID,
        profileId,
      );
      await runtime.connections.saveToStore();

      const resolved: ConnectionResolvedProfile = runtime.connections.resolveActiveProfile(
        TavernRuntimeContainer.DEFAULT_CONNECTION_SCOPE,
        TavernRuntimeContainer.DEFAULT_CONNECTION_SCOPE_ID,
      );

      expect(resolved.profile.id).assertEqual(profileId);
      expect(resolved.profile.model).assertEqual('test-model');
      expect(resolved.secretRef).assertEqual('sk-test');
    });

    it('createsChatAndStoresMessages', 0, async () => {
      const runtime = TavernRuntimeContainer.configure('unit-test', new InMemoryFileStore());
      const character: CharacterRecord = await runtime.characters.createCharacter({
        name: '艾拉',
        description: '',
        personality: '',
        scenario: '',
        firstMessage: '你好，我是艾拉。',
        exampleDialogue: '',
        tags: new Array<string>(),
      });

      const chat = await runtime.chats.createChat({
        title: character.name,
        characterId: character.id,
        personaId: '',
      });
      await runtime.messages(chat.id).addMessage({
        name: character.name,
        role: 'assistant',
        text: character.firstMessage,
      });
      await runtime.messages(chat.id).addMessage({
        name: '你',
        role: 'user',
        text: '你好',
      });
      const messages: Array<ChatMessage> = await runtime.messages(chat.id).listMessages();

      expect(chat.characterId).assertEqual(character.id);
      expect(messages.length).assertEqual(2);
      expect(messages[0].role).assertEqual('assistant');
      expect(messages[1].text).assertEqual('你好');
    });
  });
}
