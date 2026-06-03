import { distributedKVStore } from '@kit.ArkData';
import { AppUtil } from '@pura/harmony-utils';
import { ModelProviderDao } from '../db/dao/ModelProviderDao';

class AppConfigStore {
  private static readonly STORE_ID: string = 'app_config';
  // 默认提供商 id
  private static readonly key_default_provider_id: string = 'default_provider_id';
  private store: Promise<distributedKVStore.SingleKVStore> = this.openStore()

  async getDefaultProviderId(): Promise<number | undefined> {
    const store = await this.store;
    const value = await store.get(AppConfigStore.key_default_provider_id);
    if (typeof value == "number") {
      const model = await ModelProviderDao.queryById(value)
      if (model) {
        return model.id
      }
    }
    const model = await ModelProviderDao.queryFirst();
    return model?.id;
  }

  async setDefaultProviderId(id: number | undefined): Promise<void> {
    if (id == undefined) {
      return
    }
    const store = await this.store;
    await store.put(AppConfigStore.key_default_provider_id, id);
  }

  private async openStore(): Promise<distributedKVStore.SingleKVStore> {
    const context = AppUtil.getContext();
    const config: distributedKVStore.KVManagerConfig = {
      bundleName: context.applicationInfo.name,
      context: context,
    };
    const options: distributedKVStore.Options = {
      createIfMissing: true,
      encrypt: true,
      backup: false,
      autoSync: false,
      kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
      securityLevel: distributedKVStore.SecurityLevel.S3,
    };
    const kvManager = distributedKVStore.createKVManager(config);
    return await kvManager.getKVStore<distributedKVStore.SingleKVStore>(AppConfigStore.STORE_ID, options);
  }
}

export const appConfigStore = new AppConfigStore();
