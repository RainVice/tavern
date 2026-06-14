import { EventBus } from '../runtime/EventBus';
import type { CompressionAppliedPayload, CompressionConfig, CompressionResult } from './PromptCompressionModels';

/**
 * 提供Prompt 压缩相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class PromptCompressionRuntime {
  /**
   * 事件总线，用于发布压缩事件通知宿主和其他 Runtime 模块。
   */
  private events: EventBus; private config: CompressionConfig;
  /**
   * 初始化当前运行时实例，设置默认压缩配置：禁用压缩、trim 策略、4096 maxTokens。
   * @param events 事件总线实例，用于发布 prompt.compression.applied 事件。
   */
  constructor(events: EventBus) {
    this.events=events;
    this.config = { enabled: false, strategy: 'trim', maxTokens: 4096, preserveSystemPrompt: true, preserveLastMessages: 5 };
  }

  /**
   * 设置配置，用于切换运行时状态或保存配置。由 UI 配置页面或初始化流程调用，更新内部压缩策略。
   */
  setConfig(config: CompressionConfig): void { this.config = this.copyConfig(config); }
  /**
   * 获取当前格式化配置副本，用于 UI 回显配置值或序列化保存。
   * @returns 当前配置的副本。
   */
  getConfig(): CompressionConfig { return this.copyConfig(this.config); }

  /**
   * 估算给定文本的 token 数量，采用字符数除以 3.5 的近似算法。在压缩前由外部模块调用以判断是否超出阈值。
   * @param text 待估算 token 数的原始文本——通常为拼接后的对话消息或 Prompt 内容。
   */
  estimateTokens(text: string): number { return Math.ceil(text.length / 3.5); }

  /**
   * 根据当前压缩配置对 token 数执行压缩，若超出阈值则截断并发布压缩事件。在 Prompt 发送给 LLM 前由格式化或组装流程调用。
   * @param originalTokens 压缩前的原始 token 数，用于记录压缩前后的对比。
   * @param currentTokens 当前实际 token 数，用于与 maxTokens 阈值比较判断是否需要压缩。
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
   * 深拷贝压缩配置对象，防止外部代码意外修改运行时内部配置。
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
   * 深拷贝压缩结果对象，防止外部代码意外修改内部压缩结果。
   * @param result 待拷贝的压缩结果对象。
   */
  private copyResult(result: CompressionResult): CompressionResult {
    return {
      originalTokens: result.originalTokens,
      compressedTokens: result.compressedTokens,
      isCompressed: result.isCompressed,
    };
  }
}
