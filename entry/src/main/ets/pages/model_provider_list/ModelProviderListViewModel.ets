import type { ConnectionProfileRecord, ConnectionResolvedProfile } from 'tavern_ohos'
import { TavernRuntimeContainer } from '../../tavern/TavernRuntimeContainer'
import { ModelProviderEditPage } from '../model_provider_edit/ModelProviderEditPage'
import { ModelProviderListState } from './ModelProviderListState'

export class ModelProviderListViewModel {
  private state: ModelProviderListState
  private runtime: TavernRuntimeContainer = TavernRuntimeContainer.getInstance()

  constructor(state: ModelProviderListState) {
    this.state = state
    this.loadProviders()
  }

  loadProviders(): void {
    this.runtime.loadConnections().then(() => {
      const list = this.runtime.connections.listProfiles('')
      list.sort((left: ConnectionProfileRecord, right: ConnectionProfileRecord) => right.updatedAt - left.updatedAt)
      this.state.providers = list
      this.state.defaultProviderId = this.resolveDefaultProviderId()
    })
  }

  onAdd(): void {
    ModelProviderEditPage.start(() => {
      this.loadProviders()
    })
  }

  onProviderClick(provider: ConnectionProfileRecord): void {
    ModelProviderEditPage.startWithParam(provider, () => {
      this.loadProviders()
    })
  }

  onDeleteProvider(provider: ConnectionProfileRecord): void {
    this.runtime.loadConnections().then(() => {
      this.runtime.connections.deleteProfile(provider.id)
      return this.runtime.connections.saveToStore()
    }).then(() => {
      this.loadProviders()
    })
  }

  private resolveDefaultProviderId(): string {
    try {
      const resolved: ConnectionResolvedProfile = this.runtime.connections.resolveActiveProfile(
        TavernRuntimeContainer.DEFAULT_CONNECTION_SCOPE,
        TavernRuntimeContainer.DEFAULT_CONNECTION_SCOPE_ID,
      )
      return resolved.profile.id
    } catch (error) {
      return ''
    }
  }
}
