import type { OpenAIListResponse, OpenAIModel } from './Common';

/**
 * 视频生成模型 ID。
 *
 * API：Videos API。
 * 说明：官方当前视频模型包括 `sora-2` 和 `sora-2-pro`；仍允许任意字符串，便于兼容后续模型。
 */
export type VideoModel = OpenAIModel | 'sora-2' | 'sora-2-pro' | 'sora-2-2025-10-06' |
  'sora-2-pro-2025-10-06' | 'sora-2-2025-12-08';

/**
 * 视频时长。
 *
 * API：Videos API。
 * 说明：视频生成任务的片段时长，单位秒；官方当前常见值为 `4`、`8`、`12`。
 */
export type VideoSeconds = '4' | '8' | '12' | '16' | '20' | string;

/**
 * 视频尺寸。
 *
 * API：Videos API。
 * 说明：输出分辨率，格式为 `宽x高`，例如 `720x1280` 或 `1280x720`。
 */
export type VideoSize = '720x1280' | '1280x720' | '1024x1792' | '1792x1024' | string;

/**
 * 视频任务状态。
 *
 * API：Videos API 响应。
 * 说明：表示视频生成任务生命周期；具体状态以服务端返回为准。
 */
export type VideoStatus = 'queued' | 'in_progress' | 'completed' | 'failed' | 'cancelled' | 'deleted' | string;

/**
 * 视频下载资产变体。
 *
 * API：`GET /v1/videos/{video_id}/content`。
 * 说明：不传时默认下载 MP4 正片；传入 `thumbnail` 等服务端支持值可获取派生资产。
 */
export type VideoContentVariant = 'video' | 'thumbnail' | 'preview' | string;

/**
 * 视频引用。
 *
 * API：`POST /v1/videos/edits`、`POST /v1/videos/extensions`。
 * 说明：以对象形式引用一个已完成的视频，和官方请求体中的 `video: { id }` 保持一致。
 */
export interface VideoReference {
  /**
   * 视频任务 ID。
   *
   * API：Video edits/extensions。
   * 说明：要编辑或延展的已完成视频 ID。
   */
  id: string;
}

/**
 * 创建视频请求。
 *
 * API：`POST /v1/videos`。
 * 说明：创建一个视频生成任务，使用 multipart 发送文本字段和可选参考图片。
 */
export interface VideoCreateParams {
  /**
   * 视频描述。
   *
   * API：Create video。
   * 说明：描述要生成的视频内容、主体、动作、镜头和风格。
   */
  prompt: string;

  /**
   * 参考图片文件路径。
   *
   * API：Create video。
   * 说明：可选参考图片，SDK 会作为 multipart 文件字段 `input_reference` 上传。
   */
  input_reference?: string;

  /**
   * 模型 ID。
   *
   * API：Create video。
   * 说明：例如 `sora-2`、`sora-2-pro`；不传时由服务端使用默认模型。
   */
  model?: VideoModel | null;

  /**
   * 视频时长。
   *
   * API：Create video。
   * 说明：单位秒，官方当前常见值为 `4`、`8`、`12`。
   */
  seconds?: VideoSeconds | null;

  /**
   * 输出尺寸。
   *
   * API：Create video。
   * 说明：格式为 `宽x高`，例如 `720x1280`、`1280x720`。
   */
  size?: VideoSize | null;
}

/**
 * Remix 视频请求。
 *
 * API：`POST /v1/videos/{video_id}/remix`。
 * 说明：基于已完成的视频，用新的 prompt 创建一个变体视频任务。
 */
export interface VideoRemixParams {
  /**
   * 新的视频描述。
   *
   * API：Remix video。
   * 说明：描述希望在原视频基础上调整、延展或重构的内容。
   */
  prompt: string;
}

/**
 * 编辑视频请求。
 *
 * API：`POST /v1/videos/edits`。
 * 说明：基于已完成视频和编辑 prompt 创建新的视频生成任务。
 */
export interface VideoEditParams {
  /**
   * 编辑描述。
   *
   * API：Edit video。
   * 说明：描述如何修改源视频内容；官方限制为 1 到 32000 字符。
   */
  prompt: string;

  /**
   * 源视频引用。
   *
   * API：Edit video。
   * 说明：引用一个已完成的视频，格式为 `{ id: "video_..." }`。
   */
  video: VideoReference;
}

/**
 * 延展视频请求。
 *
 * API：`POST /v1/videos/extensions`。
 * 说明：基于已完成视频生成后续片段，返回拼接后的新视频任务。
 */
export interface VideoExtendParams {
  /**
   * 延展描述。
   *
   * API：Extend video。
   * 说明：描述希望在原视频结尾之后继续发生的内容。
   */
  prompt: string;

  /**
   * 新增片段时长。
   *
   * API：Extend video。
   * 说明：单位秒，官方支持 `4`、`8`、`12`，文档说明延展片段也可支持更长值。
   */
  seconds?: VideoSeconds | null;

  /**
   * 源视频引用。
   *
   * API：Extend video。
   * 说明：引用一个已完成的视频，格式为 `{ id: "video_..." }`。
   */
  video: VideoReference;
}

/**
 * 创建视频角色请求。
 *
 * API：`POST /v1/videos/characters`。
 * 说明：上传视频文件并创建一个可复用的 API character/cameo。
 */
export interface VideoCharacterCreateParams {
  /**
   * 角色显示名。
   *
   * API：Create Character。
   * 说明：展示给业务侧使用的角色名称；官方限制为 1 到 80 字符。
   */
  name: string;

  /**
   * 视频文件路径。
   *
   * API：Create Character。
   * 说明：SDK 会作为 multipart 文件字段 `video` 上传。
   */
  video: string;
}

