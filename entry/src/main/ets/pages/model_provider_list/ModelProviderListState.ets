import type { ConnectionProfileRecord } from 'tavern_ohos';

@ObservedV2
export class ModelProviderListState {
  @Trace providers: Array<ConnectionProfileRecord> = []
  @Trace defaultProviderId: string = ''
}
