import { DBManger } from '../DBManger';
import { ModelProvider, ModelProviderEntity } from '../entity/ModelProviderEntity';
import { systemDateTime } from '@kit.BasicServicesKit';
import { ObjectUtil } from '@pura/harmony-utils';

class ModelProviderDB {
  private readonly dao = DBManger.getModelProviderDao()

  public async queryAll() {
    const dao = await this.dao
    return dao.queryAll()
  }

  /**
   * 查询第一条数据
   */
  public async queryFirst(): Promise<ModelProviderEntity | undefined> {
    const dao = await this.dao
    const condition = dao.predicatesBuilder().limit(1).build()
    return condition.run().then((result) => result[0])
  }

  /**
   * 保存
   * @param model
   * @returns id
   */
  public async save(model: ModelProvider): Promise<number | undefined> {
    const existModel = await this.queryById(model.id)
    if (existModel) {
      await this.update(model)
      return model.id
    } else {
      return await this.insert(model)
    }
  }

  public async queryById(id: number | undefined): Promise<ModelProviderEntity | undefined> {
    if (id === undefined) {
      return undefined
    }
    const dao = await this.dao
    const condition = dao.getProperty(ModelProviderEntity.id_name).equalTo(id)
    const predicates = dao.predicatesBuilder().where(condition).build()
    return predicates.run().then((result) => result[0])
  }

  public async insert(model: ModelProvider): Promise<number> {
    const dao = await this.dao
    const newModel = ObjectUtil.assign(model, { updateTime: systemDateTime.getTime() } as ModelProvider)
    const entity = ObjectUtil.plainToClass(ModelProviderEntity, newModel)
    const id = dao.insert(entity)
    dao.commit()
    return id
  }

  public async update(model: ModelProvider): Promise<number> {
    const dao = await this.dao
    const newModel = ObjectUtil.assign(model, { updateTime: systemDateTime.getTime() } as ModelProvider)
    const entity = ObjectUtil.plainToClass(ModelProviderEntity, newModel)
    const count = dao.update(entity)
    dao.commit()
    return count
  }

  public async delete(model: ModelProvider): Promise<number> {
    const dao = await this.dao
    const entity = ObjectUtil.plainToClass(ModelProviderEntity, model)
    const count =  dao.delete(entity)
    dao.commit()
    return count
  }
}

export const ModelProviderDao = new ModelProviderDB()