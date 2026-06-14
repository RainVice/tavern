import type { FormattedResult, FormattingConfig, MarkdownExtension } from './MessageFormattingModels';

/**
 * 提供消息格式化相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class MessageFormattingRuntime {
  /**
   * 格式化配置，控制启用的 Markdown 扩展和代码块语言列表。
   */
  private config: FormattingConfig = { enabledExtensions: ['underline','strikethrough','code_block'], codeBlockLanguages: ['javascript','python','bash'] };

  /**
   * 设置运行时配置，更新内部维护的配置状态。
   */
  setConfig(config: FormattingConfig): void { this.config = this.copyConfig(config); }
  /**
   * 获取当前配置的副本，调用方可安全读取而不影响内部状态。
   * @returns 当前配置的深拷贝副本。
   */
  getConfig(): FormattingConfig { return this.copyConfig(this.config); }

  /**
   * 生成Text输出，供请求发送、导出或界面展示使用。
   * @param text 文本内容。
   */
  formatText(text: string): FormattedResult {
    let formatted = text;
    if (this.config.enabledExtensions.indexOf('exclusion')>=0) { formatted = this.applyExclusion(formatted); }
    return { original: text, formatted };
  }

  /**
   * 检查指定的 Markdown 扩展是否已在配置中启用。
   * @returns 扩展已启用时返回 true，否则返回 false。
   */
  isExtensionEnabled(ext: MarkdownExtension): boolean {
    return this.config.enabledExtensions.indexOf(ext) >= 0;
  }

  /**
   * 获取支持的代码块语言列表副本。
   * @returns 代码块语言列表的副本，调用方可安全读取。
   */
  getCodeBlockLanguages(): Array<string> { return this.config.codeBlockLanguages.slice(); }
  private applyExclusion(text: string): string {
    return text.replace(/\*\*(.*?)\*\*/g, ''); // 移除加粗标记
  }

  /**
   * 复制Config 值，避免外部修改内部状态。
   */
  private copyConfig(config: FormattingConfig): FormattingConfig {
    return {
      enabledExtensions: config.enabledExtensions.slice(),
      codeBlockLanguages: config.codeBlockLanguages.slice(),
    };
  }
}
