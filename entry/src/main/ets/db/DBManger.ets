import { AppUtil, LogUtil } from '@pura/harmony-utils';
import { ILog, Rdb, RdbDao, RdbDatabase } from 'rdbstore';
import { CharacterCardEntity } from './entity/CharacterCardEntity';
import { ConversationEntity } from './entity/ConversationEntity';
import { ConversationMessageEntity } from './entity/ConversationMessageEntity';
import { ModelProviderEntity } from './entity/ModelProviderEntity';
import { relationalStore } from '@kit.ArkData';

class Logger implements ILog {
  d(tag: string, message: string): void {
    LogUtil.debug(tag, message);
  }

  i(tag: string, message: string): void {
    LogUtil.info(tag, message);
  }

  w(tag: string, message: string): void {
    LogUtil.warn(tag, message);
  }

  e(tag: string, message: string): void {
    LogUtil.error(tag, message);
  }
}

export class DBManger {
  private static readonly instance: DBManger = new DBManger();
  private readonly db: RdbDatabase;

  private constructor() {
    this.db = this.dbBuilderInit();
  }

  private dbBuilderInit() {
    return Rdb.databaseBuilder(AppUtil.getContext(), {
      version: 1,
      dbName: "tavern.db",
      entities: [CharacterCardEntity, ConversationEntity, ConversationMessageEntity, ModelProviderEntity],
      migrations: [],
      encrypt: false,
      deprecatedFromVersion: 5,
      securityLevel: relationalStore.SecurityLevel.S1,
      autoMigrate: true
    })
      .setLogger(new Logger())
      .build()
  }

  static getCharacterCardDao(): Promise<RdbDao<CharacterCardEntity>> {
    return DBManger.instance.db.getDao(CharacterCardEntity);
  }

  static getConversationDao(): Promise<RdbDao<ConversationEntity>> {
    return DBManger.instance.db.getDao(ConversationEntity);
  }

  static getConversationMessageDao(): Promise<RdbDao<ConversationMessageEntity>> {
    return DBManger.instance.db.getDao(ConversationMessageEntity);
  }

  static getModelProviderDao(): Promise<RdbDao<ModelProviderEntity>> {
    return DBManger.instance.db.getDao(ModelProviderEntity)
      .then(res => {
        return res
      })
      .catch((err: Error) => {
        throw err;
      });
  }
}
