/**
 * 描述Prompt 模板模块在运行时交换的数据结构。
 */
export interface PromptTemplateDerivation {
  /**
   * context 值，由当前实例内部维护。
   */
  context: string | null;
  /**
   * instruct 值，由当前实例内部维护。
   */
  instruct: string | null;
}

/**
 * 描述调用Prompt 模板能力时需要传入的参数。
 */
export interface PromptTemplateRegistrationParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * 内容。
   */
  content: string;
}

/**
 * 描述Prompt 模板持久化或内存索引中的一条记录。
 */
export interface PromptTemplateRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * 内容。
   */
  content: string;
}

/**
 * 描述Prompt 模板事件发布时携带的数据结构。
 */
export interface PromptTemplateRenderedPayload {
  /**
   * template 标识。
   */
  templateId: string;
  /**
   * output 值，由当前实例内部维护。
   */
  output: string;
}
