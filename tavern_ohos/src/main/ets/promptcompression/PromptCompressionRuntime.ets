import { EventBus } from '../runtime/EventBus';
import type { CompressionAppliedPayload, CompressionConfig, CompressionResult } from './PromptCompressionModels';

export class PromptCompressionRuntime {
  private events: EventBus; private config: CompressionConfig;
  constructor(events: EventBus) {
    this.events=events;
    this.config = { enabled: false, strategy: 'trim', maxTokens: 4096, preserveSystemPrompt: true, preserveLastMessages: 5 };
  }

  setConfig(config: CompressionConfig): void { this.config = this.copyConfig(config); }
  getConfig(): CompressionConfig { return this.copyConfig(this.config); }

  estimateTokens(text: string): number { return Math.ceil(text.length / 3.5); }

  applyCompression(originalTokens: number, currentTokens: number): CompressionResult {
    if (!this.config.enabled||currentTokens<=this.config.maxTokens) {
      return { originalTokens: originalTokens, compressedTokens: currentTokens, isCompressed: false };
    }
    const result: CompressionResult = { originalTokens, compressedTokens: Math.min(currentTokens, this.config.maxTokens), isCompressed: true };
    this.events.publish<CompressionAppliedPayload>('prompt.compression.applied', { result: this.copyResult(result) });
    return this.copyResult(result);
  }

  private copyConfig(config: CompressionConfig): CompressionConfig {
    return {
      enabled: config.enabled,
      strategy: config.strategy,
      maxTokens: config.maxTokens,
      preserveSystemPrompt: config.preserveSystemPrompt,
      preserveLastMessages: config.preserveLastMessages,
    };
  }

  private copyResult(result: CompressionResult): CompressionResult {
    return {
      originalTokens: result.originalTokens,
      compressedTokens: result.compressedTokens,
      isCompressed: result.isCompressed,
    };
  }
}
