/**
 * 宏展开模块 - 提供文本模板中的宏解析与替换能力。
 * 支持内置宏（如角色名、变量读写、条件判断、随机选择等）和插件注册的自定义宏，
 * 通过 MacroRuntime 负责宏的注册、展开、诊断和自动补全。
 * 在发送消息或生成 AI 回复前，消息文本中的 {{...}} 模板标记会被宏运行时解析替换为实际运行时值。
 */
export { MacroRuntime } from './MacroRuntime';
export type {
  MacroAction,
  MacroDiagnostic,
  MacroEvaluationContext,
  MacroExpandedPayload,
  MacroExpansionResult,
  MacroExecutionContext,
  MacroRecord,
  MacroRegisteredPayload,
  MacroRegistrationParams,
} from './MacroModels';
