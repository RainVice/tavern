/**
 * 定义指令模板模块使用的固定配置值。
 */
export const INSTRUCT_NAMES_BEHAVIOR_NONE = 'none';
/**
 * 定义指令模板模块使用的固定配置值。
 */
export const INSTRUCT_NAMES_BEHAVIOR_FORCE = 'force';
/**
 * 定义指令模板模块使用的固定配置值。
 */
export const INSTRUCT_NAMES_BEHAVIOR_ALWAYS = 'always';

/**
 * 定义指令模板模块使用的固定配置值。
 */
export const INSTRUCT_FORCE_OUTPUT_NONE = 0;
/**
 * 定义指令模板模块使用的固定配置值。
 */
export const INSTRUCT_FORCE_OUTPUT_FIRST = 1;
/**
 * 定义指令模板模块使用的固定配置值。
 */
export const INSTRUCT_FORCE_OUTPUT_LAST = 2;

/**
 * 描述指令模板模块在运行时交换的数据结构。
 */
export interface InstructPreset {
  /**
   * 名称。
   */
  name: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled?: boolean;
  /**
   * preset 值，由当前实例内部维护。
   */
  preset?: string;
  /**
   * input sequence 值，由当前实例内部维护。
   */
  input_sequence?: string;
  /**
   * input suffix 值，由当前实例内部维护。
   */
  input_suffix?: string;
  /**
   * output sequence 值，由当前实例内部维护。
   */
  output_sequence?: string;
  /**
   * output suffix 值，由当前实例内部维护。
   */
  output_suffix?: string;
  /**
   * system sequence 值，由当前实例内部维护。
   */
  system_sequence?: string;
  /**
   * system suffix 值，由当前实例内部维护。
   */
  system_suffix?: string;
  /**
   * last system sequence 值，由当前实例内部维护。
   */
  last_system_sequence?: string;
  /**
   * first input sequence 值，由当前实例内部维护。
   */
  first_input_sequence?: string;
  /**
   * first output sequence 值，由当前实例内部维护。
   */
  first_output_sequence?: string;
  /**
   * last input sequence 值，由当前实例内部维护。
   */
  last_input_sequence?: string;
  /**
   * last output sequence 值，由当前实例内部维护。
   */
  last_output_sequence?: string;
  /**
   * story string prefix 值，由当前实例内部维护。
   */
  story_string_prefix?: string;
  /**
   * story string suffix 值，由当前实例内部维护。
   */
  story_string_suffix?: string;
  /**
   * stop sequence 值，由当前实例内部维护。
   */
  stop_sequence?: string;
  /**
   * wrap 值，由当前实例内部维护。
   */
  wrap?: boolean;
  /**
   * macro 值，由当前实例内部维护。
   */
  macro?: boolean;
  /**
   * names behavior 值，由当前实例内部维护。
   */
  names_behavior?: string;
  /**
   * activation regex 值，由当前实例内部维护。
   */
  activation_regex?: string;
  /**
   * bind to context 值，由当前实例内部维护。
   */
  bind_to_context?: boolean;
  /**
   * skip examples 列表，由当前实例内部维护。
   */
  skip_examples?: boolean;
  /**
   * user alignment message 值，由当前实例内部维护。
   */
  user_alignment_message?: string;
  /**
   * system same as user 值，由当前实例内部维护。
   */
  system_same_as_user?: boolean;
  /**
   * sequences as stop strings 列表，由当前实例内部维护。
   */
  sequences_as_stop_strings?: boolean;
  /**
   * separator sequence 值，由当前实例内部维护。
   */
  separator_sequence?: string;
  /**
   * names 列表，由当前实例内部维护。
   */
  names?: boolean;
  /**
   * names force groups 列表，由当前实例内部维护。
   */
  names_force_groups?: boolean;
}

/**
 * 描述指令模板模块在运行时交换的数据结构。
 */
export interface InstructState {
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * preset 值，由当前实例内部维护。
   */
  preset: string;
  /**
   * input sequence 值，由当前实例内部维护。
   */
  input_sequence: string;
  /**
   * input suffix 值，由当前实例内部维护。
   */
  input_suffix: string;
  /**
   * output sequence 值，由当前实例内部维护。
   */
  output_sequence: string;
  /**
   * output suffix 值，由当前实例内部维护。
   */
  output_suffix: string;
  /**
   * system sequence 值，由当前实例内部维护。
   */
  system_sequence: string;
  /**
   * system suffix 值，由当前实例内部维护。
   */
  system_suffix: string;
  /**
   * last system sequence 值，由当前实例内部维护。
   */
  last_system_sequence: string;
  /**
   * first input sequence 值，由当前实例内部维护。
   */
  first_input_sequence: string;
  /**
   * first output sequence 值，由当前实例内部维护。
   */
  first_output_sequence: string;
  /**
   * last input sequence 值，由当前实例内部维护。
   */
  last_input_sequence: string;
  /**
   * last output sequence 值，由当前实例内部维护。
   */
  last_output_sequence: string;
  /**
   * story string prefix 值，由当前实例内部维护。
   */
  story_string_prefix: string;
  /**
   * story string suffix 值，由当前实例内部维护。
   */
  story_string_suffix: string;
  /**
   * stop sequence 值，由当前实例内部维护。
   */
  stop_sequence: string;
  /**
   * wrap 值，由当前实例内部维护。
   */
  wrap: boolean;
  /**
   * macro 值，由当前实例内部维护。
   */
  macro: boolean;
  /**
   * names behavior 值，由当前实例内部维护。
   */
  names_behavior: string;
  /**
   * activation regex 值，由当前实例内部维护。
   */
  activation_regex: string;
  /**
   * bind to context 值，由当前实例内部维护。
   */
  bind_to_context: boolean;
  /**
   * skip examples 列表，由当前实例内部维护。
   */
  skip_examples: boolean;
  /**
   * user alignment message 值，由当前实例内部维护。
   */
  user_alignment_message: string;
  /**
   * system same as user 值，由当前实例内部维护。
   */
  system_same_as_user: boolean;
  /**
   * sequences as stop strings 列表，由当前实例内部维护。
   */
  sequences_as_stop_strings: boolean;
}

