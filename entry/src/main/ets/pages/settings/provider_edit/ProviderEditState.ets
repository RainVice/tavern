import { ModelObject } from 'openai_ohos';
import { Provider } from '../../../tavern/setting/provider/ProviderStore';

@ObservedV2
export class ProviderEditState {
  @Trace id: string = '';
  @Trace name: string = '';
  @Trace baseUrl: string = '';
  @Trace key: string = '';
  @Trace modelName: string = '';
  @Trace modelList: ModelObject[] = [];

  setParam(param: Provider | undefined) {
    if (param) {
      this.id = param.id ?? "";
      this.name = param.name ?? "";
      this.baseUrl = param.baseUrl ?? "";
      this.key = param.apiKey ?? "";
      this.modelName = param.model ?? "";
    }
  }
}