/**
 * 从 chat_template 推导出的 LLM prompt 格式描述，包含 context 与 instruct 两个模板的名称或 null。
 */
export interface PromptTemplateDerivation {
  /**
   * LLM 的上下文模板名称（如 "Llama 3 Instruct"、"ChatML"），无法识别时为 null。
   */
  context: string | null;
  /**
   * LLM 的指令模板名称，无法识别时与 context 相同或为 null。
   */
  instruct: string | null;
}

/**
 * 注册 prompt 模板时需要提供的参数，包含模板标识与模板内容。
 */
export interface PromptTemplateRegistrationParams {
  /**
   * 模板唯一标识字符串，注册时不可为空。
   */
  id: string;
  /**
   * 模板原始文本，包含 {{变量名}} 占位符供后续渲染替换。
   */
  content: string;
}

/**
 * prompt 模板持久化的记录结构，包含标识与原始模板文本。
 */
export interface PromptTemplateRecord {
  /**
   * 模板唯一标识，与注册时传入的 id 一致。
   */
  id: string;
  /**
   * 模板原始文本，包含 {{变量名}} 占位符。
   */
  content: string;
}

/**
 * prompt 模板渲染完成后事件发布时携带的数据结构。
 */
export interface PromptTemplateRenderedPayload {
  /**
   * 已渲染模板的标识，对应注册时的 id。
   */
  templateId: string;
  /**
   * 模板渲染完成后的最终文本输出。
   */
  output: string;
}
