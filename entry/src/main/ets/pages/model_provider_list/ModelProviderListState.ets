import { ModelProvider } from '../../store/model/ModelProvider'

@ObservedV2
export class ModelProviderListState {
  @Trace providers: ModelProvider[] = []
}