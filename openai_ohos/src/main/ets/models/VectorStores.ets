import type { CursorPageParams, JsonObject, Metadata, OpenAIListResponse } from './Common';

/**
 * Vector Stores API model。
 *
 * API：`/v1/vector_stores`、`/v1/vector_stores/{vector_store_id}/files`、`/v1/vector_stores/{vector_store_id}/file_batches`。
 * 说明：Vector Store 用于 File Search，能被 Responses 和 Assistants 的 `file_search` 工具检索。
 */

/**
 * Vector Store 状态。
 *
 * API：Vector Stores。
 * 说明：`completed` 表示索引可用；`in_progress` 表示仍在处理文件；`expired` 表示过期不可继续使用。
 */
export type VectorStoreStatus = 'expired' | 'in_progress' | 'completed';

/**
 * Vector Store 文件处理状态。
 *
 * API：Vector Store Files、Vector Store File Batches。
 * 说明：用于判断文件是否已经成功进入向量索引。
 */
export type VectorStoreFileStatus = 'in_progress' | 'completed' | 'failed' | 'cancelled';

/**
 * Vector Store 属性值。
 *
 * API：Vector Store Files、Vector Store File Batches。
 * 说明：文件属性用于筛选和查询，可传字符串、数字或布尔值。
 */
export type VectorStoreAttributeValue = string | number | boolean;

/**
 * Vector Store 文件统计。
 *
 * API：Vector Stores、Vector Store File Batches。
 * 说明：表示文件处理状态计数，便于业务判断索引是否准备完成。
 */
export interface VectorStoreFileCounts {
  /** 处理中数量。API：Vector Stores、Vector Store File Batches。说明：仍在解析、分块或嵌入的文件数量。 */
  in_progress: number;
  /** 已完成数量。API：Vector Stores、Vector Store File Batches。说明：已可被 File Search 检索的文件数量。 */
  completed: number;
  /** 失败数量。API：Vector Stores、Vector Store File Batches。说明：处理失败的文件数量。 */
  failed: number;
  /** 已取消数量。API：Vector Stores、Vector Store File Batches。说明：被取消处理的文件数量。 */
  cancelled: number;
  /** 总数量。API：Vector Stores、Vector Store File Batches。说明：该 Vector Store 或批次中的文件总数。 */
  total: number;
}

/**
 * Vector Store 过期策略。
 *
 * API：Create/Update Vector Store。
 * 说明：用于让临时知识库在一段时间后自动过期。
 */
export interface VectorStoreExpiresAfter {
  /** 过期锚点。API：Create/Update Vector Store。说明：当前官方支持 `last_active_at`。 */
  anchor: 'last_active_at';
  /** 锚点后的天数。API：Create/Update Vector Store。说明：到达该天数后 Vector Store 会过期。 */
  days: number;
}

/**
 * 静态分块配置。
 *
 * API：Vector Stores、Vector Store Files、Vector Store File Batches。
 * 说明：用于控制文件被切分成向量片段的 token 大小和重叠量。
 */
export interface VectorStoreStaticChunkingConfig {
  /** 每个 chunk 的最大 token 数。API：Vector Stores chunking strategy。说明：官方范围通常为 100 到 4096。 */
  max_chunk_size_tokens: number;
  /** chunk 间重叠 token 数。API：Vector Stores chunking strategy。说明：通常不能超过最大 chunk 的一半。 */
  chunk_overlap_tokens: number;
}

/**
 * 自动分块策略。
 *
 * API：Vector Stores chunking strategy。
 * 说明：让 OpenAI 使用默认分块配置。
 */
export interface VectorStoreAutoChunkingStrategy {
  /** 策略类型。API：Vector Stores chunking strategy。说明：固定为 `auto`。 */
  type: 'auto';
}

/**
 * 静态分块策略。
 *
 * API：Vector Stores chunking strategy。
 * 说明：开发者明确指定 chunk 大小和重叠 token 数。
 */
export interface VectorStoreStaticChunkingStrategy {
  /** 策略类型。API：Vector Stores chunking strategy。说明：固定为 `static`。 */
  type: 'static';
  /** 静态分块参数。API：Vector Stores chunking strategy。说明：包含最大 chunk token 数和重叠 token 数。 */
  static: VectorStoreStaticChunkingConfig;
}

/**
 * 其他分块策略。
 *
 * API：Vector Store File object。
 * 说明：官方可能在旧文件或未来策略中返回 `other`，SDK 保留该响应类型。
 */
