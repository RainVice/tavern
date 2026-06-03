import { Columns, ColumnType, Entity } from 'rdbstore';

/**
 * 页面和业务层使用的角色卡模型。
 *
 * 这个接口保持页面友好结构，不直接等同数据库表结构：
 * - `avatarUrl` 存在独立资源表 `character_card_asset`。
 * - `id` 直接使用数据库自增整数，未保存的新数据使用 0。
 */
@Entity({ tableName: CharacterCardEntity.tableName })
export class CharacterCardEntity implements CharacterCard {
  static readonly tableName = 'CharacterCardEntity';
  /** 角色卡业务 ID，保存后由数据库自增主键回填。新建时为 0。 */
  @Columns({
    name: CharacterCardEntity.id_name,
    type: ColumnType.INTEGER,
    autoincrement: true,
    isPrimaryKey: true,
    unique: true,
    notNull: true,
  })
  readonly id?: number = undefined;
  static readonly id_name = 'id';
  /** 角色名称，用于列表标题、详情页标题和聊天入口展示。 */
  @Columns({ name: CharacterCardEntity.name_name, type: ColumnType.TEXT, })
  readonly name?: string = undefined;
  static readonly name_name = 'name';
  /** 最近更新时间，毫秒时间戳。用于列表按最近编辑时间倒序展示。 */
  @Columns({ name: CharacterCardEntity.updateTime_name, type: ColumnType.INTEGER, })
  readonly updateTime?: number = undefined;
  static readonly updateTime_name = 'updateTime';
  /** 角色头像数据或路径。目前编辑页会保存 base64 图片字符串。 */
  @Columns({ name: CharacterCardEntity.avatarUrl_name, type: ColumnType.TEXT, })
  readonly avatarUrl?: string = undefined;
  static readonly avatarUrl_name = 'avatarUrl';
  /** 角色简介，适合展示给用户快速了解角色。 */
  @Columns({ name: CharacterCardEntity.description_name, type: ColumnType.TEXT, })
  readonly description?: string = undefined;
  static readonly description_name = 'description';
  /** 角色性格、人设设定，用于后续对话上下文。 */
  @Columns({ name: CharacterCardEntity.personality_name, type: ColumnType.TEXT, })
  readonly personality?: string = undefined;
  static readonly personality_name = 'personality';
  /** 对话发生的场景设定，用于后续对话上下文。 */
  @Columns({ name: CharacterCardEntity.scenario_name, type: ColumnType.TEXT, })
  readonly scenario?: string = undefined;
  static readonly scenario_name = 'scenario';
  /** 角色开场白，开始对话时可作为首条角色消息。 */
  @Columns({ name: CharacterCardEntity.firstMessage_name, type: ColumnType.TEXT, })
  readonly firstMessage?: string = undefined;
  static readonly firstMessage_name = 'firstMessage';
  /** 示例对话文本，用于描述角色说话风格。 */
  @Columns({ name: CharacterCardEntity.exampleMessages_name, type: ColumnType.TEXT, })
  readonly exampleMessages?: string = undefined;
  static readonly exampleMessages_name = 'exampleMessages';
}


export interface CharacterCard {
  readonly id?: number;
  readonly name?: string;
  readonly avatarUrl?: string;
  readonly updateTime?: number;
  readonly description?: string;
  readonly personality?: string;
  readonly scenario?: string;
  readonly firstMessage?: string;
  readonly exampleMessages?: string;
}