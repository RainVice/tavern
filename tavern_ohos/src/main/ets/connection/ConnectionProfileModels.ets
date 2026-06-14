import type {
  ConnectionApiType,
  ReasoningFormat,
  SecretRef,
  TavernScope,
  TokenizerStrategy,
} from '../contracts/PublicContracts';

/**
 * 描述连接配置中一条自定义 Header 记录，包含名称、值及是否标记为密钥。
 */
export interface ConnectionHeaderRecord {
  /**
   * Header 名称，如 "Authorization"。
   */
  name: string;
  /**
   * Header 值。
   */
  value: string;
  /**
   * 是否标记为密钥；为 true 时序列化或日志输出中应被遮盖。
   */
  secret: boolean;
}

/**
 * 创建连接配置记录时所需传入的参数集合。
 */
export interface ConnectionProfileCreateParams {
  /**
   * 唯一标识。
   */
  id: string;
  /**
   * 显示名称。
   */
  name: string;
  /**
   * API 类型，决定使用哪个服务提供商协议。
   */
  apiType: ConnectionApiType;
  /**
   * 模型名称，如 "gpt-4"。
   */
  model: string;
  /**
   * 服务端点地址。
   */
  serverUrl: string;
  /**
   * 密钥引用，指向外部密钥存储中的凭据。
   */
  secretRef: SecretRef;
  /**
   * 生成预设标识，关联生成参数模板。
   */
  generationPresetId: string;
  /**
   * 系统提示词预设标识，关联系统级提示词模板。
   */
  systemPromptPresetId: string;
  /**
   * 上下文模板标识，关联对话上下文格式化模板。
   */
  contextTemplateId: string;
  /**
   * 指令模板标识，关联用户输入指令格式化模板。
   */
  instructTemplateId: string;
  /**
   * 分词器策略，决定文本如何分片。
   */
  tokenizer: TokenizerStrategy;
  /**
   * 停止字符串列表，命中任意一项即停止生成。
   */
  stopStrings: Array<string>;
  /**
   * 推理格式，控制思维链等推理内容的输出格式。
   */
  reasoningFormat: ReasoningFormat;
  /**
   * 是否启用工具调用能力。
   */
  toolCallingEnabled: boolean;
  /**
   * 代理地址，用于穿透网络限制。
   */
  proxyUrl: string;
  /**
   * 自定义请求头列表。
   */
  additionalHeaders: Array<ConnectionHeaderRecord>;
  /**
   * 是否启用该连接配置。
   */
  enabled: boolean;
}

/**
 * 描述一条完整的连接配置记录，持久化存储或内存索引中的核心数据单元。
 */
export interface ConnectionProfileRecord {
  /**
   * 唯一标识。
   */
  id: string;
  /**
   * 显示名称。
   */
  name: string;
  /**
   * API 类型，决定使用哪个服务提供商协议。
   */
  apiType: ConnectionApiType;
  /**
   * 模型名称，如 "gpt-4"。
   */
  model: string;
  /**
   * 服务端点地址。
   */
  serverUrl: string;
  /**
   * 密钥引用，指向外部密钥存储中的凭据。
   */
  secretRef: SecretRef;
  /**
   * 生成预设标识，关联生成参数模板。
   */
  generationPresetId: string;
  /**
   * 系统提示词预设标识，关联系统级提示词模板。
   */
  systemPromptPresetId: string;
  /**
   * 上下文模板标识，关联对话上下文格式化模板。
   */
  contextTemplateId: string;
  /**
   * 指令模板标识，关联用户输入指令格式化模板。
   */
  instructTemplateId: string;
  /**
   * 分词器策略，决定文本如何分片。
   */
  tokenizer: TokenizerStrategy;
  /**
   * 停止字符串列表，命中任意一项即停止生成。
   */
  stopStrings: Array<string>;
  /**
   * 推理格式，控制思维链等推理内容的输出格式。
   */
  reasoningFormat: ReasoningFormat;
  /**
   * 是否启用工具调用能力。
   */
  toolCallingEnabled: boolean;
  /**
   * 代理地址，用于穿透网络限制。
   */
  proxyUrl: string;
  /**
   * 自定义请求头列表。
   */
  additionalHeaders: Array<ConnectionHeaderRecord>;
  /**
   * 是否启用该连接配置。
   */
  enabled: boolean;
  /**
   * 最后更新时间的毫秒级时间戳。
   */
  updatedAt: number;
}

