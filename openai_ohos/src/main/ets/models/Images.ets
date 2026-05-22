import type { JsonObject, OpenAIModel } from './Common';

/**
 * 图像模型 ID。
 *
 * API：`POST /v1/images/generations`、`POST /v1/images/edits`、`POST /v1/images/variations`。
 * 说明：请求仍允许任意字符串，以兼容 OpenAI 后续图像模型。
 */
export type ImageModel = OpenAIModel | 'gpt-image-1' | 'gpt-image-1-mini' | 'gpt-image-1.5' | 'dall-e-3' | 'dall-e-2';

/**
 * 图像尺寸。
 *
 * API：Images API。
 * 说明：不同模型支持的尺寸不同，HTTP 层可进一步校验。
 */
export type ImageSize = 'auto' | '256x256' | '512x512' | '1024x1024' | '1024x1536' | '1536x1024' | '1792x1024' | '1024x1792';

/**
 * 流式图像预览数量。
 *
 * API：`POST /v1/images/generations`、`POST /v1/images/edits`。
 * 说明：仅在 `stream: true` 时使用；官方当前支持 0 到 3，0 表示只返回最终图。
 */
export type ImagePartialImages = 0 | 1 | 2 | 3 | number;

/**
 * 生成图像请求。
 *
 * API：`POST /v1/images/generations`。
 * 说明：根据文本 prompt 生成一张或多张图片。
 */
export interface ImageGenerateParams {
  /**
   * 图像描述。
   *
   * API：Image generation。
   * 说明：描述要生成的图片内容、风格、构图和约束。
   */
  prompt: string;

  /**
   * 背景透明度。
   *
   * API：Image generation。
   * 说明：GPT image 模型支持；透明背景需要 `png` 或 `webp` 输出格式。
   */
  background?: 'transparent' | 'opaque' | 'auto' | null;

  /**
   * 模型 ID。
   *
   * API：Image generation。
   * 说明：例如 `gpt-image-1`、`gpt-image-1.5`、`dall-e-3`。
   */
  model?: ImageModel | null;

  /**
   * moderation 强度。
   *
   * API：Image generation。
   * 说明：GPT image 模型支持 `low` 或 `auto`。
   */
  moderation?: 'low' | 'auto' | null;

  /**
   * 生成数量。
   *
   * API：Image generation。
   * 说明：不同模型对数量限制不同；`dall-e-3` 通常只支持 1。
   */
  n?: number | null;

  /**
   * 输出压缩比例。
   *
   * API：Image generation。
   * 说明：GPT image 模型在 `webp` 或 `jpeg` 输出时支持。
   */
  output_compression?: number | null;

  /**
   * 输出格式。
   *
   * API：Image generation。
   * 说明：GPT image 模型支持 `png`、`jpeg`、`webp`。
   */
  output_format?: 'png' | 'jpeg' | 'webp' | null;

  /**
   * 流式预览图数量。
   *
   * API：Image generation/edit streaming。
   * 说明：`stream` 为 true 时请求返回的 partial image 数量，官方当前范围为 0 到 3。
   */
  partial_images?: ImagePartialImages | null;

  /**
   * 质量等级。
   *
   * API：Image generation。
   * 说明：`auto` 由模型选择；更高质量通常成本更高、耗时更长。
   */
  quality?: 'auto' | 'low' | 'medium' | 'high' | 'standard' | 'hd' | null;

  /**
   * 响应格式。
   *
   * API：Image generation。
   * 说明：旧图像模型可返回 URL 或 base64 JSON；GPT image 模型通常返回 base64。
   */
  response_format?: 'url' | 'b64_json' | null;

  /**
   * 图像尺寸。
   *
   * API：Image generation。
   * 说明：不同模型支持范围不同。
   */
  size?: ImageSize | null;

  /**
   * 是否流式返回。
   *
   * API：Image generation。
   * 说明：支持流式图像事件的模型可使用。
   */
  stream?: boolean | null;

  /**
   * 风格。
   *
   * API：Image generation。
   * 说明：部分旧模型支持 `vivid` 或 `natural`。
   */
  style?: 'vivid' | 'natural' | null;

  /**
   * 终端用户标识。
   *
   * API：Image generation。
   * 说明：用于滥用检测。
   */
  user?: string;
}