export interface VectorStoreOtherChunkingStrategy {
  /** 策略类型。API：Vector Store File object。说明：表示不是当前 SDK 明确建模的策略。 */
  type: 'other';
}

/**
 * Vector Store 分块策略。
 *
 * API：Vector Stores、Vector Store Files、Vector Store File Batches。
 * 说明：请求中通常使用 `auto` 或 `static`；响应中可能出现 `other`。
 */
export type VectorStoreChunkingStrategy =
  VectorStoreAutoChunkingStrategy | VectorStoreStaticChunkingStrategy | VectorStoreOtherChunkingStrategy;

/**
 * Vector Store 对象。
 *
 * API：`GET /v1/vector_stores/{vector_store_id}`、`POST /v1/vector_stores`。
 * 说明：表示一个可被 File Search 使用的向量知识库。
 */
export interface VectorStore {
  /** Vector Store ID。API：Vector Stores。说明：后续文件关联、搜索、更新、删除都使用该 ID。 */
  id: string;
  /** 对象类型。API：Vector Stores。说明：固定为 `vector_store`。 */
  object: 'vector_store';
  /** 创建时间。API：Vector Stores。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 名称。API：Create/Update/Retrieve Vector Store。说明：用于开发者识别该知识库。 */
  name?: string | null;
  /** 描述。API：Create/Update/Retrieve Vector Store。说明：用于说明该知识库用途。 */
  description?: string | null;
  /** 占用字节数。API：Vector Stores。说明：该向量知识库当前使用的存储空间。 */
  usage_bytes: number;
  /** 文件统计。API：Vector Stores。说明：展示文件处理状态分布。 */
  file_counts: VectorStoreFileCounts;
  /** 状态。API：Vector Stores。说明：判断该向量知识库是否可用。 */
  status: VectorStoreStatus;
  /** 过期策略。API：Vector Stores。说明：存在时表示会按策略自动过期。 */
  expires_after?: VectorStoreExpiresAfter | null;
  /** 过期时间。API：Vector Stores。说明：Unix 秒级时间戳；未设置时可能为空。 */
  expires_at?: number | null;
  /** 最后活跃时间。API：Vector Stores。说明：用于基于活跃时间的过期策略。 */
  last_active_at?: number | null;
  /** 元数据。API：Vector Stores。说明：开发者自定义键值对。 */
  metadata?: Metadata | null;
}

/**
 * 创建 Vector Store 参数。
 *
 * API：`POST /v1/vector_stores`。
 * 说明：可同时传入文件 ID，创建后自动开始索引。
 */
export interface VectorStoreCreateParams {
  /** 名称。API：Create Vector Store。说明：用于识别知识库。 */
  name?: string;
  /** 描述。API：Create Vector Store。说明：用于描述知识库用途。 */
  description?: string;
  /** 文件 ID 列表。API：Create Vector Store。说明：创建时要加入知识库的文件。 */
  file_ids?: Array<string>;
  /** 分块策略。API：Create Vector Store。说明：仅在传入文件时适用。 */
  chunking_strategy?: VectorStoreChunkingStrategy;
  /** 过期策略。API：Create Vector Store。说明：用于临时知识库自动过期。 */
  expires_after?: VectorStoreExpiresAfter;
  /** 元数据。API：Create Vector Store。说明：开发者自定义键值对。 */
  metadata?: Metadata;
}

/**
 * 更新 Vector Store 参数。
 *
 * API：`POST /v1/vector_stores/{vector_store_id}`。
 * 说明：用于修改名称、描述、元数据和过期策略。
 */
export interface VectorStoreUpdateParams {
  /** 名称。API：Update Vector Store。说明：新的知识库名称。 */
  name?: string | null;
  /** 描述。API：Update Vector Store。说明：新的用途描述。 */
  description?: string | null;
  /** 过期策略。API：Update Vector Store。说明：设置或调整自动过期。 */
  expires_after?: VectorStoreExpiresAfter | null;
  /** 元数据。API：Update Vector Store。说明：替换自定义键值对。 */
  metadata?: Metadata | null;
}

/** Vector Store 列表参数。API：`GET /v1/vector_stores`。说明：使用游标分页读取知识库列表。 */
export interface VectorStoreListParams extends CursorPageParams {
}

/** Vector Store 列表响应。API：`GET /v1/vector_stores`。说明：列表元素为 `VectorStore`。 */
export type VectorStoreListResponse = OpenAIListResponse<VectorStore>;

