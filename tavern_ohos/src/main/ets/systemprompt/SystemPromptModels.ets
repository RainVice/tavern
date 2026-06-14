/**
 * 描述系统 Prompt 持久化或内存索引中的一条记录。
 */
export interface SystemPromptRecord {
  /**
   * 提示词名称，作为唯一标识。
   */
  name: string;
  /**
   * 提示词正文内容。
   */
  content: string;
  /**
   * 提示词之后追加的对话历史说明文本。
   */
  postHistory: string;
}

/**
 * 描述系统 Prompt 模块在运行时交换的状态数据结构。
 */
export interface SystemPromptState {
  /**
   * 是否启用了系统提示词功能。
   */
  enabled: boolean;
  /**
   * 当前选中的提示词名称。
   */
  name: string;
  /**
   * 当前选中的提示词正文内容。
   */
  content: string;
  /**
   * 当前选中的提示词之后的对话历史说明文本。
   */
  postHistory: string;
}

/**
 * 描述系统 Prompt 事件发布时携带的数据结构。
 */
export interface SystemPromptPayload {
  /**
   * 系统提示词的运行时状态快照。
   */
  state: SystemPromptState;
}
