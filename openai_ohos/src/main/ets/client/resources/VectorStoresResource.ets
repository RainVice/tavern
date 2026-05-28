import type {
  VectorStore,
  VectorStoreCreateParams,
  VectorStoreDeleted,
  VectorStoreFile,
  VectorStoreFileBatch,
  VectorStoreFileBatchCreateParams,
  VectorStoreFileCreateParams,
  VectorStoreFileDeleted,
  VectorStoreFileListParams,
  VectorStoreFileListResponse,
  VectorStoreListParams,
  VectorStoreListResponse,
  VectorStoreSearchParams,
  VectorStoreSearchResponse,
  VectorStoreUpdateParams,
} from '../../models/VectorStores';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { appendCursorQuery, buildCursorListPath, buildPathWithQuery } from '../core/RequestUtils';

interface EmptyRequestBody {
}

/**
 * Vector Stores 资源入口。
 *
 * API：`/v1/vector_stores`。
 * 说明：管理 File Search 使用的向量知识库。
 */
export interface OpenAIVectorStoresResource {
  /** 文件子资源。API：Vector Store Files。说明：管理知识库内的单个文件关联。 */
  files: OpenAIVectorStoreFilesResource;
  /** 文件批次子资源。API：Vector Store File Batches。说明：批量关联和处理文件。 */
  fileBatches: OpenAIVectorStoreFileBatchesResource;
  /** 创建 Vector Store。API：`POST /v1/vector_stores`。说明：创建一个新的向量知识库。 */
  create(params: VectorStoreCreateParams): Promise<VectorStore>;
  /** 获取 Vector Store。API：`GET /v1/vector_stores/{vector_store_id}`。说明：读取知识库状态。 */
  retrieve(vectorStoreID: string): Promise<VectorStore>;
  /** 更新 Vector Store。API：`POST /v1/vector_stores/{vector_store_id}`。说明：修改名称、描述、元数据等。 */
  update(vectorStoreID: string, params: VectorStoreUpdateParams): Promise<VectorStore>;
  /** 列出 Vector Stores。API：`GET /v1/vector_stores`。说明：分页读取知识库列表。 */
  list(params?: VectorStoreListParams): Promise<VectorStoreListResponse>;
  /** 删除 Vector Store。API：`DELETE /v1/vector_stores/{vector_store_id}`。说明：删除知识库。 */
  delete(vectorStoreID: string): Promise<VectorStoreDeleted>;
  /** 搜索 Vector Store。API：`POST /v1/vector_stores/{vector_store_id}/search`。说明：执行语义检索。 */
  search(vectorStoreID: string, params: VectorStoreSearchParams): Promise<VectorStoreSearchResponse>;
}

/**
 * Vector Store Files 子资源。
 *
 * API：`/v1/vector_stores/{vector_store_id}/files`。
 * 说明：把已上传文件加入或移出向量知识库。
 */
export interface OpenAIVectorStoreFilesResource {
  /** 创建文件关联。API：Create Vector Store File。说明：把 File 加入 Vector Store。 */
  create(vectorStoreID: string, params: VectorStoreFileCreateParams): Promise<VectorStoreFile>;
  /** 获取文件关联。API：Retrieve Vector Store File。说明：读取单个文件处理状态。 */
  retrieve(vectorStoreID: string, fileID: string): Promise<VectorStoreFile>;
  /** 列出文件关联。API：List Vector Store Files。说明：分页读取知识库内文件。 */
  list(vectorStoreID: string, params?: VectorStoreFileListParams): Promise<VectorStoreFileListResponse>;
  /** 删除文件关联。API：Delete Vector Store File。说明：从知识库移除文件。 */
  delete(vectorStoreID: string, fileID: string): Promise<VectorStoreFileDeleted>;
}

/**
 * Vector Store File Batches 子资源。
 *
 * API：`/v1/vector_stores/{vector_store_id}/file_batches`。
 * 说明：批量把文件加入向量知识库。
 */
export interface OpenAIVectorStoreFileBatchesResource {
  /** 创建文件批次。API：Create Vector Store File Batch。说明：批量加入文件。 */
  create(vectorStoreID: string, params: VectorStoreFileBatchCreateParams): Promise<VectorStoreFileBatch>;
  /** 获取文件批次。API：Retrieve Vector Store File Batch。说明：读取批次处理状态。 */
  retrieve(vectorStoreID: string, batchID: string): Promise<VectorStoreFileBatch>;
  /** 取消文件批次。API：Cancel Vector Store File Batch。说明：请求停止处理批次。 */
  cancel(vectorStoreID: string, batchID: string): Promise<VectorStoreFileBatch>;
  /** 列出批次文件。API：List Vector Store Files in Batch。说明：分页读取批次内文件。 */
  listFiles(vectorStoreID: string, batchID: string, params?: VectorStoreFileListParams): Promise<VectorStoreFileListResponse>;
}

