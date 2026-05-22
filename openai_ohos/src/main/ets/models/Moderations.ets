import type { JsonObject, OpenAIModel } from './Common';

/**
 * Moderation 模型 ID。
 *
 * API：`POST /v1/moderations`。
 * 说明：请求字段仍允许任意字符串，以兼容后续 moderation 模型。
 */
export type ModerationModel = OpenAIModel | 'omni-moderation-latest' | 'omni-moderation-2024-09-26' | 'text-moderation-latest';

/**
 * Moderation 文本输入。
 *
 * API：`POST /v1/moderations`。
 * 说明：用于审核文本内容。
 */
export interface ModerationTextInput {
  /**
   * 输入类型。
   *
   * API：Moderations。
   * 说明：固定为 `text`。
   */
  type: 'text';

  /**
   * 文本内容。
   *
   * API：Moderations。
   * 说明：需要审核的文本。
   */
  text: string;
}

/**
 * Moderation 图片输入。
 *
 * API：`POST /v1/moderations`。
 * 说明：用于审核图片内容。
 */
export interface ModerationImageInput {
  /**
   * 输入类型。
   *
   * API：Moderations。
   * 说明：固定为 `image_url`。
   */
  type: 'image_url';

  /**
   * 图片信息。
   *
   * API：Moderations。
   * 说明：包含需要审核的图片 URL。
   */
  image_url: ModerationImageUrl;
}

/**
 * Moderation 图片 URL。
 *
 * API：`POST /v1/moderations`。
 * 说明：可传公网 URL 或 base64 data URL。
 */
export interface ModerationImageUrl {
  /**
   * 图片地址。
   *
   * API：Moderations。
   * 说明：完整 URL 或 data URL。
   */
  url: string;
}

/**
 * Moderation 多模态输入项。
 *
 * API：`POST /v1/moderations`。
 * 说明：用于同时审核文本和图片。
 */
export type ModerationMultiModalInput = ModerationTextInput | ModerationImageInput;

/**
 * 创建 Moderation 请求。
 *
 * API：`POST /v1/moderations`。
 * 说明：审核文本或多模态输入是否违反安全类别。
 */
export interface ModerationCreateParams {
  /**
   * 输入内容。
   *
   * API：Moderations。
   * 说明：可传单条文本、文本数组或多模态输入数组。
   */
  input: string | Array<string> | Array<ModerationMultiModalInput>;

  /**
   * 模型 ID。
   *
   * API：Moderations。
   * 说明：常用 `omni-moderation-latest`。
   */
  model?: ModerationModel;
}

/**
 * Moderation 类别标记。
 *
 * API：Moderations 响应。
 * 说明：每个字段表示对应安全类别是否命中。
 */
export type ModerationCategories = Record<string, boolean>;

/**
 * Moderation 类别分数。
 *
 * API：Moderations 响应。
 * 说明：每个字段表示对应安全类别的置信分数。
 */
export type ModerationCategoryScores = Record<string, number>;

/**
 * Moderation 单条结果。
 *
 * API：Moderations 响应。
 * 说明：对应输入中的一条待审核内容。
 */
export interface Moderation {
  /**
   * 是否整体违规。
   *
   * API：Moderations 响应。
   * 说明：任一关键类别命中时通常为 true。
   */
  flagged: boolean;

  /**
   * 类别布尔结果。
   *
   * API：Moderations 响应。
   * 说明：键名由官方安全分类定义。
   */
  categories: ModerationCategories;

  /**
   * 类别分数。
   *
   * API：Moderations 响应。
   * 说明：分数越高表示越可能命中该类别。
   */
  category_scores: ModerationCategoryScores;

  /**
   * 额外结果。
   *
   * API：Moderations 响应。
   * 说明：为兼容官方新增字段保留。
   */
  category_applied_input_types?: JsonObject;
}

/**
 * Moderation 响应。
 *
 * API：`POST /v1/moderations`。
 * 说明：包含请求 ID、模型和审核结果数组。
 */
export interface ModerationCreateResponse {
  /**
   * 请求 ID。
   *
   * API：Moderations 响应。
   * 说明：用于日志和排错。
   */
  id: string;

  /**
   * 模型 ID。
   *
   * API：Moderations 响应。
   * 说明：实际使用的 moderation 模型。
   */
  model: string;

  /**
   * 审核结果。
   *
   * API：Moderations 响应。
   * 说明：顺序与输入顺序一致。
   */
  results: Array<Moderation>;
}
