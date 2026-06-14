/**
 * 描述系统 Prompt持久化或内存索引中的一条记录。
 * 在系统提示词管理流程中，用于存储用户预设的提示词模板及其对话后追加文本。
 */
export interface SystemPromptRecord {
  /**
   * 系统提示词名称，在 SystemPromptRuntime 中作为记录的唯一标识和查找键。
   */
  name: string;
  /**
   * 系统提示词内容文本，在发送给 AI 模型时作为 system 角色的消息内容。
   */
  content: string;
  /**
   * 对话历史之后追加的提示词文本，在消息组装流程中放置在历史消息之后，用于影响模型后续回复。
   */
  postHistory: string;
}

/**
 * 描述系统提示词模块在运行时交换的状态结构。
 * 在系统提示词选择流程中，用于跟踪当前启用的提示词配置。
 */
export interface SystemPromptState {
  /**
   * 是否启用系统提示词功能，影响消息组装时是否要注入 system prompt。
   */
  enabled: boolean;
  /**
   * 当前选中的系统提示词名称，在 SystemPromptRuntime 中用于从 prompts 映射表查找记录。
   */
  name: string;
  /**
   * 当前选中的系统提示词内容，直接用于消息组装中的 system 消息体。
   */
  content: string;
  /**
   * 当前选中的 post-history 提示词文本，在消息组装流程中放置在历史消息之后。
   */
  postHistory: string;
}

/**
 * 描述系统提示词事件发布时携带的数据结构。
 * SystemPromptRuntime 在选中或变更系统提示词后发布，通知宿主 UI 更新提示词显示状态。
 */
export interface SystemPromptPayload {
  /**
   * 系统提示词的当前状态快照，包含启用状态和选中提示词的信息。
   */
  state: SystemPromptState;
}
