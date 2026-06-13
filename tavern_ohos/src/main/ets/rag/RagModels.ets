import type { VectorHit } from '../vector/VectorModels';

export interface RagChatMessage {
  role: string;
  content: string;
}

export interface RagRetrievalInput {
  query: string;
  queryEmbedding: Array<number>;
  collectionIds: Array<string>;
  topK: number;
  scoreThreshold: number;
  scope: string;
  promptTemplate: string;
}

export interface RagChunk {
  collectionId: string;
  vectorId: string;
  documentId: string;
  scope: string;
  text: string;
  score: number;
  metadataJson: string;
}

export interface RagRetrievalResult {
  query: string;
  chunks: Array<RagChunk>;
  scores: Array<number>;
  promptText: string;
  debugTrace: string;
}

export interface RagRetrievedPayload {
  query: string;
  chunks: Array<RagChunk>;
  scores: Array<number>;
  promptText: string;
}

export interface RagVectorHitSource {
  hit: VectorHit;
}