export class VectorStoresResource implements OpenAIVectorStoresResource {
  files: OpenAIVectorStoreFilesResource;
  fileBatches: OpenAIVectorStoreFileBatchesResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.files = new VectorStoreFilesResource(client);
    this.fileBatches = new VectorStoreFileBatchesResource(client);
  }

  async create(params: VectorStoreCreateParams): Promise<VectorStore> {
    const body = await this.client.post('/vector_stores', params);
    return JSON.parse(body) as VectorStore;
  }

  async retrieve(vectorStoreID: string): Promise<VectorStore> {
    const body = await this.client.get('/vector_stores/' + encodeURIComponent(vectorStoreID));
    return JSON.parse(body) as VectorStore;
  }

  async update(vectorStoreID: string, params: VectorStoreUpdateParams): Promise<VectorStore> {
    const body = await this.client.post('/vector_stores/' + encodeURIComponent(vectorStoreID), params);
    return JSON.parse(body) as VectorStore;
  }

  async list(params?: VectorStoreListParams): Promise<VectorStoreListResponse> {
    const body = await this.client.get(buildCursorListPath('/vector_stores', params));
    return JSON.parse(body) as VectorStoreListResponse;
  }

  async delete(vectorStoreID: string): Promise<VectorStoreDeleted> {
    const body = await this.client.delete('/vector_stores/' + encodeURIComponent(vectorStoreID));
    return JSON.parse(body) as VectorStoreDeleted;
  }

  async search(vectorStoreID: string, params: VectorStoreSearchParams): Promise<VectorStoreSearchResponse> {
    const body = await this.client.post('/vector_stores/' + encodeURIComponent(vectorStoreID) + '/search', params);
    return JSON.parse(body) as VectorStoreSearchResponse;
  }
}

class VectorStoreFilesResource implements OpenAIVectorStoreFilesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(vectorStoreID: string, params: VectorStoreFileCreateParams): Promise<VectorStoreFile> {
    const body = await this.client.post('/vector_stores/' + encodeURIComponent(vectorStoreID) + '/files', params);
    return JSON.parse(body) as VectorStoreFile;
  }

  async retrieve(vectorStoreID: string, fileID: string): Promise<VectorStoreFile> {
    const body = await this.client.get(
      '/vector_stores/' + encodeURIComponent(vectorStoreID) + '/files/' + encodeURIComponent(fileID)
    );
    return JSON.parse(body) as VectorStoreFile;
  }

  async list(vectorStoreID: string, params?: VectorStoreFileListParams): Promise<VectorStoreFileListResponse> {
    const body = await this.client.get(
      buildFileListPath('/vector_stores/' + encodeURIComponent(vectorStoreID) + '/files', params)
    );
    return JSON.parse(body) as VectorStoreFileListResponse;
  }

  async delete(vectorStoreID: string, fileID: string): Promise<VectorStoreFileDeleted> {
    const body = await this.client.delete(
      '/vector_stores/' + encodeURIComponent(vectorStoreID) + '/files/' + encodeURIComponent(fileID)
    );
    return JSON.parse(body) as VectorStoreFileDeleted;
  }
}

class VectorStoreFileBatchesResource implements OpenAIVectorStoreFileBatchesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(vectorStoreID: string, params: VectorStoreFileBatchCreateParams): Promise<VectorStoreFileBatch> {
    const body = await this.client.post(
      '/vector_stores/' + encodeURIComponent(vectorStoreID) + '/file_batches', params
    );
    return JSON.parse(body) as VectorStoreFileBatch;
  }

  async retrieve(vectorStoreID: string, batchID: string): Promise<VectorStoreFileBatch> {
    const body = await this.client.get(
      '/vector_stores/' + encodeURIComponent(vectorStoreID) + '/file_batches/' + encodeURIComponent(batchID)
    );
    return JSON.parse(body) as VectorStoreFileBatch;
  }

  async cancel(vectorStoreID: string, batchID: string): Promise<VectorStoreFileBatch> {
    const requestBody: EmptyRequestBody = {};
    const body = await this.client.post(
      '/vector_stores/' + encodeURIComponent(vectorStoreID) + '/file_batches/' +
        encodeURIComponent(batchID) + '/cancel', requestBody
    );
    return JSON.parse(body) as VectorStoreFileBatch;
  }

  async listFiles(vectorStoreID: string, batchID: string, params?: VectorStoreFileListParams): Promise<VectorStoreFileListResponse> {
    const path = '/vector_stores/' + encodeURIComponent(vectorStoreID) + '/file_batches/' +
      encodeURIComponent(batchID) + '/files';
    const body = await this.client.get(buildFileListPath(path, params));
    return JSON.parse(body) as VectorStoreFileListResponse;
  }
}

function buildFileListPath(path: string, params?: VectorStoreFileListParams): string {
  if (params === undefined) {
    return path;
  }
  const query: Array<string> = [];
  appendCursorQuery(query, params);
  if (params.filter !== undefined) {
    query.push('filter=' + params.filter);
  }
  return buildPathWithQuery(path, query);
}
