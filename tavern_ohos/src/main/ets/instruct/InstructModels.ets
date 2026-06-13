export const INSTRUCT_NAMES_BEHAVIOR_NONE = 'none';
export const INSTRUCT_NAMES_BEHAVIOR_FORCE = 'force';
export const INSTRUCT_NAMES_BEHAVIOR_ALWAYS = 'always';

export const INSTRUCT_FORCE_OUTPUT_NONE = 0;
export const INSTRUCT_FORCE_OUTPUT_FIRST = 1;
export const INSTRUCT_FORCE_OUTPUT_LAST = 2;

export interface InstructPreset {
  name: string;
  enabled?: boolean;
  preset?: string;
  input_sequence?: string;
  input_suffix?: string;
  output_sequence?: string;
  output_suffix?: string;
  system_sequence?: string;
  system_suffix?: string;
  last_system_sequence?: string;
  first_input_sequence?: string;
  first_output_sequence?: string;
  last_input_sequence?: string;
  last_output_sequence?: string;
  story_string_prefix?: string;
  story_string_suffix?: string;
  stop_sequence?: string;
  wrap?: boolean;
  macro?: boolean;
  names_behavior?: string;
  activation_regex?: string;
  bind_to_context?: boolean;
  skip_examples?: boolean;
  user_alignment_message?: string;
  system_same_as_user?: boolean;
  sequences_as_stop_strings?: boolean;
  separator_sequence?: string;
  names?: boolean;
  names_force_groups?: boolean;
}

export interface InstructState {
  enabled: boolean;
  preset: string;
  input_sequence: string;
  input_suffix: string;
  output_sequence: string;
  output_suffix: string;
  system_sequence: string;
  system_suffix: string;
  last_system_sequence: string;
  first_input_sequence: string;
  first_output_sequence: string;
  last_input_sequence: string;
  last_output_sequence: string;
  story_string_prefix: string;
  story_string_suffix: string;
  stop_sequence: string;
  wrap: boolean;
  macro: boolean;
  names_behavior: string;
  activation_regex: string;
  bind_to_context: boolean;
  skip_examples: boolean;
  user_alignment_message: string;
  system_same_as_user: boolean;
  sequences_as_stop_strings: boolean;
}

export interface InstructStatePatch {
  enabled?: boolean;
  preset?: string;
  input_sequence?: string;
  input_suffix?: string;
  output_sequence?: string;
  output_suffix?: string;
  system_sequence?: string;
  system_suffix?: string;
  last_system_sequence?: string;
  first_input_sequence?: string;
  first_output_sequence?: string;
  last_input_sequence?: string;
  last_output_sequence?: string;
  story_string_prefix?: string;
  story_string_suffix?: string;
  stop_sequence?: string;
  wrap?: boolean;
  macro?: boolean;
  names_behavior?: string;
  activation_regex?: string;
  bind_to_context?: boolean;
  skip_examples?: boolean;
  user_alignment_message?: string;
  system_same_as_user?: boolean;
  sequences_as_stop_strings?: boolean;
}

export interface InstructContextState {
  chat_start: string;
  example_separator: string;
  use_stop_strings: boolean;
  story_string_position_in_chat: boolean;
}

export interface InstructContextStatePatch {
  chat_start?: string;
  example_separator?: string;
  use_stop_strings?: boolean;
  story_string_position_in_chat?: boolean;
}

export interface InstructTemplateMapping {
  instruct: string;
  context: string;
}

export interface InstructStatePayload {
  state: InstructState;
}
