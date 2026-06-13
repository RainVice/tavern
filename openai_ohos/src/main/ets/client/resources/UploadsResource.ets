import type { Upload, UploadCompleteParams, UploadCreateParams, UploadPart, UploadPartCreateParams } from '../../models/Uploads';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { buildFilePart, encodePathParam } from '../core/RequestUtils';

interface EmptyRequestBody {
}

/**
 * Uploads 资源入口。
 *
 * API：`/v1/uploads`。
 * 说明：管理大文件分片上传。
 */
export interface OpenAIUploadsResource {
  /** Parts 子资源。API：Upload Parts。说明：向 Upload 添加分片。 */
  parts: OpenAIUploadPartsResource;
  /** 创建 Upload。API：`POST /v1/uploads`。说明：声明即将上传的大文件。 */
  create(params: UploadCreateParams): Promise<Upload>;
  /** 完成 Upload。API：`POST /v1/uploads/{upload_id}/complete`。说明：按顺序合并 part 并生成 File。 */
  complete(uploadID: string, params: UploadCompleteParams): Promise<Upload>;
  /** 取消 Upload。API：`POST /v1/uploads/{upload_id}/cancel`。说明：取消后不能继续添加 part。 */
  cancel(uploadID: string): Promise<Upload>;
}

/**
 * Upload Parts 子资源。
 *
 * API：`/v1/uploads/{upload_id}/parts`。
 * 说明：上传单个分片。
 */
export interface OpenAIUploadPartsResource {
  /** 创建 part。API：Create Upload Part。说明：使用 multipart 字段 `data` 上传分片。 */
  create(uploadID: string, params: UploadPartCreateParams): Promise<UploadPart>;
}

export class UploadsResource implements OpenAIUploadsResource {
  parts: OpenAIUploadPartsResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.parts = new UploadPartsResource(client);
  }

  async create(params: UploadCreateParams): Promise<Upload> {
    const body = await this.client.post('/uploads', params);
    return JSON.parse(body) as Upload;
  }

  async complete(uploadID: string, params: UploadCompleteParams): Promise<Upload> {
    const body = await this.client.post('/uploads/' + encodePathParam(uploadID) + '/complete', params);
    return JSON.parse(body) as Upload;
  }

  async cancel(uploadID: string): Promise<Upload> {
    const requestBody: EmptyRequestBody = {};
    const body = await this.client.post('/uploads/' + encodePathParam(uploadID) + '/cancel', requestBody);
    return JSON.parse(body) as Upload;
  }
}

class UploadPartsResource implements OpenAIUploadPartsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(uploadID: string, params: UploadPartCreateParams): Promise<UploadPart> {
    const part = buildFilePart('data', params.data);
    const body = await this.client.postMultipart('/uploads/' + encodePathParam(uploadID) + '/parts', [part]);
    return JSON.parse(body) as UploadPart;
  }
}
