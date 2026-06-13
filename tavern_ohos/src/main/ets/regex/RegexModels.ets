/**
 * 描述正则脚本持久化或内存索引中的一条记录。
 */
export interface RegexScriptRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * script 名称。
   */
  scriptName: string;
  /**
   * source Type 值，由当前实例内部维护。
   */
  sourceType: string;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * find Regex 值，由当前实例内部维护。
   */
  findRegex: string;
  /**
   * flags 列表，由当前实例内部维护。
   */
  flags: string;
  /**
   * replace String 值，由当前实例内部维护。
   */
  replaceString: string;
  /**
   * placements 列表，由当前实例内部维护。
   */
  placements: Array<string>;
  /**
   * disabled 值，由当前实例内部维护。
   */
  disabled: boolean;
  /**
   * markdown Only 值，由当前实例内部维护。
   */
  markdownOnly: boolean;
  /**
   * prompt Only 值，由当前实例内部维护。
   */
  promptOnly: boolean;
  /**
   * run On Edit 值，由当前实例内部维护。
   */
  runOnEdit: boolean;
  /**
   * min Depth 值，由当前实例内部维护。
   */
  minDepth: number;
  /**
   * max Depth 值，由当前实例内部维护。
   */
  maxDepth: number;
  /**
   * ephemeral 值，由当前实例内部维护。
   */
  ephemeral: boolean;
  /**
   * trim Strings 列表，由当前实例内部维护。
   */
  trimStrings: Array<string>;
}

/**
 * 描述调用正则脚本能力时需要传入的参数。
 */
export interface RegexApplyInput {
  /**
   * 文本内容。
   */
  text: string;
  /**
   * placement 值，由当前实例内部维护。
   */
  placement: string;
  /**
   * is Markdown 值，由当前实例内部维护。
   */
  isMarkdown: boolean;
  /**
   * is Prompt 值，由当前实例内部维护。
   */
  isPrompt: boolean;
  /**
   * is Edit 值，由当前实例内部维护。
   */
  isEdit: boolean;
  /**
   * depth 值，由当前实例内部维护。
   */
  depth: number;
  /**
   * 作用域标识。
   */
  scopeId: string;
}

/**
 * 描述正则脚本模块在运行时交换的数据结构。
 */
export interface RegexApplyTrace {
  /**
   * script 标识。
   */
  scriptId: string;
  /**
   * script 名称。
   */
  scriptName: string;
  /**
   * placement 值，由当前实例内部维护。
   */
  placement: string;
  /**
   * before 值，由当前实例内部维护。
   */
  before: string;
  /**
   * after 值，由当前实例内部维护。
   */
  after: string;
  /**
   * changed 值，由当前实例内部维护。
   */
  changed: boolean;
  /**
   * diff 值，由当前实例内部维护。
   */
  diff: string;
}

/**
 * 描述正则脚本操作完成后返回给调用方的结果。
 */
export interface RegexApplyResult {
  /**
   * 文本内容。
   */
  text: string;
  /**
   * traces 列表，由当前实例内部维护。
   */
  traces: Array<RegexApplyTrace>;
}

/**
 * 描述正则脚本事件发布时携带的数据结构。
 */
export interface RegexAppliedPayload {
  /**
   * trace 值，由当前实例内部维护。
   */
  trace: RegexApplyTrace;
}
