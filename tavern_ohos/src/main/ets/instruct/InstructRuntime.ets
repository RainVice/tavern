import { EventBus } from '../runtime/EventBus';
import type {
  InstructContextState,
  InstructContextStatePatch,
  InstructPreset,
  InstructState,
  InstructStatePatch,
  InstructStatePayload,
  InstructTemplateMapping,
} from './InstructModels';
import {
  INSTRUCT_FORCE_OUTPUT_FIRST,
  INSTRUCT_FORCE_OUTPUT_LAST,
  INSTRUCT_NAMES_BEHAVIOR_ALWAYS,
  INSTRUCT_NAMES_BEHAVIOR_FORCE,
  INSTRUCT_NAMES_BEHAVIOR_NONE,
} from './InstructModels';

export class InstructRuntime {
  private events: EventBus;
  private presets: Map<string, InstructPreset> = new Map<string, InstructPreset>();
  private mappings: Map<string, InstructTemplateMapping> = new Map<string, InstructTemplateMapping>();
  private selectedContextPreset: string = '';
  private state: InstructState = this.defaultState();
  private context: InstructContextState = {
    chat_start: '',
    example_separator: '',
    use_stop_strings: true,
    story_string_position_in_chat: false,
  };

  constructor(events: EventBus) {
    this.events = events;
  }

  loadPresets(presets: Array<InstructPreset>): void {
    this.presets.clear();
    for (let index = 0; index < presets.length; index += 1) {
      const preset = this.normalizePreset(presets[index]);
      this.presets.set(preset.name, preset);
    }
  }

