import { ModelDefinition } from "../../db/entity/ModelProviderEntity"

@ObservedV2
export class ModelProviderEditState {
  @Trace id?: number = undefined
  @Trace name: string = ''
  @Trace apiKey: string = ''
  @Trace baseUrl: string = ''
  @Trace modelList: Array<ModelDefinition> = []
  @Trace isDefault: boolean = false

  isShowGetModel(): boolean {
    return this.apiKey !== '' && this.baseUrl !== ''
  }
}