/**
 * 删除 Vector Store 响应。
 *
 * API：`DELETE /v1/vector_stores/{vector_store_id}`。
 * 说明：表示删除是否成功。
 */
export interface VectorStoreDeleted {
  /** ID。API：Delete Vector Store。说明：被删除的 Vector Store ID。 */
  id: string;
  /** 对象类型。API：Delete Vector Store。说明：通常为 `vector_store.deleted`。 */
  object: string;
  /** 删除结果。API：Delete Vector Store。说明：`true` 表示已删除。 */
  deleted: boolean;
}

/** Vector Store 文件错误。API：Vector Store Files。说明：文件处理失败时返回错误原因。 */
export interface VectorStoreFileLastError {
  /** 错误代码。API：Vector Store Files。说明：机器可读错误类型。 */
  code: string;
  /** 错误消息。API：Vector Store Files。说明：开发者可读错误描述。 */
  message: string;
}

/**
 * Vector Store File 对象。
 *
 * API：`/v1/vector_stores/{vector_store_id}/files`。
 * 说明：表示已关联到 Vector Store 的单个文件。
 */
export interface VectorStoreFile {
  /** 文件 ID。API：Vector Store Files。说明：关联的 OpenAI File ID。 */
  id: string;
  /** 对象类型。API：Vector Store Files。说明：固定为 `vector_store.file`。 */
  object: 'vector_store.file';
  /** 创建时间。API：Vector Store Files。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 所属 Vector Store ID。API：Vector Store Files。说明：文件所在知识库。 */
  vector_store_id: string;
  /** 文件处理状态。API：Vector Store Files。说明：表示是否索引完成。 */
  status: VectorStoreFileStatus;
  /** 占用字节数。API：Vector Store Files。说明：该文件索引占用空间。 */
  usage_bytes: number;
  /** 最后错误。API：Vector Store Files。说明：失败时包含原因。 */
  last_error?: VectorStoreFileLastError | null;
  /** 分块策略。API：Vector Store Files。说明：该文件实际使用的切分策略。 */
  chunking_strategy?: VectorStoreChunkingStrategy;
  /** 属性。API：Vector Store Files。说明：文件级可检索属性。 */
  attributes?: Record<string, VectorStoreAttributeValue>;
}

/** 创建 Vector Store File 参数。API：Create Vector Store File。说明：把已上传 File 加入指定 Vector Store。 */
export interface VectorStoreFileCreateParams {
  /** 文件 ID。API：Create Vector Store File。说明：要关联的 OpenAI File ID。 */
  file_id: string;
  /** 属性。API：Create Vector Store File。说明：文件级可检索属性。 */
  attributes?: Record<string, VectorStoreAttributeValue>;
  /** 分块策略。API：Create Vector Store File。说明：覆盖该文件的切分方式。 */
  chunking_strategy?: VectorStoreChunkingStrategy;
}

/** Vector Store File 列表参数。API：List Vector Store Files。说明：支持分页和按文件状态筛选。 */
export interface VectorStoreFileListParams extends CursorPageParams {
  /** 状态筛选。API：List Vector Store Files。说明：只返回指定处理状态的文件。 */
  filter?: VectorStoreFileStatus;
}

/** Vector Store File 列表响应。API：List Vector Store Files。说明：列表元素为 Vector Store File。 */
export type VectorStoreFileListResponse = OpenAIListResponse<VectorStoreFile>;

/** 删除 Vector Store File 响应。API：Delete Vector Store File。说明：只解除文件与 Vector Store 的关联。 */
export interface VectorStoreFileDeleted {
  /** 文件 ID。API：Delete Vector Store File。说明：被移除的文件 ID。 */
  id: string;
  /** 对象类型。API：Delete Vector Store File。说明：通常为 `vector_store.file.deleted`。 */
  object: string;
  /** 删除结果。API：Delete Vector Store File。说明：`true` 表示关联已删除。 */
  deleted: boolean;
}

/** 批量创建中的单文件配置。API：Create Vector Store File Batch。说明：用于单文件独立属性或分块策略。 */
export interface VectorStoreFileBatchCreateFile {
  /** 文件 ID。API：Create Vector Store File Batch。说明：要加入批次的文件。 */
  file_id: string;
  /** 属性。API：Create Vector Store File Batch。说明：该文件专属属性。 */
  attributes?: Record<string, VectorStoreAttributeValue>;
  /** 分块策略。API：Create Vector Store File Batch。说明：该文件专属分块策略。 */
  chunking_strategy?: VectorStoreChunkingStrategy;
}

