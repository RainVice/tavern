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

/**
 * 提供指令模板相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 管理指令模板预设的加载、选择和应用，为对话消息格式化提供序列标记和角色名渲染支持。
 * 外部调用方（如聊天消息构建器、模型配置页、备份导入导出）通过此类完成指令模板操作。
 */
export class InstructRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 已加载的指令模板预设缓存，以预设名称为键。
   */
  private presets: Map<string, InstructPreset> = new Map<string, InstructPreset>();
  /**
   * 模型 ID 到模板映射的缓存。
   */
  private mappings: Map<string, InstructTemplateMapping> = new Map<string, InstructTemplateMapping>();
  /**
   * 当前选中的上下文预设名称。
   */
  private selectedContextPreset: string = '';
  /**
   * 当前指令模板运行时状态。
   */
  private state: InstructState = this.defaultState();
  private context: InstructContextState = {
    chat_start: '',
    example_separator: '',
    use_stop_strings: true,
    story_string_position_in_chat: false,
  };

  /**
   * 初始化当前运行时实例。
   * 在应用启动时由更高层运行时容器调用，为指令模板功能注入事件基础设施。
   * @param events 事件总线，用于发布指令模板选择('instruct.selected')/状态变更('instruct.state.changed')事件，通知 UI 层和消息格式化模块模板已切换。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 加载预设列表，替换当前所有已加载的预设。
   * 在应用启动或用户重新加载预设文件时调用，将预定义的指令模板导入运行时内存。
   * @param presets 要加载的指令模板预设数组，每个预设包含完整的序列标记和配置。
   */
  loadPresets(presets: Array<InstructPreset>): void {
    this.presets.clear();
    for (let index = 0; index < presets.length; index += 1) {
      const preset = this.normalizePreset(presets[index]);
      this.presets.set(preset.name, preset);
    }
  }

  /**
   * 列出所有已加载的预设，按名称字母序排序后返回副本。
   * 由 UI 层的指令模板选择器或预设管理面板调用，展示所有可用的模板供用户选择。
   * @returns 预设对象的深拷贝列表。
   */
  listPresets(): Array<InstructPreset> {
    const values = Array.from(this.presets.values());
    values.sort((left: InstructPreset, right: InstructPreset) => left.name.localeCompare(right.name));
    const result = new Array<InstructPreset>();
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.clonePreset(values[index]));
    }
    return result;
  }

  /**
   * 合并部分更新到当前状态，并发布状态变更事件。
   * 由 UI 层（如用户手动编辑指令模板参数）调用，可部分更新序列标记、行为配置等字段。
   * @param patch 包含要更新字段的部分状态对象，未提供的字段保持不变。
   * @returns 更新后的完整状态副本。
   */
  updateState(patch: InstructStatePatch): InstructState {
    this.state = this.mergeState(this.state, patch);
    this.publishState('instruct.state.changed');
    return this.getState();
  }

  /**
   * 合并部分更新到当前上下文配置。
   * 由 UI 层（如用户编辑上下文配置）调用，更新对话起始标记、示例分隔符等上下文设置。
   * @param patch 包含要更新字段的部分上下文对象，未提供的字段保持不变。
   * @returns 更新后的完整上下文配置副本。
   */
  updateContext(patch: InstructContextStatePatch): InstructContextState {
    this.context = this.mergeContext(this.context, patch);
    return this.getContext();
  }

  /**
   * 获取当前指令模板状态的深拷贝副本。
   * 由消息格式化方法（如 formatChatMessage、getStoppingSequences）和 UI 层在需要读取当前模板配置时调用。
   * @returns 当前状态的完整副本。
   */
  getState(): InstructState {
    return this.cloneState(this.state);
  }

  /**
   * 获取当前上下文配置的深拷贝副本。
   * 由对话构造流程在构建完整上下文时调用，读取 chat_start、example_separator 等配置。
   * @returns 当前上下文配置的完整副本。
   */
  getContext(): InstructContextState {
    return this.cloneContext(this.context);
  }

  /**
   * 获取当前选中的上下文预设名称。
   * 由 autoSelectPreset() 和 UI 层在需要知道当前上下文预设时调用。
   * @returns 上下文预设名称字符串。
   */
  getContextPreset(): string {
    return this.selectedContextPreset;
  }

  /**
   * 设置模型 ID 到指令模板和上下文模板的映射关系。
   * 由 UI 层（用户配置模型映射）或初始化流程调用，用于 autoSelectPreset() 精确匹配模型到模板。
   * @param modelId 要设置映射的模型标识，作为映射 Map 的键。
   * @param instruct 指令模板名称，当 modelId 匹配时自动选择此模板。
   * @param context 上下文模板名称，当 modelId 匹配时自动选择此上下文模板。
   */
  setModelTemplateMapping(modelId: string, instruct: string, context: string): void {
    this.mappings.set(modelId, { instruct: instruct, context: context });
  }

  /**
   * 按名称选择并应用指令模板预设。若 forceGet 为 true，即使未启用也会返回当前状态转换的预设。
   * 由 UI 层（如用户从模板下拉列表中选择）调用，将选中模板应用到运行时状态。
   * @param name 预设名称，空字符串时使用当前状态返回预设。支持大小写不敏感的子串匹配。
   * @param forceGet 是否强制获取预设（忽略 enabled 状态），用于只需要读取预设配置而不实际启用的场景。
   * @returns 应用后的预设对象副本。
   */
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

  /**
   * 根据模型 ID 自动匹配并选择预设。优先使用已保存的模板映射，其次通过激活正则匹配。
   * 由模型切换或聊天启动流程调用，当用户切换聊天模型时自动选择合适的模板。
   * @param modelId 模型标识，用于匹配 mapppings 中的模板映射和预设的 activation_regex。
   * @param contextPreset 上下文预设名称，当 bind_to_context 为 true 时作为后备匹配的上下文预设。
   * @returns 成功匹配并应用预设时返回 true，否则返回 false（表示未找到匹配且未启用）。
   */
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

  /**
   * 根据当前模板状态生成停止序列列表，包括 stop_sequence 和可选的序列标记。
   * 由聊天发送流程在构建 API 请求时调用，将停止序列传递给 Provider 层以控制模型生成终止。
   * @param userName 用户名，用于替换 {{name}} 宏并排除用户名的序列标记。
   * @param characterName 角色名，用于替换 {{name}} 宏。
   * @param useStopStrings 是否启用上下文停止字符串，控制是否将 chat_start 和 example_separator 加入停止序列。
   * @returns 停止序列字符串数组，将与序列标记名替换后的结果一同发送给模型 API。
   */
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

  /**
   * 格式化单条聊天消息，添加前缀/后缀序列标记和角色名，生成适合发送给模型的文本。
   * 由对话构造流程（如 ChatRuntime 构建完整上下文时）对每条消息逐个调用，输出格式化后的消息文本。
   * @param name 发送者名称，为空时使用 "System"。
   * @param message 消息文本内容。
   * @param isUser 是否为用户消息，影响选择 input_sequence 还是 output_sequence。
   * @param isNarrator 是否为旁白消息，为 true 时使用 system_sequence 且不包含角色名。
   * @param forceAvatar 强制使用的头像名称，用于 names_behavior=force 时判断是否显示角色名。
   * @param userName 用户名，用于宏替换 {{name}}、{{name1}} 等模板变量。
   * @param characterName 角色名，用于宏替换 {{name2}} 模板变量。
   * @param forceOutputSequence 强制输出序列类型（none/first/last），用于覆盖特定位置的序列标记。
   * @returns 格式化后的消息文本，包含前缀序列、消息体和后缀序列。
   */
  formatChatMessage(name: string, message: string, isUser: boolean, isNarrator: boolean, forceAvatar: string, userName: string, characterName: string, forceOutputSequence: number): string {
    // 判断是否需要在消息前包含角色名
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

  /**
   * 格式化故事文本，根据位置参数决定是否添加前缀/后缀序列标记。
   * 由对话构造流程在构建世界信息/故事文本时调用，输出带序列标记的世界书或故事文本。
   * @param storyString 故事文本内容，来自 worldinfo 模块或故事书系统。
   * @param inChatPosition 故事文本是否嵌入在聊天上下文中，为 true 时不添加任何序列标记。
   * @returns 格式化后的故事文本，如果 storyString 为空则返回空字符串。
   */
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

  /**
   * 格式化提示词中的一行内容，根据角色名行为和强制输出序列生成适当的序列标记。
   * 由提示词构造流程（如 impersonate/continue 场景）调用，生成适合提示词编辑器的格式化行。
   * @param name 发送者名称。
   * @param isImpersonate 是否为 impersonate 模式（扮演角色），影响选择 last_input_sequence 作为前缀。
   * @param promptBias 提示偏向文本，用于在非 impersonate 模式下追加额外引导文本。
   * @param userName 用户名，用于宏替换。
   * @param characterName 角色名，用于宏替换。
   * @param isQuiet 是否为静默消息，为 true 且非 isQuietToLoud 时使用 last_system_sequence。
   * @param isQuietToLoud 是否从静默转为非静默，用于决定是否跳过静默序列。
   * @param forceOutputSequence 强制输出序列类型（none/first/last）。
   * @returns 格式化后的提示词行文本。
   */
  formatPromptLine(name: string, isImpersonate: boolean, promptBias: string, userName: string, characterName: string, isQuiet: boolean, isQuietToLoud: boolean, forceOutputSequence: number): string {
    // 根据 names_behavior 判断是否包含角色名
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

  /**
   * 规范化预设，将旧格式字段（separator_sequence、names）转换为当前状态结构。
   * @param input 待规范化的原始预设。
   * @returns 规范化后的预设对象。
   */
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

  /**
   * 将停止序列字符串拆分为单独条目，过滤空值和重复值。
   * @param result 停止序列输出列表（引用）。
   * @param combined 用换行符分隔的停止序列组合字符串。
   */
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
  /**
   * 根据当前 names_behavior 和消息角色判断是否应在消息前包含角色名。
   * @param name 发送者名称。
   * @param isUser 是否为用户消息。
   * @param isNarrator 是否为旁白消息。
   * @param forceAvatar 强制头像名称。
   * @param userName 用户名。
   * @returns 应包含角色名时返回 true。
   */
  private shouldIncludeMessageName(name: string, isUser: boolean, isNarrator: boolean, forceAvatar: string, userName: string): boolean {
    if (isNarrator) {
      return false;
    }
    if (this.state.names_behavior === INSTRUCT_NAMES_BEHAVIOR_ALWAYS) {
      return true;
    }
    return this.state.names_behavior === INSTRUCT_NAMES_BEHAVIOR_FORCE && !isUser && forceAvatar.length > 0 && name !== userName;
  }

  /**
   * 根据消息角色和强制输出序列类型获取合适的前缀序列标记。
   * @param isUser 是否为用户消息。
   * @param isNarrator 是否为旁白消息。
   * @param forceOutputSequence 强制输出序列类型。
   * @returns 匹配的前缀序列标记字符串。
   */
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

  /**
   * 根据消息角色获取合适的后缀序列标记。
   * @param isUser 是否为用户消息。
   * @param isNarrator 是否为旁白消息。
   * @returns 匹配的后缀序列标记字符串。
   */
  private getMessageSuffix(isUser: boolean, isNarrator: boolean): string {
    if (isNarrator) {
      return this.state.system_same_as_user ? this.state.input_suffix : this.state.system_suffix;
    }
    return isUser ? this.state.input_suffix : this.state.output_suffix;
  }

  /**
   * 根据提示词上下文获取合适的序列标记。
   * @param isImpersonate 是否为 impersonate 模式。
   * @param isQuiet 是否为静默消息。
   * @param isQuietToLoud 是否从静默转为非静默。
   * @param forceOutputSequence 强制输出序列类型。
   * @returns 匹配的提示词序列标记字符串。
   */
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

  /**
   * 按名称查找预设，支持精确匹配和大小写不敏感的子串匹配。
   * @param name 预设名称或子串。
   * @returns 匹配的预设对象，未找到时返回 undefined。
   */
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

  /**
   * 检查模型 ID 是否匹配预设的激活正则表达式。
   * @param source 正则表达式字符串（支持 /pattern/flags 格式）。
   * @param value 要匹配的模型 ID 字符串。
   * @returns 匹配成功时返回 true。
   */
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

  /**
   * 裁剪字符串末尾的空白字符（空格、换行、制表符）。
   * @param value 要裁剪的原始字符串。
   * @returns 裁剪末尾空白后的字符串。
   */
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

  /**
   * 深拷贝预设对象，确保字段值完全独立。
   * @param preset 原始预设对象。
   * @returns 预设对象的深拷贝副本。
   */
  private clonePreset(preset: InstructPreset): InstructPreset {
    return this.stateToPreset(this.mergeState(this.defaultState(), this.presetToPatch(preset)), preset.name);
  }

  /**
   * 深拷贝状态对象。
   * @param state 原始状态对象。
   * @returns 状态的深拷贝副本。
   */
  private cloneState(state: InstructState): InstructState {
    return this.mergeState(this.defaultState(), this.stateToPatch(state));
  }

  /**
   * 深拷贝上下文配置对象。
   * @param context 原始上下文配置对象。
   * @returns 上下文配置的深拷贝副本。
   */
  private cloneContext(context: InstructContextState): InstructContextState {
    return this.mergeContext(this.defaultContext(), this.contextToPatch(context));
  }

  /**
   * 通过事件总线发布指令模板状态变更事件。
   * @param eventName 要发布的事件名称。
   */
  private publishState(eventName: string): void {
    const payload: InstructStatePayload = {
      state: this.getState(),
    };
    this.events.publish<InstructStatePayload>(eventName, payload);
  }
}
