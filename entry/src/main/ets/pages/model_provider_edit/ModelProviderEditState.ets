import { ModelDefinition } from '../../store/model/ModelProvider'

@ObservedV2
export class ModelProviderEditState {
  @Trace id: number = 0
  @Trace name: string = ''
  @Trace apiKey: string = ''
  @Trace baseUrl: string = ''
  @Trace modelList: Array<ModelDefinition> = []

  isShowGetModel(): boolean {
    return this.apiKey !== '' && this.baseUrl !== ''
  }
}
