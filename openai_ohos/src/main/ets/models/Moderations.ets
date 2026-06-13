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
 * Moderation 类别适用输入类型。
 *
 * API：Responses moderated completions、Chat Completions moderated completions。
 * 说明：官方会标记每个分类分数对应文本、图片或二者。
 */
export type ModerationAppliedInputType = 'text' | 'image';

/**
 * Moderation 类别适用输入类型映射。
 *
 * API：Responses moderated completions、Chat Completions moderated completions。
 * 说明：键名由官方安全分类定义，值表示该分数参考的输入模态。
 */
export type ModerationCategoryAppliedInputTypes = Record<string, Array<ModerationAppliedInputType>>;

/**
 * Moderated completions 成功结果。
 *
 * API：Responses moderated completions、Chat Completions moderated completions。
 * 说明：用于描述输入或输出一侧的审核结果。
 */
export interface ModerationResult {
  /**
   * 类别布尔结果。
   *
   * API：Moderated completions。
   * 说明：键名由官方安全分类定义。
   */
  categories: ModerationCategories;

  /**
   * 类别适用输入类型。
   *
   * API：Moderated completions。
   * 说明：表示每个分类分数对应的输入模态。
   */
  category_applied_input_types: ModerationCategoryAppliedInputTypes;

  /**
   * 类别分数。
   *
   * API：Moderated completions。
   * 说明：分数越高表示越可能命中该类别。
   */
  category_scores: ModerationCategoryScores;

  /**
   * 是否整体违规。
   *
   * API：Moderated completions。
   * 说明：任一关键类别命中时通常为 true。
   */
  flagged: boolean;

  /**
   * 生成该审核结果的模型。
   *
   * API：Moderated completions。
   * 说明：例如 `omni-moderation-latest`。
   */
  model: string;

  /**
   * 结果类型。
   *
   * API：Moderated completions。
   * 说明：成功审核结果固定为 `moderation_result`。
   */
  type: 'moderation_result';
}

/**
 * Moderated completions 审核错误。
 *
 * API：Responses moderated completions、Chat Completions moderated completions。
 * 说明：输入或输出审核失败时返回。
 */
export interface ModerationError {
  /**
   * 错误代码。
   *
   * API：Moderated completions。
   * 说明：由服务端返回。
   */
  code: string;

  /**
   * 错误信息。
   *
   * API：Moderated completions。
   * 说明：用于排查审核失败原因。
   */
  message: string;

  /**
   * 结果类型。
   *
   * API：Moderated completions。
   * 说明：失败时固定为 `error`。
   */
  type: 'error';
}

/**
 * Responses moderated completions 单侧审核结果。
 *
 * API：Responses moderated completions。
 * 说明：input/output 各自可能是成功审核结果，也可能是审核错误。
 */
export type ModerationOutcome = ModerationResult | ModerationError;

/**
 * Chat Completions moderated completions 成功结果集合。
 *
 * API：Chat Completions moderated completions。
 * 说明：Chat 接口会把一侧审核结果包成 `moderation_results` 对象。
 */
export interface ModerationResults {
  /**
   * 使用的审核模型。
   *
   * API：Chat Completions moderated completions。
   * 说明：例如 `omni-moderation-latest`。
   */
  model: string;

  /**
   * 审核结果列表。
   *
   * API：Chat Completions moderated completions。
   * 说明：顺序与对应输入或输出内容一致。
   */
  results: Array<ModerationResult>;

  /**
   * 结果集合类型。
   *
   * API：Chat Completions moderated completions。
   * 说明：固定为 `moderation_results`。
   */
  type: 'moderation_results';
}

/**
 * Chat Completions moderated completions 单侧审核结果。
 *
 * API：Chat Completions moderated completions。
 * 说明：input/output 各自可能是成功结果集合，也可能是审核错误。
 */
export type ModerationResultsOutcome = ModerationResults | ModerationError;

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
