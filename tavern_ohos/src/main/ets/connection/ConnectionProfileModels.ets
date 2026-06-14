/**
 * 描述连接配置中自定义 HTTP 请求头的一条记录，用于在 API 调用时附加到请求中。
 */
export interface ConnectionHeaderRecord {
  /**
   * 请求头名称，如 'Authorization'、'X-Custom-Header' 等。
   */
  name: string;
  /**
   * 请求头字段值，对应请求头的实际取值。
   */
  value: string;
  /**
   * 是否为敏感数据（secret 为 true 时导出或日志中值会被替换为 'redacted' 脱敏处理）。
   */
  secret: boolean;
}

/**
 * 描述创建连接配置时需要传入的参数，用于连接配置创建/更新流程的输入验证和数据组装。
 */
export interface ConnectionProfileCreateParams {
  /**
   * 连接配置的唯一标识，用于在创建时指定 ID 或在更新时查找目标配置。
   */
  id: string;
  /**
   * 连接配置的显示名称，用于在配置管理界面中标识该连接。
   */
  name: string;
  /**
   * API 类型，如 'openai'、'anthropic'、'kobold' 等，用于运行时选择对应的 API 适配器。
   */
  apiType: string;
  /**
   * 使用的模型名称标识，用于在 API 请求中指定要调用的模型。
   */
  model: string;
  /**
   * API 服务地址，用于建立 API 连接的目标 URL。
   */
  serverUrl: string;
  /**
   * 密钥引用标识，用于通过密钥管理系统安全地存储和读取 API 密钥。
   */
  secretRef: string;
  /**
   * 生成参数预设标识，用于在 API 请求中应用预设的温度、Top P 等推理参数。
   */
  generationPresetId: string;
  /**
   * 系统提示词预设标识，用于覆盖默认的系统提示词。
   */
  systemPromptPresetId: string;
  /**
   * 上下文模板标识，用于指定消息上下文构建方式的预设。
   */
  contextTemplateId: string;
  /**
   * 指令模板标识，用于指定 AI 对话指令格式的预设模板。
   */
  instructTemplateId: string;
  /**
   * 使用的分词器标识，用于计算消息的 token 数量以控制上下文长度。
   */
  tokenizer: string;
  /**
   * 停止词列表，当 AI 生成到这些词时停止继续输出，用于控制生成结束条件。
   */
  stopStrings: Array<string>;
  /**
   * AI 推理结果格式标识，如 'default'、'thinking' 等，用于解析不同格式的推理输出。
   */
  reasoningFormat: string;
  /**
   * 是否启用工具调用（Function Calling）功能，允许 AI 调用外部工具。
   */
  toolCallingEnabled: boolean;
  /**
   * 代理服务器 URL，用于经过代理服务器访问目标 API。
   */
  proxyUrl: string;
  /**
   * 发送 API 请求时附加的自定义请求头列表，用于传递认证信息或其他自定义参数。
   */
  additionalHeaders: Array<ConnectionHeaderRecord>;
  /**
   * 连接配置是否启用，禁用的配置在解析活跃绑定时不会被使用。
   */
  enabled: boolean;
}

/**
 * 描述连接配置持久化或内存中的完整记录，用于连接配置管理全流程（创建、查询、更新、删除）的数据载体。
 */
export interface ConnectionProfileRecord {
  /**
   * 连接配置的唯一标识，用于在索引和事件中引用该配置。
   */
  id: string;
  /**
   * 连接配置的显示名称，用于在配置管理界面中标识该连接。
   */
  name: string;
  /**
   * API 类型标识，用于运行时选择对应的 API 适配器。
   */
  apiType: string;
  /**
   * 使用的模型名称标识，用于 API 请求中指定模型。
   */
  model: string;
  /**
   * API 服务地址，用于建立 API 连接的目标 URL。
   */
  serverUrl: string;
  /**
   * 密钥引用标识，用于安全地读取 API 密钥。
   */
  secretRef: string;
  /**
   * 生成参数预设标识，用于应用预设的温度等推理参数。
   */
  generationPresetId: string;
  /**
   * 系统提示词预设标识，用于覆盖默认的系统提示词。
   */
  systemPromptPresetId: string;
  /**
   * 上下文模板标识，用于指定消息上下文构建方式的预设。
   */
  contextTemplateId: string;
  /**
   * 指令模板标识，用于指定 AI 对话指令格式的预设。
   */
  instructTemplateId: string;
  /**
   * 使用的分词器标识，用于 token 计数以控制上下文长度。
   */
  tokenizer: string;
  /**
   * 停止词列表，用于控制 AI 生成结束条件。
   */
  stopStrings: Array<string>;
  /**
   * AI 推理结果格式标识，用于解析不同格式的推理输出。
   */
  reasoningFormat: string;
  /**
   * 是否启用工具调用功能，允许 AI 调用外部工具。
   */
  toolCallingEnabled: boolean;
  /**
   * 代理服务器 URL，用于经过代理访问 API。
   */
  proxyUrl: string;
  /**
   * 附加的自定义请求头列表，用于传递认证信息或其他自定义参数。
   */
  additionalHeaders: Array<ConnectionHeaderRecord>;
  /**
   * 连接配置是否启用。
   */
  enabled: boolean;
  /**
   * 配置记录的最后更新时间戳（毫秒），用于冲突检测和列表排序。
   */
  updatedAt: number;
}

