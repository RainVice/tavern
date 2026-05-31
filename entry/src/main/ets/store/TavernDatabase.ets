import { AppUtil } from '@pura/harmony-utils';
import { BaseDao, DaoMaster, DaoSession, Database, OpenHelper } from '@ohos/dataorm';
import { CharacterCardAssetEntity, CharacterCardEntity } from './model/CharacterCard';
import { ConversationEntity, ConversationMessageEntity, ConversationParticipantEntity } from './model/Conversation';
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
    helper.setEntities(CharacterCardEntity, CharacterCardAssetEntity, ModelProviderEntity, ModelDefinitionEntity,
      ConversationEntity, ConversationParticipantEntity, ConversationMessageEntity);
    const db: Database = await helper.getWritableDb();
    return new DaoMaster(db).newSession();
  }

  private async getDao<T, K>(entityName: string): Promise<BaseDao<T, K>> {
    const session = await this.ready;
    return session.getDao(entityName) as BaseDao<T, K>;
  }

  getCharacterCardDao(): Promise<BaseDao<CharacterCardEntity, number>> {
    return this.getDao<CharacterCardEntity, number>('CharacterCardEntity');
  }

  getCharacterCardAssetDao(): Promise<BaseDao<CharacterCardAssetEntity, number>> {
    return this.getDao<CharacterCardAssetEntity, number>('CharacterCardAssetEntity');
  }

  getModelProviderDao(): Promise<BaseDao<ModelProviderEntity, number>> {
    return this.getDao<ModelProviderEntity, number>('ModelProviderEntity');
  }

  getModelDefinitionDao(): Promise<BaseDao<ModelDefinitionEntity, number>> {
    return this.getDao<ModelDefinitionEntity, number>('ModelDefinitionEntity');
  }

  getConversationDao(): Promise<BaseDao<ConversationEntity, number>> {
    return this.getDao<ConversationEntity, number>('ConversationEntity');
  }

  getConversationParticipantDao(): Promise<BaseDao<ConversationParticipantEntity, number>> {
    return this.getDao<ConversationParticipantEntity, number>('ConversationParticipantEntity');
  }

  getConversationMessageDao(): Promise<BaseDao<ConversationMessageEntity, number>> {
    return this.getDao<ConversationMessageEntity, number>('ConversationMessageEntity');
  }
}

export const tavernDatabase = new TavernDatabase();
