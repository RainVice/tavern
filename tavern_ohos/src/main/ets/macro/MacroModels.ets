import type { VariableResolveContext } from '../variable/VariableModels';

/**
 * 描述宏展开模块在运行时交换的数据结构。
 * 在 MacroRuntime.expand / expandWithStrategy 中传递给各个 MacroAction 的 expand 方法，
 * 作为宏展开时读取运行时值的上下文输入。
 */
export interface MacroEvaluationContext {
  /**
   * user 名称，用于 {{user}} 宏展开时替换为用户昵称。
   */
  userName: string;
  /**
   * character 名称，用于 {{char}} 宏展开时替换为角色名称。
   */
  characterName: string;
  /**
   * persona 名称，用于 {{persona}} 宏展开时替换为人格名称。
   */
  personaName: string;
  /**
   * chat 名称，用于 {{chat}} 宏展开时替换为当前聊天名称。
   */
  chatName: string;
  /**
   * 当前消息的文本内容，用于 {{message}} 宏展开时替换为消息原文。
   */
  messageText: string;
  /**
   * world Info 名称，用于 {{worldinfo}} 宏展开时替换为世界信息名称。
   */
  worldInfoName: string;
  /**
   * 变量解析上下文，包含当前会话和聊天范围内的变量值，用于 {{getvar}}/{{setvar}} 等变量操作宏的读写。
   */
  variableContext: VariableResolveContext;
}

/**
 * 描述宏展开模块在运行时交换的数据结构。
 * MacroRuntime 在内部解析 {{name::arg1::arg2}} 后构建此上下文，
 * 传递给 MacroAction.expand 方法用于实际替换计算。
 */
export interface MacroExecutionContext {
  /**
   * 宏名称，对应 {{name::...}} 中的 name 部分，用于在 macros 映射中查找定义。
   */
  name: string;
  /**
   * 宏展开时传递的参数列表，对应 {{name::arg1::arg2}} 中 name 后的各段，参数本身也会递归展开。
   */
  args: Array<string>;
  /**
   * 宏在原始输入中的完整未解析文本（包含 {{ 和 }}），在诊断信息中用于标识未识别的宏。
   */
  raw: string;
  /**
   * 宏展开上下文，包含角色名称、聊天名称以及变量解析信息，
   * 由 expand 方法透传给各 MacroAction 使用。
   */
  context: MacroEvaluationContext;
}

/**
 * 描述宏展开模块在运行时交换的数据结构。
 * 每个已注册的宏都需要实现此接口，MacroRuntime 在解析到对应宏名称时调用 expand 方法获取替换文本。
 */
export interface MacroAction {
  /**
   * 根据给定的执行上下文将宏展开为替换文本。
   * 由 MacroRuntime 的 evaluateMacro 方法在匹配到已注册宏时调用，
   * 返回值将替换原始输入中的 {{name::...}} 标记。
   */
  expand(context: MacroExecutionContext): string;
}

/**
 * 描述调用宏展开能力时需要传入的参数。
 * 调用方（如插件系统或 registerBuiltIn）通过 registerMacro 方法传入此参数，
 * 用于将宏注册到 MacroRuntime 的 macros 映射中。
 */
export interface MacroRegistrationParams {
  /**
   * 宏名称，对应输入文本中 {{name}} 的花括号内名称，用于在展开时匹配查找。
   */
  name: string;
  /**
   * 宏所属分类（如 names、chat、variable、utility、time 等），用于在管理界面中对宏进行分组展示。
   */
  category: string;
  /**
   * 宏的描述文本，用于调试或界面展示，帮助开发者或用户理解宏的作用。
   */
  description: string;
  /**
   * 宏的来源标识（如 builtin、plugin），用于区分系统内置宏和第三方插件注册的宏。
   */
  source: string;
  /**
   * plugin 标识，当 source 为 plugin 时记录注册该宏的插件 ID，便于追溯宏的来源。
   */
  pluginId: string;
  /**
   * 宏展开时执行的可调用动作，实现 MacroAction 接口，运行时解析到 {{name}} 时调用其 expand 方法。
   */
  action: MacroAction;
}