  listPresets(): Array<InstructPreset> {
    const values = Array.from(this.presets.values());
    values.sort((left: InstructPreset, right: InstructPreset) => left.name.localeCompare(right.name));
    const result = new Array<InstructPreset>();
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.clonePreset(values[index]));
    }
    return result;
  }

  updateState(patch: InstructStatePatch): InstructState {
    this.state = this.mergeState(this.state, patch);
    this.publishState('instruct.state.changed');
    return this.getState();
  }

  updateContext(patch: InstructContextStatePatch): InstructContextState {
    this.context = this.mergeContext(this.context, patch);
    return this.getContext();
  }

  getState(): InstructState {
    return this.cloneState(this.state);
  }

  getContext(): InstructContextState {
    return this.cloneContext(this.context);
  }

  getContextPreset(): string {
    return this.selectedContextPreset;
  }

  setModelTemplateMapping(modelId: string, instruct: string, context: string): void {
    this.mappings.set(modelId, { instruct: instruct, context: context });
  }

  selectPreset(name: string, forceGet: boolean): InstructPreset {
    if (name.length === 0) {
      if (!this.state.enabled && !forceGet) {
        return this.clonePreset(this.stateToPreset(this.defaultState()));
      }
      return this.clonePreset(this.stateToPreset(this.state));
    }
    const preset = this.findPreset(name);
    if (preset === undefined) {
      throw new Error(`Instruct template not found: ${name}`);
    }
    this.applyPreset(preset, true);
    return this.clonePreset(preset);
  }

  autoSelectPreset(modelId: string, contextPreset: string): boolean {
    const mapped = this.mappings.get(modelId);
    if (mapped !== undefined) {
      this.applyExternalSelection(mapped.instruct, mapped.context);
      return true;
    }

    const values = Array.from(this.presets.values());
    for (let index = 0; index < values.length; index += 1) {
      let regexSource = '';
      if (values[index].activation_regex !== undefined) {
        regexSource = values[index].activation_regex as string;
      }
      if (regexSource.length > 0 && this.matchesActivationRegex(regexSource, modelId)) {
        this.applyPreset(values[index], true);
        return true;
      }
    }

    if (!this.state.enabled || !this.state.bind_to_context) {
      return false;
    }
    const contextMatch = this.presets.get(contextPreset);
    if (contextMatch === undefined) {
      return false;
    }
    this.applyPreset(contextMatch, true);
    return true;
  }

  getStoppingSequences(userName: string, characterName: string, useStopStrings: boolean): Array<string> {
    const result = new Array<string>();
    if (this.state.enabled) {
      const sequences = new Array<string>();
      sequences.push(this.state.stop_sequence);
      if (this.state.sequences_as_stop_strings) {
        sequences.push(this.replaceNameToken(this.state.input_sequence, userName));
        sequences.push(this.replaceNameToken(this.state.output_sequence, characterName));
        sequences.push(this.replaceNameToken(this.state.first_output_sequence, characterName));
        sequences.push(this.replaceNameToken(this.state.last_output_sequence, characterName));
        sequences.push(this.replaceNameToken(this.state.system_sequence, 'System'));
        sequences.push(this.replaceNameToken(this.state.last_system_sequence, 'System'));
      }
      this.addStopSequences(result, sequences.join('\n'));
    }

    if (useStopStrings && this.context.use_stop_strings) {
      if (this.context.chat_start.length > 0) {
        result.push(`\n${this.context.chat_start}`);
      }
      if (this.context.example_separator.length > 0) {
        result.push(`\n${this.context.example_separator}`);
      }
    }
    return result;
  }

  formatChatMessage(name: string, message: string, isUser: boolean, isNarrator: boolean, forceAvatar: string, userName: string, characterName: string, forceOutputSequence: number): string {
    const includeName = this.shouldIncludeMessageName(name, isUser, isNarrator, forceAvatar, userName);
    let prefix = this.getMessagePrefix(isUser, isNarrator, forceOutputSequence);
    let suffix = this.getMessageSuffix(isUser, isNarrator);
    if (this.state.macro) {
      prefix = this.applyMacros(prefix, name.length === 0 ? 'System' : name, userName, characterName);
      suffix = this.applyMacros(suffix, name.length === 0 ? 'System' : name, userName, characterName);
    }
    if (suffix.length === 0 && this.state.wrap) {
      suffix = '\n';
    }
    const separator = this.state.wrap ? '\n' : '';
    const body = includeName && name.length > 0 ? `${name}: ${message}${suffix}` : `${message}${suffix}`;
    return this.joinNonEmpty([prefix, body], separator);
  }

  formatStoryString(storyString: string, inChatPosition: boolean): string {
    if (storyString.length === 0) {
      return '';
    }
    if (inChatPosition) {
      return storyString;
    }
    const separator = this.state.wrap ? '\n' : '';
    let output = storyString;
    if (this.state.story_string_prefix.length > 0) {
      output = `${this.applyMacros(this.state.story_string_prefix, 'System', '', '')}${separator}${output}`;
    }
    if (this.state.story_string_suffix.length > 0) {
      output = `${output}${this.applyMacros(this.state.story_string_suffix, 'System', '', '')}`;
    }
    return output;
  }

  formatPromptLine(name: string, isImpersonate: boolean, promptBias: string, userName: string, characterName: string, isQuiet: boolean, isQuietToLoud: boolean, forceOutputSequence: number): string {
    const includeName = name.length > 0 && (this.state.names_behavior === INSTRUCT_NAMES_BEHAVIOR_ALWAYS || this.state.names_behavior === INSTRUCT_NAMES_BEHAVIOR_FORCE) && !(isQuiet && !isQuietToLoud);
    let sequence = this.getPromptSequence(isImpersonate, isQuiet, isQuietToLoud, forceOutputSequence);
    if (this.state.macro) {
      sequence = this.applyMacros(sequence, name.length === 0 ? 'System' : name, userName, characterName);
    }
    const separator = this.state.wrap ? '\n' : '';
    let text = includeName ? `${separator}${sequence}${separator}${name}:` : `${separator}${sequence}`;
    if (isQuiet && separator.length > 0) {
      text = text.substring(separator.length);
    }
    if (!isImpersonate && promptBias.length > 0) {
      text += includeName ? promptBias : `${separator}${promptBias.trimStart()}`;
    }
    return `${this.state.wrap ? this.trimEnd(text) : text}${includeName ? '' : separator}`;
  }

  private normalizePreset(input: InstructPreset): InstructPreset {
    const state = this.mergeState(this.defaultState(), this.presetToPatch(input));
    if (input.separator_sequence !== undefined) {
      state.output_suffix = input.separator_sequence;
    }
    if (input.names !== undefined) {
      state.names_behavior = input.names ? INSTRUCT_NAMES_BEHAVIOR_ALWAYS : (input.names_force_groups ? INSTRUCT_NAMES_BEHAVIOR_FORCE : INSTRUCT_NAMES_BEHAVIOR_NONE);
    }
    return this.stateToPreset(state, input.name);
  }

  private applyPreset(preset: InstructPreset, enable: boolean): void {
    const normalized = this.normalizePreset(preset);
    this.state = this.mergeState(this.state, this.presetToPatch(normalized));
    this.state.preset = normalized.name;
    if (enable) {
      this.state.enabled = true;
    }
    this.publishState('instruct.selected');
  }

  private applyExternalSelection(instruct: string, context: string): void {
    this.state.preset = instruct;
    this.state.enabled = true;
    this.selectedContextPreset = context;
    this.publishState('instruct.selected');
  }

  private addStopSequences(result: Array<string>, combined: string): void {
    const seen: Map<string, boolean> = new Map<string, boolean>();
    const parts = combined.split('\n');
    for (let index = 0; index < parts.length; index += 1) {
      const sequence = parts[index];
      if (sequence.trim().length === 0 || seen.get(sequence) === true) {
        continue;
      }
      seen.set(sequence, true);
      result.push(this.state.wrap ? `\n${sequence}` : sequence);
    }
  }

  private shouldIncludeMessageName(name: string, isUser: boolean, isNarrator: boolean, forceAvatar: string, userName: string): boolean {
    if (isNarrator) {
      return false;
    }
    if (this.state.names_behavior === INSTRUCT_NAMES_BEHAVIOR_ALWAYS) {
      return true;
    }
    return this.state.names_behavior === INSTRUCT_NAMES_BEHAVIOR_FORCE && !isUser && forceAvatar.length > 0 && name !== userName;
  }

  private getMessagePrefix(isUser: boolean, isNarrator: boolean, forceOutputSequence: number): string {
    if (isNarrator) {
      return this.state.system_same_as_user ? this.state.input_sequence : this.state.system_sequence;
    }
    if (isUser) {
      if (forceOutputSequence === INSTRUCT_FORCE_OUTPUT_FIRST) {
        return this.state.first_input_sequence.length > 0 ? this.state.first_input_sequence : this.state.input_sequence;
      }
      if (forceOutputSequence === INSTRUCT_FORCE_OUTPUT_LAST) {
        return this.state.last_input_sequence.length > 0 ? this.state.last_input_sequence : this.state.input_sequence;
      }
      return this.state.input_sequence;
    }
    if (forceOutputSequence === INSTRUCT_FORCE_OUTPUT_FIRST) {
      return this.state.first_output_sequence.length > 0 ? this.state.first_output_sequence : this.state.output_sequence;
    }
    if (forceOutputSequence === INSTRUCT_FORCE_OUTPUT_LAST) {
      return this.state.last_output_sequence.length > 0 ? this.state.last_output_sequence : this.state.output_sequence;
    }
    return this.state.output_sequence;
  }

  private getMessageSuffix(isUser: boolean, isNarrator: boolean): string {
    if (isNarrator) {
      return this.state.system_same_as_user ? this.state.input_suffix : this.state.system_suffix;
    }
    return isUser ? this.state.input_suffix : this.state.output_suffix;
  }

  private getPromptSequence(isImpersonate: boolean, isQuiet: boolean, isQuietToLoud: boolean, forceOutputSequence: number): string {
    if (isImpersonate) {
      return this.state.last_input_sequence.length > 0 ? this.state.last_input_sequence : this.state.input_sequence;
    }
    if (isQuiet && !isQuietToLoud) {
      return this.state.last_system_sequence.length > 0 ? this.state.last_system_sequence : this.state.output_sequence;
    }
    if (forceOutputSequence === INSTRUCT_FORCE_OUTPUT_FIRST) {
      return this.state.first_output_sequence.length > 0 ? this.state.first_output_sequence : this.state.output_sequence;
    }
    return this.state.last_output_sequence.length > 0 ? this.state.last_output_sequence : this.state.output_sequence;
  }

  private findPreset(name: string): InstructPreset | undefined {
    const exact = this.presets.get(name);
    if (exact !== undefined) {
      return exact;
    }
    const normalized = name.toLowerCase();
    const values = Array.from(this.presets.values());
    for (let index = 0; index < values.length; index += 1) {
      if (values[index].name.toLowerCase().indexOf(normalized) >= 0) {
        return values[index];
      }
    }
    return undefined;
  }

  private matchesActivationRegex(source: string, value: string): boolean {
    try {
      if (source.length >= 2 && source[0] === '/') {
        const lastSlash = source.lastIndexOf('/');
        if (lastSlash > 0) {
          const pattern = source.substring(1, lastSlash);
          const flags = source.substring(lastSlash + 1);
          return new RegExp(pattern, flags).test(value);
        }
      }
      return new RegExp(source).test(value);
    } catch (error) {
      return false;
    }
  }

  private applyMacros(value: string, name: string, userName: string, characterName: string): string {
    return value.replace(/{{name1}}/gi, userName).replace(/{{name2}}/gi, characterName).replace(/{{name}}/gi, name);
  }

  private replaceNameToken(value: string, name: string): string {
    return value.replace(/{{name}}/gi, name);
  }

  private joinNonEmpty(values: Array<string>, separator: string): string {
    const parts = new Array<string>();
    for (let index = 0; index < values.length; index += 1) {
      if (values[index].length > 0) {
        parts.push(values[index]);
      }
    }
    return parts.join(separator);
  }

  private trimEnd(value: string): string {
    let end = value.length;
    while (end > 0 && (value[end - 1] === ' ' || value[end - 1] === '\n' || value[end - 1] === '\t' || value[end - 1] === '\r')) {
      end -= 1;
    }
    return value.substring(0, end);
  }

  private mergeState(base: InstructState, patch: InstructStatePatch): InstructState {
    return {
      enabled: patch.enabled === undefined ? base.enabled : patch.enabled,
      preset: patch.preset === undefined ? base.preset : patch.preset,
      input_sequence: patch.input_sequence === undefined ? base.input_sequence : patch.input_sequence,
      input_suffix: patch.input_suffix === undefined ? base.input_suffix : patch.input_suffix,
      output_sequence: patch.output_sequence === undefined ? base.output_sequence : patch.output_sequence,
      output_suffix: patch.output_suffix === undefined ? base.output_suffix : patch.output_suffix,
      system_sequence: patch.system_sequence === undefined ? base.system_sequence : patch.system_sequence,
      system_suffix: patch.system_suffix === undefined ? base.system_suffix : patch.system_suffix,
      last_system_sequence: patch.last_system_sequence === undefined ? base.last_system_sequence : patch.last_system_sequence,
      first_input_sequence: patch.first_input_sequence === undefined ? base.first_input_sequence : patch.first_input_sequence,
      first_output_sequence: patch.first_output_sequence === undefined ? base.first_output_sequence : patch.first_output_sequence,
      last_input_sequence: patch.last_input_sequence === undefined ? base.last_input_sequence : patch.last_input_sequence,
      last_output_sequence: patch.last_output_sequence === undefined ? base.last_output_sequence : patch.last_output_sequence,
      story_string_prefix: patch.story_string_prefix === undefined ? base.story_string_prefix : patch.story_string_prefix,
      story_string_suffix: patch.story_string_suffix === undefined ? base.story_string_suffix : patch.story_string_suffix,
      stop_sequence: patch.stop_sequence === undefined ? base.stop_sequence : patch.stop_sequence,
      wrap: patch.wrap === undefined ? base.wrap : patch.wrap,
      macro: patch.macro === undefined ? base.macro : patch.macro,
      names_behavior: patch.names_behavior === undefined ? base.names_behavior : patch.names_behavior,
      activation_regex: patch.activation_regex === undefined ? base.activation_regex : patch.activation_regex,
      bind_to_context: patch.bind_to_context === undefined ? base.bind_to_context : patch.bind_to_context,
      skip_examples: patch.skip_examples === undefined ? base.skip_examples : patch.skip_examples,
      user_alignment_message: patch.user_alignment_message === undefined ? base.user_alignment_message : patch.user_alignment_message,
      system_same_as_user: patch.system_same_as_user === undefined ? base.system_same_as_user : patch.system_same_as_user,
      sequences_as_stop_strings: patch.sequences_as_stop_strings === undefined ? base.sequences_as_stop_strings : patch.sequences_as_stop_strings,
    };
  }

  private mergeContext(base: InstructContextState, patch: InstructContextStatePatch): InstructContextState {
    return {
      chat_start: patch.chat_start === undefined ? base.chat_start : patch.chat_start,
      example_separator: patch.example_separator === undefined ? base.example_separator : patch.example_separator,
      use_stop_strings: patch.use_stop_strings === undefined ? base.use_stop_strings : patch.use_stop_strings,
      story_string_position_in_chat: patch.story_string_position_in_chat === undefined ? base.story_string_position_in_chat : patch.story_string_position_in_chat,
    };
  }

  private defaultState(): InstructState {
    return {
      enabled: false,
      preset: 'Alpaca',
      input_sequence: '### Instruction:',
      input_suffix: '',
      output_sequence: '### Response:',
      output_suffix: '',
      system_sequence: '',
      system_suffix: '',
      last_system_sequence: '',
      first_input_sequence: '',
      first_output_sequence: '',
      last_input_sequence: '',
      last_output_sequence: '',
      story_string_prefix: '',
      story_string_suffix: '',
      stop_sequence: '',
      wrap: true,
      macro: true,
      names_behavior: INSTRUCT_NAMES_BEHAVIOR_FORCE,
      activation_regex: '',
      bind_to_context: false,
      skip_examples: false,
      user_alignment_message: '',
      system_same_as_user: false,
      sequences_as_stop_strings: true,
    };
  }

  private stateToPreset(state: InstructState, name?: string): InstructPreset {
    return {
      name: name === undefined ? state.preset : name,
      enabled: state.enabled,
      preset: state.preset,
      input_sequence: state.input_sequence,
      input_suffix: state.input_suffix,
      output_sequence: state.output_sequence,
      output_suffix: state.output_suffix,
      system_sequence: state.system_sequence,
      system_suffix: state.system_suffix,
      last_system_sequence: state.last_system_sequence,
      first_input_sequence: state.first_input_sequence,
      first_output_sequence: state.first_output_sequence,
      last_input_sequence: state.last_input_sequence,
      last_output_sequence: state.last_output_sequence,
      story_string_prefix: state.story_string_prefix,
      story_string_suffix: state.story_string_suffix,
      stop_sequence: state.stop_sequence,
      wrap: state.wrap,
      macro: state.macro,
      names_behavior: state.names_behavior,
      activation_regex: state.activation_regex,
      bind_to_context: state.bind_to_context,
      skip_examples: state.skip_examples,
      user_alignment_message: state.user_alignment_message,
      system_same_as_user: state.system_same_as_user,
      sequences_as_stop_strings: state.sequences_as_stop_strings,
    };
  }

  private presetToPatch(preset: InstructPreset): InstructStatePatch {
    const patch: InstructStatePatch = {};
    patch.enabled = preset.enabled;
    patch.preset = preset.preset;
    patch.input_sequence = preset.input_sequence;
    patch.input_suffix = preset.input_suffix;
    patch.output_sequence = preset.output_sequence;
    patch.output_suffix = preset.output_suffix;
    patch.system_sequence = preset.system_sequence;
    patch.system_suffix = preset.system_suffix;
    patch.last_system_sequence = preset.last_system_sequence;
    patch.first_input_sequence = preset.first_input_sequence;
    patch.first_output_sequence = preset.first_output_sequence;
    patch.last_input_sequence = preset.last_input_sequence;
    patch.last_output_sequence = preset.last_output_sequence;
    patch.story_string_prefix = preset.story_string_prefix;
    patch.story_string_suffix = preset.story_string_suffix;
    patch.stop_sequence = preset.stop_sequence;
    patch.wrap = preset.wrap;
    patch.macro = preset.macro;
    patch.names_behavior = preset.names_behavior;
    patch.activation_regex = preset.activation_regex;
    patch.bind_to_context = preset.bind_to_context;
    patch.skip_examples = preset.skip_examples;
    patch.user_alignment_message = preset.user_alignment_message;
    patch.system_same_as_user = preset.system_same_as_user;
    patch.sequences_as_stop_strings = preset.sequences_as_stop_strings;
    return patch;
  }

  private stateToPatch(state: InstructState): InstructStatePatch {
    const patch: InstructStatePatch = {};
    patch.enabled = state.enabled;
    patch.preset = state.preset;
    patch.input_sequence = state.input_sequence;
    patch.input_suffix = state.input_suffix;
    patch.output_sequence = state.output_sequence;
    patch.output_suffix = state.output_suffix;
    patch.system_sequence = state.system_sequence;
    patch.system_suffix = state.system_suffix;
    patch.last_system_sequence = state.last_system_sequence;
    patch.first_input_sequence = state.first_input_sequence;
    patch.first_output_sequence = state.first_output_sequence;
    patch.last_input_sequence = state.last_input_sequence;
    patch.last_output_sequence = state.last_output_sequence;
    patch.story_string_prefix = state.story_string_prefix;
    patch.story_string_suffix = state.story_string_suffix;
    patch.stop_sequence = state.stop_sequence;
    patch.wrap = state.wrap;
    patch.macro = state.macro;
    patch.names_behavior = state.names_behavior;
    patch.activation_regex = state.activation_regex;
    patch.bind_to_context = state.bind_to_context;
    patch.skip_examples = state.skip_examples;
    patch.user_alignment_message = state.user_alignment_message;
    patch.system_same_as_user = state.system_same_as_user;
    patch.sequences_as_stop_strings = state.sequences_as_stop_strings;
    return patch;
  }

  private contextToPatch(context: InstructContextState): InstructContextStatePatch {
    const patch: InstructContextStatePatch = {};
    patch.chat_start = context.chat_start;
    patch.example_separator = context.example_separator;
    patch.use_stop_strings = context.use_stop_strings;
    patch.story_string_position_in_chat = context.story_string_position_in_chat;
    return patch;
  }

  private defaultContext(): InstructContextState {
    return {
      chat_start: '',
      example_separator: '',
      use_stop_strings: true,
      story_string_position_in_chat: false,
    };
  }

  private clonePreset(preset: InstructPreset): InstructPreset {
    return this.stateToPreset(this.mergeState(this.defaultState(), this.presetToPatch(preset)), preset.name);
  }

  private cloneState(state: InstructState): InstructState {
    return this.mergeState(this.defaultState(), this.stateToPatch(state));
  }

  private cloneContext(context: InstructContextState): InstructContextState {
    return this.mergeContext(this.defaultContext(), this.contextToPatch(context));
  }

  private publishState(eventName: string): void {
    const payload: InstructStatePayload = {
      state: this.getState(),
    };
    this.events.publish<InstructStatePayload>(eventName, payload);
  }
}
