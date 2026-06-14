import { LogUtil, ToastUtil } from '@pura/harmony-utils'
import { RVRouter } from 'router'
import { ModelProviderEditState } from './ModelProviderEditState'
import { ZRouter } from '@hzw/zrouter'
import { OpenAI, type ModelListResponse, type ModelObject } from 'openai_ohos'
import type {
  ConnectionHeaderRecord,
  ConnectionProfileCreateParams,
  ConnectionProfileRecord,
  ConnectionResolvedProfile,
} from 'tavern_ohos'
import { TavernRuntimeContainer } from '../../tavern/TavernRuntimeContainer'

export class ModelProviderEditViewModel {
  private static readonly API_TYPE_OPENAI_COMPATIBLE: string = 'openai-compatible'
  private static readonly MODEL_LIST_HEADER: string = 'x-tavern-model-list'
  private static nextId: number = 1

  private state: ModelProviderEditState
  private runtime: TavernRuntimeContainer = TavernRuntimeContainer.getInstance()

  constructor(state: ModelProviderEditState) {
    this.state = state
    const param = ZRouter.getInstance().getParam() as ConnectionProfileRecord | undefined;
    if (param) {
      this.initFromParam(param);
    }
  }

  private initFromParam(param: ConnectionProfileRecord): void {
    if (param.id.length > 0) {
      this.runtime.loadConnections().then(() => {
        const provider = this.runtime.connections.getProfile(param.id)
        this.applyProvider(provider)
      })
    } else {
      this.applyProvider(param)
    }
  }

  onGetModel(): void {
    const secretRef = this.state.secretRef;
    const serverUrl = this.state.serverUrl;
    const client = new OpenAI({
      apiKey: secretRef,
      baseURL: serverUrl,
    })
    client.models.list()
      .then((response: ModelListResponse) => {
        const models = new Array<string>()
        for (let index = 0; index < response.data.length; index += 1) {
          const model: ModelObject = response.data[index]
          if (!ModelProviderEditViewModel.containsModel(models, model.id)) {
            models.push(model.id)
          }
        }
        this.state.modelList = models
      })
      .catch((e: Error) => {
        LogUtil.setDomain()
        LogUtil.debug('ModelProviderEditViewModel', 'onGetModel', '获取模型列表失败', e.message)
        ToastUtil.showToast($r("app.string.get_model_failed"));
      })
  }

  onAddModel(value: string): boolean {
    const modelId = value.trim()
    if (modelId.length === 0 || ModelProviderEditViewModel.containsModel(this.state.modelList, modelId)) {
      return false
    }
    const models = this.state.modelList.slice()
    models.push(modelId)
    this.state.modelList = models
    return true
  }

  onDeleteModel(item: string): void {
    const models = new Array<string>()
    for (let index = 0; index < this.state.modelList.length; index += 1) {
      if (this.state.modelList[index] !== item) {
        models.push(this.state.modelList[index])
      }
    }
    this.state.modelList = models
  }

  onSave(): boolean {
    if (this.state.name.trim() === '') {
      ToastUtil.showToast($r("app.string.provider_name_placeholder"));
      return false;
    }
    if (this.state.serverUrl.trim() === '') {
      ToastUtil.showToast($r("app.string.base_url_placeholder"));
      return false;
    }
    if (this.state.secretRef.trim() === '') {
      ToastUtil.showToast($r("app.string.api_key_placeholder"));
      return false;
    }
    if (this.state.modelList.length === 0) {
      ToastUtil.showToast($r("app.string.model_list_empty"));
      return false;
    }
    this.saveProvider().then(() => {
      RVRouter.pop(true)
    }).catch((error: Error) => {
      LogUtil.setDomain()
      LogUtil.debug('ModelProviderEditViewModel', 'onSave', '保存模型提供商失败', error.message)
      ToastUtil.showToast($r("app.string.model_provider_save_failed"));
    })
    return true;
  }

