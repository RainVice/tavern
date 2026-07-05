import { Provider, ProviderStore } from 'ets/tavern/setting/provider/ProviderStore';


@ObservedV2
export class ProviderListViewModel {
  @Trace providerList?: Provider[] = undefined

  init() {
    this.providerList = ProviderStore.instance().getProviderList() ?? []
  }

  onAddProviderList():void {

  }

  onProviderList(provider: Provider): void {

  }
}