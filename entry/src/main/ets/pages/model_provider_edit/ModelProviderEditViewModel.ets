import { LogUtil, ToastUtil } from '@pura/harmony-utils'
import { OpenAI } from 'openai_ohos'
import { RVRouter } from 'router'
import { ModelDefinition } from '../../store/model/ModelProvider'
import { ModelProviderEditState } from './ModelProviderEditState'

export class ModelProviderEditViewModel {
  private state: ModelProviderEditState

  constructor(state: ModelProviderEditState) {
    this.state = state
  }

  onGetModel() {
    const openai = new OpenAI({
      apiKey: this.state.apiKey,
      baseURL: this.state.baseUrl,
    })
    openai.models.list()
      .then(res => {
        const models = res.data.map(model => ({ modelId: model.id } as ModelDefinition))
        this.state.modelList = models
      })
      .catch((e: Error) => {
        LogUtil.setDomain()
        LogUtil.debug('ModelProviderEditViewModel', 'onGetModel', '获取模型列表失败', e.message)
        ToastUtil.showToast('获取模型列表失败')
      })
  }

  onAddModel(value: string): boolean {
    if (this.state.modelList.some(model => model.modelId == value) || value.trim() == '') {
      return false
    }
    return !!this.state.modelList.push({ modelId: value })
  }

  onDeleteModel(item: ModelDefinition): void {
    this.state.modelList = this.state.modelList.filter(model => model !== item)
  }

  onSave() {
    RVRouter.getNavStack().pop()
  }
}
