import { ModelProviderDao } from '../../db/dao/ModelProviderDao'
import { ModelProvider } from '../../db/entity/ModelProviderEntity'
import { ModelProviderEditPage } from '../model_provider_edit/ModelProviderEditPage'
import { ModelProviderListState } from './ModelProviderListState'

export class ModelProviderListViewModel {
  private state: ModelProviderListState

  constructor(state: ModelProviderListState) {
    this.state = state
    this.loadProviders()
  }

  loadProviders(): void {
    ModelProviderDao.queryAll().then((list) => {
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
    ModelProviderDao.delete(provider).then(() => {
      this.loadProviders()
    })
  }
}
