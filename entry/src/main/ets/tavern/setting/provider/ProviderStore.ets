import { JSONUtil, ObjectUtil, RandomUtil, StrUtil } from '@pura/harmony-utils'
import { BaseStore } from '../../base/BaseStore'

export class ProviderStore extends BaseStore.File {
  private static _instance?: ProviderStore
  protected readonly dirname = "setting/provider"
  protected readonly filename = "provider.jsonl"

  static instance() {
    return ProviderStore._instance ??= new ProviderStore()
  }

  /**
   * 获取供应商列表
   * @returns 供应商列表
   */
  getProviderList() {
    const text = this.readText()?.split("\n")
    return text?.map((line) => JSONUtil.jsonToBean(line, Provider) as Provider)
      .filter((provider) => !!provider) ?? []
  }

  setProvider(value: Provider): Provider {
    value = ObjectUtil.plainToClass(Provider, value)
    const providerList = this.getProviderList()
    const provider = providerList.find((provider) => provider.id == value.id)
    if (provider) {
      provider.name = value.name
      provider.baseUrl = value.baseUrl
      provider.apiKey = value.apiKey
      provider.model = value.model
    } else {
      if (StrUtil.isBlank(value.id)) {
        value.id = RandomUtil.generateRandomUUID()
      }
      providerList.push(value)
    }
    const text = providerList.map((provider) => JSONUtil.beanToJsonStr(provider)).join("\n")
    if (text) {
      this.writeText(text)
    }
    return value
  }
}

export class Provider {
  id?: string
  name?: string
  baseUrl?: string
  apiKey?: string
  model?: string
}
