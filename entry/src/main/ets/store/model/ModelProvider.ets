import { ColumnType, Columns, Entity, Id, Index, NotNull } from '@ohos/dataorm';

/**
 * 页面和业务层使用的模型提供商模型。
 *
 * 这个接口保持页面友好结构；数据库中会拆成：
 * - `model_provider` 保存提供商主信息。
 * - `model_definition` 保存该提供商可用模型列表。
 */
export interface ModelProvider {
  /** 提供商业务 ID，保存后由数据库自增主键回填。新建时为 0。 */
  id: number;

  /** 提供商名称，用于列表和编辑页展示。 */
  name: string;

  /** 最近更新时间，毫秒时间戳。用于列表按最近编辑时间倒序展示。 */
  updateTime?: number;

  /** OpenAI 兼容接口的 Base URL。 */
  baseUrl: string;

  /** 调用模型服务使用的 API Key。 */
  apiKey: string;

  /** 该提供商下可选模型列表，关系库中一条模型对应 `model_definition` 的一行。 */
  modelDefinitions: ModelDefinition[];
}

/**
 * 页面和业务层使用的模型定义。
 */
export interface ModelDefinition {
  /** 模型 ID，例如服务端返回的 `gpt-4.1`、`qwen-plus` 等标识。 */
  modelId: string;
}

/**
 * 模型提供商主表实体，对应表 `model_provider`。
 *
 * 只保存提供商级别字段；模型列表拆到 `model_definition`，避免把数组 JSON
 * 整包写入主表，也方便后续按 provider 查询、去重或扩展模型字段。
 */
@Entity('model_provider')
export class ModelProviderEntity {
  /** 主键，自增整数。新建实体使用 undefined，让数据库分配 ID，dataorm 插入后会回写该字段。 */
  @Id({ autoincrement: true })
  @Columns({ columnName: 'id', types: ColumnType.num })
  id?: number;

  /** 提供商名称。不能为空，并建立普通索引，便于后续按名称查找。 */
  @NotNull()
  @Index()
  @Columns({ columnName: 'name', types: ColumnType.str })
  name: string = '';

  /** 最近更新时间，毫秒时间戳。建立索引用于列表按更新时间倒序展示。 */
  @Index()
  @Columns({ columnName: 'update_time', types: ColumnType.num })
  updateTime: number = 0;

  /** OpenAI 兼容接口的 Base URL。不能为空。 */
  @NotNull()
  @Columns({ columnName: 'base_url', types: ColumnType.str })
  baseUrl: string = '';

  /** 调用模型服务使用的 API Key。不能为空。 */
  @NotNull()
  @Columns({ columnName: 'api_key', types: ColumnType.str })
  apiKey: string = '';

  constructor(id?: number, name?: string, updateTime?: number, baseUrl?: string, apiKey?: string) {
    this.id = id;
    this.name = name ?? '';
    this.updateTime = updateTime ?? 0;
    this.baseUrl = baseUrl ?? '';
    this.apiKey = apiKey ?? '';
  }
}

/**
 * 模型定义实体，对应表 `model_definition`。
 *
 * 一行代表某个提供商下的一个模型。`providerId + modelId` 有唯一复合索引，
 * 保证同一个提供商下面不会重复保存同一个模型 ID。
 */
@Entity('model_definition', [{ value: 'providerId, modelId', unique: true }])
export class ModelDefinitionEntity {
  /** 模型记录主键，自增整数。新建实体使用 undefined，让数据库分配 ID。 */
  @Id({ autoincrement: true })
  @Columns({ columnName: 'id', types: ColumnType.num })
  id?: number;

  /** 关联的提供商 ID，对应 `model_provider.id`。 */
  @NotNull()
  @Index()
  @Columns({ columnName: 'provider_id', types: ColumnType.num })
  providerId: number = 0;

  /** 模型 ID，例如服务端返回的模型标识。 */
  @NotNull()
  @Columns({ columnName: 'model_id', types: ColumnType.str })
  modelId: string = '';

  constructor(id?: number, providerId?: number, modelId?: string) {
    this.id = id;
    this.providerId = providerId ?? 0;
    this.modelId = modelId ?? '';
  }
}

/**
 * 将提供商主表实体和模型定义实体合并为页面/业务层模型。
 */
export function toModelProvider(entity: ModelProviderEntity, definitions: ModelDefinitionEntity[]): ModelProvider {
  const modelDefinitions = definitions
    .filter((definition) => definition.providerId === entity.id)
    .map((definition) => ({ modelId: definition.modelId } as ModelDefinition));
  return {
    id: entity.id ?? 0,
    name: entity.name,
    updateTime: entity.updateTime,
    baseUrl: entity.baseUrl,
    apiKey: entity.apiKey,
    modelDefinitions: modelDefinitions,
  };
}

/**
 * 将页面/业务层提供商模型转成提供商主表实体。
 *
 * `modelDefinitions` 不在这里处理，由 Store 单独写入 `model_definition`。
 */
export function toModelProviderEntity(provider: ModelProvider, updateTime: number): ModelProviderEntity {
  return new ModelProviderEntity(
    provider.id || undefined,
    provider.name,
    updateTime,
    provider.baseUrl,
    provider.apiKey,
  );
}
