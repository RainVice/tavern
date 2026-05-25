import { distributedKVStore } from '@kit.ArkData';
import { AppUtil, JSONUtil } from '@pura/harmony-utils';
import { ModelProvider } from './model/ModelProvider';
import { util } from '@kit.ArkTS';

/**
 * 基于分布式KV数据库的模型提供商存储
 *
 * 每个 Provider 用 p_<id> 作为 key 单独存储，前缀确保 getEntries 正常工作
 */
class ModelProviderStore {
  private kvManager: distributedKVStore.KVManager;
  private storeId: string = 'model_provider_store';
  private ready: Promise<distributedKVStore.SingleKVStore>;
  private static readonly PREFIX = 'provider_';

  constructor() {
    const ctx = AppUtil.getContext();
    this.kvManager = distributedKVStore.createKVManager({
      bundleName: ctx.applicationInfo.name,
      context: ctx,
    });
    this.ready = this.initStore();
  }

  private initStore(): Promise<distributedKVStore.SingleKVStore> {
    const options: distributedKVStore.Options = {
      createIfMissing: true,
      encrypt: true,
      backup: true,
      autoSync: true,
      kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
      securityLevel: distributedKVStore.SecurityLevel.S4,
    };
    return this.kvManager.getKVStore<distributedKVStore.SingleKVStore>(this.storeId, options);
  }

  // ====== 异步方法 ======

  getAllProviders(): Promise<ModelProvider[]> {
    return this.ready.then((store) => store.getEntries(ModelProviderStore.PREFIX).then((entries) => {
      const result: ModelProvider[] = [];
      entries.forEach((entry) => {
        const value = entry.value.value;
        if (typeof value !== 'string') {
          return;
        }
        const provider = JSONUtil.jsonToBean<ModelProvider>(value);
        if (provider) {
          result.push(provider);
        }
      });
      return result;
    })).catch((e: Error) => {
      throw e
    })
  }

  getProvider(id: string): Promise<ModelProvider | undefined> {
    return this.ready.then((store) =>
    store.get(id).then((data) => {
      if (typeof data !== 'string') {
        return undefined;
      }
      return JSONUtil.jsonToBean<ModelProvider>(data);
    })
    );
  }

  saveProvider(provider: ModelProvider): Promise<string> {
    return this.ready.then((store) => {
      if (!provider.id) {
        provider.id = ModelProviderStore.PREFIX + util.generateRandomUUID();
      }
      return store.put(provider.id, JSONUtil.beanToJsonStr(provider)).then(() => provider.id);
    });
  }

  deleteProvider(id: string): Promise<void> {
    return this.ready.then((store) => store.delete(id));
  }

  // ====== 订阅与同步 ======

  onDataChange(callback: (data: distributedKVStore.ChangeNotification) => void): void {
    this.ready.then((store) => {
      store.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL, callback);
    });
  }

  offDataChange(callback?: (data: distributedKVStore.ChangeNotification) => void): void {
    this.ready.then((store) => {
      store.off('dataChange', callback);
    });
  }

  sync(deviceIds: string[], mode?: distributedKVStore.SyncMode): void {
    this.ready.then((store) => {
      store.sync(deviceIds, mode ?? distributedKVStore.SyncMode.PUSH_PULL);
    });
  }
}

/** 全局单例 */
export const modelProviderStore = new ModelProviderStore();
