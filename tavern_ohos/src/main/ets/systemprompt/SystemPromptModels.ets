/**
 * 描述系统 Prompt持久化或内存索引中的一条记录。
 */
export interface SystemPromptRecord {
  /**
   * 名称。
   */
  name: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * post History 值，由当前实例内部维护。
   */
  postHistory: string;
}

/**
 * 描述系统 Prompt模块在运行时交换的数据结构。
 */
export interface SystemPromptState {
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * 名称。
   */
  name: string;
  /**
   * 内容。
   */
  content: string;
  /**
   * post History 值，由当前实例内部维护。
   */
  postHistory: string;
}

/**
 * 描述系统 Prompt事件发布时携带的数据结构。
 */
export interface SystemPromptPayload {
  /**
   * state 值，由当前实例内部维护。
   */
  state: SystemPromptState;
}
