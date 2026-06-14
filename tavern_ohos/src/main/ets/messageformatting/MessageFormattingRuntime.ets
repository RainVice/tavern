import type { FormattedResult, FormattingConfig, MarkdownExtension } from './MessageFormattingModels';

/**
 * 提供消息格式化相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在聊天消息展示到 UI 前调用 formatText 对消息正文进行格式化处理，
 * 支持配置 Markdown 扩展（下划线、删除线、代码块、排除规则）的启停。
 */
export class MessageFormattingRuntime {
  /**
   * 当前格式化配置，控制启用的 Markdown 扩展和代码块语言列表。
   */
  private config: FormattingConfig = { enabledExtensions: ['underline','strikethrough','code_block'], codeBlockLanguages: ['javascript','python','bash'] };

  /**
   * 替换当前格式化配置，用于切换运行时状态或保存用户配置。
   * 由 UI 层在用户修改格式化设置时调用，更新后的配置将在后续 formatText 调用中生效。
   * @param config 新的格式化配置对象，包含启用的扩展列表和代码块语言列表。
   */
  setConfig(config: FormattingConfig): void { this.config = this.copyConfig(config); }
  /**
   * 获取当前格式化配置的副本，调用方修改返回值不影响内部状态。
   * 由 UI 层调用以读取当前设置，用于展示格式化选项开关状态。
   * @returns 当前格式化配置的副本，包含启用的扩展列表和代码块语言列表。
   */
  getConfig(): FormattingConfig { return this.copyConfig(this.config); }

  /**
   * 对文本应用当前启用的格式化规则（如 exclusion 规则移除加粗标记），返回原始和格式化结果。
   * 在聊天消息展示到 UI 前由消息渲染流程调用，
   * 确保消息文本按用户配置的格式规则处理后展示。
   * @param text 待格式化的原始消息文本，通常为 AI 回复或用户消息的正文。
   * @returns 包含原始文本和格式化后文本的结果对象，调用方使用 formatted 渲染消息内容。
   */
  formatText(text: string): FormattedResult {
    let formatted = text;
    if (this.config.enabledExtensions.indexOf('exclusion')>=0) { formatted = this.applyExclusion(formatted); }
    return { original: text, formatted };
  }

  /**
   * 判断指定 Markdown 扩展是否已在配置中启用。
   * 由 UI 层在展示扩展开关状态时调用，或由 formatText 内部检查是否需要应用对应格式化规则。
   * @param ext 要检查的 Markdown 扩展名称（underline / strikethrough / code_block / exclusion）。
   * @returns 该扩展已启用时返回 true，否则返回 false。
   */
  isExtensionEnabled(ext: MarkdownExtension): boolean {
    return this.config.enabledExtensions.indexOf(ext) >= 0;
  }

  /**
   * 获取当前配置中所有代码块支持的语言列表副本。
   * 由 UI 层用于展示代码块语言配置选项，或由 formatText 内部用于代码块语法标识。
   * @returns 编程语言名称的数组副本，调用方修改不影响内部状态。
   */
  getCodeBlockLanguages(): Array<string> { return this.config.codeBlockLanguages.slice(); }
  private applyExclusion(text: string): string {
    return text.replace(/\*\*(.*?)\*\*/g, ''); // 移除加粗标记
  }

  /**
   * 深拷贝格式化配置，创建新数组防止外部修改影响内部状态。
   * @param config 要复制的格式化配置。
   * @returns 独立于原配置的副本。
   */
  private copyConfig(config: FormattingConfig): FormattingConfig {
    return {
      enabledExtensions: config.enabledExtensions.slice(),
      codeBlockLanguages: config.codeBlockLanguages.slice(),
    };
  }
}
