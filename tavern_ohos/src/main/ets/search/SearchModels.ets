export interface SearchDocumentMetadata {
  key: string;
  value: string;
}

export interface SearchDocument {
  id: string;
  domain: string;
  title: string;
  body: string;
  tags: Array<string>;
  path: string;
  metadata: Array<SearchDocumentMetadata>;
  updatedAt: number;
}

export interface SearchFilterEntity {
  id: string;
  type: string;
  title: string;
  body: string;
  tags: Array<string>;
  favorite: boolean;
  group: boolean;
  folder: boolean;
}

export interface SearchFilterInput {
  search: string;
  selectedTags: Array<string>;
  excludedTags: Array<string>;
  favoriteOnly: boolean;
  groupOnly: boolean;
  folderOnly: boolean;
}

export interface SearchQuery {
  text: string;
  domains: Array<string>;
  tags: Array<string>;
  metadataKey: string;
  metadataValue: string;
  limit: number;
}

export interface SearchHit {
  documentId: string;
  domain: string;
  title: string;
  snippet: string;
  score: number;
  path: string;
  tags: Array<string>;
  metadata: Array<SearchDocumentMetadata>;
}

export interface SearchResult {
  query: SearchQuery;
  total: number;
  hits: Array<SearchHit>;
}

export interface SearchIndexedPayload {
  document: SearchDocument;
}

export interface SearchRemovedPayload {
  documentId: string;
}
