import { RVRouter, RouterName } from 'router'
import { modelProviderStore } from '../../store/ModelProviderStore'
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

  onProviderClick(index: number): void {
    const provider = this.state.providers[index]
    RVRouter.pushWithParam(RouterName.ModelProviderEdit, provider, () => {
      this.loadProviders()
    })
  }

  onDeleteProvider(index: number): void {
    const provider = this.state.providers[index]
    modelProviderStore.deleteProvider(provider.id).then(() => {
      this.loadProviders()
    })
  }
}
