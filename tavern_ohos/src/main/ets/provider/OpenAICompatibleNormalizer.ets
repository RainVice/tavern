import type {
  OpenAICompatibleChatChunk,
  OpenAICompatibleChatChoice,
  OpenAICompatibleChatDelta,
  ProviderNormalizedChunk,
} from './ProviderModels';

/**
 * OpenAI 兼容格式的流式数据块规范化器。
 * 将不同后端返回的 JSON 数据统一转换为 ProviderNormalizedChunk 格式。
 */
export class OpenAICompatibleNormalizer {
  /**
   * 规范化 OpenAI 兼容格式的聊天数据块，提取文本增量、推理增量和结束原因。
   * @param data 原始 JSON 字符串（OpenAI 格式的流式响应）。
   * @returns 规范化后的数据块。
   */
  normalizeChatChunk(data: string): ProviderNormalizedChunk {
    const chunk = JSON.parse(data) as OpenAICompatibleChatChunk;
    let textDelta = '';
    let reasoningDelta = '';
    let finishReason = '';
    for (let index = 0; index < chunk.choices.length; index += 1) {
      const choice: OpenAICompatibleChatChoice = chunk.choices[index];
      if (choice.finish_reason !== undefined && choice.finish_reason !== null) {
        finishReason = choice.finish_reason;
      }
      const delta: OpenAICompatibleChatDelta | undefined = choice.delta;
      if (delta === undefined) {
        continue;
      }
      if (delta.content !== undefined && delta.content !== null) {
        textDelta += delta.content;
      }
      if (delta.reasoning_content !== undefined && delta.reasoning_content !== null) {
        reasoningDelta += delta.reasoning_content;
      }
      if (delta.reasoning !== undefined && delta.reasoning !== null) {
        reasoningDelta += delta.reasoning;
      }
    }
    return {
      textDelta: textDelta,
      reasoningDelta: reasoningDelta,
      finishReason: finishReason,
      rawJson: data,
    };
  }
}
