/**
 * 描述正则脚本持久化或内存索引中的一条记录。
 */
export interface RegexScriptRecord {
  /**
   * 正则脚本唯一标识，用于在数组中索引和更新该脚本。
   */
  id: string;
  /**
   * 脚本显示名称，用于 UI 列表展示和用户识别。
   */
  scriptName: string;
  /**
   * 脚本来源类型（如 local、imported 等），用于区分用户自建和外部导入的脚本。
   */
  sourceType: string;
  /**
   * 作用域标识，限制该脚本仅在特定范围内生效——与输入上下文的 scopeId 匹配才能执行。
   */
  scopeId: string;
  /**
   * 用于匹配文本的正则表达式字符串，作为替换操作的匹配模式。
   */
  findRegex: string;
  /**
   * 正则匹配标志（如 g、i、m 等），控制正则的全局搜索、大小写不敏感等行为。
   */
  flags: string;
  /**
   * 替换匹配结果的字符串，支持 $& 引用原始匹配；也支持 {{match}} 占位符自动转换为 $&。
   */
  replaceString: string;
  /**
   * 脚本生效的 placement 列表（如 before_prompt、after_prompt 等），决定在 Prompt 处理的哪个阶段执行该脚本。
   */
  placements: Array<string>;
  /**
   * 脚本是否被禁用，禁用时不参与任何替换流程。
   */
  disabled: boolean;
  /**
   * 是否仅在 Markdown 格式内容上执行，用于按内容格式过滤执行条件。
   */
  markdownOnly: boolean;
  /**
   * 是否仅在 Prompt 内容上执行，用于按内容类型过滤执行条件。
   */
  promptOnly: boolean;
  /**
   * 是否在编辑操作时自动执行，用于按操作类型过滤执行条件——编辑场景下触发。
   */
  runOnEdit: boolean;
  /**
   * 脚本执行的最小递归深度阈值，低于此深度不执行——用于嵌套处理中的深度控制。
   */
  minDepth: number;
  /**
   * 脚本执行的最大递归深度阈值，高于此深度不执行——用于防止无限递归。
   */
  maxDepth: number;
  /**
   * 脚本是否为临时性的（重启后不持久化），用于一次性或会话级别的正则替换。
   */
  ephemeral: boolean;
  /**
   * 需要从文本中移除的字符串列表，在正则替换后执行——用于清理多余的空格或特定标记。
   */
  trimStrings: Array<string>;
}

/**
 * 描述调用正则脚本能力时需要传入的参数。
 */
export interface RegexApplyInput {
  /**
   * 待处理的原始文本，将依次经过所有匹配条件的正则脚本处理。
   */
  text: string;
  /**
   * 当前处理的 placement 阶段（如 before_prompt、after_prompt 等），用于筛选匹配的脚本。
   */
  placement: string;
  /**
   * 当前文本是否为 Markdown 格式，用于匹配脚本的 markdownOnly 过滤条件。
   */
  isMarkdown: boolean;
  /**
   * 当前文本是否为 Prompt 内容，用于匹配脚本的 promptOnly 过滤条件。
   */
  isPrompt: boolean;
  /**
   * 当前是否为编辑操作，用于匹配脚本的 runOnEdit 过滤条件。
   */
  isEdit: boolean;
  /**
   * 当前处理深度，用于匹配脚本的 minDepth/maxDepth 阈值——在嵌套替换场景中递增。
   */
  depth: number;
  /**
   * 当前处理的作用域标识，用于匹配脚本的 scopeId 过滤条件。
   */
  scopeId: string;
}

/**
 * 描述正则脚本模块在运行时交换的数据结构。
 */
export interface RegexApplyTrace {
  /**
   * 执行的脚本标识，用于追踪是哪条脚本执行的替换。
   */
  scriptId: string;
  /**
   * 执行的脚本名称，用于日志和调试输出以便识别替换来源。
   */
  scriptName: string;
  /**
   * 执行时的 placement 阶段，记录替换发生的处理阶段上下文。
   */
  placement: string;
  /**
   * 替换前的文本内容，用于对比替换效果和调试。
   */
  before: string;
  /**
   * 替换后的文本内容，用于对比替换效果和调试。
   */
  after: string;
  /**
   * 文本是否发生了实际变更，用于判断替换是否真正生效。
   */
  changed: boolean;
  /**
   * 变更差异描述（格式："替换前 -> 替换后"），用于快速浏览替换效果。
   */
  diff: string;
}

/**
 * 描述正则脚本操作完成后返回给调用方的结果。
 */
export interface RegexApplyResult {
  /**
   * 经过所有匹配脚本处理后的最终文本，由调用方用于后续流程（如发送给 LLM 或展示）。
   */
  text: string;
  /**
   * 所有成功执行的正则替换追踪记录，用于调试或审计每次替换的详情。
   */
  traces: Array<RegexApplyTrace>;
}

/**
 * 描述正则脚本事件发布时携带的数据结构。
 */
export interface RegexAppliedPayload {
  /**
   * 最近一次正则替换的追踪记录，用于通知监听方（如 UI 调试面板）替换已执行。
   */
  trace: RegexApplyTrace;
}
