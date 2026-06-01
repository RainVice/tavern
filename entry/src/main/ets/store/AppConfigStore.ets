import { distributedKVStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppUtil } from '@pura/harmony-utils';
import { ModelProvider } from './model/ModelProvider';
import { modelProviderStore } from './ModelProviderStore';

class AppConfigStore {
  private static readonly STORE_ID: string = 'app_config';
  private static readonly key_default_provider_id: string = 'default_provider_id';
  private kvStoreReady?: Promise<distributedKVStore.SingleKVStore>;

  async getDefaultProvider(): Promise<ModelProvider | undefined> {
    const store = await this.getStore();
    const data = await store.get(AppConfigStore.key_default_provider_id);
    if (typeof data === 'number') {
      return await modelProviderStore.getProvider(data);
    }
    return modelProviderStore.getFirstProvider();
  }

  async saveDefaultProvider(provider: ModelProvider): Promise<void> {
    const store = await this.getStore();
    return await store.put(AppConfigStore.key_default_provider_id, provider.id)
  }

  private getStore(): Promise<distributedKVStore.SingleKVStore> {
    if (!this.kvStoreReady) {
      // 分支：首次访问配置存储，打开 KVStore 并缓存初始化 Promise。
      this.kvStoreReady = this.openStore();
    }
    // 分支：KVStore 已初始化或正在初始化，复用同一个 Promise。
    return this.kvStoreReady;
  }

  private openStore(): Promise<distributedKVStore.SingleKVStore> {
    return new Promise<distributedKVStore.SingleKVStore>((resolve, reject) => {
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
      try {
        const kvManager = distributedKVStore.createKVManager(config);
        kvManager.getKVStore<distributedKVStore.SingleKVStore>(AppConfigStore.STORE_ID, options,
          (err: BusinessError, store: distributedKVStore.SingleKVStore) => {
            if (err) {
              // 分支：打开 KVStore 失败，向上抛出具体错误信息。
              reject(new Error(err.message));
              return;
            }
            // 分支：KVStore 打开成功，后续读写复用该实例。
            resolve(store);
          });
      } catch (error) {
        // 分支：创建 KVManager 或打开 KVStore 同步抛错，统一转为 Error。
        reject(new Error('Failed to open app config store'));
      }
    });
  }
}

export const appConfigStore = new AppConfigStore();
