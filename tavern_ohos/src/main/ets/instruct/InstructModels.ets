export const INSTRUCT_NAMES_BEHAVIOR_NONE = 'none'; // 不在消息前添加角色名，用于 InstructState.names_behavior 的"不显示"模式
export const INSTRUCT_NAMES_BEHAVIOR_FORCE = 'force'; // 强制在非用户消息前添加角色名，用于 InstructState.names_behavior 的"强制非用户消息"模式
export const INSTRUCT_NAMES_BEHAVIOR_ALWAYS = 'always'; // 始终在消息前添加角色名，用于 InstructState.names_behavior 的"始终显示"模式

export const INSTRUCT_FORCE_OUTPUT_NONE = 0; // 不使用强制输出序列，由 formatChatMessage 等方法按消息角色自动选择输出序列
export const INSTRUCT_FORCE_OUTPUT_FIRST = 1; // 强制使用 first output sequence，用于第一条 AI 输出消息的特殊序列覆盖
export const INSTRUCT_FORCE_OUTPUT_LAST = 2; // 强制使用 last output sequence，用于最后一条 AI 输出消息的特殊序列覆盖

/**
 * 描述指令模板预设的配置项集合，定义了对话消息的序列标记和行为设置。
 * 用于 InstructRuntime.loadPresets() 加载预设列表，以及 selectPreset() 选择和应用预设。
 */
export interface InstructPreset {
  /**
   * 预设名称，也用作内存索引 Map 的唯一键，用于查找和引用预设。
   */
  name: string;
  /**
   * 是否启用该预设，用于控制该预设是否可自动通过 activation_regex 匹配。
   */
  enabled?: boolean;
  /**
   * 预设标识，用于 UI 显示当前使用的预设名称。
   */
  preset?: string;
  /**
   * 用户输入消息的前缀序列标记，在 formatChatMessage() 中根据消息角色决定使用用户还是 AI 的序列。
   */
  input_sequence?: string;
  /**
   * 用户输入消息的后缀序列标记，在 formatChatMessage() 中追加到消息文本之后。
   */
  input_suffix?: string;
  /**
   * AI 输出消息的前缀序列标记，在 formatChatMessage() 中根据消息角色确定是否使用。
   */
  output_sequence?: string;
  /**
   * AI 输出消息的后缀序列标记，在 formatChatMessage() 中追加到 AI 消息文本之后。
   */
  output_suffix?: string;
  /**
   * 系统消息的前缀序列标记，在 formatChatMessage() 中 for narrator 消息时使用。
   */
  system_sequence?: string;
  /**
   * 系统消息的后缀序列标记，在 formatChatMessage() 中追加到系统/旁白消息之后。
   */
  system_suffix?: string;
  /**
   * 最后一条系统消息的前缀序列标记，在 formatPromptLine() 中 for 静默消息时优先使用。
   */
  last_system_sequence?: string;
  /**
   * 第一条用户消息的前缀序列标记（覆盖 input_sequence），在 formatChatMessage() 中 forceOutputSequence 为 FIRST 时优先使用。
   */
  first_input_sequence?: string;
  /**
   * 第一条 AI 输出的前缀序列标记（覆盖 output_sequence），在 formatChatMessage() 中 forceOutputSequence 为 FIRST 时优先使用。
   */
  first_output_sequence?: string;
  /**
   * 最后一条用户消息的前缀序列标记（覆盖 input_sequence），在 formatChatMessage() 中 forceOutputSequence 为 LAST 时优先使用。
   */
  last_input_sequence?: string;
  /**
   * 最后一条 AI 输出的前缀序列标记（覆盖 output_sequence），在 formatChatMessage() 中 forceOutputSequence 为 LAST 时优先使用。
   */
  last_output_sequence?: string;
  /**
   * 故事文本的前缀序列标记，在 formatStoryString() 中非嵌入位置时添加到故事文本之前。
   */
  story_string_prefix?: string;
  /**
   * 故事文本的后缀序列标记，在 formatStoryString() 中非嵌入位置时添加到故事文本之后。
   */
  story_string_suffix?: string;
  /**
   * 停止序列标记，当模型输出此内容时停止生成，在 getStoppingSequences() 中收集用于控制生成终止条件。
   */
  stop_sequence?: string;
  /**
   * 是否在序列标记前后添加换行，在 formatChatMessage() 和 formatStoryString() 中决定消息体换行策略。
   */
  wrap?: boolean;
  /**
   * 是否启用宏替换（如 {{name}} 替换为角色名），在 formatChatMessage() 和 formatStoryString() 中控制是否执行模板变量替换。
   */
  macro?: boolean;
  /**
   * 角色名显示行为：none/force/always，在 formatChatMessage() 和 formatPromptLine() 中决定消息前是否包含角色名。
   */
  names_behavior?: string;
  /**
   * 用于模型自动匹配预设的正则表达式，在 autoSelectPreset() 中根据模型 ID 匹配预设。
   */
  activation_regex?: string;
  /**
   * 是否绑定到上下文预设，在 autoSelectPreset() 中控制是否将上下文预设作为后备匹配。
   */
  bind_to_context?: boolean;
  /**
   * 是否跳过示例对话，用于控制对话构造时是否包含 example messages。
   */
  skip_examples?: boolean;
  /**
   * 用户对齐消息，在对话开始时插入的对齐文本，用于让模型理解对话格式。
   */
  user_alignment_message?: string;
  /**
   * 系统消息是否使用与用户消息相同的序列标记，在 getMessagePrefix() 中决定旁白消息的前缀策略。
   */
  system_same_as_user?: boolean;
  /**
   * 是否将序列标记也作为停止字符串，在 getStoppingSequences() 中决定是否将 input/output/system 序列标记添加到停止序列列表。
   */
  sequences_as_stop_strings?: boolean;
  /**
   * 分隔符序列，用于替代 output_suffix，在 normalizePreset() 中兼容旧格式字段。
   */
  separator_sequence?: string;
  /**
   * 是否在消息中显示角色名，在 normalizePreset() 中转换为 names_behavior 的设置（兼容旧格式）。
   */
  names?: boolean;
  /**
   * 是否强制分组显示角色名，在 normalizePreset() 中转换为 names_behavior 的设置（兼容旧格式）。
   */
  names_force_groups?: boolean;
}

