import { ModelDefinition } from '../../store/model/ModelProvider'

@ObservedV2
export class ModelProviderEditState {
  @Trace providerName: string = ''
  @Trace apiKey: string = ''
  @Trace baseUrl: string = ''
  @Trace modelList: Array<ModelDefinition> = []

  isShowGetModel() {
    return this.apiKey && this.baseUrl
  }
}