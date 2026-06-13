import type { ImageCreateVariationParams, ImageEditParams, ImageGenerateParams, ImagesResponse } from '../../models/Images';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import type { OpenAIMultipartFormData } from '../core/Types';

/**
 * Images 资源入口。
 *
 * API：`/v1/images/*`。
 * 说明：覆盖图像生成、multipart 编辑和图像变体创建。
 */
export interface OpenAIImagesResource {
  /**
   * 生成图像。
   *
   * API：`POST /v1/images/generations`。
   * 说明：根据文本 prompt 生成图像。
   */
  generate(params: ImageGenerateParams): Promise<ImagesResponse>;

  /**
   * 编辑图像。
   *
   * API：`POST /v1/images/edits`。
   * 说明：使用 multipart 上传图片、mask 和文本参数。
   */
  edit(params: ImageEditParams): Promise<ImagesResponse>;

  /**
   * 创建图像变体。
   *
   * API：`POST /v1/images/variations`。
   * 说明：使用 multipart 上传基础图片并返回变体。
   */
  createVariation(params: ImageCreateVariationParams): Promise<ImagesResponse>;
}

export class ImagesResource implements OpenAIImagesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async generate(params: ImageGenerateParams): Promise<ImagesResponse> {
    const body = await this.client.post('/images/generations', params);
    return JSON.parse(body) as ImagesResponse;
  }

  async edit(params: ImageEditParams): Promise<ImagesResponse> {
    const parts = this.buildEditParts(params);
    const body = await this.client.postMultipart('/images/edits', parts);
    return JSON.parse(body) as ImagesResponse;
  }

  async createVariation(params: ImageCreateVariationParams): Promise<ImagesResponse> {
    const parts: Array<OpenAIMultipartFormData> = [];
    const imagePart: OpenAIMultipartFormData = {
      name: 'image',
      contentType: 'application/octet-stream',
      remoteFileName: this.fileNameFromPath(params.image),
      filePath: params.image,
    };
    parts.push(imagePart);
    if (params.model !== undefined && params.model !== null) {
      parts.push(this.textPart('model', params.model));
    }
    if (params.n !== undefined && params.n !== null) {
      parts.push(this.textPart('n', params.n.toString()));
    }
    if (params.response_format !== undefined && params.response_format !== null) {
      parts.push(this.textPart('response_format', params.response_format));
    }
    if (params.size !== undefined && params.size !== null) {
      parts.push(this.textPart('size', params.size));
    }
    if (params.user !== undefined) {
      parts.push(this.textPart('user', params.user));
    }
    const body = await this.client.postMultipart('/images/variations', parts);
    return JSON.parse(body) as ImagesResponse;
  }

  private textPart(name: string, data: string): OpenAIMultipartFormData {
    return {
      name: name,
      contentType: 'text/plain',
      data: data,
    };
  }

  private buildEditParts(params: ImageEditParams): Array<OpenAIMultipartFormData> {
    const parts: Array<OpenAIMultipartFormData> = [];
    if (typeof params.image === 'string') {
      parts.push(this.filePart('image', params.image));
    } else {
      for (let index = 0; index < params.image.length; index++) {
        parts.push(this.filePart('image', params.image[index]));
      }
    }
    parts.push(this.textPart('prompt', params.prompt));
    if (params.mask !== undefined && params.mask !== null) {
      parts.push(this.filePart('mask', params.mask));
    }
    if (params.model !== undefined && params.model !== null) {
      parts.push(this.textPart('model', params.model));
    }
    if (params.n !== undefined && params.n !== null) {
      parts.push(this.textPart('n', params.n.toString()));
    }
    if (params.output_format !== undefined && params.output_format !== null) {
      parts.push(this.textPart('output_format', params.output_format));
    }
    if (params.partial_images !== undefined && params.partial_images !== null) {
      parts.push(this.textPart('partial_images', params.partial_images.toString()));
    }
    if (params.quality !== undefined && params.quality !== null) {
      parts.push(this.textPart('quality', params.quality));
    }
    if (params.response_format !== undefined && params.response_format !== null) {
      parts.push(this.textPart('response_format', params.response_format));
    }
    if (params.size !== undefined && params.size !== null) {
      parts.push(this.textPart('size', params.size));
    }
    if (params.user !== undefined) {
      parts.push(this.textPart('user', params.user));
    }
    if (params.input_fidelity !== undefined && params.input_fidelity !== null) {
      parts.push(this.textPart('input_fidelity', params.input_fidelity));
    }
    return parts;
  }

  private filePart(name: string, path: string): OpenAIMultipartFormData {
    return {
      name: name,
      contentType: 'application/octet-stream',
      remoteFileName: this.fileNameFromPath(path),
      filePath: path,
    };
  }

  private fileNameFromPath(path: string): string {
    const index = path.lastIndexOf('/');
    if (index >= 0 && index < path.length - 1) {
      return path.substring(index + 1);
    }
    return path;
  }
}