/**
 * 描述指令模板模块在运行时交换的数据结构。
 */
export interface InstructStatePatch {
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled?: boolean;
  /**
   * preset 值，由当前实例内部维护。
   */
  preset?: string;
  /**
   * input sequence 值，由当前实例内部维护。
   */
  input_sequence?: string;
  /**
   * input suffix 值，由当前实例内部维护。
   */
  input_suffix?: string;
  /**
   * output sequence 值，由当前实例内部维护。
   */
  output_sequence?: string;
  /**
   * output suffix 值，由当前实例内部维护。
   */
  output_suffix?: string;
  /**
   * system sequence 值，由当前实例内部维护。
   */
  system_sequence?: string;
  /**
   * system suffix 值，由当前实例内部维护。
   */
  system_suffix?: string;
  /**
   * last system sequence 值，由当前实例内部维护。
   */
  last_system_sequence?: string;
  /**
   * first input sequence 值，由当前实例内部维护。
   */
  first_input_sequence?: string;
  /**
   * first output sequence 值，由当前实例内部维护。
   */
  first_output_sequence?: string;
  /**
   * last input sequence 值，由当前实例内部维护。
   */
  last_input_sequence?: string;
  /**
   * last output sequence 值，由当前实例内部维护。
   */
  last_output_sequence?: string;
  /**
   * story string prefix 值，由当前实例内部维护。
   */
  story_string_prefix?: string;
  /**
   * story string suffix 值，由当前实例内部维护。
   */
  story_string_suffix?: string;
  /**
   * stop sequence 值，由当前实例内部维护。
   */
  stop_sequence?: string;
  /**
   * wrap 值，由当前实例内部维护。
   */
  wrap?: boolean;
  /**
   * macro 值，由当前实例内部维护。
   */
  macro?: boolean;
  /**
   * names behavior 值，由当前实例内部维护。
   */
  names_behavior?: string;
  /**
   * activation regex 值，由当前实例内部维护。
   */
  activation_regex?: string;
  /**
   * bind to context 值，由当前实例内部维护。
   */
  bind_to_context?: boolean;
  /**
   * skip examples 列表，由当前实例内部维护。
   */
  skip_examples?: boolean;
  /**
   * user alignment message 值，由当前实例内部维护。
   */
  user_alignment_message?: string;
  /**
   * system same as user 值，由当前实例内部维护。
   */
  system_same_as_user?: boolean;
  /**
   * sequences as stop strings 列表，由当前实例内部维护。
   */
  sequences_as_stop_strings?: boolean;
}

/**
 * 描述指令模板模块在运行时交换的数据结构。
 */
export interface InstructContextState {
  /**
   * chat start 值，由当前实例内部维护。
   */
  chat_start: string;
  /**
   * example separator 值，由当前实例内部维护。
   */
  example_separator: string;
  /**
   * use stop strings 列表，由当前实例内部维护。
   */
  use_stop_strings: boolean;
  /**
   * story string position in chat 值，由当前实例内部维护。
   */
  story_string_position_in_chat: boolean;
}

/**
 * 描述指令模板模块在运行时交换的数据结构。
 */
export interface InstructContextStatePatch {
  /**
   * chat start 值，由当前实例内部维护。
   */
  chat_start?: string;
  /**
   * example separator 值，由当前实例内部维护。
   */
  example_separator?: string;
  /**
   * use stop strings 列表，由当前实例内部维护。
   */
  use_stop_strings?: boolean;
  /**
   * story string position in chat 值，由当前实例内部维护。
   */
  story_string_position_in_chat?: boolean;
}

/**
 * 描述指令模板模块在运行时交换的数据结构。
 */
export interface InstructTemplateMapping {
  /**
   * instruct 值，由当前实例内部维护。
   */
  instruct: string;
  /**
   * context 值，由当前实例内部维护。
   */
  context: string;
}

/**
 * 描述指令模板事件发布时携带的数据结构。
 */
export interface InstructStatePayload {
  /**
   * state 值，由当前实例内部维护。
   */
  state: InstructState;
}
