import { Provider, ProviderStore } from 'ets/tavern/setting/provider/ProviderStore';
import { ProviderEditPage } from '../provider_edit/ProviderEditPage';


@ObservedV2
export class ProviderListViewModel {
  @Trace providerList?: Provider[] = undefined

  init(): void {
    this.providerList = ProviderStore.instance().getProviderList()
  }

  onAddProviderList(): void {
    ProviderEditPage.start({ onPop: () => this.init() })
  }

  onProviderList(provider: Provider): void {
    ProviderEditPage.start({
      provider: provider, onPop: () => this.init()
    })
  }
}