/**
 * 编辑图像请求。
 *
 * API：`POST /v1/images/edits`。
 * 说明：根据输入图片、可选遮罩和 prompt 生成编辑后的图像。
 */
export interface ImageEditParams extends ImageGenerateParams {
  /**
   * 输入图片。
   *
   * API：Image edit。
   * 说明：Harmony HTTP 层可把本地 URI、沙箱路径或文件 ID 转成 multipart 上传；模型层先用字符串承载。
   */
  image: string | Array<string>;

  /**
   * 遮罩图片。
   *
   * API：Image edit。
   * 说明：透明区域表示需要编辑的区域。
   */
  mask?: string | null;

  /**
   * 输入保真度。
   *
   * API：Image edit。
   * 说明：控制编辑时对输入图像的保留程度；具体支持值以服务端为准。
   */
  input_fidelity?: 'low' | 'high' | null;
}

/**
 * 创建图像变体请求。
 *
 * API：`POST /v1/images/variations`。
 * 说明：旧式 DALL-E 变体接口，非当前优先图像入口。
 */
export interface ImageCreateVariationParams {
  /**
   * 基础图片。
   *
   * API：Image variation。
   * 说明：通常要求 PNG、方形、大小限制由官方接口决定。
   */
  image: string;

  /**
   * 模型 ID。
   *
   * API：Image variation。
   * 说明：官方当前主要支持 `dall-e-2`。
   */
  model?: ImageModel | null;

  /**
   * 生成数量。
   *
   * API：Image variation。
   * 说明：返回变体图片数量。
   */
  n?: number | null;

  /**
   * 响应格式。
   *
   * API：Image variation。
   * 说明：返回 URL 或 base64。
   */
  response_format?: 'url' | 'b64_json' | null;

  /**
   * 图像尺寸。
   *
   * API：Image variation。
   * 说明：旧接口常用 `256x256`、`512x512`、`1024x1024`。
   */
  size?: ImageSize | null;

  /**
   * 终端用户标识。
   *
   * API：Image variation。
   * 说明：用于滥用检测。
   */
  user?: string;
}

/**
 * 图像结果对象。
 *
 * API：Images API 响应。
 * 说明：单张生成、编辑或变体图片。
 */
export interface Image {
  /**
   * base64 图片数据。
   *
   * API：Images API 响应。
   * 说明：当响应格式为 `b64_json` 或 GPT image 模型返回 base64 时存在。
   */
  b64_json?: string;

  /**
   * 图片 URL。
   *
   * API：Images API 响应。
   * 说明：当响应格式为 `url` 时存在，通常有过期时间。
   */
  url?: string;

  /**
   * 修订后的 prompt。
   *
   * API：Images API 响应。
   * 说明：部分模型会返回优化后的 prompt。
   */
  revised_prompt?: string;
}

/**
 * 图像 token 用量。
 *
 * API：Images API 响应。
 * 说明：GPT image 模型会返回输入、输出和总 token 信息。
 */
export interface ImageUsage {
  /**
   * 输入 token 数。
   *
   * API：Images API 响应。
   * 说明：包含文本和图像输入折算 token。
   */
  input_tokens: number;

  /**
   * 输出 token 数。
   *
   * API：Images API 响应。
   * 说明：图像生成输出消耗的 token。
   */
  output_tokens: number;

  /**
   * 总 token 数。
   *
   * API：Images API 响应。
   * 说明：输入与输出 token 合计。
   */
  total_tokens: number;

  /**
   * 输入 token 细分。
   *
   * API：Images API 响应。
   * 说明：例如图片 token 和文本 token。
   */
  input_tokens_details?: JsonObject;

  /**
   * 输出 token 细分。
   *
   * API：Images API 响应。
   * 说明：例如图像输出 token。
   */
  output_tokens_details?: JsonObject;
}

/**
 * 图像流式事件类型。
 *
 * API：Image Streaming。
 * 说明：Images API 生成和编辑在开启 `stream` 后会通过 SSE 返回这些事件。
 */
export type ImageStreamingEventType =
  'image_generation.partial_image' |
  'image_generation.completed' |
  'image_edit.partial_image' |
  'image_edit.completed';

