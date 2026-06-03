import { DBManger } from '../DBManger';
import { CharacterCard, CharacterCardEntity } from '../entity/CharacterCardEntity';
import { systemDateTime } from '@kit.BasicServicesKit';
import { ObjectUtil } from '@pura/harmony-utils';

class CharacterCardDB {
  private readonly dao = DBManger.getCharacterCardDao()

  public async queryAll(): Promise<CharacterCardEntity[]> {
    const dao = await this.dao;
    return dao.queryAll();
  }

  public async save(model: CharacterCard): Promise<number | undefined> {
    // 检查表中是否有这个 model
    const existModel = await this.queryById(model.id)
    // 不存在才插入
    if (existModel) {
      await this.update(model)
      return model.id
    } else {
      return await this.insert(model)
    }
  }

  public async queryById(id: number | undefined): Promise<CharacterCardEntity | undefined> {
    if (id == undefined) {
      return undefined
    }
    const dao = await this.dao;
    const condition = dao.getProperty(CharacterCardEntity.id_name).equalTo(id)
    const predicates = dao.predicatesBuilder().where(condition).build()
    return predicates.run().then((result) => result[0])
  }

  public async insert(model: CharacterCard): Promise<number> {
    const dao = await this.dao;
    const newModel: Object = ObjectUtil.assign(model, { updateTime: systemDateTime.getTime() } as CharacterCard);
    const entity = ObjectUtil.plainToClass(CharacterCardEntity, newModel)
    const id = await dao.insert(entity);
    dao.commit()
    return id
  }

  public async update(model: CharacterCard): Promise<number> {
    const dao = await this.dao;
    const newModel: Object = ObjectUtil.assign(model, { updateTime: systemDateTime.getTime() } as CharacterCard);
    const entity = ObjectUtil.plainToClass(CharacterCardEntity, newModel)
    const count = dao.update(entity)
    dao.commit()
    return count
  }

  public async delete(model: CharacterCard): Promise<number> {
    const dao = await this.dao;
    const entity = ObjectUtil.plainToClass(CharacterCardEntity, model)
    const count = dao.delete(entity)
    dao.commit()
    return count
  }
}

export const CharacterCardDao = new CharacterCardDB()