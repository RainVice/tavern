import { RVRouter, RouterName } from 'router'
import { modelProviderStore } from '../../store/ModelProviderStore'
import { ModelProvider } from '../../store/model/ModelProvider'
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
    RVRouter.push(RouterName.ModelProviderEdit, () => {
      this.loadProviders()
    })
  }

  onProviderClick(provider: ModelProvider): void {
    RVRouter.pushWithParam(RouterName.ModelProviderEdit, provider, () => {
      this.loadProviders()
    })
  }

  onDeleteProvider(provider: ModelProvider): void {
    modelProviderStore.deleteProvider(provider.id).then(() => {
      this.loadProviders()
    })
  }
}