/**
 * 描述宏展开持久化或内存索引中的一条记录。
 * 在 listMacros / autocomplete 的返回值和 MacroRegisteredPayload 中使用，
 * 不包含可执行的动作（action），仅供调用方安全读取宏的元信息。
 */
export interface MacroRecord {
  /**
   * 宏名称，与注册时一致，用于在输入文本中 {{name}} 标记的匹配。
   */
  name: string;
  /**
   * 宏所属分类（如 names、chat、variable 等），用于管理界面的分组展示。
   */
  category: string;
  /**
   * 宏的描述文本，用于调试或界面展示。
   */
  description: string;
  /**
   * 宏的来源（如 builtin、plugin），区分系统内置和第三方注册。
   */
  source: string;
  /**
   * plugin 标识，当来源为 plugin 时记录注册该宏的插件 ID。
   */
  pluginId: string;
}

/**
 * 描述宏展开模块在运行时交换的数据结构。
 * 在展开遇到未知宏或解析错误时由 evaluateMacro 创建，
 * 附加到 MacroExpansionResult.diagnostics 中返回给调用方用于问题排查。
 */
export interface MacroDiagnostic {
  /**
   * macro 名称，标识哪个宏触发了诊断，用于快速定位问题宏。
   */
  macroName: string;
  /**
   * 消息数据，描述诊断的具体原因（如 "Unknown macro: xxx"），用于展示错误信息。
   */
  message: string;
  /**
   * 宏在原始输入中的字符偏移量，用于在原文中定位宏标记的位置。
   */
  offset: number;
  /**
   * 宏在原始输入中的完整未解析文本（包含 {{ 和 }}），用于在调试时展示原始标记。
   */
  raw: string;
}

/**
 * 描述宏展开操作完成后返回给调用方的结果。
 * 由 MacroRuntime.expand / expandWithStrategy 返回，
 * 调用方（如消息发送流程）使用 text 替代原始输入，并可根据 diagnostics 检查展开过程中是否出现了问题。
 */
export interface MacroExpansionResult {
  /**
   * 宏展开后的文本内容，其中所有 {{name}} 标记已被替换为对应的运行时值，供后续流程使用。
   */
  text: string;
  /**
   * 宏展开过程中产生的诊断信息列表，包含未知宏、解析错误等，供调用方进行问题排查。
   */
  diagnostics: Array<MacroDiagnostic>;
}

/**
 * 描述宏展开事件发布时携带的数据结构。
 * MacroRuntime 在 expandWithStrategy 完成后通过事件总线发布 macro.expanded 事件时使用此 payload，
 * 其他模块（如日志、UI 统计）可通过监听该事件获取展开前后的文本对比和诊断信息。
 */
export interface MacroExpandedPayload {
  /**
   * 宏展开前的原始输入文本，供事件订阅者对比展开前后的变化。
   */
  input: string;
  /**
   * 宏展开后的输出文本，其中 {{name}} 标记已被替换为运行时值。
   */
  output: string;
  /**
   * 宏展开过程中产生的诊断信息列表，供事件订阅者排查宏解析问题。
   */
  diagnostics: Array<MacroDiagnostic>;
}

/**
 * 描述宏展开事件发布时携带的数据结构。
 * MacroRuntime 在 registerMacro 成功后通过事件总线发布 macro.registered 事件时使用此 payload，
 * 其他模块（如插件管理 UI）可通过监听该事件获知新宏已可用。
 */
export interface MacroRegisteredPayload {
  /**
   * 新注册的宏记录，包含名称、分类、描述等元信息，供事件订阅者更新宏列表展示。
   */
  macro: MacroRecord;
}