/**
 * 描述指令模板当前运行时的完整状态配置。
 * 由 selectPreset() 或 updateState() 维护，用于 formatChatMessage()、getStoppingSequences() 等消息格式化方法。
 */
export interface InstructState {
  /**
   * 是否启用指令模板，控制选中的预设是否生效。为 false 时 formatChatMessage() 等仍可使用但标记为未启用。
   */
  enabled: boolean;
  /**
   * 当前选中的预设名称，用于 UI 显示和 selectPreset() 查找。
   */
  preset: string;
  /**
   * 用户输入消息的前缀序列标记，用于 formatChatMessage() 处理用户消息和 formatPromptLine() 选择序列。
   */
  input_sequence: string;
  /**
   * 用户输入消息的后缀序列标记，用于 formatChatMessage() 追加到用户消息文本后。
   */
  input_suffix: string;
  /**
   * AI 输出消息的前缀序列标记，用于 formatChatMessage() 处理 AI 响应消息。
   */
  output_sequence: string;
  /**
   * AI 输出消息的后缀序列标记，用于 formatChatMessage() 追加到 AI 消息文本后。
   */
  output_suffix: string;
  /**
   * 系统消息的前缀序列标记，用于 formatChatMessage() 处理旁白/系统消息。
   */
  system_sequence: string;
  /**
   * 系统消息的后缀序列标记，用于 formatChatMessage() 追加到系统/旁白消息后。
   */
  system_suffix: string;
  /**
   * 最后一条系统消息的前缀序列标记，用于 formatPromptLine() 中静默消息的特殊序列处理。
   */
  last_system_sequence: string;
  /**
   * 第一条用户消息的前缀序列标记，用于 formatChatMessage() 中强制第一条输入序列。
   */
  first_input_sequence: string;
  /**
   * 第一条 AI 输出的前缀序列标记，用于 formatChatMessage() 中强制第一条输出序列。
   */
  first_output_sequence: string;
  /**
   * 最后一条用户消息的前缀序列标记，用于 formatChatMessage() 中强制最后一条输入序列。
   */
  last_input_sequence: string;
  /**
   * 最后一条 AI 输出的前缀序列标记，用于 formatChatMessage() 和 formatPromptLine() 中强制最后一条输出序列。
   */
  last_output_sequence: string;
  /**
   * 故事文本的前缀序列标记，用于 formatStoryString() 非嵌入位置时的前缀添加。
   */
  story_string_prefix: string;
  /**
   * 故事文本的后缀序列标记，用于 formatStoryString() 非嵌入位置时的后缀添加。
   */
  story_string_suffix: string;
  /**
   * 停止序列标记，用于 getStoppingSequences() 收集停止条件，当模型输出此内容时终止生成。
   */
  stop_sequence: string;
  /**
   * 是否在序列标记前后添加换行，用于 formatChatMessage() 和 formatStoryString() 得消息格式化换行策略。
   */
  wrap: boolean;
  /**
   * 是否启用宏替换（如 {{name}} 替换为角色名），用于控制 formatChatMessage() 中的模板变量替换。
   */
  macro: boolean;
  /**
   * 角色名显示行为，用于 formatChatMessage() 和 formatPromptLine() 判断是否在消息前包含角色名。
   */
  names_behavior: string;
  /**
   * 用于模型自动匹配预设的正则表达式，用于 autoSelectPreset() 按模型 ID 匹配预设。
   */
  activation_regex: string;
  /**
   * 是否绑定到上下文预设，用于 autoSelectPreset() 控制上下文预设作为后备匹配策略。
   */
  bind_to_context: boolean;
  /**
   * 是否跳过示例对话，用于对话构造时控制是否包含示例消息。
   */
  skip_examples: boolean;
  /**
   * 用户对齐消息文本，用于对话构造流程，在对话开始时插入引导文本。
   */
  user_alignment_message: string;
  /**
   * 系统消息是否使用与用户消息相同的序列标记，用于 getMessagePrefix() 决定旁白消息的前缀策略。
   */
  system_same_as_user: boolean;
  /**
   * 是否将序列标记也作为停止字符串，用于 getStoppingSequences() 决定额外停止序列的收集策略。
   */
  sequences_as_stop_strings: boolean;
}

