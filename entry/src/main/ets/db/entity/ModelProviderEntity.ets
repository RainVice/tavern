import { JSONUtil, NestedClassV6 } from '@pura/harmony-utils';
import { Columns, ColumnType, Entity, PropertyConverter } from 'rdbstore';

class ModelDefinitionConvertor extends PropertyConverter<ModelDefinitionEntity[], string> {
  convertToEntityProperty(databaseValue: string): ModelDefinitionEntity[] {
    return JSONUtil.jsonToArray(databaseValue, ModelDefinitionEntity) ?? []
  }

  convertToDatabaseValue(entityProperty: ModelDefinitionEntity[]): string {
    return JSONUtil.beanToJsonStr(entityProperty)
  }
}

/**
 * 页面和业务层使用的模型定义。
 */
export class ModelDefinitionEntity implements ModelDefinition {
  /** 模型 ID，例如服务端返回的 `gpt-4.1`、`qwen-plus` 等标识。 */
  readonly modelId?: string;
}

/**
 * IMUserDBEntity
 */
@Entity({ tableName: ModelProviderEntity.tableName })
export class ModelProviderEntity implements ModelProvider {
  private static readonly tableName: string = 'ModelProviderEntity';
  /** 提供商业务 ID，保存后由数据库自增主键回填。新建时为 0。 */
  @Columns({
    name: ModelProviderEntity.id_name,
    type: ColumnType.INTEGER,
    autoincrement: true,
    isPrimaryKey: true,
    unique: true,
    notNull: true,
  })
  readonly id?: number = undefined;
  static readonly id_name = 'id';
  /** 提供商名称，用于列表和编辑页展示。 */
  @Columns({ name: ModelProviderEntity.name_name, type: ColumnType.TEXT })
  readonly name?: string = undefined;
  static readonly name_name: string = 'name';
  /** 最近更新时间，毫秒时间戳。用于列表按最近编辑时间倒序展示。 */
  @Columns({ name: ModelProviderEntity.updateTime_name, type: ColumnType.INTEGER })
  readonly updateTime?: number = undefined;
  static readonly updateTime_name: string = 'updateTime';
  /** OpenAI 兼容接口的 Base URL。 */
  @Columns({ name: ModelProviderEntity.baseUrl_name, type: ColumnType.TEXT })
  readonly baseUrl?: string = undefined;
  static readonly baseUrl_name: string = 'baseUrl';
  /** 调用模型服务使用的 API Key。 */
  @Columns({ name: ModelProviderEntity.apiKey_name, type: ColumnType.TEXT })
  readonly apiKey?: string = undefined;
  static readonly apiKey_name: string = 'apiKey';
  /** 该提供商下可选模型列表，关系库中一条模型对应 `model_definition` 的一行。 */
  @Columns({
    name: ModelProviderEntity.modelDefinitions_name,
    type: ColumnType.TEXT,
    convertor: ModelDefinitionConvertor
  })
  @NestedClassV6(ModelDefinitionEntity)
  readonly modelDefinitions?: ModelDefinitionEntity[] = undefined;
  static readonly modelDefinitions_name: string = 'modelDefinitions';
}

export interface ModelProvider {
  readonly id?: number;
  readonly name?: string;
  readonly updateTime?: number;
  readonly baseUrl?: string;
  readonly apiKey?: string;
  readonly modelDefinitions?: ModelDefinition[];
}

export interface ModelDefinition {
  readonly modelId?: string;
}