/**
 * 描述连接配置与作用域绑定的激活记录，用于在特定作用域下自动解析对应的连接配置。
 */
export interface ConnectionActiveProfileRecord {
  /**
   * 绑定作用域，如 'chat'、'character'、'global' 等，用于限定绑定适用的上下文范围。
   */
  scope: string;
  /**
   * 作用域下的具体对象标识，如聊天 ID 或角色 ID，用于定位到具体的绑定对象。
   */
  scopeId: string;
  /**
   * 绑定的连接配置标识，指明该作用域应使用哪个连接配置。
   */
  profileId: string;
  /**
   * 绑定记录的最后更新时间戳（毫秒），用于冲突检测。
   */
  updatedAt: number;
}

/**
 * 描述根据作用域解析后的完整连接配置信息，包含绑定记录和完整的配置数据，供 Provider 运行时使用。
 */
export interface ConnectionResolvedProfile {
  /**
   * 作用域绑定记录，包含 scope、scopeId 和绑定时间等信息。
   */
  binding: ConnectionActiveProfileRecord;
  /**
   * 绑定的连接配置记录，包含 API 类型、模型、地址等所有配置字段。
   */
  profile: ConnectionProfileRecord;
  /**
   * 解析后的密钥引用标识，用于 API 请求时获取认证凭据。
   */
  secretRef: string;
}

/**
 * 描述发送给 Provider 运行时的完整 API 请求参数，由连接配置解析生成，用于实际的 API 调用。
 */
export interface ConnectionProviderRequest {
  /**
   * API 类型标识，用于 Provider 运行时选择对应的 API 适配器和发送逻辑。
   */
  apiType: string;
  /**
   * 使用的模型名称标识，用于在 API 请求中指定模型。
   */
  model: string;
  /**
   * API 服务地址，API 请求的目标 URL。
   */
  serverUrl: string;
  /**
   * 密钥引用标识，用于在 API 请求中获取认证凭据。
   */
  secretRef: string;
  /**
   * 生成参数预设标识，用于在 API 请求中应用预设的推理参数。
   */
  generationPresetId: string;
  /**
   * 系统提示词预设标识，用于构建 API 请求中的系统消息。
   */
  systemPromptPresetId: string;
  /**
   * 上下文模板标识，用于构建 API 请求的消息上下文结构。
   */
  contextTemplateId: string;
  /**
   * 指令模板标识，用于格式化 API 请求中的对话指令。
   */
  instructTemplateId: string;
  /**
   * 使用的分词器标识，用于在 API 请求前计算 token 数量。
   */
  tokenizer: string;
  /**
   * 停止词列表，在 API 请求中指定生成结束条件。
   */
  stopStrings: Array<string>;
  /**
   * AI 推理结果格式标识，用于解析 API 返回的不同格式结果。
   */
  reasoningFormat: string;
  /**
   * 是否启用工具调用功能，在 API 请求中启用 Function Calling 参数。
   */
  toolCallingEnabled: boolean;
  /**
   * 代理服务器 URL，API 请求经过的代理地址。
   */
  proxyUrl: string;
  /**
   * 附加的自定义请求头列表，附加到 API 请求中传递。
   */
  additionalHeaders: Array<ConnectionHeaderRecord>;
}

/**
 * 描述连接配置创建成功后发布事件时携带的数据结构，供监听者更新 UI 或进行联动处理。
 */
export interface ConnectionProfileEventPayload {
  /**
   * 创建或更新的连接配置记录，供事件订阅者用于 UI 刷新或同步。
   */
  profile: ConnectionProfileRecord;
}

/**
 * 描述连接配置更新成功后发布事件时携带的数据结构，供监听者更新 UI 或进行联动处理。
 */
export interface ConnectionProfileUpdatedPayload {
  /**
   * 更新后的连接配置记录，供事件订阅者用于 UI 刷新或同步。
   */
  profile: ConnectionProfileRecord;
}

/**
 * 描述连接配置删除后发布事件时携带的数据结构，供监听者清理 UI 或资源引用。
 */
export interface ConnectionProfileDeletedPayload {
  /**
   * 被删除的连接配置标识，供事件订阅者用于移除 UI 中的对应项或清理引用。
   */
  profileId: string;
}

/**
 * 描述活跃连接配置变更后发布事件时携带的数据结构，供监听者更新当前生效的连接状态。
 */
export interface ConnectionActiveProfilePayload {
  /**
   * 变更后的作用域绑定记录，供事件订阅者用于更新 UI 中的绑定状态。
   */
  binding: ConnectionActiveProfileRecord;
}
