import { LogUtil, ToastUtil } from '@pura/harmony-utils'
import { OpenAI } from 'openai_ohos'
import { RVRouter } from 'router'
import { ModelProviderEditState } from './ModelProviderEditState'
import { ZRouter } from '@hzw/zrouter'
import { ModelDefinition, ModelProvider } from '../../db/entity/ModelProviderEntity'
import { ModelProviderDao } from '../../db/dao/ModelProviderDao'
import { appConfigStore } from '../../store/AppConfigStore'

export class ModelProviderEditViewModel {
  private state: ModelProviderEditState

  constructor(state: ModelProviderEditState) {
    this.state = state
    const param = ZRouter.getInstance().getParam() as ModelProvider | undefined;
    if (param) {
      this.initFromParam(param);
    }
    this.loadDefaultProviderId()
  }

  private initFromParam(param: ModelProvider): void {
    if (param.id) {
      this.state.id = param.id
      ModelProviderDao.queryById(param.id).then((provider) => {
        if (provider) {
          this.state.name = provider.name ?? ""
          this.state.baseUrl = provider.baseUrl ?? ""
          this.state.apiKey = provider.apiKey ?? ""
          this.state.modelList = provider.modelDefinitions ?? []
        }
      })
    } else {
      this.state.name = param.name ?? ""
      this.state.baseUrl = param.baseUrl ?? ""
      this.state.apiKey = param.apiKey ?? ""
      this.state.modelList = param.modelDefinitions ?? []
    }
  }

  onGetModel(): void {
    const apiKey = this.state.apiKey;
    const baseUrl = this.state.baseUrl;
    const openai = new OpenAI({
      apiKey: apiKey,
      baseURL: baseUrl,
    })
    openai.models.list()
      .then(res => {
        const models = res.data.map(model => ({ modelId: model.id } as ModelDefinition))
        this.state.modelList = models
      })
      .catch((e: Error) => {
        LogUtil.setDomain()
        LogUtil.debug('ModelProviderEditViewModel', 'onGetModel', '获取模型列表失败', e.message)
        ToastUtil.showToast($r("app.string.get_model_failed"));
      })
  }

  onAddModel(value: string): boolean {
    if (this.state.modelList.some(model => model.modelId === value) || value.trim() === '') {
      return false
    }
    return !!this.state.modelList.push({ modelId: value })
  }

  onDeleteModel(item: ModelDefinition): void {
    this.state.modelList = this.state.modelList.filter(model => model !== item)
  }

  async onSave(): Promise<boolean> {
    if (this.state.name.trim() === '') {
      ToastUtil.showToast($r("app.string.provider_name_placeholder"));
      return false;
    }
    if (this.state.baseUrl.trim() === '') {
      ToastUtil.showToast($r("app.string.base_url_placeholder"));
      return false;
    }
    if (this.state.apiKey.trim() === '') {
      ToastUtil.showToast($r("app.string.base_url_placeholder"));
      return false;
    }
    if (this.state.modelList.length === 0) {
      ToastUtil.showToast($r("app.string.model_list_empty"));
      return false;
    }
    const state = this.state;
    const provider: ModelProvider = {
      id: state.id,
      name: state.name.trim(),
      baseUrl: state.baseUrl.trim(),
      apiKey: state.apiKey.trim(),
      modelDefinitions: state.modelList,
    }
    const providerId = await ModelProviderDao.save(provider)
    if (this.state.isDefault) {
      await appConfigStore.setDefaultProviderId(providerId)
    }
    RVRouter.pop(true)
    return true;
  }

  private loadDefaultProviderId(): void {
    appConfigStore.getDefaultProviderId().then((providerId) => {
      this.state.isDefault = (this.state.id === providerId)
    })
  }
}
