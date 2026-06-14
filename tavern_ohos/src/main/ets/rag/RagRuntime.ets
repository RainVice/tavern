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

/**
 * 提供RAG 检索相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class RagRuntime {
  /**
   * 向量检索运行时实例。
   */
  private vectors: VectorRuntime;
  /**
   * 事件总线。
   */
  private events: EventBus;

  /**
   * 注入RAG 检索运行时依赖并初始化实例状态。

   * @param events 事件总线。
   */
  constructor(vectors: VectorRuntime, events: EventBus) {
    this.vectors = vectors;
    this.events = events;
  }

  /**
   * 执行完整RAG 检索流程：将输入转换为向量查询，查询向量库，将命中结果组装为片段，
   * 应用 prompt 模板，发布检索事件，返回最终结果。
   *
   * @param input 检索输入参数
   * @returns 检索结果，包含命中的片段、得分和生成的 prompt 文本
   */
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

  /**
   * 根据入参构建Query From Last User Message 值，仅生成数据结构，不直接执行外部请求。
   * @param messages 消息列表。
   * @returns 检索到的向量命中列表副本
   */
  buildQueryFromLastUserMessage(messages: Array<RagChatMessage>): string {
    for (let index = messages.length - 1; index >= 0; index -= 1) {
      if (messages[index].role === 'user') {
        return messages[index].content;
      }
    }
    return '';
  }

  /**
   * 根据入参构建Query From Recent Chat Window 值，仅生成数据结构，不直接执行外部请求。
   * @param messages 消息列表。

   * @returns 检索到的向量命中列表副本
   */
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

  /**
   * 根据入参构建Debug Trace 值，仅生成数据结构，不直接执行外部请求。

   * @returns 检索到的向量命中列表副本
   */
  private buildDebugTrace(chunks: Array<RagChunk>): string {
    const parts = new Array<string>();
    for (let index = 0; index < chunks.length; index += 1) {
      parts.push(`${chunks[index].collectionId}:${chunks[index].vectorId}:${chunks[index].score}`);
    }
    return parts.join('\n');
  }

  /**
   * 复制Result 值，避免外部修改内部状态。
   * @param result 返回结果。
   */
  private copyResult(result: RagRetrievalResult): RagRetrievalResult {
    return {
      query: result.query,
      chunks: this.copyChunks(result.chunks),
      scores: result.scores.slice(),
      promptText: result.promptText,
      debugTrace: result.debugTrace,
    };
  }

  /**
   * 复制Chunks 列表，避免外部修改内部状态。

   * @returns 检索到的向量命中列表副本
   */
  private copyChunks(chunks: Array<RagChunk>): Array<RagChunk> {
    const result = new Array<RagChunk>();
    for (let index = 0; index < chunks.length; index += 1) {
      result.push(this.copyChunk(chunks[index]));
    }
    return result;
  }

  /**
   * 复制Chunk 值，避免外部修改内部状态。
   */
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
