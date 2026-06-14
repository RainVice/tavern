import type { FormattedResult, FormattingConfig, MarkdownExtension } from './MessageFormattingModels';

/**
 * 提供消息格式化相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class MessageFormattingRuntime {
  /**
   * config 值，由当前实例内部维护。
   */
  private config: FormattingConfig = { enabledExtensions: ['underline','strikethrough','code_block'], codeBlockLanguages: ['javascript','python','bash'] };

  /**
   * 设置配置，用于切换运行时状态或保存配置。

   */
  setConfig(config: FormattingConfig): void { this.config = this.copyConfig(config); }
  /**
   * 读取指定Config，不存在时抛出错误。
   * @returns 更新或读取后的记录副本。
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
   * 判断Extension Enabled 值是否满足条件。

   * @returns 条件命中时返回 true，否则返回 false。
   */
  isExtensionEnabled(ext: MarkdownExtension): boolean {
    return this.config.enabledExtensions.indexOf(ext) >= 0;
  }

  /**
   * 读取Code Block Languages 列表，不存在时通常抛出错误或返回空值。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
