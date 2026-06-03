import { Columns, ColumnType, Entity } from 'rdbstore';

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

@Entity({ tableName: ConversationMessageEntity.tableName })
export class ConversationMessageEntity implements ConversationMessage {
  static readonly tableName: string = 'ConversationMessageEntity';

  /** 消息业务 ID，保存后由数据库自增主键回填。新建时为 0。 */
  @Columns({
    name: ConversationMessageEntity.id_name,
    type: ColumnType.INTEGER,
    autoincrement: true,
    isPrimaryKey: true,
    unique: true,
    notNull: true,
  })
  readonly id?: number = undefined;
  static readonly id_name: string = 'id';
  /** 所属会话 ID，对应 ConversationEntity.id。 */
  @Columns({ name: ConversationMessageEntity.conversationId_name, type: ColumnType.INTEGER })
  readonly conversationId?: number = undefined;
  static readonly conversationId_name: string = 'conversationId';
  /** 消息在会话内的顺序号。 */
  @Columns({ name: ConversationMessageEntity.seq_name, type: ColumnType.INTEGER })
  readonly seq?: number = undefined;
  static readonly seq_name: string = 'seq';
  /** 消息角色，区分用户、助手和系统消息。 */
  @Columns({ name: ConversationMessageEntity.role_name, type: ColumnType.TEXT })
  readonly role?: ConversationRole = undefined;
  static readonly role_name: string = 'role';
  /** 消息正文内容。 */
  @Columns({ name: ConversationMessageEntity.content_name, type: ColumnType.TEXT })
  readonly content?: string = undefined;
  static readonly content_name: string = 'content';
  /** 关联角色 ID；用户或系统消息可以为空。 */
  @Columns({ name: ConversationMessageEntity.characterId_name, type: ColumnType.TEXT })
  readonly characterId?: string = undefined;
  static readonly characterId_name: string = 'characterId';
  /** 消息状态，用于标记完成、生成中或错误。 */
  @Columns({ name: ConversationMessageEntity.status_name, type: ColumnType.TEXT })
  readonly status?: ConversationMessageStatus = undefined;
  static readonly status_name: string = 'status';
  /** 最近更新时间，毫秒时间戳。 */
  @Columns({ name: ConversationMessageEntity.updateTime_name, type: ColumnType.INTEGER })
  readonly updateTime?: number = undefined;
  static readonly updateTime_name: string = 'updateTime';
}

export interface ConversationMessage {
  readonly id?: number;
  readonly conversationId?: number;
  readonly seq?: number;
  readonly role?: ConversationRole;
  readonly content?: string;
  readonly characterId?: string;
  readonly status?: ConversationMessageStatus;
  readonly updateTime?: number;
}
