import { JSONUtil } from '@pura/harmony-utils';
import { Columns, ColumnType, Entity, PropertyConverter } from 'rdbstore';

class ConversationParticipantConvertor extends PropertyConverter<ConversationParticipant[], string> {
  convertToEntityProperty(databaseValue: string): ConversationParticipant[] {
    return JSONUtil.jsonToBean(databaseValue, Array<ConversationParticipant>) ?? [];
  }

  convertToDatabaseValue(entityProperty: ConversationParticipant[]): string {
    return JSONUtil.beanToJsonStr(entityProperty);
  }
}

export enum ConversationMode {
  Single = 'single',
  Group = 'group',
}

export interface ConversationParticipant {
  readonly characterId?: string;
}

@Entity({ tableName: ConversationEntity.tableName })
export class ConversationEntity implements Conversation {
  static readonly tableName: string = 'ConversationEntity';
  /** 会话业务 ID，保存后由数据库自增主键回填。新建时为 0。 */
  @Columns({
    name: ConversationEntity.id_name,
    type: ColumnType.INTEGER,
    autoincrement: true,
    isPrimaryKey: true,
    unique: true,
    notNull: true,
  })
  readonly id?: number;
  static readonly id_name = 'id';
  /** 会话标题，用于列表和聊天页展示。 */
  @Columns({ name: ConversationEntity.title_name, type: ColumnType.TEXT })
  readonly title?: string = undefined;
  static readonly title_name: string = 'title';
  /** 会话模式，single 表示私聊，group 表示群聊。 */
  @Columns({ name: ConversationEntity.mode_name, type: ColumnType.TEXT })
  readonly mode?: ConversationMode = undefined;
  static readonly mode_name: string = 'mode';
  /** 会话参与角色列表。 */
  @Columns({
    name: ConversationEntity.participants_name,
    type: ColumnType.TEXT,
    convertor: ConversationParticipantConvertor,
  })
  readonly participants?: ConversationParticipant[] = undefined;
  static readonly participants_name: string = 'participants';
  /** 当前会话下的消息数量，用于列表展示和排序辅助。 */
  @Columns({ name: ConversationEntity.messageCount_name, type: ColumnType.INTEGER })
  readonly messageCount?: number = undefined;
  static readonly messageCount_name: string = 'messageCount';
  /** 最近更新时间，毫秒时间戳。用于列表按最近对话倒序展示。 */
  @Columns({ name: ConversationEntity.updateTime_name, type: ColumnType.INTEGER })
  readonly updateTime?: number = undefined;
  static readonly updateTime_name: string = 'updateTime';
}

export interface Conversation {
  readonly id?: number;
  readonly title?: string;
  readonly mode?: ConversationMode;
  readonly participants?: ConversationParticipant[];
  readonly messageCount?: number;
  readonly updateTime?: number;
}
