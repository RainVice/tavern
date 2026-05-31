import { AppUtil } from '@pura/harmony-utils';
import { BaseDao, DaoMaster, DaoSession, Database, OpenHelper } from '@ohos/dataorm';
import { CharacterCardAssetEntity, CharacterCardEntity } from './model/CharacterCard';
import { ModelDefinitionEntity, ModelProviderEntity } from './model/ModelProvider';
import { common } from '@kit.AbilityKit';

class TavernOpenHelper extends OpenHelper {
  constructor(context: common.Context, name: string) {
    super(context, name);
  }
}

class TavernDatabase {
  private static readonly DB_NAME: string = 'tavern.db';
  private ready: Promise<DaoSession>;

  constructor() {
    this.ready = this.init();
  }

  private async init(): Promise<DaoSession> {
    const helper = new TavernOpenHelper(AppUtil.getContext(), TavernDatabase.DB_NAME);
    helper.setEntities(CharacterCardEntity, CharacterCardAssetEntity, ModelProviderEntity, ModelDefinitionEntity);
    const db: Database = await helper.getWritableDb();
    return new DaoMaster(db).newSession();
  }

  private async getDao<T>(entityName: string): Promise<BaseDao<T, number>> {
    const session = await this.ready;
    return session.getDao(entityName) as BaseDao<T, number>;
  }

  getCharacterCardDao(): Promise<BaseDao<CharacterCardEntity, number>> {
    return this.getDao<CharacterCardEntity>('CharacterCardEntity');
  }

  getCharacterCardAssetDao(): Promise<BaseDao<CharacterCardAssetEntity, number>> {
    return this.getDao<CharacterCardAssetEntity>('CharacterCardAssetEntity');
  }

  getModelProviderDao(): Promise<BaseDao<ModelProviderEntity, number>> {
    return this.getDao<ModelProviderEntity>('ModelProviderEntity');
  }

  getModelDefinitionDao(): Promise<BaseDao<ModelDefinitionEntity, number>> {
    return this.getDao<ModelDefinitionEntity>('ModelDefinitionEntity');
  }
}

export const tavernDatabase = new TavernDatabase();
