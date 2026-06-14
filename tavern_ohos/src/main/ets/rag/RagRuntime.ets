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
   * 向量检索运行时，用于执行向量查询以获取语义相似的文本片段。
   */
  private vectors: VectorRuntime;
  /**
   * 事件总线，用于发布 RAG 检索完成事件。
   */
  private events: EventBus;

  /**
   * 通过依赖注入初始化 RAG 检索运行时。
   * @param events 事件总线实例，用于发布 rag.retrieved 事件。
   */
  constructor(vectors: VectorRuntime, events: EventBus) {
    this.vectors = vectors;
    this.events = events;
  }

  /**
   * 执行 RAG 向量检索：将输入转换为向量查询、从向量库检索命中、生成 Prompt 文本并发布检索事件。
   * 在 LLM 请求组装流程中调用，用于为 Prompt 注入外部知识上下文。
   * @param input 检索输入参数（查询文本、向量、集合范围、阈值等）。
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
   * 从消息列表中提取最后一条用户消息的文本内容，用于构建 RAG 查询。
   * 在消息流式渲染或消息发送完成后调用，以用户最新输入作为语义检索依据。
   * @param messages 聊天消息列表，按时间正序排列。
   * @returns 最后一条用户消息的文本，无用户消息时返回空字符串。
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
   * 从最近的消息窗口中提取非系统角色的消息内容，拼接为查询字符串。
   * 在需要更丰富的对话上下文进行语义检索时调用，而非仅使用单条用户消息。
   * @param messages 聊天消息列表，按时间正序排列。
   * @param windowSize 最近消息窗口大小，限定参与拼接的消息数量。
   * @returns 拼接后的查询字符串。
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
   * 根据命中结果构建调试追踪字符串，格式为 "collectionId:vectorId:score"，每行一个命中。
   * @returns 换行分隔的调试追踪字符串。
   */
  private buildDebugTrace(chunks: Array<RagChunk>): string {
    const parts = new Array<string>();
    for (let index = 0; index < chunks.length; index += 1) {
      parts.push(`${chunks[index].collectionId}:${chunks[index].vectorId}:${chunks[index].score}`);
    }
    return parts.join('\n');
  }

  /**
   * 深拷贝检索结果对象，防止外部修改内部状态。
   * @param result 待拷贝的检索结果。
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
   * 深拷贝文本片段列表，防止外部修改内部数据。
   * @returns 文本片段列表的深拷贝。
   */
  private copyChunks(chunks: Array<RagChunk>): Array<RagChunk> {
    const result = new Array<RagChunk>();
    for (let index = 0; index < chunks.length; index += 1) {
      result.push(this.copyChunk(chunks[index]));
    }
    return result;
  }

  /**
   * 深拷贝单个文本片段对象。
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
