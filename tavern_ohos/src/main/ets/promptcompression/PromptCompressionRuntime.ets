import { EventBus } from '../runtime/EventBus';
import type { CompressionAppliedPayload, CompressionConfig, CompressionResult } from './PromptCompressionModels';

/**
 * 提供 Prompt 压缩相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class PromptCompressionRuntime {
  /**
   * 事件总线实例，用于发布 `'prompt.compression.applied'` 等事件。
   */
  private events: EventBus; private config: CompressionConfig;
  /**
   * 使用指定事件总线初始化运行时实例，并设默认配置（未启用、trim 策略、最大 4096 token）。
   * @param events 事件总线实例。
   */
  constructor(events: EventBus) {
    this.events=events;
    this.config = { enabled: false, strategy: 'trim', maxTokens: 4096, preserveSystemPrompt: true, preserveLastMessages: 5 };
  }

  /**
   * 更新压缩配置，下次 {@link applyCompression} 调用时生效。
   * @param config 要写入的完整配置对象。
   */
  setConfig(config: CompressionConfig): void { this.config = this.copyConfig(config); }
  /**
   * 获取当前压缩配置的深拷贝。
   * @returns 当前配置的副本。
   */
  getConfig(): CompressionConfig { return this.copyConfig(this.config); }

  /**
   * 根据平均中文字符 / token 比值估算给定文本的 token 数量。
   * @param text 待估算的原始文本。
   * @returns 估算的 token 数量（向上取整）。
   */
  estimateTokens(text: string): number { return Math.ceil(text.length / 3.5); }

  /**
   * 对当前 token 数执行压缩判定。若超出限制则裁剪至 {@link CompressionConfig.maxTokens}，
   * 并发布 `'prompt.compression.applied'` 事件；否则原样返回且不触发事件。
   * @param originalTokens 压缩前的原始 token 数量。
   * @param currentTokens 当前待处理的 token 数量。
   * @returns 包含原始数、压缩后数及是否实际压缩的统计结果。
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
   * 深拷贝 {@link CompressionConfig}，防止外部篡改内部状态。
   * @param config 源配置对象。
   * @returns 全新副本。
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
   * 深拷贝 {@link CompressionResult}，防止外部篡改内部状态。
   * @param result 源结果对象。
   * @returns 全新副本。
   */
  private copyResult(result: CompressionResult): CompressionResult {
    return {
      originalTokens: result.originalTokens,
      compressedTokens: result.compressedTokens,
      isCompressed: result.isCompressed,
    };
  }
}
