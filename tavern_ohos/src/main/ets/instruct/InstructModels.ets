/**
 * 角色名从不出现的模式，适用于无角色区分场景。
 */
export const INSTRUCT_NAMES_BEHAVIOR_NONE = 'none';
/**
 * 角色名强制始终出现，适用于需明确区分角色的场景。
 */
export const INSTRUCT_NAMES_BEHAVIOR_FORCE = 'force';
/**
 * 角色名始终出现（与用户角色无关），适用于全角色标注场景。
 */
export const INSTRUCT_NAMES_BEHAVIOR_ALWAYS = 'always';

/**
 * 不强制使用特定输出序列，按当前角色类型选择。
 */
export const INSTRUCT_FORCE_OUTPUT_NONE = 0;
/**
 * 强制使用 first 系列输出序列，适用于开场消息。
 */
export const INSTRUCT_FORCE_OUTPUT_FIRST = 1;
/**
 * 强制使用 last 系列输出序列，适用于收尾消息。
 */
export const INSTRUCT_FORCE_OUTPUT_LAST = 2;

/**
 * 指令模板预设的完整数据模型，包含所有可配置的模板参数。
 * 各字段值在加载或运行时由 InstructRuntime 填充维护。
 */
export interface InstructPreset {
  /**
   * 模板预设的唯一标识名称。
   */
  name: string;
  /**
   * 是否启用此预设。
   */
  enabled?: boolean;
  /**
   * 预设标识，用于区分不同来源的模板配置。
   */
  preset?: string;
  /**
   * 用户输入消息的前缀标记。
   */
  input_sequence?: string;
  /**
   * 用户输入消息的后缀标记。
   */
  input_suffix?: string;
  /**
   * 模型输出消息的前缀标记。
   */
  output_sequence?: string;
  /**
   * 模型输出消息的后缀标记。
   */
  output_suffix?: string;
  /**
   * 系统提示消息的前缀标记。
   */
  system_sequence?: string;
  /**
   * 系统提示消息的后缀标记。
   */
  system_suffix?: string;
  /**
   * 最后一条系统消息的前缀标记。
   */
  last_system_sequence?: string;
  /**
   * 首条用户输入的前缀标记。
   */
  first_input_sequence?: string;
  /**
   * 首条模型输出的前缀标记。
   */
  first_output_sequence?: string;
  /**
   * 末条用户输入的前缀标记。
   */
  last_input_sequence?: string;
  /**
   * 末条模型输出的前缀标记。
   */
  last_output_sequence?: string;
  /**
   * 故事字符串的前缀，用于注入系统叙事上下文。
   */
  story_string_prefix?: string;
  /**
   * 故事字符串的后缀。
   */
  story_string_suffix?: string;
  /**
   * 停止序列标记，模型生成遇到此标记时停止。
   */
  stop_sequence?: string;
  /**
   * 是否在序列标记前后添加换行包裹。
   */
  wrap?: boolean;
  /**
   * 是否启用宏替换（如 {{name}}、{{name1}}、{{name2}}）。
   */
  macro?: boolean;
  /**
   * 角色名出现行为模式：none / force / always。
   */
  names_behavior?: string;
  /**
   * 激活此预设的正则表达式，匹配模型 ID 时自动选择。
   */
  activation_regex?: string;
  /**
   * 是否绑定到对话上下文预设。
   */
  bind_to_context?: boolean;
  /**
   * 是否跳过示例消息的格式化。
   */
  skip_examples?: boolean;
  /**
   * 用户对齐消息，用于首个用户消息前的额外上下文。
   */
  user_alignment_message?: string;
  /**
   * 系统消息是否与用户消息使用相同的前缀后缀。
   */
  system_same_as_user?: boolean;
  /**
   * 是否将序列标记加入停止字符串列表。
   */
  sequences_as_stop_strings?: boolean;
  /**
   * 分隔符序列（已废弃，兼容旧数据时映射为 output_suffix）。
   */
  separator_sequence?: string;
  /**
   * 是否包含角色名（已废弃，兼容旧数据时映射为 names_behavior）。
   */
  names?: boolean;
  /**
   * 是否强制分组角色名（已废弃，兼容旧数据时映射为 names_behavior）。
   */
  names_force_groups?: boolean;
}

/**
 * 指令模板的运行时可变状态，不含可选字段。
 * 与 InstructPreset 结构对应用来反映当前生效的模板配置。
 */
