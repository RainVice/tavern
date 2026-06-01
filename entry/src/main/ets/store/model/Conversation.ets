import { ColumnType, Columns, Entity, Id, Index, NotNull } from '@ohos/dataorm';

export enum ConversationMode {
  Single = 'single',
  Group = 'group',
}

export enum ConversationRole {
  User = 'user',
  Assistant = 'assistant',
  System = 'system',
}

export enum ConversationMessageStatus {
  Done = 'done',
  Streaming = 'streaming',
  Error = 'error',
}

export interface ConversationParticipant {
  characterId: string;
}

export interface ConversationModel {
  id: number;
  title: string;
  mode: ConversationMode;
  participants: ConversationParticipant[];
  messageCount: number;
  updateTime: number;
}

export interface ConversationMessage {
  id: number;
  conversationId: number;
  seq: number;
  role: ConversationRole;
  content: string;
  characterId: string | null;
  status: ConversationMessageStatus;
  updateTime: number;
}

/**
 * 会话主表，对应表 `conversation`。
 *
 * `id` 是数据库自增主键。
 */
@Entity('conversation')
export class ConversationEntity {
  @Id({ autoincrement: true })
  @Columns({ columnName: 'id', types: ColumnType.num })
  id?: number;

  @NotNull()
  @Columns({ columnName: 'title', types: ColumnType.str })
  title: string = '';

  @NotNull()
  @Index()
  @Columns({ columnName: 'mode', types: ColumnType.str })
  mode: string = ConversationMode.Single;

  @Columns({ columnName: 'message_count', types: ColumnType.num })
  messageCount: number = 0;

  @Index()
  @Columns({ columnName: 'update_time', types: ColumnType.num })
  updateTime: number = 0;

  constructor(id?: number, title?: string, mode?: ConversationMode, messageCount?: number, updateTime?: number) {
    this.id = id;
    this.title = title ?? '';
    this.mode = mode ?? ConversationMode.Single;
    this.messageCount = messageCount ?? 0;
    this.updateTime = updateTime ?? 0;
  }

  static fromModel(conversation: ConversationModel): ConversationEntity {
    return new ConversationEntity(
      conversation.id || undefined,
      conversation.title,
      conversation.mode,
      conversation.messageCount,
      conversation.updateTime,
    );
  }

  static toModel(entity: ConversationEntity, participants: ConversationParticipantEntity[]): ConversationModel {
    const matchedParticipants = participants
      .filter((participant) => participant.conversationId === entity.id)
      .map((participant) => ({ characterId: participant.characterId } as ConversationParticipant));
    return {
      id: entity.id ?? 0,
      title: entity.title,
      mode: ConversationEntity.normalizeMode(entity.mode),
      participants: matchedParticipants,
      messageCount: entity.messageCount,
      updateTime: entity.updateTime,
    };
  }

  static normalizeMode(mode: string): ConversationMode {
    return mode === ConversationMode.Group ? ConversationMode.Group : ConversationMode.Single;
  }
}

/**
 * 会话参与角色表，对应表 `conversation_participant`。
 *
 * 一行代表某个角色参与某个会话。`conversationId + characterId` 唯一。
 */
@Entity('conversation_participant', [{ value: 'conversationId, characterId', unique: true }])
export class ConversationParticipantEntity {
  @Id({ autoincrement: true })
  @Columns({ columnName: 'id', types: ColumnType.num })
  id?: number;

  @NotNull()
  @Index()
  @Columns({ columnName: 'conversation_id', types: ColumnType.num })
  conversationId: number = 0;

  @NotNull()
  @Index()
  @Columns({ columnName: 'character_id', types: ColumnType.str })
  characterId: string = '';

  constructor(id?: number, conversationId?: number, characterId?: string) {
    this.id = id;
    this.conversationId = conversationId ?? 0;
    this.characterId = characterId ?? '';
  }

  static fromModel(conversationId: number, participant: ConversationParticipant): ConversationParticipantEntity {
    return new ConversationParticipantEntity(undefined, conversationId, participant.characterId);
  }
}

/**
 * 会话消息表，对应表 `conversation_message`。
 *
 * `id` 是数据库自增主键。`conversationId + seq` 唯一，用于按会话内顺序读取。
 */
@Entity('conversation_message', [{ value: 'conversationId, seq', unique: true }])
export class ConversationMessageEntity {
  @Id({ autoincrement: true })
  @Columns({ columnName: 'id', types: ColumnType.num })
  id?: number;

  @NotNull()
  @Index()
  @Columns({ columnName: 'conversation_id', types: ColumnType.num })
  conversationId: number = 0;

  @NotNull()
  @Index()
  @Columns({ columnName: 'seq', types: ColumnType.num })
  seq: number = 0;

  @NotNull()
  @Index()
  @Columns({ columnName: 'role', types: ColumnType.str })
  role: string = ConversationRole.User;

  @Columns({ columnName: 'content', types: ColumnType.str })
  content: string = '';

  @Columns({ columnName: 'character_id', types: ColumnType.str })
  characterId: string = '';

  @NotNull()
  @Index()
  @Columns({ columnName: 'status', types: ColumnType.str })
  status: string = ConversationMessageStatus.Done;

  @Index()
  @Columns({ columnName: 'update_time', types: ColumnType.num })
  updateTime: number = 0;

  constructor(id?: number, conversationId?: number, seq?: number, role?: ConversationRole,
    content?: string, characterId?: string, status?: ConversationMessageStatus, updateTime?: number) {
    this.id = id;
    this.conversationId = conversationId ?? 0;
    this.seq = seq ?? 0;
    this.role = role ?? ConversationRole.User;
    this.content = content ?? '';
    this.characterId = characterId ?? '';
    this.status = status ?? ConversationMessageStatus.Done;
    this.updateTime = updateTime ?? 0;
  }

  static fromModel(message: ConversationMessage): ConversationMessageEntity {
    return new ConversationMessageEntity(
      message.id || undefined,
      message.conversationId,
      message.seq,
      message.role,
      message.content,
      message.characterId ?? '',
      message.status,
      message.updateTime,
    );
  }

  static toModel(entity: ConversationMessageEntity): ConversationMessage {
    return {
      id: entity.id ?? 0,
      conversationId: entity.conversationId,
      seq: entity.seq,
      role: ConversationMessageEntity.normalizeRole(entity.role),
      content: entity.content,
      characterId: entity.characterId || null,
      status: ConversationMessageEntity.normalizeStatus(entity.status),
      updateTime: entity.updateTime,
    };
  }

  static normalizeRole(role: string): ConversationRole {
    if (role === ConversationRole.Assistant) {
      return ConversationRole.Assistant;
    }
    if (role === ConversationRole.System) {
      return ConversationRole.System;
    }
    return ConversationRole.User;
  }

  static normalizeStatus(status: string): ConversationMessageStatus {
    if (status === ConversationMessageStatus.Streaming) {
      return ConversationMessageStatus.Streaming;
    }
    if (status === ConversationMessageStatus.Error) {
      return ConversationMessageStatus.Error;
    }
    return ConversationMessageStatus.Done;
  }
}
