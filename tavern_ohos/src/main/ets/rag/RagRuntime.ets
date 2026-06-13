import { EventBus } from '../runtime/EventBus';
import { VectorRuntime } from '../vector/VectorRuntime';
import type { VectorHit, VectorQueryParams, VectorQueryResult } from '../vector/VectorModels';
import type {
  RagChatMessage,
  RagChunk,
  RagRetrievedPayload,
  RagRetrievalInput,
  RagRetrievalResult,
} from './RagModels';

export class RagRuntime {
  private vectors: VectorRuntime;
  private events: EventBus;

  constructor(vectors: VectorRuntime, events: EventBus) {
    this.vectors = vectors;
    this.events = events;
  }

  retrieve(input: RagRetrievalInput): RagRetrievalResult {
    const queryParams: VectorQueryParams = {
      collectionIds: input.collectionIds.slice(),
      embedding: input.queryEmbedding.slice(),
      topK: input.topK,
      scoreThreshold: input.scoreThreshold,
      scope: input.scope,
    };
    const vectorResult: VectorQueryResult = this.vectors.query(queryParams);
    const chunks = new Array<RagChunk>();
    const scores = new Array<number>();
    for (let index = 0; index < vectorResult.hits.length; index += 1) {
      const chunk = this.chunkFromHit(vectorResult.hits[index]);
      chunks.push(chunk);
      scores.push(chunk.score);
    }

    const promptText = this.applyTemplate(input.promptTemplate, this.joinChunkText(chunks));
    const result: RagRetrievalResult = {
      query: input.query,
      chunks: this.copyChunks(chunks),
      scores: scores.slice(),
      promptText: promptText,
      debugTrace: this.buildDebugTrace(chunks),
    };
    const payload: RagRetrievedPayload = {
      query: result.query,
      chunks: this.copyChunks(result.chunks),
      scores: result.scores.slice(),
      promptText: result.promptText,
    };
    this.events.publish<RagRetrievedPayload>('rag.retrieved', payload);
    return this.copyResult(result);
  }

  buildQueryFromLastUserMessage(messages: Array<RagChatMessage>): string {
    for (let index = messages.length - 1; index >= 0; index -= 1) {
      if (messages[index].role === 'user') {
        return messages[index].content;
      }
    }
    return '';
  }

  buildQueryFromRecentChatWindow(messages: Array<RagChatMessage>, windowSize: number): string {
    const selected = new Array<string>();
    const start = messages.length > windowSize ? messages.length - windowSize : 0;
    for (let index = start; index < messages.length; index += 1) {
      if (messages[index].role === 'system') {
        continue;
      }
      selected.push(messages[index].content);
    }
    return selected.join('\n');
  }

  private chunkFromHit(hit: VectorHit): RagChunk {
    return {
      collectionId: hit.collectionId,
      vectorId: hit.vector.id,
      documentId: hit.vector.documentId,
      scope: hit.vector.scope,
      text: hit.vector.text,
      score: hit.score,
      metadataJson: hit.vector.metadataJson,
    };
  }

  private joinChunkText(chunks: Array<RagChunk>): string {
    const lines = new Array<string>();
    for (let index = 0; index < chunks.length; index += 1) {
      lines.push(chunks[index].text);
    }
    return lines.join('\n');
  }

  private applyTemplate(template: string, text: string): string {
    return template.split('${text}').join(text);
  }

  private buildDebugTrace(chunks: Array<RagChunk>): string {
    const parts = new Array<string>();
    for (let index = 0; index < chunks.length; index += 1) {
      parts.push(`${chunks[index].collectionId}:${chunks[index].vectorId}:${chunks[index].score}`);
    }
    return parts.join('\n');
  }

  private copyResult(result: RagRetrievalResult): RagRetrievalResult {
    return {
      query: result.query,
      chunks: this.copyChunks(result.chunks),
      scores: result.scores.slice(),
      promptText: result.promptText,
      debugTrace: result.debugTrace,
    };
  }

  private copyChunks(chunks: Array<RagChunk>): Array<RagChunk> {
    const result = new Array<RagChunk>();
    for (let index = 0; index < chunks.length; index += 1) {
      result.push(this.copyChunk(chunks[index]));
    }
    return result;
  }

  private copyChunk(chunk: RagChunk): RagChunk {
    return {
      collectionId: chunk.collectionId,
      vectorId: chunk.vectorId,
      documentId: chunk.documentId,
      scope: chunk.scope,
      text: chunk.text,
      score: chunk.score,
      metadataJson: chunk.metadataJson,
    };
  }
}
