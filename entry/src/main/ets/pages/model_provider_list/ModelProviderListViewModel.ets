import { modelProviderStore } from '../../store/ModelProviderStore'
import { ModelProvider } from '../../store/model/ModelProvider'
import { ModelProviderEditPage } from '../model_provider_edit/ModelProviderEditPage'
import { ModelProviderListState } from './ModelProviderListState'

export class ModelProviderListViewModel {
  private state: ModelProviderListState

  constructor(state: ModelProviderListState) {
    this.state = state
    this.loadProviders()
  }

  loadProviders(): void {
    modelProviderStore.getAllProviders().then((list) => {
      this.state.providers = list
    })
  }

  onAdd(): void {
    ModelProviderEditPage.start(() => {
      this.loadProviders()
    })
  }

  onProviderClick(provider: ModelProvider): void {
    ModelProviderEditPage.startWithParam(provider, () => {
      this.loadProviders()
    })
  }

  onDeleteProvider(provider: ModelProvider): void {
    modelProviderStore.deleteProvider(provider.id).then(() => {
      this.loadProviders()
    })
  }
}
