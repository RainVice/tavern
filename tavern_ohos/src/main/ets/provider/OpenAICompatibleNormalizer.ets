import type {
  OpenAICompatibleChatChunk,
  OpenAICompatibleChatChoice,
  OpenAICompatibleChatDelta,
  ProviderNormalizedChunk,
} from './ProviderModels';

export class OpenAICompatibleNormalizer {
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
