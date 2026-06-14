import type { RuntimeSource } from '../contracts/PublicContracts';
import type { VariableResolveContext } from '../variable/VariableModels';

/**
 * 宏展开上下文，记录当前展开操作所涉及的各类名称和消息文本。
 */
export interface MacroEvaluationContext {
  /**
   * 当前对话的用户名称。
   */
  userName: string;
  /**
   * 当前对话的角色名称。
   */
  characterName: string;
  /**
   * 当前使用的 Persona 名称。
   */
  personaName: string;
  /**
   * 当前对话（chat）的名称。
   */
  chatName: string;
  /**
   * 当前待展开的消息文本。
   */
  messageText: string;
  /**
   * 当前生效的 World Info 条目名称。
   */
  worldInfoName: string;
  /**
   * 变量解析上下文，供宏内部按需查询或设置变量。
   */
  variableContext: VariableResolveContext;
}

/**
 * 单个宏在展开阶段所需的执行上下文，包含宏名称和参数。
 */
export interface MacroExecutionContext {
  /**
   * 宏名称。
   */
  name: string;
  /**
   * 宏调用时传入的参数列表。
   */
  args: Array<string>;
  /**
   * 宏调用的原始输入文本（包含 {{}} 包围符）。
   */
  raw: string;
  /**
   * 当前宏展开的评估上下文。
   */
  context: MacroEvaluationContext;
}

/**
 * 可执行的宏动作接口，实现方应在此完成宏的替换逻辑。
 */
export interface MacroAction {
  /**
   * 根据执行上下文计算宏的替换结果。
   * @param context 宏执行上下文。
   * @returns 替换后的文本。
   */
  expand(context: MacroExecutionContext): string;
}

/**
 * 注册宏时需要提供的参数集合。
 */
export interface MacroRegistrationParams {
  /**
   * 宏名称。
   */
  name: string;
  /**
   * 宏所属分类（如 names、chat、variable、utility）。
   */
  category: string;
  /**
   * 宏的功能描述。
   */
  description: string;
  /**
   * 宏的来源类型（builtin / plugin）。
   */
  source: RuntimeSource;
  /**
   * 注册该宏的插件标识，空字符串表示内置宏。
   */
  pluginId: string;
  /**
   * 宏对应的可执行动作。
   */
  action: MacroAction;
}

/**
 * 持久化或内存索引中的一条宏记录，不含执行逻辑。
 */
export interface MacroRecord {
  /**
   * 宏名称。
   */
  name: string;
  /**
   * 宏所属分类。
   */
  category: string;
  /**
   * 宏的功能描述。
   */
  description: string;
  /**
   * 宏的来源类型。
   */
  source: RuntimeSource;
  /**
   * 注册该宏的插件标识。
   */
  pluginId: string;
}

/**
 * 宏展开诊断项，记录展开过程中出现的异常或未知宏引用。
 */
export interface MacroDiagnostic {
  /**
   * 引用的宏名称。
   */
  macroName: string;
  /**
   * 诊断消息，描述具体问题。
   */
  message: string;
  /**
   * 宏在原始输入中的起始偏移量。
   */
  offset: number;
  /**
   * 宏原始文本内容（包含 {{}}）。
   */
  raw: string;
}

/**
 * 宏展开操作完成后返回给调用方的结果。
 */
export interface MacroExpansionResult {
  /**
   * 展开后的最终文本。
   */
  text: string;
  /**
   * 展开过程中产生的诊断列表。
   */
  diagnostics: Array<MacroDiagnostic>;
}

/**
 * 宏展开完成后发布事件时所携带的数据。
 */
export interface MacroExpandedPayload {
  /**
   * 展开前的输入文本。
   */
  input: string;
  /**
   * 展开后的输出文本。
   */
  output: string;
  /**
   * 展开过程中产生的诊断列表。
   */
  diagnostics: Array<MacroDiagnostic>;
}

/**
 * 宏注册完成后发布事件时所携带的数据。
 */
export interface MacroRegisteredPayload {
  /**
   * 注册的宏记录。
   */
  macro: MacroRecord;
}
