import { JSONUtil, RandomUtil, StrUtil } from '@pura/harmony-utils'
import { BaseStore } from '../../base/BaseFile'

export class ProviderStore extends BaseStore.BaseFile {
  private static _instance?: ProviderStore
  protected readonly dirname = "setting/provider"
  protected readonly filename = "provider.jsonl"
  private providerList: Provider[] | undefined = undefined

  static instance() {
    return ProviderStore._instance ??= new ProviderStore()
  }

  /**
   * 获取供应商列表
   * @returns 供应商列表
   */
  getProviderList() {
    if (this.providerList) {
      return this.providerList
    }
    const text = this.readText()?.split("\n")
    const providerList = text?.map((line) => JSONUtil.jsonToBean(line, Provider) as Provider)
      .filter((provider) => !!provider)
    return this.providerList = providerList
  }

  setProvider(value: Provider) {
    const provider = this.providerList?.find((provider) => provider.id == value.id)
    if (provider) {
      provider.name = value.name
      provider.baseUrl = value.baseUrl
      provider.apiKey = value.apiKey
      provider.model = value.model
    } else {
      if (StrUtil.isBlank(value.id)) {
        value.id = RandomUtil.generateRandomUUID()
      }
      this.providerList?.push(value)
    }
    const text = this.providerList?.map((provider) => JSONUtil.beanToJsonStr(provider)).join("\n")
    if (text) {
      this.writeText(text)
    }
  }
}

export class Provider {
  id?: string
  name?: string
  baseUrl?: string
  apiKey?: string
  model?: string
}