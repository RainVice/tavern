import { ColumnType, Columns, Entity, Id, Index, NotNull, Unique } from '@ohos/dataorm';

/**
 * 页面和业务层使用的角色卡模型。
 *
 * 这个接口保持页面友好结构，不直接等同数据库表结构：
 * - `avatarUrl` 存在独立资源表 `character_card_asset`。
 * - `id` 直接使用数据库自增整数，未保存的新数据使用 0。
 */
export interface CharacterCard {
  /** 角色卡业务 ID，保存后由数据库自增主键回填。新建时为 0。 */
  id: number;

  /** 角色名称，用于列表标题、详情页标题和聊天入口展示。 */
  name: string;

  /** 最近更新时间，毫秒时间戳。用于列表按最近编辑时间倒序展示。 */
  updateTime?: number;

  /** 角色头像数据或路径。目前编辑页会保存 base64 图片字符串。 */
  avatarUrl?: string;

  /** 角色简介，适合展示给用户快速了解角色。 */
  description?: string;

  /** 角色性格、人设设定，用于后续对话上下文。 */
  personality?: string;

  /** 对话发生的场景设定，用于后续对话上下文。 */
  scenario?: string;

  /** 角色开场白，开始对话时可作为首条角色消息。 */
  firstMessage?: string;

  /** 示例对话文本，用于描述角色说话风格。 */
  exampleMessages?: string;
}

/**
 * 角色卡主表实体，对应表 `character_card`。
 *
 * 主表只保存结构化文本字段和排序用时间；头像等较大的资源字段拆到
 * `character_card_asset`，避免列表查询时反复加载大字段。
 */
@Entity('character_card')
export class CharacterCardEntity {
  /** 主键，自增整数。新建实体使用 undefined，让数据库分配 ID，dataorm 插入后会回写该字段。 */
  @Id({ autoincrement: true })
  @Columns({ columnName: 'id', types: ColumnType.num })
  id?: number;

  /** 角色名称。不能为空，并建立普通索引，便于后续按名称查找或排序。 */
  @NotNull()
  @Index()
  @Columns({ columnName: 'name', types: ColumnType.str })
  name: string = '';

  /** 最近更新时间，毫秒时间戳。建立索引用于列表按更新时间倒序展示。 */
  @Index()
  @Columns({ columnName: 'update_time', types: ColumnType.num })
  updateTime: number = 0;

  /** 角色简介。空字符串表示用户未填写，映射回业务模型时转成 undefined。 */
  @Columns({ columnName: 'description', types: ColumnType.str })
  description: string = '';

  /** 角色性格、人设设定。 */
  @Columns({ columnName: 'personality', types: ColumnType.str })
  personality: string = '';

  /** 角色所处场景设定。 */
  @Columns({ columnName: 'scenario', types: ColumnType.str })
  scenario: string = '';

  /** 角色开场白。 */
  @Columns({ columnName: 'first_message', types: ColumnType.str })
  firstMessage: string = '';

  /** 示例对话文本。 */
  @Columns({ columnName: 'example_messages', types: ColumnType.str })
  exampleMessages: string = '';

  constructor(id?: number, name?: string, updateTime?: number, description?: string, personality?: string,
    scenario?: string, firstMessage?: string, exampleMessages?: string) {
    this.id = id;
    this.name = name ?? '';
    this.updateTime = updateTime ?? 0;
    this.description = description ?? '';
    this.personality = personality ?? '';
    this.scenario = scenario ?? '';
    this.firstMessage = firstMessage ?? '';
    this.exampleMessages = exampleMessages ?? '';
  }

  /**
   * 将数据库实体合并为页面/业务层角色卡模型。
   */
  static toModel(entity: CharacterCardEntity, asset?: CharacterCardAssetEntity): CharacterCard {
    return {
      id: entity.id ?? 0,
      name: entity.name,
      updateTime: entity.updateTime,
      avatarUrl: asset?.avatarUrl || undefined,
      description: entity.description || undefined,
      personality: entity.personality || undefined,
      scenario: entity.scenario || undefined,
      firstMessage: entity.firstMessage || undefined,
      exampleMessages: entity.exampleMessages || undefined,
    };
  }

  /**
   * 将页面/业务层角色卡模型转成角色卡主表实体。
   *
   * `avatarUrl` 不在这里处理，由 Store 单独写入 `character_card_asset`。
   */
  static fromModel(card: CharacterCard, updateTime: number): CharacterCardEntity {
    return new CharacterCardEntity(
      card.id || undefined,
      card.name,
      updateTime,
      card.description ?? '',
      card.personality ?? '',
      card.scenario ?? '',
      card.firstMessage ?? '',
      card.exampleMessages ?? '',
    );
  }
}

/**
 * 角色卡资源表实体，对应表 `character_card_asset`。
 *
 * 当前只存头像字段。后续如果要扩展更多大字段或媒体资源，可以继续放在这张表，
 * 不影响 `character_card` 主表的列表查询性能。
 */
@Entity('character_card_asset')
export class CharacterCardAssetEntity {
  /** 资源记录主键，自增整数。新建实体使用 undefined，让数据库分配 ID。 */
  @Id({ autoincrement: true })
  @Columns({ columnName: 'id', types: ColumnType.num })
  id?: number;

  /** 关联的角色卡 ID，对应 `character_card.id`。唯一约束保证一张角色卡只有一条资源记录。 */
  @NotNull()
  @Unique()
  @Index(true)
  @Columns({ columnName: 'card_id', types: ColumnType.num })
  cardId: number = 0;

  /** 角色头像数据或路径。目前保存编辑页选择图片后得到的 base64 字符串。 */
  @Columns({ columnName: 'avatar_url', types: ColumnType.str })
  avatarUrl: string = '';

  constructor(id?: number, cardId?: number, avatarUrl?: string) {
    this.id = id;
    this.cardId = cardId ?? 0;
    this.avatarUrl = avatarUrl ?? '';
  }
}
