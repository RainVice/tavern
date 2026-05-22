import type {
  VideoCharacter,
  VideoCharacterCreateParams,
  VideoCreateParams,
  VideoDeleted,
  VideoDownloadContentParams,
  VideoEditParams,
  VideoExtendParams,
  VideoJob,
  VideoListParams,
  VideoListResponse,
  VideoRemixParams,
} from '../../models/Videos';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { appendStringQuery, buildFilePart, buildPathWithQuery, buildTextPart } from '../core/RequestUtils';
import type { OpenAIMultipartFormData } from '../core/Types';

/**
 * Videos 资源入口。
 *
 * API：`/v1/videos`。
 * 说明：创建、查询、下载、remix 和删除视频生成任务。
 */
export interface OpenAIVideosResource {
  /**
   * 视频角色资源。
   *
   * API：`/v1/videos/characters`。
   * 说明：创建和读取可复用的视频角色。
   */
  characters: OpenAIVideoCharactersResource;

  /**
   * 创建视频任务。
   *
   * API：`POST /v1/videos`。
   * 说明：使用 prompt 和可选参考图片创建视频生成任务。
   */
  create(params: VideoCreateParams): Promise<VideoJob>;

  /**
   * 列出视频任务。
   *
   * API：`GET /v1/videos`。
   * 说明：分页读取当前项目最近生成的视频任务。
   */
  list(params?: VideoListParams): Promise<VideoListResponse>;

  /**
   * 获取视频任务。
   *
   * API：`GET /v1/videos/{video_id}`。
   * 说明：读取单个视频任务的最新元数据。
   */
  retrieve(videoID: string): Promise<VideoJob>;

  /**
   * 下载视频内容。
   *
   * API：`GET /v1/videos/{video_id}/content`。
   * 说明：返回 base64 编码的视频或派生资产数据。
   */
  downloadContent(videoID: string, params?: VideoDownloadContentParams): Promise<string>;

  /**
   * Remix 视频。
   *
   * API：`POST /v1/videos/{video_id}/remix`。
   * 说明：基于已完成视频和新 prompt 创建变体视频任务。
   */
  remix(videoID: string, params: VideoRemixParams): Promise<VideoJob>;

  /**
   * 编辑视频。
   *
   * API：`POST /v1/videos/edits`。
   * 说明：基于已完成视频和编辑 prompt 创建新视频任务。
   */
  edit(params: VideoEditParams): Promise<VideoJob>;

  /**
   * 延展视频。
   *
   * API：`POST /v1/videos/extensions`。
   * 说明：基于已完成视频生成后续片段，返回新视频任务。
   */
  extend(params: VideoExtendParams): Promise<VideoJob>;

  /**
   * 删除视频任务。
   *
   * API：`DELETE /v1/videos/{video_id}`。
   * 说明：删除已完成或失败的视频及其存储资产，返回删除确认对象。
   */
  delete(videoID: string): Promise<VideoDeleted>;
}

export class VideosResource implements OpenAIVideosResource {
  characters: OpenAIVideoCharactersResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.characters = new VideoCharactersResource(client);
  }

  async create(params: VideoCreateParams): Promise<VideoJob> {
    const parts = this.buildCreateParts(params);
    const body = await this.client.postMultipart('/videos', parts);
    return JSON.parse(body) as VideoJob;
  }

  async list(params?: VideoListParams): Promise<VideoListResponse> {
    const body = await this.client.get(this.buildListPath(params));
    return JSON.parse(body) as VideoListResponse;
  }

  async retrieve(videoID: string): Promise<VideoJob> {
    const body = await this.client.get('/videos/' + videoID);
    return JSON.parse(body) as VideoJob;
  }

  async downloadContent(videoID: string, params?: VideoDownloadContentParams): Promise<string> {
    return await this.client.getBinary(this.buildContentPath(videoID, params));
  }

  async remix(videoID: string, params: VideoRemixParams): Promise<VideoJob> {
    const body = await this.client.post('/videos/' + videoID + '/remix', params);
    return JSON.parse(body) as VideoJob;
  }

  async edit(params: VideoEditParams): Promise<VideoJob> {
    const body = await this.client.post('/videos/edits', params);
    return JSON.parse(body) as VideoJob;
  }

  async extend(params: VideoExtendParams): Promise<VideoJob> {
    const body = await this.client.post('/videos/extensions', params);
    return JSON.parse(body) as VideoJob;
  }

  async delete(videoID: string): Promise<VideoDeleted> {
    const body = await this.client.delete('/videos/' + videoID);
    return JSON.parse(body) as VideoDeleted;
  }

  private buildCreateParts(params: VideoCreateParams): Array<OpenAIMultipartFormData> {
    const parts: Array<OpenAIMultipartFormData> = [];
    parts.push(buildTextPart('prompt', params.prompt));
    if (params.input_reference !== undefined) {
      parts.push(buildFilePart('input_reference', params.input_reference));
    }
    if (params.model !== undefined && params.model !== null) {
      parts.push(buildTextPart('model', params.model));
    }
    if (params.seconds !== undefined && params.seconds !== null) {
      parts.push(buildTextPart('seconds', params.seconds));
    }
    if (params.size !== undefined && params.size !== null) {
      parts.push(buildTextPart('size', params.size));
    }
    return parts;
  }

  private buildListPath(params?: VideoListParams): string {
    if (params === undefined) {
      return '/videos';
    }
    const query: Array<string> = [];
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    appendStringQuery(query, 'after', params.after);
    if (params.order !== undefined) {
      query.push('order=' + params.order);
    }
    return buildPathWithQuery('/videos', query);
  }

  private buildContentPath(videoID: string, params?: VideoDownloadContentParams): string {
    if (params === undefined) {
      return '/videos/' + videoID + '/content';
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'variant', params.variant);
    return buildPathWithQuery('/videos/' + videoID + '/content', query);
  }
}

/**
 * Videos characters 资源入口。
 *
 * API：`/v1/videos/characters`。
 * 说明：上传视频创建可复用角色，并按 ID 读取角色元数据。
 */
export interface OpenAIVideoCharactersResource {
  /**
   * 创建视频角色。
   *
   * API：`POST /v1/videos/characters`。
   * 说明：使用 multipart 上传 `name` 和 `video` 文件。
   */
  create(params: VideoCharacterCreateParams): Promise<VideoCharacter>;

  /**
   * 获取视频角色。
   *
   * API：`GET /v1/videos/characters/{character_id}`。
   * 说明：读取已创建角色的 ID、名称和创建时间。
   */
  retrieve(characterID: string): Promise<VideoCharacter>;
}

class VideoCharactersResource implements OpenAIVideoCharactersResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: VideoCharacterCreateParams): Promise<VideoCharacter> {
    const parts = this.buildCreateParts(params);
    const body = await this.client.postMultipart('/videos/characters', parts);
    return JSON.parse(body) as VideoCharacter;
  }

  async retrieve(characterID: string): Promise<VideoCharacter> {
    const body = await this.client.get('/videos/characters/' + characterID);
    return JSON.parse(body) as VideoCharacter;
  }

  private buildCreateParts(params: VideoCharacterCreateParams): Array<OpenAIMultipartFormData> {
    const parts: Array<OpenAIMultipartFormData> = [];
    parts.push(buildTextPart('name', params.name));
    parts.push(buildFilePart('video', params.video));
    return parts;
  }
}