/**
 * 描述指令模板状态的部分更新字段，所有字段均为可选项。
 * 用于 updateState() 更新部分指令模板状态，无需传入完整状态对象。
 */
export interface InstructStatePatch {
  /**
   * 是否启用指令模板。
   */
  enabled?: boolean;
  /**
   * 当前选中的预设名称。
   */
  preset?: string;
  /**
   * 用户输入消息的前缀序列标记。
   */
  input_sequence?: string;
  /**
   * 用户输入消息的后缀序列标记。
   */
  input_suffix?: string;
  /**
   * AI 输出消息的前缀序列标记。
   */
  output_sequence?: string;
  /**
   * AI 输出消息的后缀序列标记。
   */
  output_suffix?: string;
  /**
   * 系统消息的前缀序列标记。
   */
  system_sequence?: string;
  /**
   * 系统消息的后缀序列标记。
   */
  system_suffix?: string;
  /**
   * 最后一条系统消息的前缀序列标记。
   */
  last_system_sequence?: string;
  /**
   * 第一条用户消息的前缀序列标记。
   */
  first_input_sequence?: string;
  /**
   * 第一条 AI 输出的前缀序列标记。
   */
  first_output_sequence?: string;
  /**
   * 最后一条用户消息的前缀序列标记。
   */
  last_input_sequence?: string;
  /**
   * 最后一条 AI 输出的前缀序列标记。
   */
  last_output_sequence?: string;
  /**
   * 故事文本的前缀序列标记。
   */
  story_string_prefix?: string;
  /**
   * 故事文本的后缀序列标记。
   */
  story_string_suffix?: string;
  /**
   * 停止序列标记。
   */
  stop_sequence?: string;
  /**
   * 是否在序列标记前后添加换行。
   */
  wrap?: boolean;
  /**
   * 是否启用宏替换。
   */
  macro?: boolean;
  /**
   * 角色名显示行为。
   */
  names_behavior?: string;
  /**
   * 用于模型自动匹配预设的正则表达式。
   */
  activation_regex?: string;
  /**
   * 是否绑定到上下文预设。
   */
  bind_to_context?: boolean;
  /**
   * 是否跳过示例对话。
   */
  skip_examples?: boolean;
  /**
   * 用户对齐消息文本。
   */
  user_alignment_message?: string;
  /**
   * 系统消息是否使用与用户消息相同的序列标记。
   */
  system_same_as_user?: boolean;
  /**
   * 是否将序列标记也作为停止字符串。
   */
  sequences_as_stop_strings?: boolean;
}

