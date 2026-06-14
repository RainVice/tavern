/**
 * 定义作者注释模块使用的固定配置值，用于在对话中标识注入模块来源。
 */
export const AUTHOR_NOTE_MODULE_NAME: string = '2_floating_prompt';

/**
 * 描述作者注释的元数据配置，用于在对话中自动注入提示词，由角色或聊天维度配置触发。
 */
export interface AuthorNoteMetadata {
  /**
   * 作者注释的提示词内容，用于在对话到达注入时机时附加到上下文中的文本。
   */
  prompt: string;
  /**
   * 每隔多少条用户消息注入一次作者注释，用于控制注入频率。
   */
  interval: number;
  /**
   * 作者注释在对话上下文中的插入深度（从最新消息往前数），用于控制提示词影响范围。
   */
  depth: number;
  /**
   * 作者注释在上下文中的位置策略编号，用于决定注入内容在上下文中的摆放顺序。
   */
  position: number;
  /**
   * 注入时使用的角色标识编号，用于指定注入内容在消息历史中的发言角色。
   */
  role: number;
}

/**
 * 描述作者注释的默认配置值，在角色或聊天未覆盖时作为系统级回退值使用。
 */
export interface AuthorNoteDefaults {
  /**
   * 默认的作者注释提示词内容，当角色未提供自定义 prompt 时使用。
   */
  prompt: string;
  /**
   * 默认的注入间隔（用户消息条数），当角色未配置间隔时使用。
   */
  interval: number;
  /**
   * 默认的上下文插入深度，当角色未配置深度时使用。
   */
  depth: number;
  /**
   * 默认的位置策略编号，当角色未配置位置时使用。
   */
  position: number;
  /**
   * 默认的角色标识编号，当角色未配置角色时使用。
   */
  role: number;
  /**
   * 是否允许作者注释触发时扫描世界书（World Info），用于决定注入时是否需要激活世界书匹配。
   */
  allowWorldInfoScan: boolean;
}

/**
 * 描述角色级别的作者注释配置，可覆盖全局默认值，用于角色在某一维度上的自定义注入行为。
 */
export interface AuthorNoteCharacterNote {
  /**
   * 角色自定义的作者注释提示词内容，忽略时使用全局默认 prompt。
   */
  prompt: string;
  /**
   * 是否启用该角色的作者注释，用于控制该角色的注入开关。
   */
  enabled: boolean;
  /**
   * 角色注释与全局注释的拼接位置（前置/后置/替换），用于决定角色注释在注入中的角色优先级。
 */
  position: number;
}

/**
 * 描述调用作者注释注入构建功能时需要传入的参数，由聊天状态、元数据配置和可选的角色注释共同组成。
 */
export interface AuthorNoteBuildInput {
  /**
   * 当前聊天的唯一标识，用于将注入结果与特定聊天会话关联。
   */
  chatId: string;
  /**
   * 是否处于活跃的聊天会话中，用于决定是否执行注入逻辑。
   */
  inChat: boolean;
  /**
   * 当前聊天中用户消息的累计条数，用于计算距离下次注入的剩余消息数。
   */
  userMessageCount: number;
  /**
   * 作者注释的元数据配置，用于指定注入周期、位置等行为参数。
   */
  metadata: AuthorNoteMetadata;
  /**
   * 作者注释的默认配置，用于当元数据或角色配置中某个字段缺失时回退使用。
   */
  defaults: AuthorNoteDefaults;
  /**
   * 可选的角色级别作者注释配置，当角色有自定义注入需求时传入，可覆盖全局默认值。
   */
  characterNote?: AuthorNoteCharacterNote;
}

/**
 * 描述作者注释注入的数据结构，供 Prompt 构建器消费，包含注入时机、内容、位置和角色信息。
 */
export interface AuthorNoteInjection {
  /**
   * 注入模块的名称标识，用于 Prompt 构建器识别该注入来源模块。
   */
  moduleName: string;
  /**
   * 当前聊天的唯一标识，用于将注入内容关联到特定聊天会话。
   */
  chatId: string;
  /**
   * 要注入的提示词内容，即最终拼接后写入上下文的文本。
   */
  prompt: string;
  /**
   * 本次注入是否启用，用于控制注入内容是否实际写入上下文。
   */
  enabled: boolean;
  /**
   * 本次注入是否需要扫描世界书，用于触发世界书匹配流程。
   */
  shouldScanWorldInfo: boolean;
  /**
   * 距离下次注入还剩多少条用户消息，用于 UI 展示倒计时或提前准备资源。
   */
  messagesTillInsertion: number;
  /**
   * 注入位置策略编号，用于 Prompt 构建器决定将该内容放在上下文中哪个位置。
   */
  position: number;
  /**
   * 注入的上下文深度，用于指定注入内容在消息历史中的深度偏移。
   */
  depth: number;
  /**
   * 注入时使用的角色标识编号，用于指定注入内容的发言角色。
   */
  role: number;
}

/**
 * 描述作者注释事件发布时携带的数据结构，用于通知宿主或其他模块注入已完成。
 */
export interface AuthorNoteBuiltPayload {
  /**
   * 构建完成后的注入数据结构，供事件订阅者读取注入结果。
   */
  injection: AuthorNoteInjection;
}
