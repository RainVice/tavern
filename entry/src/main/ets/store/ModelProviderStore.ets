import { BaseDao } from '@ohos/dataorm';
import {
  ModelDefinitionEntity,
  ModelProvider,
  ModelProviderEntity,
  toModelProvider,
  toModelProviderEntity
} from './model/ModelProvider';
import { systemDateTime } from '@kit.BasicServicesKit';
import { tavernDatabase } from './TavernDatabase';

/**
 * 基于 dataorm 关系型数据库的模型提供商存储
 */
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
      .map((provider) => toModelProvider(provider, definitions));
  }

  async getProvider(id: number): Promise<ModelProvider | undefined> {
    const providerId = id;
    if (!providerId) {
      return undefined;
    }
    const providerDao = await this.getProviderDao();
    const definitionDao = await this.getDefinitionDao();
    const provider = await providerDao.load(providerId);
    if (!provider) {
      return undefined;
    }
    const definitions = (await definitionDao.loadAll()).filter((definition) => definition.providerId === providerId);
    return toModelProvider(provider, definitions);
  }

  async saveProvider(provider: ModelProvider): Promise<number> {
    const providerDao = await this.getProviderDao();
    const updateTime = systemDateTime.getTime();
    const entity = toModelProviderEntity(provider, updateTime);
    if (entity.id) {
      const oldProvider = await providerDao.load(entity.id);
      if (oldProvider) {
        await providerDao.updateAsync(entity);
      } else {
        await providerDao.insert(entity);
      }
    } else {
      await providerDao.insert(entity);
    }
    await this.replaceDefinitions(entity.id ?? 0, provider.modelDefinitions.map((definition) => definition.modelId));
    return entity.id ?? 0;
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
    const oldDefinitions = (await definitionDao.loadAll()).filter((definition) => definition.providerId === providerId);
    for (const definition of oldDefinitions) {
      if (definition.id) {
        await definitionDao.deleteByKeyAsync(definition.id);
      }
    }
    for (let index = 0; index < modelIds.length; index++) {
      await definitionDao.insert(new ModelDefinitionEntity(undefined, providerId, modelIds[index]));
    }
  }
}

/** 全局单例 */
export const modelProviderStore = new ModelProviderStore();