/**
 * 描述指令模板上下文配置，控制对话开始和示例分隔行为。
 * 用于对话构造流程，在构造完整对话时添加 chat_start 和 example_separator 等结构标记。
 */
export interface InstructContextState {
  /**
   * 对话起始标记文本，在 getStoppingSequences() 中作为停止序列的一部分，在对话格式化时用于构建完整上下文。
   */
  chat_start: string;
  /**
   * 示例对话与真实对话之间的分隔符，在 getStoppingSequences() 中作为停止序列的一部分。
   */
  example_separator: string;
  /**
   * 是否使用停止字符串机制，在 getStoppingSequences() 中控制是否将 chat_start 和 example_separator 加入停止序列。
   */
  use_stop_strings: boolean;
  /**
   * 故事文本是否嵌入在聊天上下文内部，在 formatStoryString() 中决定前缀/后缀序列标记是否应用到故事文本。
   */
  story_string_position_in_chat: boolean;
}

/**
 * 描述指令模板上下文配置的部分更新字段，所有字段均为可选项。
 * 用于 updateContext() 更新部分上下文配置。
 */
export interface InstructContextStatePatch {
  /**
   * 对话起始标记文本。
   */
  chat_start?: string;
  /**
   * 示例对话与真实对话之间的分隔符。
   */
  example_separator?: string;
  /**
   * 是否使用停止字符串机制。
   */
  use_stop_strings?: boolean;
  /**
   * 故事文本是否嵌入在聊天上下文内部。
   */
  story_string_position_in_chat?: boolean;
}

/**
 * 描述模型模板映射关系，将模型 ID 关联到指令模板和上下文模板。
 * 用于 autoSelectPreset() 精确匹配模型到模板的映射，优先于 activation_regex 匹配。
 */
export interface InstructTemplateMapping {
  /**
   * 指令模板名称，用于 autoSelectPreset() 选择对应的指令预设。
   */
  instruct: string;
  /**
   * 上下文模板名称，用于 autoSelectPreset() 选择对应的上下文预设。
   */
  context: string;
}

/**
 * 描述指令模板状态变更事件发布时携带的数据结构。
 * 用于 publishState() 发布 'instruct.selected' 或 'instruct.state.changed' 事件，通知 UI 层和外部模块状态已更新。
 */
export interface InstructStatePayload {
  /**
   * 变更后的完整状态对象，订阅者据此更新 UI 显示或同步状态到持久化存储。
   */
  state: InstructState;
}
