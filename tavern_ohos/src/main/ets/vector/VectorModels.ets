export interface VectorCollectionCreateParams {
  id: string;
  provider: string;
  model: string;
  dimension: number;
  metadataJson: string;
}

export interface VectorCollectionRecord {
  schemaVersion: number;
  id: string;
  provider: string;
  model: string;
  dimension: number;
  path: string;
  metadataJson: string;
  createdAt: number;
  updatedAt: number;
}

export interface VectorRecord {
  id: string;
  documentId: string;
  scope: string;
  text: string;
  embedding: Array<number>;
  metadataJson: string;
  createdAt: number;
  updatedAt: number;
}

export interface VectorHit {
  collectionId: string;
  vector: VectorRecord;
  score: number;
}

export interface VectorQueryParams {
  collectionIds: Array<string>;
  embedding: Array<number>;
  topK: number;
  scoreThreshold: number;
  scope: string;
}

export interface VectorQueryResult {
  hits: Array<VectorHit>;
}

export interface VectorUpsertPayload {
  collectionId: string;
  vector: VectorRecord;
}

export interface VectorDeletedPayload {
  collectionId: string;
  deletedIds: Array<string>;
}
