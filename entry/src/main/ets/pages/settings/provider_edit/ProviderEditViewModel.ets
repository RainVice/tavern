import { ToastUtil } from '@pura/harmony-utils';
import { OpenAI } from 'openai_ohos';
import { RVRouter } from 'router';
import { Provider, ProviderStore } from '../../../tavern/setting/provider/ProviderStore';
import { ProviderEditState } from './ProviderEditState';

export class ProviderEditViewModel {
  private readonly state: ProviderEditState

  constructor(state: ProviderEditState) {
    this.state = state;
  }

  init() {
    const param = RVRouter.getParam<Provider>()
    this.state.setParam(param)
  }

  onSaveClick(): void {
    const saved = ProviderStore.instance().setProvider({
      id: this.state.id,
      name: this.state.name,
      baseUrl: this.state.baseUrl,
      apiKey: this.state.key,
      model: this.state.modelName,
    })
    if (saved) {
      RVRouter.pop(saved)
    } else {
      ToastUtil.showToast($r("app.string.model_provider_save_failed"))
    }
  }

  onGetModelClick() {
    const openai = new OpenAI({
      baseURL: this.state.baseUrl,
      apiKey: this.state.key,
    })
    openai.models.list().then(response => {
      this.state.modelList = response.data
    })
  }
}