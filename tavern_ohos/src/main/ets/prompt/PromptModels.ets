import type { CharacterRecord } from '../characters/CharacterModels';
import type { ChatMessage } from '../chats/ChatModels';
import type { WorldInfoActivation } from '../worldinfo/WorldInfoModels';

/**
 * 组装 Prompt 时所需的输入参数。
 * 用于 PromptRuntime.buildPrompt 方法，包含构建完整提示词所需的所有数据来源。
 */
export interface PromptBuildInput {
  /**
   * 请求的唯一标识，用于在结果和调试快照中关联输入和输出。
   */
  id: string;
  /**
   * 系统提示词文本，作为 Prompt 的第一个分段，设定 AI 的角色和行为基线。
   */
  systemPrompt: string;
  /**
   * 用户人格的显示名称，用于在 Prompt 中标识用户角色。
   */
  personaName: string;
  /**
   * 用户人格的描述文本，注入到 Prompt 中用于描述用户角色的背景。
   */
  personaDescription: string;
  /**
   * 作者的备注文本，作为独立分段注入到 Prompt 中，用于在运行时提供额外指引。
   */
  authorNote: string;
  /**
   * 当前对话使用的角色记录，用于提取角色的系统提示、描述、人格、场景和对话示例。
   */
  character: CharacterRecord;
  /**
   * 聊天消息列表，用于构建聊天历史分段，是按 token 预算裁剪的主要目标。
   */
  messages: Array<ChatMessage>;
  /**
   * 激活的 World Info 数据，作为独立分段注入到 Prompt 中，提供上下文世界设定。
   */
  worldInfo: WorldInfoActivation;
  /**
   * 最大预估 token 数，超出时裁剪聊天历史，用于确保 Prompt 不超过模型上下文窗口限制。
   */
  maxEstimatedTokens: number;
}

/**
 * Prompt 组装完成后返回给调用方的结果。
 * 由 PromptRuntime.buildPrompt 返回，包含分段列表、完整文本和调试快照。
 */
export interface PromptBuildResult {
  /**
   * 请求的唯一标识，与输入参数中的 id 对应，用于关联请求和结果。
   */
  id: string;
  /**
   * 组装后的 Prompt 分段列表，每个分段包含类型、角色、来源和内容等信息。
   */
  sections: Array<PromptSection>;
  /**
   * 各分段拼接后的完整文本，以便直接送入模型推理。
   */
  finalText: string;
  /**
   * 组装过程的调试快照，包含分段数、预估 token、预算值和被裁剪的分段。
   */
  debug: PromptDebugSnapshot;
}

/**
 * Prompt 组装中的一个分段。
 * 表示 Prompt 中的独立组成部分，如系统提示、角色描述、聊天历史等。
 */
export interface PromptSection {
  /**
   * 分段的唯一标识，格式为 {type}:{sourceId}，用于在裁剪调试中定位特定分段。
   */
  id: string;
  /**
   * 分段类型（如 system、chat_history、persona、world_info），用于标识分段在 Prompt 中的语义角色。
   */
  type: string;
  /**
   * 角色标识（如 system、user、assistant），用于模型区分消息来源。
   */
  role: string;
  /**
   * 来源类型（如 system、character、persona、worldinfo、message），用于标识分段数据来自哪个子系统。
   */
  source: string;
  /**
   * 分段的内容文本，将直接出现在最终拼接的 Prompt 中。
   */
  content: string;
  /**
   * 预估的 token 数量，用于在 trimToBudget 中判断是否超出预算。
   */
  estimatedTokens: number;
}

/**
 * Prompt 组装过程的调试快照。
 * 用于在 PromptBuildResult 中返回组装过程的详细统计信息。
 */
export interface PromptDebugSnapshot {
  /**
   * Prompt 请求标识，与 PromptBuildInput 中的 id 对应。
   */
  promptId: string;
  /**
   * 分段总数，用于了解 Prompt 包含多少个组成部分。
   */
  sectionCount: number;
  /**
   * 所有分段的预估 token 总数，用于确认 Prompt 是否在预算内。
   */
  estimatedTokens: number;
  /**
   * 允许的最大预估 token 数，与 PromptBuildInput 中 maxEstimatedTokens 一致。
   */
  maxEstimatedTokens: number;
  /**
   * 因超出 token 预算而被裁剪的分段 ID 列表，用于调试和历史消息裁剪追踪。
   */
  trimmedSections: Array<string>;
}

/**
 * Prompt 组装完成时通过事件总线发布的数据载荷。
 * 由 buildPrompt 在完成 Prompt 组装后发布。
 */
export interface PromptBuiltPayload {
  /**
   * 组装完成的 Prompt 结果，供监听方（如 UI 调试面板）获取完整 Prompt 数据。
   */
  prompt: PromptBuildResult;
}
