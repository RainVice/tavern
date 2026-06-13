import type { FormattedResult, FormattingConfig, MarkdownExtension } from './MessageFormattingModels';

export class MessageFormattingRuntime {
  private config: FormattingConfig = { enabledExtensions: ['underline','strikethrough','code_block'], codeBlockLanguages: ['javascript','python','bash'] };

  setConfig(config: FormattingConfig): void { this.config = this.copyConfig(config); }
  getConfig(): FormattingConfig { return this.copyConfig(this.config); }

  formatText(text: string): FormattedResult {
    let formatted = text;
    if (this.config.enabledExtensions.indexOf('exclusion')>=0) { formatted = this.applyExclusion(formatted); }
    return { original: text, formatted };
  }

  isExtensionEnabled(ext: MarkdownExtension): boolean {
    return this.config.enabledExtensions.indexOf(ext) >= 0;
  }

  getCodeBlockLanguages(): Array<string> { return this.config.codeBlockLanguages.slice(); }

  private applyExclusion(text: string): string {
    return text.replace(/\*\*(.*?)\*\*/g, ''); // 移除加粗标记
  }

  private copyConfig(config: FormattingConfig): FormattingConfig {
    return {
      enabledExtensions: config.enabledExtensions.slice(),
      codeBlockLanguages: config.codeBlockLanguages.slice(),
    };
  }
}
