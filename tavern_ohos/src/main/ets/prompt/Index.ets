/**
 * Prompt 组装模块导出。
 * PromptRuntime：提供根据输入（系统提示、角色信息、用户人格、消息历史、World Info、作者备注等）组装完整提示词的运行时能力。
 * 调用方（模型调用客户端）在发起模型推理前通过此模块构建最终送入模型的 Prompt，支持 token 预算控制和历史裁剪。
 * PromptModels：定义 Prompt 组装输入、结果、分段、调试快照及事件载荷的类型。
 * 类型用于描述 Prompt 组装流程中的数据结构和调试信息格式。
 */
export { PromptRuntime } from './PromptRuntime';
export type {
  PromptBuildInput,
  PromptBuildResult,
  PromptBuiltPayload,
  PromptDebugSnapshot,
  PromptSection,
} from './PromptModels';
