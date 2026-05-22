import type { CursorPageParams, OpenAIListResponse } from './Common';

/**
 * 文件用途。
 *
 * API：`POST /v1/files`。
 * 说明：决定上传文件可用于哪个 OpenAI 功能。
 */
export type FilePurpose =
  'assistants' | 'assistants_output' | 'batch' | 'batch_output' | 'fine-tune' | 'fine-tune-results' |
  'vision' | 'user_data' | 'evals';

/**
 * 创建文件请求。
 *
 * API：`POST /v1/files`。
 * 说明：上传文件，供 batch、fine-tuning、vision、evals 等 API 使用。
 */
export interface FileCreateParams {
  /**
   * 文件。
   *
   * API：Files。
   * 说明：Harmony HTTP 层可把本地 URI 或沙箱路径转换为 multipart 文件；模型层先用字符串承载。
   */
  file: string;

  /**
   * 文件用途。
   *
   * API：Files。
   * 说明：例如 batch 输入文件应使用 `batch`。
   */
  purpose: FilePurpose;
}

/**
 * 文件列表请求。
 *
 * API：`GET /v1/files`。
 * 说明：查询已上传文件。
 */
export interface FileListParams extends CursorPageParams {
  /**
   * 按用途过滤。
   *
   * API：Files list。
   * 说明：只返回指定 purpose 的文件。
   */
  purpose?: FilePurpose;
}

/**
 * OpenAI 文件对象。
 *
 * API：`POST /v1/files`、`GET /v1/files/{file_id}`、`GET /v1/files`。
 * 说明：表示一个已上传文件。
 */
export interface FileObject {
  /**
   * 文件 ID。
   *
   * API：Files。
   * 说明：后续在 batch、responses、fine-tuning 等 API 中引用该文件。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Files。
   * 说明：固定为 `file`。
   */
  object: 'file';

  /**
   * 文件大小。
   *
   * API：Files。
   * 说明：单位为字节。
   */
  bytes: number;

  /**
   * 创建时间。
   *
   * API：Files。
   * 说明：Unix 秒级时间戳。
   */
  created_at: number;

  /**
   * 文件名。
   *
   * API：Files。
   * 说明：上传时的原始文件名。
   */
  filename: string;

  /**
   * 文件用途。
   *
   * API：Files。
   * 说明：决定该文件可以被哪些 API 消费。
   */
  purpose: FilePurpose;

  /**
   * 文件状态。
   *
   * API：Files。
   * 说明：部分旧响应可能返回 processed、error 等状态。
   */
  status?: string;

  /**
   * 状态详情。
   *
   * API：Files。
   * 说明：当文件处理失败时可能包含错误原因。
   */
  status_details?: string | null;

  /**
   * 过期时间。
   *
   * API：Files、Uploads complete。
   * 说明：部分由 Uploads 或临时用途产生的文件会返回过期时间。
   */
  expires_at?: number | null;
}

/**
 * 删除文件响应。
 *
 * API：`DELETE /v1/files/{file_id}`。
 * 说明：表示文件删除结果。
 */
export interface FileDeleted {
  /**
   * 文件 ID。
   *
   * API：Files delete。
   * 说明：被删除的文件 ID。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Files delete。
   * 说明：固定为 `file`。
   */
  object: 'file';

  /**
   * 是否已删除。
   *
   * API：Files delete。
   * 说明：成功删除时为 true。
   */
  deleted: boolean;
}

/**
 * 文件列表响应。
 *
 * API：`GET /v1/files`。
 * 说明：返回文件对象列表。
 */
export type FileListResponse = OpenAIListResponse<FileObject>;

/**
 * 文件写入器。
 *
 * API：Files download。
 * 说明：测试或宿主可注入写入实现；默认实现使用 Harmony `fileIo` 写入目标路径。
 */
export interface FileContentWriter {
  /** 写入内容。API：Files download。说明：返回写入字节或字符数。 */
  write(destinationPath: string, contentBody: string): number;
}

/**
 * 文件下载选项。
 *
 * API：`GET /v1/files/{file_id}/content`。
 * 说明：允许测试注入 writer，生产默认使用 Harmony 文件系统。
 */
export interface FileDownloadOptions {
  /** 自定义写入器。API：Files download。说明：不传时使用 SDK 默认 fileIo 写入器。 */
  writer?: FileContentWriter;
}

/**
 * 文件下载结果。
 *
 * API：Files download。
 * 说明：表示内容已写入的目标路径和写入长度。
 */
export interface FileDownloadResult {
  /** 目标路径。API：Files download。说明：调用方传入的落盘路径。 */
  path: string;
  /** 写入长度。API：Files download。说明：默认 writer 返回写入字符数。 */
  bytes: number;
}