/** 创建 Vector Store File Batch 参数。API：Create Vector Store File Batch。说明：批量把多个文件加入 Vector Store。 */
export interface VectorStoreFileBatchCreateParams {
  /** 文件 ID 列表。API：Create Vector Store File Batch。说明：与 `files` 二选一。 */
  file_ids?: Array<string>;
  /** 文件对象列表。API：Create Vector Store File Batch。说明：用于分别设置属性或分块策略。 */
  files?: Array<VectorStoreFileBatchCreateFile>;
  /** 全局属性。API：Create Vector Store File Batch。说明：批次内文件共享属性。 */
  attributes?: Record<string, VectorStoreAttributeValue>;
  /** 全局分块策略。API：Create Vector Store File Batch。说明：批次内文件共享分块策略。 */
  chunking_strategy?: VectorStoreChunkingStrategy;
}

/** Vector Store File Batch 对象。API：Vector Store File Batches。说明：表示批量文件索引任务。 */
export interface VectorStoreFileBatch {
  /** 批次 ID。API：Vector Store File Batches。说明：用于查询或取消批次。 */
  id: string;
  /** 对象类型。API：Vector Store File Batches。说明：固定为 `vector_store.file_batch`。 */
  object: 'vector_store.file_batch';
  /** 创建时间。API：Vector Store File Batches。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 所属 Vector Store ID。API：Vector Store File Batches。说明：批次所属知识库。 */
  vector_store_id: string;
  /** 批次状态。API：Vector Store File Batches。说明：表示批量处理是否完成。 */
  status: VectorStoreFileStatus;
  /** 文件统计。API：Vector Store File Batches。说明：批次内各状态文件数量。 */
  file_counts: VectorStoreFileCounts;
}

/** Vector Store 搜索内容片段。API：Search Vector Store。说明：搜索结果中命中的文本片段。 */
export interface VectorStoreSearchResultContent {
  /** 内容类型。API：Search Vector Store。说明：当前常见为 `text`。 */
  type: 'text';
  /** 文本内容。API：Search Vector Store。说明：命中的原文片段。 */
  text: string;
}

/** Vector Store 搜索结果。API：Search Vector Store。说明：表示一个文件里的命中结果。 */
export interface VectorStoreSearchResult {
  /** 文件 ID。API：Search Vector Store。说明：命中的文件。 */
  file_id: string;
  /** 文件名。API：Search Vector Store。说明：命中文件名称。 */
  filename: string;
  /** 相似度分数。API：Search Vector Store。说明：分数越高越相关。 */
  score: number;
  /** 文件属性。API：Search Vector Store。说明：可用于展示或业务筛选。 */
  attributes: Record<string, VectorStoreAttributeValue>;
  /** 内容片段。API：Search Vector Store。说明：命中的文本数组。 */
  content: Array<VectorStoreSearchResultContent>;
}

/** Vector Store 搜索参数。API：Search Vector Store。说明：对指定 Vector Store 做语义搜索。 */
export interface VectorStoreSearchParams {
  /** 查询文本。API：Search Vector Store。说明：可以是单个字符串或多个查询。 */
  query: string | Array<string>;
  /** 最大返回数量。API：Search Vector Store。说明：限制搜索结果数。 */
  max_num_results?: number;
  /** 是否重写查询。API：Search Vector Store。说明：允许服务端优化查询表达。 */
  rewrite_query?: boolean;
  /** 过滤条件。API：Search Vector Store。说明：按文件属性过滤，结构由官方过滤语法决定。 */
  filters?: JsonObject;
  /** 排名参数。API：Search Vector Store。说明：保留为 JSON 对象以兼容官方扩展。 */
  ranking_options?: JsonObject;
}

/** Vector Store 搜索响应。API：Search Vector Store。说明：返回搜索结果页。 */
export interface VectorStoreSearchResponse {
  /** 对象类型。API：Search Vector Store。说明：官方通常返回搜索结果 page 类型。 */
  object: string;
  /** 搜索结果。API：Search Vector Store。说明：按相关性排列的命中列表。 */
  data: Array<VectorStoreSearchResult>;
  /** 是否还有下一页。API：Search Vector Store。说明：用于继续分页查询。 */
  has_more?: boolean;
  /** 下一页游标。API：Search Vector Store。说明：存在时可继续读取更多结果。 */
  next_page?: string | null;
}
