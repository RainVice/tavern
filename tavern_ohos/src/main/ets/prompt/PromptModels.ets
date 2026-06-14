import type { CharacterRecord } from '../characters/CharacterModels';
import type { ChatMessage } from '../chats/ChatModels';
import type {
  ChatMessageRole,
  PromptSectionType,
  RuntimeSource,
} from '../contracts/PublicContracts';
import type { WorldInfoActivation } from '../worldinfo/WorldInfoModels';

/**
 * 调用 Prompt 组装能力时需要传入的参数。
 * 调用方在发起 prompt 组装前必须填充此接口的所有必需字段。
 */
export interface PromptBuildInput {
  /**
   * 本次 prompt 会话的唯一标识。
   */
  id: string;
  /**
   * 系统级 system prompt，通常由运行时内部维护并自动注入。
   */
  systemPrompt: string;
  /**
   * 用户 persona 的名称。
   */
  personaName: string;
  /**
   * 用户 persona 的描述文本，用于辅助角色扮演风格的生成。
   */
  personaDescription: string;
  /**
   * Author's Note 文本，作为克制性提示词干预模型输出方向。
   */
  authorNote: string;
  /**
   * 当前对话的角色数据记录。
   */
  character: CharacterRecord;
  /**
   * 对话消息列表，为最终 prompt 中聊天记录部分的输入来源。
   */
  messages: Array<ChatMessage>;
  /**
   * 当前激活的 World Info 条目数据。
   */
  worldInfo: WorldInfoActivation;
  /**
   * 本次 prompt 组装的 Token 预算上限，用于裁剪聊天历史。
   */
  maxEstimatedTokens: number;
}

/**
 * Prompt 组装完成后返回给调用方的结果。
 * 包含按顺序排列的 section 列表、最终拼接文本以及调试快照。
 */
export interface PromptBuildResult {
  /**
   * 本次 prompt 会话的唯一标识，与输入中的 id 对应。
   */
  id: string;
  /**
   * 按最终顺序排列的 section 列表，已根据预算裁剪。
   */
  sections: Array<PromptSection>;
  /**
   * 所有 section 内容按顺序拼接后得到的完整 prompt 文本。
   */
  finalText: string;
  /**
   * 本次组装的调试快照，包含 section 数量、Token 估算等诊断信息。
   */
  debug: PromptDebugSnapshot;
}

/**
 * Prompt 组装过程中的单个数据段。
 * 每个 section 对应 prompt 中的一个组成部分（如系统提示、角色描述、聊天历史等）。
 */
export interface PromptSection {
  /**
   * 当前 section 的唯一标识，格式为 "{type}:{source标识}"。
   */
  id: string;
  /**
   * 当前 section 的类型，用于区分角色定义、聊天历史、World Info 等不同来源。
   */
  type: PromptSectionType;
  /**
   * 当前 section 在 prompt 中占据的角色（system / user / assistant）。
   */
  role: ChatMessageRole;
  /**
   * 来源类型，标示该 section 由哪个模块提供（如 character、persona、worldinfo 等）。
   */
  source: RuntimeSource;
  /**
   * 当前 section 的文本内容。
   */
  content: string;
  /**
   * 当前 section 内容的估算 Token 数，用于预算裁剪判断。
   */
  estimatedTokens: number;
}

/**
 * Prompt 组装过程中的调试快照，记录本次组装的诊断信息。
 * 包含 Token 统计和裁剪历史，用于排查 prompt 过长或被裁剪的问题。
 */
export interface PromptDebugSnapshot {
  /**
   * 本次 prompt 会话的唯一标识，与输入中的 id 对应。
   */
  promptId: string;
  /**
   * 最终保留的 section 总数（已剔除裁剪移除的 section）。
   */
  sectionCount: number;
  /**
   * 最终 prompt 的总估算 Token 数。
   */
  estimatedTokens: number;
  /**
   * Token 预算上限，与输入中的 maxEstimatedTokens 一致。
   */
  maxEstimatedTokens: number;
  /**
   * 因超出预算而被移除的 section 标识列表。
   */
  trimmedSections: Array<string>;
}

/**
 * Prompt 组装事件发布时携带的数据负载。
 * 当 prompt 组装完成后，会通过事件总线广播此负载。
 */
export interface PromptBuiltPayload {
  /**
   * 组装完成的 prompt 结果对象。
   */
  prompt: PromptBuildResult;
}
