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
      const conversation = new ConversationEntity(1, '旅馆大厅', ConversationMode.Group, 2,
        1780200000000);
      const participants: ConversationParticipantEntity[] = [
        new ConversationParticipantEntity(1, 1, 'character_a'),
        new ConversationParticipantEntity(2, 1, 'character_b'),
      ];
      const mapped: Conversation = ConversationEntity.toModel(conversation, participants);

      expect(mapped.id).assertEqual(1);
      expect(mapped.updateTime).assertEqual(1780200000000);
      expect(mapped.participants.length).assertEqual(2);
      expect(mapped.participants[1].characterId).assertEqual('character_b');

      const message: ConversationMessage = {
        id: 1,
        conversationId: 1,
        seq: 1,
        role: ConversationRole.User,
        content: '你好',
        characterId: null,
        status: ConversationMessageStatus.Done,
        updateTime: 1780200060000,
      };
      const entity: ConversationMessageEntity = ConversationMessageEntity.fromModel(message);
      const restored: ConversationMessage = ConversationMessageEntity.toModel(entity);

      expect(entity.id).assertEqual(1);
      expect(entity.conversationId).assertEqual(1);
      expect(entity.characterId).assertEqual('');
      expect(restored.characterId).assertEqual(null);
      expect(restored.seq).assertEqual(1);
      expect(restored.updateTime).assertEqual(1780200060000);
    });
  });
}
