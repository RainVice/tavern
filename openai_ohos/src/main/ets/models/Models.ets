import type { OpenAIListResponse } from './Common';

/**
 * 模型对象。
 *
 * API：`GET /v1/models`、`GET /v1/models/{model}`。
 * 说明：表示当前账号可见的一个模型。
 */
export interface ModelObject {
  /**
   * 模型 ID。
   *
   * API：Models。
   * 说明：用于各生成 API 的 `model` 字段。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Models。
   * 说明：固定为 `model`。
   */
  object: 'model';

  /**
   * 创建时间。
   *
   * API：Models。
   * 说明：Unix 秒级时间戳。
   */
  created: number;

  /**
   * 所有者。
   *
   * API：Models。
   * 说明：模型归属方。
   */
  owned_by: string;
}

/**
 * 模型列表响应。
 *
 * API：`GET /v1/models`。
 * 说明：返回当前 API key 可访问的模型列表。
 */
export type ModelListResponse = OpenAIListResponse<ModelObject>;

/**
 * 删除模型响应。
 *
 * API：`DELETE /v1/models/{model}`。
 * 说明：通常只适用于部分可删除的 fine-tuned model。
 */
export interface ModelDeleted {
  /**
   * 模型 ID。
   *
   * API：Models delete。
   * 说明：被删除的模型。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Models delete。
   * 说明：固定为 `model`。
   */
  object: 'model';

  /**
   * 是否已删除。
   *
   * API：Models delete。
   * 说明：成功删除时为 true。
   */
  deleted: boolean;
}
