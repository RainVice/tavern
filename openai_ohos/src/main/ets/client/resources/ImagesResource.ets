import type { ImageCreateVariationParams, ImageEditParams, ImageGenerateParams, ImagesResponse } from '../../models/Images';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { buildTextPart, buildFilePart, fileNameFromPath } from '../core/RequestUtils';
import type { OpenAIMultipartFormData } from '../core/Types';

/**
 * Images 资源入口。
 *
 * API：`/v1/images/*`。
 * 说明：当前实现 JSON 请求形态的生成和编辑；multipart 文件上传能力后续在 upload 层补齐。
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
   * 说明：当前以模型层字符串字段承载图片引用，实际 multipart 文件上传后续增强。
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
      remoteFileName: fileNameFromPath(params.image),
      filePath: params.image,
    };
    parts.push(imagePart);
    if (params.model !== undefined && params.model !== null) {
      parts.push(buildTextPart('model', params.model));
    }
    if (params.n !== undefined && params.n !== null) {
      parts.push(buildTextPart('n', params.n.toString()));
    }
    if (params.response_format !== undefined && params.response_format !== null) {
      parts.push(buildTextPart('response_format', params.response_format));
    }
    if (params.size !== undefined && params.size !== null) {
      parts.push(buildTextPart('size', params.size));
    }
    if (params.user !== undefined) {
      parts.push(buildTextPart('user', params.user));
    }
    const body = await this.client.postMultipart('/images/variations', parts);
    return JSON.parse(body) as ImagesResponse;
  }

  private buildEditParts(params: ImageEditParams): Array<OpenAIMultipartFormData> {
    const parts: Array<OpenAIMultipartFormData> = [];
    if (typeof params.image === 'string') {
      parts.push(buildFilePart('image', params.image));
    } else {
      for (let index = 0; index < params.image.length; index++) {
        parts.push(buildFilePart('image', params.image[index]));
      }
    }
    parts.push(buildTextPart('prompt', params.prompt));
    if (params.mask !== undefined && params.mask !== null) {
      parts.push(buildFilePart('mask', params.mask));
    }
    if (params.model !== undefined && params.model !== null) {
      parts.push(buildTextPart('model', params.model));
    }
    if (params.background !== undefined && params.background !== null) {
      parts.push(buildTextPart('background', params.background));
    }
    if (params.moderation !== undefined && params.moderation !== null) {
      parts.push(buildTextPart('moderation', params.moderation));
    }
    if (params.n !== undefined && params.n !== null) {
      parts.push(buildTextPart('n', params.n.toString()));
    }
    if (params.output_compression !== undefined && params.output_compression !== null) {
      parts.push(buildTextPart('output_compression', params.output_compression.toString()));
    }
    if (params.output_format !== undefined && params.output_format !== null) {
      parts.push(buildTextPart('output_format', params.output_format));
    }
    if (params.partial_images !== undefined && params.partial_images !== null) {
      parts.push(buildTextPart('partial_images', params.partial_images.toString()));
    }
    if (params.quality !== undefined && params.quality !== null) {
      parts.push(buildTextPart('quality', params.quality));
    }
    if (params.response_format !== undefined && params.response_format !== null) {
      parts.push(buildTextPart('response_format', params.response_format));
    }
    if (params.size !== undefined && params.size !== null) {
      parts.push(buildTextPart('size', params.size));
    }
    if (params.stream !== undefined && params.stream !== null) {
      parts.push(buildTextPart('stream', params.stream.toString()));
    }
    if (params.style !== undefined && params.style !== null) {
      parts.push(buildTextPart('style', params.style));
    }
    if (params.user !== undefined) {
      parts.push(buildTextPart('user', params.user));
    }
    if (params.input_fidelity !== undefined && params.input_fidelity !== null) {
      parts.push(buildTextPart('input_fidelity', params.input_fidelity));
    }
    return parts;
  }

}
