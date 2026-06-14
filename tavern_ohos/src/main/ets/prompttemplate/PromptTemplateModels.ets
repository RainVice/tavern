/**
 * 描述Prompt 模板模块在运行时交换的数据结构。
 */
export interface PromptTemplateDerivation {
  /**
   * 从 chat template 推导出的系统上下文模板名称，用于构建 LLM 系统提示词时的模板匹配；null 表示无法推导。
   */
  context: string | null;
  /**
   * 从 chat template 推导出的指令模板名称，用于构建 LLM 指令提示词时的模板匹配；null 表示无法推导。
   */
  instruct: string | null;
}

/**
 * 描述调用Prompt 模板能力时需要传入的参数。
 */
export interface PromptTemplateRegistrationParams {
  /**
   * 模板唯一标识，用于在字典中索引和查询该模板——由上层模块分配并保证唯一性。
   */
  id: string;
  /**
   * 模板内容字符串，包含 {{key}} 占位符供后续渲染替换——定义 Prompt 的格式化模板。
   */
  content: string;
}

/**
 * 描述Prompt 模板持久化或内存索引中的一条记录。
 */
export interface PromptTemplateRecord {
  /**
   * 模板唯一标识，用于在字典中索引和查询该模板。
   */
  id: string;
  /**
   * 模板内容字符串，包含 {{key}} 占位符供后续渲染替换。
   */
  content: string;
}

/**
 * 描述Prompt 模板事件发布时携带的数据结构。
 */
export interface PromptTemplateRenderedPayload {
  /**
   * template 标识，用于通知监听方是哪个模板完成了渲染，便于追踪渲染流程。
   */
  templateId: string;
  /**
   * 渲染完成后的最终输出文本，携带给监听方用于后续消息组装或日志记录。
   */
  output: string;
}