/**
 * 图像流式事件基础结构。
 *
 * API：Image Streaming。
 * 说明：生成和编辑的 partial/completed 事件共享这些字段。
 */
export interface ImageStreamingEventBase {
  /**
   * 事件类型。
   *
   * API：Image Streaming。
   * 说明：用于区分生成、编辑、预览图和最终图。
   */
  type: ImageStreamingEventType;

  /**
   * base64 图像数据。
   *
   * API：Image Streaming。
   * 说明：可直接 base64 解码为图片字节。
   */
  b64_json: string;

  /**
   * 创建时间。
   *
   * API：Image Streaming。
   * 说明：Unix 秒级时间戳。
   */
  created_at: number;

  /**
   * 图片尺寸。
   *
   * API：Image Streaming。
   * 说明：服务端实际使用的输出尺寸。
   */
  size: ImageSize | string;

  /**
   * 图片质量。
   *
   * API：Image Streaming。
   * 说明：服务端实际使用的质量设置。
   */
  quality: 'auto' | 'low' | 'medium' | 'high' | 'standard' | 'hd' | string;

  /**
   * 背景设置。
   *
   * API：Image Streaming。
   * 说明：服务端实际使用的背景设置。
   */
  background: 'transparent' | 'opaque' | 'auto' | string;

  /**
   * 输出格式。
   *
   * API：Image Streaming。
   * 说明：例如 `png`、`jpeg`、`webp`。
   */
  output_format: 'png' | 'jpeg' | 'webp' | string;
}

/**
 * 图像流式预览事件。
 *
 * API：`image_generation.partial_image`、`image_edit.partial_image`。
 * 说明：在最终图完成前返回的中间图像。
 */
export interface ImagePartialImageEvent extends ImageStreamingEventBase {
  type: 'image_generation.partial_image' | 'image_edit.partial_image';

  /**
   * 预览图序号。
   *
   * API：Image Streaming。
   * 说明：0-based index，便于 UI 依次替换或展示进度。
   */
  partial_image_index: number;
}

/**
 * 图像流式完成事件。
 *
 * API：`image_generation.completed`、`image_edit.completed`。
 * 说明：携带最终图像和可选 token 用量。
 */
export interface ImageCompletedEvent extends ImageStreamingEventBase {
  type: 'image_generation.completed' | 'image_edit.completed';

  /**
   * token 用量。
   *
   * API：Image Streaming。
   * 说明：GPT image 模型可返回图像生成或编辑消耗的 token。
   */
  usage?: ImageUsage;
}

/**
 * 图像流式事件。
 *
 * API：Image Streaming。
 * 说明：Images API SSE 事件的联合类型。
 */
export type ImageStreamingEvent = ImagePartialImageEvent | ImageCompletedEvent;

/**
 * 图像 API 响应。
 *
 * API：`POST /v1/images/generations`、`POST /v1/images/edits`、`POST /v1/images/variations`。
 * 说明：包含创建时间、图像列表和可选用量。
 */
export interface ImagesResponse {
  /**
   * 创建时间。
   *
   * API：Images API 响应。
   * 说明：Unix 秒级时间戳。
   */
  created: number;

  /**
   * 图片列表。
   *
   * API：Images API 响应。
   * 说明：每个元素包含 URL 或 base64 图片数据。
   */
  data?: Array<Image>;

  /**
   * 背景配置。
   *
   * API：Images API 响应。
   * 说明：返回本次生成实际使用的背景模式。
   */
  background?: 'transparent' | 'opaque';

  /**
   * 输出格式。
   *
   * API：Images API 响应。
   * 说明：返回本次生成实际使用的图片格式。
   */
  output_format?: 'png' | 'webp' | 'jpeg';

  /**
   * 图像质量。
   *
   * API：Images API 响应。
   * 说明：返回本次生成实际使用的质量等级。
   */
  quality?: 'low' | 'medium' | 'high';

  /**
   * 图像尺寸。
   *
   * API：Images API 响应。
   * 说明：返回本次生成实际使用的尺寸。
   */
  size?: string;

  /**
   * token 用量。
   *
   * API：Images API 响应。
   * 说明：GPT image 模型可返回。
   */
  usage?: ImageUsage;
}