/**
 * 描述连接配置与某一作用域的激活绑定关系。
 */
export interface ConnectionActiveProfileRecord {
  /**
   * 作用域类型，标识绑定所属的领域（如角色、对话等）。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 被绑定的连接配置标识。
   */
  profileId: string;
  /**
   * 绑定或最后更新时间的毫秒级时间戳。
   */
  updatedAt: number;
}

/**
 * 描述解析后的完整连接配置，包含激活绑定、配置记录和密钥引用三项。
 */
export interface ConnectionResolvedProfile {
  /**
   * 当前作用域的激活绑定信息。
   */
  binding: ConnectionActiveProfileRecord;
  /**
   * 完整的连接配置记录。
   */
  profile: ConnectionProfileRecord;
  /**
   * 密钥引用，指向外部密钥存储中的凭据。
   */
  secretRef: SecretRef;
}

/**
 * 描述发送给服务提供商或网络层的请求参数，不含存储层字段。
 */
export interface ConnectionProviderRequest {
  /**
   * API 类型，决定使用哪个服务提供商协议。
   */
  apiType: ConnectionApiType;
  /**
   * 模型名称，如 "gpt-4"。
   */
  model: string;
  /**
   * 服务端点地址。
   */
  serverUrl: string;
  /**
   * 密钥引用，指向外部密钥存储中的凭据。
   */
  secretRef: SecretRef;
  /**
   * 生成预设标识，关联生成参数模板。
   */
  generationPresetId: string;
  /**
   * 系统提示词预设标识，关联系统级提示词模板。
   */
  systemPromptPresetId: string;
  /**
   * 上下文模板标识，关联对话上下文格式化模板。
   */
  contextTemplateId: string;
  /**
   * 指令模板标识，关联用户输入指令格式化模板。
   */
  instructTemplateId: string;
  /**
   * 分词器策略，决定文本如何分片。
   */
  tokenizer: TokenizerStrategy;
  /**
   * 停止字符串列表，命中任意一项即停止生成。
   */
  stopStrings: Array<string>;
  /**
   * 推理格式，控制思维链等推理内容的输出格式。
   */
  reasoningFormat: ReasoningFormat;
  /**
   * 是否启用工具调用能力。
   */
  toolCallingEnabled: boolean;
  /**
   * 代理地址，用于穿透网络限制。
   */
  proxyUrl: string;
  /**
   * 自定义请求头列表。
   */
  additionalHeaders: Array<ConnectionHeaderRecord>;
}

/**
 * 连接配置创建事件发布时携带的数据。
 */
export interface ConnectionProfileEventPayload {
  /**
   * 新创建的连接配置记录副本。
   */
  profile: ConnectionProfileRecord;
}

/**
 * 连接配置更新事件发布时携带的数据。
 */
export interface ConnectionProfileUpdatedPayload {
  /**
   * 更新后的连接配置记录副本。
   */
  profile: ConnectionProfileRecord;
}

/**
 * 连接配置删除事件发布时携带的数据。
 */
export interface ConnectionProfileDeletedPayload {
  /**
   * 被删除的连接配置标识。
   */
  profileId: string;
}

/**
 * 激活绑定变更事件发布时携带的数据。
 */
export interface ConnectionActiveProfilePayload {
  /**
   * 变更后的激活绑定记录。
   */
  binding: ConnectionActiveProfileRecord;
}
