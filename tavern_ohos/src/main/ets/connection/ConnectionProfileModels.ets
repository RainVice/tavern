import type {
  ConnectionApiType,
  ReasoningFormat,
  SecretRef,
  TavernScope,
  TokenizerStrategy,
} from '../contracts/PublicContracts';

/**
 * 描述连接配置持久化或内存索引中的一条记录。
 */
export interface ConnectionHeaderRecord {
  /**
   * 名称。
   */
  name: string;
  /**
   * 字段值。
   */
  value: string;
  /**
   * secret 值，由当前实例内部维护。
   */
  secret: boolean;
}

/**
 * 描述调用连接配置能力时需要传入的参数。
 */
export interface ConnectionProfileCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * api Type 值，由当前实例内部维护。
   */
  apiType: ConnectionApiType;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * 服务地址，由当前实例内部维护。
   */
  serverUrl: string;
  /**
   * 密钥引用，由当前实例内部维护。
   */
  secretRef: SecretRef;
  /**
   * generation Preset 标识。
   */
  generationPresetId: string;
  /**
   * system Prompt Preset 标识。
   */
  systemPromptPresetId: string;
  /**
   * context Template 标识。
   */
  contextTemplateId: string;
  /**
   * instruct Template 标识。
   */
  instructTemplateId: string;
  /**
   * tokenizer 值，由当前实例内部维护。
   */
  tokenizer: TokenizerStrategy;
  /**
   * stop Strings 列表，由当前实例内部维护。
   */
  stopStrings: Array<string>;
  /**
   * reasoning Format 值，由当前实例内部维护。
   */
  reasoningFormat: ReasoningFormat;
  /**
   * tool Calling Enabled 值，由当前实例内部维护。
   */
  toolCallingEnabled: boolean;
  /**
   * proxy Url 值，由当前实例内部维护。
   */
  proxyUrl: string;
  /**
   * additional Headers 列表，由当前实例内部维护。
   */
  additionalHeaders: Array<ConnectionHeaderRecord>;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
}

/**
 * 描述连接配置持久化或内存索引中的一条记录。
 */
export interface ConnectionProfileRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * api Type 值，由当前实例内部维护。
   */
  apiType: ConnectionApiType;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * 服务地址，由当前实例内部维护。
   */
  serverUrl: string;
  /**
   * 密钥引用，由当前实例内部维护。
   */
  secretRef: SecretRef;
  /**
   * generation Preset 标识。
   */
  generationPresetId: string;
  /**
   * system Prompt Preset 标识。
   */
  systemPromptPresetId: string;
  /**
   * context Template 标识。
   */
  contextTemplateId: string;
  /**
   * instruct Template 标识。
   */
  instructTemplateId: string;
  /**
   * tokenizer 值，由当前实例内部维护。
   */
  tokenizer: TokenizerStrategy;
  /**
   * stop Strings 列表，由当前实例内部维护。
   */
  stopStrings: Array<string>;
  /**
   * reasoning Format 值，由当前实例内部维护。
   */
  reasoningFormat: ReasoningFormat;
  /**
   * tool Calling Enabled 值，由当前实例内部维护。
   */
  toolCallingEnabled: boolean;
  /**
   * proxy Url 值，由当前实例内部维护。
   */
  proxyUrl: string;
  /**
   * additional Headers 列表，由当前实例内部维护。
   */
  additionalHeaders: Array<ConnectionHeaderRecord>;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述连接配置持久化或内存索引中的一条记录。
 */
export interface ConnectionActiveProfileRecord {
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * profile 标识。
   */
  profileId: string;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述连接配置模块在运行时交换的数据结构。
 */
export interface ConnectionResolvedProfile {
  /**
   * binding 值，由当前实例内部维护。
   */
  binding: ConnectionActiveProfileRecord;
  /**
   * profile 值，由当前实例内部维护。
   */
  profile: ConnectionProfileRecord;
  /**
   * 密钥引用，由当前实例内部维护。
   */
  secretRef: SecretRef;
}

/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface ConnectionProviderRequest {
  /**
   * api Type 值，由当前实例内部维护。
   */
  apiType: ConnectionApiType;
  /**
   * 模型名称，由当前实例内部维护。
   */
  model: string;
  /**
   * 服务地址，由当前实例内部维护。
   */
  serverUrl: string;
  /**
   * 密钥引用，由当前实例内部维护。
   */
  secretRef: SecretRef;
  /**
   * generation Preset 标识。
   */
  generationPresetId: string;
  /**
   * system Prompt Preset 标识。
   */
  systemPromptPresetId: string;
  /**
   * context Template 标识。
   */
  contextTemplateId: string;
  /**
   * instruct Template 标识。
   */
  instructTemplateId: string;
  /**
   * tokenizer 值，由当前实例内部维护。
   */
  tokenizer: TokenizerStrategy;
  /**
   * stop Strings 列表，由当前实例内部维护。
   */
  stopStrings: Array<string>;
  /**
   * reasoning Format 值，由当前实例内部维护。
   */
  reasoningFormat: ReasoningFormat;
  /**
   * tool Calling Enabled 值，由当前实例内部维护。
   */
  toolCallingEnabled: boolean;
  /**
   * proxy Url 值，由当前实例内部维护。
   */
  proxyUrl: string;
  /**
   * additional Headers 列表，由当前实例内部维护。
   */
  additionalHeaders: Array<ConnectionHeaderRecord>;
}

/**
 * 描述连接配置事件发布时携带的数据结构。
 */
export interface ConnectionProfileEventPayload {
  /**
   * profile 值，由当前实例内部维护。
   */
  profile: ConnectionProfileRecord;
}

/**
 * 描述连接配置事件发布时携带的数据结构。
 */
export interface ConnectionProfileUpdatedPayload {
  /**
   * profile 值，由当前实例内部维护。
   */
  profile: ConnectionProfileRecord;
}

/**
 * 描述连接配置事件发布时携带的数据结构。
 */
export interface ConnectionProfileDeletedPayload {
  /**
   * profile 标识。
   */
  profileId: string;
}

/**
 * 描述连接配置事件发布时携带的数据结构。
 */
export interface ConnectionActiveProfilePayload {
  /**
   * binding 值，由当前实例内部维护。
   */
  binding: ConnectionActiveProfileRecord;
}
