import { BaseDao } from '@ohos/dataorm';
import {
  ModelDefinitionEntity, ModelProvider, ModelProviderEntity,
} from './model/ModelProvider';
import { systemDateTime } from '@kit.BasicServicesKit';
import { tavernDatabase } from './TavernDatabase';

class ModelProviderStore {
  private async getProviderDao(): Promise<BaseDao<ModelProviderEntity, number>> {
    return tavernDatabase.getModelProviderDao();
  }

  private async getDefinitionDao(): Promise<BaseDao<ModelDefinitionEntity, number>> {
    return tavernDatabase.getModelDefinitionDao();
  }

  async getAllProviders(): Promise<ModelProvider[]> {
    const providerDao = await this.getProviderDao();
    const definitionDao = await this.getDefinitionDao();
    const providers = await providerDao.loadAll();
    const definitions = await definitionDao.loadAll();
    return providers
      .sort((left, right) => right.updateTime - left.updateTime)
      .map((provider) => ModelProviderEntity.toModel(provider, definitions));
  }

  /**
   * 获取最近更新的第一个模型提供商。
   */
  async getFirstProvider(): Promise<ModelProvider | undefined> {
    const providerDao = await this.getProviderDao();
    const providers = await providerDao.queryBuilder()
      .orderDesc(ModelProviderEntity.UPDATE_TIME_PROPERTY)
      .limit(1)
      .list();
    if (providers.length === 0) {
      return undefined;
    }
    const provider = providers[0];
    const providerId = provider.id;
    if (!providerId) {
      return undefined;
    }
    return ModelProviderEntity.toModel(providers[0], await this.getDefinitions(providerId));
  }

  /**
   * 按主键 ID 获取单个模型提供商。
   *
   * 如果 id 无效或数据库中没有对应记录，返回 `undefined`。
   */
  async getProvider(id: number): Promise<ModelProvider | undefined> {
    const providerId = id;
    if (!providerId) {
      return undefined;
    }
    const providerDao = await this.getProviderDao();
    const provider = await providerDao.load(providerId);
    if (!provider) {
      return undefined;
    }
    return ModelProviderEntity.toModel(provider, await this.getDefinitions(providerId));
  }

  /**
   * 新增或更新模型提供商。
   *
   * 主表保存提供商名称、接口地址、密钥和更新时间；模型列表由
   * `replaceDefinitions()` 同步到 `model_definition`。如果新建 provider
   * 后模型明细保存失败，会删除刚插入的主表记录，避免留下孤立提供商。
   */
  async saveProvider(provider: ModelProvider): Promise<number> {
    const providerDao = await this.getProviderDao();
    const updateTime = systemDateTime.getTime();
    const entity = ModelProviderEntity.fromModel(provider, updateTime);
    let isNewProvider = false;
    if (entity.id) {
      const oldProvider = await providerDao.load(entity.id);
      if (oldProvider) {
        await providerDao.updateAsync(entity);
      } else {
        await providerDao.insert(entity);
        isNewProvider = true;
      }
    } else {
      await providerDao.insert(entity);
      isNewProvider = true;
    }
    const providerId = entity.id ?? 0;
    this.assertSavedId(providerId, 'model provider');
    try {
      await this.replaceDefinitions(providerId, provider.modelDefinitions.map((definition) => definition.modelId));
    } catch (e) {
      if (isNewProvider) {
        await providerDao.deleteByKeyAsync(providerId);
      }
      throw new Error('Failed to save model definitions');
    }
    return providerId;
  }

  /**
   * 删除模型提供商。
   *
   * 先清空该提供商关联的模型定义，再删除提供商主表记录，避免明细表残留。
   */
  async deleteProvider(id: number): Promise<void> {
    const providerId = id;
    if (!providerId) {
      return;
    }
    const providerDao = await this.getProviderDao();
    await this.replaceDefinitions(providerId, []);
    await providerDao.deleteByKeyAsync(providerId);
  }

  /**
   * 用新的模型 ID 列表替换某个提供商的全部模型定义。
   *
   * 已不存在的旧模型会删除；新出现的模型会插入；仍存在的模型保持不动。
   */
  private async replaceDefinitions(providerId: number, modelIds: string[]): Promise<void> {
    const definitionDao = await this.getDefinitionDao();
    const normalizedModelIds = this.normalizeModelIds(modelIds);
    const oldDefinitions = await this.getDefinitions(providerId);
    const definitionIdsToDelete: number[] = [];
    for (const definition of oldDefinitions) {
      if (definition.id && normalizedModelIds.indexOf(definition.modelId) < 0) {
        definitionIdsToDelete.push(definition.id);
      }
    }
    if (definitionIdsToDelete.length > 0) {
      await definitionDao.deleteByKeyInTxIterableAsync(definitionIdsToDelete);
    }
    const definitionsToInsert: ModelDefinitionEntity[] = [];
    for (let index = 0; index < normalizedModelIds.length; index++) {
      if (!this.hasDefinition(oldDefinitions, normalizedModelIds[index])) {
        definitionsToInsert.push(new ModelDefinitionEntity(undefined, providerId, normalizedModelIds[index]));
      }
    }
    if (definitionsToInsert.length > 0) {
      await definitionDao.insertInTxIterableAsync(definitionsToInsert);
    }
  }

  /** 查询某个提供商关联的全部模型定义实体。 */
  private async getDefinitions(providerId: number): Promise<ModelDefinitionEntity[]> {
    const definitionDao = await this.getDefinitionDao();
    return definitionDao.queryBuilder()
      .where(ModelDefinitionEntity.PROVIDER_ID_PROPERTY.eq(providerId))
      .list();
  }

  /**
   * 归一化模型 ID 列表。
   *
   * 空字符串会被过滤；重复模型 ID 只保留第一次出现的值。
   */
  private normalizeModelIds(modelIds: string[]): string[] {
    const normalized: string[] = [];
    for (const modelId of modelIds) {
      if (modelId && normalized.indexOf(modelId) < 0) {
        normalized.push(modelId);
      }
    }
    return normalized;
  }

  /** 判断旧模型定义中是否已经存在指定模型 ID。 */
  private hasDefinition(definitions: ModelDefinitionEntity[], modelId: string): boolean {
    for (const definition of definitions) {
      if (definition.modelId === modelId) {
        return true;
      }
    }
    return false;
  }

  /** 校验自增主键是否已由 dataorm 回填。 */
  private assertSavedId(id: number, entityName: string): void {
    if (!id) {
      throw new Error('Failed to save ' + entityName);
    }
  }
}

/** 全局单例 */
export const modelProviderStore = new ModelProviderStore();
