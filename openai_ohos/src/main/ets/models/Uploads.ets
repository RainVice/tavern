import type { FileObject, FilePurpose } from './Files';

/**
 * Uploads API model。
 *
 * API：`/v1/uploads`。
 * 说明：用于大文件分片上传。创建 Upload 后添加 Part，最后 complete 生成可被其他 API 使用的 File。
 */

/** Upload 状态。API：Uploads。说明：表示分片上传生命周期。 */
export type UploadStatus = 'pending' | 'completed' | 'cancelled' | 'expired';

/**
 * Upload 过期策略。
 *
 * API：Create Upload。
 * 说明：用于声明 Upload 从创建开始多久后过期。
 */
export interface UploadExpiresAfter {
  /** 过期锚点。API：Create Upload。说明：当前官方使用 `created_at`。 */
  anchor: 'created_at';
  /** 秒数。API：Create Upload。说明：从锚点开始经过多少秒后过期。 */
  seconds: number;
}

/**
 * 创建 Upload 参数。
 *
 * API：`POST /v1/uploads`。
 * 说明：声明即将上传文件的总大小、文件名、MIME 类型和用途。
 */
export interface UploadCreateParams {
  /** 文件总字节数。API：Create Upload。说明：complete 时已上传 part 总大小必须与该值匹配。 */
  bytes: number;
  /** 文件名。API：Create Upload。说明：最终生成 File 对象时使用的文件名。 */
  filename: string;
  /** MIME 类型。API：Create Upload。说明：例如 `text/jsonl`、`application/pdf`。 */
  mime_type: string;
  /** 文件用途。API：Create Upload。说明：决定最终 File 可用于 fine-tuning、batch、vision 等场景。 */
  purpose: FilePurpose;
  /** 过期策略。API：Create Upload。说明：不传时使用平台默认过期时间。 */
  expires_after?: UploadExpiresAfter;
}

/**
 * Upload 对象。
 *
 * API：Create/Complete/Cancel Upload。
 * 说明：表示一次还未或已经完成的大文件分片上传。
 */
export interface Upload {
  /** Upload ID。API：Uploads。说明：添加 part、complete、cancel 都使用该 ID。 */
  id: string;
  /** 对象类型。API：Uploads。说明：固定为 `upload`。 */
  object: 'upload';
  /** 文件总字节数。API：Uploads。说明：创建时声明的目标文件大小。 */
  bytes: number;
  /** 创建时间。API：Uploads。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 过期时间。API：Uploads。说明：Unix 秒级时间戳。 */
  expires_at: number;
  /** 文件名。API：Uploads。说明：最终 File 的文件名。 */
  filename: string;
  /** 文件用途。API：Uploads。说明：最终 File 的 purpose。 */
  purpose: FilePurpose;
  /** 状态。API：Uploads。说明：pending、completed、cancelled 或 expired。 */
  status: UploadStatus;
  /** 完成后生成的 File。API：Complete Upload。说明：仅 complete 成功后的响应包含。 */
  file?: FileObject;
}

/**
 * 创建 Upload Part 参数。
 *
 * API：`POST /v1/uploads/{upload_id}/parts`。
 * 说明：上传一个分片。当前 Harmony SDK 使用本地文件路径或 URI 交给 multipart transport。
 */
export interface UploadPartCreateParams {
  /** 分片文件路径。API：Create Upload Part。说明：multipart 字段名为 `data`。 */
  data: string;
}

/**
 * Upload Part 对象。
 *
 * API：Create Upload Part。
 * 说明：表示已经加入 Upload 的一个分片。
 */
export interface UploadPart {
  /** Part ID。API：Upload Parts。说明：complete 时按顺序传入 `part_ids`。 */
  id: string;
  /** 对象类型。API：Upload Parts。说明：固定为 `upload.part`。 */
  object: 'upload.part';
  /** 创建时间。API：Upload Parts。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 所属 Upload ID。API：Upload Parts。说明：该分片归属的 Upload。 */
  upload_id: string;
}

/**
 * Complete Upload 参数。
 *
 * API：`POST /v1/uploads/{upload_id}/complete`。
 * 说明：按顺序提交 part ID，服务端拼接后生成 File。
 */
export interface UploadCompleteParams {
  /** Part ID 列表。API：Complete Upload。说明：必须按文件内容顺序排列。 */
  part_ids: Array<string>;
  /** MD5 校验。API：Complete Upload。说明：可选，用于验证最终文件内容。 */
  md5?: string;
}