/**
 * 视频角色对象。
 *
 * API：`POST /v1/videos/characters`、`GET /v1/videos/characters/{character_id}`。
 * 说明：描述已创建的视频角色，可用于后续视频生成能力。
 */
export interface VideoCharacter {
  /**
   * 角色 ID。
   *
   * API：Video characters。
   * 说明：服务端生成的 character/cameo 标识。
   */
  id: string;

  /**
   * 创建时间。
   *
   * API：Video characters。
   * 说明：Unix 秒级时间戳。
   */
  created_at: number;

  /**
   * 角色显示名。
   *
   * API：Video characters。
   * 说明：创建时传入的展示名称。
   */
  name: string;
}

/**
 * 视频列表查询参数。
 *
 * API：`GET /v1/videos`。
 * 说明：分页读取当前项目最近生成的视频任务。
 */
export interface VideoListParams {
  /**
   * 下一页游标。
   *
   * API：List videos。
   * 说明：传入上一页最后一个视频 ID，读取之后的数据。
   */
  after?: string;

  /**
   * 返回数量上限。
   *
   * API：List videos。
   * 说明：限制本次返回的视频任务数量。
   */
  limit?: number;

  /**
   * 排序方向。
   *
   * API：List videos。
   * 说明：`asc` 为升序，`desc` 为降序。
   */
  order?: 'asc' | 'desc';
}

/**
 * 视频内容下载参数。
 *
 * API：`GET /v1/videos/{video_id}/content`。
 * 说明：选择要下载的视频资产变体。
 */
export interface VideoDownloadContentParams {
  /**
   * 下载资产变体。
   *
   * API：Retrieve video content。
   * 说明：不传时默认下载 MP4 正片；服务端可支持缩略图或预览等派生资产。
   */
  variant?: VideoContentVariant;
}

/**
 * 视频任务错误。
 *
 * API：Videos API 响应。
 * 说明：当视频生成失败时，服务端可返回机器可读错误码和人类可读说明。
 */
export interface VideoError {
  /**
   * 错误代码。
   *
   * API：Video job。
   * 说明：机器可读错误码，便于业务侧做分支处理。
   */
  code: string;

  /**
   * 错误说明。
   *
   * API：Video job。
   * 说明：人类可读错误消息，用于日志或开发调试。
   */
  message: string;
}

/**
 * 视频任务对象。
 *
 * API：Videos API 响应。
 * 说明：描述一次视频生成、查询、remix 或删除后返回的视频任务。
 */
export interface VideoJob {
  /**
   * 视频任务 ID。
   *
   * API：Videos API。
   * 说明：后续 retrieve、downloadContent、remix、delete 都使用该 ID。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Videos API。
   * 说明：视频任务对象固定为 `video`。
   */
  object: 'video' | string;

  /**
   * 创建时间。
   *
   * API：Video job。
   * 说明：Unix 秒级时间戳。
   */
  created_at: number;

  /**
   * 完成时间。
   *
   * API：Video job。
   * 说明：任务完成时的 Unix 秒级时间戳；未完成时可能不存在。
   */
  completed_at?: number | null;

  /**
   * 过期时间。
   *
   * API：Video job。
   * 说明：可下载资产过期时间，Unix 秒级时间戳；服务端未返回时为空。
   */
  expires_at?: number | null;

  /**
   * 模型 ID。
   *
   * API：Video job。
   * 说明：实际生成该视频任务的模型。
   */
  model?: VideoModel;

  /**
   * 任务状态。
   *
   * API：Video job。
   * 说明：例如 `queued`、`completed`、`failed`。
   */
  status: VideoStatus;

  /**
   * 任务进度。
   *
   * API：Video job。
   * 说明：近似完成百分比，通常为 0 到 100。
   */
  progress?: number;

  /**
   * 原始 prompt。
   *
   * API：Video job。
   * 说明：创建或 remix 时使用的视频描述。
   */
  prompt?: string;

  /**
   * 源视频 ID。
   *
   * API：Remix video。
   * 说明：如果当前任务来自 remix，这里保存源视频 ID。
   */
  remixed_from_video_id?: string;

  /**
   * 视频时长。
   *
   * API：Video job。
   * 说明：单位秒，字符串形式与请求字段保持一致。
   */
  seconds?: VideoSeconds;

  /**
   * 视频尺寸。
   *
   * API：Video job。
   * 说明：格式为 `宽x高`。
   */
  size?: VideoSize;

  /**
   * 视频质量。
   *
   * API：Video job。
   * 说明：服务端返回的质量标识，例如 `standard`。
   */
  quality?: string;

  /**
   * 错误详情。
   *
   * API：Video job。
   * 说明：任务失败时可能返回。
   */
  error?: VideoError | null;
}

/**
 * 视频删除响应。
 *
 * API：`DELETE /v1/videos/{video_id}`。
 * 说明：确认视频资源已删除，和官方 `video.deleted` 响应保持一致。
 */
export interface VideoDeleted {
  /**
   * 视频 ID。
   *
   * API：Delete video。
   * 说明：被删除的视频任务 ID。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Delete video。
   * 说明：删除响应固定为 `video.deleted`。
   */
  object: 'video.deleted' | string;

  /**
   * 删除标记。
   *
   * API：Delete video。
   * 说明：为 `true` 表示服务端已删除该资源。
   */
  deleted: boolean;
}

/**
 * 视频列表响应。
 *
 * API：`GET /v1/videos`。
 * 说明：分页返回视频任务数组。
 */
export type VideoListResponse = OpenAIListResponse<VideoJob>;
