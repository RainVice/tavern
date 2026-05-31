import { BaseDao, Property } from '@ohos/dataorm';
import { systemDateTime } from '@kit.BasicServicesKit';
import { tavernDatabase } from './TavernDatabase';
import {
  Conversation,
  ConversationEntity,
  ConversationMessage,
  ConversationMessageEntity,
  ConversationMessageStatus,
  ConversationMode,
  ConversationParticipant,
  ConversationParticipantEntity,
  ConversationRole,
} from './model/Conversation';

export interface AppendConversationMessageOptions {
  conversationId: number;
  role: ConversationRole;
  content: string;
  characterId: string | null;
  status: ConversationMessageStatus;
}

class ConversationStore {
  private static readonly PARTICIPANT_CONVERSATION_ID: Property =
    new Property(1, 'number', 'conversationId', false, 'conversation_id', false);
  private static readonly MESSAGE_CONVERSATION_ID: Property =
    new Property(1, 'number', 'conversationId', false, 'conversation_id', false);
  private static readonly MESSAGE_SEQ: Property =
    new Property(2, 'number', 'seq', false, 'seq', false);

  private appendMessageQueue: Promise<void> = Promise.resolve();

  private async getConversationDao(): Promise<BaseDao<ConversationEntity, number>> {
    return tavernDatabase.getConversationDao();
  }

  private async getParticipantDao(): Promise<BaseDao<ConversationParticipantEntity, number>> {
    return tavernDatabase.getConversationParticipantDao();
  }

  private async getMessageDao(): Promise<BaseDao<ConversationMessageEntity, number>> {
    return tavernDatabase.getConversationMessageDao();
  }

  async getAllConversations(): Promise<Conversation[]> {
    const conversationDao = await this.getConversationDao();
    const participantDao = await this.getParticipantDao();
    const conversations = await conversationDao.loadAll();
    const participants = await participantDao.loadAll();
    return conversations
      .sort((left, right) => right.updateTime - left.updateTime)
      .map((conversation) => ConversationEntity.toModel(conversation, participants));
  }

  async getConversation(id: number): Promise<Conversation | undefined> {
    if (!id) {
      return undefined;
    }
    const conversationDao = await this.getConversationDao();
    const entity = await conversationDao.load(id);
    if (!entity) {
      return undefined;
    }
    const participants = await this.getParticipants(id);
    return ConversationEntity.toModel(entity, participants);
  }

  async createConversation(title: string, mode: ConversationMode, participants: ConversationParticipant[]): Promise<number> {
    const conversationDao = await this.getConversationDao();
    const conversation: Conversation = {
      id: 0,
      title: title,
      mode: mode,
      participants: participants,
      messageCount: 0,
      updateTime: systemDateTime.getTime(),
    };
    const entity = ConversationEntity.fromModel(conversation);
    await conversationDao.insert(entity);
    const conversationId = entity.id ?? 0;
    this.assertSavedId(conversationId, 'conversation');
    try {
      await this.replaceParticipants(conversationId, conversation.participants);
    } catch (e) {
      await conversationDao.deleteByKeyAsync(conversationId);
      throw new Error('Failed to save conversation participants');
    }
    return conversationId;
  }

  async updateConversationInfo(id: number, title: string, mode: ConversationMode): Promise<void> {
    const conversationDao = await this.getConversationDao();
    const entity = await this.requireConversationEntity(id);
    entity.title = title;
    entity.mode = mode;
    entity.updateTime = systemDateTime.getTime();
    await conversationDao.updateAsync(entity);
  }

  async updateParticipants(conversationId: number, participants: ConversationParticipant[]): Promise<void> {
    await this.requireConversationEntity(conversationId);
    await this.replaceParticipants(conversationId, participants);
  }

  async deleteConversation(id: number): Promise<void> {
    if (!id) {
      return;
    }
    const conversationDao = await this.getConversationDao();
    await this.replaceParticipants(id, []);
    await this.replaceMessages(id, []);
    const entity = await conversationDao.load(id);
    if (entity) {
      await conversationDao.deleteByKeyAsync(id);
    }
  }

  async getMessages(conversationId: number): Promise<ConversationMessage[]> {
    const messageDao = await this.getMessageDao();
    return (await messageDao.queryBuilder()
      .where(ConversationStore.MESSAGE_CONVERSATION_ID.eq(conversationId))
      .orderAsc(ConversationStore.MESSAGE_SEQ)
      .list())
      .map((message) => ConversationMessageEntity.toModel(message));
  }

  async saveMessage(message: ConversationMessage): Promise<number> {
    await this.requireConversationEntity(message.conversationId);
    const messageDao = await this.getMessageDao();
    const entity = ConversationMessageEntity.fromModel(message);
    const oldEntity = entity.id ? await messageDao.load(entity.id) : undefined;
    if (entity.id && oldEntity) {
      if (oldEntity.conversationId !== message.conversationId) {
        throw new Error('Message does not belong to conversation: ' + message.id.toString());
      }
      await messageDao.updateAsync(entity);
    } else {
      await messageDao.insert(entity);
    }
    const messageId = entity.id ?? 0;
    this.assertSavedId(messageId, 'conversation message');
    await this.refreshConversationAfterMessagesChanged(message.conversationId);
    return messageId;
  }