export interface InstructState {
  /**
   * 当前是否启用指令模板格式化。
   */
  enabled: boolean;
  /**
   * 当前选中的预设标识。
   */
  preset: string;
  /**
   * 用户输入消息的前缀标记。
   */
  input_sequence: string;
  /**
   * 用户输入消息的后缀标记。
   */
  input_suffix: string;
  /**
   * 模型输出消息的前缀标记。
   */
  output_sequence: string;
  /**
   * 模型输出消息的后缀标记。
   */
  output_suffix: string;
  /**
   * 系统提示消息的前缀标记。
   */
  system_sequence: string;
  /**
   * 系统提示消息的后缀标记。
   */
  system_suffix: string;
  /**
   * 最后一条系统消息的前缀标记。
   */
  last_system_sequence: string;
  /**
   * 首条用户输入的前缀标记。
   */
  first_input_sequence: string;
  /**
   * 首条模型输出的前缀标记。
   */
  first_output_sequence: string;
  /**
   * 末条用户输入的前缀标记。
   */
  last_input_sequence: string;
  /**
   * 末条模型输出的前缀标记。
   */
  last_output_sequence: string;
  /**
   * 故事字符串的前缀。
   */
  story_string_prefix: string;
  /**
   * 故事字符串的后缀。
   */
  story_string_suffix: string;
  /**
   * 停止序列标记。
   */
  stop_sequence: string;
  /**
   * 是否在序列标记前后添加换行包裹。
   */
  wrap: boolean;
  /**
   * 是否启用宏替换。
   */
  macro: boolean;
  /**
   * 角色名出现行为模式。
   */
  names_behavior: string;
  /**
   * 激活正则表达式。
   */
  activation_regex: string;
  /**
   * 是否绑定到对话上下文预设。
   */
  bind_to_context: boolean;
  /**
   * 是否跳过示例消息的格式化。
   */
  skip_examples: boolean;
  /**
   * 用户对齐消息。
   */
  user_alignment_message: string;
  /**
   * 系统消息是否与用户消息使用相同的前缀后缀。
   */
  system_same_as_user: boolean;
  /**
   * 是否将序列标记加入停止字符串列表。
   */
  sequences_as_stop_strings: boolean;
}

/**
 * 指令模板运行时状态的部分更新模型，所有字段可选。
 * 用于向 InstructRuntime.updateState() 传递增量变更。
 */
export interface InstructStatePatch {
  /**
   * 是否启用指令模板格式化。
   */
  enabled?: boolean;
  /**
   * 当前选中的预设标识。
   */
  preset?: string;
  /**
   * 用户输入消息的前缀标记。
   */
  input_sequence?: string;
  /**
   * 用户输入消息的后缀标记。
   */
  input_suffix?: string;
  /**
   * 模型输出消息的前缀标记。
   */
  output_sequence?: string;
  /**
   * 模型输出消息的后缀标记。
   */
  output_suffix?: string;
  /**
   * 系统提示消息的前缀标记。
   */
  system_sequence?: string;
  /**
   * 系统提示消息的后缀标记。
   */
  system_suffix?: string;
  /**
   * 最后一条系统消息的前缀标记。
   */
  last_system_sequence?: string;
  /**
   * 首条用户输入的前缀标记。
   */
  first_input_sequence?: string;
  /**
   * 首条模型输出的前缀标记。
   */
  first_output_sequence?: string;
  /**
   * 末条用户输入的前缀标记。
   */
  last_input_sequence?: string;
  /**
   * 末条模型输出的前缀标记。
   */
  last_output_sequence?: string;
  /**
   * 故事字符串的前缀。
   */
  story_string_prefix?: string;
  /**
   * 故事字符串的后缀。
   */
  story_string_suffix?: string;
  /**
   * 停止序列标记。
   */
  stop_sequence?: string;
  /**
   * 是否在序列标记前后添加换行包裹。
   */
  wrap?: boolean;
  /**
   * 是否启用宏替换。
   */
  macro?: boolean;
  /**
   * 角色名出现行为模式。
   */
  names_behavior?: string;
  /**
   * 激活正则表达式。
   */
  activation_regex?: string;
  /**
   * 是否绑定到对话上下文预设。
   */
  bind_to_context?: boolean;
  /**
   * 是否跳过示例消息的格式化。
   */
  skip_examples?: boolean;
  /**
   * 用户对齐消息。
   */
  user_alignment_message?: string;
  /**
   * 系统消息是否与用户消息使用相同的前缀后缀。
   */
  system_same_as_user?: boolean;
  /**
   * 是否将序列标记加入停止字符串列表。
   */
  sequences_as_stop_strings?: boolean;
}

/**
 * 对话上下文的指令模板配置，控制示例分隔、停止字符串及故事字符串位置。
 */
export interface InstructContextState {
  /**
   * 对话起始标记，插入在首条消息之前。
   */
  chat_start: string;
  /**
   * 示例消息之间的分隔标记。
   */
  example_separator: string;
  /**
   * 是否使用停止字符串机制来终止模型生成。
   */
  use_stop_strings: boolean;
  /**
   * 故事字符串在对话中的位置（首部或尾部）。
   */
  story_string_position_in_chat: boolean;
}

/**
 * 对话上下文指令模板配置的部分更新模型，所有字段可选。
 */
export interface InstructContextStatePatch {
  /**
   * 对话起始标记。
   */
  chat_start?: string;
  /**
   * 示例消息之间的分隔标记。
   */
  example_separator?: string;
  /**
   * 是否使用停止字符串机制。
   */
  use_stop_strings?: boolean;
  /**
   * 故事字符串在对话中的位置。
   */
  story_string_position_in_chat?: boolean;
}

/**
 * 指令模板的模型模板映射，将模型 ID 关联到具体的 instruct 和 context 预设名称。
 */
export interface InstructTemplateMapping {
  /**
   * 指令模板预设名称。
   */
  instruct: string;
  /**
   * 上下文指令预设名称。
   */
  context: string;
}

/**
 * 指令模板事件发布时携带的负载数据，包含当前状态快照。
 */
export interface InstructStatePayload {
  /**
   * 当前指令模板状态副本。
   */
  state: InstructState;
}
