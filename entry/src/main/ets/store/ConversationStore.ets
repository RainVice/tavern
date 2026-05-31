import { BaseDao } from '@ohos/dataorm';
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
  conversationId: string;
  role: ConversationRole;
  content: string;
  characterId: string | null;
  status: ConversationMessageStatus;
}

class ConversationStore {
  private async getConversationDao(): Promise<BaseDao<ConversationEntity, string>> {
    return tavernDatabase.getConversationDao();
  }

  private async getParticipantDao(): Promise<BaseDao<ConversationParticipantEntity, string>> {
    return tavernDatabase.getConversationParticipantDao();
  }

  private async getMessageDao(): Promise<BaseDao<ConversationMessageEntity, string>> {
    return tavernDatabase.getConversationMessageDao();
  }

  async getAllConversations(): Promise<Conversation[]> {
    const conversationDao = await this.getConversationDao();
    const participantDao = await this.getParticipantDao();
    const conversations = await conversationDao.loadAll();
    const participants = await participantDao.loadAll();
    return conversations
      .sort((left, right) => ConversationStore.compareIsoDesc(left.updatetime, right.updatetime))
      .map((conversation) => ConversationEntity.toModel(conversation, participants));
  }

  async getConversation(id: string): Promise<Conversation | undefined> {
    if (!id) {
      return undefined;
    }
    const conversationDao = await this.getConversationDao();
    const participantDao = await this.getParticipantDao();
    const entity = (await conversationDao.loadAll()).find((conversation) => conversation.id === id);
    if (!entity) {
      return undefined;
    }
    const participants = (await participantDao.loadAll()).filter((participant) => participant.conversationId === id);
    return ConversationEntity.toModel(entity, participants);
  }

  async createConversation(title: string, mode: ConversationMode, participants: ConversationParticipant[]): Promise<string> {
    const id = this.createId('conv');
    const conversation: Conversation = {
      id: id,
      title: title,
      mode: mode,
      participants: participants,
      messageCount: 0,
      updatetime: ConversationStore.createIsoTime(),
    };
    return this.saveConversation(conversation);
  }

  async saveConversation(conversation: Conversation): Promise<string> {
    const conversationDao = await this.getConversationDao();
    const entity = ConversationEntity.fromModel(conversation);
    const oldEntity = await conversationDao.load(conversation.id);
    if (oldEntity) {
      await conversationDao.updateAsync(entity);
    } else {
      await conversationDao.insert(entity);
    }
    await this.replaceParticipants(conversation.id, conversation.participants);
    return entity.id;
  }

  async deleteConversation(id: string): Promise<void> {
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

  async getMessages(conversationId: string): Promise<ConversationMessage[]> {
    const messageDao = await this.getMessageDao();
    return (await messageDao.loadAll())
      .filter((message) => message.conversationId === conversationId)
      .sort((left, right) => left.seq - right.seq)
      .map((message) => ConversationMessageEntity.toModel(message));
  }

  async saveMessage(message: ConversationMessage): Promise<string> {
    const messageDao = await this.getMessageDao();
    const entity = ConversationMessageEntity.fromModel(message);
    const oldEntity = await messageDao.load(message.id);
    if (oldEntity) {
      await messageDao.updateAsync(entity);
    } else {
      await messageDao.insert(entity);
    }
    await this.refreshConversationAfterMessagesChanged(message.conversationId);
    return entity.id;
  }

  async appendMessage(options: AppendConversationMessageOptions): Promise<ConversationMessage> {
    const messages = await this.getMessages(options.conversationId);
    let nextSeq = 1;
    for (const message of messages) {
      if (message.seq >= nextSeq) {
        nextSeq = message.seq + 1;
      }
    }
    const messageId = this.createId('msg');
    const message: ConversationMessage = {
      id: messageId,
      conversationId: options.conversationId,
      seq: nextSeq,
      role: options.role,
      content: options.content,
      characterId: options.characterId,
      status: ConversationMessageEntity.normalizeStatus(options.status),
      updatetime: ConversationStore.createIsoTime(),
    };
    await this.saveMessage(message);
    return message;
  }

  async deleteMessage(id: string): Promise<void> {
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

  private async replaceParticipants(conversationId: string, participants: ConversationParticipant[]): Promise<void> {
    const participantDao = await this.getParticipantDao();
    const oldParticipants = (await participantDao.loadAll())
      .filter((participant) => participant.conversationId === conversationId);
    for (const participant of oldParticipants) {
      await participantDao.deleteByKeyAsync(participant.id);
    }
    for (let index = 0; index < participants.length; index++) {
      await participantDao.insert(ConversationParticipantEntity.fromModel(conversationId, participants[index]));
    }
  }

  private async replaceMessages(conversationId: string, messages: ConversationMessage[]): Promise<void> {
    const messageDao = await this.getMessageDao();
    const oldMessages = (await messageDao.loadAll()).filter((message) => message.conversationId === conversationId);
    for (const message of oldMessages) {
      await messageDao.deleteByKeyAsync(message.id);
    }
    for (let index = 0; index < messages.length; index++) {
      await messageDao.insert(ConversationMessageEntity.fromModel(messages[index]));
    }
  }

  private async refreshConversationAfterMessagesChanged(conversationId: string): Promise<void> {
    const conversation = await this.getConversation(conversationId);
    if (!conversation) {
      return;
    }
    const messages = await this.getMessages(conversationId);
    conversation.messageCount = messages.length;
    conversation.updatetime = ConversationStore.createIsoTime();
    await this.saveConversation(conversation);
  }

  private createId(prefix: string): string {
    const randomPart = Math.floor(Math.random() * 1000000).toString();
    return prefix + '_' + systemDateTime.getTime().toString() + '_' + randomPart;
  }

  private static compareIsoDesc(left: string, right: string): number {
    if (left < right) {
      return 1;
    }
    if (left > right) {
      return -1;
    }
    return 0;
  }

  private static createIsoTime(): string {
    return new Date(systemDateTime.getTime()).toISOString();
  }
}

export const conversationStore = new ConversationStore();