  async appendMessage(options: AppendConversationMessageOptions): Promise<ConversationMessage> {
    const previousTask = this.appendMessageQueue;
    let releaseCurrent: () => void = () => {};
    this.appendMessageQueue = new Promise<void>((resolve: () => void) => {
      releaseCurrent = resolve;
    });
    await previousTask;
    try {
      return await this.appendMessageLocked(options);
    } finally {
      releaseCurrent();
    }
  }

  private async appendMessageLocked(options: AppendConversationMessageOptions): Promise<ConversationMessage> {
    await this.requireConversationEntity(options.conversationId);
    const messages = await this.getMessages(options.conversationId);
    let nextSeq = 1;
    for (const message of messages) {
      if (message.seq >= nextSeq) {
        nextSeq = message.seq + 1;
      }
    }
    const message: ConversationMessage = {
      id: 0,
      conversationId: options.conversationId,
      seq: nextSeq,
      role: options.role,
      content: options.content,
      characterId: options.characterId,
      status: ConversationMessageEntity.normalizeStatus(options.status),
      updateTime: systemDateTime.getTime(),
    };
    message.id = await this.saveMessage(message);
    return message;
  }

  async deleteMessage(id: number): Promise<void> {
    if (!id) {
      return;
    }
    const messageDao = await this.getMessageDao();
    const entity = await messageDao.load(id);
    if (entity) {
      await messageDao.deleteByKeyAsync(id);
      await this.refreshConversationAfterMessagesChanged(entity.conversationId);
    }
  }

  private async replaceParticipants(conversationId: number, participants: ConversationParticipant[]): Promise<void> {
    const participantDao = await this.getParticipantDao();
    const oldParticipants = await this.getParticipants(conversationId);
    const oldParticipantIds: number[] = [];
    for (const participant of oldParticipants) {
      if (participant.id) {
        oldParticipantIds.push(participant.id);
      }
    }
    if (oldParticipantIds.length > 0) {
      await participantDao.deleteByKeyInTxIterableAsync(oldParticipantIds);
    }
    const newParticipants: ConversationParticipantEntity[] = [];
    for (let index = 0; index < participants.length; index++) {
      newParticipants.push(ConversationParticipantEntity.fromModel(conversationId, participants[index]));
    }
    if (newParticipants.length > 0) {
      await participantDao.insertInTxIterableAsync(newParticipants);
    }
  }

  private async replaceMessages(conversationId: number, messages: ConversationMessage[]): Promise<void> {
    const messageDao = await this.getMessageDao();
    const oldMessages = await this.getMessageEntities(conversationId);
    const oldMessageIds: number[] = [];
    for (const message of oldMessages) {
      if (message.id) {
        oldMessageIds.push(message.id);
      }
    }
    if (oldMessageIds.length > 0) {
      await messageDao.deleteByKeyInTxIterableAsync(oldMessageIds);
    }
    const newMessages: ConversationMessageEntity[] = [];
    for (let index = 0; index < messages.length; index++) {
      newMessages.push(ConversationMessageEntity.fromModel(messages[index]));
    }
    if (newMessages.length > 0) {
      await messageDao.insertInTxIterableAsync(newMessages);
    }
  }

  private async refreshConversationAfterMessagesChanged(conversationId: number): Promise<void> {
    const messages = await this.getMessages(conversationId);
    await this.updateConversationMeta(conversationId, messages.length, systemDateTime.getTime());
  }

  private async getParticipants(conversationId: number): Promise<ConversationParticipantEntity[]> {
    const participantDao = await this.getParticipantDao();
    return participantDao.queryBuilder()
      .where(ConversationStore.PARTICIPANT_CONVERSATION_ID.eq(conversationId))
      .list();
  }

  private async getMessageEntities(conversationId: number): Promise<ConversationMessageEntity[]> {
    const messageDao = await this.getMessageDao();
    return messageDao.queryBuilder()
      .where(ConversationStore.MESSAGE_CONVERSATION_ID.eq(conversationId))
      .orderAsc(ConversationStore.MESSAGE_SEQ)
      .list();
  }

  private async updateConversationMeta(conversationId: number, messageCount: number, updateTime: number): Promise<void> {
    const conversationDao = await this.getConversationDao();
    const entity = await this.requireConversationEntity(conversationId);
    entity.messageCount = messageCount;
    entity.updateTime = updateTime;
    await conversationDao.updateAsync(entity);
  }

  private async requireConversationEntity(conversationId: number): Promise<ConversationEntity> {
    if (!conversationId) {
      throw new Error('Conversation id is required');
    }
    const conversationDao = await this.getConversationDao();
    const entity = await conversationDao.load(conversationId);
    if (!entity) {
      throw new Error('Conversation not found: ' + conversationId.toString());
    }
    return entity;
  }

  private assertSavedId(id: number, entityName: string): void {
    if (!id) {
      throw new Error('Failed to save ' + entityName);
    }
  }

}

export const conversationStore = new ConversationStore();
