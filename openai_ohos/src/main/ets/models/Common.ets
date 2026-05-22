/**
 * OpenAI SDK model 公共类型。
 *
 * 这些类型被多个核心 API 复用，主要覆盖 JSON 参数、元数据、分页、错误和 token 用量结构。
 */

/**
 * 任意 OpenAI 模型 ID。
 *
 * API：所有需要 `model` 字段的核心 API，例如 `POST /v1/responses`、`POST /v1/chat/completions`。
 * 说明：官方会持续发布新模型，因此 SDK 允许传入任意字符串，同时在各 API 文件中保留常见模型枚举提示。
 */
export type OpenAIModel = string;

/**
 * JSON 原始值。
 *
 * API：结构化输出、函数参数 schema、batch metadata 等所有需要 JSON 对象的 API。
 * 说明：用于描述可序列化到请求体里的值，避免使用 ArkTS 不推荐的 `any` 或 `unknown`。
 */
export type JsonPrimitive = string | number | boolean | null;

/**
 * JSON 字段值。
 *
 * API：结构化输出、工具参数、batch 自定义请求体等所有需要 JSON 字段的 API。
 * 说明：ArkTS 不允许递归 type alias，这里使用有限嵌套类型覆盖 SDK model 层常见字段。
 */
export type JsonFieldValue = JsonPrimitive | Array<JsonPrimitive> | Record<string, JsonPrimitive | Array<JsonPrimitive>>;

/**
 * JSON 数组。
 *
 * API：结构化输出、工具参数、batch 自定义请求体等所有需要 JSON 数组的 API。
 * 说明：数组成员仍然必须是可 JSON 序列化的值。
 */
export type JsonArray = Array<JsonFieldValue>;

/**
 * JSON 对象。
 *
 * API：结构化输出、工具参数、metadata 之外的自由 JSON 对象字段。
 * 说明：ArkTS 不推荐手写 index signature，因此使用 `Record<string, JsonValue>` 表示动态 JSON object。
 */
export type JsonObject = Record<string, JsonFieldValue>;

/**
 * JSON 值。
 *
 * API：所有需要自由 JSON 结构的字段。
 * 说明：作为 SDK 内部的通用 JSON 类型，供 request model 和 response model 共用。
 */
export type JsonValue = JsonPrimitive | JsonArray | JsonObject;

/**
 * OpenAI 对象元数据。
 *
 * API：`POST /v1/responses`、`POST /v1/chat/completions`、`POST /v1/batches` 等支持 `metadata` 的 API。
 * 说明：官方限制通常为最多 16 个键值对；key 最长 64 字符，value 最长 512 字符。这里仅建模，不做运行时校验。
 */
export type Metadata = Record<string, string>;

/**
 * 通用列表响应。
 *
 * API：`GET /v1/models`、`GET /v1/files`、`GET /v1/batches` 等列表 API。
 * 说明：不同 API 的 `data` 元素类型不同，但外层 `object` 通常为 `list`。
 */
export interface OpenAIListResponse<T> {
  /**
   * 列表数据。
   *
   * API：所有列表 API 响应。
   * 说明：元素类型由具体 API 决定，例如 `ModelObject`、`FileObject` 或 `BatchObject`。
   */
  data: Array<T>;

  /**
   * 对象类型。
   *
   * API：所有列表 API 响应。
   * 说明：OpenAI 列表响应该字段通常固定为 `list`。
   */
  object: 'list';

  /**
   * 是否还有下一页。
   *
   * API：游标分页列表 API。
   * 说明：部分 API 返回该字段，用于判断是否继续传入 `after` 拉取下一页。
   */
  has_more?: boolean;

  /**
   * 第一条数据 ID。
   *
   * API：游标分页列表 API。
   * 说明：用于调试或分页定位，字段是否存在取决于具体 endpoint。
   */
  first_id?: string | null;

  /**
   * 最后一条数据 ID。
   *
   * API：游标分页列表 API。
   * 说明：通常可作为下一次请求的 `after` 游标。
   */
  last_id?: string | null;
}

/**
 * 通用分页查询参数。
 *
 * API：`GET /v1/files`、`GET /v1/batches` 等列表 API。
 * 说明：具体 API 可能只支持其中一部分字段。
 */
export interface CursorPageParams {
  /**
   * 下一页游标。
   *
   * API：游标分页列表 API。
   * 说明：传入上一页的最后一个对象 ID，返回其后的数据。
   */
  after?: string;

  /**
   * 上一页游标。
   *
   * API：部分游标分页列表 API。
   * 说明：传入某个对象 ID，返回其前面的数据。
   */
  before?: string;

  /**
   * 返回数量上限。
   *
   * API：游标分页列表 API。
   * 说明：官方通常限制具体范围；这里仅保留字段类型。
   */
  limit?: number;

  /**
   * 排序方向。
   *
   * API：部分列表 API。
   * 说明：`asc` 表示升序，`desc` 表示降序。
   */
  order?: 'asc' | 'desc';
}

/**
 * OpenAI API 错误对象。
 *
 * API：所有 REST API 错误响应。
 * 说明：当 HTTP 请求失败时，client 层可用该模型解析错误体。
 */
export interface OpenAIError {
  /**
   * 错误消息。
   *
   * API：所有 REST API 错误响应。
   * 说明：可直接展示给开发者用于定位参数、鉴权或额度问题。
   */
  message: string;

  /**
   * 错误类型。
   *
   * API：所有 REST API 错误响应。
   * 说明：例如 `invalid_request_error`、`authentication_error`、`rate_limit_error`。
   */
  type: string;

  /**
   * 错误参数名。
   *
   * API：所有 REST API 错误响应。
   * 说明：当错误由某个请求字段触发时，官方可能返回该字段路径。
   */
  param?: string | null;

  /**
   * 错误代码。
   *
   * API：所有 REST API 错误响应。
   * 说明：用于机器判断错误原因，可能为空。
   */
  code?: string | null;
}

/**
 * OpenAI API 错误响应外层。
 *
 * API：所有 REST API 错误响应。
 * 说明：OpenAI 错误 JSON 通常以 `{ "error": ... }` 形式返回。
 */
export interface OpenAIErrorResponse {
  /**
   * 错误详情。
   *
   * API：所有 REST API 错误响应。
   * 说明：包含人类可读消息、类型、参数和错误代码。
   */
  error: OpenAIError;
}

/**
 * 通用 token 用量。
 *
 * API：`POST /v1/chat/completions`、`POST /v1/completions` 等旧式文本 API。
 * 说明：Responses API 有自己的 `ResponseUsage`，字段命名不同。
 */
export interface CompletionUsage {
  /**
   * prompt 消耗 token 数。
   *
   * API：Chat Completions、Completions。
   * 说明：输入消息或 prompt 计入该字段。
   */
  prompt_tokens: number;

  /**
   * 输出消耗 token 数。
   *
   * API：Chat Completions、Completions。
   * 说明：模型生成内容计入该字段。
   */
  completion_tokens: number;

  /**
   * 总 token 数。
   *
   * API：Chat Completions、Completions。
   * 说明：通常等于 prompt token 与 completion token 之和，可能包含额外细分统计。
   */
  total_tokens: number;
}
