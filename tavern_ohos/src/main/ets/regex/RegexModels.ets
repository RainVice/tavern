/**
 * 描述正则脚本持久化或内存索引中的一条记录。
 */
export interface RegexScriptRecord {
  /**
   * 全局唯一标识。
   */
  id: string;
  /**
   * 脚本的用户可读名称，用于日志和调试。
   */
  scriptName: string;
  /**
   * 脚本来源类型，用于区分定义源（如"global"、"character"、"temporary"）。
   */
  sourceType: string;
  /**
   * 脚本所属作用域的标识；空字符串表示全局作用域。
   */
  scopeId: string;
  /**
   * 用于匹配文本的正则表达式字符串。
   */
  findRegex: string;
  /**
   * 正则匹配修饰标志（如 "gi"、"gm"）。
   */
  flags: string;
  /**
   * 匹配成功后用于替换文本的字符串，支持 {{match}} 占位符。
   */
  replaceString: string;
  /**
   * 脚本生效的放置位置列表，表示该脚本在哪些上下文中运行。
   */
  placements: Array<string>;
  /**
   * 是否禁用：为 true 时脚本不参与运行。
   */
  disabled: boolean;
  /**
   * 仅 Markdown 内容生效：为 true 时脚本只在 Markdown 内容上运行。
   */
  markdownOnly: boolean;
  /**
   * 仅 Prompt 内容生效：为 true 时脚本只在 Prompt 内容上运行。
   */
  promptOnly: boolean;
  /**
   * 是否在编辑时自动触发运行。
   */
  runOnEdit: boolean;
  /**
   * 脚本生效的最小层级深度，-1 表示不限制。
   */
  minDepth: number;
  /**
   * 脚本生效的最大层级深度，-1 表示不限制。
   */
  maxDepth: number;
  /**
   * 是否为临时脚本：临时脚本在下次清理时会被移除。
   */
  ephemeral: boolean;
  /**
   * 替换完成后额外需移除的字符串列表，用于清理替换产生的不需要的残余文本。
   */
  trimStrings: Array<string>;
}

/**
 * 描述调用正则脚本能力时需要传入的参数。
 */
export interface RegexApplyInput {
  /**
   * 待处理的原始文本内容。
   */
  text: string;
  /**
   * 当前 placement 值，用于匹配脚本的 placements 列表以决定是否运行。
   */
  placement: string;
  /**
   * 待处理文本是否为 Markdown 格式。
   */
  isMarkdown: boolean;
  /**
   * 待处理文本是否为 Prompt 格式。
   */
  isPrompt: boolean;
  /**
   * 是否为编辑操作触发的调用。
   */
  isEdit: boolean;
  /**
   * 当前内容层级深度，用于与脚本的 minDepth/maxDepth 比较。
   */
  depth: number;
  /**
   * 当前作用域标识，用于匹配脚本的 scopeId。
   */
  scopeId: string;
}

/**
 * 描述单个正则脚本执行前后的变更跟踪信息。
 */
export interface RegexApplyTrace {
  /**
   * 执行脚本的唯一标识。
   */
  scriptId: string;
  /**
   * 执行脚本的名称。
   */
  scriptName: string;
  /**
   * 当前执行所匹配的 placement 值。
   */
  placement: string;
  /**
   * 脚本执行前的文本内容。
   */
  before: string;
  /**
   * 脚本执行后的文本内容。
   */
  after: string;
  /**
   * 文本是否被本次执行修改。
   */
  changed: boolean;
  /**
   * 变更差异的简要描述，格式为"替换前 -> 替换后"。
   */
  diff: string;
}

/**
 * 描述正则脚本操作完成后返回给调用方的结果。
 */
export interface RegexApplyResult {
  /**
   * 处理完成后的最终文本内容。
   */
  text: string;
  /**
   * 所有脚本执行的变更轨迹列表。
   */
  traces: Array<RegexApplyTrace>;
}

/**
 * 描述正则脚本事件发布时携带的数据结构。
 */
export interface RegexAppliedPayload {
  /**
   * 单次脚本执行的轨迹信息。
   */
  trace: RegexApplyTrace;
}
