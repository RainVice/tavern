import { BaseDao } from '@ohos/dataorm';
import {
  CharacterCard,
  CharacterCardAssetEntity,
  CharacterCardEntity,
  toCharacterCard,
  toCharacterCardEntity
} from './model/CharacterCard';
import { systemDateTime } from '@kit.BasicServicesKit';
import { tavernDatabase } from './TavernDatabase';

/**
 * 基于 dataorm 关系型数据库的角色卡存储
 */
class CharacterCardStore {
  private async getCardDao(): Promise<BaseDao<CharacterCardEntity, number>> {
    return tavernDatabase.getCharacterCardDao();
  }

  private async getAssetDao(): Promise<BaseDao<CharacterCardAssetEntity, number>> {
    return tavernDatabase.getCharacterCardAssetDao();
  }

  async getAllCards(): Promise<CharacterCard[]> {
    const cardDao = await this.getCardDao();
    const assetDao = await this.getAssetDao();
    const cards = await cardDao.loadAll();
    const assets = await assetDao.loadAll();
    return cards
      .sort((left, right) => right.updateTime - left.updateTime)
      .map((card) => toCharacterCard(card, assets.find((asset) => asset.cardId === card.id)));
  }

  async getCard(id: number): Promise<CharacterCard | undefined> {
    const cardId = id;
    if (!cardId) {
      return undefined;
    }
    const cardDao = await this.getCardDao();
    const assetDao = await this.getAssetDao();
    const card = await cardDao.load(cardId);
    if (!card) {
      return undefined;
    }
    const assets = await assetDao.loadAll();
    return toCharacterCard(card, assets.find((asset) => asset.cardId === cardId));
  }

  async saveCard(card: CharacterCard): Promise<number> {
    const cardDao = await this.getCardDao();
    const updateTime = systemDateTime.getTime();
    const entity = toCharacterCardEntity(card, updateTime);
    if (entity.id) {
      const oldCard = await cardDao.load(entity.id);
      if (oldCard) {
        await cardDao.updateAsync(entity);
      } else {
        await cardDao.insert(entity);
      }
    } else {
      await cardDao.insert(entity);
    }
    await this.saveAsset(entity.id ?? 0, card.avatarUrl ?? '');
    return entity.id ?? 0;
  }

  async deleteCard(id: number): Promise<void> {
    const cardId = id;
    if (!cardId) {
      return;
    }
    const cardDao = await this.getCardDao();
    const assetDao = await this.getAssetDao();
    const assets = await assetDao.loadAll();
    const asset = assets.find((item) => item.cardId === cardId);
    if (asset?.id) {
      await assetDao.deleteByKeyAsync(asset.id);
    }
    await cardDao.deleteByKeyAsync(cardId);
  }

  private async saveAsset(cardId: number, avatarUrl: string): Promise<void> {
    const assetDao = await this.getAssetDao();
    const oldAsset = (await assetDao.loadAll()).find((asset) => asset.cardId === cardId);
    if (!avatarUrl) {
      if (oldAsset?.id) {
        await assetDao.deleteByKeyAsync(oldAsset.id);
      }
      return;
    }
    const asset = new CharacterCardAssetEntity(oldAsset?.id ?? undefined, cardId, avatarUrl);
    if (oldAsset?.id) {
      await assetDao.updateAsync(asset);
    } else {
      await assetDao.insert(asset);
    }
  }
}

/** 全局单例 */
export const characterCardStore = new CharacterCardStore();
