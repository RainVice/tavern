import { EventBus } from '../runtime/EventBus';
import type { CompressionAppliedPayload, CompressionConfig, CompressionResult } from './PromptCompressionModels';

/**
 * 提供Prompt 压缩相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class PromptCompressionRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus; private config: CompressionConfig;
  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events=events;
    this.config = { enabled: false, strategy: 'trim', maxTokens: 4096, preserveSystemPrompt: true, preserveLastMessages: 5 };
  }

  /**
   * 设置配置，用于切换运行时状态或保存配置。

   */
  setConfig(config: CompressionConfig): void { this.config = this.copyConfig(config); }
  /**
   * 读取指定Config，不存在时抛出错误。
   * @returns 更新或读取后的记录副本。
   */
  getConfig(): CompressionConfig { return this.copyConfig(this.config); }

  /**
   * 执行 estimateTokens 的内部处理步骤，供当前模块复用。
   * @param text 文本内容。
   */
  estimateTokens(text: string): number { return Math.ceil(text.length / 3.5); }

  /**
   * 执行 applyCompression 的内部处理步骤，供当前模块复用。
   * @param originalTokens token 数量或 token 内容。
   * @param currentTokens token 数量或 token 内容。
   */
  applyCompression(originalTokens: number, currentTokens: number): CompressionResult {
    if (!this.config.enabled||currentTokens<=this.config.maxTokens) {
      return { originalTokens: originalTokens, compressedTokens: currentTokens, isCompressed: false };
    }
    const result: CompressionResult = { originalTokens, compressedTokens: Math.min(currentTokens, this.config.maxTokens), isCompressed: true };
    this.events.publish<CompressionAppliedPayload>('prompt.compression.applied', { result: this.copyResult(result) });
    return this.copyResult(result);
  }

  /**
   * 复制Config 值，避免外部修改内部状态。
   */
  private copyConfig(config: CompressionConfig): CompressionConfig {
    return {
      enabled: config.enabled,
      strategy: config.strategy,
      maxTokens: config.maxTokens,
      preserveSystemPrompt: config.preserveSystemPrompt,
      preserveLastMessages: config.preserveLastMessages,
    };
  }

  /**
   * 复制Result 值，避免外部修改内部状态。
   * @param result 返回结果。
   */
  private copyResult(result: CompressionResult): CompressionResult {
    return {
      originalTokens: result.originalTokens,
      compressedTokens: result.compressedTokens,
      isCompressed: result.isCompressed,
    };
  }
}
