import { describe, it, expect } from '@ohos/hypium';
import {
  Conversation,
  ConversationEntity,
  ConversationMessage,
  ConversationMessageEntity,
  ConversationMessageStatus,
  ConversationMode,
  ConversationParticipantEntity,
  ConversationRole,
} from '../main/ets/store/model/Conversation';

export default function conversationStoreTest() {
  describe('conversationStoreModels', () => {
    it('mapsConversationParticipantsAndMessagesAcrossSeparateTables', 0, () => {
      const conversation = new ConversationEntity('conv_1', '旅馆大厅', ConversationMode.Group, 2,
        '2026-05-31T00:00:00.000Z');
      const participants: ConversationParticipantEntity[] = [
        new ConversationParticipantEntity('conv_1_character_a', 'conv_1', 'character_a'),
        new ConversationParticipantEntity('conv_1_character_b', 'conv_1', 'character_b'),
      ];
      const mapped: Conversation = ConversationEntity.toModel(conversation, participants);

      expect(mapped.id).assertEqual('conv_1');
      expect(mapped.participants.length).assertEqual(2);
      expect(mapped.participants[1].characterId).assertEqual('character_b');

      const message: ConversationMessage = {
        id: 'msg_1',
        conversationId: 'conv_1',
        seq: 1,
        role: ConversationRole.User,
        content: '你好',
        characterId: null,
        status: ConversationMessageStatus.Done,
        updatetime: '2026-05-31T00:01:00.000Z',
      };
      const entity: ConversationMessageEntity = ConversationMessageEntity.fromModel(message);
      const restored: ConversationMessage = ConversationMessageEntity.toModel(entity);

      expect(entity.characterId).assertEqual('');
      expect(restored.characterId).assertEqual(null);
      expect(restored.seq).assertEqual(1);
    });
  });
}
