import { BaseDao, Property } from '@ohos/dataorm';
import {
  ModelDefinitionEntity,
  ModelProvider,
  ModelProviderEntity,
} from './model/ModelProvider';
import { systemDateTime } from '@kit.BasicServicesKit';
import { tavernDatabase } from './TavernDatabase';

/**
 * 基于 dataorm 关系型数据库的模型提供商存储
 */
class ModelProviderStore {
  private static readonly DEFINITION_PROVIDER_ID: Property =
    new Property(1, 'number', 'providerId', false, 'provider_id', false);

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

  async deleteProvider(id: number): Promise<void> {
    const providerId = id;
    if (!providerId) {
      return;
    }
    const providerDao = await this.getProviderDao();
    await this.replaceDefinitions(providerId, []);
    await providerDao.deleteByKeyAsync(providerId);
  }

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

  private async getDefinitions(providerId: number): Promise<ModelDefinitionEntity[]> {
    const definitionDao = await this.getDefinitionDao();
    return definitionDao.queryBuilder()
      .where(ModelProviderStore.DEFINITION_PROVIDER_ID.eq(providerId))
      .list();
  }

  private normalizeModelIds(modelIds: string[]): string[] {
    const normalized: string[] = [];
    for (const modelId of modelIds) {
      if (modelId && normalized.indexOf(modelId) < 0) {
        normalized.push(modelId);
      }
    }
    return normalized;
  }

  private hasDefinition(definitions: ModelDefinitionEntity[], modelId: string): boolean {
    for (const definition of definitions) {
      if (definition.modelId === modelId) {
        return true;
      }
    }
    return false;
  }

  private assertSavedId(id: number, entityName: string): void {
    if (!id) {
      throw new Error('Failed to save ' + entityName);
    }
  }
}

/** 全局单例 */
export const modelProviderStore = new ModelProviderStore();
