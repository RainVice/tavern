import type { RuntimeSource } from '../contracts/PublicContracts';
import type { VariableResolveContext } from '../variable/VariableModels';

/**
 * 描述宏展开模块在运行时交换的数据结构。
 */
export interface MacroEvaluationContext {
  /**
   * user 名称。
   */
  userName: string;
  /**
   * character 名称。
   */
  characterName: string;
  /**
   * persona 名称。
   */
  personaName: string;
  /**
   * chat 名称。
   */
  chatName: string;
  /**
   * message Text 值，由当前实例内部维护。
   */
  messageText: string;
  /**
   * world Info 名称。
   */
  worldInfoName: string;
  /**
   * variable Context 值，由当前实例内部维护。
   */
  variableContext: VariableResolveContext;
}

/**
 * 描述宏展开模块在运行时交换的数据结构。
 */
export interface MacroExecutionContext {
  /**
   * 名称。
   */
  name: string;
  /**
   * args 列表，由当前实例内部维护。
   */
  args: Array<string>;
  /**
   * raw 值，由当前实例内部维护。
   */
  raw: string;
  /**
   * context 值，由当前实例内部维护。
   */
  context: MacroEvaluationContext;
}

/**
 * 描述宏展开模块在运行时交换的数据结构。
 */
export interface MacroAction {
  /**
   * 执行 expand 的内部处理步骤，供当前模块复用。
   */
  expand(context: MacroExecutionContext): string;
}

/**
 * 描述调用宏展开能力时需要传入的参数。
 */
export interface MacroRegistrationParams {
  /**
   * 名称。
   */
  name: string;
  /**
   * category 值，由当前实例内部维护。
   */
  category: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * 来源类型，由当前实例内部维护。
   */
  source: RuntimeSource;
  /**
   * plugin 标识。
   */
  pluginId: string;
  /**
   * action 值，由当前实例内部维护。
   */
  action: MacroAction;
}

/**
 * 描述宏展开持久化或内存索引中的一条记录。
 */
export interface MacroRecord {
  /**
   * 名称。
   */
  name: string;
  /**
   * category 值，由当前实例内部维护。
   */
  category: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * 来源类型，由当前实例内部维护。
   */
  source: RuntimeSource;
  /**
   * plugin 标识。
   */
  pluginId: string;
}

/**
 * 描述宏展开模块在运行时交换的数据结构。
 */
export interface MacroDiagnostic {
  /**
   * macro 名称。
   */
  macroName: string;
  /**
   * 消息数据。
   */
  message: string;
  /**
   * offset 值，由当前实例内部维护。
   */
  offset: number;
  /**
   * raw 值，由当前实例内部维护。
   */
  raw: string;
}

/**
 * 描述宏展开操作完成后返回给调用方的结果。
 */
export interface MacroExpansionResult {
  /**
   * 文本内容。
   */
  text: string;
  /**
   * diagnostics 列表，由当前实例内部维护。
   */
  diagnostics: Array<MacroDiagnostic>;
}

/**
 * 描述宏展开事件发布时携带的数据结构。
 */
export interface MacroExpandedPayload {
  /**
   * 输入数据。
   */
  input: string;
  /**
   * output 值，由当前实例内部维护。
   */
  output: string;
  /**
   * diagnostics 列表，由当前实例内部维护。
   */
  diagnostics: Array<MacroDiagnostic>;
}

/**
 * 描述宏展开事件发布时携带的数据结构。
 */
export interface MacroRegisteredPayload {
  /**
   * macro 值，由当前实例内部维护。
   */
  macro: MacroRecord;
}
