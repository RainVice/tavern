import { BaseDao, Property } from '@ohos/dataorm';
import {
  CharacterCard,
  CharacterCardAssetEntity,
  CharacterCardEntity,
} from './model/CharacterCard';
import { systemDateTime } from '@kit.BasicServicesKit';
import { tavernDatabase } from './TavernDatabase';

/**
 * 基于 dataorm 关系型数据库的角色卡存储
 */
class CharacterCardStore {
  private static readonly ASSET_CARD_ID: Property =
    new Property(1, 'number', 'cardId', false, 'card_id', false);

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
      .map((card) => CharacterCardEntity.toModel(card, assets.find((asset) => asset.cardId === card.id)));
  }

  async getCard(id: number): Promise<CharacterCard | undefined> {
    const cardId = id;
    if (!cardId) {
      return undefined;
    }
    const cardDao = await this.getCardDao();
    const card = await cardDao.load(cardId);
    if (!card) {
      return undefined;
    }
    return CharacterCardEntity.toModel(card, await this.getAsset(cardId));
  }

  async saveCard(card: CharacterCard): Promise<number> {
    const cardDao = await this.getCardDao();
    const updateTime = systemDateTime.getTime();
    const entity = CharacterCardEntity.fromModel(card, updateTime);
    let isNewCard = false;
    if (entity.id) {
      const oldCard = await cardDao.load(entity.id);
      if (oldCard) {
        await cardDao.updateAsync(entity);
      } else {
        await cardDao.insert(entity);
        isNewCard = true;
      }
    } else {
      await cardDao.insert(entity);
      isNewCard = true;
    }
    const cardId = entity.id ?? 0;
    this.assertSavedId(cardId, 'character card');
    try {
      await this.saveAsset(cardId, card.avatarUrl ?? '');
    } catch (e) {
      if (isNewCard) {
        await cardDao.deleteByKeyAsync(cardId);
      }
      throw new Error('Failed to save character card asset');
    }
    return cardId;
  }

  async deleteCard(id: number): Promise<void> {
    const cardId = id;
    if (!cardId) {
      return;
    }
    const cardDao = await this.getCardDao();
    const assetDao = await this.getAssetDao();
    const asset = await this.getAsset(cardId);
    if (asset?.id) {
      await assetDao.deleteByKeyAsync(asset.id);
    }
    await cardDao.deleteByKeyAsync(cardId);
  }

  private async saveAsset(cardId: number, avatarUrl: string): Promise<void> {
    const assetDao = await this.getAssetDao();
    const oldAsset = await this.getAsset(cardId);
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

  private async getAsset(cardId: number): Promise<CharacterCardAssetEntity | undefined> {
    const assetDao = await this.getAssetDao();
    const assets = await assetDao.queryBuilder()
      .where(CharacterCardStore.ASSET_CARD_ID.eq(cardId))
      .list();
    return assets.length > 0 ? assets[0] : undefined;
  }

  private assertSavedId(id: number, entityName: string): void {
    if (!id) {
      throw new Error('Failed to save ' + entityName);
    }
  }
}

/** 全局单例 */
export const characterCardStore = new CharacterCardStore();