  private async saveProvider(): Promise<void> {
    const state = this.state;
    await this.runtime.loadConnections()
    const firstProvider = this.runtime.connections.listProfiles('').length === 0
    const profileId = state.id.length > 0 ? state.id : ModelProviderEditViewModel.createProfileId()
    const params: ConnectionProfileCreateParams = {
      id: profileId,
      name: state.name.trim(),
      apiType: ModelProviderEditViewModel.API_TYPE_OPENAI_COMPATIBLE,
      model: state.modelList[0],
      serverUrl: state.serverUrl.trim(),
      secretRef: state.secretRef.trim(),
      generationPresetId: '',
      systemPromptPresetId: '',
      contextTemplateId: '',
      instructTemplateId: '',
      tokenizer: 'provider',
      stopStrings: new Array<string>(),
      reasoningFormat: '',
      toolCallingEnabled: false,
      proxyUrl: '',
      additionalHeaders: ModelProviderEditViewModel.writeModelListHeader(state.modelList),
      enabled: true,
    }
    let saved: ConnectionProfileRecord
    if (state.id.length > 0) {
      saved = this.runtime.connections.updateProfile(state.id, params)
    } else {
      saved = this.runtime.connections.createProfile(params)
    }
    if (state.isDefault || firstProvider) {
      this.runtime.connections.setActiveProfile(
        TavernRuntimeContainer.DEFAULT_CONNECTION_SCOPE,
        TavernRuntimeContainer.DEFAULT_CONNECTION_SCOPE_ID,
        saved.id,
      )
    }
    await this.runtime.connections.saveToStore()
  }

  private applyProvider(provider: ConnectionProfileRecord): void {
    this.state.id = provider.id
    this.state.name = provider.name
    this.state.serverUrl = provider.serverUrl
    this.state.secretRef = provider.secretRef
    this.state.modelList = ModelProviderEditViewModel.readModelList(provider)
    this.state.isDefault = this.isDefaultProvider(provider.id)
  }

  private isDefaultProvider(profileId: string): boolean {
    try {
      const resolved: ConnectionResolvedProfile = this.runtime.connections.resolveActiveProfile(
        TavernRuntimeContainer.DEFAULT_CONNECTION_SCOPE,
        TavernRuntimeContainer.DEFAULT_CONNECTION_SCOPE_ID,
      )
      return resolved.profile.id === profileId
    } catch (error) {
      return false
    }
  }

  private static writeModelListHeader(models: Array<string>): Array<ConnectionHeaderRecord> {
    const normalized = ModelProviderEditViewModel.normalizeModelList(models)
    const headers = new Array<ConnectionHeaderRecord>()
    headers.push({
      name: ModelProviderEditViewModel.MODEL_LIST_HEADER,
      value: normalized.join('\n'),
      secret: false,
    })
    return headers
  }

  private static readModelList(profile: ConnectionProfileRecord): Array<string> {
    const result = new Array<string>()
    if (profile.model.trim().length > 0) {
      result.push(profile.model.trim())
    }
    const encoded = ModelProviderEditViewModel.findModelListHeader(profile.additionalHeaders)
    if (encoded.length > 0) {
      const lines = encoded.split('\n')
      for (let index = 0; index < lines.length; index += 1) {
        const modelId = lines[index].trim()
        if (modelId.length > 0 && !ModelProviderEditViewModel.containsModel(result, modelId)) {
          result.push(modelId)
        }
      }
    }
    return result
  }

  private static normalizeModelList(models: Array<string>): Array<string> {
    const result = new Array<string>()
    for (let index = 0; index < models.length; index += 1) {
      const modelId = models[index].trim()
      if (modelId.length > 0 && !ModelProviderEditViewModel.containsModel(result, modelId)) {
        result.push(modelId)
      }
    }
    return result
  }

  private static containsModel(models: Array<string>, modelId: string): boolean {
    for (let index = 0; index < models.length; index += 1) {
      if (models[index] === modelId) {
        return true
      }
    }
    return false
  }

  private static findModelListHeader(headers: Array<ConnectionHeaderRecord>): string {
    for (let index = 0; index < headers.length; index += 1) {
      if (headers[index].name === ModelProviderEditViewModel.MODEL_LIST_HEADER) {
        return headers[index].value
      }
    }
    return ''
  }

  private static createProfileId(): string {
    const id = `provider-${Date.now()}-${ModelProviderEditViewModel.nextId}`
    ModelProviderEditViewModel.nextId += 1
    return id
  }
}
