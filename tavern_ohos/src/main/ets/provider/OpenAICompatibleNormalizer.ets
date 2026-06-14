import type {
  OpenAICompatibleChatChunk,
  OpenAICompatibleChatChoice,
  OpenAICompatibleChatDelta,
  ProviderNormalizedChunk,
} from './ProviderModels';

/**
 * OpenAI 兼容格式的流式响应归一化器。
 * 将后端返回的流式 JSON 数据块统一为 ProviderNormalizedChunk 格式，
 * 提取其中的文本增量、推理过程增量和结束原因。
 */
export class OpenAICompatibleNormalizer {
  /**
   * 解析并归一化一个 OpenAI 兼容的流式 JSON 数据块。
   * 遍历 choices 数组，汇总所有候选的文本增量、推理过程增量，并记录结束原因。
   * @param data 后端返回的原始 JSON 字符串（单行流式数据）。
   * @returns 归一化后的数据块，包含文本增量、推理增量、结束原因和原始 JSON。
   */
  normalizeChatChunk(data: string): ProviderNormalizedChunk {
    const chunk = JSON.parse(data) as OpenAICompatibleChatChunk;
    let textDelta = '';
    let reasoningDelta = '';
    let finishReason = '';
    // 遍历所有候选结果，累加文本和推理增量
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
