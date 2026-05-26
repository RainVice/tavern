import { distributedKVStore } from '@kit.ArkData';
import { AppUtil, JSONUtil } from '@pura/harmony-utils';
import { CharacterCard } from './model/CharacterCard';
import { util } from '@kit.ArkTS';

/**
 * 基于分布式KV数据库的角色卡存储
 *
 * 每个角色卡用 character_card_<id> 作为 key 单独存储
 */
class CharacterCardStore {
  private kvManager: distributedKVStore.KVManager;
  private storeId: string = 'character_card_store';
  private ready: Promise<distributedKVStore.SingleKVStore>;
  private static readonly PREFIX = 'character_card_';

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

  getAllCards(): Promise<CharacterCard[]> {
    return this.ready.then((store) => store.getEntries(CharacterCardStore.PREFIX).then((entries) => {
      const result: CharacterCard[] = [];
      entries.forEach((entry) => {
        const value = entry.value.value;
        if (typeof value !== 'string') {
          return;
        }
        const card = JSONUtil.jsonToBean<CharacterCard>(value);
        if (card) {
          result.push(card);
        }
      });
      return result;
    }));
  }

  getCard(id: string): Promise<CharacterCard | undefined> {
    return this.ready.then((store) =>
      store.get(id).then((data) => {
        if (typeof data !== 'string') {
          return undefined;
        }
        return JSONUtil.jsonToBean<CharacterCard>(data);
      })
    );
  }

  saveCard(card: CharacterCard): Promise<string> {
    return this.ready.then((store) => {
      if (!card.id) {
        card.id = CharacterCardStore.PREFIX + util.generateRandomUUID();
      }
      return store.put(card.id, JSONUtil.beanToJsonStr(card)).then(() => card.id);
    });
  }

  deleteCard(id: string): Promise<void> {
    return this.ready.then((store) => store.delete(id));
  }
}

/** 全局单例 */
export const characterCardStore = new CharacterCardStore();
